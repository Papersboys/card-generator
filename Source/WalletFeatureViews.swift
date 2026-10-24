import SwiftUI

struct TransactionsView:View {
    @ObservedObject var model:Model
    @State var confirmAuthorization=false
    func t(_ key:String)->String {L10n.text(key,language:model.language)}
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack {Label(t("交易流水"),systemImage:"list.bullet.rectangle").font(.headline);Spacer();Button(t("刷新流水")) {model.loadTransactions()}.disabled(model.busy || model.loggingIn)}
            Text(t("显示 Link 或已连接金融账户的流水，不代表商家的完整结算记录。")).font(.caption).foregroundStyle(.secondary)
            Picker(t("来源"),selection:$model.transactionOrigin) {Text(t("全部")).tag("");Text("Link").tag("link");Text(t("外部连接")).tag("external_connection")}.pickerStyle(.segmented)
            HStack {TextField(t("开始 YYYY-MM-DD"),text:$model.transactionStart);TextField(t("结束 YYYY-MM-DD"),text:$model.transactionEnd)}.textFieldStyle(.roundedBorder)
            Button(t("授权交易读取")) {confirmAuthorization=true}.disabled(model.loggingIn || model.busy || !model.isSignedIn)
            if model.transactionsNeedAuthorization {Text(t("当前授权不足，请授权交易读取后重试。")).font(.caption).foregroundStyle(.orange)}
            if !model.transactionsLoaded {Text(t("点击刷新读取流水；若提示权限不足，再授权交易读取。")).font(.caption).foregroundStyle(.secondary)}
            if model.transactionsLoaded && model.transactions.isEmpty {Text(t("没有符合条件的交易。")).foregroundStyle(.secondary)}
            ForEach(model.transactions) {transaction in
                VStack(alignment:.leading,spacing:6) {
                    HStack(alignment:.top) {Text(transaction.description.isEmpty ? transaction.id : transaction.description).font(.subheadline.weight(.medium));Spacer();Text(transaction.formattedAmount).monospacedDigit().fontWeight(.semibold)}
                    HStack {Text(transaction.date);Spacer();Text(transaction.status)}.font(.caption).foregroundStyle(.secondary)
                    Text(transaction.origin=="link" ? "Link" : t("外部连接")).font(.caption2).foregroundStyle(.secondary)
                }.textSelection(.enabled).padding(.vertical,6)
                Divider()
            }
            if model.transactionsHaveMore {Button(t("加载更多")) {model.loadTransactions(more:true)}.disabled(model.busy || model.loggingIn)}
        }.panelSurface()
        .alert(t("授权交易读取？"),isPresented:$confirmAuthorization) {
            Button(t("返回"),role:.cancel){}
            Button(t("继续授权")) {model.login(upgrade:true)}
        } message: {Text(t("将在 Link 中请求读取当前账户的 Link 和外部连接交易。请确认授权的是当前账户；原支付权限会保留。App 不会自动付款。"))}
    }
}
struct MethodEdit:Identifiable {
    let id:String
    let label:String
    var nickname:String
    var isDefault:Bool
}
struct PaymentMethodsView:View {
    @ObservedObject var model:Model
    @State var editing:MethodEdit?
    func t(_ key:String)->String {L10n.text(key,language:model.language)}
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            HStack {Label(t("付款卡管理"),systemImage:"wallet.pass").font(.headline);Spacer();PaymentMethodsReloadButton(model:model)}
            Text(t("修改会同步到 Link 钱包。清空昵称将移除昵称；设为默认会替换原默认付款方式。")).font(.caption).foregroundStyle(.secondary)
            if model.methods.isEmpty {Text(t("暂无付款方式，可点击右上角刷新按钮重试。")).font(.caption).foregroundStyle(.secondary)}
            ForEach(model.methods.indices,id:\.self) {index in
                let method=model.methods[index]
                HStack {
                    Image(systemName:"creditcard").foregroundStyle(Color.linkTeal)
                    Text(paymentMethodLabel(method)).font(.subheadline).textSelection(.enabled)
                    Spacer()
                    if method["is_default"] as? Bool == true {Text(t("默认")).font(.caption).foregroundStyle(Color.linkTeal)}
                    Button(t("编辑")) {editing=MethodEdit(id:str(method,"id"),label:paymentMethodLabel(method),nickname:str(method,"nickname"),isDefault:method["is_default"] as? Bool == true)}.disabled(model.busy || model.loggingIn)
                }
                Divider()
            }
        }.panelSurface()
        .sheet(item:$editing) {value in MethodEditor(model:model,original:value)}
    }
}
struct MethodEditor:View {
    @ObservedObject var model:Model
    let original:MethodEdit
    @State var nickname:String
    @State var isDefault:Bool
    @State var confirmSave=false
    @Environment(\.dismiss) var dismiss
    init(model:Model,original:MethodEdit) {self.model=model;self.original=original;_nickname=State(initialValue:original.nickname);_isDefault=State(initialValue:original.isDefault)}
    func t(_ key:String)->String {L10n.text(key,language:model.language)}
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            Text(t("编辑付款方式")).font(.headline)
            Text(original.label).font(.caption).textSelection(.enabled)
            TextField(t("昵称"),text:$nickname).textFieldStyle(.roundedBorder)
            Toggle(t("设为默认付款方式"),isOn:$isDefault)
            HStack {Button(t("返回")) {dismiss()};Spacer();Button(t("保存到 Link")) {confirmSave=true}.buttonStyle(.borderedProminent)}
        }.padding(24).frame(width:380)
        .alert(t("保存到 Link？"),isPresented:$confirmSave) {
            Button(t("返回"),role:.cancel){}
            Button(t("确认保存")) {model.updateMethod(original.id,nickname:nickname,isDefault:isDefault);dismiss()}
        } message: {Text(t("这会修改 Link 钱包中的昵称和默认付款方式。"))}
    }
}


