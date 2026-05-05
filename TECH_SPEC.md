# 宝宝相册 iOS 版 — 技术方案

## 1. 项目目标

将 Android 版「宝宝相册」移植为同款 iPhone 应用。核心功能保持一致：

- 扫描手机相册中的照片和视频
- 通过兼容 OpenAI Vision 的接口识别是否包含 0-3 岁婴幼儿
- 高置信度照片自动归档到「宝宝相册」相簿
- 中等置信度照片交由用户确认
- 增量扫描，避免重复调用 API
- 照片移动（非复制），节省存储空间

---

## 2. 技术栈选型

| 类别 | iOS 方案 | 对应 Android 方案 |
|---|---|---|
| 语言 | Swift 6 | Kotlin 2.1 |
| UI 框架 | SwiftUI + iOS 原生组件 | Jetpack Compose + Material 3 |
| 导航 | NavigationStack (iOS 16+) | Navigation Compose |
| 本地数据库 | SwiftData (iOS 17+) | Room + KSP |
| 网络层 | URLSession (原生) | OkHttp |
| 图片加载 | AsyncImage (SwiftUI 原生) + PhotosUI | Coil Compose |
| 视频播放 | AVKit / VideoPlayer | Media3 ExoPlayer |
| 偏好设置 | UserDefaults (封装为 SettingsManager) | SharedPreferences |
| 并发 | Swift Concurrency (async/await, TaskGroup) | Kotlin Coroutines + Semaphore |
| 后台任务 | BGTaskScheduler | WorkManager |
| JSON 解析 | Foundation JSONSerialization / Codable | org.json.JSONObject |
| 图片处理 | Core Graphics / UIImage | BitmapFactory |
| 视频帧提取 | AVFoundation (AVAssetImageGenerator) | MediaMetadataRetriever |

### 最低版本要求

- **最低支持**: iOS 17.0（SwiftData 要求 iOS 17+，覆盖 ~90% 活跃设备）
- **推荐目标**: iOS 18.0

---

## 3. 项目结构

```
baby-photos-ios/
├── BabyPhotos.xcodeproj
├── BabyPhotos/
│   ├── BabyPhotosApp.swift                 # App 入口，依赖组装
│   ├── ContentView.swift                   # TabView 根视图
│   │
│   ├── Data/
│   │   ├── Local/
│   │   │   ├── ImageAnalysisModel.swift    # SwiftData @Model
│   │   │   └── ModelContainer+ext.swift    # ModelContainer 配置与迁移
│   │   └── Repository/
│   │       └── AnalysisRepository.swift    # 核心编排：扫描→识别→分类→归档
│   │
│   ├── Domain/
│   │   ├── Album/
│   │   │   └── AlbumManager.swift          # PHAssetCollection 相簿管理
│   │   ├── Classifier/
│   │   │   └── ClassificationEngine.swift  # 阈值决策逻辑
│   │   ├── Model/
│   │   │   ├── BabyDetectionResult.swift
│   │   │   ├── ClassificationDecision.swift
│   │   │   ├── ScannedPhoto.swift
│   │   │   └── ScanSummary.swift
│   │   ├── Preprocessor/
│   │   │   ├── ImagePreprocessor.swift     # 缩放、压缩、Base64
│   │   │   └── VideoFrameExtractor.swift   # 视频帧提取
│   │   ├── Recognizer/
│   │   │   ├── BabyRecognizer.swift        # 协议
│   │   │   └── BabyRecognizerImpl.swift    # OpenAI Vision API 调用
│   │   └── Scanner/
│   │       ├── PhotoScanner.swift          # 协议 + PHAsset 扫描实现
│   │       └── MediaScanRange.swift        # 增量扫描范围计算
│   │
│   ├── UI/
│   │   ├── Navigation/
│   │   │   └── AppTabView.swift            # TabView + 标签栏
│   │   ├── Component/
│   │   │   ├── AnalysisMediaPreview.swift  # 图片/视频预览组件
│   │   │   ├── ConfidenceBadge.swift       # 置信度徽章
│   │   │   ├── ConfirmDialog.swift         # 确认弹窗
│   │   │   └── PhotoGridItem.swift         # 照片网格项
│   │   ├── Screen/
│   │   │   ├── Home/
│   │   │   │   ├── HomeView.swift
│   │   │   │   └── HomeViewModel.swift
│   │   │   ├── History/
│   │   │   │   ├── HistoryView.swift
│   │   │   │   └── HistoryViewModel.swift
│   │   │   └── Settings/
│   │   │       ├── SettingsView.swift
│   │   │       └── SettingsViewModel.swift
│   │   └── Theme/
│   │       ├── Color+ext.swift
│   │       └── Theme.swift
│   │
│   ├── Util/
│   │   ├── PhotoPermissionHelper.swift     # 相册权限请求
│   │   ├── SettingsManager.swift           # UserDefaults 封装
│   │   └── VideoThumbnailHelper.swift      # 视频缩略图生成
│   │
│   └── Resources/
│       ├── Assets.xcassets
│       └── Info.plist
│
└── BabyPhotosTests/
    └── MediaScanRangeTests.swift
```

