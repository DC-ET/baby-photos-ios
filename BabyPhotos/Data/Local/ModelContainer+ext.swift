import Foundation
import SwiftData

extension ModelContainer {
    static func makeDefault() -> ModelContainer {
        let schema = Schema([ImageAnalysisEntity.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    static func makeInMemory() -> ModelContainer {
        let schema = Schema([ImageAnalysisEntity.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create in-memory ModelContainer: \(error)")
        }
    }
}
