import Foundation
import CryptoKit

@main struct UpdateTests {
    static func main() throws {
        let root=URL(fileURLWithPath:CommandLine.arguments[1])
        let plist=try PropertyListSerialization.propertyList(from:Data(contentsOf:root.appendingPathComponent("dist/LinkCard.app/Contents/Info.plist")),format:nil) as! [String:Any]
        let version=plist["CFBundleShortVersionString"] as! String
        precondition(plist["SUFeedURL"] as? String == "https://github.com/Papersboys/card-generator/releases/latest/download/appcast.xml")
        precondition(plist["SURequireSignedFeed"] as? Bool == true && plist["SUVerifyUpdateBeforeExtraction"] as? Bool == true)
        precondition(plist["SUAutomaticallyUpdate"] as? Bool == false)
        let publicKey=try Curve25519.Signing.PublicKey(rawRepresentation:Data(base64Encoded:plist["SUPublicEDKey"] as! String)!)
        let feed=try Data(contentsOf:root.appendingPathComponent("dist/appcast.xml"))
        let xml=String(decoding:feed,as:UTF8.self)
        func capture(_ pattern:String)->String {
            let regex=try! NSRegularExpression(pattern:pattern)
            let match=regex.firstMatch(in:xml,range:NSRange(xml.startIndex...,in:xml))!
            return String(xml[Range(match.range(at:1),in:xml)!])
        }
        let archive=try Data(contentsOf:root.appendingPathComponent("dist/LinkCard-macos-arm64.zip"))
        let archiveSignature=Data(base64Encoded:capture("sparkle:edSignature=\"([^\"]+)\""))!
        precondition(publicKey.isValidSignature(archiveSignature,for:archive))
        var tampered=archive;tampered[0] ^= 1
        precondition(!publicKey.isValidSignature(archiveSignature,for:tampered))
        let feedSignature=Data(base64Encoded:capture("edSignature: ([A-Za-z0-9+/=]+)"))!
        let signedLength=Int(capture("length: ([0-9]+)"))!
        precondition(publicKey.isValidSignature(feedSignature,for:feed.prefix(signedLength)))
        precondition(xml.contains("/releases/download/v\(version)/LinkCard-macos-arm64.zip"))
        precondition(xml.contains("length=\"\(archive.count)\""))
        precondition(xml.contains("<sparkle:version>\(plist["CFBundleVersion"]!)</sparkle:version>"))
        print("PASS: signed feed and archive match embedded public key; tampered archives rejected; release URLs and versions match")
    }
}