---

## 4. 架构设计

### 4.1 分层架构

与 Android 版保持一致的分层：

```
┌─────────────────────────────┐
│         UI Layer            │  SwiftUI Views + ViewModels (ObservableObject)
├─────────────────────────────┤
│      Repository Layer       │  AnalysisRepository（流程编排）
├─────────────────────────────┤
│       Domain Layer          │  Scanner / Preprocessor / Recognizer / Classifier / AlbumManager
├─────────────────────────────┤
│        Data Layer           │  SwiftData (ModelContainer) + UserDefaults
└─────────────────────────────┘
```

### 4.2 依赖组装

不引入第三方 DI 框架。在 `BabyPhotosApp.swift` 中手动组装所有依赖，与 Android 版 `BabyPhotosApp` 模式一致：

```swift
@main
struct BabyPhotosApp: App {
    // 手动组装依赖
    private let settingsManager: SettingsManager
    private let scanner: PhotoScanner
    private let preprocessor: ImagePreprocessor
    private let videoFrameExtractor: VideoFrameExtractor
    private let recognizer: BabyRecognizer
    private let classifier: ClassificationEngine
    private let albumManager: AlbumManager
    private let repository: AnalysisRepository

    init() {
        // 组装依赖链
        // ...
    }

    var body: some Scene {
        WindowGroup {
            ContentView(repository: repository, settingsManager: settingsManager)
        }
    }
}
```

### 4.3 状态管理

每个页面使用 `@Observable` (iOS 17+) 或 `ObservableObject` + `@Published` 持有 UI 状态：

```swift
@Observable
class HomeViewModel {
    var uiState = HomeUiState()
    // ...
}

struct HomeUiState {
    var babyPhotoCount: Int = 0
    var lastScanSummary: ScanSummary?
    var isScanning: Bool = false
    var scanProgress: String = ""
    var pendingConfirmations: [ClassificationDecision] = []
    var showPermissionAlert: Bool = false
    // ...
}
```

---

## 5. 权限方案

### 5.1 相册访问权限

iOS 14+ 引入了分级相册权限。本应用需要**完整访问权限**（Full Access）才能扫描所有照片。

| 权限 | Info.plist Key | 说明 |
|---|---|---|
| 相册读取 | `NSPhotoLibraryUsageDescription` | 基础权限声明 |
| 相册完整访问 | `NSPhotoLibraryFullAccessUsageDescription` | iOS 17+ 扫描全部照片需要 |
| 添加到相册 | `PHPhotoLibrary.shared().performChanges` | 移动照片到宝宝相簿 |

**权限请求流程：**

```
用户点击「开始扫描」
  → 检查 PHAuthorizationStatus
  → .notDetermined → 请求 .readWrite
  → .limited → 提示需要完整访问，引导到设置
  → .authorized → 继续扫描
  → .denied / .restricted → 提示去设置开启
```

### 5.2 网络权限

