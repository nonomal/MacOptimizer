import SwiftUI
import AppKit

private let consoleAccent = Color(red: 0.28, green: 0.82, blue: 0.96)

// MARK: - Applications

struct ConsoleAppManagerDetailView: View {
    @Binding var viewState: MonitorView.DashboardState
    @StateObject private var appScanner = AppScanner()
    @StateObject private var processService = ProcessService()
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var apps: [ManagedApplication] = []
    @State private var selectedApp: ManagedApplication?

    var body: some View {
        ConsoleDetailPage(
            title: localized("应用管理", "Applications"),
            subtitle: localized("查看已安装应用的来源、大小与运行状态", "Installed application details and status"),
            backAction: { viewState = .dashboard },
            refreshAction: loadData
        ) {
            VStack(spacing: 12) {
                ConsoleSearchField(
                    placeholder: localized("搜索名称、开发者或 Bundle ID", "Search name, developer or bundle ID"),
                    text: $searchText
                )

                if isLoading {
                    ConsolePageLoadingState(text: localized("正在读取已安装应用…", "Loading installed applications…"))
                } else if filteredApps.isEmpty {
                    ConsolePageEmptyState(
                        symbol: "square.grid.2x2",
                        title: localized("没有找到应用", "No applications found"),
                        subtitle: searchText.isEmpty
                            ? localized("未能读取已安装应用", "Installed applications could not be read")
                            : localized("请尝试其他搜索条件", "Try another search")
                    )
                } else {
                    VStack(spacing: 0) {
                        ConsoleTableHeader(columns: [
                            (localized("应用", "Application"), nil),
                            (localized("来源", "Source"), 100),
                            (localized("大小", "Size"), 90),
                            (localized("状态", "Status"), 84),
                            (localized("详情", "Details"), 70)
                        ])

                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 2) {
                                ForEach(filteredApps) { app in
                                    Button { selectedApp = app } label: {
                                        ConsoleAppRow(app: app, loc: loc)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.bottom, 12)
                        }
                    }
                    .consolePanel()
                }
            }
        }
        .sheet(item: $selectedApp) { app in
            ConsoleAppDetailSheet(
                app: app,
                processService: processService,
                appScanner: appScanner,
                onChanged: loadData
            )
        }
        .onAppear(perform: loadData)
    }

    private var filteredApps: [ManagedApplication] {
        guard !searchText.isEmpty else { return apps }
        return apps.filter {
            $0.app.name.localizedCaseInsensitiveContains(searchText)
                || $0.app.vendor.localizedCaseInsensitiveContains(searchText)
                || ($0.app.bundleIdentifier?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private func localized(_ chinese: String, _ english: String) -> String {
        loc.text(chinese, english)
    }

    private func loadData() {
        Task {
            await MainActor.run { isLoading = true }
            if appScanner.apps.isEmpty {
                await appScanner.scanApplications()
            }
            await processService.scanProcesses(showApps: true)

            let runningByPath = Dictionary(grouping: processService.processes) { $0.validationPath ?? "" }
            let mapped = appScanner.apps.map { installed in
                let process = runningByPath[installed.path.path]?.first
                    ?? processService.processes.first(where: { $0.name == installed.name })
                return ManagedApplication(app: installed, process: process)
            }.sorted {
                if $0.isRunning != $1.isRunning { return $0.isRunning }
                return $0.app.name.localizedStandardCompare($1.app.name) == .orderedAscending
            }

            await MainActor.run {
                apps = mapped
                isLoading = false
            }
        }
    }
}

private struct ManagedApplication: Identifiable {
    let app: InstalledApp
    let process: ProcessItem?
    var id: UUID { app.id }
    var isRunning: Bool { process != nil }
}

private struct ConsoleAppRow: View {
    let app: ManagedApplication
    let loc: LocalizationManager
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(nsImage: app.app.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.app.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.90))
                        .lineLimit(1)
                    Text(app.app.version.map { "v\($0)" } ?? loc.text(
    simplifiedChinese: "版本未知",
    traditionalChinese: "版本未知",
    english: "Unknown version",
    japanese: "不明なバージョン",
    korean: "알 수 없는 버전",
    russian: "Неизвестная версия"
))
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.38))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(app.app.isAppStore ? "App Store" : loc.text("开发者", "Developer"))
                .consoleCell(width: 100)
            Text(app.app.formattedSize).consoleCell(width: 90)
            ConsoleStatusPill(
                title: app.isRunning ? loc.text("运行中", "Running") : loc.text(
    simplifiedChinese: "未运行",
    traditionalChinese: "未運行",
    english: "Stopped",
    japanese: "中止中",
    korean: "중지됨",
    russian: "Остановлено"
),
                active: app.isRunning
            )
            .frame(width: 84, alignment: .leading)
            ConsoleDetailsIndicator().frame(width: 70)
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(Color.white.opacity(isHovering ? 0.060 : 0.025), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}

private struct ConsoleAppDetailSheet: View {
    let app: ManagedApplication
    @ObservedObject var processService: ProcessService
    @ObservedObject var appScanner: AppScanner
    let onChanged: () -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var showForceQuitConfirmation = false
    @State private var showCleanConfirmation = false
    @State private var isWorking = false
    @State private var resultMessage: String?

