import SwiftUI

struct HistoryView: View {
    @Environment(AnalysisRepository.self) private var repository
    @State private var viewModel = HistoryViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(HistoryFilter.allCases, id: \.self) { filter in
                            FilterChip(
                                title: filter.rawValue,
                                isSelected: viewModel.uiState.filter == filter
                            ) {
                                viewModel.setFilter(filter)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                if viewModel.filteredItems.isEmpty {
                    Spacer()
                    Text("暂无记录")
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.filteredItems) { item in
                            HistoryItemCard(entity: item, movingItemIds: viewModel.uiState.movingItemIds)
                                .onTapGesture {
                                    viewModel.uiState.selectedEntity = item
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    swipeActionsContent(for: item)
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("历史记录")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.uiState.showCleanConfirm = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("清理无效记录")
                }
            }
            .onAppear {
                viewModel.setup(repository: repository)
            }
            .sheet(item: Binding(
                get: { viewModel.uiState.selectedEntity },
                set: { viewModel.uiState.selectedEntity = $0 }
            )) { entity in
                HistoryDetailSheet(entity: entity)
            }
            .alert("清理无效记录", isPresented: Binding(
                get: { viewModel.uiState.showCleanConfirm },
                set: { viewModel.uiState.showCleanConfirm = $0 }
            )) {
                Button("清理", role: .destructive) {
                    viewModel.cleanStaleRecords()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将扫描所有历史记录，自动删除对应的图片/视频已从系统相册中移除的条目。此操作不可撤销，是否继续？")
            }
            .onChange(of: viewModel.uiState.userMessage) { _, newValue in
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

    @ViewBuilder
    private func swipeActionsContent(for item: ImageAnalysisEntity) -> some View {
        if item.isInBabyAlbum {
            Button {
                viewModel.removeFromBabyAlbum(item)
            } label: {
                Label("移出相册", systemImage: "arrow.backward")
            }
            .tint(Color.red)
        } else if item.classificationAction == .ignore {
            Button {
                viewModel.moveToBabyAlbum(item)
            } label: {
                Label("移入相册", systemImage: "arrow.forward")
            }
            .tint(Color.green)
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct HistoryItemCard: View {
    let entity: ImageAnalysisEntity
    let movingItemIds: Set<String>

    private var actionColor: Color {
        switch entity.classificationAction {
        case .autoAdd: return .accentColor
        case .needsConfirm: return .purple
        case .ignore: return Color(.systemGray)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            AnalysisMediaThumbnail(entity: entity, size: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(entity.fileName ?? entity.path.components(separatedBy: "/").last ?? entity.path)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(entity.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                ConfidenceBadge(confidence: entity.confidence)
            }

            Spacer()

            if movingItemIds.contains(entity.id) {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text(entity.actionLabel)
                    .font(.caption)
                    .foregroundStyle(actionColor)
            }
        }
        .padding(.vertical, 4)
    }
}

struct HistoryDetailSheet: View {
    let entity: ImageAnalysisEntity
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(entity.fileName ?? entity.path.components(separatedBy: "/").last ?? entity.path)
                        .font(.headline)

                    HistoryDetailMediaPreview(entity: entity)

                    Group {
                        DetailRow(label: "状态", value: entity.actionLabel)
                        DetailRow(label: "类型", value: entity.isVideo ? "视频" : "照片")
                        DetailRow(label: "是否包含宝宝", value: entity.containsBaby ? "是" : "否")
                        DetailRow(label: "置信度", value: "\(entity.confidence)%")
                        DetailRow(label: "分析时间", value: formatDate(entity.timestamp))
                        DetailRow(label: "当前路径", value: entity.path)
                        if entity.movedTo != nil {
                            DetailRow(label: "归档路径", value: entity.movedTo ?? "")
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("识别描述")
                            .font(.subheadline).bold()
                        Text(entity.reason)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
            .navigationTitle("详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .textSelection(.enabled)
        }
    }
}
