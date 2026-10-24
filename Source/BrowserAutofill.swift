import AppKit
import Foundation

struct AutofillPage:Identifiable {
    let id=UUID()
    let url:String
    let origin:String
    let kinds:[String]
    let blockedFrames:Int
}
struct AutofillCard {
    let values:[String:String]
    init(details:[(String,String)],billing:[String:String]) throws {
        func value(_ key:String)->String {details.first{$0.0==key}?.1 ?? ""}
        let number=value("Card number").filter(\.isNumber),cvc=value("CVC")
        let expiry=value("Expiration").split(separator:"/").map(String.init)
        guard number.range(of:"^[0-9]{12,19}$",options:.regularExpression) != nil,
              cvc.range(of:"^[0-9]{3,4}$",options:.regularExpression) != nil,
              expiry.count==2,let month=Int(expiry[0]),(1...12).contains(month),let rawYear=Int(expiry[1]) else {throw LinkError(message:"卡信息不完整，请重新显示卡信息后再填写。")}
        let year=rawYear<100 ? 2000+rawYear : rawYear
        guard (2000...2199).contains(year) else {throw LinkError(message:"卡信息不完整，请重新显示卡信息后再填写。")}
        var result=billing;result["number"]=number;result["cvc"]=cvc
        result["month"]=String(format:"%02d",month);result["year"]=String(year)
        values=result
    }
}

enum SafariAutofill {
    private static let queue=DispatchQueue(label:"linkcard.safari-autofill",qos:.userInitiated)
    static func scan() async throws -> AutofillPage {
        let result=try await execute(["action":"scan"])
        guard let raw=result["url"] as? String,let url=URL(string:raw),url.scheme=="https",url.host != nil,url.user==nil,url.password==nil else {throw LinkError(message:"只能向 HTTPS 付款页面填卡。")}
        return AutofillPage(url:raw,origin:str(result,"origin"),kinds:result["kinds"] as? [String] ?? [],blockedFrames:result["blockedFrames"] as? Int ?? 0)
    }
    static func fill(page:AutofillPage,card:AutofillCard) async throws -> [String:Any] {
        try await execute(["action":"fill","url":page.url,"card":card.values])
    }
    private static func execute(_ command:[String:Any]) async throws -> [String:Any] {
        // Neither credentials nor the evaluated script go through a shell, clipboard, file or log.
        let bytes=try JSONSerialization.data(withJSONObject:command)
        guard let resource=Bundle.main.url(forResource:"autofill",withExtension:"js"),let engine=try? String(contentsOf:resource,encoding:.utf8) else {throw LinkError(message:"浏览器填卡组件缺失，请重新安装 App。")}
        let expected=command["url"] as? String ?? ""
        let script="JSON.stringify(("+engine+")("+String(decoding:bytes,as:UTF8.self)+"))"
        return try await withCheckedThrowingContinuation {continuation in
            queue.async {
                autoreleasepool {
                    let source="""
                    on executePage(scriptText, expectedURL)
                        if application id "com.apple.Safari" is not running then error number -600
                        tell application id "com.apple.Safari"
                            if (count of windows) is 0 then error number -600
                            with timeout of 20 seconds
                                set pageTab to current tab of front window
                                set pageURL to URL of pageTab
                                if expectedURL is not "" and pageURL is not expectedURL then error number -2701
                                set outputJSON to do JavaScript scriptText in pageTab
                                return {pageURL, outputJSON}
                            end timeout
                        end tell
                    end executePage
                    """
                    guard let appleScript=NSAppleScript(source:source) else {continuation.resume(throwing:LinkError(message:"无法连接 Safari。"));return}
                    let event=NSAppleEventDescriptor(eventClass:0x61736372,eventID:0x70736272,targetDescriptor:nil,returnID:-1,transactionID:0)
                    event.setParam(NSAppleEventDescriptor(string:"executepage"),forKeyword:0x736e616d)
                    let args=NSAppleEventDescriptor.list();args.insert(NSAppleEventDescriptor(string:script),at:1);args.insert(NSAppleEventDescriptor(string:expected),at:2)
                    event.setParam(args,forKeyword:0x2d2d2d2d)
                    var error:NSDictionary?
                    let output=appleScript.executeAppleEvent(event,error:&error)
                    if let error=error {
                        // AppleScript error descriptions may echo the script. Never surface them.
                        let code=(error[NSAppleScript.errorNumber] as? NSNumber)?.intValue ?? 0
                        let message=code == -2701 ? "页面已切换，请重新检查网站后再填写。" : code == -1743 ? "请在系统设置的隐私与安全性 → 自动化中允许 Link Card 控制 Safari。" : code == -600 ? "请先在 Safari 打开付款页面。" : "无法在 Safari 执行填卡。请开启开发菜单中的允许来自 Apple 事件的 JavaScript，并检查自动化权限。"
                        continuation.resume(throwing:LinkError(message:message));return
                    }
                    guard output.numberOfItems==2,let trustedURL=output.atIndex(1)?.stringValue,let string=output.atIndex(2)?.stringValue,let data=string.data(using:.utf8),var result=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any] else {continuation.resume(throwing:LinkError(message:"Safari 未返回有效的填卡结果。"));return}
                    if let code=result["error"] as? String {
                        let message=["https_required":"只能向 HTTPS 付款页面填卡。","page_changed":"页面已切换，请重新检查网站后再填写。","no_card_fields":"没有找到可填写的卡号字段；跨域付款框请使用复制按钮。","invalid_card":"卡信息不完整，请重新显示卡信息后再填写。" ][code] ?? "Safari 未返回有效的填卡结果。"
                        continuation.resume(throwing:LinkError(message:message));return
                    }
                    // The browser, not webpage JavaScript, supplies the confirmation URL.
                    result["url"]=trustedURL
                    if var components=URLComponents(string:trustedURL) {
                        components.path="";components.query=nil;components.fragment=nil
                        result["origin"]=components.string ?? ""
                    }
                    continuation.resume(returning:result)
                }
            }
        }
    }
}
