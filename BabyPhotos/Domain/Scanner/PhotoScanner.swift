import Foundation
@preconcurrency import Photos

protocol PhotoScanner: Sendable {
    func scanPhotos(since date: Date?) async -> [ScannedPhoto]
}

final class PHAssetPhotoScanner: PhotoScanner, Sendable {
    func scanPhotos(since date: Date?) async -> [ScannedPhoto] {
        let options = PHFetchOptions()
        var predicates: [NSPredicate] = []

        // Filter for images and videos
        predicates.append(NSPredicate(
            format: "mediaType == %d OR mediaType == %d",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaType.video.rawValue
        ))

        // Filter by date
        if let date = date {
            predicates.append(NSPredicate(format: "creationDate >= %@", date as NSDate))
        }

        options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let assets = PHAsset.fetchAssets(with: options)

        var results: [ScannedPhoto] = []
        assets.enumerateObjects { asset, _, _ in
            let mediaType: MediaType = asset.mediaType == .video ? .video : .image
            let mimeType = self.mimeType(for: asset)
            let fileName = PHAssetResource.assetResources(for: asset).first?.originalFilename ?? "Unknown"
            let scannedPhoto = ScannedPhoto(
                id: asset.localIdentifier,
                path: asset.localIdentifier,
                fileName: fileName,
                dateAdded: asset.creationDate ?? Date(),
                mimeType: mimeType,
                mediaType: mediaType
            )
            results.append(scannedPhoto)
        }

        return results
    }

    private func mimeType(for asset: PHAsset) -> String {
        switch asset.mediaType {
        case .video:
            return "video/mp4"
        case .image:
            // Try to get more specific type from PHAssetResource
            if let resource = PHAssetResource.assetResources(for: asset).first {
                let uti = resource.uniformTypeIdentifier
                if uti.contains("heic") || uti.contains("HEIC") {
                    return "image/heic"
                }
            }
            return "image/jpeg"
        default:
            return "application/octet-stream"
        }
    }
}