    var body: some View {
        ConsoleDetailSheet(title: localized("应用详情", "Application Details"), dismiss: { dismiss() }) {
            HStack(alignment: .top, spacing: 18) {
                Image(nsImage: app.app.icon)
                    .resizable().scaledToFit()
                    .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 5) {
                    Text(app.app.name).font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                    Text(app.app.version.map { "Version \($0)" } ?? localized("版本未知", "Unknown version"))
                        .font(.system(size: 11)).foregroundColor(.white.opacity(0.48))
                    ConsoleStatusPill(title: app.isRunning ? localized("运行中", "Running") : localized("未运行", "Stopped"), active: app.isRunning)
                }
                Spacer()
            }

            ConsoleDetailGrid(rows: [
                (localized("Bundle ID", "Bundle ID"), app.app.bundleIdentifier ?? "—"),
                (localized("开发者", "Developer"), app.app.vendor),
                (localized("来源", "Source"), app.app.isAppStore ? "Mac App Store" : localized("开发者分发", "Developer distribution")),
                (localized("应用大小", "Application size"), app.app.formattedSize),
                ("PID", app.process.map { String($0.pid) } ?? "—"),
                (localized("路径", "Path"), app.app.path.path)
            ])

            if let resultMessage {
                Text(resultMessage).font(.system(size: 10)).foregroundColor(.white.opacity(0.58))
            }

            HStack(spacing: 10) {
                ConsoleSecondaryButton(title: localized("在访达中显示", "Show in Finder"), symbol: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([app.app.path])
                }
                Spacer()
                ConsoleDestructiveButton(title: localized("清理应用数据", "Clean App Data"), symbol: "eraser") {
                    showCleanConfirmation = true
                }
                .disabled(isWorking)
                if app.isRunning {
                    ConsoleDestructiveButton(title: localized("强制退出", "Force Quit"), symbol: "xmark.octagon") {
                        showForceQuitConfirmation = true
                    }
                    .disabled(isWorking || app.process?.pid == ProcessInfo.processInfo.processIdentifier)
                }
            }
        }
        .alert(localized("确认强制退出？", "Force quit this app?"), isPresented: $showForceQuitConfirmation) {
            Button(localized("取消", "Cancel"), role: .cancel) {}
            Button(localized("强制退出", "Force Quit"), role: .destructive) {
                guard let process = app.process else { return }
                processService.forceTerminateProcess(process)
                resultMessage = localized("已发送强制退出请求", "Force quit request sent")
                onChanged()
            }
        } message: {
            Text(localized("未保存的内容可能丢失。", "Unsaved work may be lost."))
        }
        .alert(localized("确认清理应用数据？", "Clean application data?"), isPresented: $showCleanConfirmation) {
            Button(localized("取消", "Cancel"), role: .cancel) {}
            Button(localized("移到废纸篓", "Move Data to Trash"), role: .destructive) { cleanApplicationData() }
        } message: {
            Text(localized("将清理缓存、日志和配置等残留数据，但保留应用本体。运行中的应用会先被强制退出。", "Caches, logs and preferences will be moved to Trash while the app remains installed. A running app will be force quit first."))
        }
    }

    private func localized(_ chinese: String, _ english: String) -> String { loc.text(chinese, english) }

    private func cleanApplicationData() {
        Task {
            isWorking = true
            if let process = app.process {
                await processService.cleanAppData(for: process)
            } else {
                let files = await ResidualFileScanner().scanResidualFiles(for: app.app)
                await MainActor.run {
                    files.forEach { $0.isSelected = true }
                    app.app.residualFiles = files
                }
                _ = await FileRemover().removeResidualFiles(of: app.app, moveToTrash: true)
            }
            await appScanner.refreshAppSize(for: app.app)
            await MainActor.run {
                isWorking = false
                resultMessage = localized("应用数据清理完成", "Application data cleaned")
                onChanged()
            }
        }
    }
}

// MARK: - Processes

struct ConsoleProcessManagerDetailView: View {
    @Binding var viewState: MonitorView.DashboardState
    @Binding var sortMode: ConsoleProcessSortMode
    @StateObject private var service = ProcessService()
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var searchText = ""
    @State private var selectedProcess: ProcessItem?

    var body: some View {
        ConsoleDetailPage(
            title: localized("进程管理", "Processes"),
            subtitle: localized("查看当前用户进程的 CPU、内存与命令路径", "CPU, memory and command paths for current-user processes"),
            backAction: { viewState = .dashboard },
            refreshAction: refresh
        ) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ConsoleSearchField(placeholder: localized("搜索名称、PID 或用户", "Search name, PID or user"), text: $searchText)
                    Picker("", selection: $sortMode) {
                        Text(localized("按内存", "Memory")).tag(ConsoleProcessSortMode.memory)
                        Text(localized("按 CPU", "CPU")).tag(ConsoleProcessSortMode.cpu)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 170)
                }

