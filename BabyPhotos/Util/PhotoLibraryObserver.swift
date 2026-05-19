import Foundation
@preconcurrency import Photos

@MainActor
final class PhotoLibraryObserver: NSObject, PHPhotoLibraryChangeObserver {
    var onLibraryChanged: (() -> Void)?

    func startObserving() {
        PHPhotoLibrary.shared().register(self)
    }

    func stopObserving() {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            onLibraryChanged?()
        }
    }
}
