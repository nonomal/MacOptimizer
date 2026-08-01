import SwiftUI
import AppKit

// MARK: - Console Dashboard
struct MonitorView: View {
    @State private var viewState: DashboardState = .dashboard
    @State private var processSortMode: ConsoleProcessSortMode = .memory
    @StateObject private var systemMonitor = SystemMonitorService()
    @ObservedObject var loc = LocalizationManager.shared
    
    enum DashboardState {
        case dashboard
        case appManager
        case portManager
        case processManager

        case networkOptimize  // 新增：网络优化
        case protection // 新增：安全防护
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar
            ConsoleSidebar(selection: $viewState)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Right Content
            ZStack {
                switch viewState {
                case .dashboard:
                    ConsoleOverviewView(
                        viewState: $viewState,
                        processSortMode: $processSortMode,
                        systemMonitor: systemMonitor
                    )
                case .protection:
                    ConsoleProtectionDetailView(viewState: $viewState)
                case .appManager:
                    ConsoleAppManagerDetailView(viewState: $viewState)
                case .portManager:
                    ConsolePortManagerDetailView(viewState: $viewState)
                case .processManager:
                    ConsoleProcessManagerDetailView(
                        viewState: $viewState,
                        sortMode: $processSortMode
                    )
                case .networkOptimize:
                    ConsoleNetworkDetailView(viewState: $viewState, systemService: systemMonitor)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear) // Gradient is in main window
        }
        .onAppear {
            systemMonitor.startMonitoring()
        }
        .onDisappear {
            systemMonitor.stopMonitoring()
        }
    }
}

// MARK: - 1. Dashboard Home View
struct ConsoleDashboardView: View {
    @Binding var viewState: MonitorView.DashboardState
    @ObservedObject var loc = LocalizationManager.shared
    @ObservedObject var scanManager = ScanServiceManager.shared
    @StateObject private var systemService = SystemMonitorService()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(loc.text(
    simplifiedChinese: "控制台",
    traditionalChinese: "主控台",
    english: "Console",
    japanese: "ゲーム機:",
    korean: "콘솔",
    russian: "Консоль"
))
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)
                    Text(loc.text("系统概览与管理", "System Overview & Management"))
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
            }
            .padding(32)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Top Stats: System Stats, Network (Reorganized)
                    HStack(spacing: 16) {
                        // CPU & Memory Circle
                        MonitorCard(title: loc.text("系统负载", "System Load"), icon: "cpu", color: .blue) {
                            HStack(spacing: 20) {
                                UsageRing(percentage: systemService.cpuUsage, label: "CPU", subLabel: String(format: "%.0f%%", systemService.cpuUsage * 100))
                                UsageRing(percentage: systemService.memoryUsage, label: "RAM", subLabel: String(format: "%.0f%%", systemService.memoryUsage * 100))
                            }
                        }
                        
                        // Network Speed Card - 可点击进入网络优化
                        Button(action: {
                            viewState = .networkOptimize
                        }) {
                            MonitorCard(title: loc.text("网络速度", "Network"), icon: "wifi", color: .green) {
                                VStack(spacing: 8) {
                                    // 波形图
                                    NetworkWaveform(downloadHistory: systemService.downloadSpeedHistory, uploadHistory: systemService.uploadSpeedHistory)
                                        .frame(height: 40)
                                    
                                    // 速度显示
                                    HStack(spacing: 12) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.down")
                                                .font(.system(size: 10))
                                                .foregroundColor(.green)
                                            Text(systemService.formatSpeed(systemService.downloadSpeed))
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(.white)
                                        }
                                        
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.up")
                                                .font(.system(size: 10))
                                                .foregroundColor(.cyan)
                                            Text(systemService.formatSpeed(systemService.uploadSpeed))
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(.white)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption2)
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(height: 160)
                    
                    Text(loc.text("管理工具", "Management Tools"))
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                    
                    // Function Cards Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        // App Management
                        DashboardButton(
                            title: loc.text(
    simplifiedChinese: "应用管理",
    traditionalChinese: "應用管理",
    english: "App Manager",
    japanese: "アプリマネージャー",
    korean: "앱 관리자",
    russian: "Диспетчер приложений"
),
                            description: loc.text("管理应用、强制退出、重置", "Manage apps, force quit, reset"),
                            icon: "square.grid.2x2.fill",
                            color: .cyan
                        ) {
                            viewState = .appManager
                        }
                        
                        // Port Management
                        DashboardButton(
                            title: loc.text(
    simplifiedChinese: "端口管理",
    traditionalChinese: "連接埠管理",
    english: "Port Manager",
    japanese: "港湾管理者",
    korean: "포트 관리자",
    russian: "Менеджер порта"
),
                            description: loc.text("查看和关闭网络端口", "View and close network ports"),
                            icon: "network",
                            color: .purple
                        ) {
                            viewState = .portManager
                        }
                        
                        // Process Management
                        DashboardButton(
                            title: loc.text(
    simplifiedChinese: "进程管理",
    traditionalChinese: "行程管理",
    english: "Process Manager",
    japanese: "プロセスマネージャー",
    korean: "진행관리자",
    russian: "Менеджер по технологиям"
),
                            description: loc.text("监控和结束后台进程", "Monitor and kill background processes"),
                            icon: "waveform.path.ecg",
                            color: .green
                        ) {
                            viewState = .processManager
                        }
                        
                        // Protection Center
                        DashboardButton(
                            title: loc.text(
    simplifiedChinese: "安全中心",
    traditionalChinese: "安全中心",
    english: "Safety Center",
    japanese: "セーフティセンター",
    korean: "CCTV 안전센터",
    russian: "Центр безопасности"
),
                            description: ProtectionService.shared.isMonitoring ? (loc.text("实时保护已开启", "Real-time protection on")) : (loc.text("实时保护未开启", "Protection disabled")),
                            icon: "shield.checkerboard",
                            color: ProtectionService.shared.isMonitoring ? .green : .orange
                        ) {
                            viewState = .protection
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            systemService.startMonitoring()
            // 确保 junk size 是最新的
            if !scanManager.isAnyScanning && scanManager.totalCleanableSize == 0 {
                Task {
                    // 可选：静默启动垃圾扫描
                     scanManager.startJunkScanIfNeeded()
                     scanManager.startSmartCleanScanIfNeeded()
                }
            }
        }
        .onDisappear {
            systemService.stopMonitoring()
        }
    }
}

