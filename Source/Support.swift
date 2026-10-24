import Foundation
import CoreFoundation

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
struct LinkError: LocalizedError { let message: String; var requiresLogin=false; var httpStatus:Int?=nil; var errorDescription: String? { message } }

struct SignedInAccount {
    let id:String
    let name:String
    let email:String
    init(_ data:[String:Any]) {
        id=str(data,"id")
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

func spendLimitValue(_ row:[String:Any]?,_ key:String)->String {
    guard let value=row?[key] else {return "未返回"}
    if value is NSNull {return key=="used" ? "未返回" : "无限额"}
    guard let number=value as? NSNumber,CFGetTypeID(number) != CFBooleanGetTypeID() else {return "未返回"}
    return String(format:"USD %.2f",number.doubleValue/100)
}

func sameLinkAccount(id:String,email:String,otherID:String,otherEmail:String)->Bool {
    if !id.isEmpty && !otherID.isEmpty {return id==otherID}
    let email=email.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()
    let other=otherEmail.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()
    return !email.isEmpty && email==other
}


struct RecurringSchedule {
    let interval:String
    let count:Int
    init?(interval:String,count:Int) {
        guard ["day","week","month","year"].contains(interval),count>0 else {return nil}
        self.interval=interval;self.count=count
    }
    var body:[String:Any] {["interval":interval,"interval_count":count]}
    var context:String {"This is a recurring payment request, every \(count) \(interval)(s)."}
    func label(_ language:AppLanguage)->String {
        if language == .english {return "Every \(count) \(interval)"+(count==1 ? "" : "s")}
        return "每 \(count) \(["day":"天","week":"周","month":"月","year":"年"][interval] ?? interval)"
    }
    static func from(_ raw:[String:Any])->RecurringSchedule? {
        guard let recurring=raw["recurring"] as? [String:Any] else {return nil}
        let count=recurring["interval_count"] as? Int ?? 1
        return RecurringSchedule(interval:str(recurring,"interval"),count:count)
    }
}
