import Foundation
import Combine

struct RequestItem: Identifiable {
    let raw: [String:Any]
    var id:String { str(raw,"id") }
    var merchant:String { str(raw,"merchant_name") }
    var status:String { str(raw,"status") }
}
@MainActor final class Model: ObservableObject {
    let api:NativeLink
    @Published var language:AppLanguage=L10n.selected { didSet { UserDefaults.standard.set(language.rawValue,forKey:L10n.preferenceKey) } }
    init(api:NativeLink = .shared) { self.api=api }
    @Published var isSignedIn=false
    @Published var checkingAccount=true
    @Published var account:SignedInAccount?
    func start() {
        Task { await refreshAccount(); if isSignedIn { load() } }
    }
    func refreshAccount() async {
        checkingAccount=true
        defer { checkingAccount=false }
        isSignedIn=await api.hasSession()
        guard isSignedIn else { account=nil;return }
        do {
            account=SignedInAccount(try await api.userInfo())
            isSignedIn=true
        } catch {
            handle(error)
            if isSignedIn { message="已登录，暂时无法加载账户信息。" }
        }
    }
    func handle(_ error:Error) {
        if (error as? LinkError)?.requiresLogin == true {
            isSignedIn=false;account=nil;detail=[];methods=[];requests=[]
            approvalWatch?.cancel();pendingID="";approvalURL=""
        }
        message=error.localizedDescription
    }
    @Published var loginURL:URL?
    @Published var loginPhrase=""
    @Published var loggingIn=false
    var loginTask:Task<Void,Never>?
    func login() {
        guard !loggingIn else { return }
        loggingIn=true;message="";loginURL=nil;loginPhrase=""
        approvalWatch?.cancel();detail=[];requests=[];approvalURL="";pendingID=""
        loginTask=Task {
            defer { self.loggingIn=false }
            do {
                let flow=try await api.beginLogin()
                self.loginURL=flow.url;self.loginPhrase=flow.phrase
                self.message="打开登录链接，在 Link 中输入授权短语。"
                var interval=flow.interval
                while Date()<flow.expires {
                    try await Task.sleep(nanoseconds:UInt64(interval*1_000_000_000))
                    guard !Task.isCancelled else { return }
                    do {
                        if try await api.finishLogin(flow) {
                            self.loginURL=nil;self.loginPhrase="";self.isSignedIn=true;self.message="Link 登录成功。";await self.refreshAccount();if self.isSignedIn {self.load()};return
                        }
                    } catch is LoginSlowDown { interval += 5 }
                }
                self.message="登录链接已过期，请重新登录。"
            } catch is CancellationError { self.message="已停止等待登录。" }
            catch { self.handle(error) }
        }
    }

