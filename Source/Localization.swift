import Foundation

enum AppLanguage:String,CaseIterable {
    case chinese="zh", english="en"
    var locale:Locale { Locale(identifier:self == .chinese ? "zh_CN" : "en_US") }
}
enum L10n {
    static let preferenceKey="appLanguage"
    static var selected:AppLanguage { AppLanguage(rawValue:UserDefaults.standard.string(forKey:preferenceKey) ?? "zh") ?? .chinese }
    static let english:[String:String] = [
        "登录 Link":"Log in to Link", "清除卡信息":"Clear card details",
        "请求 / 历史":"Requests / History", "创建 Generate":"Create",
        "包含历史":"Include history", "刷新列表":"Refresh list",
        "Unknown merchant":"Unknown merchant", "显示卡信息 Show":"Show card details",
        "取消请求 Cancel":"Cancel request", "付款方式":"Payment method",
        "选择或填写下方 ID":"Select a method or enter its ID below", "加载":"Load",
        "付款方式 ID":"Payment method ID", "商家名称":"Merchant name", "商家 URL":"Merchant URL",
        "金额（最小单位，如 $15 = 1500）":"Amount in minor units ($15 = 1500)", "币种":"Currency",
        "商品（数量 1）":"Item (quantity 1)", "用途 Context（至少 100 字符）":"Context (minimum 100 characters)",
        "检查并创建请求…":"Review and create…", "打开 Link 登录授权 ↗":"Open Link authorization ↗",
        "停止等待":"Stop waiting", "在 Link 中批准请求 ↗":"Approve in Link ↗",
        "已批准，刷新卡信息":"Refresh after approval", "创建付款请求？":"Create spend request?",
        "返回":"Back", "创建并请求批准":"Create and request approval", "取消这个请求？":"Cancel this request?",
        "取消请求":"Cancel request", "最小单位":"minor units", "金额":"Amount", "商品":"Item",
        "创建后仍需要在 Link 中批准。":"You will still need to approve this request in Link.",
        "这不会撤销已完成的付款。":"This does not reverse completed payments.",
        "打开 Link Card":"Open Link Card", "退出":"Quit",
        "原生直连 Link API，无需 CLI。登录存入 Keychain；卡信息仅保留在内存。关闭窗口会清除显示。取消请求不等于退款。":"Connects directly to Link; no CLI required. Login is stored in Keychain; card details stay in memory. Closing the window clears the display. Canceling a request does not issue a refund.",
        "打开登录链接，在 Link 中输入授权短语。":"Open the authorization link and enter the phrase in Link.",
        "Link 登录成功。":"Logged in to Link.", "登录链接已过期，请重新登录。":"The login link expired. Please log in again.",
        "已停止等待登录。":"Stopped waiting for login.", "自动等待已结束；可手动刷新卡信息。":"Automatic approval checks ended. You can refresh card details manually.",
        "没有历史请求。":"No request history found.", "没有活跃请求；可打开包含历史，或创建新请求。":"No active requests. Enable Include history or create a new request.",
        "没有找到付款方式；可手动填写付款方式 ID。":"No payment methods found. You can enter a payment method ID manually.",
        "暂无完整卡信息。若等待批准，请打开 Link 批准后点击刷新卡信息。":"Full card details are not available. If approval is pending, approve in Link and refresh.",
        "检查付款方式、商家 URL、正整数金额和至少 100 字符的用途；商品名不能包含逗号。":"Check the payment method, merchant URL, positive integer amount, and context of at least 100 characters. Item names cannot contain commas.",
        "未返回 spend request ID":"Link did not return a spend request ID.",
        "请点击「登录 Link」在浏览器授权，无需安装 CLI。":"Click Log in to Link and authorize in your browser. No CLI is required.",
        "现有登录已过期。请点击「登录 Link」建立独立 App 登录。":"Your existing login expired. Click Log in to Link to establish an independent app session.",
        "Link 未返回登录凭证":"Link did not return login credentials.", "请求失败":"Request failed",
        "Link 登录返回无效数据":"Link returned invalid login data.", "Link 授权信息无效":"Link returned invalid authorization details.",
        "Link 返回无效响应":"Link returned an invalid response.", "无效的 spend request ID":"Invalid spend request ID."
    ]
    static let chineseFields:[String:String] = [
        "Spend request ID":"请求 ID", "Status":"状态", "Merchant":"商家名称", "Merchant URL":"商家 URL",
        "Context":"用途", "Created at":"创建时间", "Card number":"卡号", "CVC":"CVC / 安全码",
        "Brand":"卡组织", "Expiration":"卡面有效期", "Billing address":"账单地址", "Valid until":"可用截止时间",
        "Unknown merchant":"未知商家"
    ]
    static let states:[String:(String,String)] = [
        "created":("已创建","Created"), "pending_approval":("等待批准","Pending approval"),
        "approved":("已批准","Approved"), "requires_action":("需要操作","Action required"),
        "canceled":("已取消","Canceled"), "cancelled":("已取消","Canceled"),
        "expired":("已过期","Expired"), "denied":("已拒绝","Denied"), "submitted":("已提交","Submitted"),
        "succeeded":("已成功","Succeeded"), "failed":("失败","Failed"), "completed":("已完成","Completed")
    ]
    static func status(_ value:String,language:AppLanguage)->String {
        guard let pair=states[value] else {return value};return language == .chinese ? pair.0 : pair.1
    }
    static func text(_ value:String,language:AppLanguage?=nil)->String {
        let lang=language ?? selected
        if lang == .chinese {return chineseFields[value] ?? value}
        if let translated=english[value] {return translated}
        if value.hasPrefix("请求状态：") {return "Request status: "+status(String(value.dropFirst("请求状态：".count)),language:lang)}
        if value.hasPrefix("自动刷新停止：") {return "Automatic refresh stopped: "+text(String(value.dropFirst("自动刷新停止：".count)),language:lang)}
        if value.hasPrefix("已取消请求 "),value.hasSuffix("。取消请求不等于退款。") {
            let id=value.dropFirst("已取消请求 ".count).dropLast("。取消请求不等于退款。".count)
            return "Canceled request \(id). Canceling a request does not issue a refund."
        }
        for (prefix,translation) in [("无法读取 Keychain 登录凭证（","Unable to read Keychain credentials ("),("无法保存 Keychain 登录凭证（","Unable to save Keychain credentials (")] {
            if value.hasPrefix(prefix) {return translation+value.dropFirst(prefix.count).replacingOccurrences(of:"）",with:")")}
        }
        return value.replacingOccurrences(of:"请求失败",with:"Request failed")
    }
}
