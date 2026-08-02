import SwiftUI
import AppKit

// MARK: - Data Models
// MARK: - Data Models
struct AppUpdateItem: Identifiable, Hashable, Sendable {
    let id = UUID()
    let app: InstalledApp // Reference to the local app
    let newVersion: String
    let size: String
    let releaseDate: String
    let releaseNotes: String?  // Changed to Optional
    let screenshotUrls: [URL]
    let artworkUrl: URL?
    let appStoreId: Int?       // Added for mas-cli
    var directDownloadURL: URL? = nil
    var isSelected: Bool = false
    
    // Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AppUpdateItem, rhs: AppUpdateItem) -> Bool {
        lhs.id == rhs.id
    }
}

// iTunes API Response Models
struct ITunesSearchResponse: Codable {
    let resultCount: Int
    let results: [ITunesSearchResult]
}

struct ITunesSearchResult: Codable {
    let version: String
    let currentVersionReleaseDate: String
    let releaseNotes: String?
    let screenshotUrls: [String]
    let artworkUrl512: String
    let bundleId: String
    let trackId: Int           // Added
    let fileSizeBytes: String? // Stringified integer
}

// MARK: - Service
class AppUpdaterService: ObservableObject {
    static let shared = AppUpdaterService()
    @Published var updates: [AppUpdateItem] = []
    @Published var isScanning = false
    @Published var scanComplete = false
    @Published var progress: Double = 0
    
    // 更新状态
    @Published var isUpdating = false
    @Published var updateProgress: Double = 0
    @Published var currentlyUpdatingAppName: String = ""
    @Published var updateError: String?
    @Published var updateComplete = false  // 更新完成标志
    
    // 单个应用的更新状态
    @Published var appUpdateStatuses: [UUID: UpdateStatus] = [:]
    
    enum UpdateStatus: Equatable {
        case pending
        case downloading
        case installing
        case completed
        case failed(String)
    }
    
    private let scanner = AppScanner()
    
    func scanForUpdates() async {
        await MainActor.run {
            isScanning = true
            scanComplete = false
            updates = []
            progress = 0
        }
        
        // 1. Scan Installed Apps using existing AppScanner
        await scanner.scanApplications()
        let installedApps = scanner.apps
        
        var foundUpdates: [AppUpdateItem] = []
        let total = Double(installedApps.count)
        var processed = 0.0
        
        // 2. batch check iTunes API
        // Only check apps with bundle IDs. Limit to first 50 for demo speed/rate limits if needed, or all.
        // Also prioritize "App Store" apps or known vendors.
        
        await withTaskGroup(of: AppUpdateItem?.self) { group in
            for app in installedApps {
                guard let bundleId = app.bundleIdentifier, !bundleId.isEmpty else {
                    processed += 1
                    let currentProcessed = processed
                    await MainActor.run { self.progress = currentProcessed / total }
                    continue
                }
                
                group.addTask {
                    let result = await self.checkUpdate(for: app, bundleId: bundleId)
                    return result
                }
            }
            
            for await update in group {
                processed += 1
                let currentProcessed = processed
                await MainActor.run { self.progress = currentProcessed / total }
                if let update = update {
                    foundUpdates.append(update)
                }
            }
        }
        let finalUpdates = foundUpdates
        await MainActor.run {
            self.updates = finalUpdates
            self.isScanning = false
            self.scanComplete = true
            self.progress = 1.0
        }
    }
    
