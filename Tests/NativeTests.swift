import Foundation

final class MockProtocol:URLProtocol {
    static var calls:[URLRequest]=[]
    static var revokeRefresh=false
    static var rejectCreate=false
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
            if Self.revokeRefresh {status=400;payload=["message":"refresh_token is not active: status: revoked"]}
            else {payload=["access_token":"MOCK_NEW","refresh_token":"MOCK_REFRESH","expires_in":3600]}
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
                    if Self.rejectCreate {status=400;payload=["error":["message":"Mock creation rejected"]]}
                    else {payload=["id":"lsrq_mock","status":Self.requestStatus,"approval_url":"https://app.link.com/activity/approve/lsrq_mock"]}}
                else {payload=["data":Self.emptyList ? [] : [["id":"lsrq_mock","status":"approved"]]]}
            case "/spend_requests/lsrq_mock":payload=["id":"lsrq_mock","status":Self.requestStatus,"card":["number":"MOCK_NUMBER","cvc":"MOCK_CVC","exp_month":12,"exp_year":2030]]
            case "/spend_requests/lsrq_mock/request_approval":
                precondition(request.httpMethod=="POST");Self.requestStatus="pending_approval";payload=["id":"lsrq_mock","approval_link":"https://app.link.com/activity/approve/lsrq_mock"]
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
        let report=ErrorReport(error:"Link HTTP 401: token SECRET user@example.com card 4242424242424242 cvc 123",version:"2.7.4")
        precondition(report.http_status==401 && report.category=="authorization")
        for value in ["SECRET","user@example.com","4242424242424242","cvc"] {precondition(!report.preview.contains(value))}
        let payload=try JSONSerialization.jsonObject(with:report.json) as! [String:Any]
        precondition(Set(payload.keys)==Set(["schema","app_version","os_version","category","http_status"]))
        print("PASS: report payload contains only allowlisted fields, no raw error text or credentials")
        let nicknameCard:[String:Any] = ["brand":"amex","last4":"1000"]
        precondition(paymentMethodLabel(["nickname":" Gold ","card_details":nicknameCard]) == "Gold · amex …1000")
        precondition(paymentMethodLabel(["nickname":NSNull(),"card_details":nicknameCard]) == "amex …1000")
        precondition(paymentMethodLabel(["nickname":"  ","card_details":nicknameCard]) == "amex …1000")
        precondition(paymentMethodLabel(["name":"Business Gold Card","card_details":nicknameCard]) == "Business Gold Card · amex …1000")
        precondition(paymentMethodLabel(["nickname":"Custom","name":"Business Gold Card","card_details":nicknameCard]) == "Custom · amex …1000")
        print("PASS: payment method nicknames, whitespace trimming, and missing nickname fallback")
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
        MockProtocol.revokeRefresh=true
        let revokedAPI=NativeLink(session:URLSession(configuration:config),testTokens:LinkTokens(access_token:"MOCK_OLD",refresh_token:"MOCK_REFRESH",expires_at:0),persistTokens:false)
        let revokedModel=Model(api:revokedAPI)
        revokedModel.requests=[RequestItem(raw:["id":"lsrq_mock","status":"approved"])]
        revokedModel.detail=[("CVC","MOCK_CVC")]
        await revokedModel.refreshAccount()
        precondition(!revokedModel.isSignedIn && revokedModel.account==nil && revokedModel.detail.isEmpty && revokedModel.requests.isEmpty)
        precondition(revokedModel.lastError.contains("revoked"))
        let hasRevokedSession=await revokedAPI.hasSession()
        precondition(!hasRevokedSession)
        MockProtocol.revokeRefresh=false
        revokedModel.login();await revokedModel.loginTask?.value
        while revokedModel.busy {try await Task.sleep(nanoseconds:10_000_000)}
        precondition(revokedModel.isSignedIn && revokedModel.account?.email=="example@example.com" && revokedModel.lastError.isEmpty)
        print("PASS: revoked refresh token restores login and fresh authorization recovers the session")
        // Successful device authorization loads the verified profile immediately.
        model.login()
        await model.loginTask?.value
        while model.busy { try await Task.sleep(nanoseconds:10_000_000) }
        precondition(model.isSignedIn && model.account?.email=="example@example.com" && !model.loggingIn)
        func idle(_ model:Model) async throws {while model.busy {try await Task.sleep(nanoseconds:10_000_000)}}
        let logoutModel=Model(api:revokedAPI)
        await logoutModel.refreshAccount()
        logoutModel.detail=[("CVC","MOCK_CVC")];logoutModel.requests=[RequestItem(raw:["id":"lsrq_mock","status":"approved"])]
        logoutModel.methods=[["id":"csmrpd_mock"]];logoutModel.pendingID="lsrq_mock";logoutModel.approvalURL="https://app.link.com/activity/approve/lsrq_mock"
        let beforeLogoutCalls=MockProtocol.calls.count
        logoutModel.logout();try await idle(logoutModel)
        precondition(!logoutModel.isSignedIn && logoutModel.account==nil && logoutModel.detail.isEmpty && logoutModel.requests.isEmpty && logoutModel.methods.isEmpty)
        precondition(logoutModel.pendingID.isEmpty && logoutModel.approvalURL.isEmpty && logoutModel.message=="已退出登录。")
        precondition(MockProtocol.calls.count==beforeLogoutCalls)
        let sessionAfterLogout=await revokedAPI.hasSession();precondition(!sessionAfterLogout)
        logoutModel.login();await logoutModel.loginTask?.value;try await idle(logoutModel)
        precondition(logoutModel.isSignedIn)
        print("PASS: logout clears local session and sensitive state without API mutations; fresh login works")
        let closedPanel=Model(api:api)
        closedPanel.requests=[RequestItem(raw:["id":"lsrq_mock","status":"approved"])]
        closedPanel.show("lsrq_mock");closedPanel.displayCredentials=false
        try await idle(closedPanel)
        precondition(closedPanel.detail.isEmpty && closedPanel.requests[0].raw["card"]==nil)
        closedPanel.displayCredentials=true
        closedPanel.show("lsrq_mock");try await idle(closedPanel)
        precondition(closedPanel.detail.contains{$0.0=="CVC" && $0.1=="MOCK_CVC"})
        precondition(closedPanel.requests[0].raw["card"]==nil)
        print("PASS: closed panel discards in-flight credentials, metadata stays card-free, reopening permits explicit retrieval")
        let context=String(repeating:"Mock purchase details. ",count:8)
        model.create(payment:"csmrpd_mock",merchant:"Mock",url:"https://example.com",amount:"1500",currency:"usd",item:"Mock item",context:context)
        try await idle(model)
        precondition(MockProtocol.lastCreateBody["expires_at"]==nil)
        precondition(model.lastCreatedID=="lsrq_mock" && !model.detail.isEmpty)
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
        fresh.create(payment:"csmrpd_mock",merchant:"Mock",url:"https://example.com",amount:"1500",currency:"usd",item:"Mock item",context:context)
        try await idle(fresh)
        precondition(MockProtocol.lastCreateBody["expires_at"]==nil)
        fresh.cancel(fresh.requests[0]);try await idle(fresh)
        precondition(fresh.requests.isEmpty && fresh.detail.isEmpty)
        precondition(!RequestItem(raw:["status":"expired"]).canCancel)
        let rejected=Model(api:api)
        MockProtocol.rejectCreate=true
        rejected.create(payment:"csmrpd_mock",merchant:"Mock",url:"https://example.com",amount:"1500",currency:"usd",item:"Mock item",context:context)
        try await idle(rejected)
        precondition(rejected.lastCreatedID==nil && rejected.requests.isEmpty && rejected.approvalURL.isEmpty)
        precondition(rejected.creationError?.contains("Mock creation rejected")==true)
        precondition(rejected.lastError.contains("Mock creation rejected"))
        let savedError=rejected.lastError
        rejected.load();try await idle(rejected)
        precondition(rejected.lastError==savedError)
        rejected.lastError=""
        precondition(rejected.lastError.isEmpty)
        MockProtocol.rejectCreate=false
        print("PASS: error banner state persists across refresh and can be dismissed")
        print("PASS: failed creation exposes server error and never signals a successful request")
        let needsApproval=Model(api:api)
        MockProtocol.requestStatus="created"
        needsApproval.create(payment:"csmrpd_mock",merchant:"Mock",url:"https://example.com",amount:"1500",currency:"usd",item:"Mock item",context:context)
        try await idle(needsApproval)
        precondition(needsApproval.requests.first?.status=="pending_approval")
        precondition(needsApproval.approvalURL=="https://app.link.com/activity/approve/lsrq_mock")
        precondition(MockProtocol.calls.contains{$0.url?.path.hasSuffix("/request_approval")==true})
        needsApproval.approvalWatch?.cancel()
        needsApproval.requests=[RequestItem(raw:["id":"lsrq_mock","status":"created"])]
        needsApproval.requestApproval("lsrq_mock");try await idle(needsApproval)
        precondition(needsApproval.requests.first?.approvalLink != nil)
        needsApproval.approvalWatch?.cancel()
        print("PASS: created requests explicitly request approval; approval_link is normalized; existing requests can recover approval links")
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
        print("PASS: creation omits unsupported expires_at, server-confirmed cancellation, credential cleanup, and active/history list behavior")
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