                if service.isScanning && service.processes.isEmpty {
                    ConsolePageLoadingState(text: localized("正在读取进程…", "Loading processes…"))
                } else if let error = service.lastError, service.processes.isEmpty {
                    ConsolePageEmptyState(symbol: "exclamationmark.triangle", title: localized("无法读取进程", "Processes unavailable"), subtitle: error)
                } else if filteredProcesses.isEmpty {
                    ConsolePageEmptyState(symbol: "waveform.path.ecg", title: localized("没有找到进程", "No processes found"), subtitle: localized("请尝试其他搜索条件", "Try another search"))
                } else {
                    VStack(spacing: 0) {
                        ConsoleTableHeader(columns: [
                            (localized("进程", "Process"), nil), ("PID", 72), ("CPU", 72),
                            (localized("内存", "Memory"), 92), (localized("用户", "User"), 90), (localized("详情", "Details"), 70)
                        ])
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 2) {
                                ForEach(filteredProcesses) { item in
                                    Button { selectedProcess = item } label: { ConsoleProcessRow(item: item) }
                                        .buttonStyle(.plain)
                                }
                            }
                            .padding(.bottom, 12)
                        }
                    }
                    .consolePanel()
                }
            }
        }
        .sheet(item: $selectedProcess) { item in
            ConsoleProcessDetailSheet(item: item, service: service) { refresh() }
        }
        .onAppear(perform: refresh)
    }

    private var filteredProcesses: [ProcessItem] {
        service.processes.filter {
            searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
                || String($0.pid).contains(searchText) || $0.user.localizedCaseInsensitiveContains(searchText)
        }.sorted {
            if sortMode == .cpu, $0.cpuUsage != $1.cpuUsage { return $0.cpuUsage > $1.cpuUsage }
            if sortMode == .memory, $0.memoryUsage != $1.memoryUsage { return $0.memoryUsage > $1.memoryUsage }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private func refresh() { Task { await service.scanProcesses(showApps: false) } }
    private func localized(_ chinese: String, _ english: String) -> String { loc.text(chinese, english) }
}

private struct ConsoleProcessRow: View {
    let item: ProcessItem
    @State private var isHovering = false
    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 9) {
                Group {
                    if let icon = item.icon { Image(nsImage: icon).resizable().scaledToFit() }
                    else { Image(systemName: "gearshape.fill").foregroundColor(.white.opacity(0.32)) }
                }.frame(width: 22, height: 22)
                Text(item.name).font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.88)).lineLimit(1)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Text(String(item.pid)).consoleCell(width: 72, monospaced: true)
            Text(String(format: "%.1f%%", item.cpuUsage)).consoleCell(width: 72, monospaced: true)
            Text(item.formattedMemory).consoleCell(width: 92, monospaced: true)
            Text(item.user).consoleCell(width: 90)
            ConsoleDetailsIndicator().frame(width: 70)
        }
        .padding(.horizontal, 14).frame(height: 46)
        .background(Color.white.opacity(isHovering ? 0.060 : 0.025), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle()).onHover { isHovering = $0 }
    }
}

private struct ConsoleProcessDetailSheet: View {
    let item: ProcessItem
    @ObservedObject var service: ProcessService
    let onChanged: () -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var showConfirmation = false

    var body: some View {
        ConsoleDetailSheet(title: localized("进程详情", "Process Details"), dismiss: { dismiss() }) {
            HStack(spacing: 14) {
                Image(systemName: "waveform.path.ecg").font(.system(size: 28)).foregroundColor(consoleAccent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name).font(.system(size: 19, weight: .bold)).foregroundColor(.white)
                    Text(item.isApp ? localized("图形应用进程", "Application process") : localized("当前用户后台进程", "Current-user background process"))
                        .font(.system(size: 10)).foregroundColor(.white.opacity(0.45))
                }
                Spacer()
            }
            ConsoleDetailGrid(rows: [
                ("PID", String(item.pid)), ("CPU", String(format: "%.1f%%", item.cpuUsage)),
                (localized("内存", "Memory"), item.formattedMemory), (localized("用户", "User"), item.user),
                (localized("类型", "Type"), item.isApp ? localized("应用", "Application") : localized("后台进程", "Background process")),
                (localized("命令路径", "Command path"), item.commandPath.isEmpty ? "—" : item.commandPath)
            ])
            HStack {
                Text(localized("强制结束可能导致未保存的数据丢失或关联服务中断。", "Force quitting may lose unsaved data or interrupt related services."))
                    .font(.system(size: 9)).foregroundColor(.white.opacity(0.38))
                Spacer()
                ConsoleDestructiveButton(title: localized("强制结束", "Force Quit"), symbol: "xmark.octagon") { showConfirmation = true }
                    .disabled(item.pid == ProcessInfo.processInfo.processIdentifier)
            }
        }
        .alert(localized("确认强制结束进程？", "Force quit this process?"), isPresented: $showConfirmation) {
            Button(localized("取消", "Cancel"), role: .cancel) {}
            Button(localized("强制结束", "Force Quit"), role: .destructive) {
                service.forceTerminateProcess(item); onChanged(); dismiss()
            }
        } message: { Text("\(item.name) · PID \(item.pid)") }
    }
    private func localized(_ chinese: String, _ english: String) -> String { loc.text(chinese, english) }
}