iOS 不需要显式声明网络权限，但需要在 App Transport Security 中允许 HTTPS 连接（默认已允许）。用户自定义的 API Base URL 需确保为 HTTPS。

### 5.3 后台任务权限

在 Info.plist 中声明 `BGTaskSchedulerPermittedIdentifiers`，用于后台定期扫描。

---

## 6. 核心数据模型

### 6.1 SwiftData Model

```swift
import SwiftData
import Foundation

@Model
class ImageAnalysisEntity {
    @Attribute(.unique) var id: String          // SHA-256(file path)
    @Attribute(.unique) var path: String        // 扫描时的原始路径 (PHAsset localIdentifier)
    var mediaType: String                       // "IMAGE" / "VIDEO"
    var mimeType: String                        // e.g. "image/jpeg"
    var containsBaby: Bool
    var confidence: Int                         // 0-100
    var reason: String                          // AI 生成的说明
    var action: String                          // "AUTO_ADD" / "NEEDS_CONFIRM" / "IGNORE"
    var timestamp: Date                         // 分析时间
    var movedTo: String?                        // 移动到宝宝相簿后的 localIdentifier

    init(id: String, path: String, mediaType: String, mimeType: String,
         containsBaby: Bool, confidence: Int, reason: String,
         action: String, timestamp: Date, movedTo: String? = nil) {
        self.id = id
        self.path = path
        self.mediaType = mediaType
        self.mimeType = mimeType
        self.containsBaby = containsBaby
        self.confidence = confidence
        self.reason = reason
        self.action = action
        self.timestamp = timestamp
        self.movedTo = movedTo
    }
}
```

### 6.2 Domain Models

```swift
enum MediaType: String, Codable {
    case image = "IMAGE"
    case video = "VIDEO"
}

struct ScannedPhoto: Identifiable {
    let id: String            // PHAsset localIdentifier
    let path: String          // localIdentifier 作为路径标识
    let dateAdded: Date
    let mimeType: String
    let mediaType: MediaType
}

struct BabyDetectionResult {
    let containsBaby: Bool
    let confidence: Int
    let reason: String
}

enum ClassificationAction {
    case autoAdd
    case needsConfirm
    case ignore
}

struct ClassificationDecision {
    let photo: ScannedPhoto
    let detectionResult: BabyDetectionResult
    let action: ClassificationAction
}

struct ScanSummary {
    let totalScanned: Int
    let newlyAnalyzed: Int
    let autoAdded: Int
    let needsConfirmation: Int
    let confirmationItems: [ClassificationDecision]
}

struct PreprocessedImage {
    let originalIdentifier: String
    let base64Data: String
    let compressedSize: Int
}
```

---

## 7. 核心模块设计

### 7.1 PhotoScanner — 相册扫描

**Android 对应**: `MediaStorePhotoScanner` (通过 MediaStore 查询)

**iOS 实现**: 使用 `PHFetchOptions` + `PHAsset` 查询系统相册。

```swift
protocol PhotoScanner {
    func scanPhotos(since date: Date) -> [ScannedPhoto]
}

class PHAssetPhotoScanner: PhotoScanner {
    func scanPhotos(since date: Date) -> [ScannedPhoto] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d OR mediaType == %d",
                                         PHAssetMediaType.image.rawValue,
                                         PHAssetMediaType.video.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let assets = PHAsset.fetchAssets(with: options)
        // 过滤 creationDate >= date 的资产
        // 转换为 [ScannedPhoto]
    }
}
```

**关键差异**:
- Android 使用 MediaStore 的 `DATE_ADDED` 列；iOS 使用 `PHAsset.creationDate`
- iOS 的 `PHAsset.localIdentifier` 作为唯一标识，替代 Android 的 MediaStore `_ID`
- 增量扫描水位线存储 `creationDate` 而非 `DATE_ADDED`

### 7.2 ImagePreprocessor — 图片预处理

**Android 对应**: `ImagePreprocessor` (BitmapFactory 解码 + Canvas 缩放 + JPEG 压缩 + Base64)

**iOS 实现**: 使用 `UIImage` + Core Graphics。