// MARK: - 2. App Management View
struct ConsoleAppManagerView: View {
    @Binding var viewState: MonitorView.DashboardState
    @StateObject private var appScanner = AppScanner()
    @StateObject private var processService = ProcessService()
    @ObservedObject var loc = LocalizationManager.shared
    @State private var searchText = ""
    @State private var isScanning = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Back Button
            ConsoleHeader(
                title: loc.text(
    simplifiedChinese: "应用管理",
    traditionalChinese: "應用管理",
    english: "App Manager",
    japanese: "アプリマネージャー",
    korean: "앱 관리자",
    russian: "Диспетчер приложений"
),
                backAction: { viewState = .dashboard }
            )
            
            // Search & Filter
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondaryText)
                TextField(loc.text("搜索应用...", "Search apps..."), text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 32)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            if isScanning {
                Spacer()
                ProgressView()
                Text(loc.text("正在加载应用...", "Loading apps..."))
                    .foregroundColor(.secondaryText)
                    .padding(.top)
                Spacer()
            } else {
                List {
                    // Header Row
                    HStack {
                        Text(loc.text("应用名称", "App Name"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(loc.text("状态", "Status"))
                            .frame(width: 80, alignment: .leading)
                        Text(loc.text("操作", "Actions"))
                            .frame(width: 200, alignment: .trailing)
                    }
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .listRowBackground(Color.clear)
                    .compatibleListRowSeparatorHidden()
                    
                    ForEach(filteredApps) { app in
                        AppManagerRow(app: app, processService: processService, appScanner: appScanner, loc: loc)
                            .listRowBackground(Color.white.opacity(0.02))
                            .compatibleListRowSeparatorHidden()
                            .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                    }
                }
                .listStyle(.plain)
                .compatibleScrollContentBackgroundHidden()
                .padding(.horizontal, 16)
            }
        }
        .onAppear {
            loadData()
        }
    }
    
    // Combine AppScanner data with Running status
    struct AppViewModel: Identifiable {
        let id: UUID
        let installedApp: InstalledApp
        var isRunning: Bool
        var processItem: ProcessItem?
    }
    
    @State private var appViewModels: [AppViewModel] = []
    
    var filteredApps: [AppViewModel] {
        if searchText.isEmpty {
            return appViewModels
        }
        return appViewModels.filter { $0.installedApp.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    func loadData() {
        Task {
            isScanning = true
            if appScanner.apps.isEmpty {
                await appScanner.scanApplications()
            }
            
            await processService.scanProcesses(showApps: true)
            
            var viewModels: [AppViewModel] = []
            // Map validation path (bundle path) to running process items
            let runningMap = Dictionary(grouping: processService.processes, by: { $0.validationPath ?? "" })
            
            for app in appScanner.apps {
                var isRunning = false
                var pItem: ProcessItem? = nil
                
                if let processes = runningMap[app.path.path], let first = processes.first {
                    isRunning = true
                    pItem = first
                } else if let p = processService.processes.first(where: { $0.name == app.name }) {
                     isRunning = true
                     pItem = p
                }
                
                viewModels.append(AppViewModel(id: app.id, installedApp: app, isRunning: isRunning, processItem: pItem))
            }
            
            viewModels.sort {
                if $0.isRunning != $1.isRunning {
                    return $0.isRunning
                }
                return $0.installedApp.name < $1.installedApp.name
            }
            
            await MainActor.run {
                self.appViewModels = viewModels
                self.isScanning = false
            }
        }
    }
}

struct AppManagerRow: View {
    let app: ConsoleAppManagerView.AppViewModel
    @ObservedObject var processService: ProcessService
    @ObservedObject var appScanner: AppScanner // 新增
    @ObservedObject var installedApp: InstalledApp // 必须观测此对象以触发刷新
    var loc: LocalizationManager
    
    @State private var isRunningLocal: Bool
    @State private var isSpinning = false
    @State private var showSuccess = false
    @State private var showCleanConfirmation = false
    
    init(app: ConsoleAppManagerView.AppViewModel, processService: ProcessService, appScanner: AppScanner, loc: LocalizationManager) {
        self.app = app
        self.processService = processService
        self.appScanner = appScanner
        self.installedApp = app.installedApp // 绑定观测对象
        self.loc = loc
        self._isRunningLocal = State(initialValue: app.isRunning)
    }
    
    var body: some View {
        HStack {
            appIconView
            appInfoView
            Spacer()
            statusView
            actionsView
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var appIconView: some View {
        Image(nsImage: installedApp.icon)
            .resizable()
            .frame(width: 32, height: 32)
    }
    
    private var appInfoView: some View {
        VStack(alignment: .leading) {
            Text(installedApp.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            Text((loc.text("应用大小: ", "App Size: ")) + installedApp.formattedSize)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    private var statusView: some View {
        HStack {
            if isRunningLocal {
                Circle().fill(Color.green).frame(width: 8, height: 8)
                Text(loc.text("运行中", "Running"))
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Text(loc.text(
    simplifiedChinese: "未运行",
    traditionalChinese: "未運行",
    english: "Stopped",
    japanese: "中止中",
    korean: "중지됨",
    russian: "Остановлено"
))
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
        }
        .frame(width: 80, alignment: .leading)
    }
    
    private var actionsView: some View {
        HStack(spacing: 12) {
            cleanButton
            forceQuitButton
        }
        .frame(width: 200, alignment: .trailing)
    }
    
    private var cleanButton: some View {
        Button(action: {
            showCleanConfirmation = true
        }) {
            HStack(spacing: 4) {
                if isSpinning {
                    ProgressView().scaleEffect(0.5).frame(width: 10, height: 10)
                    Text(loc.text("清理中...", "Cleaning..."))
                } else if showSuccess {
                    Image(systemName: "checkmark")
                    Text(loc.text(
    simplifiedChinese: "完成",
    traditionalChinese: "完成",
    english: "Done",
    japanese: "完了",
    korean: "완료",
    russian: "Готово"
))
                } else {
                    Image(systemName: "eraser")
                    Text(loc.text(
    simplifiedChinese: "清理",
    traditionalChinese: "清理",
    english: "Clean",
    japanese: "洗う",
    korean: "지우기",
    russian: "Очистить"
))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(showSuccess ? Color.green.opacity(0.2) : Color.white.opacity(0.1))
            .foregroundColor(showSuccess ? .green : .white)
            .cornerRadius(6)
            .frame(width: 100)
        }
        .disabled(isSpinning)
        .buttonStyle(.plain)
        .help(loc.text("清理应用残留数据（不删除应用本身）", "Clean app data (keeps app installed)"))
        .alert(isPresented: $showCleanConfirmation) {
            Alert(
                title: Text(loc.text("确认清理", "Confirm Clean")),
                message: Text(loc.text("该操作将清理应用的所有缓存、日志和配置数据。\n应用本身（\(app.installedApp.formattedSize)）将被保留。", "This will clean all cache, logs, and config data.\nThe app itself (\(app.installedApp.formattedSize)) will be kept.")),
                primaryButton: .destructive(Text(loc.text("确认清理", "Clean Data"))) {
                    Task {
                        isSpinning = true
                        showSuccess = false
                        
                        // Minimum 1s delay for visual feedback
                        let startTime = Date()
                        
                        if isRunningLocal, let item = app.processItem {
                             await processService.cleanAppData(for: item)
                             withAnimation { isRunningLocal = false }
                        } else {
                            // If stopped, manually scan and remove residuals
                            let scanner = ResidualFileScanner()
                            let files = await scanner.scanResidualFiles(for: app.installedApp)
                            
                             if !files.isEmpty {
                                 for file in files { file.isSelected = true }
                                 let appWithFiles = app.installedApp
                                 appWithFiles.residualFiles = files
                                 let remover = FileRemover()
                                 _ = await remover.removeResidualFiles(of: appWithFiles, moveToTrash: true)
                             }
                        }
                        
                        // Ensure spinner shows for at least a moment
                        let elapsed = Date().timeIntervalSince(startTime)
                        if elapsed < 0.8 {
                            try? await Task.sleep(nanoseconds: UInt64((0.8 - elapsed) * 1_000_000_000))
                        }
                        
                        // 刷新应用大小
                        await appScanner.refreshAppSize(for: app.installedApp)
                        
                        await MainActor.run {
                            isSpinning = false
                            showSuccess = true
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showSuccess = false
                            }
                        }
                    }
                },
                secondaryButton: .cancel(Text(loc.text("取消", "Cancel")))
            )
        }
    }
    
    private var forceQuitButton: some View {
        Group {
            if isRunningLocal {
                Button(action: {
                    if let item = app.processItem {
                        processService.forceTerminateProcess(item)
                        withAnimation { isRunningLocal = false }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.octagon.fill")
                        Text(loc.text("强制退出", "Force Quit"))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.2))
                    .foregroundColor(.red)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            } else {
                // Placeholder
                Color.clear.frame(width: 90, height: 26)
            }
        }
    }
}

// MARK: - 3. Port Management View
struct ConsolePortManagerView: View {
    @Binding var viewState: MonitorView.DashboardState
    @StateObject private var portService = PortScannerService()
    @ObservedObject var loc = LocalizationManager.shared
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            ConsoleHeader(
                title: loc.text(
    simplifiedChinese: "端口管理",
    traditionalChinese: "連接埠管理",
    english: "Port Manager",
    japanese: "港湾管理者",
    korean: "포트 관리자",
    russian: "Менеджер порта"
),
                backAction: { viewState = .dashboard },
                refreshAction: { Task { await portService.scanPorts() } }
            )
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondaryText)
                TextField(loc.text("搜索端口、PID...", "Search ports, PID..."), text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
            }
            .padding(10)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 32)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            if portService.isScanning {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        HStack {
                            Text(loc.text("程序", "Process"))
                                .frame(width: 150, alignment: .leading)
                            Text("PID")
                                .frame(width: 60, alignment: .leading)
                            Text(loc.text("端口", "Port"))
                                .frame(width: 80, alignment: .leading)
                            Text(loc.text("协议", "Proto"))
                                .frame(width: 60, alignment: .leading)
                            Spacer()
                            Text(loc.text("操作", "Action"))
                                .frame(width: 60)
                        }
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        
                        ForEach(portService.ports.filter {
                            searchText.isEmpty || $0.displayName.localizedCaseInsensitiveContains(searchText) || String($0.pid).contains(searchText) || $0.portString.contains(searchText)
                        }) { port in
                            HStack {
                                HStack(spacing: 8) {
                                    if let icon = port.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 20, height: 20)
                                    } else {
                                        Image(systemName: "network")
                                            .foregroundColor(.cyan)
                                    }
                                    Text(port.displayName).lineLimit(1)
                                }
                                .frame(width: 150, alignment: .leading)
                                
                                Text(String(port.pid))
                                    .frame(width: 60, alignment: .leading)
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Text(port.portString)
                                    .font(.system(size: 14, weight: .medium))
                                    .frame(width: 80, alignment: .leading)
                                    .foregroundColor(.cyan)
                                
                                Text(port.protocol)
                                    .frame(width: 60, alignment: .leading)
                                    .foregroundColor(.white.opacity(0.5))
                                
                                Spacer()
                                
                                Button(action: { portService.terminateProcess(port) }) {
                                    Text(loc.text("结束", "Kill"))
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.red.opacity(0.6))
                                        .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                                .frame(width: 60)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.02))
                            Divider().background(Color.white.opacity(0.05))
                        }
                    }
                }
            }
        }
        .onAppear {
            Task { await portService.scanPorts() }
        }
    }
}

