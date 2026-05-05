import SwiftUI
@preconcurrency import Photos
@preconcurrency import AVKit

private struct AssetWrapper: @unchecked Sendable {
    let asset: AVAsset?
}

struct AnalysisMediaThumbnail: View {
    let entity: ImageAnalysisEntity
    var size: CGFloat = 64

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: size, height: size)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }

            if entity.isVideo {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(radius: 2)
                    .padding(4)
            }
        }
        .task {
            await loadThumbnail()
        }
        .onChange(of: entity.path) {
            Task { await loadThumbnail() }
        }
    }

    private func loadThumbnail() async {
        let identifier = entity.displayPath
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else { return }

        let image = await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: size * 2, height: size * 2),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }

        await MainActor.run {
            self.thumbnail = image
        }
    }
}

struct HistoryDetailMediaPreview: View {
    let entity: ImageAnalysisEntity
    @State private var thumbnail: UIImage?
    @State private var isPlaying = false
    @State private var videoPlayer: AVPlayer?

    var body: some View {
        VStack(spacing: 8) {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(minHeight: 220, maxHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemGray5))
                    .frame(minHeight: 220, maxHeight: 360)
                    .overlay {
                        ProgressView()
                    }
            }

            if entity.isVideo {
                if isPlaying, let player = videoPlayer {
                    VideoPlayer(player: player)
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Button("收起播放器") { isPlaying = false }
                        .font(.caption)
                } else {
                    Button("播放视频") { isPlaying = true }
                        .font(.caption)
                }
            }
        }
        .task {
            await loadFullPreview()
            if entity.isVideo {
                await loadVideoPlayer()
            }
        }
    }

    @MainActor
    private func loadFullPreview() async {
        let identifier = entity.displayPath
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else { return }

        let image: UIImage? = await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(
                for: asset, targetSize: CGSize(width: 1200, height: 1200),
                contentMode: .aspectFit, options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }

        self.thumbnail = image
    }

    @MainActor
    private func loadVideoPlayer() async {
        let identifier = entity.displayPath
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else { return }

        let wrapper: AssetWrapper = await withCheckedContinuation { continuation in
            PHImageManager.default().requestAVAsset(forVideo: asset, options: nil) { result, _, _ in
                continuation.resume(returning: AssetWrapper(asset: result))
            }
        }

        if let avAsset = wrapper.asset {
            self.videoPlayer = AVPlayer(playerItem: AVPlayerItem(asset: avAsset))
        }
    }
}
