import SwiftUI
import AppKit
import AVKit

struct ContentView: View {
    @ObservedObject private var navigation = AppNavigationController.shared
    @ObservedObject private var loc = LocalizationManager.shared
    @StateObject private var uninstallerScanner = AppScanner()
    @State private var displayedModule: AppModule = AppNavigationController.shared.selectedModule
    @State private var isModuleLoading = false
    @State private var moduleSwitchToken = UUID()
    // @State private var showIntro = false // Video disabled
    
    var body: some View {
        GeometryReader { geometry in
            replicaWindow(size: geometry.size)
        }
        .frame(minWidth: 980, minHeight: 600)
        .ignoresSafeArea(.all)
        .onChange(of: navigation.selectedModule) { target in
            beginModuleSwitch(to: target)
        }
        .onAppear(perform: updateApplicationTitle)
        .onChange(of: loc.currentLanguage) { _ in updateApplicationTitle() }
    }

    /// CleanMyMac's window is one continuous gradient surface. The sidebar
    /// and ubiquitous bottom button float above that surface; there is no
    /// second inset content card behind the module.
    private func replicaWindow(size: CGSize) -> some View {
        // The titlebar is transparent, but the original layout still starts
        // below its 23pt traffic-light band. Keep that visual inset while the
        // background itself continues behind the full window.
        let titlebarInset = CleanMyMacWindowMetrics.titlebarContentInset
        let sidebarLeft: CGFloat = 9
        let sidebarTop: CGFloat = 33 + titlebarInset
        let sidebarWidth: CGFloat = 216
        let sidebarHeight = max(520, size.height - sidebarTop - 40)
        let contentLeft = sidebarLeft + sidebarWidth
        let contentWidth = max(620, size.width - 28 - contentLeft)
        let contentHeight = max(1, size.height - titlebarInset)

        return ZStack(alignment: .topLeading) {
            // The original window uses one continuous surface. The window is
            // opaque at the AppKit level, while this single gradient supplies
            // the visible module background all the way to the window edges.
            displayedModule.backgroundGradient
                .frame(width: size.width, height: size.height)
                .ignoresSafeArea()

            moduleContent(for: displayedModule)
                .id(displayedModule)
                .frame(width: contentWidth, height: contentHeight, alignment: .topLeading)
                .offset(x: contentLeft, y: titlebarInset)
                .zIndex(2)

            if isModuleLoading {
                ModuleContentLoadingView(module: navigation.selectedModule)
                    .frame(width: contentWidth, height: contentHeight)
                    .offset(x: contentLeft, y: titlebarInset)
                    .transition(.opacity)
                    .zIndex(20)
            }

            CleanMyMacSidebar(
                selectedModule: $navigation.selectedModule,
                appScanner: uninstallerScanner
            )
            .frame(width: sidebarWidth, height: sidebarHeight)
            .offset(x: sidebarLeft, y: sidebarTop)
            .zIndex(30)

            if showsAssistant(for: displayedModule) {
                Button {
                    navigation.selectedModule = .smartClean
                } label: {
                    HStack(spacing: 6) {
                        Circle().fill(Color.cyan.opacity(0.92)).frame(width: 8, height: 8)
                        Circle().fill(Color.cyan.opacity(0.72)).frame(width: 3, height: 3)
                        Text(LocalizationManager.shared.text(
    simplifiedChinese: "助手",
    traditionalChinese: "助理",
    english: "Assistant",
    japanese: "アシスタント",
    korean: "협조자",
    russian: "Ассистент"
))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.86))
                    .padding(.horizontal, 13)
                    .frame(height: 30)
                    .background(Color.black.opacity(0.25), in: Capsule())
                }
                .buttonStyle(.plain)
                .position(x: size.width - 28 - 46, y: 27 + titlebarInset)
                .zIndex(25)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func showsAssistant(for module: AppModule) -> Bool {
        module == .spaceLens || module == .largeFiles || module == .updater
    }

    @ViewBuilder
    private func moduleContent(for module: AppModule) -> some View {
        switch module {
        case .smartClean:
            SmartCleanerReplicaView(selectedModule: $navigation.selectedModule)
        case .cleaner:
            SystemJunkReplicaView()
        case .mailAttachments:
            MailAttachmentsReplicaView()
        case .trash:
            TrashBinsReplicaView()
        case .malware:
            MalwareRemovalReplicaView()
        case .privacy:
            PrivacyReplicaView()
        case .monitor:
            MonitorView()
        case .deepClean:
            DeepCleanView(selectedModule: $navigation.selectedModule)
        case .maintenance:
            MaintenanceReplicaView()
        case .optimizer:
            OptimizationReplicaView()
        case .uninstaller:
            UninstallerReplicaView(appScanner: uninstallerScanner)
        case .updater:
            AppUpdaterView()
        case .extensions:
            ExtensionsReplicaView()
        case .spaceLens:
            SpaceLensView()
        case .largeFiles:
            LargeFileView(selectedModule: $navigation.selectedModule)
        case .shredder:
            ShredderView()
        case .fileExplorer:
            FileExplorerView()
        }
    }

    private func beginModuleSwitch(to target: AppModule) {
        let token = UUID()
        moduleSwitchToken = token
        isModuleLoading = true

        // Commit the unique sidebar selection first. Construct the requested
        // module on the next run-loop turn so expensive module setup cannot
        // delay the selection highlight.
        DispatchQueue.main.async {
            guard moduleSwitchToken == token else { return }
            displayedModule = target

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                guard moduleSwitchToken == token else { return }
                isModuleLoading = false
            }
        }
    }

    private func updateApplicationTitle() {
        let localizedName = (loc.currentLanguage == .chinese || loc.currentLanguage == .traditionalChinese)
            ? "Mac优化大师"
            : "MacOptimizer"
        NSApp.mainWindow?.title = localizedName
        NSApp.mainMenu?.items.first?.title = localizedName
    }
}

private struct ModuleContentLoadingView: View {
    let module: AppModule
    @ObservedObject private var loc = LocalizationManager.shared

