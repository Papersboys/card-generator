import Foundation
import CoreFoundation

struct MerchantTemplate:Codable,Identifiable,Equatable {
    var id=UUID()
    var name:String
    var merchant:String
    var url:String
    var amount:String
    var currency:String
    var item:String
    var interval:String
    var intervalCount:Int
    func validate() throws {
        guard !name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,
              !merchant.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,
              let link=URL(string:url),["https","http"].contains(link.scheme ?? ""),link.host != nil,
              let value=Int(amount),value>0,!item.isEmpty,
              interval.isEmpty || RecurringSchedule(interval:interval,count:intervalCount) != nil
        else {throw LinkError(message:"请填写模板名称、商家、有效网址、正整数金额和商品。")}
    }
}

enum RequestEvent:String {
    case approved,failed,paymentSucceeded,paymentFailed
    var message:String {
        switch self {
        case .approved:return "付款请求已批准，打开 Link Card 查看。"
        case .failed:return "付款请求未获批准或已失败，打开 Link Card 查看。"
        case .paymentSucceeded:return "Link 返回一笔付款成功，打开 Link Card 查看。"
        case .paymentFailed:return "Link 返回一笔付款失败，打开 Link Card 查看。"
        }
    }
}
struct RequestEventTracker {
    private var statuses:[String:String]=[:]
    private var payments:[String:[String:String]]=[:]
    mutating func observe(_ request:RequestItem)->[RequestEvent] {
        guard !request.id.isEmpty else {return []}
        var events:[RequestEvent]=[]
        let previous=statuses[request.id]
        if let previous=previous,previous != request.status {
            if request.status=="approved" {events.append(.approved)}
            else if ["failed","rejected","declined"].contains(request.status) {events.append(.failed)}
        }
        statuses[request.id]=request.status
        var rows=request.raw["payment_history"] as? [[String:Any]] ?? []
        if let current=request.raw["payment_status_details"] as? [String:Any] {rows.append(current)}
        var known=payments[request.id] ?? [:]
        for row in rows {
            let id=str(row,"link_transaction_id","id"),outcome=str(row,"outcome")
            guard !id.isEmpty,!outcome.isEmpty else {continue}
            if previous != nil,known[id] != outcome {
                if outcome=="success" {events.append(.paymentSucceeded)}
                else if ["failed","failure","declined"].contains(outcome) {events.append(.paymentFailed)}
            }
            known[id]=outcome
        }
        payments[request.id]=known
        return events
    }
}


struct SpendLimitAlert:Identifiable {
    let scope:String
    let level:String
    let amount:Double
    var id:String {scope+level}
    var message:String {level=="insufficient" ? "填写金额超过当前额度" : level=="exhausted" ? "当前额度为零" : "剩余额度不足 20%"}
    var scopeLabel:String {["per_transaction":"单笔","daily":"每日","thirty_day":"滚动30天"][scope] ?? scope}
    static func evaluate(_ limits:[String:Any]?,amount:Int?=nil,currency:String="usd")->[SpendLimitAlert] {
        func finite(_ value:Any?)->Double? {
            guard let n=value as? NSNumber,CFGetTypeID(n) != CFBooleanGetTypeID(),n.doubleValue.isFinite,n.doubleValue>=0 else {return nil}
            return n.doubleValue
        }
        var alerts:[SpendLimitAlert]=[]
        for scope in ["per_transaction","daily","thirty_day"] {
            guard let row=limits?[scope] as? [String:Any],let limit=finite(row["limit"]) else {continue}
            guard let remaining=scope=="per_transaction" ? limit : finite(row["remaining"]) else {continue}
            let level:String?
            if let amount=amount,amount>0,currency.lowercased()=="usd",Double(amount)>remaining {level="insufficient"}
            else if remaining==0 {level="exhausted"}
            else if scope != "per_transaction",limit>0,remaining/limit<0.2 {level="near"}
            else {level=nil}
            if let level=level {alerts.append(SpendLimitAlert(scope:scope,level:level,amount:remaining))}
        }
        return alerts
    }
}
struct RequestFilter:Equatable {
    var query=""
    var status=""
    var paymentID=""
    var kind=""
    var isActive:Bool {!query.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || !status.isEmpty || !paymentID.isEmpty || !kind.isEmpty}
    static func fundingID(_ request:RequestItem)->String {
        for key in ["payment_details","payment_method"] {
            if let id=request.raw[key] as? String,!id.isEmpty {return id}
            if let method=request.raw[key] as? [String:Any],!str(method,"id").isEmpty {return str(method,"id")}
        }
        return ""
    }
    func matches(_ request:RequestItem)->Bool {
        if !status.isEmpty && request.status != status {return false}
        if !paymentID.isEmpty && Self.fundingID(request) != paymentID {return false}
        let recurring=RecurringSchedule.from(request.raw) != nil
        if kind=="single" && recurring || kind=="recurring" && !recurring {return false}
        let text=[request.merchant,request.id,str(request.raw,"merchant_url"),str(request.raw,"context")].joined(separator:" ")
        return query.split(whereSeparator:{$0.isWhitespace}).allSatisfy{text.range(of:String($0),options:[.caseInsensitive,.diacriticInsensitive]) != nil}
    }
}
