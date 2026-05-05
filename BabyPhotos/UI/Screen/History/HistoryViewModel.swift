import Foundation
import SwiftData
@preconcurrency import Photos

enum HistoryFilter: String, CaseIterable {
    case all = "全部"
    case baby = "宝宝"
    case confirmed = "已确认"
    case ignored = "已忽略"
}

@Observable
@MainActor
final class HistoryViewModel {
    var uiState = HistoryUiState()

    struct HistoryUiState {
        var allItems: [ImageAnalysisEntity] = []
        var filter: HistoryFilter = .all
        var movingItemIds: Set<String> = []
        var userMessage: String?
        var selectedEntity: ImageAnalysisEntity?
        var showRemoveConfirm = false
        var showCleanConfirm = false
    }

    var filteredItems: [ImageAnalysisEntity] {
        switch uiState.filter {
        case .all:
            return uiState.allItems
        case .baby:
            return uiState.allItems.filter { $0.containsBaby }
        case .confirmed:
            return uiState.allItems.filter { $0.classificationAction == .autoAdd && $0.containsBaby }
        case .ignored:
            return uiState.allItems.filter { $0.classificationAction == .ignore }
        }
    }

    private var repository: AnalysisRepository?

    func setup(repository: AnalysisRepository) {
        self.repository = repository
        loadHistory()
    }

    func loadHistory() {
        guard let repository else { return }
        do {
            uiState.allItems = try repository.fetchAll()
        } catch {
            print("Failed to load history: \(error)")
        }
    }

    func setFilter(_ filter: HistoryFilter) {
        uiState.filter = filter
    }

    func moveToBabyAlbum(_ entity: ImageAnalysisEntity) {
        guard let repository, !uiState.movingItemIds.contains(entity.id) else { return }
        uiState.movingItemIds.insert(entity.id)

        Task {
            do {
                try await repository.confirmAndMove(entity: entity)
                await MainActor.run {
                    uiState.movingItemIds.remove(entity.id)
                    uiState.userMessage = "已移动到宝宝相册"
                    loadHistory()
                }
            } catch {
                await MainActor.run {
                    uiState.movingItemIds.remove(entity.id)
                    uiState.userMessage = "移动失败：\(error.localizedDescription)"
                }
            }
        }
    }

    func removeFromBabyAlbum(_ entity: ImageAnalysisEntity) {
        guard let repository, !uiState.movingItemIds.contains(entity.id) else { return }
        uiState.movingItemIds.insert(entity.id)

        Task {
            do {
                try await repository.removeFromBabyAlbum(entity: entity)
                await MainActor.run {
                    uiState.movingItemIds.remove(entity.id)
                    uiState.userMessage = "已移回原始位置"
                    loadHistory()
                }
            } catch {
                await MainActor.run {
                    uiState.movingItemIds.remove(entity.id)
                    uiState.userMessage = "移除失败：\(error.localizedDescription)"
                }
            }
        }
    }

    func cleanStaleRecords() {
        guard let repository else { return }
        let allIdentifiers = uiState.allItems.map { $0.path }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: allIdentifiers, options: nil)

        var existingIds = Set<String>()
        assets.enumerateObjects { asset, _, _ in
            existingIds.insert(asset.localIdentifier)
        }

        let staleIds = uiState.allItems
            .filter { !existingIds.contains($0.path) }
            .map { $0.id }

        if staleIds.isEmpty {
            uiState.userMessage = "没有发现已失效的记录"
        } else {
            do {
                try repository.deleteByIds(staleIds)
                uiState.userMessage = "已清理 \(staleIds.count) 条无效记录"
                loadHistory()
            } catch {
                uiState.userMessage = "清理失败：\(error.localizedDescription)"
            }
        }
    }

    func clearUserMessage() {
        uiState.userMessage = nil
    }
}