```swift
class ImagePreprocessor {
    private let maxSize: CGFloat
    private let jpegQuality: CGFloat

    func preprocess(asset: PHAsset) async throws -> PreprocessedImage {
        // 1. 通过 PHImageManager 请求图片数据
        // 2. UIImage 下采样（避免一次性加载全尺寸）
        // 3. 缩放到 maxSize
        // 4. JPEG 压缩
        // 5. Base64 编码
        // 6. 包装为 data:image/jpeg;base64,... 格式
    }
}
```

**关键差异**:
- Android 使用 `BitmapFactory.Options.inSampleSize` 进行下采样；iOS 使用 `CGImageSource` 的 `kCGImageSourceThumbnailMaxPixelSize` 进行高效下采样
- Android 使用 `Bitmap.compress()`；iOS 使用 `UIImage.jpegData(compressionQuality:)`

### 7.3 VideoFrameExtractor — 视频帧提取

**Android 对应**: `VideoFrameExtractor` (MediaMetadataRetriever)

**iOS 实现**: 使用 `AVAssetImageGenerator`。

```swift
class VideoFrameExtractor {
    private let imagePreprocessor: ImagePreprocessor

    func extractFrames(from asset: PHAsset) async throws -> [PreprocessedImage] {
        // 1. 通过 PHImageManager 获取 AVAsset
        // 2. 创建 AVAssetImageGenerator
        // 3. 在 3 个均匀时间点提取 CGImage
        // 4. 每帧通过 ImagePreprocessor 预处理
    }
}
```

**关键差异**:
- Android 使用 `MediaMetadataRetriever.getFrameAtTime()`；iOS 使用 `AVAssetImageGenerator.copyCGImage(at:actualTime:)`
- iOS 需要通过 `PHImageManager.requestAVAsset` 获取视频资产

### 7.4 BabyRecognizerImpl — 视觉识别

**Android 对应**: `BabyRecognizerImpl` (OkHttp + org.json)

**iOS 实现**: 使用 `URLSession` + `JSONSerialization`。

```swift
class BabyRecognizerImpl: BabyRecognizer {
    private let settingsManager: SettingsManager
    private let session: URLSession

    func recognize(image: PreprocessedImage) async throws -> BabyDetectionResult {
        // 1. 构建 OpenAI Chat Completions 请求体
        // 2. POST 到 {apiBaseUrl}/v1/chat/completions
        // 3. 解析响应 JSON
        // 4. 处理 markdown code block 包裹的 JSON
        // 5. 返回 BabyDetectionResult
    }
}
```

**请求格式**（与 Android 完全一致）:

```json
{
    "model": "{modelName}",
    "messages": [
        {"role": "system", "content": "{systemPrompt}"},
        {"role": "user", "content": [
            {"type": "text", "text": "{userPrompt}"},
            {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,..."}}
        ]}
    ],
    "max_tokens": 300,
    "temperature": 0.1
}
```

**响应解析**（兼容 markdown code block）:

```swift
func parseResponse(_ content: String) -> BabyDetectionResult {
    var jsonStr = content.trimmingCharacters(in: .whitespacesAndNewlines)
    // 去掉 ```json ... ``` 包裹
    if jsonStr.hasPrefix("```") {
        // 提取 code block 内容
    }
    // 解析 JSON
}
```

### 7.5 ClassificationEngine — 分类引擎

**Android 对应**: `ClassificationEngine`

**iOS 实现**: 纯逻辑，与平台无关。

```swift
class ClassificationEngine {
    private let autoAddThreshold: Int
    private let confirmThreshold: Int

    func classify(photo: ScannedPhoto, result: BabyDetectionResult) -> ClassificationDecision {
        let action: ClassificationAction
        if result.containsBaby && result.confidence >= autoAddThreshold {
            action = .autoAdd
        } else if result.containsBaby && result.confidence >= confirmThreshold {
            action = .needsConfirm
        } else {
            action = .ignore
        }
        return ClassificationDecision(photo: photo, detectionResult: result, action: action)
    }
}
```

### 7.6 AlbumManager — 相簿管理

**Android 对应**: `AlbumManager` (文件系统移动 + MediaStore 刷新)

**iOS 实现**: 使用 Photos Framework (`PHAssetCollection` + `PHAssetChangeRequest`)。

```swift
class AlbumManager {
    private let albumName = "宝宝相册"

