import Foundation
@preconcurrency import Photos

final class BabyAlbumReader: Sendable {
    func fetchAllMedia() async -> [BabyAlbumMedia] {
        guard let album = AlbumManager.findBabyAlbumCollection() else {
            return []
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let result = PHAsset.fetchAssets(in: album, options: options)
        var items: [BabyAlbumMedia] = []
        items.reserveCapacity(result.count)

        result.enumerateObjects { asset, _, _ in
            let mediaType: BabyAlbumMediaType = asset.mediaType == .video ? .video : .image
            let createdAt = asset.creationDate ?? Date.distantPast
            items.append(
                BabyAlbumMedia(
                    id: asset.localIdentifier,
                    mediaType: mediaType,
                    createdAt: createdAt,
                    loadKey: asset.localIdentifier
                )
            )
        }
        return items
    }
}
