import SwiftUI
@preconcurrency import Photos
@preconcurrency import AVKit

struct AlbumViewer: View {
    let items: [BabyAlbumMedia]
    let initialIndex: Int
    let onDismiss: () -> Void

    @State private var currentIndex: Int

    init(items: [BabyAlbumMedia], initialIndex: Int, onDismiss: @escaping () -> Void) {
        self.items = items
        self.initialIndex = initialIndex
        self.onDismiss = onDismiss
        _currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, media in
                    AlbumViewerPage(media: media)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .ignoresSafeArea()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.35))
            }
            .padding(.leading, 16)
            .padding(.top, 8)
        }
    }
}

private struct AlbumViewerPage: View {
    let media: BabyAlbumMedia

    @State private var image: UIImage?
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if media.isVideo {
                if let player {
                    VideoPlayer(player: player)
                        .onAppear { player.play() }
                } else {
                    ProgressView()
                        .tint(.white)
                }
            } else if let image {
                ZoomableImageView(image: image)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: media.loadKey) {
            await loadMedia()
        }
        .onDisappear {
            player?.pause()
        }
    }

    private func loadMedia() async {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [media.loadKey], options: nil)
        guard let asset = assets.firstObject else { return }

        if media.isVideo {
            let avAsset: AVAsset? = await withCheckedContinuation { continuation in
                PHImageManager.default().requestAVAsset(forVideo: asset, options: nil) { result, _, _ in
                    continuation.resume(returning: result)
                }
            }
            await MainActor.run {
                if let avAsset {
                    player = AVPlayer(playerItem: AVPlayerItem(asset: avAsset))
                }
            }
            return
        }

        let loaded: UIImage? = await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
        await MainActor.run {
            image = loaded
        }
    }
}