struct PaymentMethodsReloadButton:View {
    @ObservedObject var model:Model
    var label:String {L10n.text("刷新付款方式",language:model.language)}
    var body:some View {
        Button {model.loadMethods()} label: {
            Image(systemName:"arrow.clockwise")
                .font(.system(size:14,weight:.semibold))
                .frame(width:36,height:36)
                .foregroundStyle(Color.linkTeal)
                .background(Color.linkTeal.opacity(0.09),in:RoundedRectangle(cornerRadius:9))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
        .disabled(model.busy || model.loggingIn || !model.isSignedIn)
        .opacity(model.busy || model.loggingIn || !model.isSignedIn ? 0.45 : 1)
    }
}


struct MerchantTemplatesView:View {
    @ObservedObject var model:Model
    let current:MerchantTemplate
    let apply:(MerchantTemplate)->Void
    @State private var selected=""
    @State private var name=""
    func t(_ key:String)->String {L10n.text(key,language:model.language)}
    var body:some View {
        DisclosureGroup {
            VStack(alignment:.leading,spacing:12) {
                Picker(t("选择模板"),selection:$selected) {
                    Text(t("新模板")).tag("")
                    ForEach(model.templates) {template in Text(template.name).tag(template.id.uuidString)}
                }.onChange(of:selected) {id in
                    guard let template=model.templates.first(where:{$0.id.uuidString==id}) else {name="";return}
                    name=template.name;apply(template)
                }
                TextField(t("模板名称"),text:$name).textFieldStyle(.roundedBorder)
                HStack {
                    Button(t("保存当前填写")) {
                        var template=current;template.name=name.trimmingCharacters(in:.whitespacesAndNewlines)
                        if let id=UUID(uuidString:selected) {template.id=id}
                        do {try model.saveTemplate(template);selected=template.id.uuidString}
                        catch {model.handle(error)}
                    }.disabled(name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                    if let id=UUID(uuidString:selected) {
                        Button(t("删除模板"),role:.destructive) {model.deleteTemplate(id);selected="";name=""}
                    }
                }
                Text(t("选择模板会替换当前购买信息；仅在本机按账户保存，不保存付款方式 ID 或卡信息。")).font(.caption).foregroundStyle(.secondary)
            }.padding(.top,10)
        } label: {Label(t("商家模板"),systemImage:"square.stack.3d.up")}
        .panelSurface()
    }
}

struct SubscriptionTermsView:View {
    let request:RequestItem
    let language:AppLanguage
    func t(_ key:String)->String {L10n.text(key,language:language)}
    var body:some View {
        VStack(alignment:.leading,spacing:10) {
            Label(request.merchant,systemImage:"repeat").font(.headline)
            LabeledContent(t("周期"),value:RecurringSchedule.from(request.raw)?.label(language) ?? "—")
            LabeledContent(t("每期上限"),value:WalletTransaction(raw:request.raw).formattedAmount)
            LabeledContent(t("币种"),value:str(request.raw,"currency").uppercased())
            LabeledContent(t("状态"),value:L10n.status(request.status,language:language))
            LabeledContent(t("请求到期"),value:expiry)
            Text(str(request.raw,"merchant_url")).font(.caption).textSelection(.enabled)
            Text(request.id).font(.system(.caption,design:.monospaced)).textSelection(.enabled)
            if let link=request.approvalLink {Link(t("在 Link 中批准请求 ↗"),destination:link)}
            Text(t("每期上限不是已扣款金额。下次扣款日由商家决定；取消凭证后仍需在商家处取消订阅。")).font(.caption).foregroundStyle(.secondary)
        }.panelSurface()
    }
    var expiry:String {
        guard let seconds=Double(str(request.raw,"expires_at")) else {return t("未返回")}
        return Date(timeIntervalSince1970:seconds).formatted(Date.FormatStyle(date:.abbreviated,time:.shortened).locale(language.locale))
    }
}

struct SafariAutofillView:View {
    @ObservedObject var model:Model
    @State private var page:AutofillPage?
    @State private var requestID=""
    @State private var result:[String:Any]?
    func t(_ key:String)->String {L10n.text(key,language:model.language)}
    func detail(_ key:String)->String {model.detail.first{$0.0==key}?.1 ?? ""}
    var body:some View {
        VStack(alignment:.leading,spacing:9) {
            Button {scan()} label: {Label(t("填入 Safari…"),systemImage:"safari").frame(maxWidth:.infinity).padding(10).background(.white.opacity(0.12),in:RoundedRectangle(cornerRadius:10)).contentShape(Rectangle())}
                .buttonStyle(.plain).disabled(model.busy || model.checkingAccount || model.loggingIn)
            Text(t("先确认网站，再填写；不会提交付款。跨域付款框可能需要手动复制。")).font(.caption2).foregroundStyle(.white.opacity(0.75))
            if let result=result {
                let filled=result["filled"] as? [String] ?? []
                Text(t("已尝试填写，请在 Safari 核对后自行付款。")).font(.caption)
                Text(t("已填写字段")+": "+filled.map{fieldName($0)}.joined(separator:", ")).font(.caption2)
                if (result["blockedFrames"] as? Int ?? 0)>0 || !(result["skipped"] as? [String] ?? []).isEmpty {
                    Text(t("部分字段无法填写，请使用复制按钮补齐。")).font(.caption2)
                }
            }
            DisclosureGroup(t("首次使用设置")) {
                Text(t("Safari 设置 → 高级 → 显示网页开发者功能，然后在开发菜单或开发者设置中允许来自 Apple 事件的 JavaScript；系统询问时允许 Link Card 控制 Safari。")).font(.caption2).fixedSize(horizontal:false,vertical:true).padding(.top,6)
            }.font(.caption2)
        }
        .sheet(item:$page) {target in
            VStack(alignment:.leading,spacing:16) {
                Label(t("确认填写网站"),systemImage:"lock.shield").font(.title2.bold())
                Text(target.origin).font(.system(.title3,design:.monospaced)).textSelection(.enabled)
                Text(displayURL(target.url)).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                Text(t("请求商家")+": "+detail("Merchant")).font(.callout)
                if let merchant=URL(string:detail("Merchant URL"))?.host,
                   let current=URL(string:target.url)?.host,
                   merchant.lowercased().replacingOccurrences(of:"www.",with:"") != current.lowercased().replacingOccurrences(of:"www.",with:"") {
                    Text(t("当前网站与请求商家域名不同，请确认这是你要使用的付款网站。")).font(.callout).foregroundStyle(.orange)
                }
                Text(t("检测到字段")+": "+target.kinds.map{fieldName($0)}.joined(separator:", ")).font(.callout)
                if target.blockedFrames>0 {Text(t("检测到无法访问的跨域付款框，部分字段需要手动复制。")).font(.caption).foregroundStyle(.secondary)}
                Text(t("将填写当前显示的虚拟卡和已返回的账单地址，不会提交表单。继续会覆盖对应字段。")).font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(t("返回")) {page=nil}.keyboardShortcut(.cancelAction)
                    Spacer()
                    Button(t("确认并填写")) {fill(target)}.buttonStyle(.borderedProminent)
                        .disabled(!target.kinds.contains("number") || model.busy || detail("Spend request ID") != requestID)
                }
                if !target.kinds.contains("number") {Text(t("没有找到可填写的卡号字段；跨域付款框请使用复制按钮。")).font(.caption).foregroundStyle(.secondary)}
            }.padding(24).frame(width:430).foregroundStyle(.primary)
        }
        .onChange(of:model.detail.isEmpty) {empty in if empty {page=nil;result=nil}}
    }
    func scan() {
        guard !model.busy,model.displayCredentials else {return}
        requestID=detail("Spend request ID");let expected=requestID
        result=nil;model.busy=true
        Task {
            defer {model.busy=false}
            do {
                let target=try await SafariAutofill.scan()
                guard model.displayCredentials,detail("Spend request ID")==expected,!detail("Card number").isEmpty else {return}
                page=target
            } catch {model.handle(error)}
        }
    }
    func fill(_ target:AutofillPage) {
        guard !model.busy,model.displayCredentials,detail("Spend request ID")==requestID else {page=nil;return}
        do {
            let card=try AutofillCard(details:model.detail,billing:model.billingFields)
            page=nil;model.busy=true
            Task {
                defer {model.busy=false}
                do {result=try await SafariAutofill.fill(page:target,card:card)}
                catch {model.handle(error)}
            }
        } catch {page=nil;model.handle(error)}
    }
    func displayURL(_ raw:String)->String {
        guard var parts=URLComponents(string:raw) else {return ""}
        parts.query=nil;parts.fragment=nil;return parts.string ?? ""
    }
    func fieldName(_ key:String)->String {
        t(["number":"Card number","cvc":"CVC","expiry":"Expiration","month":"有效期月份","year":"有效期年份","name":"持卡人姓名","street":"Billing address","line1":"账单地址第一行","line2":"账单地址第二行","city":"城市","state":"州／省","postal":"邮编","country":"国家"][key] ?? key)
    }
}


struct SpendLimitAlertsView:View {
    let alerts:[SpendLimitAlert]
    let language:AppLanguage
    func t(_ key:String)->String {L10n.text(key,language:language)}
    var body:some View {
        if !alerts.isEmpty {
            VStack(alignment:.leading,spacing:8) {
                ForEach(alerts) {alert in
                    HStack(alignment:.top,spacing:8) {
                        Image(systemName:alert.level=="near" ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                        VStack(alignment:.leading,spacing:3) {
                            Text(t(alert.scopeLabel)+" · "+t(alert.message)).font(.callout.weight(.medium))
                            Text(t(alert.scope=="per_transaction" ? "上限" : "剩余")+": "+String(format:"USD %.2f",alert.amount/100)).font(.caption)
                        }
                    }.foregroundStyle(alert.level=="near" ? Color.orange : Color.red)
                }
                Text(t("仅依据 Link 返回的美元等值额度；其他币种不自动换算，最终以 Link 批准结果为准。")).font(.caption2).foregroundStyle(.secondary)
            }.padding(14).frame(maxWidth:.infinity,alignment:.leading).background(Color.orange.opacity(0.07),in:RoundedRectangle(cornerRadius:12))
        }
    }
}
struct RequestFilterView:View {
    @Binding var filter:RequestFilter
    let requests:[RequestItem]
    let methods:[[String:Any]]
    let language:AppLanguage
    func t(_ key:String)->String {L10n.text(key,language:language)}
    var statuses:[String] {Array(Set(requests.map(\.status).filter{!$0.isEmpty}+(filter.status.isEmpty ? [] : [filter.status]))).sorted()}
    var paymentIDs:[String] {Array(Set(requests.map{RequestFilter.fundingID($0)}.filter{!$0.isEmpty}+(filter.paymentID.isEmpty ? [] : [filter.paymentID]))).sorted()}
    var body:some View {
        VStack(alignment:.leading,spacing:10) {
            HStack {
                Image(systemName:"magnifyingglass").foregroundStyle(.secondary)
                TextField(t("搜索商家、网址、请求 ID 或用途"),text:$filter.query).textFieldStyle(.roundedBorder)
                if filter.isActive {Button(t("清空筛选")) {filter=RequestFilter()}}
            }
            LazyVGrid(columns:[GridItem(.adaptive(minimum:145),spacing:12)],spacing:10) {
                Picker(t("状态"),selection:$filter.status) {
                    Text(t("全部状态")).tag("")
                    ForEach(statuses,id:\.self) {status in Text(L10n.status(status,language:language)).tag(status)}
                }
                Picker(t("付款卡"),selection:$filter.paymentID) {
                    Text(t("全部付款卡")).tag("")
                    ForEach(paymentIDs,id:\.self) {id in Text(paymentLabel(id)).tag(id)}
                }
                Picker(t("请求类型"),selection:$filter.kind) {
                    Text(t("全部类型")).tag("");Text(t("单次付款")).tag("single");Text(t("周期付款")).tag("recurring")
                }
            }
            Text(t("筛选当前已加载的请求；包含历史由上方开关控制。")).font(.caption2).foregroundStyle(.secondary)
        }.panelSurface()
    }
    func paymentLabel(_ id:String)->String {
        if let method=methods.first(where:{str($0,"id")==id}) {return paymentMethodLabel(method)}
        return id
    }
}
