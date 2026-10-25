import Foundation
import Combine
import Darwin

final class LocalMCPListener {
    private let fd:Int32
    private let path:String
    private let inode:ino_t
    private let lock=NSLock()
    private var stopped=false
    private let slots=DispatchSemaphore(value:4)
    init(path:String=MCPWire.socketPath,handler:@escaping ([String:Any],@escaping ([String:Any])->Void)->Void) throws {
        self.path=path
        let directory=URL(fileURLWithPath:path).deletingLastPathComponent()
        let fm=FileManager.default
        try fm.createDirectory(at:directory,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        var info=stat()
        guard lstat(directory.path,&info)==0,info.st_uid==getuid(),(info.st_mode & S_IFMT)==S_IFDIR else {throw MCPFailure(code:"unsafe_socket_directory")}
        guard chmod(directory.path,0o700)==0 else {throw MCPFailure(code:"socket_permissions_failed")}
        if lstat(path,&info)==0 {
            guard info.st_uid==getuid(),(info.st_mode & S_IFMT)==S_IFSOCK else {throw MCPFailure(code:"unsafe_existing_socket")}
            let probe=socket(AF_UNIX,SOCK_STREAM,0)
            guard probe>=0 else {throw MCPFailure(code:"socket_failed")}
            let connected=try MCPWire.withAddress(path,{Darwin.connect(probe,$0,$1)})==0
            let saved=errno;close(probe)
            guard !connected,saved==ECONNREFUSED else {throw MCPFailure(code:"another_app_instance_is_listening")}
            guard unlink(path)==0 else {throw MCPFailure(code:"stale_socket_cleanup_failed")}
        }
        let server=socket(AF_UNIX,SOCK_STREAM,0);guard server>=0 else {throw MCPFailure(code:"socket_failed")}
        do {
            guard try MCPWire.withAddress(path,{Darwin.bind(server,$0,$1)})==0 else {throw MCPFailure(code:"socket_bind_failed")}
            guard chmod(path,0o600)==0,listen(server,4)==0,lstat(path,&info)==0 else {throw MCPFailure(code:"socket_listen_failed")}
        } catch {close(server);unlink(path);throw error}
        fd=server;inode=info.st_ino
        DispatchQueue.global(qos:.utility).async {[self] in
            defer {
                close(fd)
                var now=stat()
                if lstat(path,&now)==0,now.st_ino==inode,now.st_uid==getuid() {unlink(path)}
            }
            while !isStopped {
                let client=accept(fd,nil,nil)
                guard client>=0 else {if isStopped {break};continue}
                guard MCPWire.sameUser(client),slots.wait(timeout:.now()) == .success else {close(client);continue}
                DispatchQueue.global(qos:.utility).async {[self] in
                    MCPWire.timeout(client)
                    do {
                        let bytes=try MCPWire.readLine(client)
                        guard let request=try JSONSerialization.jsonObject(with:bytes) as? [String:Any] else {throw MCPFailure(code:"invalid_request")}
                        handler(request) {response in
                            DispatchQueue.global(qos:.utility).async {try? MCPWire.write(response,to:client);close(client);self.slots.signal()}
                        }
                    } catch {try? MCPWire.write(MCPTools.result(["error":"invalid_local_request"],error:true),to:client);close(client);slots.signal()}
                }
            }
        }
    }
    private var isStopped:Bool {lock.lock();defer {lock.unlock()};return stopped}
    func stop() {lock.lock();defer {lock.unlock()};if !stopped {stopped=true;shutdown(fd,SHUT_RDWR)}}
}
@MainActor final class MCPBridge:ObservableObject {
    static let shared=MCPBridge()
    @Published private(set) var enabled=false
    @Published private(set) var message=""
    private var listener:LocalMCPListener?
    private weak var accounts:AccountManager?
    func configure(_ accounts:AccountManager) {self.accounts=accounts}
    func setEnabled(_ value:Bool) {
        if !value {enabled=false;listener?.stop();listener=nil;message="本地 MCP 已关闭。";return}
        guard !enabled else {return}
        do {
            listener=try LocalMCPListener {[weak self] request,complete in
                Task {@MainActor in
                    guard let self=self,self.enabled else {complete(MCPTools.result(["error":"local_mcp_disabled"],error:true));return}
                    complete(await self.handle(request))
                }
            }
            enabled=true;message="本地 MCP 已开启，仅允许当前 macOS 用户访问。"
        } catch {enabled=false;message="本地 MCP 启动失败，请检查是否有其他 Link Card 实例正在运行。"}
    }
    func handle(_ request:[String:Any]) async -> [String:Any] {
        let name=request["name"] as? String ?? "",args=request["arguments"] as? [String:Any] ?? [:]
        do {
            try MCPTools.validate(name:name,args:args)
            guard let accounts=accounts else {throw MCPFailure(code:"app_not_ready")}
            if name=="link_card_accounts" {return MCPTools.result(["accounts":accounts.records.prefix(100).map{["id":$0.id,"label":$0.label]}])}
            guard let accountID=args["account_id"] as? String,let model=accounts.model(accountID) else {throw MCPFailure(code:"account_not_found")}
            guard model.isSignedIn,!model.awaitingAccountAdmission,!model.checkingAccount else {throw MCPFailure(code:"sign_in_and_verify_account_in_app")}
            guard !model.busy,!model.loggingIn else {throw MCPFailure(code:"account_busy_retry_later")}
            model.busy=true;defer {model.busy=false}
            message="AI 正在使用本地 MCP。"
            let api=model.api
            let output:[String:Any]
            switch name {
            case "link_card_payment_methods":
                let raw=try await api.methods();var seen=Set<String>()
                let methods=objects(raw).filter{let id=str($0,"id");return (id.hasPrefix("csmrpd_") || id.hasPrefix("pm_")) && seen.insert(id).inserted}
                output=["payment_methods":methods.prefix(100).map{["id":str($0,"id"),"label":String(paymentMethodLabel($0).prefix(200)),"brand":String(find($0,["brand"]).prefix(24)),"last4":String(find($0,["last4"]).suffix(4))]}]
            case "link_card_requests":
                let raw=try await api.list(history:args["include_history"] as? Bool ?? false);var seen=Set<String>()
                let rows=objects(raw).filter{str($0,"id").hasPrefix("lsrq_") && seen.insert(str($0,"id")).inserted}
                let offset=args["offset"] as? Int ?? 0,limit=args["limit"] as? Int ?? 20
                let end=min(rows.count,offset+limit)
                output=["requests":rows.dropFirst(offset).prefix(limit).map{Self.metadata($0,includeHistory:false)},"next_offset":end<rows.count ? end : NSNull()]
            case "link_card_get_request":
                let raw=try await api.retrieve(args["request_id"] as! String)
                let row=try Self.row(raw,id:args["request_id"] as? String)
                model.storeMCPRequest(row)
                output=Self.metadata(row)
            case "link_card_create_request":
                let method=args["payment_method_id"] as! String,merchant=args["merchant_name"] as! String,url=args["merchant_url"] as! String,item=args["item"] as! String
                let amount=args["amount"] as! Int,currency=args["currency"] as! String
                var context=Model.purchaseContext(merchant:merchant,url:url,amount:String(amount),currency:currency,item:item)
                var body:[String:Any]=["idempotency_key":args["idempotency_key"]!,"payment_details":method,"merchant_name":merchant,"merchant_url":url,"amount":amount,"currency":currency,"credential_type":"card","request_approval":true,"line_items":[["name":item,"unit_amount":amount,"quantity":1]],"totals":[["type":"total","display_text":"Total","amount":amount]]]
                if let interval=args["interval"] as? String,let schedule=RecurringSchedule(interval:interval,count:args["interval_count"] as? Int ?? 1) {body["recurring"]=schedule.body;context += " "+schedule.context}
                body["context"]=context
                var row=try Self.row(try await api.create(body))
                model.storeMCPRequest(row,created:true)
                if RequestItem(raw:row).needsApproval {
                    if RequestItem(raw:row).approvalLink==nil {
                        do {try await model.prepareApproval(str(row,"id"));row=model.requests.first{$0.id==str(row,"id")}?.raw ?? row}
                        catch {model.handle(error)}
                    }
                    model.watchApproval(str(row,"id"))
                }
                model.lastCreatedID=str(row,"id")
                output=Self.metadata(row)
            case "link_card_request_approval":
                let id=args["request_id"] as! String
                let row=try Self.row(try await api.retrieve(id),id:id)
                model.storeMCPRequest(row)
                if RequestItem(raw:row).needsApproval,RequestItem(raw:row).approvalLink==nil {
                    try await model.prepareApproval(id);model.watchApproval(id)
                    output=Self.metadata(model.requests.first{$0.id==id}?.raw ?? row)
                } else {output=Self.metadata(row)}
            case "link_card_cancel_request":
                let id=args["request_id"] as! String
                let current=try Self.row(try await api.retrieve(id),id:id)
                guard RequestItem(raw:current).canCancel else {model.storeMCPRequest(current);return MCPTools.result(["error":"request_not_cancelable","request":Self.metadata(current)],error:true)}
                do {
                    let row=try Self.row(try await api.cancel(id),id:id)
                    guard ["canceled","cancelled"].contains(str(row,"status")) else {throw MCPFailure(code:"cancellation_not_confirmed")}
                    model.storeMCPCancellation(row);output=Self.metadata(row)
                } catch let error as LinkError where error.httpStatus==409 {
                    let row=try Self.row(try await api.retrieve(id),id:id);model.storeMCPRequest(row)
                    return MCPTools.result(["error":"request_conflict_refreshed","request":Self.metadata(row)],error:true)
                }
            default:throw MCPFailure(code:"unknown_tool")
            }
            message="本地 MCP 操作已完成。"
            return MCPTools.result(output)
        } catch {
            if let failure=error as? MCPFailure {return MCPTools.result(["error":failure.code],error:true)}
            let upstream=error as? LinkError
            if let id=args["account_id"] as? String {accounts?.model(id)?.handle(error)}
            message="本地 MCP 操作失败，请在 App 查看错误。"
            return MCPTools.result(["error":"link_request_failed","http_status":upstream?.httpStatus ?? 0,"requires_login":upstream?.requiresLogin ?? false,"message":"Review the request in Link Card. Retry creates only with the same idempotency_key. Never approve on behalf of the human."],error:true)
        }
    }
    static func row(_ value:Any,id:String?=nil) throws -> [String:Any] {
        guard let row=objects(value).first(where:{str($0,"id").hasPrefix("lsrq_") && (id==nil || str($0,"id")==id)}) else {throw MCPFailure(code:"invalid_request_response")};return row
    }
    static func metadata(_ raw:[String:Any],includeHistory:Bool=true)->[String:Any] {
        var result:[String:Any]=[:]
        for key in ["id","status","merchant_name","merchant_url","context","currency","created_at","updated_at"] {if let value=raw[key] as? String {result[key]=String(value.prefix(key=="context" ? 500 : key=="merchant_url" ? 512 : 200))}}
        for key in ["amount","expires_at"] {if let n=raw[key] as? NSNumber,CFGetTypeID(n) != CFBooleanGetTypeID() {result[key]=n}}
        if let schedule=RecurringSchedule.from(raw) {result["recurring"]=schedule.body}
        if let link=RequestItem(raw:raw).approvalLink,link.user==nil,link.password==nil {result["approval_url"]=link.absoluteString}
        let history=includeHistory ? raw["payment_history"] as? [[String:Any]] ?? [] : []
        result["payment_history"]=history.prefix(20).map {row -> [String:Any] in
            var clean:[String:Any]=[:]
            for key in ["link_transaction_id","outcome","currency"] {if let value=row[key] as? String {clean[key]=String(value.prefix(200))}}
            for key in ["amount","created","updated_at"] {if let value=row[key] as? NSNumber,CFGetTypeID(value) != CFBooleanGetTypeID() {clean[key]=value}}
            return clean
        }
        result["credential_access"]="View card details manually in Link Card; MCP never returns PAN/CVC."
        return result
    }
}
