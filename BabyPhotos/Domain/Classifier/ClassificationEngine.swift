import Foundation

final class ClassificationEngine: Sendable {
    private let autoAddThreshold: Int
    private let confirmThreshold: Int

    init(autoAddThreshold: Int = 80, confirmThreshold: Int = 50) {
        self.autoAddThreshold = autoAddThreshold
        self.confirmThreshold = confirmThreshold
    }

    func classify(photo: ScannedPhoto, result: BabyDetectionResult) -> ClassificationDecision {
        let action: ClassificationAction
        if result.containsBaby && result.confidence >= autoAddThreshold {
            action = .autoAdd
        } else if result.containsBaby && result.confidence >= confirmThreshold {
            action = .needsConfirm
        } else {
            action = .ignore
        }
        return ClassificationDecision(photo: photo, detectionResult: result, action: action)
    }
}