    private func checkUpdate(for app: InstalledApp, bundleId: String) async -> AppUpdateItem? {
        if bundleId.caseInsensitiveCompare("com.tencent.xinWeChat") == .orderedSame {
            return await checkWeChatUpdate(for: app)
        }

        // The iTunes lookup describes the App Store edition. Do not offer that
        // metadata as an update for a separately distributed vendor build.
        guard app.isAppStore else { return nil }

        // Real logic: Compare versions.
        guard let info = await fetchITunesInfo(bundleId: bundleId) else { return nil }
        
        let currentVersion = app.version ?? "0.0.0"
        let newVersion = info.version
        
        // simple string compare for now, or use compare(options: .numeric)
        // Only return if newVersion > currentVersion (or != for safety)
        if newVersion.compare(currentVersion, options: .numeric) != .orderedDescending {
            return nil
        }
        
        return AppUpdateItem(
            app: app,
            newVersion: info.version,
            size: info.fileSizeBytes.flatMap { Int64($0).map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } } ?? "Unknown",
            releaseDate: formatDate(info.currentVersionReleaseDate),
            releaseNotes: info.releaseNotes ?? "Update details not available.",
            screenshotUrls: info.screenshotUrls.compactMap { URL(string: $0) },
            artworkUrl: URL(string: info.artworkUrl512),
            appStoreId: info.trackId
        )
    }

    private func checkWeChatUpdate(for app: InstalledApp) async -> AppUpdateItem? {
        guard let pageURL = URL(string: "https://mac.weixin.qq.com/"),
              let (data, _) = try? await URLSession.shared.data(from: pageURL),
              let html = String(data: data, encoding: .utf8) else { return nil }

        let pattern = #"https://dldir1v6\.qq\.com/weixin/Universal/Mac/WeChatMac_([0-9.]+)\.dmg"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let urlRange = Range(match.range(at: 0), in: html),
              let versionRange = Range(match.range(at: 1), in: html),
              let downloadURL = URL(string: String(html[urlRange])) else { return nil }

        let latestVersion = String(html[versionRange])
        let currentVersion = app.version ?? "0"
        guard latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending else { return nil }

        let appStoreInfo = await fetchITunesInfo(bundleId: "com.tencent.xinWeChat")
        let notes = extractWeChatReleaseNotes(from: html)
        return AppUpdateItem(
            app: app,
            newVersion: latestVersion,
            size: await remoteFileSize(downloadURL)
                ?? appStoreInfo?.fileSizeBytes.flatMap { Int64($0).map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } }
                ?? "—",
            releaseDate: formatDate(appStoreInfo?.currentVersionReleaseDate ?? ""),
            releaseNotes: notes.isEmpty ? appStoreInfo?.releaseNotes : notes,
            screenshotUrls: appStoreInfo?.screenshotUrls.compactMap(URL.init(string:)) ?? [],
            artworkUrl: appStoreInfo.flatMap { URL(string: $0.artworkUrl512) },
            appStoreId: appStoreInfo?.trackId,
            directDownloadURL: downloadURL
        )
    }

    private func extractWeChatReleaseNotes(from html: String) -> String {
        guard let listRange = html.range(of: #"<ul class="log-section">"#),
              let listEnd = html[listRange.upperBound...].range(of: "</ul>"),
              let regex = try? NSRegularExpression(pattern: #"<li[^>]*>(.*?)</li>"#, options: [.dotMatchesLineSeparators]) else { return "" }

        let section = String(html[listRange.upperBound..<listEnd.lowerBound])
        return regex.matches(in: section, range: NSRange(section.startIndex..., in: section))
            .compactMap { match -> String? in
                guard let range = Range(match.range(at: 1), in: section) else { return nil }
                return section[range]
                    .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
            .map { "- \($0)" }
            .joined(separator: "\n")
    }

    private func remoteFileSize(_ url: URL) async -> String? {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              response.expectedContentLength > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: response.expectedContentLength, countStyle: .file)
    }
    
    private func fetchITunesInfo(bundleId: String) async -> ITunesSearchResult? {
        let urlString = "https://itunes.apple.com/lookup?bundleId=\(bundleId)&country=cn" // Default to CN for Chinese content preference? Or allow fallback.
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
            return response.results.first
        } catch {
            return nil
        }
    }
    
    private func formatDate(_ isoString: String) -> String {
        // 2024-12-17T07:00:00Z
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: isoString) {
            let display = DateFormatter()
            display.dateFormat = "yyyy年MM月dd日"
            return display.string(from: date)
        }
        return isoString
    }
    
    // MARK: - Update Functions
    
    func toggleSelection(for item: AppUpdateItem) {
        if let index = updates.firstIndex(where: { $0.id == item.id }) {
            updates[index].isSelected.toggle()
        }
    }
    
    func selectAll() {
        let allSelected = updates.allSatisfy { $0.isSelected }
        updates = updates.map {
            var copy = $0
            copy.isSelected = !allSelected
            return copy
        }
    }
    
    /// 检查 mas-cli 是否安装
    private func isMasInstalled() -> Bool {
        let possiblePaths = ["/opt/homebrew/bin/mas", "/usr/local/bin/mas", "/usr/bin/mas"]
        return possiblePaths.contains { FileManager.default.fileExists(atPath: $0) }
    }
    
    /// 获取 mas 可执行文件路径
    func getMasPath() -> String? {
        let possiblePaths = ["/opt/homebrew/bin/mas", "/usr/local/bin/mas", "/usr/bin/mas"]
        return possiblePaths.first { FileManager.default.fileExists(atPath: $0) }
    }
    
    /// 更新选中的应用
    func updateSelectedApps() async {
        let selectedApps = updates.filter { $0.isSelected }
        guard !selectedApps.isEmpty else { return }
        
        await MainActor.run {
            isUpdating = true
            updateProgress = 0
            updateError = nil
            updateComplete = false
        }
        
        // 检查 mas-cli
        guard let masPath = getMasPath() else {
            await MainActor.run {
                isUpdating = false
                updateError = "无法找到 mas-cli"
            }
            return
        }
        
        // 初始化所有选中应用的状态
        for app in selectedApps {
            await MainActor.run {
                appUpdateStatuses[app.id] = .pending
            }
        }
        
        // 更新每个应用
        for (index, app) in selectedApps.enumerated() {
            await MainActor.run {
                currentlyUpdatingAppName = app.app.name
                updateProgress = Double(index) / Double(selectedApps.count)
                appUpdateStatuses[app.id] = .downloading
            }
            
            if let appStoreId = app.appStoreId {
                // Check if it is a MAS app
                if !app.app.isAppStore {
                     await MainActor.run {
                        appUpdateStatuses[app.id] = .failed(LocalizationManager.shared.text("非 App Store 版本，无法自动更新", "This is not an App Store version and cannot be updated automatically"))
                    }
                    continue
                }

                await MainActor.run {
                    appUpdateStatuses[app.id] = .installing
                }
                let (success, errorMsg) = await updateWithMas(masPath: masPath, appStoreId: appStoreId)
                await MainActor.run {
                    appUpdateStatuses[app.id] = success ? .completed : .failed(errorMsg ?? LocalizationManager.shared.text("更新失败", "Update Failed"))
                }
            }
        }
        
        await MainActor.run {
            isUpdating = false
            updateProgress = 1.0
            currentlyUpdatingAppName = ""
            updateComplete = true
        }
        
        playCompletionSound()
    }
    
    /// 使用 mas 更新单个应用
    func updateWithMas(masPath: String, appStoreId: Int) async -> (Bool, String?) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: masPath)
        task.arguments = ["upgrade", String(appStoreId)]
        
        // mas usually outputs to stdout, errors might be on stderr
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus != 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                var output = String(data: data, encoding: .utf8) ?? ""
                if output.isEmpty { output = LocalizationManager.shared.text("未知错误（退出代码：\(task.terminationStatus)）", "Unknown error (exit code: \(task.terminationStatus))") }
                
                // Friendly error mapping
                if output.contains("sudo: a password is required") || output.contains("sudo: a terminal is required") {
                    return (false, LocalizationManager.shared.text("需要管理员权限，请前往 App Store 更新", "Administrator privileges are required. Update the app from the App Store."))
                }
                
                // Clean up output (mas output can be verbose)
                return (false, output.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            
            return (true, nil)
        } catch {
            return (false, LocalizationManager.shared.text("执行错误：\(error.localizedDescription)", "Execution error: \(error.localizedDescription)"))
        }
    }
    
    /// 播放完成提示音
    private static var soundPlayer: NSSound?
    
    private func playCompletionSound() {
        if let soundURL = Bundle.main.url(forResource: "CleanDidFinish", withExtension: "m4a") {
            AppUpdaterService.soundPlayer?.stop()
            AppUpdaterService.soundPlayer = NSSound(contentsOf: soundURL, byReference: false)
            AppUpdaterService.soundPlayer?.play()
        }
    }
}

