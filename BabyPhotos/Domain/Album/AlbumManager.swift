import Foundation
@preconcurrency import Photos

final class AlbumManager: Sendable {
    static let babyAlbumTitle = "宝宝相册"

    /// Returns the baby album if it already exists (does not create).
    static func findBabyAlbumCollection() -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title == %@", babyAlbumTitle)
        let collections = PHAssetCollection.fetchAssetCollections(
            with: .album, subtype: .any, options: fetchOptions
        )
        return collections.firstObject
    }

    /// Fetches the existing baby album or creates a new one.
    private func getOrCreateAlbum() async throws -> PHAssetCollection {
        if let existing = Self.findBabyAlbumCollection() {
            return existing
        }

        // Create new album
        var albumPlaceholder: PHObjectPlaceholder?
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(
                withTitle: Self.babyAlbumTitle
            )
            albumPlaceholder = request.placeholderForCreatedAssetCollection
        }

        guard let placeholder = albumPlaceholder else {
            throw NSError(domain: "AlbumManager", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create album placeholder"])
        }

        let result = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [placeholder.localIdentifier], options: nil
        )
        guard let album = result.firstObject else {
            throw NSError(domain: "AlbumManager", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to fetch created album"])
        }
        return album
    }

    /// Adds a PHAsset to the baby album.
    func addToAlbum(asset: PHAsset) async throws {
        let album = try await getOrCreateAlbum()
        try await PHPhotoLibrary.shared().performChanges {
            let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
            albumChangeRequest?.addAssets([asset] as NSArray)
        }
    }

    /// Removes a PHAsset from the baby album.
    func removeFromAlbum(asset: PHAsset) async throws {
        let album = try await getOrCreateAlbum()
        try await PHPhotoLibrary.shared().performChanges {
            let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
            albumChangeRequest?.removeAssets([asset] as NSArray)
        }
    }

    /// Checks whether a PHAsset is in the baby album.
    func isAssetInAlbum(localIdentifier: String) async -> Bool {
        do {
            let album = try await getOrCreateAlbum()
            let assets = PHAsset.fetchAssets(in: album, options: nil)
            var found = false
            assets.enumerateObjects { asset, _, stop in
                if asset.localIdentifier == localIdentifier {
                    found = true
                    stop.pointee = true
                }
            }
            return found
        } catch {
            return false
        }
    }
}
