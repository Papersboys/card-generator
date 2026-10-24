import Foundation

struct ErrorReport:Encodable {
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

struct ErrorLogStore {
    static let shared=ErrorLogStore()
    let directory:URL
    init(directory:URL?=nil) {
        self.directory=directory ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/LinkCard",isDirectory:true)
    }
    var fileURL:URL {directory.appendingPathComponent("error-log.jsonl")}
    func append(_ report:ErrorReport) throws {
        let fm=FileManager.default
        try fm.createDirectory(at:directory,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        try fm.setAttributes([.posixPermissions:0o700],ofItemAtPath:directory.path)
        var lines=(try? String(contentsOf:fileURL,encoding:.utf8))?.split(separator:"\n").map(String.init) ?? []
        let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys]
        struct Entry:Encodable {let timestamp:String;let report:ErrorReport}
        let entry=Entry(timestamp:ISO8601DateFormatter().string(from:Date()),report:report)
        lines.append(String(decoding:try encoder.encode(entry),as:UTF8.self))
        lines=Array(lines.suffix(200))
        while lines.joined(separator:"\n").utf8.count>256*1024 && lines.count>1 {lines.removeFirst()}
        let data=Data((lines.joined(separator:"\n")+"\n").utf8)
        try data.write(to:fileURL,options:[.atomic])
        try fm.setAttributes([.posixPermissions:0o600],ofItemAtPath:fileURL.path)
    }
}
