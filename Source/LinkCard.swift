import AppKit
import SwiftUI
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
                            self.loginURL=nil;self.loginPhrase="";self.message="Link 登录成功。";self.load();return
                        }
                    } catch is LoginSlowDown { interval += 5 }
                }
                self.message="登录链接已过期，请重新登录。"
            } catch is CancellationError { self.message="已停止等待登录。" }
            catch { self.message=error.localizedDescription }
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
                catch { self.message="自动刷新停止："+error.localizedDescription; return }
            }
            self.message="自动等待已结束；可手动刷新卡信息。"
        }
    }
    func perform(_ action: @escaping () async throws -> Void) {
        guard !busy else { return }; busy = true; message = ""
        Task { do { try await action() } catch { message = error.localizedDescription }; busy = false }
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
struct ContentView: View {
    @ObservedObject var model:Model
    @State var tab = 0
    @State var selected:String?
    @State var payment = ""
@State var merchant = ""
@State var url = ""
@State var amount = ""
@State var currency = "usd"
@State var item = ""
@State var context = ""
    @State var confirmCreate = false
    @State var toCancel:RequestItem?
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack { Image(systemName:"creditcard.fill").foregroundStyle(.cyan); Text("Link Card").font(.title2.bold()); Spacer(); Picker("Language / 语言",selection:$model.language) { Text("中文").tag(AppLanguage.chinese); Text("English").tag(AppLanguage.english) }.pickerStyle(.segmented).labelsHidden().frame(width:145); if model.busy { ProgressView().controlSize(.small) }; Button(t("登录 Link")) { model.login() }.disabled(model.loggingIn); Button(t("清除卡信息")) { model.detail=[] }.disabled(model.detail.isEmpty) }
            Picker("",selection:$tab) { Text(t("请求 / 历史")).tag(0); Text(t("创建 Generate")).tag(1) }.pickerStyle(.segmented)
            if tab == 0 {
                HStack { Toggle(t("包含历史"),isOn:$model.history).onChange(of:model.history) { _ in model.load() }; Spacer(); Button(t("刷新列表")) { model.load() } }.disabled(model.busy)
                List(selection:$selected) { ForEach(model.requests) { r in
                    HStack { VStack(alignment:.leading) { Text(r.merchant.isEmpty ? t("Unknown merchant") : r.merchant).font(.headline); Text(r.id).font(.system(.caption,design:.monospaced)); Text("\(str(r.raw,"amount")) \(str(r.raw,"currency").uppercased()) \(t("最小单位"))").font(.caption) }; Spacer(); Text(L10n.status(r.status,language:model.language)).foregroundStyle(r.status == "approved" ? .green : .secondary) }.tag(r.id)
                } }.frame(minHeight:145,maxHeight:220)
                HStack { Button(t("显示卡信息 Show")) { if let id=selected { model.show(id) } }; Button(t("取消请求 Cancel"),role:.destructive) { toCancel=model.requests.first{$0.id==selected} } }.disabled(selected == nil || model.busy)
            } else {
                ScrollView { Form {
                    HStack { Picker(t("付款方式"),selection:$payment) { Text(t("选择或填写下方 ID")).tag(""); ForEach(model.methods.indices,id:\.self) { i in let d=model.methods[i]; Text("\(find(d,["brand"])) …\(find(d,["last4"])) · \(str(d,"id"))").tag(str(d,"id")) } }; Button(t("加载")) { model.loadMethods() } }
                    TextField(t("付款方式 ID"),text:$payment)
                    TextField(t("商家名称"),text:$merchant); TextField(t("商家 URL"),text:$url)
                    HStack { TextField(t("金额（最小单位，如 $15 = 1500）"),text:$amount); TextField(t("币种"),text:$currency).frame(width:80) }
                    TextField(t("商品（数量 1）"),text:$item)
                    Text(t("用途 Context（至少 100 字符）")+" · \(context.count)/100").font(.caption)
                    TextEditor(text:$context).frame(height:65).border(.gray.opacity(0.3))
                    Button(t("检查并创建请求…")) { confirmCreate=true }.disabled(model.busy || context.count<100 || payment.isEmpty || amount.isEmpty || merchant.isEmpty || item.isEmpty)
                }.padding(4) }
            }
            if let loginURL=model.loginURL {
                HStack { Link(t("打开 Link 登录授权 ↗"),destination:loginURL); Text(model.loginPhrase).font(.system(.body,design:.monospaced)).textSelection(.enabled); Button(t("停止等待")) {model.loginTask?.cancel()} }
            }
            if !model.approvalURL.isEmpty, let u=URL(string:model.approvalURL), u.scheme == "https", u.host == "app.link.com" {
                HStack { Link(t("在 Link 中批准请求 ↗"),destination:u); if !model.pendingID.isEmpty { Button(t("已批准，刷新卡信息")) { model.show(model.pendingID) }.disabled(model.busy) } }
            }
            if !model.detail.isEmpty {
                ScrollView { Grid(alignment:.leading,horizontalSpacing:16,verticalSpacing:9) { ForEach(model.detail.indices,id:\.self) { i in
                    GridRow { Text(t(model.detail[i].0)).foregroundStyle(.cyan).frame(width:145,alignment:.leading); Text(model.detail[i].0 == "Status" ? L10n.status(model.detail[i].1,language:model.language) : display(model.detail[i].1)).font(.system(.body,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) }; Divider()
                } }.padding(10) }.frame(minHeight:200).background(.quaternary.opacity(0.3)).clipShape(RoundedRectangle(cornerRadius:8))
            }
            if !model.message.isEmpty { ScrollView { Text(t(model.message)).font(.caption).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) }.frame(maxHeight:90) }
            Text(t("原生直连 Link API，无需 CLI。登录存入 Keychain；卡信息仅保留在内存。关闭窗口会清除显示。取消请求不等于退款。")).font(.caption2).foregroundStyle(.secondary)
        }.padding(18).frame(minWidth:820,minHeight:650)
        .alert(t("创建付款请求？"),isPresented:$confirmCreate) { Button(t("返回"),role:.cancel){}; Button(t("创建并请求批准")) { model.create(payment:payment,merchant:merchant,url:url,amount:amount,currency:currency,item:item,context:context); tab=0 } } message: { Text(createSummary) }
        .alert(t("取消这个请求？"),isPresented:Binding(get:{toCancel != nil},set:{if !$0 {toCancel=nil}})) { Button(t("返回"),role:.cancel){toCancel=nil}; Button(t("取消请求"),role:.destructive){if let r=toCancel {model.cancel(r)};toCancel=nil} } message:{Text("\(toCancel?.merchant ?? "")\n\(toCancel?.id ?? "")\n\(t("这不会撤销已完成的付款。"))")}
    }
    func t(_ key:String)->String { L10n.text(key,language:model.language) }
    var createSummary:String { "\(merchant)\n\(url)\n\(t("金额")): \(amount) \(currency.uppercased()) \(t("最小单位"))\n\(t("商品")): \(item)\n\(context)\n\(t("创建后仍需要在 Link 中批准。"))" }
    func display(_ s:String)->String { if s.isEmpty {return "—"}; if let timestamp=Double(s),timestamp>1_000_000_000,timestamp<10_000_000_000 { return Date(timeIntervalSince1970:timestamp).formatted(Date.FormatStyle(date:.abbreviated,time:.standard).locale(model.language.locale)) }; return s }
}
@MainActor final class AppDelegate:NSObject,NSApplicationDelegate,NSWindowDelegate {
    let model=Model(); var status:NSStatusItem!; var window:NSWindow!
    var languageObserver:AnyCancellable?
    func applicationDidFinishLaunching(_ notification:Notification) {
        NSApp.setActivationPolicy(.accessory)
        status=NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
        status.button?.image=NSImage(systemSymbolName:"creditcard",accessibilityDescription:"Link Card")
        languageObserver=model.$language.sink { [weak self] language in self?.updateMenu(language) }
        window=NSWindow(contentRect:NSRect(x:0,y:0,width:900,height:820),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        window.title="Link Card";window.isReleasedWhenClosed=false;window.delegate=self;window.contentView=NSHostingView(rootView:ContentView(model:model));window.center();openWindow();model.load()
    }
    func updateMenu(_ language:AppLanguage) {
        let menu=NSMenu()
        menu.addItem(withTitle:L10n.text("打开 Link Card",language:language),action:#selector(openWindow),keyEquivalent:"")
        menu.addItem(withTitle:L10n.text("退出",language:language),action:#selector(quit),keyEquivalent:"q")
        for item in menu.items {item.target=self};status.menu=menu
    }
    @objc func openWindow(){window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)}
    @objc func quit(){NSApp.terminate(nil)}
    func windowWillClose(_ notification:Notification){model.approvalWatch?.cancel();model.detail=[];model.approvalURL=""}
}
@main struct LinkCardApp {
    @MainActor static func main() {
        let app=NSApplication.shared
        let delegate=AppDelegate()
        app.delegate=delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