// MARK: - 4. Process Management View
struct ConsoleProcessManagerView: View {
    @Binding var viewState: MonitorView.DashboardState
    @StateObject private var processService = ProcessService()
    @ObservedObject var loc = LocalizationManager.shared
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            ConsoleHeader(
                title: loc.text("后台进程管理", "Background Processes"),
                backAction: { viewState = .dashboard },
                refreshAction: { Task { await processService.scanProcesses(showApps: false) } }
            )
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondaryText)
                TextField(loc.text("搜索进程...", "Search processes..."), text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
            }
            .padding(10)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 32)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            if processService.isScanning {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(processService.processes.filter { 
                            searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) 
                        }) { item in
                            HStack {
                                Image(systemName: "gearshape.fill")
                                    .foregroundColor(.white.opacity(0.3))
                                    .font(.system(size: 14))
                                
                                VStack(alignment: .leading) {
                                    Text(item.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                    Text("PID: \(item.pid)")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                
                                Spacer()
                                
                                Text(item.formattedMemory)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.trailing, 10)
                                
                                Button(action: { processService.forceTerminateProcess(item) }) {
                                    Image(systemName: "xmark.octagon.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 16))
                                }
                                .buttonStyle(.plain)
                                .help(loc.text("强制结束", "Force Quit"))
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.02))
                            .cornerRadius(6)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.vertical, 10)
                }
            }
        }
        .onAppear {
            Task { await processService.scanProcesses(showApps: false) }
        }
    }
}