// MARK: - Ports

struct ConsolePortManagerDetailView: View {
    @Binding var viewState: MonitorView.DashboardState
    @StateObject private var service = PortScannerService()
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var searchText = ""
    @State private var selectedPort: PortItem?

    var body: some View {
        ConsoleDetailPage(
            title: localized("端口管理", "Ports"),
            subtitle: localized("读取本机真实监听端口和所属进程", "Live listening ports and owning processes"),
            backAction: { viewState = .dashboard },
            refreshAction: refresh
        ) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ConsoleSearchField(placeholder: localized("搜索程序、端口、PID 或地址", "Search process, port, PID or address"), text: $searchText)
                    Toggle(localized("仅监听", "Listening only"), isOn: $service.filterListeningOnly)
                        .toggleStyle(.switch).font(.system(size: 10)).foregroundColor(.white.opacity(0.65))
                        .onChange(of: service.filterListeningOnly) { _ in refresh() }
                }
                if service.isScanning && service.ports.isEmpty {
                    ConsolePageLoadingState(text: localized("正在读取网络端口…", "Loading network ports…"))
                } else if let error = service.lastError, service.ports.isEmpty {
                    ConsolePageEmptyState(symbol: "exclamationmark.triangle", title: localized("无法读取端口", "Ports unavailable"), subtitle: error)
                } else if filteredPorts.isEmpty {
                    ConsolePageEmptyState(symbol: "network", title: localized("没有找到端口", "No ports found"), subtitle: localized("当前筛选条件下没有网络连接", "No network connections match this filter"))
                } else {
                    VStack(spacing: 0) {
                        ConsoleTableHeader(columns: [
                            (localized("程序", "Process"), nil), ("PID", 72), (localized("端口", "Port"), 72),
                            (localized("协议", "Protocol"), 72), (localized("状态", "State"), 90), (localized("详情", "Details"), 70)
                        ])
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 2) {
                                ForEach(filteredPorts) { item in
                                    Button { selectedPort = item } label: { ConsolePortRow(item: item) }.buttonStyle(.plain)
                                }
                            }.padding(.bottom, 12)
                        }
                    }.consolePanel()
                }
            }
        }
        .sheet(item: $selectedPort) { item in ConsolePortDetailSheet(item: item, service: service) { refresh() } }
        .onAppear(perform: refresh)
    }

    private var filteredPorts: [PortItem] {
        service.ports.filter { searchText.isEmpty || $0.displayName.localizedCaseInsensitiveContains(searchText)
            || String($0.pid).contains(searchText) || $0.portString.contains(searchText)
            || $0.address.localizedCaseInsensitiveContains(searchText) }
    }
    private func refresh() { Task { await service.scanPorts() } }
    private func localized(_ chinese: String, _ english: String) -> String { loc.text(chinese, english) }
}

private struct ConsolePortRow: View {
    let item: PortItem
    @State private var isHovering = false
    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 9) {
                Group { if let icon = item.icon { Image(nsImage: icon).resizable().scaledToFit() } else { Image(systemName: "network").foregroundColor(consoleAccent) } }.frame(width: 22, height: 22)
                Text(item.displayName).font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.88)).lineLimit(1)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Text(String(item.pid)).consoleCell(width: 72, monospaced: true)
            Text(item.portString).consoleCell(width: 72, monospaced: true, color: consoleAccent)
            Text(item.protocol).consoleCell(width: 72)
            ConsoleStatusPill(title: item.state.isEmpty ? "—" : item.state, active: item.state == "LISTEN").frame(width: 90, alignment: .leading)
            ConsoleDetailsIndicator().frame(width: 70)
        }
        .padding(.horizontal, 14).frame(height: 46)
        .background(Color.white.opacity(isHovering ? 0.060 : 0.025), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle()).onHover { isHovering = $0 }
    }
}