    /// 获取或创建「宝宝相册」自定义相簿
    private func getOrCreateAlbum() -> PHAssetCollection? {
        // 1. 查找已存在的同名相簿
        // 2. 不存在则创建
    }

    /// 将资产移动到宝宝相簿（添加到相簿，从相机胶卷移除）
    func moveToAlbum(asset: PHAsset) async throws {
        guard let album = getOrCreateAlbum() else { return }
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest(for: asset)
            let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
            albumChangeRequest?.addAssets([asset] as NSArray)
            // 可选：从「最近项目」移除（需用户确认，iOS 不支持真正的「移动」）
        }
    }

    /// 将资产从宝宝相簿移回（从相簿移除）
    func removeFromAlbum(asset: PHAsset) async throws {
        guard let album = getOrCreateAlbum() else { return }
        try await PHPhotoLibrary.shared().performChanges {
            let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
            albumChangeRequest?.removeAssets([asset] as NSArray)
        }
    }
}
```

**关键差异**:
- Android 通过文件系统 `File.renameTo()` 实现真正的移动；iOS 的 Photos Framework 只能「添加到相簿」和「从相簿移除」，原图始终保留在「最近项目」中
- Android 使用文件路径标识；iOS 使用 `PHAsset.localIdentifier`
- iOS 需要通过 `PHPhotoLibrary.shared().performChanges` 在事务中操作

**设计决策**: iOS 版采用「添加到宝宝相簿 + 从宝宝相簿移除」的模式。原图始终保留在系统相册中，「宝宝相簿」作为分类视图。这与 Android 版的「移动文件到 BabyAlbum 目录」在用户感知上类似，但技术实现不同。

### 7.7 AnalysisRepository — 核心编排

**Android 对应**: `AnalysisRepository`

**iOS 实现**: 使用 Swift Concurrency (async/await + TaskGroup)。

```swift
class AnalysisRepository {
    private let scanner: PhotoScanner
    private let preprocessor: ImagePreprocessor
    private let videoFrameExtractor: VideoFrameExtractor
    private let recognizer: BabyRecognizer
    private let classifier: ClassificationEngine
    private let albumManager: AlbumManager
    private let modelContext: ModelContext
    private let settingsManager: SettingsManager

    func runDailyScan() async throws -> ScanSummary {
        // 1. 扫描照片（PHAsset 查询，since 最后扫描水位线）
        // 2. 去重（检查 SwiftData 中已有的记录）
        // 3. 并发识别（TaskGroup，最大并发数 4）
        //    - 图片：预处理 → 识别
        //    - 视频：提取 3 帧 → 逐帧识别 → 取最佳结果
        // 4. 分类（ClassificationEngine）
        // 5. 自动归档（AUTO_ADD → AlbumManager）
        // 6. 持久化（SwiftData 写入）
        // 7. 更新扫描水位线
    }
}
```

**并发控制**（替代 Android 的 `Semaphore(4)`）:

```swift
// 使用 TaskGroup + Semaphore-like 模式
func analyzeWithConcurrencyLimit<T>(
    items: [ScannedPhoto],
    maxConcurrency: Int = 4,
    handler: @escaping (ScannedPhoto) async throws -> T
) async throws -> [T] {
    // 使用 AsyncSemaphore 或手动限制 TaskGroup 并发数
}
```

> **注意**: Swift 标准库没有内置 Semaphore。可使用 `DispatchSemaphore`（阻塞式）或自定义 `AsyncSemaphore`（基于 continuation）来限制并发。推荐后者以避免阻塞主线程。

---

## 8. UI 设计

### 8.1 页面结构

与 Android 版完全一致，3 个 Tab：

| Tab | 图标 | 标题 | 功能 |
|---|---|---|---|
| 首页 | `house.fill` | 宝宝相册 | 品牌展示、开始扫描、统计、待确认列表 |
| 历史 | `clock.fill` | 历史记录 | 分类筛选、滑动操作、详情弹窗 |
| 设置 | `gearshape.fill` | 设置 | API 配置、阈值、提示词、预处理参数 |

### 8.2 HomeView

```swift
struct HomeView: View {
    @State private var viewModel: HomeViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 品牌区域：宝宝图标 + 标题 + 副标题
                    BrandHeaderView()

