import Foundation

struct APILogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let provider: String
    let url: String
    let method: String
    let statusCode: Int?
    let durationMs: Int
    let responsePreview: String?
    let error: String?

    var succeeded: Bool { statusCode.map { (200...299).contains($0) } ?? false }
    var isRateLimited: Bool { statusCode == 429 }
    var isFailed: Bool { error != nil || (statusCode.map { $0 >= 400 } ?? false) }

    var urlPath: String {
        URL(string: url)?.path ?? url
    }

    var statusLabel: String {
        if let code = statusCode { return "\(code)" }
        return "ERR"
    }
}

@MainActor
final class APICallLogger: ObservableObject {
    static let shared = APICallLogger()
    private init() {}

    @Published var entries: [APILogEntry] = []
    @Published var isPaused: Bool = false

    private let maxEntries = 300

    func log(_ entry: APILogEntry) {
        guard !isPaused else { return }
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
    }

    func clear() { entries.removeAll() }

    // MARK: - Helpers used by callers

    static func providerName(from url: URL?) -> String {
        guard let host = url?.host else { return "Unknown" }
        if host.contains("minimax") { return "MiniMax" }
        if host.contains("z.ai") || host.contains("zhipuai") { return "GLM" }
        if host.contains("moonshot") { return "Kimi" }
        if host.contains("github.com") { return "Copilot" }
        if host.contains("claude.ai") { return "Claude" }
        if host.contains("chatgpt.com") || host.contains("openai.com") { return "Codex" }
        return host
    }

    static func preview(_ data: Data, maxLength: Int = 600) -> String? {
        if let json = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let str = String(data: pretty, encoding: .utf8) {
            return str.count > maxLength ? String(str.prefix(maxLength)) + "\n…" : str
        }
        guard let str = String(data: data, encoding: .utf8) else { return nil }
        return str.count > maxLength ? String(str.prefix(maxLength)) + "…" : str
    }
}