// MARK: - Components

struct ConsoleHeader: View {
    let title: String
    let backAction: () -> Void
    var refreshAction: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            Button(action: backAction) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                    Text(title)
                        .font(.title2)
                        .bold()
                }
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            if let refresh = refreshAction {
                Button(action: refresh) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.white.opacity(0.7))
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(32)
    }
}

struct DashboardButton: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)
                    .padding(12)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color.white.opacity(isHovering ? 0.1 : 0.05))
            .cornerRadius(16)
            .scaleEffect(isHovering ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.3), value: isHovering)
    }
}

struct MonitorCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

struct UsageRing: View {
    let percentage: Double
    let label: String
    let subLabel: String
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 8)
            
            Circle()
                .trim(from: 0, to: percentage)
                .stroke(
                    AngularGradient(
                        colors: [.blue, .cyan],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: percentage)
            
            VStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Text(subLabel)
                    .font(.title3)
                    .bold()
                    .foregroundColor(.white)
            }
        }
        .frame(width: 80, height: 80)
    }
}

// MARK: - 5. Console Junk Clean View (控制台垃圾清理)
struct ConsoleJunkCleanView: View {
    @Binding var viewState: MonitorView.DashboardState
    @ObservedObject private var service = ScanServiceManager.shared.smartCleanerService
    @ObservedObject private var loc = LocalizationManager.shared
    
    @State private var showDeleteConfirmation = false
    @State private var deleteResult: (success: Int, failed: Int, size: Int64)?
    @State private var showCleaningFinished = false
    @State private var failedFiles: [CleanerFileItem] = []
    @State private var showRetryWithAdmin = false
    @State private var showDetailSheet = false
    @State private var initialDetailCategory: CleanerCategory? = nil
    
    // 检查是否有扫描结果
    private var hasScanResults: Bool {
        return service.systemJunkTotalSize > 0 ||
               !service.duplicateGroups.isEmpty ||
               !service.similarPhotoGroups.isEmpty ||
               !service.largeFiles.isEmpty ||
               !service.userCacheFiles.isEmpty ||
               !service.systemCacheFiles.isEmpty
    }
    
    // 计算扫描到的总大小
    private var totalScannedSize: Int64 {
        let topLevelCategories: [CleanerCategory] = [
            .systemJunk, .duplicates, .similarPhotos, .largeFiles
        ]
        return topLevelCategories.reduce(0) { $0 + service.sizeFor(category: $1) }
    }
    
