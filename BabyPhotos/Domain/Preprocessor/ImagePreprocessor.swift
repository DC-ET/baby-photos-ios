import Foundation
@preconcurrency import Photos
import CoreGraphics
import ImageIO
import UIKit

final class ImagePreprocessor: Sendable {
    private let maxSize: Int
    private let jpegQuality: Int

    init(maxSize: Int = 1024, jpegQuality: Int = 70) {
        self.maxSize = maxSize
        self.jpegQuality = jpegQuality
    }

    func preprocess(asset: PHAsset) async throws -> PreprocessedImage {
        let imageData = try await requestImageData(for: asset)
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let cgImage = downsample(source: source, maxSize: CGFloat(maxSize)) else {
            return PreprocessedImage(originalIdentifier: asset.localIdentifier, base64Data: "", compressedSize: 0)
        }
        return preprocess(cgImage: cgImage, identifier: asset.localIdentifier)
    }

    func preprocess(cgImage: CGImage, identifier: String) -> PreprocessedImage {
        let scaled = scaleImage(cgImage, toMaxSize: CGFloat(maxSize))
        guard let data = compressToJPEG(scaled, quality: CGFloat(jpegQuality) / 100.0) else {
            return PreprocessedImage(originalIdentifier: identifier, base64Data: "", compressedSize: 0)
        }
        let base64 = data.base64EncodedString()
        let dataURI = "data:image/jpeg;base64,\(base64)"
        return PreprocessedImage(
            originalIdentifier: identifier,
            base64Data: dataURI,
            compressedSize: data.count
        )
    }

    private func requestImageData(for asset: PHAsset) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.version = .current
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            PHImageManager.default().requestImageDataAndOrientation(
                for: asset, options: options
            ) { data, _, _, info in
                if let data = data {
                    continuation.resume(returning: data)
                } else {
                    let error = (info?[PHImageErrorKey] as? NSError)
                        ?? NSError(domain: "ImagePreprocessor", code: -1,
                                   userInfo: [NSLocalizedDescriptionKey: "Failed to load image data"])
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func downsample(source: CGImageSource, maxSize: CGFloat) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private func scaleImage(_ cgImage: CGImage, toMaxSize maxSize: CGFloat) -> CGImage {
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        guard width > maxSize || height > maxSize else { return cgImage }

        let scale = min(maxSize / width, maxSize / height)
        let newWidth = Int(width * scale)
        let newHeight = Int(height * scale)

        let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else { return cgImage }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage() ?? cgImage
    }

    private func compressToJPEG(_ cgImage: CGImage, quality: CGFloat) -> Data? {
        let opaque: CGImage
        if cgImage.alphaInfo != .none && cgImage.alphaInfo != .noneSkipFirst && cgImage.alphaInfo != .noneSkipLast {
            let width = cgImage.width
            let height = cgImage.height
            let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            if let context = CGContext(
                data: nil, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo
            ) {
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
                opaque = context.makeImage() ?? cgImage
            } else {
                opaque = cgImage
            }
        } else {
            opaque = cgImage
        }
        let uiImage = UIImage(cgImage: opaque)
        return uiImage.jpegData(compressionQuality: quality)
    }
}
