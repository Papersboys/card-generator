import Foundation
import Security

struct LinkTokens: Codable {
    var access_token:String
    var refresh_token:String?
    var expires_in:Double?
    var expires_at:Double?
}
struct LoginSlowDown:Error {}
struct DeviceLogin {
    let deviceCode:String
    let phrase:String
    let url:URL
    let interval:Double
    let expires:Date
}
enum TokenStore {
    static let service="local.yuanxili.linkcard.oauth"
    static var query:[String:Any] { [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:"link"] }
    static func load() throws -> LinkTokens? {
        var q=query; q[kSecReturnData as String]=true; q[kSecMatchLimit as String]=kSecMatchLimitOne
        var result:CFTypeRef?
        let status=SecItemCopyMatching(q as CFDictionary,&result)
        if status==errSecItemNotFound { return nil }
        guard status==errSecSuccess,let data=result as? Data else { throw LinkError(message:"无法读取 Keychain 登录凭证（\(status)）") }
        return try JSONDecoder().decode(LinkTokens.self,from:data)
    }
    static func delete() throws {
        let status=SecItemDelete(query as CFDictionary)
        guard status==errSecSuccess || status==errSecItemNotFound else {throw LinkError(message:"无法清除 Keychain 登录凭证（\(status)）")}
    }
    static func save(_ tokens:LinkTokens) throws {
        let data=try JSONEncoder().encode(tokens)
        let attrs=[kSecValueData as String:data]
        var status=SecItemUpdate(query as CFDictionary,attrs as CFDictionary)
        if status==errSecItemNotFound {
            var q=query; q[kSecValueData as String]=data; q[kSecAttrAccessible as String]=kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status=SecItemAdd(q as CFDictionary,nil)
        }
        guard status==errSecSuccess else { throw LinkError(message:"无法保存 Keychain 登录凭证（\(status)）") }
    }
}
final class NoRedirect:NSObject,URLSessionTaskDelegate {
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping (URLRequest?)->Void) { completionHandler(nil) }
}
actor NativeLink {
    static let shared=NativeLink()
    private let session:URLSession
    private var tokens:LinkTokens?
    private var ownsSession=false
    private var sessionRevoked=false
    private var sessionGeneration=0
    private static let signedOutKey="linkCardExplicitlySignedOut"
    private let persistTokens:Bool
    private var refreshTask:Task<LinkTokens,Error>?
    private let clientID="lwlpk_U7Qy7ThG69STZk" // Public device-flow client from Stripe's MIT-licensed Link CLI.
    init(session:URLSession?=nil,testTokens:LinkTokens?=nil,persistTokens:Bool=true) {
        self.persistTokens=persistTokens
        if let session=session { self.session=session }
        else {
            let config=URLSessionConfiguration.ephemeral
            config.urlCache=nil; config.httpCookieStorage=nil; config.timeoutIntervalForRequest=30
            self.session=URLSession(configuration:config,delegate:NoRedirect(),delegateQueue:nil)
        }
        self.tokens=testTokens
    }
    private func readTokens() throws -> LinkTokens {
        guard !sessionRevoked && !(persistTokens && UserDefaults.standard.bool(forKey:Self.signedOutKey)) else {throw LinkError(message:"Link 登录授权已失效，请重新登录。",requiresLogin:true)}
        if let tokens=tokens { return tokens }
        if let saved=try TokenStore.load() { tokens=saved; ownsSession=true; return saved }
        // Read-only compatibility: never rotate or write the CLI's shared refresh token.
        let file=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/link-cli-nodejs/config.json")
        if let data=try? Data(contentsOf:file),let obj=try? JSONSerialization.jsonObject(with:data) as? [String:Any],let auth=obj["auth"] as? [String:Any],let access=auth["access_token"] as? String {
            let expiry=auth["expires_at"] as? Double
            if let expiry=expiry,expiry > Date().timeIntervalSince1970*1000+60000 {
                let imported=LinkTokens(access_token:access,refresh_token:nil,expires_at:expiry)
                tokens=imported; return imported
            }
        }
        throw LinkError(message:"请点击「登录 Link」在浏览器授权，无需安装 CLI。",requiresLogin:true)
    }
    private func accessToken(force:Bool=false) async throws -> String {
        let current=try readTokens()
        if !force && (current.expires_at ?? 0)>Date().timeIntervalSince1970*1000+60000 { return current.access_token }
        guard let refresh=current.refresh_token else { throw LinkError(message:"现有登录已过期。请点击「登录 Link」建立独立 App 登录。",requiresLogin:true) }
        if let task=refreshTask { return try await task.value.access_token }
        let generation=sessionGeneration
        let task=Task<LinkTokens,Error> {
            let (status,data)=try await self.form("/device/token",["grant_type":"refresh_token","refresh_token":refresh,"client_id":self.clientID])
            guard (200..<300).contains(status) else { throw self.error(status,data) }
            return try self.decodeTokens(data,previousRefresh:refresh)
        }
        refreshTask=task
        defer { refreshTask=nil }
        let renewed:LinkTokens
        do {renewed=try await task.value}
        catch {
            if (error as? LinkError)?.requiresLogin == true {sessionRevoked=true;tokens=nil}
            throw error
        }
        guard generation==sessionGeneration && !sessionRevoked else {throw CancellationError()}
        if ownsSession && persistTokens { try TokenStore.save(renewed) }
        tokens=renewed; return renewed.access_token
    }
    private func decodeTokens(_ data:[String:Any],previousRefresh:String?=nil) throws -> LinkTokens {
        guard let token=data["access_token"] as? String,!token.isEmpty else { throw LinkError(message:"Link 未返回登录凭证") }
        let ttl=data["expires_in"] as? Double ?? 3600
        return LinkTokens(access_token:token,refresh_token:data["refresh_token"] as? String ?? previousRefresh,expires_in:ttl,expires_at:Date().timeIntervalSince1970*1000+ttl*1000)
    }
    private func error(_ status:Int,_ data:[String:Any]) -> LinkError {
        let nested=data["error"] as? [String:Any] ?? [:]
        let message=data["error_description"] as? String ?? nested["message"] as? String ?? data["message"] as? String ?? data["error"] as? String ?? "请求失败"
        let code=data["error"] as? String ?? nested["code"] as? String ?? ""
        let lower=message.lowercased()
        let revokedRefresh=(status==400 || status==401) && lower.contains("refresh_token") && (lower.contains("not active") || lower.contains("revoked"))
        let needsLogin=status==401 || ["invalid_grant","invalid_token","expired_token"].contains(code) || revokedRefresh
        let guidance=revokedRefresh ? "\nLink 登录授权已失效，请重新登录。" : ""
        return LinkError(message:"Link HTTP \(status): \(message)"+guidance,requiresLogin:needsLogin)
    }
    private func form(_ path:String,_ fields:[String:String]) async throws -> (Int,[String:Any]) {
        var request=URLRequest(url:URL(string:"https://login.link.com"+path)!)
        request.httpMethod="POST";request.setValue("application/x-www-form-urlencoded",forHTTPHeaderField:"Content-Type")
        let allowed=CharacterSet.alphanumerics.union(CharacterSet(charactersIn:"-._~"))
        request.httpBody=fields.sorted{$0.key<$1.key}.map{($0.key.addingPercentEncoding(withAllowedCharacters:allowed) ?? "")+"="+($0.value.addingPercentEncoding(withAllowedCharacters:allowed) ?? "")}.joined(separator:"&").data(using:.utf8)
        let (data,response)=try await session.data(for:request)
        guard let http=response as? HTTPURLResponse,let json=try JSONSerialization.jsonObject(with:data) as? [String:Any] else { throw LinkError(message:"Link 登录返回无效数据") }
        return (http.statusCode,json)
    }
    func beginLogin() async throws -> DeviceLogin {
        let (status,data)=try await form("/device/code",["client_id":clientID,"scope":"userinfo:read payment_methods.agentic","connection_label":"Link Card","client_hint":"Link Card"])
        guard (200..<300).contains(status) else { throw error(status,data) }
        guard let code=data["device_code"] as? String,let phrase=data["user_code"] as? String,let value=(data["verification_uri_complete"] ?? data["verification_uri"]) as? String,let url=URL(string:value),url.scheme=="https",["app.link.com","login.link.com","link.com"].contains(url.host ?? "") else { throw LinkError(message:"Link 授权信息无效") }
        return DeviceLogin(deviceCode:code,phrase:phrase,url:url,interval:max(1,data["interval"] as? Double ?? 5),expires:Date().addingTimeInterval(data["expires_in"] as? Double ?? 600))
    }
    func finishLogin(_ login:DeviceLogin) async throws -> Bool {
        let generation=sessionGeneration
        let (status,data)=try await form("/device/token",["grant_type":"urn:ietf:params:oauth:grant-type:device_code","device_code":login.deviceCode,"client_id":clientID])
        if status==400,let code=data["error"] as? String {
            if code=="authorization_pending" { return false }
            if code=="slow_down" { throw LoginSlowDown() }
        }
        guard (200..<300).contains(status) else { throw error(status,data) }
        guard generation==sessionGeneration else {throw CancellationError()}
        let saved=try decodeTokens(data)
        if persistTokens {try TokenStore.save(saved);UserDefaults.standard.set(false,forKey:Self.signedOutKey)}
        tokens=saved;ownsSession=true;sessionRevoked=false;return true
    }
    func request(_ path:String,method:String="GET",body:[String:Any]?=nil,retry:Bool=true) async throws -> Any {
        let token=try await accessToken()
        var request=URLRequest(url:URL(string:"https://api.link.com"+path)!)
        request.httpMethod=method;request.setValue("Bearer "+token,forHTTPHeaderField:"Authorization")
        if let body=body { request.httpBody=try JSONSerialization.data(withJSONObject:body);request.setValue("application/json",forHTTPHeaderField:"Content-Type") }
        let (data,response)=try await session.data(for:request)
        guard let http=response as? HTTPURLResponse else { throw LinkError(message:"Link 返回无效响应") }
        if http.statusCode==401 && retry {
            _ = try await accessToken(force:true)
            return try await self.request(path,method:method,body:body,retry:false)
        }
        let json=(try? JSONSerialization.jsonObject(with:data)) ?? [:]
        guard (200..<300).contains(http.statusCode) else { throw error(http.statusCode,json as? [String:Any] ?? [:]) }
        return json
    }
    func logout() throws {
        if persistTokens {
            try TokenStore.delete()
            // Do not silently re-import the CLI login after an explicit app logout.
            UserDefaults.standard.set(true,forKey:Self.signedOutKey)
        }
        sessionGeneration += 1
        refreshTask?.cancel();refreshTask=nil
        tokens=nil;ownsSession=false;sessionRevoked=true
    }
    func hasSession()->Bool { (try? readTokens()) != nil }
    func userInfo() async throws -> [String:Any] {
        guard let profile=try await request("/userinfo") as? [String:Any] else {throw LinkError(message:"账户信息响应无效。")}
        return profile
    }
    func list(history:Bool) async throws -> Any { try await request("/spend_requests"+(history ? "?include_history=true" : "")) }
    func methods() async throws -> Any { try await request("/payment-details") }
    func retrieve(_ id:String,card:Bool=false) async throws -> Any { try await request("/spend_requests/"+(try safeID(id))+(card ? "?include=card" : "")) }
    func requestApproval(_ id:String) async throws -> Any { try await request("/spend_requests/"+(try safeID(id))+"/request_approval",method:"POST") }
    func cancel(_ id:String) async throws -> Any { try await request("/spend_requests/"+(try safeID(id))+"/cancel",method:"POST") }
    private func safeID(_ id:String) throws -> String {
        guard id.hasPrefix("lsrq_"),id.allSatisfy({$0.isASCII && ($0.isLetter || $0.isNumber || $0=="_")}) else { throw LinkError(message:"无效的 spend request ID") };return id
    }
    func create(_ body:[String:Any]) async throws -> Any { try await request("/spend_requests",method:"POST",body:body) }
}
