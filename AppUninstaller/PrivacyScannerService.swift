import Foundation
import Combine
import AppKit
import SQLite3

// MARK: - 扫描状态
enum PrivacyScanState {
    case initial
    case scanning
    case completed
    case cleaning
    case finished
}

// MARK: - 隐私数据类型
enum PrivacyType: String, CaseIterable, Identifiable {
    case history = "浏览记录"
    case cookies = "Cookie 文件"
    case downloads = "下载记录"
    case permissions = "应用权限"
    case recentItems = "最近项目列表"
    case wifi = "Wi-Fi 网络"
    case chat = "聊天信息"
    case development = "开发痕迹" // Terminal, VSCode, etc.
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .history: return "clock.arrow.circlepath"
        case .cookies: return "lock.circle"
        case .downloads: return "arrow.down.circle"
        case .permissions: return "lock.shield" // 权限锁
        case .recentItems: return "clock" // 最近项目
        case .wifi: return "wifi" // Wi-Fi
        case .chat: return "message" // 聊天
        case .development: return "terminal" // 开发
        }
    }
}

// MARK: - 浏览器类型
enum BrowserType: String, CaseIterable, Identifiable {
    case safari = "Safari"
    case chrome = "Google Chrome"
    case firefox = "Firefox"
    case system = "System" // 系统项
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .safari: return "safari"
        case .chrome: return "globe"
        case .firefox: return "flame"
        case .system: return "applelogo"
        }
    }
}

// MARK: - 隐私项模型
struct PrivacyItem: Identifiable, Equatable {
    let id = UUID()
    let browser: BrowserType
    let type: PrivacyType
    let path: URL
    let size: Int64
    let displayPath: String // 用于显示更友好的路径或描述
    var isSelected: Bool = true
    var children: [PrivacyItem]? = nil // 子项列表（用于展开详情）
}

// MARK: - 应用权限项模型
struct AppPermission: Identifiable, Equatable {
    let id = UUID()
    let bundleId: String
    let appName: String
    let appIcon: NSImage
    let service: String         // kTCCServiceCamera
    let serviceName: String     // "相机"
    let serviceCategory: String // "隐私"
    let authValue: Int          // 0=拒绝, 2=允许
    let lastModified: Date
    
    static func == (lhs: AppPermission, rhs: AppPermission) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 浏览器数据类型
enum BrowserDataType: String, CaseIterable, Identifiable {
    case browsingHistory = "浏览历史"
    case downloadHistory = "下载历史"
    case cookies = "Cookies"
    case passwords = "已存储密码"
    case autofillForms = "自动填充表格"
    case searchQueries = "搜索问题"
    case lastSession = "上次活动时间表"
    case localStorage = "本地存储"
    case cache = "缓存"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .browsingHistory: return "clock.arrow.circlepath"
        case .downloadHistory: return "arrow.down.circle"
        case .cookies: return "network"
        case .passwords: return "key.fill"
        case .autofillForms: return "doc.text.fill"
        case .searchQueries: return "magnifyingglass"
        case .lastSession: return "clock"
        case .localStorage: return "internaldrive"
        case .cache: return "folder"
        }
    }
}

// MARK: - 浏览器数据项模型
struct BrowserDataItem: Identifiable, Equatable {
    let id = UUID()
    let browser: BrowserType
    let dataType: BrowserDataType
    let count: Int              // 条目数：377个Cookie
    let size: Int64             // 文件大小：229 KB
    let profile: String         // Profile名称：Default
    let appIcon: NSImage?       // 真实应用图标
    var isSelected: Bool = true
    