private struct ConsolePortDetailSheet: View {
    let item: PortItem
    @ObservedObject var service: PortScannerService
    let onChanged: () -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var showConfirmation = false
    var body: some View {
        ConsoleDetailSheet(title: localized("端口详情", "Port Details"), dismiss: { dismiss() }) {
            HStack(spacing: 14) {
                Image(systemName: "network").font(.system(size: 28)).foregroundColor(consoleAccent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.displayName).font(.system(size: 19, weight: .bold)).foregroundColor(.white)
                    Text("\(item.protocol) · \(item.address):\(item.portString)").font(.system(size: 10, design: .monospaced)).foregroundColor(.white.opacity(0.45))
                }; Spacer()
            }
            ConsoleDetailGrid(rows: [
                (localized("进程", "Process"), item.displayName), ("PID", String(item.pid)),
                (localized("用户", "User"), item.user), (localized("端口", "Port"), item.portString),
                (localized("协议", "Protocol"), item.protocol), (localized("状态", "State"), item.state.isEmpty ? "—" : item.state),
                (localized("监听地址", "Address"), item.address)
            ])
            HStack {
                Text(localized("结束进程会同时关闭该进程拥有的其他端口。", "Ending the process also closes its other ports."))
                    .font(.system(size: 9)).foregroundColor(.white.opacity(0.38))
                Spacer()
                ConsoleDestructiveButton(title: localized("结束进程", "End Process"), symbol: "xmark.octagon") { showConfirmation = true }
                    .disabled(Int32(item.pid) == ProcessInfo.processInfo.processIdentifier)
            }
        }
        .alert(localized("确认结束进程？", "End this process?"), isPresented: $showConfirmation) {
            Button(localized("取消", "Cancel"), role: .cancel) {}
            Button(localized("结束进程", "End Process"), role: .destructive) { service.terminateProcess(item); onChanged(); dismiss() }
        } message: { Text("\(item.displayName) · PID \(item.pid)") }
    }
    private func localized(_ chinese: String, _ english: String) -> String { loc.text(chinese, english) }
}

// MARK: - Network diagnostics

struct ConsoleNetworkDetailView: View {
    @Binding var viewState: MonitorView.DashboardState
    @ObservedObject var systemService: SystemMonitorService
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var isDiagnosing = false
    @State private var diagnostic: NetworkDiagnostic?

    var body: some View {
        ConsoleDetailPage(
            title: localized("网络诊断", "Network Diagnostics"),
            subtitle: localized("实时流量与只读连接检查，不修改网络设置", "Live traffic and read-only checks; no settings are changed"),
            backAction: { viewState = .dashboard },
            refreshAction: diagnose
        ) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        ConsoleInfoMetric(title: "SSID", value: networkDisplayName, symbol: "wifi")
                        ConsoleInfoMetric(title: localized("本次监控", "Monitoring"), value: systemService.connectionDuration, symbol: "clock")
                    }
                    HStack(spacing: 12) {
                        ConsoleInfoMetric(title: localized("实时下载", "Download"), value: systemService.formatSpeed(systemService.downloadSpeed), symbol: "arrow.down")
                        ConsoleInfoMetric(title: localized("实时上传", "Upload"), value: systemService.formatSpeed(systemService.uploadSpeed), symbol: "arrow.up")
                        ConsoleInfoMetric(title: localized("累计下载", "Downloaded"), value: systemService.totalDownload, symbol: "tray.and.arrow.down")
                        ConsoleInfoMetric(title: localized("累计上传", "Uploaded"), value: systemService.totalUpload, symbol: "tray.and.arrow.up")
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text(localized("最近 40 秒", "Last 40 seconds")).font(.system(size: 11, weight: .semibold)).foregroundColor(.white.opacity(0.82))
                        NetworkWaveform(downloadHistory: systemService.downloadSpeedHistory, uploadHistory: systemService.uploadSpeedHistory).frame(height: 92)
                    }.padding(16).consolePanel()

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(localized("连接诊断", "Connection checks")).font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                                Text(localized("检查默认路由和 DNS 解析，仅执行读取命令", "Read-only checks for default route and DNS resolution"))
                                    .font(.system(size: 9)).foregroundColor(.white.opacity(0.42))
                            }
                            Spacer()
                            ConsoleSecondaryButton(title: localized("重新诊断", "Run Again"), symbol: "arrow.clockwise", action: diagnose).disabled(isDiagnosing)
                        }
                        if isDiagnosing {
                            HStack { ProgressView().scaleEffect(0.7); Text(localized("正在诊断…", "Running diagnostics…")) }.font(.system(size: 10)).foregroundColor(.white.opacity(0.55))
                        } else if let diagnostic {
                            ConsoleDiagnosticRow(title: localized("默认路由", "Default route"), value: diagnostic.gateway, passed: diagnostic.hasGateway)
                            ConsoleDiagnosticRow(title: localized("DNS 解析", "DNS resolution"), value: diagnostic.dnsMessage, passed: diagnostic.dnsWorks)
                            ConsoleDiagnosticRow(title: localized("网络接口", "Network interface"), value: diagnostic.interface, passed: diagnostic.interface != "—")
                        }
                    }.padding(16).consolePanel()
                }.padding(.bottom, 20)
            }
        }
        .onAppear { systemService.startMonitoring(); diagnose() }
    }

    private func diagnose() {
        guard !isDiagnosing else { return }
        isDiagnosing = true
        Task.detached {
            let routeOutput = Self.run("/sbin/route", ["-n", "get", "default"])
            let gateway = routeOutput.components(separatedBy: "\n").first(where: { $0.contains("gateway:") })?
                .components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces) ?? "—"
            let interface = routeOutput.components(separatedBy: "\n").first(where: { $0.contains("interface:") })?
                .components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces) ?? "—"
            let dnsOutput = Self.run("/usr/bin/dscacheutil", ["-q", "host", "-a", "name", "apple.com"])
            let result = NetworkDiagnostic(gateway: gateway, interface: interface, hasGateway: gateway != "—", dnsWorks: dnsOutput.contains("ip_address:"), dnsMessage: dnsOutput.contains("ip_address:") ? "apple.com" : "—")
            await MainActor.run { diagnostic = result; isDiagnosing = false }
        }
    }
    nonisolated private static func run(_ path: String, _ arguments: [String]) -> String {
        let process = Process(); let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: path); process.arguments = arguments; process.standardOutput = pipe; process.standardError = FileHandle.nullDevice
        do { try process.run(); let data = pipe.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit(); return String(data: data, encoding: .utf8) ?? "" } catch { return "" }
    }
    private var networkDisplayName: String {
        if !systemService.wifiSSID.contains("Not Connected") { return systemService.wifiSSID }
        guard let interface = diagnostic?.interface, interface != "—" else { return localized("未连接", "Not Connected") }
        return loc.text(
            simplifiedChinese: "已连接 · \(interface)",
            traditionalChinese: "已連線 · \(interface)",
            english: "Connected · \(interface)",
            japanese: "接続済み · \(interface)",
            korean: "연결됨 · \(interface)",
            russian: "Подключено · \(interface)"
        )
    }
    private func localized(_ chinese: String, _ english: String) -> String { loc.text(chinese, english) }
}

