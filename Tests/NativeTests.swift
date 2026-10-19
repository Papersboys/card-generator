import Foundation

final class MockProtocol:URLProtocol {
    static var calls:[URLRequest]=[]
    static var emptyList=false
    static var requestStatus="approved"
    static var force401=false
    static var pollCount=0
    static var profileUnavailable=false
    static var rejectCancel=false
    static var lastCreateBody:[String:Any]=[:]
    override class func canInit(with request:URLRequest)->Bool {true}
    override class func canonicalRequest(for request:URLRequest)->URLRequest {request}
    override func startLoading() {
        Self.calls.append(request)
        let path=request.url!.path
        if path=="/userinfo" && Self.profileUnavailable {
            client?.urlProtocol(self,didFailWithError:NSError(domain:NSURLErrorDomain,code:NSURLErrorNotConnectedToInternet));return
        }
        var status=200
        var payload:[String:Any]=[:]
        if path=="/device/code" {
            payload=["device_code":"mock_device","user_code":"MOCK PHRASE","verification_uri":"https://app.link.com/login","expires_in":600,"interval":1]
        } else if path=="/device/token" {
            payload=["access_token":"MOCK_NEW","refresh_token":"MOCK_REFRESH","expires_in":3600]
        } else if Self.force401 && request.value(forHTTPHeaderField:"Authorization")=="Bearer MOCK_OLD" {
            status=401;payload=["error":["message":"Expired"]]
        } else {
            precondition(request.value(forHTTPHeaderField:"Authorization")?.hasPrefix("Bearer MOCK_")==true)
            switch path {
            case "/userinfo":payload=["name":"Example User","email":"example@example.com"]
            case "/payment-details": payload=["payment_details":[["id":"csmrpd_mock","card_details":["brand":"visa","last4":"4242"]]]]
            case "/spend_requests":
                if request.httpMethod=="POST" {
                    var body=request.httpBody ?? Data()
                    if body.isEmpty,let stream=request.httpBodyStream {
                        stream.open();defer{stream.close()};var buffer=[UInt8](repeating:0,count:4096)
                        while true {let length=stream.read(&buffer,maxLength:buffer.count);if length<=0 {break};body.append(contentsOf:buffer.prefix(length))}
                    }
                    Self.lastCreateBody=(try? JSONSerialization.jsonObject(with:body)) as? [String:Any] ?? [:]
                    payload=["id":"lsrq_mock","status":Self.requestStatus,"approval_url":"https://app.link.com/activity/approve/lsrq_mock"]}
                else {payload=["data":Self.emptyList ? [] : [["id":"lsrq_mock","status":"approved"]]]}
            case "/spend_requests/lsrq_mock":payload=["id":"lsrq_mock","status":Self.requestStatus,"card":["number":"MOCK_NUMBER","cvc":"MOCK_CVC","exp_month":12,"exp_year":2030]]
            case "/spend_requests/lsrq_mock/cancel":payload=["id":"lsrq_mock","status":Self.rejectCancel ? "approved" : "canceled"]
            default:status=404;payload=["message":"Not found"]
            }
        }
        client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:status,httpVersion:nil,headerFields:["Content-Type":"application/json"])!,cacheStoragePolicy:.notAllowed)
        client?.urlProtocol(self,didLoad:try! JSONSerialization.data(withJSONObject:payload))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
