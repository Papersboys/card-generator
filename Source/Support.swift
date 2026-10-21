import Foundation

func objects(_ value: Any) -> [[String: Any]] {
    if let d = value as? [String: Any] { return [d] + d.values.flatMap { objects($0) } }
    if let a = value as? [Any] { return a.flatMap { objects($0) } }
    return []
}
func str(_ d: [String: Any], _ keys: String...) -> String {
    for key in keys { if let v = d[key], !(v is NSNull) { return String(describing: v) } }
    return ""
}
func find(_ value: Any, _ keys: [String]) -> String {
    for d in objects(value) { for key in keys { let s = str(d,key); if !s.isEmpty { return s } } }
    return ""
}
struct LinkError: LocalizedError { let message: String; var requiresLogin=false; var errorDescription: String? { message } }

struct SignedInAccount {
    let name:String
    let email:String
    init(_ data:[String:Any]) {
        let fullName=str(data,"name").trimmingCharacters(in:.whitespacesAndNewlines)
        name=fullName.isEmpty ? [str(data,"first_name"),str(data,"last_name")].filter{!$0.isEmpty}.joined(separator:" ") : fullName
        email=str(data,"email")
    }
}

func paymentMethodLabel(_ method:[String:Any]) -> String {
    let nickname=(method["nickname"] as? String ?? "").trimmingCharacters(in:.whitespacesAndNewlines)
    let name=(method["name"] as? String ?? "").trimmingCharacters(in:.whitespacesAndNewlines)
    let displayName=nickname.isEmpty ? name : nickname
    let brand=find(method,["brand"])
    let last4=find(method,["last4"])
    let card=[brand,last4.isEmpty ? "" : "…"+last4].filter{!$0.isEmpty}.joined(separator:" ")
    let label=[displayName,card].filter{!$0.isEmpty}.joined(separator:" · ")
    return label.isEmpty ? str(method,"id") : label
}
