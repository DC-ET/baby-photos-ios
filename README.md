# Baby Photos Archive（宝宝照片归档）
> 安卓版本：https://github.com/DC-ET/baby-photos

**宝宝照片归档** 是一款安装在 **iPhone** 上的相册整理工具，适合 **有 0～3 岁宝宝的家庭**：日常随手拍很多，真正和宝宝相关的照片、视频却分散在相册各处，事后一张张翻找、归类很费时间。应用帮你在本地完成「**筛出来 → 归到一处**」：自动找出画面里 **疑似带宝宝** 的素材，整理进 **专属的宝宝相册**；对不太有把握的内容，会先 **请你确认** 再收录，尽量避免误收。

**使用方式**：你在应用里填入自己已开通的 **AI 看图服务**（各家在线大模型均可，按服务商说明自行开通与付费）；应用 **不提供云相册、也不代管你的照片**，所有媒体始终留在本机，由你控制何时扫描、是否纳入宝宝相册。

> 请勿在 Issue、截图或公开场合泄露你在应用内填写的 **服务密钥**。

---

## 特性 & 亮点

1. **纯本地，无自建服务端**：扫描、缓存、识别记录均在设备上完成；仅按你的配置调用第三方视觉 API，应用不托管用户相册。
2. **与系统相册无缝集成**：使用 Photos Framework 管理相簿，照片始终留在系统相册中，通过「宝宝相册」自定义相簿进行分类管理。
3. **图片与视频兼顾**：相册扫描覆盖图片与视频；视频通过抽帧生成静态图再走同一套视觉识别与分类流程（详见 `VideoFrameExtractor`、`PhotoScanner`）。
4. **少打扰、可省钱**：SwiftData 记录已分析路径，避免对同一文件重复调用模型；并发上限控制（如 `AsyncSemaphore`）降低瞬时流量与 API 压力。
5. **分级自动化**：高置信度可自动归档，中置信度需用户确认后再移动，降低误操作风险。
6. **原生 iOS 体验**：使用 SwiftUI + SwiftData 构建，完全遵循 iOS 设计规范，支持深色模式、动态字体等系统特性。

---

## 功能概览

- **本地扫描**：基于 Photos Framework 发现待分析图片与视频。
- **预处理**：缩放、JPEG 压缩、Base64，降低带宽与调用成本。
- **视觉识别**：调用 `/v1/chat/completions`，解析模型返回的 JSON（`contains_baby`、`confidence`、`reason`），兼容部分模型用 markdown 代码块包裹 JSON 的情况。
- **分类与归档**（默认规则，与 `ClassificationEngine` 一致）：
  - **置信度 ≥ 80**：可自动加入宝宝相册（具体行为以应用内逻辑为准）。
  - **50～79**：需用户确认后再归档。
  - **低于 50** 或判定不含宝宝：忽略。
- **去重与记录**：已分析路径写入 SwiftData，避免对同一张照片重复调用 API。
- **后台任务**：BGTaskScheduler 周期性扫描。

![image](docs/image.png)
![image](docs/image2.png)
![image](docs/image3.png)

---

## 使用说明

