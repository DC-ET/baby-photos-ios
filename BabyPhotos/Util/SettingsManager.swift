import Foundation

@Observable
final class SettingsManager: @unchecked Sendable {
    static let defaultSystemPrompt = """
    你是一个图片分类器。
    任务：判断图片中是否包含0-3岁婴幼儿。
    规则：
    1. 看到婴儿/幼儿 => true
    2. 背影/局部但明显为婴儿 => true
    3. 无法判断 => false
    4. 成人/儿童（>5岁） => false
    5. 玩具娃娃 => false
    输出 JSON：{"contains_baby": true/false, "confidence": 0-100, "reason": "一句话说明"}
    """

    static let defaultUserPrompt = "判断图片是否包含0-3岁婴幼儿，并返回JSON结果"

    private let defaults = UserDefaults.standard

    var apiBaseUrl: String {
        get { defaults.string(forKey: "apiBaseUrl") ?? "https://dashscope.aliyuncs.com/compatible-mode" }
        set { defaults.setValue(newValue, forKey: "apiBaseUrl") }
    }

    var apiKey: String {
        get { defaults.string(forKey: "apiKey") ?? "" }
        set { defaults.setValue(newValue, forKey: "apiKey") }
    }

    var modelName: String {
        get { defaults.string(forKey: "modelName") ?? "qwen3-vl-flash" }
        set { defaults.setValue(newValue, forKey: "modelName") }
    }

    var autoAddThreshold: Int {
        get {
            let v = defaults.integer(forKey: "autoAddThreshold")
            return v > 0 ? v : 80
        }
        set { defaults.setValue(newValue, forKey: "autoAddThreshold") }
    }

    var confirmThreshold: Int {
        get {
            let v = defaults.integer(forKey: "confirmThreshold")
            return v > 0 ? v : 50
        }
        set { defaults.setValue(newValue, forKey: "confirmThreshold") }
    }

    var maxImageSize: Int {
        get {
            let v = defaults.integer(forKey: "maxImageSize")
            return v > 0 ? v : 1024
        }
        set { defaults.setValue(newValue, forKey: "maxImageSize") }
    }

    var jpegQuality: Int {
        get {
            let v = defaults.integer(forKey: "jpegQuality")
            return v > 0 ? v : 70
        }
        set { defaults.setValue(newValue, forKey: "jpegQuality") }
    }

    var concurrencyLimit: Int {
        get {
            let v = defaults.integer(forKey: "concurrencyLimit")
            return v > 0 ? v : 10
        }
        set { defaults.setValue(newValue, forKey: "concurrencyLimit") }
    }

    var systemPrompt: String {
        get { defaults.string(forKey: "systemPrompt") ?? Self.defaultSystemPrompt }
        set { defaults.setValue(newValue, forKey: "systemPrompt") }
    }

    var userPrompt: String {
        get { defaults.string(forKey: "userPrompt") ?? Self.defaultUserPrompt }
        set { defaults.setValue(newValue, forKey: "userPrompt") }
    }

    var scanStartDate: Date? {
        get {
            let ts = defaults.double(forKey: "scanStartDate")
            return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        }
        set {
            defaults.setValue(newValue?.timeIntervalSince1970 ?? 0, forKey: "scanStartDate")
        }
    }

    var scanStartDateSnapshotAtLastScan: Date? {
        get {
            let ts = defaults.double(forKey: "scanStartDateSnapshotAtLastScan")
            return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        }
        set {
            defaults.setValue(newValue?.timeIntervalSince1970 ?? 0, forKey: "scanStartDateSnapshotAtLastScan")
        }
    }

    var lastScanMediaDateAddedWatermark: Date? {
        get {
            let ts = defaults.double(forKey: "lastScanMediaDateAddedWatermark")
            return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
        }
        set {
            defaults.setValue(newValue?.timeIntervalSince1970 ?? 0, forKey: "lastScanMediaDateAddedWatermark")
        }
    }

    func isApiConfigured() -> Bool {
        !apiBaseUrl.trimmingCharacters(in: .whitespaces).isEmpty &&
        !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
