import SwiftUI

struct HomeView: View {
    @Environment(AnalysisRepository.self) private var repository
    @Environment(SettingsManager.self) private var settingsManager
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Brand header
                    Image(systemName: "figure.2.and.child.holdinghands")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)

                    Text("宝宝相册")
                        .font(.title2).bold()

                    Text("AI 智能识别照片和视频，自动归档")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer().frame(height: 24)

                    // Scan button or progress
                    if viewModel.uiState.isScanning {
                        if let progress = viewModel.uiState.scanProgress, progress.total > 0 {
                            VStack(spacing: 8) {
                                ProgressView(value: progress.fraction)
                                    .progressViewStyle(.linear)
                                let phaseText: String = {
                                    switch progress.phase {
                                    case .scanningMedia: return "正在扫描相册..."
                                    case .analyzing: return "正在识别照片..."
                                    case .classifying: return "正在分类归档..."
                                    }
                                }()
                                Text("\(phaseText) \(progress.current)/\(progress.total) (\(progress.percent)%)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            VStack(spacing: 8) {
                                ProgressView()
                                Text("正在扫描照片和视频...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Button {
                            viewModel.requestStartScan()
                        } label: {
                            Label("立即扫描", systemImage: "magnifyingglass")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!viewModel.uiState.isApiConfigured || !viewModel.uiState.hasPhotoPermission)

                        if !viewModel.uiState.isApiConfigured {
                            Text("请先在设置中配置 API")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        if !viewModel.uiState.hasPhotoPermission {
                            Button("需要相册读取权限才能扫描照片和视频") {
                                viewModel.requestPhotoPermission()
                            }
                            .font(.caption)
                            .foregroundStyle(.red)
                        }
                    }

                    Spacer().frame(height: 24)

                    // Stats card
                    VStack(alignment: .leading, spacing: 8) {
                        Text("统计")
                            .font(.headline)
                        Text("已归档宝宝媒体: \(viewModel.uiState.babyPhotoCount)")
                            .font(.subheadline)
                        if let summary = viewModel.uiState.lastScanSummary {
                            Text("上次扫描: 共\(summary.totalScanned)个, 自动添加\(summary.autoAdded)个, 待确认\(summary.needsConfirmation)个")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 2)

                    // Pending items
                    if !viewModel.uiState.pendingItems.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("待确认照片/视频 (\(viewModel.uiState.pendingItems.count))")
                                    .font(.headline)
                                Spacer()
                                Button("全部跳过") { viewModel.rejectAll() }
                                    .font(.caption)
                                Button("全部确认") { viewModel.confirmAll() }
                                    .font(.caption)
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                            }

                            ForEach(viewModel.uiState.pendingItems) { item in
                                PendingPhotoItemRow(
                                    entity: item,
                                    onConfirm: { viewModel.confirmItem(item) },
                                    onReject: { viewModel.rejectItem(item) }
                                )
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("宝宝相册")
            .onAppear {
                viewModel.setup(
                    repository: repository,
                    settingsManager: settingsManager,
                    modelContainer: modelContext.container
                )
            }
            .alert("设置扫描起始时间", isPresented: Binding(
                get: { viewModel.uiState.showScanStartDateDialog },
                set: { viewModel.uiState.showScanStartDateDialog = $0 }
            )) {
                Button("确定") {
                    viewModel.setScanStartDate(Date())
                }
                Button("取消", role: .cancel) {
                    viewModel.skipScanStartDate()
                }
            } message: {
                Text("请选择开始扫描的日期")
            }
            .onChange(of: viewModel.uiState.userMessage) { _, newValue in
                // Auto-dismiss after a short delay
                if newValue != nil {
                    Task {
                        try? await Task.sleep(for: .seconds(3))
                        viewModel.clearUserMessage()
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let message = viewModel.uiState.userMessage {
                    Text(message)
                        .font(.subheadline)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding()
                        .transition(.move(edge: .bottom))
                }
            }
        }
    }
}

struct PendingPhotoItemRow: View {
    let entity: ImageAnalysisEntity
    let onConfirm: () -> Void
    let onReject: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AnalysisMediaThumbnail(entity: entity, size: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text(entity.fileName ?? entity.path.components(separatedBy: "/").last ?? entity.path)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(entity.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                ConfidenceBadge(confidence: entity.confidence)
            }

            Spacer()

            VStack(spacing: 4) {
                Button("跳过") { onReject() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("添加") { onConfirm() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(8)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.03), radius: 1)
    }
}