    var body: some View {
        ZStack {
            module.backgroundGradient

            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
                Text(loc.text(
    simplifiedChinese: "正在加载…",
    traditionalChinese: "正在加載…",
    english: "Loading…",
    japanese: "読み込み中…",
    korean: "로드 중…",
    russian: "Загрузка…"
))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.68))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 开场视频视图
struct IntroVideoView: View {
    let onComplete: () -> Void
    @State private var player: AVPlayer?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let player = player {
                // 使用自定义的 VideoPlayerView 替代 SwiftUI 的 VideoPlayer
                VideoPlayerView(player: player)
                    .ignoresSafeArea()
            }
            
            // 跳过按钮
            VStack {
                HStack {
                    Spacer()
                    Button(action: onComplete) {
                        Text("跳过")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                    .padding(20)
                }
                Spacer()
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
    
    private func setupPlayer() {
        guard let url = Bundle.main.url(forResource: "Intro", withExtension: "mp4") else {
            // 如果找不到视频，直接完成
            onComplete()
            return
        }
        
        player = AVPlayer(url: url)
        player?.play()
        
        // 视频播放完毕时回调
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { _ in
            onComplete()
        }
    }
}

// MARK: - 自定义视频播放器视图（使用 AVPlayerLayer 避免兼容性问题）
struct VideoPlayerView: NSViewRepresentable {
    let player: AVPlayer
    
    func makeNSView(context: Context) -> NSView {
        let view = VideoLayerView()
        view.player = player
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? VideoLayerView {
            view.player = player
        }
    }
}

// 使用 CALayer 的视图来承载 AVPlayerLayer
class VideoLayerView: NSView {
    var player: AVPlayer? {
        didSet {
            playerLayer.player = player
        }
    }
    
    private let playerLayer = AVPlayerLayer()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }
    
    private func setupLayer() {
        wantsLayer = true
        layer = CALayer()
        playerLayer.videoGravity = .resizeAspect
        layer?.addSublayer(playerLayer)
    }
    
    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
}

// 拆分出来的应用列表视图
struct AppListView: View {
    let apps: [InstalledApp]
    let selectedApp: InstalledApp?
    let isScanning: Bool
    @Binding var searchText: String
    let onSelect: (InstalledApp) -> Void
    let onRefresh: () -> Void
    @ObservedObject var loc: LocalizationManager
    
    var body: some View {
        VStack(spacing: 0) {
            // 头部工具栏
            HStack {
                Text(loc.text(
    simplifiedChinese: "应用列表",
    traditionalChinese: "應用程式列表",
    english: "App List",
    japanese: "アプリリスト",
    korean: "앱 목록",
    russian: "Список приложений"
))
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.3))
                TextField(loc.L("search_apps"), text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
            }
            .padding(10)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            
            if isScanning {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Text(loc.text(
    simplifiedChinese: "扫描应用中...",
    traditionalChinese: "掃描應用程式中...",
    english: "Scanning apps...",
    japanese: "アプリをスキャンしています...",
    korean: "앱 검사 중...",
    russian: "Сканирование приложений..."
))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                Spacer()
            } else {
                List(apps) { app in
                    AppListRow(app: app, isSelected: selectedApp?.id == app.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(app)
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        .listRowBackground(Color.clear)
                        .compatibleListRowSeparatorHidden()
                }
                .listStyle(.plain)
                .compatibleScrollContentBackgroundHidden()
            }
            
            // 底部统计
            HStack {
                Text(loc.text(
    simplifiedChinese: "\(apps.count) 个应用",
    traditionalChinese: "\(apps.count)個應用",
    english: "\(apps.count) apps",
    japanese: "アプリ",
    korean: "\(apps.count) 앱",
    russian: "\(apps.count) apps"
))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(12)
            .background(Color.black.opacity(0.2))
        }
        .background(Color.black.opacity(0.2))
    }
}

// 拆分出来的空状态视图
struct EmptySelectionView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "app.square")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.1))
            Text(loc.text(
    simplifiedChinese: "选择一个应用以查看详情",
    traditionalChinese: "選擇一個應用程式以查看詳情",
    english: "Select an app to view details",
    japanese: "アプリを選択して詳細を表示",
    korean: "세부 정보를 보려면 앱을 선택하세요",
    russian: "Выберите приложение, чтобы посмотреть подробности"
))
                .font(.title3)
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

// 列表行组件 (适配新风格)
struct AppListRow: View {
    @ObservedObject var app: InstalledApp
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primaryText)
                
                Text(app.formattedSize)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondaryText)
            }
            
            Spacer()
            
            if !app.residualFiles.isEmpty {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue : Color.clear)
        )
    }
}
