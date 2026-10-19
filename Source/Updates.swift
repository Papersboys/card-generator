import AppKit
import Combine
import Sparkle

@MainActor final class UpdateManager:ObservableObject {
    static let shared=UpdateManager()
    let controller:SPUStandardUpdaterController
    @Published private(set) var canCheck=false
    @Published private(set) var automaticChecks=false
    init() {
        controller=SPUStandardUpdaterController(startingUpdater:false,updaterDelegate:nil,userDriverDelegate:nil)
        controller.updater.publisher(for:\.canCheckForUpdates).receive(on:RunLoop.main).assign(to:&$canCheck)
        controller.updater.publisher(for:\.automaticallyChecksForUpdates).receive(on:RunLoop.main).assign(to:&$automaticChecks)
    }
    func start() {controller.startUpdater()}
    func check() {controller.checkForUpdates(nil)}
    func setAutomaticChecks(_ enabled:Bool) {controller.updater.automaticallyChecksForUpdates=enabled}
}