    @Published var requests:[RequestItem] = []
    @Published var methods:[[String:Any]] = []
    @Published var busy = false
    @Published var message = ""
    @Published var history = false
    @Published var detail:[(String,String)] = []
    @Published var approvalURL = ""
    @Published var pendingID = ""
    var approvalWatch: Task<Void,Never>?
    func watchApproval(_ id:String) {
        approvalWatch?.cancel()
        approvalWatch = Task {
            for _ in 0..<300 {
                do {
                    try await Task.sleep(nanoseconds:2_000_000_000)
                    if Task.isCancelled { return }
                    let result = try await self.api.retrieve(id)
                    guard !Task.isCancelled else { return }
                    let request = objects(result).first(where:{str($0,"id")==id}) ?? [:]
                    let status = str(request,"status")
                    if status == "approved" {
                        while self.busy { try await Task.sleep(nanoseconds:200_000_000) }
                        guard !Task.isCancelled else { return }
                        self.show(id); return
                    }
                    if !["created","pending_approval","requires_action"].contains(status) {
                        self.pendingID=""; self.message="请求状态："+status; return
                    }
                } catch is CancellationError { return }
                catch { self.handle(error); self.message="自动刷新停止："+error.localizedDescription; return }
            }
            self.message="自动等待已结束；可手动刷新卡信息。"
        }
    }
    func perform(_ action: @escaping () async throws -> Void) {
        guard !busy else { return }; busy = true; message = ""
        Task { do { try await action() } catch { handle(error) }; busy = false }
    }
    func load() { perform {
        let result = try await self.api.list(history:self.history)
        var seen = Set<String>()
        self.requests = objects(result).filter { str($0,"id").hasPrefix("lsrq_") && seen.insert(str($0,"id")).inserted }.map { RequestItem(raw:$0) }
        if self.requests.isEmpty { self.message = self.history ? "没有历史请求。" : "没有活跃请求；可打开包含历史，或创建新请求。" }
    } }
    func loadMethods() { perform {
        let result = try await self.api.methods()
        var seen = Set<String>()
        self.methods = objects(result).filter { let id = str($0,"id"); return (id.hasPrefix("csmrpd_") || id.hasPrefix("pm_")) && seen.insert(id).inserted }
        if self.methods.isEmpty { self.message = "没有找到付款方式；可手动填写付款方式 ID。" }
    } }
    func cancel(_ item:RequestItem) { perform {
        _ = try await self.api.cancel(item.id)
        if self.pendingID == item.id { self.approvalWatch?.cancel(); self.pendingID=""; self.approvalURL="" }
        self.message = "已取消请求 \(item.id)。取消请求不等于退款。"
        self.requests = self.requests.map { r in if r.id == item.id { var d = r.raw; d["status"] = "canceled"; return RequestItem(raw:d) }; return r }
    } }
    func show(_ id:String, fallback:[String:Any] = [:]) { perform { try await self.retrieve(id,fallback:fallback) } }
    func retrieve(_ id:String, fallback:[String:Any] = [:]) async throws {
        let result = try await self.api.retrieve(id,card:true)
        let request = objects(result).first(where:{str($0,"id")==id}) ?? fallback
        let card:Any = request["card"] ?? [:]
        let month = find(card,["exp_month","expiry_month","expiration_month"])
        let year = find(card,["exp_year","expiry_year","expiration_year"])
        let address = objects(card).compactMap { $0["billing_address"] ?? ($0["billing_details"] as? [String:Any])?["address"] }.first
        let billing:String
        if let d = address as? [String:Any] { billing = ["name","line1","line_1","line2","line_2","city","locality","state","administrative_area","postal_code","country"].compactMap { d[$0] as? String }.filter{ !$0.isEmpty }.joined(separator:", ") }
        else { billing = address.map{String(describing:$0)} ?? "" }
        self.detail = [("Spend request ID",id),("Status",str(request,"status")),("Merchant",str(request,"merchant_name")),("Merchant URL",str(request,"merchant_url")),("Context",str(request,"context")),("Created at",str(request,"created_at")),("Card number",find(card,["number","card_number","pan"])),("CVC",find(card,["cvc","cvv","security_code"])),("Brand",find(card,["brand","network"]).isEmpty ? str(request,"card_brand") : find(card,["brand","network"])),("Expiration",month.isEmpty ? find(card,["expiration_date","expiry"]) : month+"/"+year),("Billing address",billing),("Valid until",find(card,["valid_until","expires_at"]).isEmpty ? str(request,"expires_at") : find(card,["valid_until","expires_at"]))]
        self.approvalURL = str(request,"approval_url")
        self.pendingID = ["pending_approval","created","requires_action"].contains(str(request,"status")) ? id : ""
        if find(card,["number","card_number","pan"]).isEmpty { self.message = "暂无完整卡信息。若等待批准，请打开 Link 批准后点击刷新卡信息。" }
    }
    func create(payment:String,merchant:String,url:String,amount:String,currency:String,item:String,context:String) { perform {
        guard let cents = Int(amount), cents > 0, context.count >= 100, let u = URL(string:url), ["http","https"].contains(u.scheme ?? ""), !merchant.isEmpty, !payment.isEmpty, !item.contains(",") else { throw LinkError(message:"检查付款方式、商家 URL、正整数金额和至少 100 字符的用途；商品名不能包含逗号。") }
        let body:[String:Any] = ["idempotency_key":UUID().uuidString,"payment_details":payment,"credential_type":"card","merchant_name":merchant,"merchant_url":url,"amount":cents,"currency":currency,"context":context,"line_items":[["name":item,"unit_amount":cents,"quantity":1]],"totals":[["type":"total","display_text":"Total","amount":cents]],"request_approval":true]
        let result = try await self.api.create(body)
        guard let request = objects(result).first(where:{str($0,"id").hasPrefix("lsrq_")}) else { throw LinkError(message:"未返回 spend request ID") }
        let id = str(request,"id")
        self.requests.insert(RequestItem(raw:request),at:0)
        try await self.retrieve(id,fallback:request)
        if !self.pendingID.isEmpty { self.watchApproval(id) }
    } }
}
