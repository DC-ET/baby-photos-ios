import Foundation

struct BabyDetectionResult: Codable, Sendable {
    let containsBaby: Bool
    let confidence: Int
    let reason: String
}