// MARK: - Main View
struct AppUpdaterView: View {
    @StateObject private var service = AppUpdaterService.shared
    @State private var viewState: Int = 0 // 0: Landing, 1: List, 2: Updating
    @State private var selectedUpdateId: UUID?
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var selectedTab: Int = 0  // 0: 全部, 1: 成功, 2: 失败
    @State private var expandedFailedItems: Set<UUID> = []
    
    var body: some View {
        Group {
            switch viewState {
            case 0:
                landingView
            case 1:
                listView
            case 2:
                updatingView
            default:
                landingView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            viewState = 0
            selectedUpdateId = selectedUpdateId ?? service.updates.first?.id
            if service.updates.isEmpty && !service.isScanning && !service.scanComplete {
                Task {
                    await service.scanForUpdates()
                }
            }
        }
    }
    
    // MARK: - Landing View
    var landingView: some View {
        ZStack {
            HStack(alignment: .top, spacing: 25) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(loc.text(
    simplifiedChinese: "更新程序",
    traditionalChinese: "更新程式",
    english: "Updater",
    japanese: "Updater",
    korean: "업데이터",
    russian: "Обновления"
))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)

                    Text(loc.text(
    simplifiedChinese: "让所有应用程序始终保持最新、最可靠的版本。",
    traditionalChinese: "讓所有應用程式始終保持最新、最可靠的版本。",
    english: "Keep every application current and reliable.",
    japanese: "すべてのアプリケーションを最新かつ信頼性の高い状態に保ちます。",
    korean: "모든 응용 프로그램을 최신 상태로 유지하고 안정적으로 유지하십시오.",
    russian: "Поддерживайте актуальность и надежность каждого приложения."
))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.72))
                        .padding(.top, 10)

