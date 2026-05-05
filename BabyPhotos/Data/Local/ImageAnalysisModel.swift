import Foundation
import SwiftData

@Model
final class ImageAnalysisEntity: @unchecked Sendable {
    @Attribute(.unique) var id: String          // SHA-256 of path
    @Attribute(.unique) var path: String        // PHAsset localIdentifier
    var fileName: String?                       // original filename, e.g. "IMG_1234.HEIC"
    var mediaType: String                       // "IMAGE" / "VIDEO"
    var mimeType: String                        // e.g. "image/jpeg"
    var containsBaby: Bool
    var confidence: Int                         // 0-100
    var reason: String
    var action: String                          // "AUTO_ADD" / "NEEDS_CONFIRM" / "IGNORE"
    var timestamp: Date
    var movedTo: String?                        // localIdentifier when in baby album (non-nil = in album)

    init(id: String, path: String, fileName: String? = nil, mediaType: String, mimeType: String,
         containsBaby: Bool, confidence: Int, reason: String,
         action: String, timestamp: Date, movedTo: String? = nil) {
        self.id = id
        self.path = path
        self.fileName = fileName
        self.mediaType = mediaType
        self.mimeType = mimeType
        self.containsBaby = containsBaby
        self.confidence = confidence
        self.reason = reason
        self.action = action
        self.timestamp = timestamp
        self.movedTo = movedTo
    }
}

extension ImageAnalysisEntity {
    var classificationAction: ClassificationAction {
        ClassificationAction(rawValue: action) ?? .ignore
    }

    var isVideo: Bool {
        mediaType == MediaType.video.rawValue
    }

    var actionLabel: String {
        switch classificationAction {
        case .autoAdd: return "已归档"
        case .needsConfirm: return "待确认"
        case .ignore: return "已忽略"
        }
    }

    var isInBabyAlbum: Bool {
        movedTo != nil
    }

    var displayPath: String {
        movedTo ?? path
    }
}
