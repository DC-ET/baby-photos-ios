import SwiftUI

struct SettingsView: View {
    @Environment(SettingsManager.self) private var settingsManager
    @State private var viewModel = SettingsViewModel()
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case apiBaseUrl, apiKey, modelName, systemPrompt, userPrompt
    }

    var body: some View {
        NavigationStack {
            Form {
                // API Configuration
                Section("API 配置") {
                    TextField("API 地址", text: $viewModel.uiState.apiBaseUrl)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused($focusedField, equals: .apiBaseUrl)

                    SecureField("API Key", text: $viewModel.uiState.apiKey)
                        .focused($focusedField, equals: .apiKey)

                    TextField("模型名称", text: $viewModel.uiState.modelName)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused($focusedField, equals: .modelName)

                    Button {
                        viewModel.testApiConnection()
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.uiState.isTestingApi {
                                ProgressView()
                                    .padding(.trailing, 6)
                                Text("测试中...")
                            } else {
                                Text("测试 API 连接")
                            }
                            Spacer()
                        }
                    }
                    .disabled(viewModel.uiState.isTestingApi)

                    if let result = viewModel.uiState.apiTestResult {
                        switch result {
                        case .success:
                            Text("连接成功，API 可正常使用")
                                .font(.caption)
                                .foregroundStyle(.green)
                        case .failure(let message):
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }

                // Scan Settings
                Section("扫描设置") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("自动添加阈值: \(viewModel.uiState.autoAddThreshold)%")
                        Slider(
                            value: Binding(
                                get: { Double(viewModel.uiState.autoAddThreshold) },
                                set: { viewModel.uiState.autoAddThreshold = Int($0) }
                            ),
                            in: 50...100,
                            step: 1
                        )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("并发数: \(viewModel.uiState.concurrencyLimit)")
                        Slider(
                            value: Binding(
                                get: { Double(viewModel.uiState.concurrencyLimit) },
                                set: { viewModel.uiState.concurrencyLimit = Int($0) }
                            ),
                            in: 1...50,
                            step: 1
                        )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("确认阈值: \(viewModel.uiState.confirmThreshold)%")
                        Slider(
                            value: Binding(
                                get: { Double(viewModel.uiState.confirmThreshold) },
                                set: { viewModel.uiState.confirmThreshold = Int($0) }
                            ),
                            in: 20...79,
                            step: 1
                        )
                    }

                    DatePicker(
                        "扫描起始时间",
                        selection: Binding(
                            get: { viewModel.uiState.scanStartDate ?? Date() },
                            set: { viewModel.uiState.scanStartDate = $0 }
                        ),
                        displayedComponents: .date
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("仅扫描此日期之后添加的照片，避免处理历史照片")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Recognition Prompts
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("System 提示词")
                        TextEditor(text: $viewModel.uiState.systemPrompt)
                            .frame(minHeight: 80)
                            .font(.caption)
                            .scrollDisabled(true)
                            .focused($focusedField, equals: .systemPrompt)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("User 提示词")
                        TextEditor(text: $viewModel.uiState.userPrompt)
                            .frame(minHeight: 40)
                            .font(.caption)
                            .scrollDisabled(true)
                            .focused($focusedField, equals: .userPrompt)
                    }
                } header: {
                    Text("识别提示词")
                } footer: {
                    Text("自定义 AI 识别图片/视频时使用的提示词。留空则使用默认值。")
                }

                // Image Preprocessing
                Section("图片预处理") {
                    Stepper(
                        "最大尺寸 (px): \(viewModel.uiState.maxImageSize)",
                        value: $viewModel.uiState.maxImageSize,
                        in: 512...2048,
                        step: 128
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("JPEG 质量: \(viewModel.uiState.jpegQuality)%")
                        Slider(
                            value: Binding(
                                get: { Double(viewModel.uiState.jpegQuality) },
                                set: { viewModel.uiState.jpegQuality = Int($0) }
                            ),
                            in: 50...90,
                            step: 5
                        )
                    }
                }

                // Save button
                Section {
                    Button {
                        viewModel.saveSettings()
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.uiState.isSaved {
                                Label("已保存", systemImage: "checkmark")
                            } else {
                                Text("保存设置")
                            }
                            Spacer()
                        }
                    }
                    .disabled(viewModel.uiState.isSaved)
                }
            }
            .navigationTitle("设置")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        focusedField = nil
                    }
                }
            }
            .onAppear {
                viewModel.setup(settingsManager: settingsManager)
            }
        }
    }
}