private struct NetworkDiagnostic { let gateway: String; let interface: String; let hasGateway: Bool; let dnsWorks: Bool; let dnsMessage: String }

// MARK: - Protection

struct ConsoleProtectionDetailView: View {
    @Binding var viewState: MonitorView.DashboardState
    @ObservedObject private var service = ProtectionService.shared
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var section = 0

    var body: some View {
        ConsoleDetailPage(
            title: localized("安全中心", "Safety Center"),
            subtitle: localized("真实下载目录监控与安全能力状态", "Download monitoring and security capability status"),
            backAction: { viewState = .dashboard }
        ) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(service.isMonitoring ? localized("下载实时监控已开启", "Download monitoring is on") : localized("下载实时监控已关闭", "Download monitoring is off"))
                                .font(.system(size: 15, weight: .bold)).foregroundColor(service.isMonitoring ? .green : .white)
                            Text(localized("监控下载目录中新写入的文件；浏览器内容拦截为独立扩展能力", "Monitors new files in Downloads; browser blocking requires a separate extension"))
                                .font(.system(size: 10)).foregroundColor(.white.opacity(0.48))
                        }
                        Spacer()
                        Toggle("", isOn: Binding(get: { service.isMonitoring }, set: { $0 ? service.startMonitoring() : service.stopMonitoring() }))
                            .toggleStyle(.switch)
                    }.padding(16).consolePanel()

                    HStack(spacing: 12) {
                        ConsoleCapabilityCard(title: localized("下载监控", "Downloads"), value: service.isMonitoring ? localized("运行中", "Active") : localized("已关闭", "Off"), symbol: "arrow.down.circle", active: service.isMonitoring) { section = 0 }
                        ConsoleCapabilityCard(title: localized("浏览器拦截", "Browser Blocking"), value: localized("未连接扩展", "Not Connected"), symbol: "safari", active: false) { section = 1 }
                        ConsoleCapabilityCard(title: localized("威胁记录", "Threats"), value: "\(service.threatHistory.count)", symbol: "exclamationmark.shield", active: service.threatHistory.isEmpty) { section = 2 }
                    }

                    Picker("", selection: $section) {
                        Text(localized("下载监控详情", "Download Details")).tag(0)
                        Text(localized("浏览器扩展", "Browser Extension")).tag(1)
                        Text(localized("威胁记录", "Threat History")).tag(2)
                    }.pickerStyle(.segmented)

                    protectionDetails
                }.padding(.bottom, 20)
            }
        }
    }

    @ViewBuilder private var protectionDetails: some View {
        if section == 0 {
            VStack(alignment: .leading, spacing: 12) {
                ConsoleDetailGrid(rows: [
                    (localized("监控位置", "Monitored folder"), FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? "~/Downloads"),
                    (localized("检测方式", "Detection"), localized("下载目录新增或修改文件触发扫描", "Scan on new or modified files in Downloads")),
                    (localized("当前状态", "Status"), service.isMonitoring ? localized("运行中", "Active") : localized("已关闭", "Off"))
                ])
                ConsoleSecondaryButton(title: localized("在访达中显示", "Show in Finder"), symbol: "folder") {
                    if let url = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                }
            }.padding(16).consolePanel()
        } else if section == 1 {
            ConsolePageEmptyState(symbol: "puzzlepiece.extension", title: localized("未连接浏览器内容拦截扩展", "Browser content blocker not connected"), subtitle: localized("当前版本不会生成或展示模拟广告拦截数据。接入 Safari 或其他浏览器扩展后，才能显示真实拦截统计。", "This version does not generate simulated ad-blocking data. Real statistics require a connected browser extension."))
        } else if service.threatHistory.isEmpty {
            ConsolePageEmptyState(symbol: "checkmark.shield", title: localized("未发现威胁", "No threats detected"), subtitle: localized("当前没有真实的威胁检测记录", "There are no recorded detections"))
        } else {
            VStack(spacing: 6) {
                ForEach(service.threatHistory) { threat in
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(threat.name).font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
                            Text(threat.path.path).font(.system(size: 9)).foregroundColor(.white.opacity(0.42)).lineLimit(1).truncationMode(.middle)
                        }
                        Spacer(); Text(threat.type.rawValue).font(.system(size: 9)).foregroundColor(.red)
                    }.padding(12).consolePanel()
                }
            }
        }
    }
    private func localized(_ chinese: String, _ english: String) -> String { loc.text(chinese, english) }
}

