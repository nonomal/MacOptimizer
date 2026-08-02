import AppKit
import SwiftUI

/// Pixel-led reconstruction of the CleanMyMac X Smart Scan module.
/// The scanner and cleaner remain the project's native implementations; this
/// view restores the original product's layout and state transitions.
struct SmartCleanerReplicaView: View {
    @Binding var selectedModule: AppModule

    @ObservedObject private var service = ScanServiceManager.shared.smartCleanerService
    @ObservedObject private var loc = LocalizationManager.shared

    @State private var showDetailSheet = false
    @State private var detailCategory: CleanerCategory?
    @State private var showCleanConfirmation = false
    @State private var cleaningFinished = false
    @State private var showRunningAppsAlert = false
    @State private var detectedRunningApps: [(name: String, icon: NSImage?, bundleId: String)] = []
    @State private var failedFiles: [CleanerFileItem] = []
    @State private var showAdminRetry = false

    private enum PageState {
        case initial, scanning, results, cleaning, finished
    }

    private var state: PageState {
        if service.isScanning { return .scanning }
        if service.isCleaning { return .cleaning }
        if cleaningFinished { return .finished }
        if hasResults { return .results }
        return .initial
    }

    private var hasResults: Bool {
        service.systemJunkTotalSize > 0 ||
        !service.duplicateGroups.isEmpty ||
        !service.similarPhotoGroups.isEmpty ||
        !service.largeFiles.isEmpty ||
        !service.userCacheFiles.isEmpty ||
        !service.systemCacheFiles.isEmpty ||
        !service.virusThreats.isEmpty ||
        service.hasAppUpdates ||
        !service.startupItems.isEmpty ||
        service.scanProgress >= 1
    }

    private var cleanupSize: Int64 {
        service.sizeFor(category: .systemJunk)
    }

    private var totalScannedSize: Int64 {
        cleanupSize + service.sizeFor(category: .virus)
    }

    private var cleanupFinishedScanning: Bool {
        [.systemJunk, .duplicates, .similarPhotos, .largeFiles]
            .allSatisfy(service.scannedCategories.contains)
    }

    private var protectionFinishedScanning: Bool {
        service.scannedCategories.contains(.virus)
    }

    private var speedFinishedScanning: Bool {
        service.scannedCategories.contains(.startupItems) &&
        service.scannedCategories.contains(.appUpdates)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                switch state {
                case .initial:
                    initialPage(height: proxy.size.height)
                        .offset(x: -15)
                case .scanning:
                    scanPage(isCleaning: false)
                        .offset(x: -15)
                case .results:
                    resultsPage
                        .offset(x: -15)
                case .cleaning:
                    scanPage(isCleaning: true)
                        .offset(x: -15)
                case .finished:
                    finishedPage
                        .offset(x: -15)
                }

                header
                    .offset(x: -15)
                actionButton

                if showDetailSheet {
                    Color.black.opacity(0.58)
                        .frame(width: proxy.size.width + 224, height: proxy.size.height)
                        .offset(x: -112)
                        .ignoresSafeArea()
                        .transition(.opacity)

                    CleanMyMacDetailsOverlay(
                        service: service,
                        loc: loc,
                        isPresented: $showDetailSheet,
                        initialCategory: detailCategory
                    )
                    .frame(width: min(778, proxy.size.width - 44), height: 489)
                    .offset(x: -15, y: -19)
                    .transition(.opacity.combined(with: .scale(scale: 0.995)))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .animation(.easeOut(duration: 0.16), value: showDetailSheet)
        }
        .confirmationDialog(
            localized("确认运行", "Confirm Run"),
            isPresented: $showCleanConfirmation
        ) {
            Button(localized("运行", "Run"), role: .destructive) {
                Task {
                    let result = await service.cleanAll()
                    if result.failed > 0 && !result.failedFiles.isEmpty {
                        failedFiles = result.failedFiles
                        showAdminRetry = true
                    } else {
                        cleaningFinished = true
                    }
                }
            }
            Button(localized("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(localized("清理选中的垃圾并运行优化任务。", "Clean selected junk and run optimization tasks."))
        }
        .alert(
            localized("检测到正在运行的应用", "Running Apps Detected"),
            isPresented: $showRunningAppsAlert
        ) {
            Button(localized("继续运行", "Continue"), role: .destructive) {
                showCleanConfirmation = true
            }
            Button(localized("取消", "Cancel"), role: .cancel) {}
        } message: {
            let names = detectedRunningApps.map(\.name).joined(separator: "、")
            Text(runningAppsMessage(names))
        }
        .alert(
            localized("部分文件需要管理员权限", "Some Files Require Admin Privileges"),
            isPresented: $showAdminRetry
        ) {
            Button(localized("使用管理员权限删除", "Delete with Admin"), role: .destructive) {
                Task {
                    _ = await service.cleanWithPrivileges(files: failedFiles)
                    failedFiles = []
                    cleaningFinished = true
                }
            }
            Button(localized("完成", "Done"), role: .cancel) {
                cleaningFinished = true
            }
        } message: {
            Text(permissionFailureMessage(failedFiles.count))
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(spacing: 0) {
            ZStack {
                if state != .initial {
                    Text(localized("智能扫描", "Smart Scan"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.58))
                }

                HStack {
                    if state == .results || state == .finished {
                        Button {
                            cleaningFinished = false
                            Task { service.resetAll() }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "chevron.left")
                                Text(localized("重新开始", "Start Over"))
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.58))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
            }
            .frame(height: 52)
            .padding(.horizontal, 18)

            Spacer()
        }
    }

    private func initialPage(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: max(65, height * 0.10))

            resourceImage("welcome")
                .frame(width: 565, height: min(310, height * 0.49))

            Spacer().frame(height: 25)

            Text(localized("欢迎使用Mac优化大师", "Welcome to MacOptimizer"))
                .font(.system(size: 35, weight: .regular))
                .foregroundColor(.white.opacity(0.96))

            Text(localized("开始全面、仔细扫描您的 Mac。", "Start a comprehensive, careful scan of your Mac."))
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.66))
                .padding(.top, 11)

            Spacer(minLength: 112)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func scanPage(isCleaning: Bool) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 81)

