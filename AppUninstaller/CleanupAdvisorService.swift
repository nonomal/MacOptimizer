import Foundation

enum CleanupAdviceDecision: String, Codable, Sendable {
    case recommended
    case caution
    case keep
    case unknown
}

struct CleanupAdvice: Codable, Sendable {
    let decision: CleanupAdviceDecision
    let confidence: Double
    let reason: String
    let summary: String
    
    static let pending = CleanupAdvice(
        decision: .unknown,
        confidence: 0,
        reason: "正在分析此项目。",
        summary: "分析中"
    )
}

struct CleanupAdvisorItemContext: Codable, Sendable {
    let id: UUID
    let category: String
    let path: String
    let name: String
    let size: Int64
    let isDirectory: Bool
    let modifiedAt: Date?
    let contentPreview: String?
}

struct CleanupAdvisorResponse: Codable, Sendable {
    let recommendations: [UUID: CleanupAdvice]
}

final class CleanupAdvisorService {
    static let shared = CleanupAdvisorService()
    
    private let fileManager = FileManager.default
    private let maxPreviewBytes = 4096
    private let maxDirectoryChildren = 12
    
    private init() {}
    
    func analyze(items: [JunkItem]) async -> [UUID: CleanupAdvice] {
        let contexts = items.map { buildContext(for: $0) }
        
        // API hook: send `contexts` to a non-chat JSON endpoint when configured.
        // Until an endpoint is provided, local rules give deterministic guidance.
        return Dictionary(uniqueKeysWithValues: contexts.map { context in
            (context.id, makeLocalRecommendation(for: context))
        })
    }
    
    private func buildContext(for item: JunkItem) -> CleanupAdvisorItemContext {
        let values = try? item.path.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
        let isDirectory = values?.isDirectory ?? false
        
        return CleanupAdvisorItemContext(
            id: item.id,
            category: item.type.rawValue,
            path: item.path.path,
            name: item.name,
            size: item.size,
            isDirectory: isDirectory,
            modifiedAt: values?.contentModificationDate,
            contentPreview: contentPreview(for: item.path, isDirectory: isDirectory)
        )
    }
    
    private func contentPreview(for url: URL, isDirectory: Bool) -> String? {
        if isDirectory {
            return directoryPreview(for: url)
        }
        
        guard isTextLike(url) else { return nil }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        
        let data = handle.readData(ofLength: maxPreviewBytes)
        guard !data.isEmpty else { return nil }
        
        let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii)
        return text?
            .components(separatedBy: .newlines)
            .prefix(12)
            .joined(separator: "\n")
    }
    
    private func directoryPreview(for url: URL) -> String? {
        guard let children = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }
        
        return children
            .prefix(maxDirectoryChildren)
            .map { child in
                let isDirectory = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                return "\(isDirectory ? "dir" : "file"): \(child.lastPathComponent)"
            }
            .joined(separator: "\n")
    }
    
    private func isTextLike(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let textExtensions: Set<String> = [
            "log", "txt", "json", "plist", "xml", "yaml", "yml", "toml",
            "conf", "ini", "crash", "ips", "trace", "cache", "tmp"
        ]
        return textExtensions.contains(ext)
    }
    
    private func makeLocalRecommendation(for context: CleanupAdvisorItemContext) -> CleanupAdvice {
        let path = context.path.lowercased()
        let name = context.name.lowercased()
        
        if path.contains("/library/developer/xcode/deriveddata") ||
            path.contains("/library/developer/coresimulator/caches") ||
            path.contains("/library/caches/") ||
            path.contains("/library/logs/") ||
            path.contains("/diagnosticreports/") ||
            path.contains("/crashreporter/") ||
            name.hasSuffix(".log") ||
            name.hasSuffix(".crash") {
            return CleanupAdvice(
                decision: .recommended,
                confidence: 0.86,
                reason: "此项目位于缓存、日志或开发工具衍生资料目录，通常可重新生成。",
                summary: "建议清理"
            )
        }
        
        if path.contains("/downloads/") || name.hasSuffix(".dmg") || name.hasSuffix(".iso") || name.hasSuffix(".pkg") || name.hasSuffix(".zip") {
            return CleanupAdvice(
                decision: .caution,
                confidence: 0.68,
                reason: "这是用户下载或安装包类文件，可能已不需要，但应先确认是否仍要保留。",
                summary: "谨慎清理"
            )
        }
        
        if path.contains("/mobileSync/backup".lowercased()) ||
            path.contains("/mail downloads") ||
            path.contains("/messages/attachments") {
            return CleanupAdvice(
                decision: .caution,
                confidence: 0.72,
                reason: "此项目可能包含备份、邮件附件或个人资料，建议确认内容后再删除。",
                summary: "谨慎清理"
            )
        }
        
        if path.contains("/preferences/") ||
            name.hasSuffix(".plist") ||
            path.contains("/application support/") {
            return CleanupAdvice(
                decision: .keep,
                confidence: 0.76,
                reason: "此项目可能保存应用设置或运行资料，误删可能导致配置丢失。",
                summary: "不建议"
            )
        }
        
        return CleanupAdvice(
            decision: .caution,
            confidence: 0.5,
            reason: "无法仅凭路径确认用途，建议查看内容后决定。",
            summary: "谨慎清理"
        )
    }
}
