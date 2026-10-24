import Foundation

struct ErrorReport:Codable {
    let schema=1
    let app_version:String
    let os_version:String
    let category:String
    let http_status:Int
    init(error:String,version:String?=nil) {
        app_version=version ?? Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "0"
        let os=ProcessInfo.processInfo.operatingSystemVersion
        os_version="\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        let lower=error.lowercased()
        let pattern="Link HTTP ([1-5][0-9]{2}):"
        if let range=error.range(of:pattern,options:.regularExpression) {
            http_status=Int(error[range].filter{$0.isNumber}) ?? 0
        } else {http_status=0}
        if lower.contains("token") || lower.contains("401") || lower.contains("revoked") {category="authorization"}
        else if lower.contains("amount must be at least") {category="minimum_amount"}
        else if lower.contains("approval") || error.contains("批准") {category="approval"}
        else if lower.contains("network") || lower.contains("timed out") || error.contains("网络") {category="network"}
        else if http_status>=500 {category="server"}
        else {category="other"}
    }
    var json:Data {let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys];return (try? encoder.encode(self)) ?? Data()}
    var preview:String {String(data:json,encoding:.utf8) ?? ""}
}
final class ReportNoRedirect:NSObject,URLSessionTaskDelegate {
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping(URLRequest?)->Void) {completionHandler(nil)}
}
@MainActor final class ErrorReporter:ObservableObject {
    @Published var sending=false
    @Published var feedback=""
    func send(_ report:ErrorReport) {
        guard !sending else {return}
        guard let value=Bundle.main.object(forInfoDictionaryKey:"ErrorReportURL") as? String,let url=URL(string:value),url.scheme=="https",url.host?.hasSuffix(".lambda-url.us-west-2.on.aws")==true else {feedback="错误报告接收服务尚未配置。";return}
        sending=true;feedback=""
        Task {
            let config=URLSessionConfiguration.ephemeral
            config.urlCache=nil;config.httpCookieStorage=nil
            let session=URLSession(configuration:config,delegate:ReportNoRedirect(),delegateQueue:nil)
            defer {session.invalidateAndCancel();sending=false}
            do {
                var request=URLRequest(url:url);request.httpMethod="POST";request.timeoutInterval=15
                request.setValue("application/json",forHTTPHeaderField:"Content-Type");request.httpBody=report.json
                let (data,response)=try await session.data(for:request)
                guard (response as? HTTPURLResponse)?.statusCode==201,let object=try JSONSerialization.jsonObject(with:data) as? [String:Any],let id=object["report_id"] as? String,UUID(uuidString:id) != nil else {throw URLError(.badServerResponse)}
                feedback="错误报告已发送。"
            } catch {feedback="发送失败，请稍后重试。"}
        }
    }
}
