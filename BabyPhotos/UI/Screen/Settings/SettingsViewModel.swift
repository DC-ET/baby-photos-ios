import Foundation

enum ApiTestResult: Equatable {
    case success
    case failure(String)
}

@Observable
@MainActor
final class SettingsViewModel {
    var uiState = SettingsUiState()

    struct SettingsUiState {
        var apiBaseUrl = "https://dashscope.aliyuncs.com/compatible-mode"
        var apiKey = ""
        var modelName = "qwen3-vl-flash"
        var autoAddThreshold = 80
        var confirmThreshold = 50
        var maxImageSize = 1024
        var jpegQuality = 70
        var concurrencyLimit = 10
        var scanStartDate: Date?
        var systemPrompt = ""
        var userPrompt = ""
        var isSaved = false
        var isTestingApi = false
        var apiTestResult: ApiTestResult?
    }

    private var settingsManager: SettingsManager?

    func setup(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
        loadFromSettings()
    }

    private func loadFromSettings() {
        guard let sm = settingsManager else { return }
        uiState.apiBaseUrl = sm.apiBaseUrl
        uiState.apiKey = sm.apiKey
        uiState.modelName = sm.modelName
        uiState.autoAddThreshold = sm.autoAddThreshold
        uiState.confirmThreshold = sm.confirmThreshold
        uiState.maxImageSize = sm.maxImageSize
        uiState.jpegQuality = sm.jpegQuality
        uiState.concurrencyLimit = sm.concurrencyLimit
        uiState.scanStartDate = sm.scanStartDate
        uiState.systemPrompt = sm.systemPrompt
        uiState.userPrompt = sm.userPrompt
    }

    func saveSettings() {
        guard let sm = settingsManager else { return }
        sm.apiBaseUrl = uiState.apiBaseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        sm.apiKey = uiState.apiKey
        sm.modelName = uiState.modelName.isEmpty ? "qwen3-vl-flash" : uiState.modelName
        sm.autoAddThreshold = uiState.autoAddThreshold
        sm.confirmThreshold = uiState.confirmThreshold
        sm.maxImageSize = uiState.maxImageSize
        sm.jpegQuality = uiState.jpegQuality
        sm.concurrencyLimit = uiState.concurrencyLimit
        sm.scanStartDate = uiState.scanStartDate
        sm.systemPrompt = uiState.systemPrompt.isEmpty ? SettingsManager.defaultSystemPrompt : uiState.systemPrompt
        sm.userPrompt = uiState.userPrompt.isEmpty ? SettingsManager.defaultUserPrompt : uiState.userPrompt

        uiState.isSaved = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            uiState.isSaved = false
        }
    }

    func testApiConnection() {
        let baseUrl = uiState.apiBaseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let key = uiState.apiKey

        guard !baseUrl.isEmpty, !key.isEmpty else {
            uiState.apiTestResult = .failure("请先填写 API 地址和 API Key")
            return
        }

        uiState.isTestingApi = true
        uiState.apiTestResult = nil

        Task {
            let result = await doTestApi(baseUrl: baseUrl, apiKey: key, model: uiState.modelName.isEmpty ? "qwen3-vl-flash" : uiState.modelName)
            uiState.isTestingApi = false
            uiState.apiTestResult = result
        }
    }

    private func doTestApi(baseUrl: String, apiKey: String, model: String) async -> ApiTestResult {
        guard let url = URL(string: "\(baseUrl)/v1/chat/completions") else {
            return .failure("API 地址格式不正确")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 100,
            "messages": [
                ["role": "user", "content": "你好"]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return .failure("构建请求失败: \(error.localizedDescription)")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure("无效的服务器响应")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let responseBody = String(data: data, encoding: .utf8) ?? ""
                let message: String
                switch httpResponse.statusCode {
                case 401:
                    message = "认证失败，请检查 API Key 是否正确"
                case 403:
                    message = "访问被拒绝，请检查 API Key 权限"
                case 404:
                    message = "接口不存在，请检查 API 地址是否正确"
                case 429:
                    message = "请求过于频繁，请稍后再试"
                case 500...599:
                    message = "服务器错误 (\(httpResponse.statusCode))，请稍后再试"
                default:
                    message = "请求失败 (\(httpResponse.statusCode)): \(responseBody)"
                }
                return .failure(message)
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                return .failure("API 返回格式异常")
            }

            if content.isEmpty {
                return .failure("API 返回内容为空")
            }

            return .success
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet:
                return .failure("网络连接失败，请检查网络")
            case .cannotFindHost, .cannotConnectToHost:
                return .failure("无法连接到服务器，请检查 API 地址")
            case .timedOut:
                return .failure("连接超时，请检查网络或 API 地址")
            case .badURL:
                return .failure("API 地址格式不正确")
            default:
                return .failure("网络错误: \(error.localizedDescription)")
            }
        } catch {
            return .failure("测试失败: \(error.localizedDescription)")
        }
    }

    func clearTestResult() {
        uiState.apiTestResult = nil
    }
}