                    VStack(alignment: .leading, spacing: 64) {
                        updaterFeatureRow(
                            image: "updater_benefit_latest",
                            title: loc.text(
    simplifiedChinese: "仅使用最新版本",
    traditionalChinese: "僅使用最新版本",
    english: "Use only the latest versions",
    japanese: "最新バージョンのみを使用する",
    korean: "최신 버전만 사용",
    russian: "Использовать только последние версии"
),
                            subtitle: loc.text(
    simplifiedChinese: "让 CleanMyMac 为您检查和更新软件。",
    traditionalChinese: "讓CleanMyMac 為您檢查和更新軟體。",
    english: "Let CleanMyMac check and update software for you.",
    japanese: "CleanMyMacにソフトウェアのチェックとアップデートを依頼します。",
    korean: "CleanMyMac에서 소프트웨어를 확인하고 업데이트하세요.",
    russian: "Позвольте CleanMyMac проверить и обновить программное обеспечение для вас."
)
                        )

                        updaterFeatureRow(
                            image: "updater_benefit_compatible",
                            title: loc.text(
    simplifiedChinese: "避免软件不兼容",
    traditionalChinese: "避免軟體不相容",
    english: "Avoid software incompatibility",
    japanese: "ソフトウェアの非互換性を回避する",
    korean: "소프트웨어 비호환성 방지",
    russian: "Избегайте несовместимости программного обеспечения"
),
                            subtitle: loc.text(
    simplifiedChinese: "再也不会出现应用程序过时版本引起的兼容性问题。",
    traditionalChinese: "再也不會出現應用程式過時版本所引起的相容性問題。",
    english: "Prevent compatibility issues caused by outdated applications.",
    japanese: "古いアプリケーションによって引き起こされる互換性の問題を防ぎます。",
    korean: "오래된 응용 프로그램으로 인한 호환성 문제를 방지합니다.",
    russian: "Предотвращение проблем совместимости, вызванных устаревшими приложениями."
)
                        )
                    }
                    .padding(.top, 42)