    var body: some View {
        ZStack {
            if service.isScanning {
                scanningView
            } else if service.isCleaning || showRetryWithAdmin {
                cleaningView
            } else if showCleaningFinished {
                cleaningFinishedView
            } else if hasScanResults {
                resultsView
            } else {
                noDataView
            }
        }
        .sheet(isPresented: $showDetailSheet) {
            AllCategoriesDetailSheet(
                service: service,
                loc: loc,
                isPresented: $showDetailSheet,
                initialCategory: initialDetailCategory
            )
        }
        .confirmationDialog(
            loc.text("确认删除", "Confirm Delete"),
            isPresented: $showDeleteConfirmation
        ) {
            Button(loc.text(
    simplifiedChinese: "开始清理",
    traditionalChinese: "開始清理",
    english: "Start Cleaning",
    japanese: "清掃を開始",
    korean: "청소 시작",
    russian: "Начало уборки"
), role: .destructive) {
                Task {
                    let result = await service.cleanAll()
                    deleteResult = (result.success, result.failed, result.size)
                    failedFiles = result.failedFiles
                    
                    if result.failed > 0 && !failedFiles.isEmpty {
                        showRetryWithAdmin = true
                    } else {
                        showCleaningFinished = true
                    }
                }
            }
            Button(loc.L("cancel"), role: .cancel) {}
        } message: {
            Text(loc.text("将清理所有选中的垃圾文件，释放空间。", "Clean all selected files to free up space."))
        }
        .alert(loc.text("部分文件需要管理员权限", "Some Files Require Admin Privileges"), isPresented: $showRetryWithAdmin) {
            Button(loc.text("使用管理员权限删除", "Delete with Admin"), role: .destructive) {
                Task {
                    let adminResult = await service.cleanWithPrivileges(files: failedFiles)
                    if let currentResult = deleteResult {
                        deleteResult = (
                            currentResult.success + adminResult.success,
                            adminResult.failed,
                            currentResult.size + adminResult.size
                        )
                    }
                    failedFiles = []
                    showCleaningFinished = true
                }
            }
            Button(loc.L("cancel"), role: .cancel) {
                showCleaningFinished = true
            }
        } message: {
            let totalFailedSize = failedFiles.reduce(0) { $0 + $1.size }
            Text(loc.text("有 \(failedFiles.count) 个文件（共 \(ByteCountFormatter.string(fromByteCount: totalFailedSize, countStyle: .file))）因权限不足无法删除。\n\n是否使用管理员权限强制删除？", "\(failedFiles.count) files (\(ByteCountFormatter.string(fromByteCount: totalFailedSize, countStyle: .file))) could not be deleted."))
        }
    }
    
