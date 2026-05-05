import Foundation

struct ScanSummary: Sendable {
    let totalScanned: Int
    let newlyAnalyzed: Int
    let autoAdded: Int
    let needsConfirmation: Int
    let confirmationItems: [ClassificationDecision]
}

struct PreprocessedImage: Sendable {
    let originalIdentifier: String
    let base64Data: String       // full data URI: "data:image/jpeg;base64,..."
    let compressedSize: Int      // byte count of compressed JPEG
}

enum ScanPhase: Sendable {
    case scanningMedia
    case analyzing
    case classifying
}

struct ScanProgress: Sendable {
    let phase: ScanPhase
    let current: Int
    let total: Int

    var fraction: Double {
        total > 0 ? Double(current) / Double(total) : 0
    }

    var percent: Int {
        Int(fraction * 100)
    }
}
