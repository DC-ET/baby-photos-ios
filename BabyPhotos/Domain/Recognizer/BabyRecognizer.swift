import Foundation

protocol BabyRecognizer: Sendable {
    func recognize(base64Image: String) async throws -> BabyDetectionResult
}
