import SwiftUI

struct AlbumView: View {
    @State private var viewModel = AlbumViewModel()

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.uiState.displayState {
                case .loading:
                    ProgressView("加载中…")
                case .permissionDenied:
                    permissionDeniedView
                case .empty:
                    emptyView
                case .content:
                    albumGrid
                }
            }
            .navigationTitle(
                viewModel.uiState.displayState == .content
                    ? "相册（\(viewModel.totalCount)）"
                    : "相册"
            )
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                viewModel.reload()
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { viewModel.uiState.selectedIndex != nil },
                set: { if !$0 { viewModel.closeViewer() } }
            )
        ) {
            if let index = viewModel.uiState.selectedIndex {
                AlbumViewer(
                    items: viewModel.uiState.flatItems,
                    initialIndex: index,
                    onDismiss: { viewModel.closeViewer() }
                )
            }
        }
    }

    private var albumGrid: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
                ForEach(viewModel.uiState.sections) { section in
                    Section {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(section.items) { media in
                                AlbumGridThumbnail(media: media)
                                    .onTapGesture {
                                        if let index = viewModel.uiState.flatItems.firstIndex(of: media) {
                                            viewModel.openViewer(at: index)
                                        }
                                    }
                            }
                        }
                    } header: {
                        Text(section.title)
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                            .padding(.top, 4)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("需要相册读取权限才能查看宝宝相册")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("授予相册权限") {
                viewModel.requestPhotoPermission()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("宝宝相册还是空的")
                .font(.headline)
            Text("去首页扫描并归档照片后，会显示在这里")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