                    // 开始扫描按钮
                    Button("开始扫描") { viewModel.startScan() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.canScan)

                    // 统计卡片
                    StatsCardView(
                        babyCount: viewModel.uiState.babyPhotoCount,
                        summary: viewModel.uiState.lastScanSummary
                    )

                    // 待确认列表
                    if !viewModel.uiState.pendingConfirmations.isEmpty {
                        PendingConfirmationSection(
                            items: viewModel.uiState.pendingConfirmations,
                            onConfirmAll: viewModel.confirmAll,
                            onRejectAll: viewModel.rejectAll
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("宝宝相册")
        }
    }
}
```

### 8.3 HistoryView

```swift
struct HistoryView: View {
    @State private var viewModel: HistoryViewModel

    var body: some View {
        NavigationStack {
            VStack {
                // 筛选 Chips
                FilterChipsView(selected: $viewModel.selectedFilter)

                // 历史列表
                List {
                    ForEach(viewModel.filteredItems) { item in
                        HistoryItemRow(item: item)
                            .swipeActions(edge: .trailing) {
                                Button(viewModel.isInAlbum(item) ? "移出相簿" : "加入相簿") {
                                    viewModel.toggleAlbumStatus(item)
                                }
                            }
                            .onTapGesture {
                                viewModel.showDetail(item)
                            }
                    }
                }
            }
            .navigationTitle("历史记录")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("清理过期记录") { viewModel.cleanStaleRecords() }
                }
            }
            .sheet(item: $viewModel.selectedItem) { item in
                HistoryDetailView(item: item)
            }
        }
    }
}
```

### 8.4 SettingsView

```swift
struct SettingsView: View {
    @State private var viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            Form {
                // API 配置
                Section("API 配置") {
                    TextField("Base URL", text: $viewModel.apiBaseUrl)
                    SecureField("API Key", text: $viewModel.apiKey)
                    TextField("模型名称", text: $viewModel.modelName)
                }

                // 扫描设置
                Section("扫描设置") {
                    VStack(alignment: .leading) {
                        Text("自动添加阈值: \(viewModel.autoAddThreshold)%")
                        Slider(value: ..., in: 50...100, step: 1)
                    }
                    VStack(alignment: .leading) {
                        Text("确认阈值: \(viewModel.confirmThreshold)%")
                        Slider(value: ..., in: 20...79, step: 1)
                    }
                    DatePicker("扫描起始日期", selection: $viewModel.scanStartDate, displayedComponents: .date)
                }

                // 识别提示词
                Section("识别提示词") {
                    TextField("系统提示词", text: $viewModel.systemPrompt, axis: .vertical)
                    TextField("用户提示词", text: $viewModel.userPrompt, axis: .vertical)
                }

                // 图片预处理
                Section("图片预处理参数") {
                    Stepper("最大尺寸: \(viewModel.maxImageSize)px",
                            value: $viewModel.maxImageSize, in: 512...2048, step: 128)
                    VStack(alignment: .leading) {
                        Text("JPEG 压缩质量: \(Int(viewModel.jpegQuality * 100))%")
                        Slider(value: $viewModel.jpegQuality, in: 0.5...0.9, step: 0.05)
                    }
                }

                // 保存
                Button("保存设置") { viewModel.save() }
            }
            .navigationTitle("设置")
        }
    }
}
```

---

## 9. 后台任务

### 9.1 BGTaskScheduler

使用 iOS 的 `BGTaskScheduler` 实现每日后台扫描，对应 Android 版的 WorkManager。

```swift
// 注册后台任务
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.babyphotos.daily-scan",
    using: nil
) { task in
    handleDailyScan(task: task as! BGProcessingTask)
}

