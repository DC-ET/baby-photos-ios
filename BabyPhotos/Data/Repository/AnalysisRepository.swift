import Foundation
import SwiftData
import CryptoKit
@preconcurrency import Photos
import Observation

@Observable
@MainActor
final class AnalysisRepository {
    private let scanner: PhotoScanner
    private let preprocessor: ImagePreprocessor
    private let videoFrameExtractor: VideoFrameExtractor
    private let recognizer: BabyRecognizer
    private let classifier: ClassificationEngine
    private let albumManager: AlbumManager
    private let modelContainer: ModelContainer
    private let settingsManager: SettingsManager
    private let semaphore: AsyncSemaphore

    init(scanner: PhotoScanner, preprocessor: ImagePreprocessor,
         videoFrameExtractor: VideoFrameExtractor, recognizer: BabyRecognizer,
         classifier: ClassificationEngine, albumManager: AlbumManager,
         modelContainer: ModelContainer, settingsManager: SettingsManager) {
        self.scanner = scanner
        self.preprocessor = preprocessor
        self.videoFrameExtractor = videoFrameExtractor
        self.recognizer = recognizer
        self.classifier = classifier
        self.albumManager = albumManager
        self.modelContainer = modelContainer
        self.settingsManager = settingsManager
        self.semaphore = AsyncSemaphore(limit: settingsManager.concurrencyLimit)
    }

    // MARK: - Core Scan Pipeline

    func runDailyScan(onProgress: (@Sendable (ScanProgress) -> Void)? = nil) async throws -> ScanSummary {
        onProgress?(ScanProgress(phase: .scanningMedia, current: 0, total: 0))

        let effectiveLower = computeEffectiveMediaScanLowerBound(
            configuredStart: settingsManager.scanStartDate ?? Date(),
            snapshotAtLastScan: settingsManager.scanStartDateSnapshotAtLastScan,
            watermark: settingsManager.lastScanMediaDateAddedWatermark
        )

        let scannedPhotos = await scanner.scanPhotos(since: effectiveLower)

        // Deduplicate
        let context = ModelContext(modelContainer)
        var newPhotos: [ScannedPhoto] = []
        for photo in scannedPhotos {
            if try await fetchByPathOrMovedTo(photo.path, context: context) == nil {
                newPhotos.append(photo)
            }
        }

        // Analyze concurrently
        onProgress?(ScanProgress(phase: .analyzing, current: 0, total: newPhotos.count))
        var autoAdded = 0
        var needsConfirmation = 0
        var confirmationItems: [ClassificationDecision] = []
        var analyzedCount = 0

        try await withThrowingTaskGroup(of: ClassificationDecision?.self) { group in
            for photo in newPhotos {
                group.addTask { [self] in
                    await self.semaphore.wait()
                    defer { Task { await self.semaphore.signal() } }
                    do {
                        return try await self.analyzeMedia(photo)
                    } catch {
                        print("Analysis failed for \(photo.path): \(error)")
                        return nil
                    }
                }
            }

            for try await decision in group {
                analyzedCount += 1
                onProgress?(ScanProgress(phase: .analyzing, current: analyzedCount, total: newPhotos.count))
                guard let decision = decision else { continue }

                switch decision.action {
                case .autoAdd:
                    do {
                        try await self.albumManager.addToAlbum(
                            asset: self.fetchAsset(for: decision.photo)
                        )
                        self.persistDecision(decision, movedTo: decision.photo.path, context: context)
                        autoAdded += 1
                    } catch {
                        // Downgrade to needs confirm on move failure
                        self.persistDecision(decision, movedTo: nil, context: context)
                        needsConfirmation += 1
                        confirmationItems.append(decision)
                    }
                case .needsConfirm:
                    self.persistDecision(decision, movedTo: nil, context: context)
                    needsConfirmation += 1
                    confirmationItems.append(decision)
                case .ignore:
                    self.persistDecision(decision, movedTo: nil, context: context)
                }
            }
        }

        onProgress?(ScanProgress(phase: .classifying, current: newPhotos.count, total: newPhotos.count))

        // Update watermark
        let maxDate = newPhotos.map(\.dateAdded).max()
        settingsManager.scanStartDateSnapshotAtLastScan = settingsManager.scanStartDate
        if let maxDate = maxDate {
            settingsManager.lastScanMediaDateAddedWatermark = maxDate
        }

        try context.save()

        return ScanSummary(
            totalScanned: scannedPhotos.count,
            newlyAnalyzed: newPhotos.count,
            autoAdded: autoAdded,
            needsConfirmation: needsConfirmation,
            confirmationItems: confirmationItems
        )
    }

    // MARK: - Analyze Single Media

