import SwiftUI
@preconcurrency import Photos

struct AlbumGridThumbnail: View {
    let media: BabyAlbumMedia
    var size: CGFloat = 120

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay {
                            ProgressView()
                        }
                }
            }
            .frame(width: size, height: size)
            .clipped()

            if media.isVideo {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(radius: 2)
                    .padding(6)
            }
        }
        .task(id: media.loadKey) {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [media.loadKey], options: nil)
        guard let asset = assets.firstObject else { return }

        let image: UIImage? = await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
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
            thumbnail = image
        }
    }
}