// 调度每日任务
func scheduleDailyScan() {
    let request = BGProcessingTaskRequest(identifier: "com.babyphotos.daily-scan")
    request.requiresNetworkConnectivity = true
    request.requiresExternalPower = false
    try? BGTaskScheduler.shared.submit(request)
}
```

> **注意**: iOS 的后台任务执行时机由系统决定，不像 Android WorkManager 那样精确。后台扫描结果通过本地通知推送给用户。

### 9.2 本地通知

扫描完成后通过 `UNUserNotificationCenter` 发送本地通知：

```swift
func postScanNotification(summary: ScanSummary) {
    let content = UNMutableNotificationContent()
    content.title = "扫描完成"
    content.body = "发现 \(summary.autoAdded) 张宝宝照片已自动归档，\(summary.needsConfirmation) 张待确认"
    content.sound = .default

    let request = UNNotificationRequest(
        identifier: "scan-complete",
        content: content,
        trigger: nil  // 立即发送
    )
    UNUserNotificationCenter.current().add(request)
}
```

---

## 10. 配置存储

### SettingsManager

```swift
class SettingsManager {
    private let defaults = UserDefaults.standard

    // API 配置
    var apiBaseUrl: String {
        get { defaults.string(forKey: "apiBaseUrl") ?? "" }
        set { defaults.setValue(newValue, forKey: "apiBaseUrl") }
    }
    var apiKey: String {
        get { defaults.string(forKey: "apiKey") ?? "" }
        set { defaults.setValue(newValue, forKey: "apiKey") }
    }
    var modelName: String {
        get { defaults.string(forKey: "modelName") ?? "gpt-4o" }
        set { defaults.setValue(newValue, forKey: "modelName") }
    }

    // 扫描设置
    var autoAddThreshold: Int {
        get { defaults.integer(forKey: "autoAddThreshold").nonZeroOr(80) }
        set { defaults.setValue(newValue, forKey: "autoAddThreshold") }
    }
    var confirmThreshold: Int {
        get { defaults.integer(forKey: "confirmThreshold").nonZeroOr(50) }
        set { defaults.setValue(newValue, forKey: "confirmThreshold") }
    }

    // 预处理参数
    var maxImageSize: Int {
        get { defaults.integer(forKey: "maxImageSize").nonZeroOr(1024) }
        set { defaults.setValue(newValue, forKey: "maxImageSize") }
    }
    var jpegQuality: Double {
        get { defaults.double(forKey: "jpegQuality").nonZeroOr(0.7) }
        set { defaults.setValue(newValue, forKey: "jpegQuality") }
    }

    // 扫描水位线
    var lastScanDate: Date? {
        get { defaults.object(forKey: "lastScanDate") as? Date }
        set { defaults.setValue(newValue, forKey: "lastScanDate") }
    }

    var scanStartDate: Date {
        get { defaults.object(forKey: "scanStartDate") as? Date ?? Date() }
        set { defaults.setValue(newValue, forKey: "scanStartDate") }
    }

    // 提示词
    var systemPrompt: String { /* 默认值同 Android 版 */ }
    var userPrompt: String { /* 默认值同 Android 版 */ }

