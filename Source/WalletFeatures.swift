import Foundation

struct AuthorizationGrant:Codable {
    var type:String
    var actions:[String]
}
struct VerificationInfo {
    let status:String
    let actionURL:URL?
    init(_ profile:[String:Any]) {
        let value=(profile["agent_wallet_verification_requirement"] ?? profile["agent_wallet_step_up"]) as? [String:Any] ?? [:]
        status=str(value,"status")
        if let url=URL(string:str(value,"action_url")),url.scheme=="https",["app.link.com","link.com"].contains(url.host ?? ""),url.user==nil,url.password==nil {actionURL=url} else {actionURL=nil}
    }
    var label:String {
        switch status {
        case "not_required":return "无需额外验证"
        case "complete":return "验证完成"
        case "pending":return "身份验证中"
        case "contact_support":return "需要联系 Link 支持"
        case "ssn_verification","credit_file_match_ca","identity_verification","doc_upload_ca":return "需要身份验证"
        default:return "验证状态未返回"
        }
    }
}
struct WalletTransaction:Identifiable {
    let raw:[String:Any]
    var id:String {str(raw,"id")}
    var description:String {str(raw,"description")}
    var date:String {str(raw,"created_date")}
    var status:String {str(raw,"status")}
    var origin:String {str(raw,"origin")}
    var formattedAmount:String {
        guard let number=raw["amount"] as? NSNumber else {return "—"}
        let formatter=NumberFormatter();formatter.numberStyle = .currency
        formatter.currencyCode=str(raw,"currency").uppercased()
        // ISO currency fraction digits, including zero-decimal JPY and 3-decimal KWD.
        let divisor=pow(10.0,Double(formatter.maximumFractionDigits))
        return formatter.string(from:NSNumber(value:number.doubleValue/divisor)) ?? "—"
    }
}
