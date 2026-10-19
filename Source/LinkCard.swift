import AppKit
import SwiftUI
import Combine

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
    var context:String { Model.purchaseContext(merchant:merchant,url:url,amount:amount,currency:currency,item:item) }
    @State var validUntil=Date().addingTimeInterval(86400)
    @State var confirmCreate = false
    @State var toCancel:RequestItem?
    var body: some View {
        ScrollView { VStack(alignment:.leading,spacing:20) {
            HStack(spacing:12) { Image(systemName:"creditcard.fill").foregroundStyle(.cyan); Text("Link Card").font(.title2.bold()); Spacer(); Picker("Language / 语言",selection:$model.language) { Text("中文").tag(AppLanguage.chinese); Text("English").tag(AppLanguage.english) }.pickerStyle(.segmented).labelsHidden().frame(width:145) }
            HStack(spacing:12) { if model.busy { ProgressView().controlSize(.small) }; if model.checkingAccount {
                ProgressView().controlSize(.small).help(t("正在检查登录…"))
            } else if model.isSignedIn {
                HStack(spacing:6) {
                    Image(systemName:"checkmark.circle.fill").foregroundStyle(.green)
                    VStack(alignment:.leading,spacing:2) {
                        Text(t("已登录")).font(.caption).foregroundStyle(.secondary)
                        if let account=model.account {
                            if !account.name.isEmpty {Text(account.name).font(.callout).lineLimit(1)}
                            if !account.email.isEmpty {Text(account.email).font(.caption).foregroundStyle(.secondary).lineLimit(1)}
                        }
                    }
                }.frame(maxWidth:200,alignment:.leading).help([model.account?.name,model.account?.email].compactMap{$0}.filter{!$0.isEmpty}.joined(separator:"\n"))
            } else { Button(t("登录 Link")) { model.login() }.disabled(model.loggingIn) }; Spacer(); Button(t("清除卡信息")) { model.detail=[] }.disabled(model.detail.isEmpty) }
            Picker("",selection:$tab) { Text(t("请求 / 历史")).tag(0); Text(t("创建 Generate")).tag(1); Text(t("待批准")).tag(2) }.pickerStyle(.segmented)
            if tab == 0 || tab == 2 {
                HStack { if tab == 0 { Toggle(t("包含历史"),isOn:$model.history).onChange(of:model.history) { _ in model.load() } }; Spacer(); Button(t("刷新列表")) { model.load() } }.disabled(model.busy)
                List(selection:$selected) { ForEach(tab == 2 ? model.requests.filter(\.needsApproval) : model.requests) { r in
                    HStack { VStack(alignment:.leading) { Text(r.merchant.isEmpty ? t("Unknown merchant") : r.merchant).font(.headline); Text(r.id).font(.system(.caption,design:.monospaced)).lineLimit(1).truncationMode(.middle); Text("\(str(r.raw,"amount")) \(str(r.raw,"currency").uppercased()) \(t("最小单位"))").font(.caption) }; Spacer(); Text(L10n.status(r.status,language:model.language)).foregroundStyle(r.status == "approved" ? .green : .secondary); Button(t("取消请求"),role:.destructive) {toCancel=r}.buttonStyle(.borderless).disabled(model.busy || !r.canCancel) }.tag(r.id)
                } }.frame(minHeight:145,maxHeight:220)
                if tab == 2 {
                    Text(t("选择请求查看详情，批准操作将在 Link 中完成。")).font(.caption).foregroundStyle(.secondary)
                    if model.requests.filter(\.needsApproval).isEmpty {Text(t("没有待批准的请求。")).foregroundStyle(.secondary)}
                    if let request=model.requests.first(where:{$0.id==selected}),request.needsApproval {
                        VStack(alignment:.leading,spacing:8) {
                            Text(str(request.raw,"merchant_url")).textSelection(.enabled)
                            Text(str(request.raw,"context")).font(.callout).textSelection(.enabled)
                            if let link=request.approvalLink {Link(t("在 Link 中批准请求 ↗"),destination:link).buttonStyle(.borderedProminent)}
                            else {Button(t("获取批准链接")) {model.show(request.id)}}
                        }.padding().frame(maxWidth:.infinity,alignment:.leading).background(.quaternary.opacity(0.3)).clipShape(RoundedRectangle(cornerRadius:10))
                    }
                }
                HStack { Button(t(tab == 2 ? "查看请求" : "显示卡信息 Show")) { if let id=selected { model.show(id) } }; Button(t("取消请求 Cancel"),role:.destructive) { toCancel=model.requests.first{$0.id==selected} }.disabled(model.requests.first{$0.id==selected}?.canCancel != true) }.disabled(selected == nil || model.busy)
            } else {
                VStack(alignment:.leading,spacing:20) {
                    HStack {
                        Label(t("付款方式"),systemImage:"wallet.pass").font(.headline)
                        Spacer()
                        Button(t("加载")) { model.loadMethods() }
                    }
                    Picker(t("付款方式"),selection:$payment) {
                        Text(t("选择或填写下方 ID")).tag("")
                        ForEach(model.methods.indices,id:\.self) { i in
                            let d=model.methods[i]
                            Text("\(find(d,["brand"])) …\(find(d,["last4"]))").tag(str(d,"id"))
                        }
                    }.labelsHidden().frame(maxWidth:.infinity).clipped()
                    field("付款方式 ID",text:$payment)
                    Divider()
                    Label(t("商品"),systemImage:"bag").font(.headline)
                    LazyVGrid(columns:[GridItem(.adaptive(minimum:260),spacing:18)],alignment:.leading,spacing:18) {
                        field("商家名称",text:$merchant)
                        field("商家 URL",text:$url)
                        field("金额（最小单位，如 $15 = 1500）",text:$amount)
                        field("币种",text:$currency)
                    }
                    field("商品（数量 1）",text:$item)
                    Divider()
                    VStack(alignment:.leading,spacing:10) {
                        Text(t("可用截止时间")).font(.subheadline.weight(.medium))
                        ViewThatFits(in:.horizontal) {
                            HStack { expiryPicker; Button(t("一天以后")) {validUntil=Date().addingTimeInterval(86400)} }
                            VStack(alignment:.leading,spacing:10) { expiryPicker; Button(t("一天以后")) {validUntil=Date().addingTimeInterval(86400)} }
                        }
                        Text(t("默认一天以后；这是请求到期时间，卡片实际可用时间以 Link 返回为准。")).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                    }
                    VStack(alignment:.leading,spacing:8) {
                        Text(t("用途说明（自动生成）")).font(.subheadline.weight(.medium))
                        Text(context).font(.callout).foregroundStyle(.secondary).textSelection(.enabled).fixedSize(horizontal:false,vertical:true)
                    }
                    HStack { Spacer(); Button(t("检查并创建请求…")) { confirmCreate=true }.buttonStyle(.borderedProminent).controlSize(.large).disabled(model.busy || payment.isEmpty || amount.isEmpty || merchant.isEmpty || item.isEmpty) }
                }.padding(22).background(Color(nsColor:.controlBackgroundColor)).clipShape(RoundedRectangle(cornerRadius:16)).overlay(RoundedRectangle(cornerRadius:16).stroke(Color.primary.opacity(0.07)))
            }
            if let loginURL=model.loginURL {
                HStack { Link(t("打开 Link 登录授权 ↗"),destination:loginURL); Text(model.loginPhrase).font(.system(.body,design:.monospaced)).textSelection(.enabled); Button(t("停止等待")) {model.loginTask?.cancel()} }
            }
            if !model.approvalURL.isEmpty, let u=URL(string:model.approvalURL), u.scheme == "https", u.host == "app.link.com" {
                HStack { Link(t("在 Link 中批准请求 ↗"),destination:u).buttonStyle(.borderedProminent); if !model.pendingID.isEmpty { Button(t("已批准，刷新卡信息")) { model.show(model.pendingID) }.disabled(model.busy) } }
            }
            if !model.detail.isEmpty {
                ScrollView { Grid(alignment:.leading,horizontalSpacing:16,verticalSpacing:9) { ForEach(model.detail.indices,id:\.self) { i in
                    GridRow { Text(t(model.detail[i].0)).foregroundStyle(.cyan).frame(width:145,alignment:.leading); Text(model.detail[i].0 == "Status" ? L10n.status(model.detail[i].1,language:model.language) : display(model.detail[i].1)).font(.system(.body,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) }; Divider()
                } }.padding(10) }.frame(height:300).background(.quaternary.opacity(0.3)).clipShape(RoundedRectangle(cornerRadius:8))
            }
            if !model.message.isEmpty { ScrollView { Text(t(model.message)).font(.caption).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) }.frame(maxHeight:90) }
            Text(t("原生直连 Link API，无需 CLI。登录存入 Keychain；卡信息仅保留在内存。关闭窗口会清除显示。")).font(.caption2).foregroundStyle(.secondary)
            HStack(spacing:6) {
                Button("Apache License 2.0") {
                    if let licenseURL=Bundle.main.url(forResource:"LICENSE",withExtension:nil) {
                        NSWorkspace.shared.open(licenseURL)
                    } else if let licenseURL=URL(string:"https://www.apache.org/licenses/LICENSE-2.0") {
                        NSWorkspace.shared.open(licenseURL)
                    }
                }.buttonStyle(.link).help(t("查看完整许可证"))
            }.font(.caption2)

        }.padding(24).frame(maxWidth:1000).frame(maxWidth:.infinity) }.background(Color(nsColor:.windowBackgroundColor)).frame(minWidth:520,minHeight:480)
        .onChange(of:model.lastCreatedID) {selected=$0;tab=2}
        .onChange(of:tab) { value in if value == 2 {model.load()} }
        .environment(\.locale,model.language.locale)
        .alert(t("创建付款请求？"),isPresented:$confirmCreate) { Button(t("返回"),role:.cancel){}; Button(t("创建并请求批准")) { model.create(payment:payment,merchant:merchant,url:url,amount:amount,currency:currency,item:item,context:context,validUntil:validUntil); tab=2 } } message: { Text(createSummary) }
        .alert(t("取消这个请求？"),isPresented:Binding(get:{toCancel != nil},set:{if !$0 {toCancel=nil}})) { Button(t("返回"),role:.cancel){toCancel=nil}; Button(t("取消请求"),role:.destructive){if let r=toCancel {model.cancel(r)};toCancel=nil} } message:{Text("\(toCancel?.merchant ?? "")\n\(toCancel?.id ?? "")\n\(t("这不会撤销已完成的付款。"))")}
    }
    var expiryPicker:some View {
        DatePicker(t("可用截止时间"),selection:$validUntil,in:Date()...,displayedComponents:[.date,.hourAndMinute]).labelsHidden()
    }
    func field(_ title:String,text:Binding<String>)->some View {
        VStack(alignment:.leading,spacing:7) {
            Text(t(title)).font(.subheadline.weight(.medium)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            TextField("",text:text).textFieldStyle(.roundedBorder).controlSize(.large).frame(maxWidth:.infinity).accessibilityLabel(t(title))
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
    func t(_ key:String)->String { L10n.text(key,language:model.language) }
    var createSummary:String { "\(merchant)\n\(url)\n\(t("金额")): \(amount) \(currency.uppercased()) \(t("最小单位"))\n\(t("商品")): \(item)\n\(t("可用截止时间")): \(validUntil.formatted(Date.FormatStyle(date:.abbreviated,time:.shortened).locale(model.language.locale)))\n\(context)\n\(t("创建后仍需要在 Link 中批准。"))" }
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
        window.minSize=NSSize(width:540,height:520);window.title="Link Card";window.isReleasedWhenClosed=false;window.delegate=self;window.contentView=NSHostingView(rootView:ContentView(model:model));window.center();openWindow();model.start()
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
