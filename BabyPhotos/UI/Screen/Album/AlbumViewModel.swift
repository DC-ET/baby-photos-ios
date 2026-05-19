import Foundation
@preconcurrency import Photos

@Observable
@MainActor
final class AlbumViewModel {
    enum DisplayState: Equatable {
        case loading
        case permissionDenied
        case empty
        case content
    }

    struct AlbumUiState: Equatable {
        var displayState: DisplayState = .loading
        var sections: [BabyAlbumDateSection] = []
        var flatItems: [BabyAlbumMedia] = []
        var selectedIndex: Int?
    }

    var uiState = AlbumUiState()

    private let reader = BabyAlbumReader()
    private let libraryObserver = PhotoLibraryObserver()

    init() {
        libraryObserver.onLibraryChanged = { [weak self] in
            self?.reload()
        }
    }

    func onAppear() {
        libraryObserver.startObserving()
        refreshPermissionAndLoad()
    }

    func onDisappear() {
        libraryObserver.stopObserving()
    }

    func refreshPermissionAndLoad() {
        if PhotoPermissionHelper.currentAuthorizationStatus() == .notDetermined {
            Task {
                _ = await PhotoPermissionHelper.requestFullAccess()
                reload()
            }
            return
        }
        reload()
    }

    func requestPhotoPermission() {
        Task {
            _ = await PhotoPermissionHelper.requestFullAccess()
            reload()
        }
    }

    func reload() {
        guard PhotoPermissionHelper.hasFullAccess() else {
            uiState.displayState = .permissionDenied
            uiState.sections = []
            uiState.flatItems = []
            return
        }

        uiState.displayState = .loading
        Task {
            let items = await reader.fetchAllMedia()
            let sections = BabyAlbumDateGrouper.group(items)
            uiState.flatItems = sections.flatMap(\.items)
            uiState.sections = sections
            uiState.displayState = items.isEmpty ? .empty : .content
        }
    }

    func openViewer(at index: Int) {
        uiState.selectedIndex = index
    }

    func closeViewer() {
        uiState.selectedIndex = nil
    }

    var totalCount: Int {
        uiState.flatItems.count
    }
}
