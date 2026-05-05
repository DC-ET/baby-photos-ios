import Foundation
import SwiftData
@preconcurrency import Photos

@Observable
@MainActor
final class HomeViewModel {
    var uiState = HomeUiState()

    struct HomeUiState {
        var lastScanSummary: ScanSummary?
        var isScanning = false
        var scanProgress: ScanProgress?
        var isConfirming = false
        var isApiConfigured = false
        var hasPhotoPermission = false
        var babyPhotoCount = 0
        var pendingItems: [ImageAnalysisEntity] = []
        var showScanStartDateDialog = false
        var userMessage: String?
    }

    private var repository: AnalysisRepository?
    private var settingsManager: SettingsManager?
    private var modelContainer: ModelContainer?

    func setup(repository: AnalysisRepository, settingsManager: SettingsManager, modelContainer: ModelContainer) {
        self.repository = repository
        self.settingsManager = settingsManager
        self.modelContainer = modelContainer
        refreshState()
    }

    func refreshState() {
        guard let settingsManager, let repository else { return }
        uiState.isApiConfigured = settingsManager.isApiConfigured()
        uiState.hasPhotoPermission = PhotoPermissionHelper.hasFullAccess()

        // Auto-request permission on first launch
        if PhotoPermissionHelper.currentAuthorizationStatus() == .notDetermined {
            requestPhotoPermission()
        }

        reloadCounts()
    }

    func reloadCounts() {
        guard let repository else { return }
        do {
            uiState.babyPhotoCount = try repository.fetchBabyPhotos().count
            uiState.pendingItems = try repository.fetchPendingConfirmations()
        } catch {
            print("Failed to reload counts: \(error)")
        }
    }

    func requestStartScan() {
        guard let settingsManager else { return }
        if settingsManager.scanStartDate == nil {
            uiState.showScanStartDateDialog = true
        } else {
            startScan()
        }
    }

    func setScanStartDate(_ date: Date) {
        settingsManager?.scanStartDate = date
        uiState.showScanStartDateDialog = false
        startScan()
    }

    func skipScanStartDate() {
        settingsManager?.scanStartDate = Date(timeIntervalSince1970: 0)
        uiState.showScanStartDateDialog = false
        startScan()
    }

    func startScan() {
        guard let repository else { return }
        uiState.isScanning = true
        uiState.scanProgress = nil
        uiState.userMessage = nil

        Task {
            do {
                let summary = try await repository.runDailyScan { [weak self] progress in
                    Task { @MainActor in
                        self?.uiState.scanProgress = progress
                    }
                }
                await MainActor.run {
                    uiState.lastScanSummary = summary
                    uiState.isScanning = false
                    uiState.scanProgress = nil
                    reloadCounts()
                }
            } catch {
                await MainActor.run {
                    uiState.isScanning = false
                    uiState.scanProgress = nil
                    uiState.userMessage = "扫描失败: \(error.localizedDescription)"
                }
            }
        }
    }

    func confirmItem(_ entity: ImageAnalysisEntity) {
        guard let repository else { return }
        uiState.isConfirming = true

        Task {
            do {
                try await repository.confirmAndMove(entity: entity)
                await MainActor.run {
                    uiState.isConfirming = false
                    uiState.userMessage = "已添加到宝宝相册"
                    reloadCounts()
                }
            } catch {
                await MainActor.run {
                    uiState.isConfirming = false
                    uiState.userMessage = "添加失败：\(error.localizedDescription)"
                }
            }
        }
    }

    func rejectItem(_ entity: ImageAnalysisEntity) {
        guard let repository else { return }
        repository.reject(entity: entity)
        reloadCounts()
    }

    func confirmAll() {
        guard let repository else { return }
        let items = uiState.pendingItems
        guard !items.isEmpty else { return }
        uiState.isConfirming = true

        Task {
            var failures = 0
            for item in items {
                do {
                    try await repository.confirmAndMove(entity: item)
                } catch {
                    failures += 1
                }
            }
            await MainActor.run {
                uiState.isConfirming = false
                reloadCounts()
                if failures == 0 {
                    uiState.userMessage = "已全部添加到宝宝相册"
                } else {
                    uiState.userMessage = "有 \(failures) 个文件添加失败，请稍后重试"
                }
            }
        }
    }

    func rejectAll() {
        guard let repository else { return }
        for item in uiState.pendingItems {
            repository.reject(entity: item)
        }
        reloadCounts()
    }

    func clearUserMessage() {
        uiState.userMessage = nil
    }

    func requestPhotoPermission() {
        Task {
            let status = await PhotoPermissionHelper.requestFullAccess()
            await MainActor.run {
                uiState.hasPhotoPermission = (status == .authorized || status == .limited)
            }
        }
    }
}