// MARK: - Shared console UI

private struct ConsoleDetailPage<Content: View>: View {
    let title: String; let subtitle: String; let backAction: () -> Void; var refreshAction: (() -> Void)? = nil
    @ViewBuilder let content: Content
    init(title: String, subtitle: String, backAction: @escaping () -> Void, refreshAction: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.title = title; self.subtitle = subtitle; self.backAction = backAction; self.refreshAction = refreshAction; self.content = content()
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: backAction) { Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold)).frame(width: 30, height: 30).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8)) }.buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 20, weight: .bold)); Text(subtitle).font(.system(size: 9)).foregroundColor(.white.opacity(0.42)) }.foregroundColor(.white)
                Spacer()
                if let refreshAction { ConsoleSecondaryButton(title: "", symbol: "arrow.clockwise", action: refreshAction) }
            }.padding(.horizontal, 22).frame(height: 72)
            content.padding(.horizontal, 22).padding(.bottom, 18)
        }
    }
}

private struct ConsoleSearchField: View {
    let placeholder: String; @Binding var text: String
    var body: some View { HStack(spacing: 8) { Image(systemName: "magnifyingglass").foregroundColor(.white.opacity(0.32)); TextField(placeholder, text: $text).textFieldStyle(.plain).foregroundColor(.white); if !text.isEmpty { Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.white.opacity(0.35)) }.buttonStyle(.plain) } }.padding(.horizontal, 12).frame(height: 36).background(Color.black.opacity(0.13), in: RoundedRectangle(cornerRadius: 9)).overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.07), lineWidth: 0.7)) }
}

private struct ConsoleTableHeader: View {
    let columns: [(String, CGFloat?)]
    var body: some View { HStack(spacing: 10) { ForEach(Array(columns.enumerated()), id: \.offset) { _, column in Text(column.0).frame(maxWidth: column.1 == nil ? .infinity : nil, alignment: .leading).frame(width: column.1).font(.system(size: 9, weight: .medium)).foregroundColor(.white.opacity(0.36)) } }.padding(.horizontal, 14).frame(height: 32) }
}

private struct ConsoleStatusPill: View {
    let title: String; let active: Bool
    var body: some View { HStack(spacing: 5) { Circle().fill(active ? Color.green : Color.white.opacity(0.28)).frame(width: 5, height: 5); Text(title).font(.system(size: 9, weight: .medium)).foregroundColor(active ? .green : .white.opacity(0.48)).lineLimit(1) } }
}

private struct ConsoleDetailsIndicator: View {
    var body: some View { HStack(spacing: 4) { Text(LocalizationManager.shared.text(
    simplifiedChinese: "查看",
    traditionalChinese: "查看",
    english: "View",
    japanese: "表示",
    korean: "보기",
    russian: "Просмотр"
)); Image(systemName: "chevron.right").font(.system(size: 7, weight: .bold)) }.font(.system(size: 9, weight: .medium)).foregroundColor(.white.opacity(0.48)).frame(maxWidth: .infinity, alignment: .trailing) }
}

private struct ConsolePageLoadingState: View {
    let text: String
    var body: some View { VStack(spacing: 12) { ProgressView(); Text(text).font(.system(size: 10)).foregroundColor(.white.opacity(0.48)) }.frame(maxWidth: .infinity, maxHeight: .infinity).consolePanel() }
}

private struct ConsolePageEmptyState: View {
    let symbol: String; let title: String; let subtitle: String
    var body: some View { VStack(spacing: 9) { Image(systemName: symbol).font(.system(size: 28)).foregroundColor(.white.opacity(0.22)); Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.80)); Text(subtitle).font(.system(size: 10)).foregroundColor(.white.opacity(0.42)).multilineTextAlignment(.center).frame(maxWidth: 460) }.frame(maxWidth: .infinity, minHeight: 190).padding(18).consolePanel() }
}

