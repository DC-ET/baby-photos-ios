import Foundation
import BackgroundTasks
import UserNotifications

/// Background scan manager using BGTaskScheduler.
/// Note: The actual registration and scheduling is done in BabyPhotosApp.
/// This class provides the notification helper.
enum BackgroundScanManager {
    static let taskIdentifier = "com.babyphotos.daily-scan"

    static func postScanNotification(autoAdded: Int, needsConfirmation: Int) {
        let content = UNMutableNotificationContent()
        content.title = "扫描完成"
        content.body = "发现 \(autoAdded) 张宝宝照片已自动归档，\(needsConfirmation) 张待确认"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "scan-complete-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
