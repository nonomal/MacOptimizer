import SwiftUI

struct AppUninstallerView: View {
    @ObservedObject var appScanner: AppScanner
    @State private var selectedCategory: AppCategory = .all
    @State private var searchText = ""
    @State private var selectedAppIds: Set<UUID> = []
    @State private var showingDeleteConfirmation = false
    @State private var detailedApp: InstalledApp?
    @ObservedObject private var loc = LocalizationManager.shared
    
    // 卸载相关状态
    @State private var isUninstalling = false
    @State private var uninstallProgress: String = ""
    @State private var uninstallResults: [RemovalResult] = []
    @State private var showingResults = false
    @State private var totalRemovedSize: Int64 = 0
    @State private var totalSuccessCount = 0
    @State private var totalFailedCount = 0
    
    private let fileRemover = FileRemover()
    
    enum AppCategory: Hashable {
        case all
        case leftovers
        case appStore
        case vendor(String)
        
        var title: String {
            switch self {
            case .all: return LocalizationManager.shared.text("所有应用程序", "All Applications")
            case .leftovers: return LocalizationManager.shared.text("残留项", "Leftovers")
            case .appStore: return "App Store"
            case .vendor(let name): return name
            }
        }
        
        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .leftovers: return "trash.slash"
            case .appStore: return "bag" // or app.badge
            case .vendor: return "building.2"
            }
        }
    }
    
    var filteredApps: [InstalledApp] {
        let baseApps: [InstalledApp]
        switch selectedCategory {
        case .all:
            baseApps = appScanner.apps
        case .leftovers:
            baseApps = appScanner.apps.filter { !$0.residualFiles.isEmpty } // Placeholder logic
        case .appStore:
            baseApps = appScanner.apps.filter { $0.isAppStore }
        case .vendor(let name):
            baseApps = appScanner.apps.filter { $0.vendor == name }
        }
        
        if searchText.isEmpty {
            return baseApps
        }
        return baseApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    // Vendors list
    var vendors: [String] {
        let allVendors = appScanner.apps.map { $0.vendor }
        let unique = Array(Set(allVendors)).sorted()
        return unique.filter { $0 != "Unknown" }
    }
    
    var totalSelectedSize: Int64 {
        appScanner.apps.filter { selectedAppIds.contains($0.id) }.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // MARK: - Sidebar
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(loc.text(
    simplifiedChinese: "卸载器",
    traditionalChinese: "解除安裝器",
    english: "Uninstaller",
    japanese: "アンインストーラー",
    korean: "제거 프로그램",
    russian: "Удалитель"
))
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()
                
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.3))
                    TextField(loc.L("search_apps"), text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)
                }
                .padding(8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.bottom, 10)
                
                List {
                    // All Apps
                    SidebarRow(category: .all, count: appScanner.apps.count, isSelected: selectedCategory == .all)
                        .onTapGesture { selectedCategory = .all }
                    
                    // Leftovers (Placeholder)
                    SidebarRow(category: .leftovers, count: 0, isSelected: selectedCategory == .leftovers)
                        .onTapGesture { selectedCategory = .leftovers }
                    
                    Text(loc.text(
    simplifiedChinese: "商店",
    traditionalChinese: "商店",
    english: "Store",
    japanese: "ストア",
    korean: "스토어",
    russian: "эт."
))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.top, 10)
                        .padding(.leading, 8)
                    
                    SidebarRow(category: .appStore, count: appScanner.apps.filter { $0.isAppStore }.count, isSelected: selectedCategory == .appStore)
                        .onTapGesture { selectedCategory = .appStore }
                    
                    Text(loc.text(
    simplifiedChinese: "供应商",
    traditionalChinese: "供應商",
    english: "Vendors",
    japanese: "ベンダー",
    korean: "Vendors",
    russian: "Поставщики"
))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.top, 10)
                        .padding(.leading, 8)
                    
                    ForEach(vendors, id: \.self) { vendor in
                        SidebarRow(category: .vendor(vendor), count: appScanner.apps.filter { $0.vendor == vendor }.count, isSelected: selectedCategory == .vendor(vendor))
                            .onTapGesture { selectedCategory = .vendor(vendor) }
                    }
                }

                .listStyle(.plain)
                .compatibleScrollContentBackgroundHidden()
            }
            .frame(width: 250)
            // Left panel background removed for unification

            
            // MARK: - App List or Detail
            ZStack {
                if let app = detailedApp {
                    VStack(spacing: 0) {
                        // Navigation Bar
                        HStack {
                            Button(action: {
                                withAnimation {
                                    detailedApp = nil
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text(loc.text(
    simplifiedChinese: "返回",
    traditionalChinese: "返回",
    english: "Back",
    japanese: "戻る",
    korean: "뒤로",
    russian: "Назад"
))
                                }
                                .foregroundColor(.secondaryText)
                            }
                            .buttonStyle(.plain)
                            .padding()
                            
                            Spacer()
                        }
                        .background(Color.cardBackground)
                        
                        AppDetailView(
                            app: app,
                            onDelete: { includeApp, toTrash in
                                Task {
                                    await performSingleAppUninstall(app: app, includeApp: includeApp, moveToTrash: toTrash)
                                }
                            }
                        )
                    }
                    .transition(.move(edge: .trailing))
                } else {
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            Text(selectedCategory.title)
                                .font(.title2)
                                .foregroundColor(.white)
                            Spacer()
                            
                            Text(loc.text(
    simplifiedChinese: "排序方式按 名称",
    traditionalChinese: "排序方式按名稱",
    english: "Sort by Name",
    japanese: "名前でソート",
    korean: "이름으로 정렬",
    russian: "Сортировать по имени"
))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding()
                        
                        if appScanner.isScanning {
                             Spacer()
                             ProgressView()
                             Text(loc.text(
    simplifiedChinese: "正在扫描应用...",
    traditionalChinese: "正在掃描應用程式...",
    english: "Scanning Apps...",
    japanese: "アプリをスキャンしています...",
    korean: "앱 검사 중...",
    russian: "Сканирование приложений..."
))
                                .padding(.top)
                             Spacer()
                        } else {
                            LazyListView(items: filteredApps, itemHeight: 56) { app in
                                AppChecklistRow(
                                    app: app,
                                    isSelected: selectedAppIds.contains(app.id),
                                    onToggleSelection: {
                                        if selectedAppIds.contains(app.id) {
                                            selectedAppIds.remove(app.id)
                                        } else {
                                            selectedAppIds.insert(app.id)
                                        }
                                    },
                                    onViewDetails: {
                                        withAnimation {
                                            detailedApp = app
                                        }
                                    }
                                )
                            }
                        }
                        
                        // Bottom Bar (Uninstall Action)
                        if !selectedAppIds.isEmpty {
                            HStack {
                                Spacer()
                                
                                VStack(spacing: 4) {
                                    Button(action: {
                                        showingDeleteConfirmation = true
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.blue.opacity(0.2))
                                                .frame(width: 80, height: 80)
                                                .overlay(
                                                    Circle().stroke(Color.blue.opacity(0.5), lineWidth: 1)
                                                )
                                            
                                            VStack {
                                                Text(loc.text(
    simplifiedChinese: "卸载",
    traditionalChinese: "卸載",
    english: "Uninstall",
    japanese: "アンインストール",
    korean: "제거",
    russian: "Деинсталлировать"
))
                                                    .foregroundColor(.white)
                                                    .fontWeight(.medium)
                                                Text(ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file))
                                                    .font(.caption2)
                                                    .foregroundColor(.white.opacity(0.7))
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.bottom, 20)
                                
                                Spacer()
                            }
                            .background(Color.white.opacity(0.05))
                            .transition(.move(edge: .bottom))
                        }
                    }
                    .transition(.move(edge: .leading))
                }
            }

            .frame(maxWidth: .infinity)
        }
        }
        .onAppear {
             if appScanner.apps.isEmpty {
                 Task { await appScanner.scanApplications() }
             }
        }
        // 确认卸载对话框
        .alert(loc.text(
    simplifiedChinese: "确认卸载?",
    traditionalChinese: "確認卸載?",
    english: "Confirm Uninstall?",
    japanese: "アンインストールの確認",
    korean: "제거를 확인하시겠습니까?",
    russian: "Подтвердить удаление"
), isPresented: $showingDeleteConfirmation) {
            Button(loc.text(
    simplifiedChinese: "完全卸载",
    traditionalChinese: "完全卸載",
    english: "Complete Uninstall",
    japanese: "アンインストール完了",
    korean: "제거 완료",
    russian: "Полное удаление"
), role: .destructive) {
                Task {
                    await performUninstall()
                }
            }
            Button(loc.L("cancel"), role: .cancel) {}
        } message: {
            Text(loc.text(
    simplifiedChinese: "将删除选中的 \(selectedAppIds.count) 个应用及其所有关联文件（配置、缓存、日志等）。此操作将把文件移至废纸篓，可从废纸篓恢复。",
    traditionalChinese: "將刪除選取的\(selectedAppIds.count)個應用程式及其所有關聯檔案（配置、快取、日誌等）。此操作將把文件移至廢紙簍，可從廢紙簍恢復。",
    english: "This will remove \(selectedAppIds.count) selected app(s) and all associated files (preferences, caches, logs, etc.). Files will be moved to Trash and can be recovered.",
    japanese: "これにより、\(selectedAppIds.count)選択したアプリと関連するすべてのファイル（環境設定、キャッシュ、ログなど）が削除されます。ファイルはゴミ箱に移動され、復元できます。",
    korean: "이렇게 하면 \(selectedAppIds.count) 선택한 앱과 모든 관련 파일 (환경 설정, 캐시, 로그 등) 이 제거됩니다. 파일이 휴지통으로 이동되며 복구할 수 있습니다.",
    russian: "Это приведет к удалению \(selectedAppIds.count) выбранных приложений и всех связанных файлов (предпочтений, кэшей, журналов и т. д.). Файлы будут перемещены в корзину и могут быть восстановлены."
))
        }
        // 卸载进度指示器
        .overlay {
            if isUninstalling {
                ZStack {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text(loc.text(
    simplifiedChinese: "正在卸载...",
    traditionalChinese: "正在卸載...",
    english: "Uninstalling...",
    japanese: "アンインストールしています。",
    korean: "제거 중...",
    russian: "Удаление..."
))
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(uninstallProgress)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.cardBackground)
                    )
                }
            }
        }
        // 卸载结果对话框
        .alert(loc.text(
    simplifiedChinese: "卸载完成",
    traditionalChinese: "卸載完成",
    english: "Uninstall Complete",
    japanese: "アンインストールが完了しました",
    korean: "제거 완료",
    russian: "Удаление завершено"
), isPresented: $showingResults) {
            Button(loc.text(
                simplifiedChinese: "确定",
                traditionalChinese: "確定",
                english: "OK",
                japanese: "OK",
                korean: "확인",
                russian: "ОК"
            )) {
                showingResults = false
            }
        } message: {
            Text(loc.text(
                simplifiedChinese: "成功删除 \(totalSuccessCount) 个项目，释放空间 \(ByteCountFormatter.string(fromByteCount: totalRemovedSize, countStyle: .file))\(totalFailedCount > 0 ? "，\(totalFailedCount) 个项目删除失败" : "")",
                traditionalChinese: "已成功刪除 \(totalSuccessCount) 個項目，釋放 \(ByteCountFormatter.string(fromByteCount: totalRemovedSize, countStyle: .file))\(totalFailedCount > 0 ? "；\(totalFailedCount) 個項目刪除失敗" : "")",
                english: "Successfully removed \(totalSuccessCount) items and freed \(ByteCountFormatter.string(fromByteCount: totalRemovedSize, countStyle: .file))\(totalFailedCount > 0 ? "; \(totalFailedCount) items failed" : "")",
                japanese: "\(totalSuccessCount)項目を削除し、\(ByteCountFormatter.string(fromByteCount: totalRemovedSize, countStyle: .file))を解放しました\(totalFailedCount > 0 ? "。\(totalFailedCount)項目を削除できませんでした" : "")",
                korean: "항목 \(totalSuccessCount)개를 삭제하고 \(ByteCountFormatter.string(fromByteCount: totalRemovedSize, countStyle: .file))의 공간을 확보했습니다\(totalFailedCount > 0 ? ". \(totalFailedCount)개 항목을 삭제하지 못했습니다" : "")",
                russian: "Удалено объектов: \(totalSuccessCount). Освобождено \(ByteCountFormatter.string(fromByteCount: totalRemovedSize, countStyle: .file))\(totalFailedCount > 0 ? ". Не удалось удалить: \(totalFailedCount)" : "")"
            ))
        }
    }
    
    // MARK: - 卸载逻辑
    
    /// 执行完整卸载流程
    private func performUninstall() async {
        let appsToUninstall = appScanner.apps.filter { selectedAppIds.contains($0.id) }
        guard !appsToUninstall.isEmpty else { return }
        
        await MainActor.run {
            isUninstalling = true
            uninstallProgress = loc.text(
    simplifiedChinese: "准备中...",
    traditionalChinese: "準備中...",
    english: "Preparing...",
    japanese: "処理中…",
    korean: "준비 중...",
    russian: "Подготовка..."
)
            totalRemovedSize = 0
            totalSuccessCount = 0
            totalFailedCount = 0
            uninstallResults = []
        }
        
        for app in appsToUninstall {
            // 更新进度
            await MainActor.run {
                uninstallProgress = loc.text(
    simplifiedChinese: "正在处理: \(app.name)",
    traditionalChinese: "正在處理:\(app.name)",
    english: "Processing: \(app.name)",
    japanese: "処理：",
    korean: "처리 중: \(app.name)",
    russian: "Обработка: \(app.name)"
)
            }
            
            // 检查应用是否正在运行
            if fileRemover.isAppRunning(app) {
                await MainActor.run {
                    uninstallProgress = loc.text(
    simplifiedChinese: "正在关闭: \(app.name)",
    traditionalChinese: "正在關閉:\(app.name)",
    english: "Closing: \(app.name)",
    japanese: "結びの言葉：",
    korean: "마무리: \(app.name)",
    russian: "Закрытие: \(app.name)"
)
                }
                // 尝试终止应用
                let _ = fileRemover.terminateApp(app)
                // 等待应用关闭
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 等待1秒
                
                // 如果还在运行，强制终止
                if fileRemover.isAppRunning(app) {
                    let _ = fileRemover.forceTerminateApp(app)
                    try? await Task.sleep(nanoseconds: 500_000_000) // 等待0.5秒
                }
            }
            
            // 扫描残留文件
            await MainActor.run {
                uninstallProgress = loc.text(
    simplifiedChinese: "正在扫描残留文件: \(app.name)",
    traditionalChinese: "正在掃描殘留檔案:\(app.name)",
    english: "Scanning residual files: \(app.name)",
    japanese: "残留ファイルのスキャン： \(app.name)",
    korean: "잔여 파일 검색: \(app.name)",
    russian: "Сканирование остаточных файлов: \(app.name)"
)
            }
            await appScanner.scanResidualFiles(for: app)
            
            // 执行删除
            await MainActor.run {
                uninstallProgress = loc.text(
    simplifiedChinese: "正在删除: \(app.name)",
    traditionalChinese: "正在刪除:\(app.name)",
    english: "Deleting: \(app.name)",
    japanese: "削除中",
    korean: "삭제 중: \(app.name)",
    russian: "Удаление: \(app.name)"
)
            }
            
            let result = await fileRemover.removeApp(app, includeApp: true, moveToTrash: true)
            
            await MainActor.run {
                uninstallResults.append(result)
                totalSuccessCount += result.successCount
                totalFailedCount += result.failedCount
                totalRemovedSize += result.totalSizeRemoved
            }
            
            // 从列表中移除已卸载的应用
            if result.failedCount == 0 || (result.successCount > 0 && result.failedPaths.first?.path != app.path.path) {
                await appScanner.removeFromList(app: app)
            }
        }
        
        await MainActor.run {
            isUninstalling = false
            selectedAppIds.removeAll()
            showingResults = true
        }
    }
    
    /// 执行单个应用卸载（从详情页面调用）
    private func performSingleAppUninstall(app: InstalledApp, includeApp: Bool, moveToTrash: Bool) async {
        await MainActor.run {
            isUninstalling = true
            uninstallProgress = loc.text(
    simplifiedChinese: "正在处理: \(app.name)",
    traditionalChinese: "正在處理:\(app.name)",
    english: "Processing: \(app.name)",
    japanese: "処理：",
    korean: "처리 중: \(app.name)",
    russian: "Обработка: \(app.name)"
)
            totalRemovedSize = 0
            totalSuccessCount = 0
            totalFailedCount = 0
        }
        
        // 检查应用是否正在运行
        if includeApp && fileRemover.isAppRunning(app) {
            await MainActor.run {
                uninstallProgress = loc.text(
    simplifiedChinese: "正在关闭: \(app.name)",
    traditionalChinese: "正在關閉:\(app.name)",
    english: "Closing: \(app.name)",
    japanese: "結びの言葉：",
    korean: "마무리: \(app.name)",
    russian: "Закрытие: \(app.name)"
)
            }
            let _ = fileRemover.terminateApp(app)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            if fileRemover.isAppRunning(app) {
                let _ = fileRemover.forceTerminateApp(app)
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
        
        // 执行删除
        await MainActor.run {
            uninstallProgress = loc.text(
    simplifiedChinese: "正在删除: \(app.name)",
    traditionalChinese: "正在刪除:\(app.name)",
    english: "Deleting: \(app.name)",
    japanese: "削除中",
    korean: "삭제 중: \(app.name)",
    russian: "Удаление: \(app.name)"
)
        }
        
        let result = await fileRemover.removeApp(app, includeApp: includeApp, moveToTrash: moveToTrash)
        
        await MainActor.run {
            totalSuccessCount = result.successCount
            totalFailedCount = result.failedCount
            totalRemovedSize = result.totalSizeRemoved
        }
        
        // 从列表中移除已卸载的应用（仅当应用本体也被删除时）
        if includeApp && (result.failedCount == 0 || result.failedPaths.first?.path != app.path.path) {
            await appScanner.removeFromList(app: app)
            await MainActor.run {
                detailedApp = nil // 返回列表视图
            }
        }
        
        await MainActor.run {
            isUninstalling = false
            showingResults = true
        }
    }
    
    // MARK: - Subviews
    
    func SidebarRow(category: AppCategory, count: Int, isSelected: Bool) -> some View {
        HStack {
            // Radio button style selection indicator (from design image 1)
            ZStack {
                Circle().stroke(Color.white.opacity(0.3), lineWidth: 1)
                    .frame(width: 16, height: 16)
                if isSelected {
                    Circle().fill(Color.blue).frame(width: 10, height: 10)
                }
            }
            
            Text(category.title)
                .foregroundColor(.white)
                .font(.system(size: 13))
            
            Spacer()
            
            if count > 0 {
                Text("\(count)") // or size if preferred
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
    
    struct AppChecklistRow: View {
        @ObservedObject var app: InstalledApp
        let isSelected: Bool
        let onToggleSelection: () -> Void
        let onViewDetails: () -> Void
        
        var body: some View {
            HStack(spacing: 12) {
                // Checkbox - Toggle Selection
                Button(action: onToggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .purple : .secondaryText)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                
                // Content - View Details
                HStack(spacing: 12) {
                    Image(nsImage: app.icon)
                        .resizable()
                        .frame(width: 32, height: 32)
                    
                    Text(app.name)
                        .font(.body)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(app.formattedSize)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.3))
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onViewDetails()
                }
            }
            .padding(12)
            .background(Color.clear) // Unified background, no specific row background
            .cornerRadius(8)
        }
    }
}
