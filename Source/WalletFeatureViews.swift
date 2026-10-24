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