    func isApiConfigured() -> Bool {
        !apiBaseUrl.trimmingCharacters(in: .whitespaces).isEmpty &&
        !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
```

---

## 11. 与 Android 版的关键差异

| 方面 | Android | iOS | 影响 |
|---|---|---|---|
| 照片访问 | MediaStore + 文件路径 | Photos Framework + PHAsset | 路径标识方式不同，iOS 用 `localIdentifier` |
| 照片移动 | 文件系统 `File.renameTo()` | `PHAssetCollectionChangeRequest` | iOS 无法真正「移动」，只能添加/移除相簿 |
| 并发控制 | `Semaphore(4)` | `TaskGroup` + `AsyncSemaphore` | Swift 无内置 Semaphore，需自定义 |
| 图片下采样 | `BitmapFactory.inSampleSize` | `CGImageSource` thumbnail | iOS 的 `CGImageSource` 更高效 |
| 视频帧提取 | `MediaMetadataRetriever` | `AVAssetImageGenerator` | API 风格不同，功能等价 |
| 网络请求 | OkHttp | URLSession | 原生 API，无需第三方库 |
| 数据库 | Room (SQLite) | SwiftData (SQLite) | SwiftData 更声明式 |
| 后台任务 | WorkManager | BGTaskScheduler | iOS 后台任务调度更受限 |
| 权限模型 | 运行时逐项请求 | 相册分级权限（有限/完整） | iOS 17+ 需要完整访问才能扫描全部照片 |
| 文件存储 | 外部存储 / `Pictures/BabyAlbum` | 应用沙盒 + Photos Library | iOS 无需处理文件路径差异 |

---

## 12. 依赖管理

### 12.1 Swift Package Manager

本项目尽量使用 Apple 原生框架，最小化第三方依赖：

| 依赖 | 是否必需 | 说明 |
|---|---|---|
| SwiftUI | 是（系统内置） | UI 框架 |
| SwiftData | 是（系统内置） | 本地数据库 |
| Photos | 是（系统内置） | 相册访问 |
| PhotosUI | 否（系统内置） | PHPicker（备选方案） |
| AVFoundation | 是（系统内置） | 视频帧提取 |
| AVKit | 是（系统内置） | 视频播放 |
| UserNotifications | 是（系统内置） | 本地通知 |
| BackgroundTasks | 是（系统内置） | 后台扫描 |
| CryptoKit | 是（系统内置） | SHA-256 哈希 |

**无需引入任何第三方依赖。** 所有功能均可通过 Apple 原生框架实现。

---

## 13. 单元测试

### 13.1 测试范围

与 Android 版保持一致，优先为纯业务逻辑编写单元测试：

| 测试文件 | 测试内容 |
|---|---|
| `MediaScanRangeTests.swift` | 增量扫描范围计算逻辑 |
| `ClassificationEngineTests.swift` | 分类阈值决策逻辑 |
| `BabyRecognizerResponseTests.swift` | JSON 响应解析（含 markdown code block） |
| `ImagePreprocessorTests.swift` | 图片缩放与压缩逻辑 |
| `SettingsManagerTests.swift` | 设置读取与默认值 |

### 13.2 测试框架

使用 Swift Testing（iOS 17+ 推荐）或 XCTest。

---

## 14. 开发计划

### Phase 1: 项目骨架
- [ ] 创建 Xcode 项目，配置 SwiftData ModelContainer
- [ ] 实现 SettingsManager
- [ ] 实现 TabView 导航框架
- [ ] 搭建基础 UI 骨架（3 个空页面）

### Phase 2: 核心域逻辑
- [ ] 实现 PhotoScanner (PHAsset 扫描)
- [ ] 实现 ImagePreprocessor + VideoFrameExtractor
- [ ] 实现 BabyRecognizerImpl (URLSession 网络调用)
- [ ] 实现 ClassificationEngine
- [ ] 实现 AlbumManager (Photos Framework)
- [ ] 实现 AnalysisRepository (核心编排)

### Phase 3: UI 完善
- [ ] HomeView：品牌展示、扫描按钮、统计、待确认列表
- [ ] HistoryView：筛选、滑动操作、详情弹窗
- [ ] SettingsView：表单配置、保存

### Phase 4: 后台与通知
- [ ] BGTaskScheduler 后台扫描
- [ ] 本地通知

### Phase 5: 测试与优化
- [ ] 单元测试
- [ ] 权限流程测试
- [ ] 性能优化（大量照片场景）
- [ ] 边界情况处理

---

## 15. 隐私与安全

与 Android 版 AGENTS.md 中的隐私要求保持一致：

- API Key 仅存储在 UserDefaults 中，不写入源码、日志或文档
- 图片 Base64 数据不记录到日志
- 识别响应中的隐私内容不持久化到日志
- 照片操作（添加/移除相簿）需用户明确触发，不自动执行不可逆操作
- 网络请求使用 HTTPS