private struct ConsoleDetailSheet<Content: View>: View {
    let title: String; let dismiss: () -> Void; @ViewBuilder let content: Content
    init(title: String, dismiss: @escaping () -> Void, @ViewBuilder content: () -> Content) { self.title = title; self.dismiss = dismiss; self.content = content() }
    var body: some View { ZStack { LinearGradient(colors: [Color(red: 0.20, green: 0.06, blue: 0.22), Color(red: 0.10, green: 0.04, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea(); VStack(spacing: 16) { HStack { Text(title).font(.system(size: 14, weight: .bold)).foregroundColor(.white); Spacer(); Button(action: dismiss) { Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).frame(width: 28, height: 28).background(Color.white.opacity(0.08), in: Circle()) }.buttonStyle(.plain) }; content; Spacer(minLength: 0) }.padding(20) }.frame(width: 590, height: 470) }
}

private struct ConsoleDetailGrid: View {
    let rows: [(String, String)]
    var body: some View { VStack(spacing: 0) { ForEach(Array(rows.enumerated()), id: \.offset) { index, row in HStack(alignment: .top, spacing: 12) { Text(row.0).font(.system(size: 10)).foregroundColor(.white.opacity(0.40)).frame(width: 94, alignment: .leading); Text(row.1).font(.system(size: 10, design: row.0.contains("路径") || row.0.contains("Path") ? .monospaced : .default)).foregroundColor(.white.opacity(0.78)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).lineLimit(2).truncationMode(.middle) }.padding(.vertical, 9); if index < rows.count - 1 { Divider().background(Color.white.opacity(0.06)) } } }.padding(.horizontal, 12).background(Color.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 0.7)) }
}

private struct ConsoleSecondaryButton: View {
    let title: String; let symbol: String; let action: () -> Void
    var body: some View { Button(action: action) { HStack(spacing: 6) { Image(systemName: symbol); if !title.isEmpty { Text(title) } }.font(.system(size: 10, weight: .medium)).foregroundColor(.white.opacity(0.78)).padding(.horizontal, title.isEmpty ? 9 : 12).frame(height: 30).background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 0.7)) }.buttonStyle(.plain) }
}

private struct ConsoleDestructiveButton: View {
    let title: String; let symbol: String; let action: () -> Void
    var body: some View { Button(action: action) { HStack(spacing: 6) { Image(systemName: symbol); Text(title) }.font(.system(size: 10, weight: .semibold)).foregroundColor(.red.opacity(0.92)).padding(.horizontal, 12).frame(height: 30).background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.16), lineWidth: 0.7)) }.buttonStyle(.plain) }
}

private struct ConsoleInfoMetric: View {
    let title: String; let value: String; let symbol: String
    var body: some View { HStack(spacing: 10) { Image(systemName: symbol).foregroundColor(consoleAccent).frame(width: 28, height: 28).background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8)); VStack(alignment: .leading, spacing: 2) { Text(title).font(.system(size: 9)).foregroundColor(.white.opacity(0.40)); Text(value).font(.system(size: 11, weight: .semibold)).foregroundColor(.white.opacity(0.86)).lineLimit(1) }; Spacer() }.padding(12).frame(maxWidth: .infinity, minHeight: 56).consolePanel() }
}

private struct ConsoleDiagnosticRow: View {
    let title: String; let value: String; let passed: Bool
    var body: some View { HStack(spacing: 9) { Image(systemName: passed ? "checkmark.circle.fill" : "exclamationmark.circle.fill").foregroundColor(passed ? .green : .orange); Text(title).font(.system(size: 10, weight: .medium)).foregroundColor(.white.opacity(0.72)); Spacer(); Text(value).font(.system(size: 9, design: .monospaced)).foregroundColor(.white.opacity(0.46)).lineLimit(1) } }
}

private struct ConsoleCapabilityCard: View {
    let title: String; let value: String; let symbol: String; let active: Bool; let action: () -> Void
    var body: some View { Button(action: action) { VStack(alignment: .leading, spacing: 10) { HStack { Image(systemName: symbol).foregroundColor(active ? .green : consoleAccent); Spacer(); Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold)).foregroundColor(.white.opacity(0.28)) }; Text(value).font(.system(size: 15, weight: .bold)).foregroundColor(.white); Text(title).font(.system(size: 9)).foregroundColor(.white.opacity(0.42)) }.padding(14).frame(maxWidth: .infinity, alignment: .leading).consolePanel() }.buttonStyle(.plain) }
}

private extension Text {
    func consoleCell(width: CGFloat, monospaced: Bool = false, color: Color = .white.opacity(0.52)) -> some View { self.font(.system(size: 10, design: monospaced ? .monospaced : .default)).foregroundColor(color).lineLimit(1).frame(width: width, alignment: .leading) }
}

private extension View {
    func consolePanel() -> some View { background(Color.black.opacity(0.13), in: RoundedRectangle(cornerRadius: 12, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.065), lineWidth: 0.7)) }
}
