import Foundation

enum MediaType: String, Codable, Sendable {
    case image = "IMAGE"
    case video = "VIDEO"
}

struct ScannedPhoto: Identifiable, Sendable {
    let id: String       // PHAsset localIdentifier
    let path: String     // same as id on iOS
    let fileName: String // original filename, e.g. "IMG_1234.HEIC"
    let dateAdded: Date
    let mimeType: String
    let mediaType: MediaType
}
