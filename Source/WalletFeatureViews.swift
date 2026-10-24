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
            HStack {Label(t("付款卡管理"),systemImage:"wallet.pass").font(.headline);Spacer();Button(t("加载")) {model.loadMethods()}.disabled(model.busy || model.loggingIn)}
            Text(t("修改会同步到 Link 钱包。清空昵称将移除昵称；设为默认会替换原默认付款方式。")).font(.caption).foregroundStyle(.secondary)
            if model.methods.isEmpty {Text(t("点击加载读取 Link 钱包中的付款方式。")).font(.caption).foregroundStyle(.secondary)}
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
