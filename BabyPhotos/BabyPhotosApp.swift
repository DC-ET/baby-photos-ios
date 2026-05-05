import SwiftUI
import SwiftData
import BackgroundTasks
import UserNotifications

@main
struct BabyPhotosApp: App {
    let repository: AnalysisRepository
    let settingsManager: SettingsManager
    let modelContainer: ModelContainer

    init() {
        let settings = SettingsManager()
        settingsManager = settings

        let container = ModelContainer.makeDefault()
        modelContainer = container

        let scanner = PHAssetPhotoScanner()
        let preprocessor = ImagePreprocessor(
            maxSize: settings.maxImageSize,
            jpegQuality: settings.jpegQuality
        )
        let videoFrameExtractor = VideoFrameExtractor(imagePreprocessor: preprocessor)
        let recognizer = BabyRecognizerImpl(
            apiBaseUrl: settings.apiBaseUrl,
            apiKey: settings.apiKey,
            modelName: settings.modelName,
            systemPrompt: settings.systemPrompt,
            userPrompt: settings.userPrompt
        )
        let classifier = ClassificationEngine(
            autoAddThreshold: settings.autoAddThreshold,
            confirmThreshold: settings.confirmThreshold
        )
        let albumManager = AlbumManager()

        repository = AnalysisRepository(
            scanner: scanner,
            preprocessor: preprocessor,
            videoFrameExtractor: videoFrameExtractor,
            recognizer: recognizer,
            classifier: classifier,
            albumManager: albumManager,
            modelContainer: container,
            settingsManager: settings
        )

        registerBackgroundTask()
        requestNotificationPermission()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
        .environment(repository)
        .environment(settingsManager)
    }

    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.babyphotos.daily-scan",
            using: nil
        ) { task in
            handleDailyScan(task: task as! BGProcessingTask)
        }
        scheduleDailyScan()
    }

    private func scheduleDailyScan() {
        let request = BGProcessingTaskRequest(identifier: "com.babyphotos.daily-scan")
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleDailyScan(task: BGProcessingTask) {
        scheduleDailyScan()

        let operation = Task {
            do {
                let summary = try await repository.runDailyScan()
                postScanNotification(summary: summary)
                task.setTaskCompleted(success: true)
            } catch {
                print("Background scan failed: \(error)")
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            operation.cancel()
        }
    }

    private func postScanNotification(summary: ScanSummary) {
        let content = UNMutableNotificationContent()
        content.title = "扫描完成"
        content.body = "发现 \(summary.autoAdded) 张宝宝照片已自动归档，\(summary.needsConfirmation) 张待确认"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "scan-complete-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