    private func analyzeMedia(_ photo: ScannedPhoto) async throws -> ClassificationDecision {
        switch photo.mediaType {
        case .image:
            let preprocessed = try await preprocessor.preprocess(
                asset: fetchAsset(for: photo)
            )
            guard !preprocessed.base64Data.isEmpty else {
                throw NSError(domain: "AnalysisRepository", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Preprocessing failed"])
            }
            let result = try await recognizer.recognize(base64Image: preprocessed.base64Data)
            return classifier.classify(photo: photo, result: result)

        case .video:
            return try await analyzeVideo(photo)
        }
    }

    private func analyzeVideo(_ photo: ScannedPhoto) async throws -> ClassificationDecision {
        let frames = try await videoFrameExtractor.extractFrames(from: fetchAsset(for: photo))
        guard !frames.isEmpty else {
            return classifier.classify(
                photo: photo,
                result: BabyDetectionResult(containsBaby: false, confidence: 0, reason: "No frames extracted")
            )
        }

        var bestBabyFrame: ClassificationDecision?
        var bestFallbackFrame: ClassificationDecision?

        for frame in frames {
            let result = try await recognizer.recognize(base64Image: frame.base64Data)
            let decision = classifier.classify(photo: photo, result: result)

            // Early return on AUTO_ADD
            if decision.action == .autoAdd {
                return decision
            }

            if result.containsBaby {
                if bestBabyFrame == nil || result.confidence > (bestBabyFrame?.detectionResult.confidence ?? 0) {
                    bestBabyFrame = decision
                }
            } else {
                if bestFallbackFrame == nil || result.confidence > (bestFallbackFrame?.detectionResult.confidence ?? 0) {
                    bestFallbackFrame = decision
                }
            }
        }

        return bestBabyFrame ?? bestFallbackFrame ?? classifier.classify(
            photo: photo,
            result: BabyDetectionResult(containsBaby: false, confidence: 0, reason: "No valid frames")
        )
    }

    // MARK: - User Actions

    func confirmAndMove(entity: ImageAnalysisEntity) async throws {
        let asset = PHAsset.fetchAssets(withLocalIdentifiers: [entity.path], options: nil).firstObject
        guard let asset = asset else {
            throw NSError(domain: "AnalysisRepository", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Asset not found"])
        }
        try await albumManager.addToAlbum(asset: asset)
        entity.action = ClassificationAction.autoAdd.rawValue
        entity.movedTo = entity.path
        try modelContainer.mainContext.save()
    }

    func reject(entity: ImageAnalysisEntity) {
        entity.action = ClassificationAction.ignore.rawValue
        try? modelContainer.mainContext.save()
    }

    func removeFromBabyAlbum(entity: ImageAnalysisEntity) async throws {
        let asset = PHAsset.fetchAssets(withLocalIdentifiers: [entity.path], options: nil).firstObject
        if let asset = asset {
            try await albumManager.removeFromAlbum(asset: asset)
        }
        entity.action = ClassificationAction.ignore.rawValue
        entity.movedTo = nil
        try modelContainer.mainContext.save()
    }

    // MARK: - Data Access Helpers

    func fetchByPathOrMovedTo(_ path: String, context: ModelContext? = nil) throws -> ImageAnalysisEntity? {
        let ctx = context ?? modelContainer.mainContext
        var descriptor = FetchDescriptor<ImageAnalysisEntity>(
            predicate: #Predicate { $0.path == path || $0.movedTo == path }
        )
        descriptor.fetchLimit = 1
        return try ctx.fetch(descriptor).first
    }

    func fetchById(_ id: String) throws -> ImageAnalysisEntity? {
        var descriptor = FetchDescriptor<ImageAnalysisEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContainer.mainContext.fetch(descriptor).first
    }

    func fetchBabyPhotos() throws -> [ImageAnalysisEntity] {
        var descriptor = FetchDescriptor<ImageAnalysisEntity>(
            predicate: #Predicate { $0.containsBaby == true },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContainer.mainContext.fetch(descriptor)
    }

    func fetchPendingConfirmations() throws -> [ImageAnalysisEntity] {
        var descriptor = FetchDescriptor<ImageAnalysisEntity>(
            predicate: #Predicate { $0.action == "NEEDS_CONFIRM" },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContainer.mainContext.fetch(descriptor)
    }

    func fetchAll() throws -> [ImageAnalysisEntity] {
        let descriptor = FetchDescriptor<ImageAnalysisEntity>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContainer.mainContext.fetch(descriptor)
    }

    func deleteByIds(_ ids: [String]) throws {
        let ctx = modelContainer.mainContext
        for id in ids {
            var descriptor = FetchDescriptor<ImageAnalysisEntity>(
                predicate: #Predicate { $0.id == id }
            )
            descriptor.fetchLimit = 1
            if let entity = try ctx.fetch(descriptor).first {
                ctx.delete(entity)
            }
        }
        try ctx.save()
    }

    // MARK: - Helpers

    private func persistDecision(_ decision: ClassificationDecision, movedTo: String?, context: ModelContext) {
        let hashId = SHA256.hash(data: Data(decision.photo.path.utf8))
        let id = hashId.map { String(format: "%02x", $0) }.joined()

        let entity = ImageAnalysisEntity(
            id: id,
            path: decision.photo.path,
            fileName: decision.photo.fileName,
            mediaType: decision.photo.mediaType.rawValue,
            mimeType: decision.photo.mimeType,
            containsBaby: decision.detectionResult.containsBaby,
            confidence: decision.detectionResult.confidence,
            reason: decision.detectionResult.reason,
            action: decision.action.rawValue,
            timestamp: Date(),
            movedTo: movedTo
        )
        context.insert(entity)
    }

    private func fetchAsset(for photo: ScannedPhoto) -> PHAsset {
        PHAsset.fetchAssets(withLocalIdentifiers: [photo.path], options: nil).firstObject!
    }
}