                    if !service.isScanning && service.scanComplete && !service.updates.isEmpty {
                        Button(action: {
                            viewState = 1
                            if let first = service.updates.first {
                                selectedUpdateId = first.id
                            }
                        }) {
                            Text(loc.text(
    simplifiedChinese: "查看 \(service.updates.count) 个更新…",
    traditionalChinese: "查看\(service.updates.count)個更新…",
    english: "View \(service.updates.count) updates…",
    japanese: "\(service.updates.count) 更新を表示…",
    korean: "\(service.updates.count) 업데이트 보기...",
    russian: "Просмотр \(service.updates.count) обновлений..."
))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color.black.opacity(0.76))
                                .padding(.horizontal, 13)
                                .frame(height: 30)
                                .background(Color(red: 0.30, green: 0.84, blue: 0.98), in: RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 46)
                    }
                }
                .frame(width: 320, alignment: .leading)

                updaterResourceImage("updater_module")
                    .frame(width: 350, height: 350)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, 98)
            .padding(.top, 132)

            VStack {
                Spacer()

                if service.isScanning {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                .frame(width: 84, height: 84)
                            
                            Circle()
                                .trim(from: 0, to: service.progress)
                                .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                .frame(width: 84, height: 84)
                                .rotationEffect(.degrees(-90))
                            
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.white)
                        }
                        Text(loc.text(
    simplifiedChinese: "正在检查更新...",
    traditionalChinese: "正在檢查更新...",
    english: "Checking...",
    japanese: "チェックしています...",
    korean: "체크중...",
    russian: "Проверка..."
))
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.bottom, 22)
                } else if service.updates.isEmpty {
                    CircularActionButton(
                        title: loc.text(
    simplifiedChinese: "检查",
    traditionalChinese: "檢查",
    english: "Check",
    japanese: "チェック",
    korean: "확인",
    russian: "Проверка"
),
                        gradient: GradientStyles.updater,
                        action: { Task { await service.scanForUpdates() } }
                    )
                    .padding(.bottom, 22)
                }
            }
        }
    }

    private func updaterFeatureRow(image: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 18) {
            updaterResourceImage(image)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func updaterResourceImage(_ name: String) -> some View {
        if let path = Bundle.main.path(forResource: name, ofType: "png"),
           let image = NSImage(contentsOfFile: path) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "arrow.triangle.2.circlepath")
                .resizable()
                .scaledToFit()
                .foregroundColor(.white.opacity(0.65))
        }
    }
    
    // MARK: - Feature Row Helper
    func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    // MARK: - List View
    var listView: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left Panel: List
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button(action: { withAnimation { viewState = 0 }}) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text(loc.text(
    simplifiedChinese: "简介",
    traditionalChinese: "簡介",
    english: "Intro",
    japanese: "イントロ",
    korean: "Intro",
    russian: "Вводная"
))
                            }
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.leading, 11)
                    .padding(.trailing, 12)
                    .padding(.top, 19)
                    .padding(.bottom, 14)

                    HStack {
                        Button(action: {
                            service.selectAll()
                        }) {
                            Text(loc.text(
    simplifiedChinese: "全选",
    traditionalChinese: "全選",
    english: "Select All",
    japanese: "すべてを選択",
    korean: "전체선택",
    russian: "Выбрать все"
))
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        HStack(spacing: 4) {
                            Text(loc.text(
    simplifiedChinese: "排序方式按 上次打开时间",
    traditionalChinese: "排序方式按上次開啟時間",
    english: "Sort by Last Opened",
    japanese: "最後に開いたもので並べ替え",
    korean: "마지막 열림으로 정렬",
    russian: "Сортировать по последнему открытию"
))
                            Image(systemName: "chevron.down").font(.system(size: 7, weight: .bold))
                        }
                        .font(.system(size: 10.5))
                        .foregroundColor(.white.opacity(0.52))
                        .padding(.trailing, 32)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(service.updates) { item in
                                updateRow(item)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                .frame(width: 377)

                Rectangle()
                    .fill(Color.white.opacity(0.045))
                    .frame(width: 1)
                
                // Right Panel: Details
                if let selectedId = selectedUpdateId, let item = service.updates.first(where: { $0.id == selectedId }) {
                    ZStack(alignment: .bottom) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                // Header: Title
                                ZStack(alignment: .topLeading) {
                                    Text(loc.text(
    simplifiedChinese: "更新程序",
    traditionalChinese: "更新程式",
    english: "Updater",
    japanese: "Updater",
    korean: "업데이터",
    russian: "Обновления"
))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white.opacity(0.56))
                                        .offset(x: 10)
                                    // Search Bar Mock
                                    HStack {
                                        Image(systemName: "magnifyingglass")
                                        Text(loc.text(
    simplifiedChinese: "搜索",
    traditionalChinese: "搜尋",
    english: "Search",
    japanese: "検索する",
    korean: "검색",
    russian: "Поиск"
))
                                    }
                                    .padding(6)
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(6)
                                    .foregroundColor(.white.opacity(0.5))
                                    .font(.system(size: 12))
                                    .frame(width: 200, height: 30, alignment: .leading)
                                    .offset(x: 134)
                                }
                                .padding(.top, 16)
                                .padding(.horizontal, 20)
                                
                                // App Title
                                Text(item.app.name)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .offset(y: -20)
                                
                                // Version Info Line
                                HStack(spacing: 12) {
                                    Text(loc.text(
                                        simplifiedChinese: "版本 \(item.app.version ?? "?")",
                                        traditionalChinese: "版本 \(item.app.version ?? "?")",
                                        english: "Version \(item.app.version ?? "?")",
                                        japanese: "バージョン \(item.app.version ?? "?")",
                                        korean: "버전 \(item.app.version ?? "?")",
                                        russian: "Версия \(item.app.version ?? "?")"
                                    ))
                                        .foregroundColor(.white.opacity(0.6))
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.4))
                                    Text(item.newVersion)
                                        .foregroundColor(.white)
                                        .fontWeight(.bold)
                                    
                                    Text("|")
                                        .foregroundColor(.white.opacity(0.2))
                                    
                                    Text(item.releaseDate)
                                        .foregroundColor(.white.opacity(0.6))
                                    
                                    Spacer()
                                    
                                    Text(item.size)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .font(.system(size: 13))
                                .padding(.horizontal, 30)
                                .offset(y: -20)
                                
                                // Screenshots
                                if !item.screenshotUrls.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(item.screenshotUrls, id: \.self) { url in
                                                AsyncImage(url: url) { phase in
                                                    if let image = phase.image {
                                                        image.resizable()
                                                             .aspectRatio(contentMode: .fill)
                                                             .frame(width: 400, height: 250)
                                                             .clipped()
                                                             .cornerRadius(8)
                                                    } else {
                                                        Rectangle()
                                                            .fill(Color.white.opacity(0.1))
                                                            .frame(width: 400, height: 250)
                                                            .cornerRadius(8)
                                                    }
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                    .offset(y: -10)
                                }
                                
                                // Release Notes
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(loc.text(
    simplifiedChinese: "最近更新：",
    traditionalChinese: "最近更新",
    english: "What's New:",
    japanese: "更新情報",
    korean: "새소식",
    russian: "Что нового:"
))
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text(item.releaseNotes ?? (loc.text(
    simplifiedChinese: "暂无更新说明",
    traditionalChinese: "暫無更新說明",
    english: "No update notes available",
    japanese: "利用可能なアップデートノートはありません",
    korean: "사용 가능한 업데이트 메모 없음",
    russian: "Заметки об обновлении отсутствуют"
)))
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.8))
                                        .lineSpacing(4)
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 100)
                                .offset(y: -10)
                            }
                        }
                        
                        // Update Button (Centered) - Now handles BULK update
                        Button(action: {
                            // Start Update
                            withAnimation {
                                viewState = 2
                            }
                            Task {
                                await service.updateSelectedApps()
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(service.updates.filter { $0.isSelected }.isEmpty ? Color.gray.opacity(0.3) : Color.blue.opacity(0.8)) // Change color when active
                                    .frame(width: 60, height: 60)
                                    .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                                
                                Circle()
                                    .stroke(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                                    .frame(width: 58, height: 58)
                                
                                VStack(spacing: 0) {
                                    Text(loc.text(
    simplifiedChinese: "更新",
    traditionalChinese: "更新",
    english: "Update",
    japanese: "更新",
    korean: "업데이트",
    russian: "Обновить"
))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    let count = service.updates.filter { $0.isSelected }.count
                                    if count > 0 {
                                        Text("(\(count))")
                                            .font(.system(size: 10))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 30)
                        .disabled(service.updates.filter { $0.isSelected }.isEmpty)
                    }
                } else {
                    Spacer()
                }
            }
        }
    }
    
    func updateRow(_ item: AppUpdateItem) -> some View {
        HStack(spacing: 12) {
            // Checkbox Area
            ZStack {
                Circle()
                    .stroke(item.isSelected ? Color.green : Color.white.opacity(0.4), lineWidth: 1.5)
                    .frame(width: 18, height: 18)
                
                if item.isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                service.toggleSelection(for: item)
            }
            .frame(width: 30, height: 30) // Larger hit area
            
            // Item Content (Clicking here selects details)
            HStack(spacing: 12) {
                // Icon (Real NSImage)
                Image(nsImage: item.app.icon)
                    .resizable()
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.app.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    Text(loc.text(
    simplifiedChinese: "版本 \(item.newVersion)",
    traditionalChinese: "版本",
    english: "Ver \(item.newVersion)",
    japanese: "Ver.",
    korean: "버전",
    russian: "Версия"
))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedUpdateId = item.id
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 60)
        .contentShape(Rectangle())
        .background(RoundedRectangle(cornerRadius: 9).fill(selectedUpdateId == item.id ? Color.black.opacity(0.13) : Color.clear))
        .padding(.horizontal, 10)
    }
    
    // MARK: - Updating View (进度页面)
    var updatingView: some View {
        VStack(spacing: 0) {
            // 顶部导航
            HStack {
                Button(action: {
                    if service.updateComplete {
                        withAnimation {
                            viewState = 1
                            service.updateComplete = false
                            service.appUpdateStatuses.removeAll()
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(loc.text(
    simplifiedChinese: "更新程序",
    traditionalChinese: "更新程式",
    english: "Updater",
    japanese: "Updater",
    korean: "업데이터",
    russian: "Обновления"
))
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(service.updateComplete ? 0.8 : 0.4))
                }
                .buttonStyle(.plain)
                .disabled(!service.updateComplete)
                
                Spacer()
                
                Text(service.updateComplete ? 
                     (loc.text(
    simplifiedChinese: "更新完成",
    traditionalChinese: "更新完成",
    english: "Complete",
    japanese: "完了",
    korean: "완료",
    russian: "Пройти"
)) :
                     (loc.text(
    simplifiedChinese: "正在更新...",
    traditionalChinese: "正在更新...",
    english: "Updating...",
    japanese: "更新中...",
    korean: "업데이트 중…",
    russian: "Обновление..."
)))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                Text("").frame(width: 100)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // 当前更新的应用
            if !service.updateComplete && !service.currentlyUpdatingAppName.isEmpty {
                VStack(spacing: 8) {
                    Text(loc.text(
    simplifiedChinese: "正在更新",
    traditionalChinese: "正在更新",
    english: "Updating",
    japanese: "更新中",
    korean: "업데이트중",
    russian: "Новый адрес"
))
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                    Text(service.currentlyUpdatingAppName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.top, 20)
                .padding(.bottom, 10)
            }
            
            // Tab 切换栏
            if service.updateComplete {
                HStack(spacing: 0) {
                    tabButton(title: loc.text(
    simplifiedChinese: "全部",
    traditionalChinese: "全部",
    english: "All",
    japanese: "すべて",
    korean: "All",
    russian: "Все"
), 
                              count: service.updates.filter { $0.isSelected }.count, 
                              isSelected: selectedTab == 0, action: { selectedTab = 0 })
                    tabButton(title: loc.text(
    simplifiedChinese: "成功",
    traditionalChinese: "成功",
    english: "Success",
    japanese: "成功",
    korean: "성공",
    russian: "Успешно"
), 
                              count: successCount, isSelected: selectedTab == 1, 
                              action: { selectedTab = 1 }, color: .green)
                    tabButton(title: loc.text(
    simplifiedChinese: "失败",
    traditionalChinese: "失敗",
    english: "Failed",
    japanese: "失敗しました",
    korean: "실패함",
    russian: "Не удалось"
), 
                              count: failedCount, isSelected: selectedTab == 2, 
                              action: { selectedTab = 2 }, color: .red)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            
            // 更新列表
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(filteredUpdateItems) { item in
                        progressRow(item)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // 底部
            if service.updateComplete {
                VStack(spacing: 16) {
                    HStack(spacing: 40) {
                        VStack {
                            Text("\(successCount)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.green)
                            Text(loc.text(
    simplifiedChinese: "成功",
    traditionalChinese: "成功",
    english: "Success",
    japanese: "成功",
    korean: "성공",
    russian: "Успешно"
))
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        VStack {
                            Text("\(failedCount)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(failedCount > 0 ? .red : .white.opacity(0.5))
                            Text(loc.text(
    simplifiedChinese: "失败",
    traditionalChinese: "失敗",
    english: "Failed",
    japanese: "失敗しました",
    korean: "실패함",
    russian: "Не удалось"
))
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    Button(action: {
                        withAnimation {
                            viewState = 0
                            service.updateComplete = false
                            service.appUpdateStatuses.removeAll()
                            Task { await service.scanForUpdates() }
                        }
                    }) {
                        Text(loc.text(
    simplifiedChinese: "完成",
    traditionalChinese: "完成",
    english: "Done",
    japanese: "完了",
    korean: "완료",
    russian: "Готово"
))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 30)
            } else {
                VStack(spacing: 12) {
                    ProgressView(value: service.updateProgress)
                        .progressViewStyle(.linear)
                        .tint(Color(red: 0.4, green: 0.8, blue: 0.9))
                        .frame(width: 300)
                    Text("\(Int(service.updateProgress * 100))%")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    var successCount: Int {
        service.appUpdateStatuses.values.filter { $0 == .completed }.count
    }
    
    var failedCount: Int {
        service.appUpdateStatuses.values.filter { if case .failed(_) = $0 { return true }; return false }.count
    }
    
    var filteredUpdateItems: [AppUpdateItem] {
        let selected = service.updates.filter { $0.isSelected }
        switch selectedTab {
        case 1: return selected.filter { service.appUpdateStatuses[$0.id] == .completed }
        case 2: return selected.filter { if let s = service.appUpdateStatuses[$0.id], case .failed(_) = s { return true }; return false }
        default: return selected
        }
    }
    
    func tabButton(title: String, count: Int, isSelected: Bool, action: @escaping () -> Void, color: Color = .white) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text(title).font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? color : .white.opacity(0.6))
                    Text("(\(count))").font(.system(size: 11))
                        .foregroundColor(isSelected ? color.opacity(0.8) : .white.opacity(0.4))
                }
                Rectangle().fill(isSelected ? color : Color.clear).frame(height: 2)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
    
    func progressRow(_ item: AppUpdateItem) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Image(nsImage: item.app.icon).resizable().frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.app.name).font(.system(size: 14, weight: .medium)).foregroundColor(.white)
                    Text(loc.text(
    simplifiedChinese: "版本 \(item.newVersion)",
    traditionalChinese: "版本",
    english: "Ver \(item.newVersion)",
    japanese: "Ver.",
    korean: "버전",
    russian: "Версия"
))
                        .font(.system(size: 12)).foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                statusView(for: item)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
            .onTapGesture {
                if let s = service.appUpdateStatuses[item.id], case .failed(_) = s {
                    withAnimation {
                        if expandedFailedItems.contains(item.id) { expandedFailedItems.remove(item.id) }
                        else { expandedFailedItems.insert(item.id) }
                    }
                }
            }
            
            // 失败详情
            if let s = service.appUpdateStatuses[item.id], case .failed(let error) = s, expandedFailedItems.contains(item.id) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc.text(
    simplifiedChinese: "失败原因：",
    traditionalChinese: "失敗原因：",
    english: "Reason:",
    japanese: "理由：",
    korean: "이유:",
    russian: "Причина:"
))
                        .font(.system(size: 12, weight: .medium)).foregroundColor(.red.opacity(0.9))
                    Text(error).font(.system(size: 11)).foregroundColor(.white.opacity(0.7))
                    Button(action: { Task { await retryUpdate(for: item) } }) {
                        Text(loc.text(
    simplifiedChinese: "重试",
    traditionalChinese: "重試",
    english: "Retry",
    japanese: "再試行",
    korean: "다시 시도",
    russian: "Повторить попытку"
))
                            .font(.system(size: 11, weight: .medium)).foregroundColor(.cyan)
                            .padding(.horizontal, 12).padding(.vertical, 4)
                            .background(Color.cyan.opacity(0.15)).cornerRadius(4)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 16).padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color.white.opacity(0.05)).cornerRadius(8).padding(.vertical, 4)
    }
    
    func statusView(for item: AppUpdateItem) -> some View {
        Group {
            if let status = service.appUpdateStatuses[item.id] {
                switch status {
                case .pending:
                    Text(loc.text(
    simplifiedChinese: "等待中",
    traditionalChinese: "等待中",
    english: "Pending",
    japanese: "保留",
    korean: "대기",
    russian: "В процессе"
))
                        .font(.system(size: 12)).foregroundColor(.white.opacity(0.5))
                case .downloading:
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.6).progressViewStyle(.circular)
                        Text(loc.text(
    simplifiedChinese: "下载中",
    traditionalChinese: "下載中",
    english: "Downloading",
    japanese: "ダウンロード実績",
    korean: "다운로드 중",
    russian: "Скачивание"
))
                            .font(.system(size: 12)).foregroundColor(.cyan)
                    }
                case .installing:
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.6).progressViewStyle(.circular)
                        Text(loc.text(
    simplifiedChinese: "安装中",
    traditionalChinese: "安裝中...",
    english: "Installing",
    japanese: "インストール中",
    korean: "설치",
    russian: "Установка"
))
                            .font(.system(size: 12)).foregroundColor(.orange)
                    }
                case .completed:
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text(loc.text(
    simplifiedChinese: "完成",
    traditionalChinese: "完成",
    english: "Done",
    japanese: "完了",
    korean: "완료",
    russian: "Готово"
))
                            .font(.system(size: 12)).foregroundColor(.green)
                    }
                case .failed(_):
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                        Text(loc.text(
    simplifiedChinese: "更新失败",
    traditionalChinese: "更新失敗",
    english: "Failed",
    japanese: "失敗しました",
    korean: "실패함",
    russian: "Не удалось"
))
                            .font(.system(size: 12)).foregroundColor(.red)
                        Image(systemName: expandedFailedItems.contains(item.id) ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10)).foregroundColor(.red.opacity(0.6))
                    }
                }
            } else {
                Text(loc.text(
    simplifiedChinese: "等待中",
    traditionalChinese: "等待中",
    english: "Pending",
    japanese: "保留",
    korean: "대기",
    russian: "В процессе"
))
                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.5))
            }
        }
    }
    
    func retryUpdate(for item: AppUpdateItem) async {
        guard let masPath = service.getMasPath(), let appStoreId = item.appStoreId else { return }
        await MainActor.run {
            service.appUpdateStatuses[item.id] = .installing
            expandedFailedItems.remove(item.id)
        }
        let (success, errorMsg) = await service.updateWithMas(masPath: masPath, appStoreId: appStoreId)
        await MainActor.run {
            service.appUpdateStatuses[item.id] = success ? .completed : .failed(errorMsg ?? "重试失败")
        }
    }
}
