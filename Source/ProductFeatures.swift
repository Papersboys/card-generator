import Foundation

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
