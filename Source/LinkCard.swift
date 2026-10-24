import AppKit
import SwiftUI
import Combine
import Sparkle

struct ContentView: View {
    @ObservedObject var model:Model
    @ObservedObject var updates=UpdateManager.shared
    @State var tab = 0
    @State var selected:String?
    @State var payment = ""
@State var merchant = "Costco"
@State var url = "https://www.costco.com"
@State var amount = ""
@State var currency = "usd"
@State var item = ""
    var context:String { Model.purchaseContext(merchant:merchant,url:url,amount:amount,currency:currency,item:item) }
    @State var confirmCreate = false
    @State var toCancel:RequestItem?
    @State var copiedField:String?
    var body: some View {
        GeometryReader { geometry in
        VStack(spacing:0) {
        if !model.lastError.isEmpty {
            VStack(alignment:.leading,spacing:8) {
                HStack {
                    Label(t("操作失败"),systemImage:"exclamationmark.triangle.fill").foregroundStyle(.red).font(.headline)
                    Spacer()
                    Button(t("复制错误")) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(t(model.lastError),forType:.string)
                    }
                    Button {model.lastError="";model.creationError=nil} label: {Image(systemName:"xmark")}.buttonStyle(.plain).help(t("关闭错误提示"))
                }
                ScrollView {
                    Text(t(model.lastError)).font(.callout).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading).fixedSize(horizontal:false,vertical:true)
                }.frame(maxHeight:80)
            }.padding(14).background(Color.red.opacity(0.08)).overlay(RoundedRectangle(cornerRadius:10).stroke(Color.red.opacity(0.25))).clipShape(RoundedRectangle(cornerRadius:10)).padding(.horizontal,24).padding(.top,16)
        }
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
                Button(t("退出登录")) {model.logout()}.disabled(model.busy || model.checkingAccount || model.loggingIn)
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
                            else {Button(t("获取批准链接")) {model.requestApproval(request.id)}.disabled(model.busy)}
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
                            Text(paymentMethodLabel(d)).tag(str(d,"id"))
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
                ScrollView { Grid(alignment:.leading,horizontalSpacing:12,verticalSpacing:10) { ForEach(displayedDetails.indices,id:\.self) { i in
                    let field=displayedDetails[i]
                    GridRow {
                        Text(t(field.0)).foregroundStyle(.cyan).frame(width:112,alignment:.leading)
                        Text(field.0 == "Status" ? L10n.status(field.1,language:model.language) : display(field.1)).font(.system(.body,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading).fixedSize(horizontal:false,vertical:true)
                        if ["Card number","CVC","Expiration"].contains(field.0) {
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(field.1,forType:.string)
                                copiedField=field.0
                                Task {try? await Task.sleep(nanoseconds:2_000_000_000);if copiedField==field.0 {copiedField=nil}}
                            } label: {Label(t(copiedField==field.0 ? "已复制" : "复制"),systemImage:copiedField==field.0 ? "checkmark" : "doc.on.doc")}
                            .controlSize(.small).disabled(field.1.isEmpty || field.1=="—")
                            .accessibilityLabel(t("复制")+" "+t(field.0))
                        } else {Color.clear.frame(width:1,height:1)}
                    }; Divider()
                } }.padding(12) }.frame(height:300).background(.quaternary.opacity(0.3)).clipShape(RoundedRectangle(cornerRadius:8))
            }
            if !model.message.isEmpty { ScrollView { Text(t(model.message)).font(.caption).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) }.frame(maxHeight:90) }
            Text(t("原生直连 Link API，无需 CLI。登录存入 Keychain；卡信息仅保留在内存。关闭面板会清除显示。")).font(.caption2).foregroundStyle(.secondary)
            HStack(spacing:6) {
                Text("Link Card \(Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "")").foregroundStyle(.secondary)
                Text("·").foregroundStyle(.tertiary)
                Button("Apache License 2.0") {
                    if let licenseURL=Bundle.main.url(forResource:"LICENSE",withExtension:nil) {
                        NSWorkspace.shared.open(licenseURL)
                    } else if let licenseURL=URL(string:"https://www.apache.org/licenses/LICENSE-2.0") {
                        NSWorkspace.shared.open(licenseURL)
                    }
                }.buttonStyle(.link).help(t("查看完整许可证"))
                Spacer()
                Button(t("检查更新…")) {updates.check()}.disabled(!updates.canCheck)
            }.font(.caption2)
            HStack {
                Toggle(t("自动检查更新"),isOn:Binding(get:{updates.automaticChecks},set:{updates.setAutomaticChecks($0)})).toggleStyle(.checkbox).font(.caption)
                Spacer()
                Button(t("退出")) {NSApp.terminate(nil)}.buttonStyle(.link).font(.caption)
            }

        }.frame(width:min(1000,max(0,geometry.size.width-48))).padding(24).frame(maxWidth:.infinity) }
        }
        }.background(Color(nsColor:.windowBackgroundColor)).frame(minWidth:520,minHeight:480)
        .onChange(of:model.lastCreatedID) {selected=$0;tab=2}
        .onChange(of:model.detail.first(where:{$0.0=="Card number"})?.1) {_ in copiedField=nil}
        .onChange(of:tab) { value in if value == 2 {model.load()} }
        .environment(\.locale,model.language.locale)
        .alert(t("创建付款请求？"),isPresented:$confirmCreate) { Button(t("返回"),role:.cancel){}; Button(t("创建并请求批准")) { model.create(payment:payment,merchant:merchant,url:url,amount:amount,currency:currency,item:item,context:context) } } message: { Text(createSummary) }
        .alert(t("取消这个请求？"),isPresented:Binding(get:{toCancel != nil},set:{if !$0 {toCancel=nil}})) { Button(t("返回"),role:.cancel){toCancel=nil}; Button(t("取消请求"),role:.destructive){if let r=toCancel {model.cancel(r)};toCancel=nil} } message:{Text("\(toCancel?.merchant ?? "")\n\(toCancel?.id ?? "")\n\(t("这不会撤销已完成的付款。"))")}
    }
    var displayedDetails:[(String,String)] {
        let priority=["Card number","CVC","Expiration","Billing address","Brand","Valid until"]
        if model.detail.first(where:{$0.0=="Card number"})?.1.isEmpty != false {return model.detail.filter{!priority.contains($0.0)}}
        return priority.compactMap {key in model.detail.first{$0.0==key}} + model.detail.filter{!priority.contains($0.0)}
    }
    func placeholder(_ title:String)->String {
        switch title {
        case "付款方式 ID":return t("选择付款方式，或粘贴 ID")
        case "商家名称":return "Costco"
        case "商家 URL":return "https://www.costco.com"
        case "金额（最小单位，如 $15 = 1500）":return currency.lowercased()=="usd" ? t("例如 1500（$15.00 USD）") : t("填写该币种的最小单位金额")
        case "币种":return "usd"
        case "商品（数量 1）":return t("例如 Costco Shop Card")
        default:return ""
        }
    }
    func field(_ title:String,text:Binding<String>)->some View {
        VStack(alignment:.leading,spacing:7) {
            Text(t(title)).font(.subheadline.weight(.medium)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            TextField(placeholder(title),text:text).textFieldStyle(.roundedBorder).controlSize(.large).frame(maxWidth:.infinity).accessibilityLabel(t(title))
            if title == "金额（最小单位，如 $15 = 1500）",currency.lowercased()=="usd" {
                Text(t("USD 以美分填写：50 = $0.50（最低），1500 = $15.00。")).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            }
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
    func t(_ key:String)->String { L10n.text(key,language:model.language) }
    var createSummary:String { "\(merchant)\n\(url)\n\(t("金额")): \(amount) \(currency.uppercased()) \(t("最小单位"))\n\(t("商品")): \(item)\n\(context)\n\(t("创建后仍需要在 Link 中批准。"))" }
    func display(_ s:String)->String { if s.isEmpty {return "—"}; if let timestamp=Double(s),timestamp>1_000_000_000,timestamp<10_000_000_000 { return Date(timeIntervalSince1970:timestamp).formatted(Date.FormatStyle(date:.abbreviated,time:.standard).locale(model.language.locale)) }; return s }
}
@MainActor func installMainMenu(language:AppLanguage) {
    let main=NSMenu()
    let application=NSMenuItem()
    let applicationMenu=NSMenu(title:"Link Card")
    applicationMenu.addItem(withTitle:L10n.text("退出",language:language),action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
    application.submenu=applicationMenu
    main.addItem(application)
    let editItem=NSMenuItem()
    let edit=NSMenu(title:L10n.text("编辑",language:language))
    for (title,action,key,shift) in [
        ("撤销","undo:","z",false), ("重做","redo:","z",true),
        ("剪切","cut:","x",false), ("复制","copy:","c",false),
        ("粘贴","paste:","v",false), ("全选","selectAll:","a",false)
    ] {
        let item=NSMenuItem(title:L10n.text(title,language:language),action:Selector(action),keyEquivalent:key)
        item.keyEquivalentModifierMask=shift ? [.command,.shift] : [.command]
        // A nil target routes commands to the focused native field editor.
        item.target=nil
        edit.addItem(item)
    }
    editItem.submenu=edit
    main.addItem(editItem)
    NSApp.mainMenu=main
}
@MainActor final class AppDelegate:NSObject,NSApplicationDelegate,NSPopoverDelegate {
    let model:Model
    let startServices:Bool
    var status:NSStatusItem!
    let popover=NSPopover()
    var contextMenu=NSMenu()
    var languageObserver:AnyCancellable?
    var outsideClickMonitor:Any?
    var localClickMonitor:Any?
    init(model:Model?=nil,startServices:Bool=true) {
        self.model=model ?? Model();self.startServices=startServices;super.init()
    }
    func applicationDidFinishLaunching(_ notification:Notification) {
        NSApp.setActivationPolicy(.accessory)
        status=NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
        status.button?.image=NSImage(systemSymbolName:"creditcard",accessibilityDescription:"Link Card")
        status.button?.target=self;status.button?.action=#selector(togglePopover(_:))
        status.button?.sendAction(on:[.leftMouseUp,.rightMouseUp])
        popover.behavior = .transient
        popover.delegate=self
        popover.contentViewController=NSHostingController(rootView:ContentView(model:model))
        languageObserver=model.$language.sink {[weak self] language in self?.updateMenu(language)}
        model.displayCredentials=false
        if startServices {model.start();UpdateManager.shared.start()}
        else {openPopover()}
    }
    func updateMenu(_ language:AppLanguage) {
        installMainMenu(language:language)
        let menu=NSMenu()
        let open=NSMenuItem(title:L10n.text("打开 Link Card",language:language),action:#selector(openFromMenu),keyEquivalent:"")
        open.target=self;menu.addItem(open)
        let update=NSMenuItem(title:L10n.text("检查更新…",language:language),action:#selector(SPUStandardUpdaterController.checkForUpdates(_:)),keyEquivalent:"")
        update.target=UpdateManager.shared.controller;menu.addItem(update)
        let quit=NSMenuItem(title:L10n.text("退出",language:language),action:#selector(quit),keyEquivalent:"q")
        quit.target=self;menu.addItem(quit)
        contextMenu=menu
    }
    @objc func togglePopover(_ sender:Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp,let button=status.button {
            contextMenu.popUp(positioning:nil,at:NSPoint(x:0,y:button.bounds.minY),in:button)
        } else if popover.isShown {popover.performClose(sender)}
        else {openPopover()}
    }
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows:Bool)->Bool {
        openPopover();return false
    }
    @objc func openFromMenu() {openPopover()}
    func openPopover() {
        guard let button=status.button else {return}
        let available=button.window?.screen?.visibleFrame.size ?? NSSize(width:900,height:800)
        popover.contentSize=NSSize(width:min(640,available.width-24),height:min(760,available.height-36))
        model.displayCredentials=true
        popover.show(relativeTo:button.bounds,of:button,preferredEdge:.minY)
        NSApp.activate(ignoringOtherApps:true)
        popover.contentViewController?.view.window?.makeKey()
        installDismissMonitors()
        if let id=model.lastCreatedID,model.requests.contains(where:{$0.id==id && $0.status=="approved"}),model.detail.isEmpty,!model.busy {
            model.show(id)
        }
    }
    func installDismissMonitors() {
        removeDismissMonitors()
        outsideClickMonitor=NSEvent.addGlobalMonitorForEvents(matching:[.leftMouseDown,.rightMouseDown]) {[weak self] _ in
            Task {@MainActor in self?.popover.performClose(nil)}
        }
        localClickMonitor=NSEvent.addLocalMonitorForEvents(matching:[.leftMouseDown,.rightMouseDown,.keyDown]) {[weak self] event in
            guard let self=self,self.popover.isShown else {return event}
            if event.type == .keyDown {
                if event.keyCode == 53 {self.popover.performClose(nil);return nil}
                return event
            }
            guard let panel=self.popover.contentViewController?.view.window else {return event}
            // Preserve clicks in the panel, its confirmation sheets and native popup menus.
            if event.window == panel || event.window?.sheetParent == panel || event.window?.parent == panel || event.window == self.status.button?.window {return event}
            if event.window == nil || event.window?.level == .normal {self.popover.performClose(nil)}
            return event
        }
    }
    func removeDismissMonitors() {
        if let monitor=outsideClickMonitor {NSEvent.removeMonitor(monitor);outsideClickMonitor=nil}
        if let monitor=localClickMonitor {NSEvent.removeMonitor(monitor);localClickMonitor=nil}
    }
    func popoverDidClose(_ notification:Notification) {
        removeDismissMonitors()
        model.displayCredentials=false;model.detail=[]
    }
    @objc func quit() {NSApp.terminate(nil)}
}
@main struct LinkCardApp {
    @MainActor static func main() {
        let app=NSApplication.shared
        let delegate=AppDelegate()
        app.delegate=delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