            Text(isCleaning
                 ? localized("正在运行任务...", "Running tasks...")
                 : localized("正在查看它...", "Checking it..."))
                .font(.system(size: 25, weight: .bold))
                .foregroundColor(.white.opacity(0.96))

            Text(isCleaning
                 ? localized("稍等片刻。马上就好。", "Just a moment. This will be quick.")
                 : localized("稍等片刻。我们都希望它易如反掌。", "Just a moment. We all want this to be effortless."))
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.48))
                .padding(.top, 8)

            Spacer().frame(height: 47)

            HStack(alignment: .top, spacing: 95) {
                replicaColumn(
                    kind: .cleanup,
                    status: cleanupStatus(isCleaning: isCleaning),
                    result: .none
                )
                replicaColumn(
                    kind: .protection,
                    status: protectionStatus(isCleaning: isCleaning),
                    result: .none
                )
                replicaColumn(
                    kind: .speed,
                    status: speedStatus(isCleaning: isCleaning),
                    result: .none
                )
            }

            Spacer(minLength: 100)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsPage: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 81)

            Text(localized("好了，我发现的内容都在这里。", "Okay, here's what I found."))
                .font(.system(size: 25, weight: .bold))
                .foregroundColor(.white.opacity(0.96))

            Text(localized(
                "保持您的 Mac 干净、安全、性能优化的所有任务正在等候。立即运行！",
                "Everything needed to keep your Mac clean, safe, and optimized is ready. Run it now!"
            ))
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.48))
                .padding(.top, 8)

            Spacer().frame(height: 47)

            HStack(alignment: .top, spacing: 95) {
                replicaColumn(
                    kind: .cleanup,
                    status: .complete,
                    result: cleanupSize > 0 ? .cleanup(cleanupSize) : .good
                )
                replicaColumn(
                    kind: .protection,
                    status: .complete,
                    result: service.virusThreats.isEmpty ? .good : .threats(service.virusThreats.count)
                )
                replicaColumn(
                    kind: .speed,
                    status: .complete,
                    result: .tasks(service.startupItems.count)
                )
            }

            Spacer(minLength: 100)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var finishedPage: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 81)

            Text(localized("做得不错！", "Nice work!"))
                .font(.system(size: 25, weight: .bold))
                .foregroundColor(.white.opacity(0.96))

            Text(localized("您的 Mac 状态很好。", "Your Mac is in great shape."))
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.48))
                .padding(.top, 8)

            Spacer().frame(height: 47)

            HStack(alignment: .top, spacing: 95) {
                replicaColumn(kind: .cleanup, status: .complete, result: .none)
                replicaColumn(kind: .protection, status: .complete, result: .none)
                replicaColumn(kind: .speed, status: .complete, result: .none)
            }

            Spacer(minLength: 100)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    fileprivate enum ColumnKind {
        case cleanup, protection, speed

        var resource: String {
            switch self {
            case .cleanup: return "clean-up.866fafd0"
            case .protection: return "zhiwendunpai_2026"
            case .speed: return "smart-scan.2f4ddf59"
            }
        }

        var imageSize: CGSize {
            switch self {
            case .cleanup: return CGSize(width: 178, height: 178)
            case .protection: return CGSize(width: 270, height: 270)
            case .speed: return CGSize(width: 180, height: 180)
            }
        }

        var imageYOffset: CGFloat {
            switch self {
            case .cleanup: return 0
            case .protection: return -10
            case .speed: return -5
            }
        }

        var color: Color {
            switch self {
            case .cleanup: return Color(red: 0.30, green: 0.82, blue: 0.94)
            case .protection: return Color(red: 0.27, green: 0.84, blue: 0.54)
            case .speed: return Color(red: 0.91, green: 0.42, blue: 0.70)
            }
        }
    }

    private enum ColumnStatus {
        case pending, active, complete
    }

    private enum ColumnResult {
        case none, cleanup(Int64), good, threats(Int), tasks(Int)
    }

    private func replicaColumn(kind: ColumnKind, status: ColumnStatus, result: ColumnResult) -> some View {
        let showsResult = !isEmptyResult(result)
        let displaySize = columnImageSize(kind, showsResult: showsResult)

        return VStack(spacing: 0) {
            resourceImage(kind.resource)
                .frame(width: displaySize.width, height: displaySize.height)
                .offset(y: kind.imageYOffset + (showsResult ? resultImageYOffset(kind) : 0))
                .modifier(ReplicaIconMotion(kind: kind, active: status == .active))
                .frame(height: showsResult ? 201 : 230)

            HStack(spacing: 6) {
                if status == .complete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 0.35, green: 0.88, blue: 0.94))
                }

                Text(columnTitle(kind))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white.opacity(0.94))

                if kind == .protection {
                    Text("▰ moonlock")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.90))
                }
            }
            .frame(height: 22)

            Text(columnDescription(kind, status: status))
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.46))
                .lineLimit(1)
                .padding(.top, 4)

            resultView(result, color: kind.color, kind: kind)
                .padding(.top, showsResult ? 16 : 8)
        }
        .frame(width: 185)
    }

    private func isEmptyResult(_ result: ColumnResult) -> Bool {
        if case .none = result { return true }
        return false
    }

    private func columnImageSize(_ kind: ColumnKind, showsResult: Bool) -> CGSize {
        guard showsResult else { return kind.imageSize }
        switch kind {
        case .cleanup: return CGSize(width: 142, height: 142)
        case .protection: return CGSize(width: 172, height: 172)
        case .speed: return CGSize(width: 145, height: 145)
        }
    }

    private func resultImageYOffset(_ kind: ColumnKind) -> CGFloat {
        switch kind {
        case .cleanup: return 8
        case .protection, .speed: return 15
        }
    }

    @ViewBuilder
    private func resultView(_ result: ColumnResult, color: Color, kind: ColumnKind) -> some View {
        switch result {
        case .none:
            if service.isScanning {
                if columnIsActive(kind) {
                    Text(service.currentScanPath.isEmpty ? " " : service.currentScanPath)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.34))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(width: 185)
                } else {
                    Text(columnWaitingText(kind))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.34))
                }
            }
        case .cleanup(let size):
            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    let pair = formattedSizeParts(size)
                    Text(pair.value)
                        .font(.system(size: 37, weight: .ultraLight))
                    Text(pair.unit)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(color)

                Button {
                    detailCategory = .systemJunk
                    showDetailSheet = true
                } label: {
                    Text(localized("查看详情...", "View Details..."))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(red: 0.42, green: 0.88, blue: 0.98))
                        .padding(.horizontal, 12)
                        .frame(height: 25)
                        .background(Color.black.opacity(0.27), in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
            }
        case .good:
            VStack(spacing: 7) {
                Text(localized("好", "Good"))
                    .font(.system(size: 37, weight: .ultraLight))
                    .foregroundColor(color)
                Text(localized("没有找到威胁", "No threats found"))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.38))
            }
        case .threats(let count):
            VStack(spacing: 7) {
                Text("\(count)")
                    .font(.system(size: 37, weight: .ultraLight))
                    .foregroundColor(.red.opacity(0.90))
                Text(localized("个威胁", "threats"))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.38))
            }
        case .tasks(let count):
            VStack(spacing: 7) {
                Text("\(count)")
                    .font(.system(size: 37, weight: .ultraLight))
                    .foregroundColor(.white.opacity(0.68))
                Text(localized("个任务可运行", "tasks can be run"))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.38))
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        CleanMyMacBottomActionSlot {
            switch state {
            case .initial:
                orbButton(title: localized("扫描", "Scan"), style: .scan) {
                    Task { await service.scanAll() }
                }
            case .scanning:
                CleanMyMacBottomActionCluster {
                    orbButton(title: localized("停止", "Stop"), style: .stop) {
                        service.stopScanning()
                    }
                } accessory: {
                    Text(ByteCountFormatter.string(fromByteCount: totalScannedSize, countStyle: .file))
                        .font(.system(size: 17, weight: .light))
                        .foregroundColor(.white.opacity(0.72))
                }
            case .results:
                orbButton(title: localized("运行", "Run"), style: .run) {
                    let selectedFiles = service.getAllSelectedFiles()
                    detectedRunningApps = service.checkRunningApps(for: selectedFiles)
                    if detectedRunningApps.isEmpty {
                        showCleanConfirmation = true
                    } else {
                        showRunningAppsAlert = true
                    }
                }
            case .cleaning:
                orbButton(title: localized("停止", "Stop"), style: .stop) {
                    service.stopCleaning()
                }
            case .finished:
                EmptyView()
            }
        }
    }

    private enum OrbStyle { case scan, stop, run }

    private func orbButton(title: String, style: OrbStyle, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            CleanMyMacActionOrb(
                title: title,
                gradient: orbGradient(style),
                glowColor: orbGlow(style),
                ringColor: orbRing(style)
            )
        }
        .buttonStyle(.plain)
    }

    private func orbGradient(_ style: OrbStyle) -> LinearGradient {
        switch style {
        case .scan:
            return LinearGradient(colors: [Color(red: 0.51, green: 0.47, blue: 0.65), Color(red: 0.37, green: 0.42, blue: 0.62)], startPoint: .top, endPoint: .bottom)
        case .stop:
            return LinearGradient(colors: [Color(red: 0.64, green: 0.31, blue: 0.58), Color(red: 0.44, green: 0.29, blue: 0.52)], startPoint: .top, endPoint: .bottom)
        case .run:
            return LinearGradient(colors: [Color(red: 0.50, green: 0.42, blue: 0.67), Color(red: 0.36, green: 0.36, blue: 0.58)], startPoint: .top, endPoint: .bottom)
        }
    }

    private func orbGlow(_ style: OrbStyle) -> Color {
        style == .run ? Color.cyan : Color(red: 0.66, green: 0.35, blue: 0.84)
    }

    private func orbRing(_ style: OrbStyle) -> Color {
        style == .run ? Color(red: 0.28, green: 0.86, blue: 0.98) : Color.white.opacity(0.48)
    }

    private func columnTitle(_ kind: ColumnKind) -> String {
        switch kind {
        case .cleanup: return localized("清理", "Cleanup")
        case .protection: return localized("保护", "Protection")
        case .speed: return localized("速度", "Speed")
        }
    }

    private func columnDescription(_ kind: ColumnKind, status: ColumnStatus) -> String {
        if state == .finished {
            switch kind {
            case .cleanup: return localized("不需要的垃圾已移除", "Unneeded junk removed")
            case .protection: return localized("潜在问题已解决", "Potential issues resolved")
            case .speed: return localized("Mac 的性能达到极致", "Your Mac is performing at its best")
            }
        }

        if state == .cleaning {
            switch (kind, status) {
            case (.cleanup, .active):
                return localized("正在清理系统…", "Cleaning your system…")
            case (.cleanup, .complete):
                return localized("不需要的垃圾已移除", "Unneeded junk removed")
            case (.protection, .active):
                return localized("正在保护系统…", "Protecting your system…")
            case (.protection, .complete):
                return localized("潜在问题已解决", "Potential issues resolved")
            case (.speed, .active):
                return localized("正在优化您的系统...", "Optimizing your system...")
            case (.speed, .complete):
                return localized("Mac 的性能达到极致", "Your Mac is performing at its best")
            default:
                break
            }
        }

        if state == .scanning && status != .complete {
            switch kind {
            case .cleanup: return localized("正在查找不需要的文件...", "Finding unwanted files...")
            case .protection: return localized("正在确定潜在威胁...", "Determining potential threats...")
            case .speed: return localized("定义合适的任务...", "Defining suitable tasks...")
            }
        }

        switch kind {
        case .cleanup: return localized("移除不需要的垃圾", "Remove unwanted junk")
        case .protection: return localized("消除潜在威胁", "Eliminate potential threats")
        case .speed: return localized("提升系统性能", "Improve system performance")
        }
    }

    private func columnWaitingText(_ kind: ColumnKind) -> String {
        guard kind != .cleanup else { return "" }
        return localized("正在等待...", "Waiting...")
    }

    private func columnIsActive(_ kind: ColumnKind) -> Bool {
        switch kind {
        case .cleanup:
            return [.systemJunk, .duplicates, .similarPhotos, .largeFiles].contains(service.currentCategory)
        case .protection:
            return service.currentCategory == .virus
        case .speed:
            return [.startupItems, .performanceApps, .appUpdates].contains(service.currentCategory)
        }
    }

    private func cleanupStatus(isCleaning: Bool) -> ColumnStatus {
        if isCleaning {
            guard let category = service.cleaningCurrentCategory else { return .pending }
            if [.systemJunk, .duplicates, .similarPhotos, .largeFiles].contains(category) { return .active }
            return .complete
        }
        if columnIsActive(.cleanup) { return .active }
        return cleanupFinishedScanning ? .complete : .pending
    }

    private func protectionStatus(isCleaning: Bool) -> ColumnStatus {
        if isCleaning {
            guard let category = service.cleaningCurrentCategory else { return .pending }
            if category == .virus { return .active }
            if [.startupItems, .performanceApps, .appUpdates].contains(category) { return .complete }
            return .pending
        }
        if columnIsActive(.protection) { return .active }
        return protectionFinishedScanning ? .complete : .pending
    }

    private func speedStatus(isCleaning: Bool) -> ColumnStatus {
        if isCleaning {
            return [.startupItems, .performanceApps, .appUpdates].contains(service.cleaningCurrentCategory) ? .active : .pending
        }
        if columnIsActive(.speed) { return .active }
        return speedFinishedScanning ? .complete : .pending
    }

    private func formattedSizeParts(_ bytes: Int64) -> (value: String, unit: String) {
        let text = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        let pieces = text.split(separator: " ", maxSplits: 1).map(String.init)
        return (pieces.first ?? "0", pieces.count > 1 ? pieces[1] : "")
    }

    private func resourceImage(_ name: String) -> some View {
        Group {
            if let url = Bundle.main.url(forResource: name, withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "questionmark.square.dashed")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.white.opacity(0.35))
            }
        }
    }

    private func localized(_ chinese: String, _ english: String) -> String {
        loc.text(chinese, english)
    }

    private func runningAppsMessage(_ names: String) -> String {
        loc.text(
            simplifiedChinese: "以下应用正在使用待处理的文件：\(names)",
            traditionalChinese: "以下應用程式正在使用待處理的檔案：\(names)",
            english: "These apps are using files selected for processing: \(names)",
            japanese: "次のアプリが処理対象のファイルを使用しています：\(names)",
            korean: "다음 앱에서 처리할 파일을 사용 중입니다: \(names)",
            russian: "Эти приложения используют выбранные файлы: \(names)"
        )
    }

    private func permissionFailureMessage(_ count: Int) -> String {
        loc.text(
            simplifiedChinese: "有 \(count) 个文件因权限不足无法删除。",
            traditionalChinese: "有 \(count) 個檔案因權限不足而無法刪除。",
            english: "\(count) files could not be deleted due to permissions.",
            japanese: "権限がないため \(count) 個のファイルを削除できませんでした。",
            korean: "권한이 없어 파일 \(count)개를 삭제하지 못했습니다.",
            russian: "Не удалось удалить файлов: \(count). Недостаточно прав."
        )
    }
}

private struct ReplicaIconMotion: ViewModifier {
    let kind: SmartCleanerReplicaView.ColumnKind
    let active: Bool
    @State private var phase = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(active && phase ? 1.025 : 1)
            .rotationEffect(active && kind == .speed ? .degrees(phase ? 2.5 : -2.5) : .zero)
            .animation(active ? .easeInOut(duration: 0.65).repeatForever(autoreverses: true) : .default, value: phase)
            .onAppear { phase = active }
            .onChange(of: active) { phase = $0 }
    }
}