    static func == (lhs: BrowserDataItem, rhs: BrowserDataItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 隐私扫描服务
class PrivacyScannerService: ObservableObject {
    @Published var privacyItems: [PrivacyItem] = []
    @Published var appPermissions: [AppPermission] = [] // 新增：解析出的应用权限
    @Published var browserDataItems: [BrowserDataItem] = [] // 新增：解析出的浏览器数据
    @Published var isScanning: Bool = false
    @Published var scanProgress: Double = 0
    @Published var shouldStop = false
    @Published var hasScanned = false
    @Published var isCleaning = false
    @Published var cleanedSize: Int64 = 0
    private var shouldStopCleaning = false
    
    // 统计数据
    var totalHistoryCount: Int { count(for: .history) }
    var totalCookiesCount: Int { count(for: .cookies) }
    var totalPermissionsCount: Int { count(for: .permissions) }
    
    private let fileManager = FileManager.default
    
    private func count(for type: PrivacyType) -> Int {
        privacyItems.filter { $0.type == type }.count
    }
    
    var totalSize: Int64 {
        privacyItems.reduce(0) { $0 + $1.size }
    }
    
    var selectedSize: Int64 {
        privacyItems.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    func stopScan() {
        shouldStop = true
        isScanning = false
    }
    
    // MARK: - 扫描方法
    func scanAll() async {
        await MainActor.run {
            isScanning = true
            shouldStop = false
            privacyItems.removeAll()
            appPermissions.removeAll()
            browserDataItems.removeAll()
            scanProgress = 0
            hasScanned = false
            isCleaning = false
            cleanedSize = 0
        }
        
        // 1. 扫描浏览器数据
        let browsers = BrowserType.allCases.filter { $0 != .system }
        for (index, browser) in browsers.enumerated() {
            if shouldStop { break }
            let items = await scanBrowser(browser)
            await MainActor.run {
                privacyItems.append(contentsOf: items.filter { ScanResultIgnoreStore.shouldInclude($0.path) })
                scanProgress = Double(index + 1) / Double(browsers.count + 4)
            }
        }
        
        // 2. 扫描最近项目
        if !shouldStop {
            let recentItems = await scanRecentItems()
            await MainActor.run {
                privacyItems.append(contentsOf: recentItems.filter { ScanResultIgnoreStore.shouldInclude($0.path) })
                scanProgress += 0.1
            }
        }
        
        // 3. 扫描应用权限 (TCC)
        if !shouldStop {
            let permissions = await scanPermissions()
            print("🔵 [Privacy] scanPermissions returned \(permissions.count) items")
            await MainActor.run {
                privacyItems.append(contentsOf: permissions.filter { ScanResultIgnoreStore.shouldInclude($0.path) })
                print("🔵 [Privacy] Total privacyItems after adding permissions: \(privacyItems.count)")
                print("🔵 [Privacy] Permissions items: \(privacyItems.filter { $0.type == .permissions }.count)")
                
                // 打印前 10 个权限项
                let permItems = privacyItems.filter { $0.type == .permissions }
                for (index, item) in permItems.prefix(10).enumerated() {
                    print("  \(index + 1). \(item.displayPath)")
                }
                
                scanProgress += 0.1
            }
        }
        
        // 4. 扫描 Wi-Fi
        if !shouldStop {
            let wifiItems = await scanWiFi()
            await MainActor.run {
                privacyItems.append(contentsOf: wifiItems.filter { ScanResultIgnoreStore.shouldInclude($0.path) })
                scanProgress += 0.1
            }
        }
        
        // 5. 扫描聊天数据
        if !shouldStop {
            let chatItems = await scanChatData()
            await MainActor.run {
                privacyItems.append(contentsOf: chatItems.filter { ScanResultIgnoreStore.shouldInclude($0.path) })
                scanProgress += 0.1
            }
        }
        
        // 6. 扫描开发痕迹 (Terminal, VSCode)
        if !shouldStop {
            let devItems = await scanDevelopmentHistory()
            await MainActor.run {
                privacyItems.append(contentsOf: devItems.filter { ScanResultIgnoreStore.shouldInclude($0.path) })
                scanProgress = 1.0
                isScanning = false
            }
        } else {
             await MainActor.run { isScanning = false }
        }

        await MainActor.run {
            self.isScanning = false
            if !self.shouldStop {
                self.scanProgress = 1.0
                self.hasScanned = true
                for index in self.privacyItems.indices {
                    self.privacyItems[index].isSelected = false
                    if let children = self.privacyItems[index].children {
                        for childIndex in children.indices {
                            self.privacyItems[index].children![childIndex].isSelected = false
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 辅助方法：添加关联文件 (WAL/SHM)
    private func addWithRelatedFiles(path: URL, type: PrivacyType, browser: BrowserType, description: String, to items: inout [PrivacyItem]) {
        if let size = fileSize(at: path) {
            items.append(PrivacyItem(browser: browser, type: type, path: path, size: size, displayPath: description))
        }
        
        let walPath = path.appendingPathExtension("wal")
        if let size = fileSize(at: walPath) {
            items.append(PrivacyItem(browser: browser, type: type, path: walPath, size: size, displayPath: "\(description) (WAL)"))
        }
        
        let shmPath = path.appendingPathExtension("shm")
        if let size = fileSize(at: shmPath) {
            items.append(PrivacyItem(browser: browser, type: type, path: shmPath, size: size, displayPath: "\(description) (SHM)"))
        }
    }
    
    // MARK: - 进程检测与终止
    func checkRunningBrowsers() -> [BrowserType] {
        var running: [BrowserType] = []
        let apps = NSWorkspace.shared.runningApplications
        
        for app in apps {
            guard let bundleId = app.bundleIdentifier else { continue }
            if bundleId.contains("com.apple.Safari") {
                if !running.contains(.safari) { running.append(.safari) }
            } else if bundleId.contains("com.google.Chrome") {
                if !running.contains(.chrome) { running.append(.chrome) }
            } else if bundleId.contains("org.mozilla.firefox") {
                if !running.contains(.firefox) { running.append(.firefox) }
            }
        }
        return running
    }
    
    func closeBrowsers() async -> Bool {
        let apps = NSWorkspace.shared.runningApplications
        var success = true
        
        for app in apps {
            guard let bundleId = app.bundleIdentifier else { continue }
            if bundleId.contains("com.apple.Safari") || 
               bundleId.contains("com.google.Chrome") || 
               bundleId.contains("org.mozilla.firefox") {
                
                app.terminate()
                
                // 等待一段时间看是否关闭
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                if !app.isTerminated {
                    app.forceTerminate()
                }
                
                if !app.isTerminated {
                    success = false
                }
            }
        }
        return success
    }
    
    /// 递归切换选中状态
    func toggleSelection(for id: UUID) {
        func toggle(in items: inout [PrivacyItem]) -> Bool {
            for i in 0..<items.count {
                if items[i].id == id {
                    items[i].isSelected.toggle()
                    // 如果有子项，同步选中状态
                    if let children = items[i].children {
                        for j in 0..<children.count {
                            items[i].children![j].isSelected = items[i].isSelected
                        }
                    }
                    return true
                }
                // 递归查找子项
                if items[i].children != nil {
                    if toggle(in: &items[i].children!) {
                        
                        // 更新父项状态（可选：如果所有子项都被选中/取消，父项也要更新？暂不实现复杂逻辑）
                        return true
                    }
                }
            }
            return false
        }
        
        if toggle(in: &privacyItems) {
            objectWillChange.send()
        }
    }
    
    // MARK: - 清理方法
    func cleanSelected() async -> (cleaned: Int64, failed: Int64) {
        var cleaned: Int64 = 0
        var failed: Int64 = 0
        var successfullyDeleted: Set<URL> = []

        await MainActor.run {
            self.isCleaning = true
            self.cleanedSize = 0
            self.shouldStopCleaning = false
        }
        
        // DEBUG: Print all items and their selection state
        print("🔍 [DEBUG] Total privacy items: \(privacyItems.count)")
        for (index, item) in privacyItems.enumerated() {
            print("  [\(index)] \(item.displayPath) - selected: \(item.isSelected), path: \(item.path.lastPathComponent)")
        }
        
        // 1. Gather all unique paths to delete from selected items (recursive)
        // IMPORTANT: Skip permission items (type == .permissions) as they can't be deleted as files
        var pathsToDelete: Set<URL> = []
        
        func collectPaths(from items: [PrivacyItem]) {
            for item in items {
                if item.isSelected && item.type != .permissions {
                    // Skip invalid paths like /dev/null
                    if item.path.path != "/dev/null" && !item.path.path.isEmpty {
                        pathsToDelete.insert(item.path)
                    }
                }
                if let children = item.children {
                    collectPaths(from: children)
                }
            }
        }
        collectPaths(from: privacyItems)
        
        print("🧹 [Clean] Starting cleanup of \(pathsToDelete.count) paths")
        
        if pathsToDelete.isEmpty {
            print("⚠️ [Clean] WARNING: No items selected for deletion!")
            await MainActor.run { self.isCleaning = false }
            return (0, 0)
        }
        
        let itemsToDelete = privacyItems.filter { $0.isSelected }
        
        // 2. Terminate Browsers to release file locks
        let browsersToClose: Set<String> = Set(itemsToDelete.compactMap {
            switch $0.browser {
            case .chrome: return "com.google.Chrome"
            case .firefox: return "org.mozilla.firefox"
            case .safari: return "com.apple.Safari"
            default: return nil
            }
        })
        
        if !browsersToClose.isEmpty {
            print("🧹 [Clean] Closing browsers: \(browsersToClose)")
            for bundleId in browsersToClose {
                let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
                for app in apps {
                    app.terminate()
                }
            }
            try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
            
            for bundleId in browsersToClose {
                let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
                for app in apps {
                    if !app.isTerminated {
                        print("🧹 [Clean] Force terminating \(bundleId)")
                        app.forceTerminate()
                    }
                }
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        // 3. Perform Intelligent Cleaning
        for path in pathsToDelete {
            if shouldStopCleaning { break }
            let pathString = path.path
            let fileName = path.lastPathComponent
            
            // Check if this is a browser database that should be cleaned with SQL
            if pathString.contains("/Google/Chrome/") {
                // Use SQL DELETE for Chrome databases to preserve login state
                if fileName == "History" {
                    print("🧹 [Clean] Clearing Chrome History with SQL...")
                    let cleared = clearChromeHistory(at: path)
                    if cleared > 0 {
                        successfullyDeleted.insert(path)
                        print("✅ [Clean] Cleared Chrome History tables")
                    }
                    continue
                } else if fileName == "Cookies" {
                    print("🧹 [Clean] Clearing Chrome Cookies with SQL...")
                    let cleared = clearChromeCookies(at: path)
                    if cleared > 0 {
                        successfullyDeleted.insert(path)
                        print("✅ [Clean] Cleared Chrome Cookies")
                    }
                    continue
                } else if fileName == "Web Data" {
                    print("🧹 [Clean] Clearing Chrome Autofill with SQL...")
                    let cleared = clearChromeAutofillData(at: path)
                    if cleared > 0 {
                        successfullyDeleted.insert(path)
                        print("✅ [Clean] Cleared Chrome Autofill")
                    }
                    continue
                }
                // Other Chrome files (GPU Cache, Favicons, etc.) - delete normally
            } else if pathString.contains("/Safari/") && fileName == "History.db" {
                print("🧹 [Clean] Clearing Safari History with SQL...")
                let cleared = clearSafariHistory(at: path)
                if cleared > 0 {
                    successfullyDeleted.insert(path)
                    print("✅ [Clean] Cleared Safari History")
                }
                continue
            }
            
            // Default: Delete file normally
            do {
                if fileManager.fileExists(atPath: path.path) {
                    print("🧹 [Clean] Deleting: \(path.path)")
                    // ⚠️ 安全修复: 优先使用trashItem
                    do {
                        try fileManager.trashItem(at: path, resultingItemURL: nil)
                        print("✅ [Clean] Moved to trash: \(path.lastPathComponent)")
                    } catch {
                        // Keep the result visible if a recoverable move fails.
                        // Privacy cleanup must not silently become permanent.
                        throw error
                    }
                    
                    // Verify deletion
                    if !fileManager.fileExists(atPath: path.path) {
                        successfullyDeleted.insert(path)
                        print("✅ [Clean] SUCCESS: \(path.lastPathComponent)")
                    } else {
                        print("⚠️ [Clean] File still exists after deletion: \(path.path)")
                        failed += 1
                    }
                    
                    // Delete related SQLite files
                    let relatedPaths = [
                        pathString + "-wal",
                        pathString + "-shm", 
                        pathString + "-journal"
                    ]
                    for relPath in relatedPaths {
                        if fileManager.fileExists(atPath: relPath) {
                            try? fileManager.trashItem(at: URL(fileURLWithPath: relPath), resultingItemURL: nil)
                        }
                    }
                } else {
                    // File doesn't exist, consider it "cleaned"
                    successfullyDeleted.insert(path)
                }
            } catch let error as NSError {
                if error.code == 513 || error.domain == NSCocoaErrorDomain {
                    print("❌ [Clean] PERMISSION DENIED: \(path.lastPathComponent)")
                    print("   → 请在系统设置中授予\"完全磁盘访问权限\"")
                } else {
                    print("❌ [Clean] ERROR: \(path.lastPathComponent) - \(error.localizedDescription)")
                }
                failed += 1
            }
        }
        
        // Calculate cleaned size from successfully deleted paths
        func sumSize(from items: [PrivacyItem], deleted: Set<URL>) {
            for item in items {
                if deleted.contains(item.path) {
                    cleaned += item.size
                }
                if let children = item.children {
                    sumSize(from: children, deleted: deleted)
                }
            }
        }
        sumSize(from: privacyItems, deleted: successfullyDeleted)
        
        print("🧹 [Clean] Result: \(successfullyDeleted.count) deleted, \(failed) failed")
        
        // 4. Handle Recent Items refresh
        if itemsToDelete.contains(where: { $0.type == .recentItems }) {
            print("🧹 [Clean] Clearing Finder Recents metadata...")
            
            // Kill sharedfilelistd to release .sfl files
            let task = Process()
            task.launchPath = "/usr/bin/killall"
            task.arguments = ["sharedfilelistd"]
            try? task.run()
            
            // Clear Spotlight kMDItemLastUsedDate metadata for recent files
            // This is what Finder "Recents" actually uses
            await clearSpotlightRecentMetadata()
            
            // Restart Finder to refresh
            let task2 = Process()
            task2.launchPath = "/usr/bin/killall"
            task2.arguments = ["Finder"]
            try? task2.run()
            
            print("✅ [Clean] Finder refresh commands sent")
        }
        
        // 5. Handle Permission Reset using tccutil
        let selectedPermissions = privacyItems.filter { $0.type == .permissions && $0.isSelected }
        if !selectedPermissions.isEmpty {
            print("🔒 [Clean] Resetting \(selectedPermissions.count) TCC permissions...")
            await resetTCCPermissions(selectedPermissions)
        }
        
        
        let finalDeleted = successfullyDeleted // Create immutable copy for thread safety
        let finalCleanedSize = cleaned
        await MainActor.run {
            // Remove successfully deleted file items from list
            privacyItems.removeAll { item in
                finalDeleted.contains(item.path)
            }
            self.cleanedSize = finalCleanedSize
            self.isCleaning = false
        }
        
        return (cleaned, failed)
    }

    func stopCleaning() {
        shouldStopCleaning = true
    }

    func reset() {
        shouldStop = true
        shouldStopCleaning = true
        privacyItems = []
        appPermissions = []
        browserDataItems = []
        isScanning = false
        scanProgress = 0
        hasScanned = false
        isCleaning = false
        cleanedSize = 0
    }
    
    /// Clear Spotlight kMDItemLastUsedDate metadata from recently used files
    /// This is what Finder "Recents" smart folder actually uses
    private func clearSpotlightRecentMetadata() async {
        let home = FileManager.default.homeDirectoryForCurrentUser
        
        // Common directories where recent files are typically found
        let directories = [
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Downloads")
        ]
        
        var clearedCount = 0
        
        for dir in directories {
            guard fileManager.fileExists(atPath: dir.path) else { continue }
            
            // Get files in directory (non-recursive to avoid too many files)
            if let contents = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                for file in contents.prefix(100) { // Limit to 100 files per directory
                    // Use xattr to remove kMDItemLastUsedDate
                    let process = Process()
                    process.launchPath = "/usr/bin/xattr"
                    process.arguments = ["-d", "com.apple.metadata:kMDItemLastUsedDate", file.path]
                    process.standardOutput = FileHandle.nullDevice
                    process.standardError = FileHandle.nullDevice
                    
                    try? process.run()
                    process.waitUntilExit()
                    
                    if process.terminationStatus == 0 {
                        clearedCount += 1
                    }
                }
            }
        }
        
        print("🧹 [Clean] Cleared kMDItemLastUsedDate from \(clearedCount) files")
    }
    
    /// Reset TCC permissions using tccutil command
    /// WARNING: This feature is DISABLED because tccutil reset resets ALL apps' permissions,
    /// including our own app's FDA and ScreenCapture permissions, which breaks the app.
    /// For now, permissions are VIEW-ONLY. Users should manage permissions in System Settings.
    private func resetTCCPermissions(_ permissions: [PrivacyItem]) async {
        print("⚠️ [TCC] Permission reset is DISABLED to protect app functionality.")
        print("   Permissions are view-only. Please manage permissions in System Settings.")
        print("   Selected \(permissions.count) permissions for review.")
        
        // Do NOT actually reset permissions as it would break the app
        // The previous implementation using tccutil reset was too dangerous
        // because it resets permissions for ALL apps, not just third-party apps.
    }
    
    // MARK: - Helper Scanning Methods
    
    private func scanBrowser(_ browser: BrowserType) async -> [PrivacyItem] {
        var items: [PrivacyItem] = []
        
        switch browser {
        case .safari:
            items.append(contentsOf: scanSafari())
        case .chrome:
            items.append(contentsOf: scanChrome())
        case .firefox:
            items.append(contentsOf: scanFirefox())
        case .system:
            break
        }
        
        return items
    }
    
    private func scanSafari() -> [PrivacyItem] {
        var items: [PrivacyItem] = []
        let home = FileManager.default.homeDirectoryForCurrentUser
        
        // 1. History
        let historyURL = home.appendingPathComponent("Library/Safari/History.db")
        addWithRelatedFiles(path: historyURL, type: .history, browser: .safari, description: "Safari 浏览记录数据库", to: &items)
        
        // 2. Downloads
        let downloadsURL = home.appendingPathComponent("Library/Safari/Downloads.plist")
         if let size = fileSize(at: downloadsURL) {
            items.append(PrivacyItem(browser: .safari, type: .downloads, path: downloadsURL, size: size, displayPath: "Safari 下载记录列表"))
        }
        
        // 3. Cookies - Check multiple locations for different macOS versions
        let cookiesPaths = [
            // Classic location (macOS Mojave and earlier)
            home.appendingPathComponent("Library/Cookies/Cookies.binarycookies"),
            // Containers location (macOS Catalina+)
            home.appendingPathComponent("Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies"),
            // Safari 16+ on macOS Ventura/Sonoma
            home.appendingPathComponent("Library/Safari/Cookies"),
            // WebKit Cookies
            home.appendingPathComponent("Library/WebKit/com.apple.Safari/Cookies/Cookies.binarycookies")
        ]
        
        for cookiesURL in cookiesPaths {
            if let size = fileSize(at: cookiesURL) {
                items.append(PrivacyItem(browser: .safari, type: .cookies, path: cookiesURL, size: size, displayPath: "Safari Cookie 文件"))
                print("   ✅ Found Safari Cookies at: \(cookiesURL.path)")
                break // Only add once
            }
            // Check if it's a directory
            if let size = folderSize(at: cookiesURL), size > 0 {
                items.append(PrivacyItem(browser: .safari, type: .cookies, path: cookiesURL, size: size, displayPath: "Safari Cookies 目录"))
                print("   ✅ Found Safari Cookies directory at: \(cookiesURL.path)")
                break
            }
        }
        
        // Also check for system-wide cookies that Safari uses
        let systemCookiesURL = URL(fileURLWithPath: "/Library/Cookies")
        if fileManager.fileExists(atPath: systemCookiesURL.path) {
            if let size = folderSize(at: systemCookiesURL), size > 0 {
                items.append(PrivacyItem(browser: .safari, type: .cookies, path: systemCookiesURL, size: size, displayPath: "系统 Cookies"))
            }
        }
        
        // 4. LocalStorage
        let localStorageURL = home.appendingPathComponent("Library/Safari/LocalStorage")
        if let size = folderSize(at: localStorageURL), size > 0 {
            items.append(PrivacyItem(browser: .safari, type: .history, path: localStorageURL, size: size, displayPath: "Safari 本地存储"))
        }
        
        // 5. WebsiteData (Databases, IndexedDB, etc.)
        let websiteDataURL = home.appendingPathComponent("Library/Safari/Databases")
        if let size = folderSize(at: websiteDataURL), size > 0 {
            items.append(PrivacyItem(browser: .safari, type: .history, path: websiteDataURL, size: size, displayPath: "Safari 网站数据库"))
        }
        
        // 6. Touch Icons / Favicon Cache
        let touchIconsURL = home.appendingPathComponent("Library/Safari/Touch Icons Cache")
        if let size = folderSize(at: touchIconsURL), size > 0 {
            items.append(PrivacyItem(browser: .safari, type: .history, path: touchIconsURL, size: size, displayPath: "Safari 图标缓存"))
        }
        
        // 7. Form Values
        let formValuesURL = home.appendingPathComponent("Library/Safari/Form Values")
        if let size = fileSize(at: formValuesURL) {
            items.append(PrivacyItem(browser: .safari, type: .history, path: formValuesURL, size: size, displayPath: "Safari 表单数据"))
        }
        
        // 8. Safari Caches
        let safariCacheURL = home.appendingPathComponent("Library/Caches/com.apple.Safari")
        if let size = folderSize(at: safariCacheURL), size > 0 {
            items.append(PrivacyItem(browser: .safari, type: .history, path: safariCacheURL, size: size, displayPath: "Safari 缓存"))
        }
        
        // 9. Last Session
        let lastSessionURL = home.appendingPathComponent("Library/Safari/LastSession.plist")
        if let size = fileSize(at: lastSessionURL) {
            items.append(PrivacyItem(browser: .safari, type: .history, path: lastSessionURL, size: size, displayPath: "Safari 上次会话"))
        }
        
        // 10. Top Sites
        let topSitesURL = home.appendingPathComponent("Library/Safari/TopSites.plist")
        if let size = fileSize(at: topSitesURL) {
            items.append(PrivacyItem(browser: .safari, type: .history, path: topSitesURL, size: size, displayPath: "Safari 热门网站"))
        }

        // 11. Favicon Cache
        let faviconsURL = home.appendingPathComponent("Library/Safari/Favicon Cache")
        if let size = folderSize(at: faviconsURL), size > 0 {
            items.append(PrivacyItem(browser: .safari, type: .history, path: faviconsURL, size: size, displayPath: "Safari 网站图标缓存"))
        }
        
        // 12. Remote Notifications
        let remoteNotifURL = home.appendingPathComponent("Library/Safari/RemoteNotification")
        if let size = folderSize(at: remoteNotifURL), size > 0 {
             items.append(PrivacyItem(browser: .safari, type: .history, path: remoteNotifURL, size: size, displayPath: "Safari 远程通知缓存"))
        }

        // 13. Recently Closed Tabs
        let closedTabsURL = home.appendingPathComponent("Library/Safari/RecentlyClosedTabs.plist")
        if let size = fileSize(at: closedTabsURL) {
            items.append(PrivacyItem(browser: .safari, type: .history, path: closedTabsURL, size: size, displayPath: "Safari 最近关闭标签页"))
        }

        return items
    }
    
    private func scanChrome() -> [PrivacyItem] {
        var items: [PrivacyItem] = []
        let home = FileManager.default.homeDirectoryForCurrentUser
        let chromeDir = home.appendingPathComponent("Library/Application Support/Google/Chrome")
        
        guard fileManager.fileExists(atPath: chromeDir.path) else { return [] }
        
        print("🔍 [Chrome] Starting deep scan...")
        
        // 扫描所有 Profile
        var profiles: [URL] = []
        let defaultPath = chromeDir.appendingPathComponent("Default")
        if fileManager.fileExists(atPath: defaultPath.path) {
            profiles.append(defaultPath)
        }
        
        // 查找其他 Profile
        if let contents = try? fileManager.contentsOfDirectory(at: chromeDir, includingPropertiesForKeys: nil) {
            for item in contents where item.lastPathComponent.hasPrefix("Profile ") {
                profiles.append(item)
            }
        }
        
        print("   Found \(profiles.count) Chrome profiles")
        
        for profile in profiles {
            let profileName = profile.lastPathComponent
            
            // ===== 1. 解析 History 数据库 =====
            let historyURL = profile.appendingPathComponent("History")
            if fileManager.fileExists(atPath: historyURL.path) {
                let (visits, downloads, searches) = parseChromeHistory(at: historyURL)
                let historySize = fileSize(at: historyURL) ?? 0
                
                print("   ✅ \(profileName) - History: \(visits) visits, \(downloads) downloads, \(searches) searches")
                
                if visits > 0 {
                    items.append(PrivacyItem(browser: .chrome, type: .history, path: historyURL, size: historySize, displayPath: "Chrome 浏览历史 (\(profileName)) - \(visits) 条记录"))
                }
                if downloads > 0 {
                    items.append(PrivacyItem(browser: .chrome, type: .downloads, path: historyURL, size: 0, displayPath: "Chrome 下载历史 (\(profileName)) - \(downloads) 条记录"))
                }
                if searches > 0 {
                    items.append(PrivacyItem(browser: .chrome, type: .history, path: historyURL, size: 0, displayPath: "Chrome 搜索问题 (\(profileName)) - \(searches) 条记录"))
                }
            }
            
            // ===== 2. 解析 Cookies 数据库 =====
            let cookiesURL = profile.appendingPathComponent("Cookies")
            if fileManager.fileExists(atPath: cookiesURL.path) {
                let cookieCount = parseChromeCookies(at: cookiesURL)
                let cookieSize = fileSize(at: cookiesURL) ?? 0
                
                print("   ✅ \(profileName) - Cookies: \(cookieCount) cookies")
                
                if cookieCount > 0 {
                    // 解析详情 (Top 100 Domains)
                    let details = parseChromeCookiesDetails(at: cookiesURL)
                    let children = details.map { (domain, count) in
                        PrivacyItem(
                            browser: .chrome,
                            type: .cookies,
                            path: cookiesURL,
                            size: 0,
                            displayPath: "\(domain) - \(count) 项"
                        )
                    }
                    
                    items.append(PrivacyItem(
                        browser: .chrome, 
                        type: .cookies, 
                        path: cookiesURL, 
                        size: cookieSize, 
                        displayPath: "Chrome Cookies (\(profileName)) - \(cookieCount) 个",
                        children: children.isEmpty ? nil : children
                    ))
                }
            }
            
            // ===== 3. 解析 Login Data (密码) =====
            let loginDataURL = profile.appendingPathComponent("Login Data")
            if fileManager.fileExists(atPath: loginDataURL.path) {
                let passwordCount = parseChromePasswords(at: loginDataURL)
                let loginSize = fileSize(at: loginDataURL) ?? 0
                
                print("   ✅ \(profileName) - Passwords: \(passwordCount) passwords")
                
                if passwordCount > 0 {
                    items.append(PrivacyItem(browser: .chrome, type: .history, path: loginDataURL, size: loginSize, displayPath: "Chrome 已存储密码 (\(profileName)) - \(passwordCount) 个"))
                }
            }
            
            // ===== 4. 解析 Web Data (自动填充) =====
            let webDataURL = profile.appendingPathComponent("Web Data")
            if fileManager.fileExists(atPath: webDataURL.path) {
                let autofillCount = parseChromeAutofill(at: webDataURL)
                let webDataSize = fileSize(at: webDataURL) ?? 0
                
                print("   ✅ \(profileName) - Autofill: \(autofillCount) entries")
                
                if autofillCount > 0 {
                    items.append(PrivacyItem(browser: .chrome, type: .history, path: webDataURL, size: webDataSize, displayPath: "Chrome 自动填充表格 (\(profileName)) - \(autofillCount) 个"))
                }
            }
            
            // ===== 5. Local Storage =====
            let localStorageURL = profile.appendingPathComponent("Local Storage/leveldb")
            if let size = folderSize(at: localStorageURL), size > 0 {
                items.append(PrivacyItem(browser: .chrome, type: .history, path: localStorageURL, size: size, displayPath: "Chrome 本地存储 (\(profileName))"))
            }
            
            // ===== 6. IndexedDB =====
            let indexedDBURL = profile.appendingPathComponent("IndexedDB")
            if let size = folderSize(at: indexedDBURL), size > 0 {
                items.append(PrivacyItem(browser: .chrome, type: .history, path: indexedDBURL, size: size, displayPath: "Chrome IndexedDB (\(profileName))"))
            }
            
            // ===== 7. Cache =====
            let cacheURL = profile.appendingPathComponent("Cache")
            if let size = folderSize(at: cacheURL), size > 0 {
                items.append(PrivacyItem(browser: .chrome, type: .history, path: cacheURL, size: size, displayPath: "Chrome 缓存 (\(profileName))"))
            }
            
            // ===== 8. Service Worker =====
            let swCacheURL = profile.appendingPathComponent("Service Worker/CacheStorage")
            if let size = folderSize(at: swCacheURL), size > 0 {
                items.append(PrivacyItem(browser: .chrome, type: .history, path: swCacheURL, size: size, displayPath: "Chrome Service Worker 缓存 (\(profileName))"))
            }
            
            // ===== 9. GPU Cache =====
            let gpuCacheURL = profile.appendingPathComponent("GPUCache")
            if let size = folderSize(at: gpuCacheURL), size > 0 {
                items.append(PrivacyItem(browser: .chrome, type: .history, path: gpuCacheURL, size: size, displayPath: "Chrome GPU 缓存 (\(profileName))"))
            }

            // ===== 10. Session Data =====
            let sessionFiles = ["Last Session", "Last Tabs", "Current Session", "Current Tabs", "Top Sites", "Shortcuts", "Visited Links", "Favicons"]
            for sFile in sessionFiles {
                let sURL = profile.appendingPathComponent(sFile)
                if let size = fileSize(at: sURL) {
                    items.append(PrivacyItem(browser: .chrome, type: .history, path: sURL, size: size, displayPath: "Chrome \(sFile) (\(profileName))"))
                }
            }
        }
        
        print("   📊 Total Chrome items: \(items.count)")
        return items
    }

    
    private func scanFirefox() -> [PrivacyItem] {
        var items: [PrivacyItem] = []
        let home = FileManager.default.homeDirectoryForCurrentUser
        let firefoxDir = home.appendingPathComponent("Library/Application Support/Firefox/Profiles")
        
        guard fileManager.fileExists(atPath: firefoxDir.path) else { return [] }
        
        print("🔍 [Firefox] Starting deep scan...")
        
        
        // 获取 Firefox 图标 (暂未使用)
        _ = getAppIcon(for: .firefox)
        
        // 获取所有 Profile
        let profiles = (try? fileManager.contentsOfDirectory(at: firefoxDir, includingPropertiesForKeys: nil)) ?? []
        print("   Found \(profiles.count) Firefox profiles")
        
        for profile in profiles {
            let profileName = profile.lastPathComponent
            if profileName.hasPrefix(".") { continue } // 跳过隐藏文件
            
            // 1. History (places.sqlite)
            let placesURL = profile.appendingPathComponent("places.sqlite")
            if fileManager.fileExists(atPath: placesURL.path) {
                let visitCount = parseFirefoxHistory(at: placesURL)
                let size = fileSize(at: placesURL) ?? 0
                
                print("   ✅ \(profileName) - History: \(visitCount) visits")
                
                if visitCount > 0 {
                    items.append(PrivacyItem(
                        browser: .firefox,
                        type: .history, 
                        path: placesURL,
                        size: size,
                        displayPath: "Firefox 浏览历史 (\(profileName)) - \(visitCount) 条记录"
                    ))
                }
            }
            
            // 2. Cookies (cookies.sqlite)
            let cookiesURL = profile.appendingPathComponent("cookies.sqlite")
            if fileManager.fileExists(atPath: cookiesURL.path) {
                let cookieCount = parseFirefoxCookies(at: cookiesURL)
                let size = fileSize(at: cookiesURL) ?? 0
                
                print("   ✅ \(profileName) - Cookies: \(cookieCount) cookies")
                
                if cookieCount > 0 {
                    items.append(PrivacyItem(
                        browser: .firefox,
                        type: .cookies,
                        path: cookiesURL,
                        size: size,
                        displayPath: "Firefox Cookies (\(profileName)) - \(cookieCount) 个"
                    ))
                }
            }
            
            // 3. Form History (formhistory.sqlite)
            let formHistoryURL = profile.appendingPathComponent("formhistory.sqlite")
            if fileManager.fileExists(atPath: formHistoryURL.path) {
                let formCount = parseFirefoxFormHistory(at: formHistoryURL)
                let size = fileSize(at: formHistoryURL) ?? 0
                
                print("   ✅ \(profileName) - Form History: \(formCount) entries")
                
                if formCount > 0 {
                    items.append(PrivacyItem(
                        browser: .firefox,
                        type: .history,
                        path: formHistoryURL,
                        size: size,
                        displayPath: "Firefox 表单历史 (\(profileName)) - \(formCount) 条记录"
                    ))
                }
            }
            
            // 4. Cache
            // Firefox Cache 通常在 ~/Library/Caches/Firefox/Profiles/...
            let cacheDir = home.appendingPathComponent("Library/Caches/Firefox/Profiles/\(profileName)/cache2")
            if let size = folderSize(at: cacheDir), size > 0 {
                items.append(PrivacyItem(browser: .firefox, type: .history, path: cacheDir, size: size, displayPath: "Firefox 缓存 (\(profileName))"))
            }

            // 5. Local Storage (storage/default)
            let storageDir = profile.appendingPathComponent("storage/default")
            if let size = folderSize(at: storageDir), size > 0 {
                 items.append(PrivacyItem(browser: .firefox, type: .history, path: storageDir, size: size, displayPath: "Firefox 本地存储 (\(profileName))"))
            }
        }
        
        print("   📊 Total Firefox items: \(items.count)")
        
        return items
    }

    
    private func scanRecentItems() async -> [PrivacyItem] {
        var items: [PrivacyItem] = []
        let home = FileManager.default.homeDirectoryForCurrentUser
        
        let sflBase = home.appendingPathComponent("Library/Application Support/com.apple.sharedfilelist")
        if fileManager.fileExists(atPath: sflBase.path) {
            let enumerator = fileManager.enumerator(at: sflBase, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants])
            while let fileURL = enumerator?.nextObject() as? URL {
                let name = fileURL.lastPathComponent
                if name.hasSuffix(".sfl2") || name.hasSuffix(".sfl3") {
                    if let size = fileSize(at: fileURL) {
                        let dirName = fileURL.deletingLastPathComponent().lastPathComponent
                        let displayName: String
                        if dirName.contains("ApplicationRecentDocuments") {
                             displayName = "应用最近文档: \(name.replacingOccurrences(of: ".sfl3", with: "").replacingOccurrences(of: ".sfl2", with: "").replacingOccurrences(of: "com.apple.LSSharedFileList.", with: ""))"
                        } else {
                             displayName = "系统最近项目: \(name)"
                        }
                        
                        items.append(PrivacyItem(browser: .system, type: .recentItems, path: fileURL, size: size, displayPath: displayName))
                    }
                }
            }
        }
        
        // Specific plists
        let plists = [
            "Library/Preferences/com.apple.sidebarlists.plist",
            "Library/Preferences/com.apple.recentitems.plist"
        ]
        for p in plists {
            let url = home.appendingPathComponent(p)
            if fileManager.fileExists(atPath: url.path), let size = fileSize(at: url) {
                items.append(PrivacyItem(browser: .system, type: .recentItems, path: url, size: size, displayPath: "主要系统记录: \(url.lastPathComponent)"))
            }
        }
        
        // Recent Servers
        let recentServersDir = home.appendingPathComponent("Library/Recent Servers")
        if let size = folderSize(at: recentServersDir), size > 0 {
             items.append(PrivacyItem(browser: .system, type: .recentItems, path: recentServersDir, size: size, displayPath: "最近访问的服务器"))
        }

        return items
    }
    
    private func scanPermissions() async -> [PrivacyItem] {
        var items: [PrivacyItem] = []
        
        // 解析 TCC 数据库，获取详细的应用权限
        let systemTCCURL = URL(fileURLWithPath: "/Library/Application Support/com.apple.TCC/TCC.db")
        let userTCCURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db")
        
        print("🔍 [Privacy] Scanning TCC databases...")
        print("   System TCC: \(systemTCCURL.path)")
        print("   User TCC: \(userTCCURL.path)")
        
        // 1. 解析系统级 TCC 数据库
        let systemPerms = await parseTCCDatabase(at: systemTCCURL)
        print("   ✅ System permissions found: \(systemPerms.count)")
        
        // 2. 解析用户级 TCC 数据库
        let userPerms = await parseTCCDatabase(at: userTCCURL)
        print("   ✅ User permissions found: \(userPerms.count)")
        
        // 3. 合并权限
        let allPermissions = systemPerms + userPerms
        print("   📊 Total permissions: \(allPermissions.count)")
        
        // 4. 更新到 appPermissions
        await MainActor.run {
            self.appPermissions = allPermissions
        }
        
        // 5. 为兼容性：也创建 PrivacyItem 格式的权限记录（每个权限一项）
        for perm in allPermissions {
            items.append(PrivacyItem(
                browser: .system,
                type: .permissions,
                path: URL(fileURLWithPath: "/dev/null"), // 虚拟路径
                size: 0, // 权限本身没有文件大小
                displayPath: "\(perm.appName) - \(perm.serviceName)"
            ))
        }
        
        print("   ✅ Created \(items.count) PrivacyItems for permissions")
        
        return items
    }
    
    private func scanWiFi() async -> [PrivacyItem] {
        var items: [PrivacyItem] = []
        // /Library/Preferences/SystemConfiguration/com.apple.airport.preferences.plist
        let wifiURL = URL(fileURLWithPath: "/Library/Preferences/SystemConfiguration/com.apple.airport.preferences.plist")
        
        if let size = fileSize(at: wifiURL) {
            items.append(PrivacyItem(
                browser: .system,
                type: .wifi,
                path: wifiURL,
                size: size,
                displayPath: "已知 Wi-Fi 网络配置"
            ))
        }
        
        return items
    }
    
    private func scanChatData() async -> [PrivacyItem] {
        var items: [PrivacyItem] = []
        let home = FileManager.default.homeDirectoryForCurrentUser
        
        // 1. iMessage
        let messagesURL = home.appendingPathComponent("Library/Messages/chat.db")
        addWithRelatedFiles(path: messagesURL, type: .chat, browser: .system, description: "iMessage 聊天记录", to: &items)
        
        let attachmentsURL = home.appendingPathComponent("Library/Messages/Attachments")
        if let size = folderSize(at: attachmentsURL), size > 0 {
            items.append(PrivacyItem(browser: .system, type: .chat, path: attachmentsURL, size: size, displayPath: "iMessage 附件"))
        }
        
        // 2. 微信 (WeChat)
        let wechatContainerURL = home.appendingPathComponent("Library/Containers/com.tencent.xinWeChat")
        if fileManager.fileExists(atPath: wechatContainerURL.path) {
            // 聊天数据库
            let wechatDataURL = wechatContainerURL.appendingPathComponent("Data/Library/Application Support/com.tencent.xinWeChat")
            if let size = folderSize(at: wechatDataURL), size > 0 {
                items.append(PrivacyItem(browser: .system, type: .chat, path: wechatDataURL, size: size, displayPath: "微信聊天数据"))
            }
            
            // 缓存
            let wechatCacheURL = wechatContainerURL.appendingPathComponent("Data/Library/Caches")
            if let size = folderSize(at: wechatCacheURL), size > 0 {
                items.append(PrivacyItem(browser: .system, type: .chat, path: wechatCacheURL, size: size, displayPath: "微信缓存"))
            }
        }
        
        // 3. QQ
        let qqContainerURL = home.appendingPathComponent("Library/Containers/com.tencent.qq")
        if fileManager.fileExists(atPath: qqContainerURL.path) {
            let qqDataURL = qqContainerURL.appendingPathComponent("Data/Library/Application Support/QQ")
            if let size = folderSize(at: qqDataURL), size > 0 {
                items.append(PrivacyItem(browser: .system, type: .chat, path: qqDataURL, size: size, displayPath: "QQ 聊天数据"))
            }
            
            let qqCacheURL = qqContainerURL.appendingPathComponent("Data/Library/Caches")
            if let size = folderSize(at: qqCacheURL), size > 0 {
                items.append(PrivacyItem(browser: .system, type: .chat, path: qqCacheURL, size: size, displayPath: "QQ 缓存"))
            }
        }
        
        // 4. Telegram
        let telegramGroupURL = home.appendingPathComponent("Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram")
        if fileManager.fileExists(atPath: telegramGroupURL.path) {
            let telegramDataURL = telegramGroupURL.appendingPathComponent("stable")
            if let size = folderSize(at: telegramDataURL), size > 0 {
                items.append(PrivacyItem(browser: .system, type: .chat, path: telegramDataURL, size: size, displayPath: "Telegram 聊天数据"))
            }
        }
        
        // Telegram 缓存
        let telegramCacheURL = home.appendingPathComponent("Library/Caches/ru.keepcoder.Telegram")
        if let size = folderSize(at: telegramCacheURL), size > 0 {
            items.append(PrivacyItem(browser: .system, type: .chat, path: telegramCacheURL, size: size, displayPath: "Telegram 缓存"))
        }
        
        // 5. 企业微信
        let weworkContainerURL = home.appendingPathComponent("Library/Containers/com.tencent.WeWorkMac")
        if fileManager.fileExists(atPath: weworkContainerURL.path) {
            let weworkDataURL = weworkContainerURL.appendingPathComponent("Data/Library/Application Support")
            if let size = folderSize(at: weworkDataURL), size > 0 {
                items.append(PrivacyItem(browser: .system, type: .chat, path: weworkDataURL, size: size, displayPath: "企业微信聊天数据"))
            }
            
            let weworkCacheURL = weworkContainerURL.appendingPathComponent("Data/Library/Caches")
            if let size = folderSize(at: weworkCacheURL), size > 0 {
                items.append(PrivacyItem(browser: .system, type: .chat, path: weworkCacheURL, size: size, displayPath: "企业微信缓存"))
            }
        }
        
        // 6. 钉钉
        let dingtalkContainerURL = home.appendingPathComponent("Library/Containers/com.alibaba.DingTalkMac")
        if fileManager.fileExists(atPath: dingtalkContainerURL.path) {
            let dingtalkDataURL = dingtalkContainerURL.appendingPathComponent("Data/Library/Application Support")
            if let size = folderSize(at: dingtalkDataURL), size > 0 {
                items.append(PrivacyItem(browser: .system, type: .chat, path: dingtalkDataURL, size: size, displayPath: "钉钉聊天数据"))
            }
        }
        
        // 7. Slack
        let slackCacheURL = home.appendingPathComponent("Library/Caches/com.tinyspeck.slackmacgap")
        if let size = folderSize(at: slackCacheURL), size > 0 {
            items.append(PrivacyItem(browser: .system, type: .chat, path: slackCacheURL, size: size, displayPath: "Slack 缓存"))
        }
        
        let slackDataURL = home.appendingPathComponent("Library/Application Support/Slack")
        if let size = folderSize(at: slackDataURL), size > 0 {
            items.append(PrivacyItem(browser: .system, type: .chat, path: slackDataURL, size: size, displayPath: "Slack 数据"))
        }
        
        // 8. Discord
        let discordCacheURL = home.appendingPathComponent("Library/Application Support/discord")
        if let size = folderSize(at: discordCacheURL), size > 0 {
            items.append(PrivacyItem(browser: .system, type: .chat, path: discordCacheURL, size: size, displayPath: "Discord 数据"))
        }
        
        // 9. WhatsApp
        let whatsappCacheURL = home.appendingPathComponent("Library/Caches/net.whatsapp.WhatsApp")
        if let size = folderSize(at: whatsappCacheURL), size > 0 {
            items.append(PrivacyItem(browser: .system, type: .chat, path: whatsappCacheURL, size: size, displayPath: "WhatsApp 缓存"))
        }
        
        let whatsappDataURL = home.appendingPathComponent("Library/Application Support/WhatsApp")
        if let size = folderSize(at: whatsappDataURL), size > 0 {
            items.append(PrivacyItem(browser: .system, type: .chat, path: whatsappDataURL, size: size, displayPath: "WhatsApp 数据"))
        }

        // 10. Skype
        let skypeURL = home.appendingPathComponent("Library/Application Support/Skype")
         if let size = folderSize(at: skypeURL), size > 0 {
            items.append(PrivacyItem(browser: .system, type: .chat, path: skypeURL, size: size, displayPath: "Skype 数据"))
        }
        
        return items
    }
    
    private func scanDevelopmentHistory() async -> [PrivacyItem] {
        var items: [PrivacyItem] = []
        let home = FileManager.default.homeDirectoryForCurrentUser
        
        // 1. Terminal History
        let shellHistories = [
            ".zsh_history": "Zsh 命令历史",
            ".bash_history": "Bash 命令历史",
            ".python_history": "Python 命令历史",
            ".node_repl_history": "Node.js 命令历史",
            ".mysql_history": "MySQL 命令历史"
        ]
        
        for (filename, displayName) in shellHistories {
            let historyURL = home.appendingPathComponent(filename)
            if let size = fileSize(at: historyURL) {
                items.append(PrivacyItem(
                    browser: .system,
                    type: .development,
                    path: historyURL,
                    size: size,
                    displayPath: displayName
                ))
            }
        }
        
        // 2. VSCode
        let vscodePath = home.appendingPathComponent("Library/Application Support/Code")
        if fileManager.fileExists(atPath: vscodePath.path) {
            // History
            let historyURL = vscodePath.appendingPathComponent("User/History")
            if let size = folderSize(at: historyURL), size > 0 {
                items.append(PrivacyItem(browser: .system, type: .development, path: historyURL, size: size, displayPath: "VSCode 编辑历史"))
            }
            
            // Backups
            let backupsURL = vscodePath.appendingPathComponent("Backups")
            if let size = folderSize(at: backupsURL), size > 0 {
                items.append(PrivacyItem(browser: .system, type: .development, path: backupsURL, size: size, displayPath: "VSCode 工作区备份"))
            }
            
            // CachedData
            let cachedDataURL = vscodePath.appendingPathComponent("CachedData")
            if let size = folderSize(at: cachedDataURL), size > 0 {
                items.append(PrivacyItem(browser: .system, type: .development, path: cachedDataURL, size: size, displayPath: "VSCode 缓存数据"))
            }
        }
        
        // 3. Xcode
        let xcodeUserData = home.appendingPathComponent("Library/Developer/Xcode/UserData")
        if fileManager.fileExists(atPath: xcodeUserData.path) {
            // IB Support
            let ibSupport = xcodeUserData.appendingPathComponent("IB Support/Simulator")
            if let size = folderSize(at: ibSupport), size > 0 {
                 items.append(PrivacyItem(browser: .system, type: .development, path: ibSupport, size: size, displayPath: "Xcode Interface Builder 缓存"))
            }
        }
        
        return items
    }

    private func fileSize(at url: URL) -> Int64? {
        // 如果没有权限读取，可能会失败
        guard let attrs = try? fileManager.attributesOfItem(atPath: url.path) else { return nil }
        return attrs[.size] as? Int64
    }
    
    private func folderSize(at url: URL) -> Int64? {
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return nil }
        var size: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                size += Int64(fileSize)
            }
        }
        return size
    }
    
    // MARK: - TCC 数据库解析
    
    /// 解析 TCC 数据库，获取应用权限列表
    private func parseTCCDatabase(at url: URL) async -> [AppPermission] {
        var permissions: [AppPermission] = []
        
        // 1. 打开 SQLite 数据库
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            print("Failed to open TCC database at \(url.path)")
            return []
        }
        defer { sqlite3_close(db) }
        
        // 2. 查询所有权限 (client_type = 0 表示 Bundle ID)
        let query = "SELECT service, client, auth_value, last_modified FROM access WHERE client_type = 0"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("Failed to prepare TCC query")
            return []
        }
        defer { sqlite3_finalize(statement) }
        
        // 3. 遍历结果
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let servicePtr = sqlite3_column_text(statement, 0),
                  let clientPtr = sqlite3_column_text(statement, 1) else { continue }
            
            let service = String(cString: servicePtr)
            let bundleId = String(cString: clientPtr)
            let authValue = Int(sqlite3_column_int(statement, 2))
            let lastModified = sqlite3_column_int64(statement, 3)
            
            // 只包含已授权的权限 (authValue == 2 表示允许)
            guard authValue == 2 else { continue }
            
            // 4. 获取应用信息
            if let (appName, appIcon) = getAppInfo(bundleId: bundleId) {
                let (serviceName, serviceCategory) = localizeService(service)
                
                let perm = AppPermission(
                    bundleId: bundleId,
                    appName: appName,
                    appIcon: appIcon,
                    service: service,
                    serviceName: serviceName,
                    serviceCategory: serviceCategory,
                    authValue: authValue,
                    lastModified: Date(timeIntervalSince1970: TimeInterval(lastModified))
                )
                permissions.append(perm)
            }
        }
        
        return permissions
    }
    
    /// 获取应用图标和名称
    private func getAppInfo(bundleId: String) -> (String, NSImage)? {
        // 1. 尝试从 NSWorkspace 获取
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let appName = FileManager.default.displayName(atPath: appURL.path)
                .replacingOccurrences(of: ".app", with: "")
            let appIcon = NSWorkspace.shared.icon(forFile: appURL.path)
            return (appName, appIcon)
        }
        
        // 2. 尝试从常见路径查找
        let commonPaths = [
            "/Applications/\(bundleId).app",
            "/System/Applications/\(bundleId).app"
        ]
        
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                let appName = FileManager.default.displayName(atPath: path)
                    .replacingOccurrences(of: ".app", with: "")
                let appIcon = NSWorkspace.shared.icon(forFile: path)
                return (appName, appIcon)
            }
        }
        
        // 3. 降级：使用 Bundle ID，但过滤掉一些系统内部组件
        if bundleId.contains("apple") && !bundleId.contains("com.apple.Safari") {
            return nil // 跳过 Apple 内部组件
        }
        
        let defaultIcon = NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil) ?? NSImage()
        return (bundleId, defaultIcon)
    }
    
    /// 本地化权限类型
    private func localizeService(_ service: String) -> (name: String, category: String) {
        let isChinese = LocalizationManager.shared.currentLanguage == .chinese
        
        switch service {
        case "kTCCServiceCamera":
            return (isChinese ? "相机" : "Camera", isChinese ? "隐私" : "Privacy")
        case "kTCCServiceMicrophone":
            return (isChinese ? "麦克风" : "Microphone", isChinese ? "隐私" : "Privacy")
        case "kTCCServicePhotos", "kTCCServicePhotosAdd":
            return (isChinese ? "照片" : "Photos", isChinese ? "隐私" : "Privacy")
        case "kTCCServiceLocation":
            return (isChinese ? "位置" : "Location", isChinese ? "隐私" : "Privacy")
        case "kTCCServiceContacts":
            return (isChinese ? "通讯录" : "Contacts", isChinese ? "隐私" : "Privacy")
        case "kTCCServiceCalendar":
            return (isChinese ? "日历" : "Calendar", isChinese ? "隐私" : "Privacy")
        case "kTCCServiceReminders":
            return (isChinese ? "提醒事项" : "Reminders", isChinese ? "隐私" : "Privacy")
        case "kTCCServiceAddressBook":
            return (isChinese ? "通讯录" : "Address Book", isChinese ? "隐私" : "Privacy")
        case "kTCCServiceScreenCapture":
            return (isChinese ? "屏幕录制" : "Screen Recording", isChinese ? "隐私" : "Privacy")
        case "kTCCServiceAccessibility":
            return (isChinese ? "辅助功能" : "Accessibility", isChinese ? "隐私" : "Privacy")
        case "kTCCServicePostEvent":
            return (isChinese ? "输入监控" : "Input Monitoring", isChinese ? "隐私" : "Privacy")
        case "kTCCServiceSystemPolicyAllFiles":
            return (isChinese ? "完全磁盘访问" : "Full Disk Access", isChinese ? "隐私" : "Privacy")
        case "kTCCServiceSystemPolicyDesktopFolder":
            return (isChinese ? "桌面文件夹" : "Desktop Folder", isChinese ? "隐私" : "Privacy")
        case "kTCCServiceSystemPolicyDocumentsFolder":
            return (isChinese ? "文稿文件夹" : "Documents Folder", isChinese ? "隐私" : "Privacy")
        case "kTCCServiceSystemPolicyDownloadsFolder":
            return (isChinese ? "下载文件夹" : "Downloads Folder", isChinese ? "隐私" : "Privacy")
        case "kTCCServiceSystemPolicyNetworkVolumes":
            return (isChinese ? "网络卷" : "Network Volumes", isChinese ? "隐私" : "Privacy")
        case "kTCCServiceSystemPolicyRemovableVolumes":
            return (isChinese ? "可移动卷" : "Removable Volumes", isChinese ? "隐私" : "Privacy")
        case "kTCCServiceFileProviderDomain":
            return (isChinese ? "文件提供程序" : "File Provider", isChinese ? "隐私" : "Privacy")
        case "kTCCServiceFileProviderPresence":
            return (isChinese ? "文件提供程序状态" : "File Provider Presence", isChinese ? "隐私" : "Privacy")
        case "kTCCServiceMediaLibrary":
            return (isChinese ? "媒体资料库" : "Media Library", isChinese ? "隐私" : "Privacy")
        case "kTCCServiceSiri":
            return (isChinese ? "Siri" : "Siri", isChinese ? "隐私" : "Privacy")
        case "kTCCServiceSpeechRecognition":
            return (isChinese ? "语音识别" : "Speech Recognition", isChinese ? "隐私" : "Privacy")
        case "kTCCServiceAppleEvents":
            return (isChinese ? "自动化" : "Automation", isChinese ? "隐私" : "Privacy")
        case "kTCCServiceBluetoothAlways":
            return (isChinese ? "蓝牙" : "Bluetooth", isChinese ? "隐私" : "Privacy")
        case "kTCCServiceWillow":
            return (isChinese ? "HomeKit" : "HomeKit", isChinese ? "隐私" : "Privacy")
        default:
            // 未知权限类型，显示原始名称
            let cleaned = service.replacingOccurrences(of: "kTCCService", with: "")
            return (cleaned, isChinese ? "其他" : "Other")
        }
    }
}
