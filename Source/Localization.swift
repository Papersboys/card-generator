import Foundation

enum AppLanguage:String,CaseIterable {
    case chinese="zh", english="en"
    var locale:Locale { Locale(identifier:self == .chinese ? "zh_CN" : "en_US") }
}
enum L10n {
    static let preferenceKey="appLanguage"
    static var selected:AppLanguage { AppLanguage(rawValue:UserDefaults.standard.string(forKey:preferenceKey) ?? "zh") ?? .chinese }
    static let english:[String:String] = [
        "已复制":"Copied", "请求已批准，打开菜单栏面板查看卡信息。":"Request approved. Open the menu bar panel to view card details.",
        "检查更新…":"Check for Updates…", "自动检查更新":"Automatically check for updates",
        "退出登录":"Log out", "已退出登录。":"Logged out.",
        "Link 登录授权已失效，请重新登录。":"Your Link authorization is no longer valid. Please log in again.",
        "选择付款方式，或粘贴 ID":"Select a payment method or paste its ID",
        "例如 1500（$15.00 USD）":"e.g. 1500 ($15.00 USD)",
        "填写该币种的最小单位金额":"Enter an amount in this currency's minor units",
        "例如 Costco Shop Card":"e.g. Costco Shop Card",
        "USD 以美分填写：50 = $0.50（最低），1500 = $15.00。":"Enter USD in cents: 50 = $0.50 (minimum), 1500 = $15.00.",
        "发送错误日志":"Send error logs",
        "本地日志保存失败，请使用复制错误。":"Could not save the local log. Use Copy error instead.",
        "错误日志已保存在本地；点击发送后选择分享渠道。日志不包含原始错误文本或付款凭证。":"Error logs are saved locally. Choose a sharing destination after clicking Send. Logs exclude raw error text and payment credentials.",
        "消费限额":"Spend limits", "刷新额度":"Refresh limits", "上限":"Limit", "已用":"Used", "剩余":"Remaining", "单笔":"Per purchase", "每日":"Daily", "滚动30天":"Rolling 30 days", "未返回":"Not provided", "无限额":"Unlimited",
        "正在加载额度…":"Loading limits…", "Link 暂未返回消费限额，请尝试刷新。":"Link has not returned spend limits. Try refreshing.",
        "以 Link 当前返回的美元等值额度为准；此处不会推算或叠加账户额度。":"USD-equivalent limits returned by Link. Account limits are not estimated or combined.",
        "账户":"Account", "添加账户":"Add account", "请登录此 Link 账户。":"Please log in to this Link account.",
        "请求状态响应无效。":"Invalid request status response.",
        "此请求已结束，无法再次取消。已刷新服务端状态。":"This request is in a terminal state and cannot be canceled. Server status refreshed.",
        "此请求已结束，无法取消；刷新状态失败，请稍后刷新列表。":"This request is in a terminal state and cannot be canceled. Status refresh failed; refresh the list later.",
        "你的付款工作台":"Your payment workspace", "虚拟卡":"Virtual card", "还没有请求":"No requests yet", "批准入口会在创建请求后显示。":"Approval links appear after you create a request.", "创建付款请求，批准后即可查看卡信息。":"Create a request and approve it to view card details.", "创建付款请求":"Create a request",
        "操作失败":"Action failed", "复制错误":"Copy error", "关闭错误提示":"Dismiss error",
        "无法创建付款请求":"Unable to create spend request",
        "无法确认新请求状态，请稍后刷新。":"Unable to confirm the new request status. Refresh again shortly.",
        "请求已创建，请在 Link 中批准。":"Request created. Please approve it in Link.",
        "编辑":"Edit", "撤销":"Undo", "重做":"Redo", "剪切":"Cut", "复制":"Copy", "粘贴":"Paste", "全选":"Select All",
        "查看请求":"Review request", "待批准":"Approve", "用途说明（自动生成）":"Context (generated automatically)",
        "选择请求查看详情，批准操作将在 Link 中完成。":"Review a request here, then approve it in Link.",
        "当前状态无法请求批准，请刷新列表检查状态。":"Approval cannot be requested in this state. Refresh the request status.",
        "Link 未返回批准链接，请刷新请求后重试。":"Link did not return an approval link. Refresh the request and try again.",
        "没有待批准的请求。":"No requests awaiting approval.", "获取批准链接":"Get approval link",
        "查看完整许可证":"View full license",
        "可用截止时间":"Valid until", "一天以后":"One day from now",
        "默认一天以后；这是请求到期时间，卡片实际可用时间以 Link 返回为准。":"Defaults to one day from now. This sets request expiry; actual card validity is determined by Link.",
        "可用截止时间必须晚于当前时间。":"Valid until must be later than the current time.",
        "当前状态无法取消该请求。":"This request cannot be canceled in its current state.",
        "Link 尚未确认取消，请刷新列表检查状态。":"Link has not confirmed cancellation. Refresh the list to check its status.",
        "该请求已取消，卡信息已清除。":"This request was canceled. Card details have been cleared.",
        "已登录":"Logged in", "正在检查登录…":"Checking login…", "已登录，暂时无法加载账户信息。":"Logged in. Account details are temporarily unavailable.", "账户信息响应无效。":"Invalid account details response.",
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
        "原生直连 Link API，无需 CLI。登录存入 Keychain；卡信息仅保留在内存。关闭面板会清除显示。":"Connects directly to Link; no CLI required. Login is stored in Keychain; card details stay in memory. Closing the panel clears the display.",
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
        "Request expiry":"请求到期时间", "Spend request ID":"请求 ID", "Status":"状态", "Merchant":"商家名称", "Merchant URL":"商家 URL",
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
        if value.hasPrefix("已取消请求 "),value.hasSuffix("。") {
            let id=value.dropFirst("已取消请求 ".count).dropLast(1)
            return "Canceled request \(id)."
        }
        for (prefix,translation) in [("无法清除 Keychain 登录凭证（","Unable to delete Keychain credentials ("),("无法读取 Keychain 登录凭证（","Unable to read Keychain credentials ("),("无法保存 Keychain 登录凭证（","Unable to save Keychain credentials (")] {
            if value.hasPrefix(prefix) {return translation+value.dropFirst(prefix.count).replacingOccurrences(of:"）",with:")")}
        }
        return value.replacingOccurrences(of:"请求失败",with:"Request failed").replacingOccurrences(of:"Link 登录授权已失效，请重新登录。",with:"Your Link authorization is no longer valid. Please log in again.")
    }
}
