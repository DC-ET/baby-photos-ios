import Foundation

enum ClassificationAction: String, Sendable {
    case autoAdd = "AUTO_ADD"
    case needsConfirm = "NEEDS_CONFIRM"
    case ignore = "IGNORE"
}

struct ClassificationDecision: Sendable {
    let photo: ScannedPhoto
    let detectionResult: BabyDetectionResult
    let action: ClassificationAction
}