    // MARK: - 无数据视图 (触发扫描)
    private var noDataView: some View {
        VStack(spacing: 0) {
            ConsoleHeader(
                title: loc.text("垃圾清理", "Junk Cleanup"),
                backAction: { viewState = .dashboard }
            )
            
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.pink.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "trash.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.pink)
            }
            .padding(.bottom, 30)
            
            Text(loc.text("暂无垃圾数据", "No junk data yet"))
                .font(.title2)
                .foregroundColor(.white)
                .padding(.bottom, 8)
            
            Text(loc.text("请先进行系统扫描以检测可清理的垃圾文件", "Run a system scan to detect cleanable junk files"))
                .font(.body)
                .foregroundColor(.secondaryText)
                .padding(.bottom, 40)
            
            Button(action: {
                Task {
                    await service.scanAll()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text(loc.text("开始扫描", "Start Scan"))
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                .cornerRadius(25)
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
    }
    
    // MARK: - 扫描中视图
    private var scanningView: some View {
        VStack(spacing: 0) {
            ConsoleHeader(
                title: loc.text("垃圾清理", "Junk Cleanup"),
                backAction: { viewState = .dashboard }
            )
            
            Spacer()
            
            Text(loc.text("正在扫描...", "Scanning..."))
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .padding(.bottom, 40)
            
            VStack(alignment: .leading, spacing: 20) {
                let categories: [CleanerCategory] = [.systemJunk, .duplicates, .similarPhotos, .largeFiles]
                
                ForEach(categories, id: \.self) { category in
                    CleaningTaskRow(
                        icon: category.icon,
                        color: category.color,
                        title: loc.currentLanguage == .chinese ? category.rawValue : category.englishName,
                        status: getScanningStatus(for: category),
                        fileSize: ByteCountFormatter.string(fromByteCount: service.sizeFor(category: category), countStyle: .file)
                    )
                }
            }
            .frame(maxWidth: 400)
            
            Spacer()
            
            CircularActionButton(
                title: loc.text(
    simplifiedChinese: "停止",
    traditionalChinese: "停止",
    english: "Stop",
    japanese: "停止",
    korean: "정지",
    russian: "Остановить"
),
                gradient: CircularActionButton.stopGradient,
                progress: service.scanProgress,
                showProgress: true,
                scanSize: ByteCountFormatter.string(fromByteCount: totalScannedSize, countStyle: .file),
                action: {
                    service.stopScanning()
                }
            )
            .padding(.bottom, 40)
            
            Text(service.currentScanPath)
                .font(.caption)
                .foregroundColor(.secondaryText.opacity(0.6))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
        }
    }
    
    // MARK: - 结果视图
    private var resultsView: some View {
        VStack(spacing: 0) {
            ConsoleHeader(
                title: loc.text("垃圾清理", "Junk Cleanup"),
                backAction: { viewState = .dashboard },
                refreshAction: {
                    Task {
                        service.resetAll()
                        await service.scanAll()
                    }
                }
            )
            
            Spacer()
            
            Text(loc.text("扫描完成", "Scan Complete"))
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .padding(.bottom, 8)
            
            Text(loc.text("发现以下可清理的垃圾文件", "Found the following junk files"))
                .font(.body)
                .foregroundColor(.secondaryText)
                .padding(.bottom, 30)
            
            // 结果概览
            HStack(spacing: 20) {
                ResultCategoryCard(
                    icon: "internaldrive.fill",
                    iconColor: .blue,
                    title: loc.text("清理", "Cleanup"),
                    subtitle: loc.text("移除不需要的垃圾", "Remove junk"),
                    value: ByteCountFormatter.string(fromByteCount: totalScannedSize, countStyle: .file),
                    hasDetails: true,
                    onDetailTap: {
                        initialDetailCategory = nil
                        showDetailSheet = true
                    }
                )
            }
            
            Spacer()
            
            CircularActionButton(
                title: loc.text("清理", "Cleanup"),
                gradient: CircularActionButton.greenGradient,
                action: {
                    showDeleteConfirmation = true
                }
            )
            .padding(.bottom, 60)
        }
    }
    
    // MARK: - 清理中视图
    private var cleaningView: some View {
        VStack(spacing: 0) {
            ConsoleHeader(
                title: loc.text("垃圾清理", "Junk Cleanup"),
                backAction: { viewState = .dashboard }
            )
            
            Spacer()
            
            Text(loc.text(
    simplifiedChinese: "正在清理系统...",
    traditionalChinese: "正在清理系統...",
    english: "Cleaning System...",
    japanese: "システムのクリーニング",
    korean: "세척 시스템(cleaning system)",
    russian: "Процедура уборки"
))
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .padding(.bottom, 40)
            
            VStack(alignment: .leading, spacing: 20) {
                let categoriesToClean: [CleanerCategory] = {
                    let all: [CleanerCategory] = [.systemJunk, .duplicates, .similarPhotos, .largeFiles]
                    return all.filter { service.sizeFor(category: $0) > 0 }
                }()
                
                ForEach(categoriesToClean, id: \.self) { category in
                    CleaningTaskRow(
                        icon: category.icon,
                        color: category.color,
                        title: loc.currentLanguage == .chinese ? category.rawValue : category.englishName,
                        status: getCleaningStatus(for: category),
                        fileSize: ByteCountFormatter.string(fromByteCount: service.sizeFor(category: category), countStyle: .file)
                    )
                }
            }
            .frame(maxWidth: 400)
            
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .green))
                
                Text(loc.text("清理中", "Cleaning"))
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - 清理完成视图
    private var cleaningFinishedView: some View {
        VStack(spacing: 0) {
            ConsoleHeader(
                title: loc.text("垃圾清理", "Junk Cleanup"),
                backAction: {
                    showCleaningFinished = false
                    viewState = .dashboard
                }
            )
            
            Spacer()
            
            // 电脑图标
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.pink.opacity(0.8))
                    .frame(width: 200, height: 140)
                    .shadow(color: .pink.opacity(0.3), radius: 20, x: 0, y: 10)
                
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.bottom, 40)
            
            // 结果标题
            Text(loc.text("做得不错！", "Well Done!"))
                .font(.title)
                .bold()
                .foregroundColor(.white)
                .padding(.bottom, 8)
            
            Text(loc.text(
    simplifiedChinese: "您的 Mac 状态很好。",
    traditionalChinese: "您的Mac 狀態很好。",
    english: "Your Mac is in good shape.",
    japanese: "お使いのMacは良好な状態です。",
    korean: "Mac의 상태가 양호합니다.",
    russian: "Ваш Mac в хорошей форме."
))
                .font(.body)
                .foregroundColor(.secondaryText)
                .padding(.bottom, 30)
            
            // 结果统计
            HStack(spacing: 12) {
                Image(systemName: "externaldrive.fill")
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.blue)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text(ByteCountFormatter.string(fromByteCount: (deleteResult?.size ?? 0), countStyle: .file))
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    Text(loc.text("不需要的垃圾已移除", "Junk removed"))
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }
            
            Spacer()
            
            Button(action: {
                showCleaningFinished = false
                // 清理完成后重新扫描以刷新统计
                Task {
                    service.resetAll()
                    await service.scanAll()
                }
                viewState = .dashboard
            }) {
                Text(loc.text("返回控制台", "Back to Console"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(25)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 60)
        }
    }
    
    // MARK: - Helper Functions
    private func getScanningStatus(for category: CleanerCategory) -> CleaningTaskRow.Status {
        let isCurrent = service.currentCategory == category
        let isCompleted = !isCurrent && (
            (category == .systemJunk && [.duplicates, .similarPhotos, .largeFiles].contains(service.currentCategory)) ||
            (category == .duplicates && [.similarPhotos, .largeFiles].contains(service.currentCategory)) ||
            (category == .similarPhotos && [.largeFiles].contains(service.currentCategory))
        )
        
        if isCurrent { return .processing }
        if isCompleted { return .completed }
        return .waiting
    }
    
    private func getCleaningStatus(for category: CleanerCategory) -> CleaningTaskRow.Status {
        if service.cleanedCategories.contains(category) {
            return .completed
        } else if service.cleaningCurrentCategory == category {
            return .processing
        } else {
            return .waiting
        }
    }
}

// MARK: - Network Waveform Component
struct NetworkWaveform: View {
    let downloadHistory: [Double]
    let uploadHistory: [Double]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Download Wave (green)
                Path { path in
                    drawWave(path: &path, data: downloadHistory, size: geometry.size)
                }
                .stroke(
                    LinearGradient(colors: [.green.opacity(0.8), .green.opacity(0.3)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1.5
                )
                
                // Download Fill
                Path { path in
                    drawWaveFill(path: &path, data: downloadHistory, size: geometry.size)
                }
                .fill(
                    LinearGradient(colors: [.green.opacity(0.3), .green.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                )
                
                // Upload Wave (cyan)
                Path { path in
                    drawWave(path: &path, data: uploadHistory, size: geometry.size)
                }
                .stroke(
                    LinearGradient(colors: [.cyan.opacity(0.8), .cyan.opacity(0.3)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1.5
                )
            }
        }
    }
    
    private func drawWave(path: inout Path, data: [Double], size: CGSize) {
        guard data.count > 1 else { return }
        
        let maxValue = max(data.max() ?? 1, 1000) // 至少 1KB/s 作为最小刻度
        let stepX = size.width / CGFloat(data.count - 1)
        
        for (index, value) in data.enumerated() {
            let x = CGFloat(index) * stepX
            let normalizedY = min(value / maxValue, 1.0)
            let y = size.height - (CGFloat(normalizedY) * size.height * 0.9)
            
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
    }
    
    private func drawWaveFill(path: inout Path, data: [Double], size: CGSize) {
        guard data.count > 1 else { return }
        
        let maxValue = max(data.max() ?? 1, 1000)
        let stepX = size.width / CGFloat(data.count - 1)
        
        path.move(to: CGPoint(x: 0, y: size.height))
        
        for (index, value) in data.enumerated() {
            let x = CGFloat(index) * stepX
            let normalizedY = min(value / maxValue, 1.0)
            let y = size.height - (CGFloat(normalizedY) * size.height * 0.9)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()
    }
}

// MARK: - 6. Network Optimize View
struct ConsoleNetworkOptimizeView: View {
    @Binding var viewState: MonitorView.DashboardState
    @ObservedObject var systemService: SystemMonitorService
    @ObservedObject private var loc = LocalizationManager.shared
    
    @State private var isOptimizing = false
    @State private var optimizationComplete = false
    @State private var optimizationProgress = 0.0
    @State private var currentOptimization = ""
    
    var body: some View {
        VStack(spacing: 0) {
            ConsoleHeader(
                title: loc.text("网络优化", "Network Optimization"),
                backAction: { viewState = .dashboard }
            )
            
            Spacer()
            
            if isOptimizing {
                optimizingView
            } else if optimizationComplete {
                completeView
            } else {
                mainView
            }
            
            Spacer()
        }
    }
    
    // 主界面
    private var mainView: some View {
        VStack(spacing: 30) {
            // 网络图标
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "wifi")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
            }
            
            // 当前网速显示
            VStack(spacing: 16) {
                Text(loc.text("当前网络速度", "Current Network Speed"))
                    .font(.title2)
                    .foregroundColor(.white)
                
                HStack(spacing: 40) {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.green)
                            Text(loc.text(
    simplifiedChinese: "下载",
    traditionalChinese: "下載",
    english: "Download",
    japanese: "ダウンロード",
    korean: "다운로드",
    russian: "Загрузить"
))
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                        Text(systemService.formatSpeed(systemService.downloadSpeed))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(.cyan)
                            Text(loc.text(
    simplifiedChinese: "上传",
    traditionalChinese: "上傳",
    english: "Upload",
    japanese: "アップロード",
    korean: "업로드",
    russian: "Загрузить"
))
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                        Text(systemService.formatSpeed(systemService.uploadSpeed))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                // 波形图
                NetworkWaveform(downloadHistory: systemService.downloadSpeedHistory, uploadHistory: systemService.uploadSpeedHistory)
                    .frame(height: 80)
                    .frame(maxWidth: 400)
                    .padding(.top, 20)
            }
            
            // 优化按钮
            Button(action: { startOptimization() }) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                    Text(loc.text("优化网络", "Optimize Network"))
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 14)
                .background(LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing))
                .cornerRadius(25)
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
            
            // 优化说明
            VStack(alignment: .leading, spacing: 8) {
                Text(loc.text("网络优化将执行：", "Network optimization will:"))
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                
                VStack(alignment: .leading, spacing: 4) {
                    OptimizationItem(text: loc.text("刷新 DNS 缓存", "Flush DNS cache"))
                    OptimizationItem(text: loc.text("清理网络临时文件", "Clear network temp files"))
                    OptimizationItem(text: loc.text("优化网络设置", "Optimize network settings"))
                }
            }
            .padding(.top, 30)
        }
    }
    
    // 优化中视图
    private var optimizingView: some View {
        VStack(spacing: 30) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 6)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: optimizationProgress)
                    .stroke(
                        LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: "wifi")
                    .font(.system(size: 36))
                    .foregroundColor(.green)
            }
            
            Text(loc.text("正在优化网络...", "Optimizing Network..."))
                .font(.title2)
                .foregroundColor(.white)
            
            Text(currentOptimization)
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
    }
    
