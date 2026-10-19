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
struct LinkError: LocalizedError { let message: String; var errorDescription: String? { message } }
