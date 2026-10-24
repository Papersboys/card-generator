import Foundation
import Combine
import UserNotifications

@MainActor final class NotificationManager:NSObject,ObservableObject,UNUserNotificationCenterDelegate {
    static let shared=NotificationManager()
    @Published private(set) var enabled=UserDefaults.standard.bool(forKey:"linkCardStatusNotifications")
    @Published private(set) var requesting=false
    @Published var message=""
    private let center=UNUserNotificationCenter.current()
    override init() {super.init();center.delegate=self}
    func setEnabled(_ value:Bool) {
        guard !requesting else {return}
        if !value {enabled=false;UserDefaults.standard.set(false,forKey:"linkCardStatusNotifications");message="";return}
        requesting=true
        Task {
            defer {requesting=false}
            do {
                let granted=try await center.requestAuthorization(options:[.alert,.sound])
                enabled=granted;UserDefaults.standard.set(granted,forKey:"linkCardStatusNotifications")
                message=granted ? "通知已开启；App 运行期间约每分钟检查状态。" : "通知未获允许，请在 macOS 系统设置中开启 Link Card 通知。"
            } catch {enabled=false;UserDefaults.standard.set(false,forKey:"linkCardStatusNotifications");message="无法启用系统通知，请在 macOS 系统设置中检查通知权限。"}
        }
    }
    func checkPermission() {
        guard enabled else {return}
        Task {
            let settings=await center.notificationSettings()
            if ![.authorized,.provisional].contains(settings.authorizationStatus) {
                enabled=false;UserDefaults.standard.set(false,forKey:"linkCardStatusNotifications")
                message="通知未获允许，请在 macOS 系统设置中开启 Link Card 通知。"
            }
        }
    }
    func send(_ event:RequestEvent,language:AppLanguage) {
        guard enabled else {return}
        let content=UNMutableNotificationContent();content.title="Link Card"
        content.body=L10n.text(event.message,language:language);content.sound = .default
        center.add(UNNotificationRequest(identifier:UUID().uuidString,content:content,trigger:nil)) {[weak self] error in
            if error != nil {Task {@MainActor in self?.message="系统通知发送失败，请检查 macOS 通知设置。"}}
        }
    }
    nonisolated func userNotificationCenter(_ center:UNUserNotificationCenter,willPresent notification:UNNotification,withCompletionHandler completionHandler:@escaping (UNNotificationPresentationOptions)->Void) {completionHandler([.banner,.sound])}
}