@main struct Tests {
    @MainActor static func main() async throws {
        let generated=Model.purchaseContext(merchant:"Example Store",url:"https://example.com",amount:"200",currency:"jpy",item:"Lunch")
        precondition(generated.count>=100 && generated.contains("200 minor units in JPY") && generated.contains("Lunch") && generated.contains("Example Store"))
        precondition(RequestItem(raw:["status":"pending_approval","approval_url":"https://app.link.com/activity/approve/lsrq_mock"]).approvalLink != nil)
        precondition(RequestItem(raw:["status":"approved","approval_url":"https://app.link.com/activity/approve/lsrq_mock"]).approvalLink == nil)
        precondition(RequestItem(raw:["status":"pending_approval","approval_url":"https://example.com"]).approvalLink == nil)
        print("PASS: generated purchase context, pending approval filtering, and trusted approval links")
        let config=URLSessionConfiguration.ephemeral;config.protocolClasses=[MockProtocol.self]
        let api=NativeLink(session:URLSession(configuration:config),testTokens:LinkTokens(access_token:"MOCK_OLD",refresh_token:"MOCK_REFRESH",expires_at:Date().timeIntervalSince1970*1000+600000),persistTokens:false)
        let list=try await api.list(history:true)
        precondition(objects(list).contains{str($0,"id")=="lsrq_mock"})
        precondition(MockProtocol.calls.last!.url!.query=="include_history=true")
        _ = try await api.methods()
        let card=try await api.retrieve("lsrq_mock",card:true)
        precondition(find(card,["cvc"])=="MOCK_CVC")
        precondition(MockProtocol.calls.last!.url!.query=="include=card")
        _ = try await api.create(["payment_details":"csmrpd_mock","amount":1500,"request_approval":true,"idempotency_key":"mock_unique"])
        precondition(MockProtocol.calls.last!.httpMethod=="POST")
        _ = try await api.cancel("lsrq_mock")
        precondition(MockProtocol.calls.last!.url!.path.hasSuffix("/cancel"))
        let count=MockProtocol.calls.count
        do {_ = try await api.retrieve("lsrq_bad/other");fatalError("Invalid ID accepted")} catch {}
        precondition(MockProtocol.calls.count==count)
        MockProtocol.force401=true
        _ = try await api.methods()
        precondition(MockProtocol.calls.contains{$0.url!.path=="/device/token"})
        let login=try await api.beginLogin()
        precondition(login.phrase=="MOCK PHRASE")
        let loggedIn=try await api.finishLogin(login);precondition(loggedIn)
        let model=Model(api:api)
        await model.refreshAccount()
        precondition(model.isSignedIn && !model.checkingAccount)
        precondition(model.account?.name=="Example User" && model.account?.email=="example@example.com")
        // A temporary network error must not turn an existing session into a logged-out UI.
        MockProtocol.profileUnavailable=true
        await model.refreshAccount()
        precondition(model.isSignedIn && model.account?.email=="example@example.com")
        MockProtocol.profileUnavailable=false
        let expiredAPI=NativeLink(session:URLSession(configuration:config),testTokens:LinkTokens(access_token:"MOCK_OLD",refresh_token:nil,expires_at:Date().timeIntervalSince1970*1000+600000),persistTokens:false)
        let expiredModel=Model(api:expiredAPI)
        await expiredModel.refreshAccount()
        precondition(!expiredModel.isSignedIn && expiredModel.account==nil && !expiredModel.checkingAccount)
        // Successful device authorization loads the verified profile immediately.
        model.login()
        await model.loginTask?.value
        while model.busy { try await Task.sleep(nanoseconds:10_000_000) }
        precondition(model.isSignedIn && model.account?.email=="example@example.com" && !model.loggingIn)
        func idle(_ model:Model) async throws {while model.busy {try await Task.sleep(nanoseconds:10_000_000)}}
        let context=String(repeating:"Mock purchase details. ",count:8)
        let customExpiry=Date().addingTimeInterval(7200)
        model.create(payment:"csmrpd_mock",merchant:"Mock",url:"https://example.com",amount:"1500",currency:"usd",item:"Mock item",context:context,validUntil:customExpiry)
        try await idle(model)
        precondition(MockProtocol.lastCreateBody["expires_at"] as? Int==Int(customExpiry.timeIntervalSince1970))
        precondition(model.lastCreatedID=="lsrq_mock" && !model.detail.isEmpty)
        let beforeInvalid=MockProtocol.calls.count
        model.create(payment:"csmrpd_mock",merchant:"Mock",url:"https://example.com",amount:"1500",currency:"usd",item:"Mock item",context:context,validUntil:Date().addingTimeInterval(-60))
        try await idle(model)
        precondition(MockProtocol.calls.count==beforeInvalid)
        model.history=true
        MockProtocol.rejectCancel=true
        model.cancel(model.requests[0]);try await idle(model)
        precondition(model.requests[0].status != "canceled" && !model.detail.isEmpty)
        MockProtocol.rejectCancel=false
        model.cancel(model.requests[0]);try await idle(model)
        precondition(model.requests[0].status=="canceled" && model.detail.isEmpty)
        model.show("lsrq_mock");try await idle(model)
        precondition(model.detail.isEmpty)
        let fresh=Model(api:api)
        let beforeDefault=Date().timeIntervalSince1970
        fresh.create(payment:"csmrpd_mock",merchant:"Mock",url:"https://example.com",amount:"1500",currency:"usd",item:"Mock item",context:context)
        try await idle(fresh)
        let defaultExpiry=MockProtocol.lastCreateBody["expires_at"] as! Int
        precondition(abs(Double(defaultExpiry)-beforeDefault-86400)<2)
        fresh.cancel(fresh.requests[0]);try await idle(fresh)
        precondition(fresh.requests.isEmpty && fresh.detail.isEmpty)
        precondition(!RequestItem(raw:["status":"expired"]).canCancel)
        let delayed=Model(api:api)
        MockProtocol.emptyList=true;MockProtocol.requestStatus="pending_approval"
        delayed.create(payment:"csmrpd_mock",merchant:"Mock",url:"https://example.com",amount:"1500",currency:"usd",item:"Mock item",context:context)
        try await idle(delayed)
        precondition(delayed.requests.count==1 && delayed.requests[0].needsApproval && !delayed.approvalURL.isEmpty)
        precondition(delayed.message=="请求已创建，请在 Link 中批准。")
        delayed.approvalWatch?.cancel()
        delayed.load();try await idle(delayed)
        precondition(delayed.requests.count==1 && delayed.requests[0].needsApproval && delayed.requests[0].approvalLink != nil)
        precondition(!delayed.message.contains("没有活跃"))
        MockProtocol.requestStatus="approved"
        delayed.load();try await idle(delayed)
        precondition(delayed.requests.count==1 && delayed.requests[0].status=="approved")
        MockProtocol.requestStatus="expired"
        delayed.load();try await idle(delayed)
        precondition(delayed.requests.isEmpty)
        MockProtocol.emptyList=false;MockProtocol.requestStatus="approved"
        print("PASS: newly created requests survive list delay, preserve approval links, and reconcile terminal status")
        print("PASS: custom/default expiry seconds, past-date rejection, server-confirmed cancellation, credential cleanup, and active/history list behavior")
        let fallback=SignedInAccount(["first_name":"Example","last_name":"User"])
        precondition(fallback.name=="Example User" && fallback.email.isEmpty)
        precondition(L10n.text("已登录",language:.english)=="Logged in")
        print("PASS: verified account profile, offline session retention, expired login recovery, and post-login account loading")
        // Existing messages must re-render when the language changes, preserving request IDs.
        precondition(L10n.text("请求 / 历史",language:.english)=="Requests / History")
        precondition(L10n.text("Card number",language:.chinese)=="卡号")
        precondition(L10n.status("pending_approval",language:.english)=="Pending approval")
        precondition(L10n.status("pending_approval",language:.chinese)=="等待批准")
        let notice="已取消请求 lsrq_mock。"
        precondition(L10n.text(notice,language:.english)=="Canceled request lsrq_mock.")
        precondition(L10n.text(notice,language:.chinese)==notice)
        precondition(L10n.text("自动刷新停止：现有登录已过期。请点击「登录 Link」建立独立 App 登录。",language:.english).contains("Your existing login expired"))
        precondition(L10n.text("无法读取 Keychain 登录凭证（-1）",language:.english)=="Unable to read Keychain credentials (-1)")
        precondition(L10n.text("merchant supplied context",language:.english)=="merchant supplied context")
        print("PASS: English/Chinese controls, card labels, statuses, dynamic messages, and error localization")
        print("PASS: native list/history, methods, card retrieval, create/cancel routing, ID validation, 401 refresh, device login; no CLI and no real writes")
    }
}