1. **底部导航**：**首页**（扫描与待确认）、**历史**（历史识别与详情）、**设置**（API 与扫描参数）。
2. **首次使用前**：打开 **设置**，填写 **API 地址**、**API Key**、**模型名称**（须支持视觉/多模态），按需设置 **扫描起始时间**（只处理该日期之后进入相册的媒体，避免扫全库）、**自动添加阈值** / **确认阈值**、图片预处理参数，点 **保存设置**。未完成 API 配置时，首页 **开始扫描** 不可用。
   - **默认配置**：应用已预置 [阿里云百炼平台](https://bailian.console.aliyun.com/) 作为默认 API 服务，模型默认使用 **qwen3-vl-flash**。你只需注册百炼平台账号、开通服务并获取 API Key 即可快速开始使用。
   - **qwen3-vl-flash 价格**：输入 0.15 元/百万 tokens；输入（缓存命中）0.03 元/百万 tokens；输出 1.5 元/百万 tokens。
3. **扫描与权限**：在 **首页** 点 **开始扫描**；按系统提示授予 **相册完整访问权限**（iOS 17+ 需要完整访问才能扫描全部照片）。授权后再次扫描即可。
4. **结果与归档**：扫描结束后，高置信媒体可按规则 **自动** 添加到宝宝相册；置信度居中的会出现在 **待确认** 列表，可单条处理，或使用 **全部确认** / **全部跳过**。归档后可在系统相册的「宝宝相册」相簿中查看。
5. **后台**：在满足网络等条件时，应用会通过 **BGTaskScheduler** 做周期性扫描，与手动扫描共用同一套逻辑与记录。扫描完成后会通过本地通知提醒用户。

---

## 技术栈

| 类别 | 选型 |
|------|------|
| 语言 | Swift 6 |
| UI | SwiftUI + iOS 原生组件 |
| 导航 | NavigationStack (iOS 16+) |
| 本地存储 | SwiftData (iOS 17+) |
| 网络 | URLSession (原生) |
| 图片 | AsyncImage (SwiftUI 原生) + PhotosUI |
| 视频播放 | AVKit / VideoPlayer |
| 偏好设置 | UserDefaults (封装为 SettingsManager) |
| 并发 | Swift Concurrency (async/await, TaskGroup) |
| 后台任务 | BGTaskScheduler |
| JSON 解析 | Foundation JSONSerialization / Codable |
| 图片处理 | Core Graphics / UIImage |
| 视频帧提取 | AVFoundation (AVAssetImageGenerator) |

**最低版本要求**：iOS 17.0（SwiftData 要求 iOS 17+，覆盖 ~90% 活跃设备）

---

## 环境要求

- **Xcode 15** 及以上（推荐 Xcode 16）
- **iOS 17.0** 及以上目标设备或模拟器
- **Apple Developer 账号**（用于真机调试与后台任务权限）

---

## 构建与检查

使用 Xcode 打开 `BabyPhotos.xcodeproj`，选择目标设备后：

1. **构建项目**：`Cmd + B` 或 Product → Build
2. **运行测试**：`Cmd + U` 或 Product → Test
3. **运行应用**：`Cmd + R` 或 Product → Run

---

## 从源码构建

1. 使用 Xcode 打开 `BabyPhotos.xcodeproj`，等待 Swift Package 解析完成。
2. 在应用内 **设置** 中配置：
   - **Base URL**（默认已填入阿里云百炼平台地址，也可使用其他兼容 OpenAI 接口的服务）
   - **API Key**（仅保存在本机，勿提交到 Git）
   - **模型名称**（默认为 `qwen3-vl-flash`，需支持 Vision / 多模态消息）
3. 授予相册完整访问权限；iOS 17+ 需要完整访问才能扫描全部照片。
4. 首次使用建议先 **手动扫描小批量**，确认归档路径与误判情况后再依赖自动或后台流程。

更完整的产品与技术说明见 [**TECH_SPEC.md**](TECH_SPEC.md)。

---

## 权限与隐私提示

- 应用会读取图片与视频，并可能将照片 **添加到宝宝相册自定义相簿**，**不会**在 README 中描述任何静默删除原图或批量不可逆策略以外的行为；修改 `AlbumManager` 等模块时请格外谨慎。
- **API Key、完整请求体、Base64 图片、含隐私的模型原文** 不应写入日志或对外分享。
- 开源前请自行审查 `Info.plist` 中的权限声明是否与你的产品定位一致；若上架 App Store，需准备 **隐私政策** 与 **数据出境/API 说明**（如适用）。

---

## 目录结构（摘要）

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

## 参与贡献

欢迎 Issue / PR。提交前请尽量：

- 保持分层清晰（UI 不承载重业务流程）。
- 涉及权限、相簿操作、数据库迁移、后台策略的改动，在 PR 中说明动机与验证方式。
- 不引入非必要的大型依赖（尽量使用 Apple 原生框架）。
- 遵循 Swift 编码规范与 SwiftUI 最佳实践。

---

## 免责声明

- 本工具依赖第三方视觉模型的判断，**可能存在误判或漏判**。
- 使用大模型 API 会有一定的成本，请根据实际情况选择是否使用。
- 归档操作为真实的照片相簿管理操作，使用前请自行备份重要数据。
- 作者与贡献者不对因使用本软件造成的任何直接或间接损失承担责任。