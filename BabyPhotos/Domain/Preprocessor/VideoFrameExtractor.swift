import Foundation
@preconcurrency import Photos
@preconcurrency import AVFoundation

final class VideoFrameExtractor: Sendable {
    private let imagePreprocessor: ImagePreprocessor
    private let frameCount: Int

    init(imagePreprocessor: ImagePreprocessor, frameCount: Int = 3) {
        self.imagePreprocessor = imagePreprocessor
        self.frameCount = frameCount
    }

    func extractFrames(from asset: PHAsset) async throws -> [PreprocessedImage] {
        let avAsset = try await requestAVAsset(for: asset)
        guard let duration = try? await avAsset.load(.duration),
              duration.seconds > 0 else {
            return []
        }

        let generator = AVAssetImageGenerator(asset: avAsset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        var frames: [PreprocessedImage] = []

        for index in 1...frameCount {
            let seconds = duration.seconds * Double(index) / Double(frameCount + 1)
            let time = CMTime(seconds: seconds, preferredTimescale: 600)

            do {
                let (cgImage, _) = try await generator.image(at: time)
                let preprocessed = imagePreprocessor.preprocess(
                    cgImage: cgImage,
                    identifier: "\(asset.localIdentifier)#frame=\(Int(seconds * 1000000))"
                )
                if !preprocessed.base64Data.isEmpty {
                    frames.append(preprocessed)
                }
            } catch {
                // Skip failed frames
                continue
            }
        }

        return frames
    }

    private func requestAVAsset(for asset: PHAsset) async throws -> AVAsset {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.version = .current
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestAVAsset(
                forVideo: asset, options: options
            ) { avAsset, _, info in
                if let avAsset = avAsset {
                    continuation.resume(returning: avAsset)
                } else {
                    let error = (info?[PHImageErrorKey] as? NSError)
                        ?? NSError(domain: "VideoFrameExtractor", code: -1,
                                   userInfo: [NSLocalizedDescriptionKey: "Failed to load video asset"])
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