    // 完成视图
    private var completeView: some View {
        VStack(spacing: 30) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.green)
            }
            
            Text(loc.text("网络优化完成", "Network Optimization Complete"))
                .font(.title2)
                .foregroundColor(.white)
            
            Text(loc.text("您的网络已优化完毕", "Your network has been optimized"))
                .font(.body)
                .foregroundColor(.secondaryText)
            
            Button(action: { viewState = .dashboard }) {
                Text(loc.text("返回控制台", "Back to Console"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(25)
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
        }
    }
    
    private func startOptimization() {
        isOptimizing = true
        optimizationProgress = 0
        
        let steps = [
            (loc.text("刷新 DNS 缓存...", "Flushing DNS cache..."), "sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder"),
            (loc.text("清理网络临时文件...", "Cleaning network temp files..."), "rm -rf ~/Library/Caches/com.apple.network* 2>/dev/null"),
            (loc.text("优化网络设置...", "Optimizing network settings..."), "networksetup -setairportpower en0 off 2>/dev/null; sleep 1; networksetup -setairportpower en0 on 2>/dev/null")
        ]
        
        Task {
            for (index, step) in steps.enumerated() {
                await MainActor.run {
                    currentOptimization = step.0
                }
                
                // 模拟优化过程
                try? await Task.sleep(nanoseconds: 800_000_000)
                
                await MainActor.run {
                    optimizationProgress = Double(index + 1) / Double(steps.count)
                }
            }
            
            await MainActor.run {
                isOptimizing = false
                optimizationComplete = true
            }
        }
    }
}

