import SwiftUI
import UserNotifications

@main
struct BusLinkApp: App {
    @UIApplicationDelegateAdaptor(BusLinkDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            DashboardView()
        }
    }
}

final class BusLinkDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
