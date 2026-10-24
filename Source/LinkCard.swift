import AppKit
import SwiftUI
import Combine
import Sparkle

struct ContentView: View {
    @ObservedObject var model:Model
    @EnvironmentObject var accounts:AccountManager
    @ObservedObject var updates=UpdateManager.shared
    @ObservedObject var notifications=NotificationManager.shared
    @State var tab = 0
    @State var selected:String?
    @State var payment = ""
@State var merchant = "Costco"
@State var url = "https://www.costco.com"
@State var amount = ""
@State var currency = "usd"
@State var item = ""
    @State var recurringInterval=""
    @State var recurringCount=1
    var schedule:RecurringSchedule? {RecurringSchedule(interval:recurringInterval,count:recurringCount)}
    var context:String { Model.purchaseContext(merchant:merchant,url:url,amount:amount,currency:currency,item:item)+(schedule.map{" "+$0.context} ?? "") }
    @State var confirmCreate = false
    @State var toCancel:RequestItem?
    @State var copiedField:String?
    @State var showLimits=false
    var body: some View {
        GeometryReader { geometry in
        VStack(spacing:0) {
        if !model.lastError.isEmpty {
            VStack(alignment:.leading,spacing:8) {
                HStack {
                    Label(t("操作失败"),systemImage:"exclamationmark.triangle.fill").foregroundStyle(.red).font(.headline)
                    Spacer()
                    ShareLink(item:ErrorLogStore.shared.fileURL) {Label(t("发送错误日志"),systemImage:"square.and.arrow.up")}.disabled(model.logWriteFailed)
                    Button(t("复制错误")) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(t(model.lastError),forType:.string)
                    }
                    Button {model.lastError="";model.creationError=nil} label: {Image(systemName:"xmark").frame(width:32,height:32).contentShape(Rectangle())}.buttonStyle(.plain).help(t("关闭错误提示"))
                }
                ScrollView {
                    Text(t(model.lastError)).font(.callout).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading).fixedSize(horizontal:false,vertical:true)
                }.frame(maxHeight:80)
                Text(t(model.logWriteFailed ? "本地日志保存失败，请使用复制错误。" : "错误日志已保存在本地；点击发送后选择分享渠道。日志不包含原始错误文本或付款凭证。")).font(.caption).foregroundStyle(.secondary)
            }.padding(14).background(Color.red.opacity(0.08)).overlay(RoundedRectangle(cornerRadius:10).stroke(Color.red.opacity(0.25))).clipShape(RoundedRectangle(cornerRadius:10)).padding(.horizontal,24).padding(.top,16)
        }
        ScrollView { VStack(alignment:.leading,spacing:20) {
            HStack(spacing:12) {
                LinkMark().frame(width:44,height:44)
                VStack(alignment:.leading,spacing:2) {
                    Text("Link Card").font(.system(size:23,weight:.bold,design:.rounded))
                    Text(t("你的付款工作台")).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Language / 语言",selection:$model.language) {Text("中文").tag(AppLanguage.chinese);Text("English").tag(AppLanguage.english)}.pickerStyle(.segmented).labelsHidden().frame(width:145)
            }.padding(.bottom,2)
            if let loading=model.loadingMessage {
                HStack(spacing:12) {
                    ProgressView().controlSize(.small)
                    VStack(alignment:.leading,spacing:3) {
                        Text(t(loading)).font(.callout.weight(.medium))
                        Text(t("请稍候，完成后会自动更新。")).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }.padding(14).frame(maxWidth:.infinity,alignment:.leading)
                    .background(Color.linkTeal.opacity(0.07),in:RoundedRectangle(cornerRadius:12))
                    .accessibilityElement(children:.combine)
            }
            VStack(alignment:.leading,spacing:12) {
            HStack {
                Picker(t("账户"),selection:Binding(get:{accounts.activeID},set:{accounts.select($0)})) {
                    ForEach(Array(accounts.records.enumerated()),id:\.element.id) {index,record in
                        Text(record.label.isEmpty ? t("账户")+" "+String(index+1) : record.label).tag(record.id)
                    }
                }.disabled(!accounts.canSwitch)
                Button {accounts.add()} label: {Label(t("添加账户"),systemImage:"person.badge.plus")}.disabled(!accounts.canSwitch)
            }
            if !accounts.notice.isEmpty {Label(t(accounts.notice),systemImage:"person.crop.circle.badge.checkmark").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)}
            HStack(spacing:12) { if model.checkingAccount {
                Text(t("正在检查登录…")).font(.caption).foregroundStyle(.secondary)
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
            }.panelSurface()
            if model.isSignedIn,let verification=model.verification {
                HStack {
                    Label(t(verification.label),systemImage:verification.status=="complete" ? "checkmark.shield" : "person.crop.rectangle.badge.checkmark").font(.caption)
                    Spacer()
                    if let url=verification.actionURL {Link(t("在 Link 中验证"),destination:url)}
                }.panelSurface()
            }
            if model.isSignedIn {
                DisclosureGroup(t("消费限额"),isExpanded:$showLimits) {
                VStack(alignment:.leading,spacing:10) {
                    HStack {
                        Label(t("消费限额"),systemImage:"gauge.with.dots.needle.50percent").font(.headline)
                        Spacer()
                        Button(t("刷新额度")) {Task {await model.refreshAccount()}}.disabled(model.checkingAccount || model.busy)
                    }
                    if let limits=model.spendLimits {
                        Grid(alignment:.leading,horizontalSpacing:12,verticalSpacing:8) {
                            GridRow {Text("");Text(t("上限"));Text(t("已用"));Text(t("剩余"))}.foregroundStyle(.secondary)
                            ForEach([("per_transaction","单笔"),("daily","每日"),("thirty_day","滚动30天")],id:\.0) {key,title in
                                let row=limits[key] as? [String:Any]
                                GridRow {
                                    Text(t(title))
                                    Text(t(spendLimitValue(row,"limit")))
                                    Text(key=="per_transaction" ? "—" : t(spendLimitValue(row,"used")))
                                    Text(key=="per_transaction" ? "—" : t(spendLimitValue(row,"remaining")))
                                }
                            }
                        }.font(.caption).textSelection(.enabled)
                        Text(t("以 Link 当前返回的美元等值额度为准；此处不会推算或叠加账户额度。")).font(.caption2).foregroundStyle(.secondary)
                    } else {
                        Text(t(model.checkingAccount ? "正在加载额度…" : "Link 暂未返回消费限额，请尝试刷新。")).font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.top,10).frame(maxWidth:.infinity,alignment:.leading)
                }.panelSurface()
            }
            navigationTabs
            if !detailValue("Card number").isEmpty {credentialPanel}
            if tab == 0 || tab == 2 || tab == 5 {
                HStack { if tab == 0 || tab == 5 { Toggle(t("包含历史"),isOn:$model.history).onChange(of:model.history) { _ in model.load() } }; Spacer(); Button(t("刷新列表")) { model.load() } }.disabled(model.busy)
                if visibleRequests.isEmpty {
                    VStack(spacing:10) {
                        Image(systemName:tab==2 ? "checkmark.seal" : "rectangle.stack").font(.system(size:28,weight:.light)).foregroundStyle(Color.linkTeal)
                        Text(t(tab==2 ? "没有待批准的请求。" : tab==5 ? "还没有周期请求" : "还没有请求")).font(.headline)
                        Text(t(tab==2 ? "批准入口会在创建请求后显示。" : "创建付款请求，批准后即可查看卡信息。")).font(.caption).foregroundStyle(.secondary)
                        if tab==0 || tab==5 {Button(t("创建付款请求")) {if tab==5 {recurringInterval="month"};tab=1}.buttonStyle(.borderedProminent)}
                    }.frame(maxWidth:.infinity).padding(.vertical,28).panelSurface()
                } else {
                List(selection:$selected) { ForEach(visibleRequests) { r in
                    HStack { VStack(alignment:.leading) { Text(r.merchant.isEmpty ? t("Unknown merchant") : r.merchant).font(.headline); if let schedule=RecurringSchedule.from(r.raw) {Label(schedule.label(model.language),systemImage:"repeat").font(.caption).foregroundStyle(Color.linkTeal)}; Text(r.id).font(.system(.caption,design:.monospaced)).lineLimit(1).truncationMode(.middle); Text("\(str(r.raw,"amount")) \(str(r.raw,"currency").uppercased()) \(t("最小单位"))").font(.caption) }; Spacer(); Text(L10n.status(r.status,language:model.language)).font(.caption.weight(.medium)).padding(.horizontal,9).padding(.vertical,5).foregroundStyle(r.status == "approved" ? Color.linkTeal : Color.secondary).background((r.status == "approved" ? Color.linkTeal : Color.secondary).opacity(0.1),in:Capsule()); Button(t("取消请求"),role:.destructive) {toCancel=r}.buttonStyle(.borderless).disabled(model.busy || !r.canCancel) }.tag(r.id)
                } }.frame(height:min(220,CGFloat(visibleRequests.count)*78+16)).scrollContentBackground(.hidden).panelSurface()
                }
                if tab == 2 {
                    Text(t("选择请求查看详情，批准操作将在 Link 中完成。")).font(.caption).foregroundStyle(.secondary)

                    if let request=model.requests.first(where:{$0.id==selected}),request.needsApproval {
                        VStack(alignment:.leading,spacing:8) {
                            Text(str(request.raw,"merchant_url")).textSelection(.enabled)
                            Text(str(request.raw,"context")).font(.callout).textSelection(.enabled)
                            if let link=request.approvalLink {Link(t("在 Link 中批准请求 ↗"),destination:link).buttonStyle(.borderedProminent)}
                            else {Button(t("获取批准链接")) {model.requestApproval(request.id)}.disabled(model.busy)}
                        }.padding().frame(maxWidth:.infinity,alignment:.leading).background(.quaternary.opacity(0.3)).clipShape(RoundedRectangle(cornerRadius:10))
                    }
                }
                if tab==5,let request=visibleRequests.first(where:{$0.id==selected}) {SubscriptionTermsView(request:request,language:model.language)}
                HStack { Button(t(tab == 2 ? "查看请求" : "显示卡信息 Show")) { if let id=selected { model.show(id) } }; Button(t("取消请求 Cancel"),role:.destructive) { toCancel=model.requests.first{$0.id==selected} }.disabled(model.requests.first{$0.id==selected}?.canCancel != true) }.disabled(selected == nil || model.busy)
            } else if tab==3 {TransactionsView(model:model)}
            else if tab==4 {PaymentMethodsView(model:model)}
            else {
                MerchantTemplatesView(model:model,current:MerchantTemplate(name:"",merchant:merchant,url:url,amount:amount,currency:currency,item:item,interval:recurringInterval,intervalCount:recurringCount)) {template in
                    merchant=template.merchant;url=template.url;amount=template.amount;currency=template.currency
                    item=template.item;recurringInterval=template.interval;recurringCount=template.intervalCount
                }
                VStack(alignment:.leading,spacing:20) {
                    HStack {
                        Label(t("付款方式"),systemImage:"wallet.pass").font(.headline)
                        Spacer()
                        PaymentMethodsReloadButton(model:model)
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
                    Picker(t("付款周期"),selection:$recurringInterval) {
                        Text(t("单次付款")).tag("")
                        Text(t("天")).tag("day");Text(t("周")).tag("week")
                        Text(t("月")).tag("month");Text(t("年")).tag("year")
                    }
                    if let schedule=schedule {
                        Stepper(value:$recurringCount,in:1...999) {Text(schedule.label(model.language))}
                        Text(t("周期请求仍需在 Link 批准；App 不会定时发起扣款。商家订阅请在商家处单独管理。")).font(.caption).foregroundStyle(.secondary)
                    }
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
                        Text(t(field.0)).foregroundStyle(.secondary).font(.caption.weight(.medium)).frame(width:100,alignment:.leading)
                        Text(field.0 == "Status" ? L10n.status(field.1,language:model.language) : display(field.1)).font(.system(.body,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading).fixedSize(horizontal:false,vertical:true)

                    }; Divider()
                } }.padding(12) }.frame(height:220).panelSurface()
            }
            if !model.message.isEmpty { ScrollView { Text(t(model.message)).font(.caption).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) }.frame(maxHeight:90) }
            VStack(alignment:.leading,spacing:6) {
                Toggle(isOn:Binding(get:{notifications.enabled},set:{notifications.setEnabled($0)})) {Label(t("状态通知"),systemImage:"bell.badge")}.toggleStyle(.checkbox).disabled(notifications.requesting)
                Text(t(notifications.message.isEmpty ? "开启后在 App 运行期间检查状态；通知不显示卡号、金额或账户信息。" : notifications.message)).font(.caption2).foregroundStyle(.secondary)
            }
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

        }.frame(width:min(1000,max(0,geometry.size.width-40))).padding(20).frame(maxWidth:.infinity) }
        }
        }.background(Color(nsColor:.windowBackgroundColor)).tint(.linkTeal).frame(minWidth:420,minHeight:480)
        .onChange(of:model.lastCreatedID) {selected=$0;tab=2}
        .onChange(of:model.detail.first(where:{$0.0=="Card number"})?.1) {_ in copiedField=nil}
        .onChange(of:tab) { value in if value == 2 {model.load()} }
        .task(id:"\(tab)-\(model.isSignedIn)") {
            guard [1,4,5].contains(tab),model.isSignedIn else {return}
            // A request refresh may still be finishing when the user opens Create or Cards.
            // Wait for that operation instead of silently dropping the automatic load.
            do {
                while model.busy {try await Task.sleep(nanoseconds:100_000_000)}
                try Task.checkCancellation()
                guard [1,4,5].contains(tab),model.isSignedIn else {return}
                if tab==5 {model.load()} else {model.loadMethods()}
            } catch is CancellationError {} catch {}
        }
        .environment(\.locale,model.language.locale)
        .alert(t("创建付款请求？"),isPresented:$confirmCreate) { Button(t("返回"),role:.cancel){}; Button(t("创建并请求批准")) { model.create(payment:payment,merchant:merchant,url:url,amount:amount,currency:currency,item:item,context:context,recurringInterval:recurringInterval,recurringCount:recurringCount) } } message: { Text(createSummary) }
        .alert(t("取消这个请求？"),isPresented:Binding(get:{toCancel != nil},set:{if !$0 {toCancel=nil}})) { Button(t("返回"),role:.cancel){toCancel=nil}; Button(t("取消请求"),role:.destructive){if let r=toCancel {model.cancel(r)};toCancel=nil} } message:{Text("\(toCancel?.merchant ?? "")\n\(toCancel?.id ?? "")\n\(t("这不会撤销已完成的付款。"))")}
    }
    var visibleRequests:[RequestItem] {tab==5 ? model.subscriptionRequests : tab==2 ? model.requests.filter(\.needsApproval) : model.requests}
    func detailValue(_ key:String)->String {model.detail.first{$0.0==key}?.1 ?? ""}
    var navigationTabs:some View {
        LazyVGrid(columns:[GridItem(.adaptive(minimum:95),spacing:4)],spacing:4) {
            ForEach([(0,"请求","rectangle.stack"),(1,"创建","plus.circle"),(2,"批准","checkmark.seal"),(3,"流水","list.bullet.rectangle"),(4,"付款卡","wallet.pass"),(5,"订阅","repeat")],id:\.0) {index,title,icon in
                Button {tab=index} label: {
                    VStack(spacing:5) {Image(systemName:icon).font(.system(size:15));Text(t(title)).font(.system(size:11,weight:.semibold))}.frame(maxWidth:.infinity).padding(.vertical,10)
                        .foregroundStyle(tab==index ? Color.white : Color.secondary)
                        .background(tab==index ? Color.linkInk : Color.clear,in:RoundedRectangle(cornerRadius:10))
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityAddTraits(tab==index ? [.isSelected] : [])
            }
        }.padding(4).background(Color.primary.opacity(0.045),in:RoundedRectangle(cornerRadius:14))
    }
    func copyCredential(_ key:String)->some View {
        Button {
            NSPasteboard.general.clearContents();NSPasteboard.general.setString(detailValue(key),forType:.string)
            copiedField=key
            Task {try? await Task.sleep(nanoseconds:2_000_000_000);if copiedField==key {copiedField=nil}}
        } label: {
            Label(t(copiedField==key ? "已复制" : "复制"),systemImage:copiedField==key ? "checkmark" : "doc.on.doc")
                .font(.caption.weight(.medium)).padding(.horizontal,10).padding(.vertical,7)
                .background(.white.opacity(0.12),in:RoundedRectangle(cornerRadius:8))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(detailValue(key).isEmpty).accessibilityLabel(t("复制")+" "+t(key))
    }
    var credentialPanel:some View {
        VStack(alignment:.leading,spacing:18) {
            HStack {
                Label(t("虚拟卡"),systemImage:"creditcard").font(.caption.weight(.semibold)).foregroundStyle(Color.linkMint)
                Spacer()
                Text(detailValue("Brand").uppercased()).font(.system(.headline,design:.rounded)).italic()
            }
            VStack(alignment:.leading,spacing:7) {
                Text(t("Card number")).font(.caption).foregroundStyle(.white.opacity(0.7))
                HStack {
                    Text(detailValue("Card number")).font(.system(size:23,weight:.medium,design:.monospaced)).textSelection(.enabled).minimumScaleFactor(0.65).lineLimit(1)
                    Spacer(minLength:8);copyCredential("Card number")
                }
            }
            HStack(spacing:24) {
                ForEach(["CVC","Expiration"],id:\.self) {key in
                    VStack(alignment:.leading,spacing:7) {
                        Text(t(key)).font(.caption).foregroundStyle(.white.opacity(0.7))
                        HStack {Text(display(detailValue(key))).font(.system(.body,design:.monospaced)).textSelection(.enabled);Spacer(minLength:6);copyCredential(key)}
                    }.frame(maxWidth:.infinity,alignment:.leading)
                }
            }
        }.foregroundStyle(.white).padding(22).background(LinearGradient(colors:[.linkInk,Color(red:0.08,green:0.28,blue:0.33)],startPoint:.topLeading,endPoint:.bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius:20)).overlay(RoundedRectangle(cornerRadius:20).stroke(.white.opacity(0.12)))
    }
    var displayedDetails:[(String,String)] {
        let priority=["Card number","CVC","Expiration","Billing address","Brand","Valid until"]
        if model.detail.first(where:{$0.0=="Card number"})?.1.isEmpty != false {return model.detail.filter{!priority.contains($0.0)}}
        return model.detail.filter{!["Card number","CVC","Expiration"].contains($0.0)}
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
    var createSummary:String { "\(merchant)\n\(url)\n\(t("金额")): \(amount) \(currency.uppercased()) \(t("最小单位"))\n\(t("商品")): \(item)\n\(schedule?.label(model.language) ?? t("单次付款"))\n\(context)\n\(t("创建后仍需要在 Link 中批准。"))" }
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
// Keep the status button clickable while its loading indicator is visible.
final class MenuBarProgressIndicator:NSProgressIndicator {
    override func hitTest(_ point:NSPoint)->NSView? {nil}
}
@MainActor final class AppDelegate:NSObject,NSApplicationDelegate,NSPopoverDelegate {
    let accounts:AccountManager
    var model:Model {accounts.activeModel}
    var panels:[String:NSViewController]=[:]
    var accountRefreshTask:Task<Void,Never>?
    let startServices:Bool
    var status:NSStatusItem!
    let popover=NSPopover()
    var contextMenu=NSMenu()
    var languageObserver:AnyCancellable?
    var loadingObserver:AnyCancellable?
    var notificationObserver:AnyCancellable?
    let statusProgress=MenuBarProgressIndicator()
    var outsideClickMonitor:Any?
    var localClickMonitor:Any?
    init(model:Model?=nil,startServices:Bool=true) {
        self.accounts=AccountManager(initialModel:model);self.startServices=startServices;super.init()
    }
    func applicationDidFinishLaunching(_ notification:Notification) {
        NSApp.setActivationPolicy(.accessory)
        status=NSStatusBar.system.statusItem(withLength:32)
        status.button?.image=menuBarMark()
        statusProgress.style = .spinning
        statusProgress.controlSize = .small
        statusProgress.isDisplayedWhenStopped=false
        statusProgress.translatesAutoresizingMaskIntoConstraints=false
        if let button=status.button {
            button.addSubview(statusProgress)
            NSLayoutConstraint.activate([
                statusProgress.centerXAnchor.constraint(equalTo:button.centerXAnchor),
                statusProgress.centerYAnchor.constraint(equalTo:button.centerYAnchor),
                statusProgress.widthAnchor.constraint(equalToConstant:16),
                statusProgress.heightAnchor.constraint(equalToConstant:16)
            ])
        }
        status.button?.target=self;status.button?.action=#selector(togglePopover(_:))
        status.button?.sendAction(on:[.leftMouseUp,.rightMouseUp])
        popover.behavior = .transient
        popover.delegate=self
        accounts.onSwitch={[weak self] in self?.switchAccount()}
        installAccountPanel()
        languageObserver=model.$language.sink {[weak self] language in self?.updateMenu(language)}
        model.displayCredentials=false
        if startServices {
            accounts.onNotification={event,language in NotificationManager.shared.send(event,language:language)}
            notificationObserver=NotificationManager.shared.$enabled.sink {[weak self] enabled in self?.accounts.setNotifications(enabled)}
            NotificationManager.shared.checkPermission()
            accounts.startActive();UpdateManager.shared.start()
        }
        else {openPopover()}
    }
    func installAccountPanel() {
        model.openLoginPage={NSWorkspace.shared.open($0)}
        if panels[accounts.activeID]==nil {panels[accounts.activeID]=NSHostingController(rootView:ContentView(model:model).environmentObject(accounts))}
        popover.contentViewController=panels[accounts.activeID]
        languageObserver=model.$language.sink {[weak self] language in self?.updateMenu(language)}
        loadingObserver=model.$checkingAccount.combineLatest(model.$loggingIn,model.$busy,model.$language)
            .sink {[weak self] checking,logging,busy,language in
                guard let self=self else {return}
                let key=checking ? "正在检查登录并加载账户…" : logging ? "正在等待 Link 登录授权…" : busy ? "正在加载或更新数据…" : "打开 Link Card"
                self.status.button?.toolTip=L10n.text(key,language:language)
                self.status.button?.setAccessibilityLabel(L10n.text(key,language:language))
                if checking || logging || busy {
                    self.status.button?.image=nil
                    self.statusProgress.startAnimation(nil)
                } else {
                    self.statusProgress.stopAnimation(nil)
                    self.status.button?.image=menuBarMark()
                }
            }
    }
    func switchAccount() {
        installAccountPanel()
        model.displayCredentials=popover.isShown
        accountRefreshTask?.cancel()
        let selected=model
        accountRefreshTask=Task {await selected.refreshAccount();if selected.isSignedIn {selected.load()}}
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
        NotificationManager.shared.checkPermission()
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