struct OptimizationItem: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 12))
            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Protection View
struct ConsoleProtectionView: View {
    @Binding var viewState: MonitorView.DashboardState
    @ObservedObject var protectionService = ProtectionService.shared
    @ObservedObject var loc = LocalizationManager.shared
    @State private var selectedTab = 0 // 0: Ads, 1: Threats
    
    var body: some View {
        VStack(spacing: 0) {
            ConsoleHeader(
                title: loc.text(
    simplifiedChinese: "安全中心",
    traditionalChinese: "安全中心",
    english: "Safety Center",
    japanese: "セーフティセンター",
    korean: "CCTV 안전센터",
    russian: "Центр безопасности"
),
                backAction: { viewState = .dashboard }
            )
            
            ScrollView {
                VStack(spacing: 24) {
                    // Status Card
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(protectionService.isMonitoring ? (loc.text("实时保护已开启", "Real-time Protection: ON")) : (loc.text("实时保护已关闭", "Real-time Protection: OFF")))
                                .font(.title3)
                                .bold()
                                .foregroundColor(protectionService.isMonitoring ? .green : .white)
                            
                            Text(loc.text("正在监控下载文件夹和拦截网页广告", "Monitoring downloads and blocking ads"))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { protectionService.isMonitoring },
                            set: { newValue in
                                if newValue {
                                    protectionService.startMonitoring() 
                                } else {
                                    protectionService.stopMonitoring()
                                }
                            }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                    }
                    .padding(24)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    
                    // Statistics Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        // Downloads Monitored
                        MonitorStatCard(
                            title: loc.text("下载监控", "Downloads"),
                            value: "Active",
                            icon: "arrow.down.circle.fill",
                            color: .blue
                        )
                        
                        // Ads Blocked
                        MonitorStatCard(
                            title: loc.text("拦截广告", "Ads Blocked"),
                            value: "\(protectionService.adBlockedCount)",
                            icon: "hand.raised.fill",
                            color: .orange
                        )
                        
                        // Threats
                        MonitorStatCard(
                            title: loc.text("拦截威胁", "Threats"),
                            value: "\(protectionService.threatHistory.count)",
                            icon: "exclamationmark.shield.fill",
                            color: .red
                        )
                    }
                    
                    // Details Section
                    VStack(spacing: 16) {
                        // Tab Picker
                        Picker("", selection: $selectedTab) {
                            Text(loc.text("广告拦截记录", "Blocked Ads")).tag(0)
                            Text(loc.text("威胁记录", "Detected Threats")).tag(1)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        if selectedTab == 0 {
                            // Ads List
                            if protectionService.blockedAds.isEmpty {
                                EmptyStateView(
                                    icon: "hand.raised",
                                    title: loc.text("暂无拦截记录", "No Ads Blocked"),
                                    subtitle: loc.text("浏览网页时将自动拦截广告", "Ads will be blocked while browsing")
                                )
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(protectionService.blockedAds) { ad in
                                        HStack {
                                            Image(systemName: "safari.fill") // Generic browser icon or based on source
                                                .foregroundColor(.orange)
                                                .frame(width: 20)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(ad.domain)
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(.white)
                                                Text("\(ad.source) • \(formatDate(ad.date))")
                                                    .font(.caption2)
                                                    .foregroundColor(.white.opacity(0.5))
                                            }
                                            
                                            Spacer()
                                            
                                            Text(loc.text("已拦截", "Blocked"))
                                                .font(.caption2)
                                                .foregroundColor(.green)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.green.opacity(0.1))
                                                .cornerRadius(4)
                                        }
                                        .padding(12)
                                        .background(Color.white.opacity(0.04))
                                        .cornerRadius(8)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        } else {
                            // Threat List
                            if protectionService.threatHistory.isEmpty {
                                EmptyStateView(
                                    icon: "checkmark.shield",
                                    title: loc.text("未发现威胁", "No Threats Detected"),
                                    subtitle: loc.text("您的系统目前是安全的", "Your system is currently safe")
                                )
                            } else {
                                ForEach(protectionService.threatHistory) { threat in
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.red)
                                        VStack(alignment: .leading) {
                                            Text(threat.name)
                                                .foregroundColor(.white)
                                            Text(threat.path.path)
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.5))
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                        }
                                        Spacer()
                                        Text(threat.type.rawValue)
                                            .font(.caption)
                                            .padding(4)
                                            .background(Color.red.opacity(0.2))
                                            .cornerRadius(4)
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(8)
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 32)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.2))
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            Spacer()
        }
        .padding(40)
        .background(Color.white.opacity(0.02))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct MonitorStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}
