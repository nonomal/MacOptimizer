import SwiftUI
import AppKit
import AVFoundation

struct SpaceLensView: View {
    @ObservedObject private var scanner = ScanServiceManager.shared.spaceLensScanner
    @State private var viewState: Int = 0 // 0: Landing, 1: Scanning, 2: Results, 3: Cleanup Results
    
    // UI State
    @State private var navigationStack: [FileNode] = []
    @State private var forwardNavigationStack: [FileNode] = []
    @State private var currentNode: FileNode?
    @State private var focusedNodeID: UUID?
    @State private var loadingNodeIDs: Set<UUID> = []
    
    // Selection for landing page
    @State private var selectedDiskPath: URL = FileManager.default.homeDirectoryForCurrentUser
    @State private var selectedDiskName: String = NSUserName()
    @State private var showDiskPicker = false
    @State private var mountedVolumeURLs: [URL] = []
    
    // Remove Functionality
    @State private var showRemoveConfirmation = false
    @State private var itemsToRemove: [FileNode] = []
    @State private var cleanupResults: (success: Int, failed: Int, size: Int64)? = nil
    @State private var failedFiles: [FailedFileInfo] = []
    
    @ObservedObject private var loc = LocalizationManager.shared
    
    // Audio
    @State private var audioPlayer: AVAudioPlayer?
    
    // Selection Stats
    @State private var showSelectedItemsPopover = false
    
    var selectedSize: Int64 {
        guard let current = currentNode else { return 0 }
        return current.children.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
    
    var selectedItems: [FileNode] {
        guard let current = currentNode else { return [] }
        return current.children.filter { $0.isSelected }
    }
    
    var body: some View {
        Group {
            if viewState == 0 {
                landingView
            } else if viewState == 1 {
                scanningView
            } else if viewState == 2 {
                resultsView
            } else if viewState == 3 {
                // Show cleanup results
                if let results = cleanupResults {
                    if failedFiles.isEmpty {
                        CleanupResultsView(
                            cleanedSize: results.size,
                            cleanedCount: results.success,
                            recommendations: [],
                            onDismiss: {
                                resetToLanding()
                            }
                        )
                    } else {
                        CleanupDetailResultsView(
                            cleanedSize: results.size,
                            cleanedCount: results.success,
                            failedFiles: failedFiles,
                            failedCount: results.failed,
                            totalAttempted: results.success + results.failed,
                            onDismiss: {
                                resetToLanding()
                            }
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: refreshMountedVolumes)
    }
    
    // MARK: - Landing View
    var landingView: some View {
        ZStack {
            HStack(alignment: .top, spacing: 25) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(loc.text("空间透镜", "Space Lens"))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)

                    Text(loc.text("对文件夹和文件进行视觉大小比较，方便快速清理。", "Visually compare folders and files for quick cleanup."))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.72))
                        .padding(.top, 10)

                    VStack(alignment: .leading, spacing: 79) {
                        featureRow(
                            image: "space_lens_benefit_overview",
                            title: loc.text("即时尺寸概览", "Instant Size Overview"),
                            desc: loc.text("浏览存储空间，同时查看什么内容占据最多空间。", "Browse storage and see what takes the most space.")
                        )

                        featureRow(
                            image: "space_lens_benefit_decision",
                            title: loc.text("快速决策", "Quick Decisions"),
                            desc: loc.text("不浪费时间检查您要删除内容的大小。", "No time wasted checking sizes before deletion.")
                        )
                    }
                    .padding(.top, 40)

                    diskSelectorCard
                        .padding(.top, 48)
                }
                .frame(width: 320, alignment: .leading)

                resourceImage("space_lens_module")
                    .frame(width: 350, height: 350)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, 98)
            .padding(.top, 132)
            
            // Bottom Floating Scan Button
            CleanMyMacBottomActionSlot {
                CircularActionButton(
                    title: loc.text(
    simplifiedChinese: "扫描",
    traditionalChinese: "掃描",
    english: "Scan",
    japanese: "スキャン",
    korean: "스캔",
    russian: "Сканировать"
),
                    gradient: GradientStyles.spaceLens,
                    action: startScan
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Feature Row Helper
    private func featureRow(image: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 18) {
            resourceImage(image)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func resourceImage(_ name: String) -> some View {
        if let path = Bundle.main.path(forResource: name, ofType: "png"),
           let image = NSImage(contentsOfFile: path) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "circle")
                .resizable()
                .scaledToFit()
                .foregroundColor(.white.opacity(0.65))
        }
    }
    
    // MARK: - Disk Selector
    private var diskSelectorCard: some View {
        Button {
            refreshMountedVolumes()
            showDiskPicker.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: selectedDiskPath.path))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        // 显示磁盘名称和容量
                        Text(diskDisplayName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    
                    // 显示已使用空间
                    Text(diskUsageText)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.52))
                }
                
                Spacer()
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .frame(width: 319, height: 57)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.025))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.30), lineWidth: 0.7)
                    )
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showDiskPicker, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(mountedVolumeURLs, id: \.path) { volumeURL in
                    diskChoice(
                        title: volumeName(for: volumeURL),
                        subtitle: volumeUsageText(for: volumeURL),
                        url: volumeURL
                    ) {
                        selectedDiskPath = volumeURL
                        selectedDiskName = volumeName(for: volumeURL)
                    }
                }

                Divider()

                diskChoice(
                    title: NSUserName(),
                    subtitle: loc.text("您的主文件夹", "Your Home Folder"),
                    url: FileManager.default.homeDirectoryForCurrentUser
                ) {
                    selectedDiskPath = FileManager.default.homeDirectoryForCurrentUser
                    selectedDiskName = NSUserName()
                }

                Divider()

                Button {
                    showDiskPicker = false
                    selectFolder()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.badge.plus")
                            .frame(width: 18)
                        Text(loc.text("选择文件夹…", "Select Folder…"))
                            .font(.system(size: 12))
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 30)
                }
                .buttonStyle(.plain)
            }
            .padding(8)
            .frame(width: 245)
            .onAppear(perform: refreshMountedVolumes)
        }
        .frame(width: 319, height: 57)
    }

    private func diskChoice(
        title: String,
        subtitle: String,
        url: URL,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            showDiskPicker = false
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelectedScanLocation(url) ? "checkmark" : "")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 12)

                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 6)
            .frame(height: 38)
        }
        .buttonStyle(.plain)
    }

    private func refreshMountedVolumes() {
        let keys: Set<URLResourceKey> = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeIsLocalKey,
            .volumeIsInternalKey,
            .volumeIsReadOnlyKey
        ]
        let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(keys),
            options: [.skipHiddenVolumes]
        ) ?? []

        var seenPaths: Set<String> = []
        mountedVolumeURLs = volumes
            .map(\.standardizedFileURL)
            .filter { seenPaths.insert($0.path).inserted }
            .sorted { left, right in
                if left.path == "/" { return true }
                if right.path == "/" { return false }

                let leftValues = try? left.resourceValues(forKeys: keys)
                let rightValues = try? right.resourceValues(forKeys: keys)
                let leftInternal = leftValues?.volumeIsInternal ?? false
                let rightInternal = rightValues?.volumeIsInternal ?? false
                if leftInternal != rightInternal { return leftInternal }
                return volumeName(for: left).localizedStandardCompare(volumeName(for: right)) == .orderedAscending
            }

        if mountedVolumeURLs.isEmpty {
            mountedVolumeURLs = [URL(fileURLWithPath: "/")]
        }
    }

    private func volumeName(for url: URL) -> String {
        if let values = try? url.resourceValues(forKeys: [.volumeNameKey]),
           let name = values.volumeName,
           !name.isEmpty {
            return name
        }
        let displayName = FileManager.default.displayName(atPath: url.path)
        return displayName.isEmpty ? url.lastPathComponent : displayName
    }

    private func volumeUsageText(for url: URL) -> String {
        guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: url.path),
              let total = (attributes[.systemSize] as? NSNumber)?.int64Value,
              let free = (attributes[.systemFreeSize] as? NSNumber)?.int64Value else {
            return loc.text("磁盘宗卷", "Disk volume")
        }
        let used = max(0, total - free)
        return loc.text("已使用 \(formatBytes(used))，共 \(formatBytes(total))", "\(formatBytes(used)) used of \(formatBytes(total))")
    }

    private func isSelectedScanLocation(_ url: URL) -> Bool {
        selectedDiskPath.standardizedFileURL.path == url.standardizedFileURL.path
    }
    
    // MARK: - Disk Info Helpers
    
    /// 获取磁盘空间信息
    private func getDiskSpaceInfo() -> (total: Int64, used: Int64, free: Int64)? {
        let fileManager = FileManager.default
        
        do {
            // 获取路径的文件系统属性
            let attributes = try fileManager.attributesOfFileSystem(forPath: selectedDiskPath.path)
            
            // 总空间
            let totalSpace = attributes[.systemSize] as? Int64 ?? 0
            // 可用空间
            let freeSpace = attributes[.systemFreeSize] as? Int64 ?? 0
            // 已使用空间
            let usedSpace = totalSpace - freeSpace
            
            return (total: totalSpace, used: usedSpace, free: freeSpace)
        } catch {
            print("Failed to get disk space info: \(error)")
            return nil
        }
    }
    
    /// 格式化字节为可读大小
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
    }
    
    /// 磁盘显示名称（包含真实容量）
    private var diskDisplayName: String {
        guard let diskInfo = getDiskSpaceInfo() else {
            // 如果获取失败，返回简单名称
            if selectedDiskPath == FileManager.default.homeDirectoryForCurrentUser {
                return selectedDiskName + " " + (loc.text("您的主文件夹", "Your Home"))
            } else {
                return selectedDiskName
            }
        }
        
        let totalSize = formatBytes(diskInfo.total)
        
        let isMountedVolume = mountedVolumeURLs.contains {
            $0.standardizedFileURL.path == selectedDiskPath.standardizedFileURL.path
        }
        return isMountedVolume ? "\(selectedDiskName): \(totalSize)" : selectedDiskName
    }
    
    /// 磁盘使用率（0.0 - 1.0）真实计算
    private var diskUsagePercentage: CGFloat {
        guard let diskInfo = getDiskSpaceInfo() else {
            return 0.5 // 默认 50%
        }
        
        guard diskInfo.total > 0 else {
            return 0.0
        }
        
        let percentage = CGFloat(diskInfo.used) / CGFloat(diskInfo.total)
        return min(max(percentage, 0.0), 1.0) // 确保在 0.0 - 1.0 范围内
    }
    
    /// 磁盘使用文本（真实数据）
    private var diskUsageText: String {
        if selectedDiskPath == FileManager.default.homeDirectoryForCurrentUser {
            return loc.text("您的主文件夹", "Your Home Folder")
        }

        let isMountedVolume = mountedVolumeURLs.contains {
            $0.standardizedFileURL.path == selectedDiskPath.standardizedFileURL.path
        }
        if !isMountedVolume {
            return (selectedDiskPath.path as NSString).abbreviatingWithTildeInPath
        }

        guard let diskInfo = getDiskSpaceInfo() else {
            return loc.text("无法获取空间信息", "Unable to get space info")
        }
        
        let usedSize = formatBytes(diskInfo.used)
        
        return loc.text("已使用 \(usedSize)", "Used \(usedSize)")
    }
    

    // MARK: - Scanning View
    var scanningView: some View {
        ZStack {
            VStack {
                Spacer()
                
                // Pulsating Planet
                ZStack {
                    if let imagePath = Bundle.main.path(forResource: "kongjianshentou", ofType: "png"),
                       let nsImage = NSImage(contentsOfFile: imagePath) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 300, height: 300)
                            .scaleEffect(scanner.isScanning ? 1.05 : 1.0)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: scanner.isScanning)
                    }
                }
                // Scanning Status Text
                Text(loc.text("构建您的存储图...", "Building your storage map..."))
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(.top, 40)
                
                Text(scanner.currentPath)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                    .frame(width: 500)
                    .padding(.top, 8)
                
                Spacer()
                
                // Stop Button & Size
                HStack(spacing: 20) {
                    Button(action: stopScan) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                .frame(width: 80, height: 80)
                            
                            // Progress Ring
                            Circle()
                                .trim(from: 0, to: scanner.scanProgress)
                                .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))
                            
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 70, height: 70)
                            
                            Text(loc.text(
    simplifiedChinese: "停止",
    traditionalChinese: "停止",
    english: "Stop",
    japanese: "停止",
    korean: "정지",
    russian: "Остановить"
))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Text(ByteCountFormatter.string(fromByteCount: scanner.totalSize, countStyle: .file))
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.bottom, 60)
            }
            .onChange(of: scanner.rootNode) { newNode in
                if let root = newNode {
                    self.currentNode = root
                    self.navigationStack = []
                    self.forwardNavigationStack = []
                    self.focusedNodeID = root.children.first?.id
                    
                    // Play sound and wait before showing results
                    playScanCompleteSound {
                        withAnimation {
                            self.viewState = 2
                        }
                    }
                }
            }
        }
    }
    
    func playScanCompleteSound(completion: @escaping () -> Void) {
        guard let soundURL = Bundle.main.url(forResource: "CleanDidFinish", withExtension: "m4a") else {
            completion()
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.play()
            
            // Wait for duration
            let duration = audioPlayer?.duration ?? 0
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                completion()
            }
        } catch {
            print("Failed to play sound: \(error)")
            completion()
        }
    }
    
    // MARK: - Results View
    var resultsView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    resultsDirectoryPane
                        .frame(width: 300)

                    if let node = currentNode {
                        ZStack {
                            packedBubbleChart(
                                for: node,
                                size: CGSize(
                                    width: max(1, geometry.size.width - 300),
                                    height: max(1, geometry.size.height - 52)
                                )
                            )

                            if loadingNodeIDs.contains(node.id) {
                                directoryLoadingOverlay
                            }
                        }
                    }
                }
                .padding(.top, 52)

                resultsHeader

                CleanMyMacBottomActionSlot {
                    CleanMyMacBottomActionCluster(accessoryOffset: CGSize(width: 82, height: 0)) {
                        Button(action: prepareForRemoval) {
                            CleanMyMacActionOrb(
                                title: loc.text("移除", "Remove"),
                                gradient: LinearGradient(
                                    colors: [Color.white.opacity(selectedSize == 0 ? 0.04 : 0.14), Color.black.opacity(0.12)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                glowColor: Color(red: 0.31, green: 0.84, blue: 0.76),
                                ringColor: Color(red: 0.31, green: 0.84, blue: 0.76),
                                disabled: selectedSize == 0
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedSize == 0)
                    } accessory: {
                        if selectedSize > 0 {
                            Text(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.72))
                        }
                    }
                }
            }
            .overlay {
                if showRemoveConfirmation {
                    RemoveConfirmationView(
                        items: itemsToRemove,
                        onCancel: {
                            showRemoveConfirmation = false
                        },
                        onConfirm: {
                            deleteSelectedItems()
                        }
                    )
                }
            }
        }
    }

    private var resultsHeader: some View {
        HStack {
            Button {
                resetToLanding()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text(loc.text("重新开始", "Start Over"))
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.68))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(loc.text("空间透镜", "Space Lens"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.58))

            Spacer()

            Color.clear.frame(width: 74, height: 1)
        }
        .padding(.horizontal, 17)
        .frame(height: 52)
    }

    private var resultsDirectoryPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                compactNavigationButton("chevron.left", disabled: navigationStack.isEmpty, action: goBack)
                compactNavigationButton("chevron.right", disabled: forwardNavigationStack.isEmpty, action: goForward)

                breadcrumbPath
            }
            .padding(.horizontal, 10)
            .frame(height: 42)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 3) {
                    ForEach(currentNode?.children ?? []) { child in
                        FileListRow(
                            node: child,
                            isFocused: focusedNodeID == child.id,
                            isRemovable: isRemovableNode(child),
                            onFocus: { focusedNodeID = child.id },
                            onEnter: { enterNode(child) },
                            onIgnore: { ignoreNode(child) }
                        )
                    }
                }
                .padding(.horizontal, 9)
                .padding(.bottom, 100)
            }
            .overlay {
                if let node = currentNode, loadingNodeIDs.contains(node.id) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white.opacity(0.78))
                }
            }
        }
    }

    private var breadcrumbPath: some View {
        let path = navigationStack + (currentNode.map { [$0] } ?? [])

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(path.enumerated()), id: \.element.id) { index, node in
                    Button {
                        navigateToBreadcrumb(index, in: path)
                    } label: {
                        HStack(spacing: 4) {
                            if let icon = iconForFile(node) {
                                Image(nsImage: icon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 17, height: 17)
                            }

                            Text(FileManager.default.displayName(atPath: node.url.path))
                                .font(.system(size: 12, weight: index == path.count - 1 ? .semibold : .medium))
                                .foregroundColor(.white.opacity(index == path.count - 1 ? 0.90 : 0.66))
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)

                    if index < path.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.white.opacity(0.34))
                    }
                }
            }
            .padding(.leading, 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var directoryLoadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.10)

            VStack(spacing: 9) {
                ProgressView()
                    .controlSize(.regular)
                    .tint(.white)
                Text(loc.text("正在读取文件夹…", "Loading folder…"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.72))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func compactNavigationButton(_ symbol: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(disabled ? 0.20 : 0.64))
                .frame(width: 23, height: 23)
                .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func isRemovableNode(_ node: FileNode) -> Bool {
        let protectedNames: Set<String> = [
            "Library", "Downloads", "Movies", "Pictures", "Documents",
            "Applications", "Desktop", "Music", "Public"
        ]
        return !protectedNames.contains(node.name)
    }

    private struct BubblePlacement {
        let node: FileNode
        var center: CGPoint
        let radius: CGFloat
    }

    private func packedBubbleChart(for node: FileNode, size: CGSize) -> some View {
        let placements = packedPlacements(for: Array(node.children.prefix(14)), in: size)
        let diameter = max(1, min(size.width - 30, size.height - 28))

        return ZStack {
            Circle()
                .fill(Color.black.opacity(0.14))
                .overlay(Circle().stroke(Color.black.opacity(0.13), lineWidth: 21))
                .overlay(Circle().stroke(Color.white.opacity(0.045), lineWidth: 1))
                .frame(width: diameter, height: diameter)

            ForEach(placements, id: \.node.id) { placement in
                Button {
                    if placement.node.isDirectory {
                        enterNode(placement.node)
                    } else {
                        focusedNodeID = placement.node.id
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.29, green: 0.84, blue: 0.78).opacity(0.30))
                            .overlay {
                                Circle().stroke(
                                    focusedNodeID == placement.node.id
                                        ? Color(red: 0.65, green: 0.96, blue: 0.85).opacity(0.78)
                                        : Color.white.opacity(0.035),
                                    lineWidth: focusedNodeID == placement.node.id ? 5 : 1
                                )
                            }

                        VStack(spacing: 5) {
                            if let icon = iconForFile(placement.node) {
                                Image(nsImage: icon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(
                                        width: min(placement.radius * 0.82, 67),
                                        height: min(placement.radius * 0.82, 67)
                                    )
                            }

                            if focusedNodeID == placement.node.id, placement.radius >= 64 {
                                Text(placement.node.name)
                                    .font(.system(size: min(13, placement.radius * 0.10), weight: .semibold))
                                    .foregroundColor(.white.opacity(0.94))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(maxWidth: placement.radius * 1.55)

                                Text(placement.node.formattedSize)
                                    .font(.system(size: min(12, placement.radius * 0.09), weight: .medium))
                                    .foregroundColor(.white.opacity(0.82))
                            }
                        }
                    }
                    .frame(width: placement.radius * 2, height: placement.radius * 2)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .position(placement.center)
                .help("\(placement.node.name)  \(placement.node.formattedSize)")
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private func packedPlacements(for nodes: [FileNode], in size: CGSize) -> [BubblePlacement] {
        guard !nodes.isEmpty else { return [] }

        let diameter = max(1, min(size.width - 30, size.height - 28))
        let outerRadius = diameter / 2 - 17
        let chartCenter = CGPoint(x: size.width / 2, y: size.height / 2 - 3)
        let maximumSize = max(nodes.first?.size ?? 1, 1)
        let anchors: [CGPoint] = [
            CGPoint(x: -0.18, y: 0.04), CGPoint(x: 0.36, y: 0.06),
            CGPoint(x: 0.08, y: -0.46), CGPoint(x: 0.12, y: 0.48),
            CGPoint(x: -0.44, y: -0.42), CGPoint(x: 0.51, y: -0.40),
            CGPoint(x: -0.45, y: 0.43), CGPoint(x: 0.52, y: 0.43),
            CGPoint(x: -0.62, y: -0.10), CGPoint(x: 0.64, y: -0.10),
            CGPoint(x: -0.62, y: 0.20), CGPoint(x: 0.64, y: 0.19),
            CGPoint(x: -0.18, y: 0.68), CGPoint(x: 0.37, y: 0.66)
        ]

        var placements = nodes.enumerated().map { index, child -> BubblePlacement in
            let ratio = max(0, Double(child.size) / Double(maximumSize))
            let radius = max(outerRadius * 0.055, outerRadius * 0.36 * CGFloat(pow(ratio, 0.30)))
            let anchor = anchors[min(index, anchors.count - 1)]
            return BubblePlacement(
                node: child,
                center: CGPoint(
                    x: chartCenter.x + anchor.x * outerRadius,
                    y: chartCenter.y + anchor.y * outerRadius
                ),
                radius: radius
            )
        }

        for _ in 0..<90 {
            for left in placements.indices {
                for right in placements.indices where right > left {
                    let dx = placements[right].center.x - placements[left].center.x
                    let dy = placements[right].center.y - placements[left].center.y
                    let distance = max(sqrt(dx * dx + dy * dy), 0.1)
                    let required = placements[left].radius + placements[right].radius + 2
                    guard distance < required else { continue }
                    let push = (required - distance) / 2
                    let nx = dx / distance
                    let ny = dy / distance
                    placements[left].center.x -= nx * push
                    placements[left].center.y -= ny * push
                    placements[right].center.x += nx * push
                    placements[right].center.y += ny * push
                }
            }

            for index in placements.indices {
                let anchor = anchors[min(index, anchors.count - 1)]
                let target = CGPoint(
                    x: chartCenter.x + anchor.x * outerRadius,
                    y: chartCenter.y + anchor.y * outerRadius
                )
                placements[index].center.x += (target.x - placements[index].center.x) * 0.018
                placements[index].center.y += (target.y - placements[index].center.y) * 0.018

                let dx = placements[index].center.x - chartCenter.x
                let dy = placements[index].center.y - chartCenter.y
                let distance = max(sqrt(dx * dx + dy * dy), 0.1)
                let allowed = outerRadius - placements[index].radius
                if distance > allowed {
                    placements[index].center = CGPoint(
                        x: chartCenter.x + dx / distance * allowed,
                        y: chartCenter.y + dy / distance * allowed
                    )
                }
            }
        }
        return placements
    }
    
    // MARK: - Actions
    func startScan() {
        let path = selectedDiskPath
        Task {
            await scanner.scan(targetURL: path)
        }
        withAnimation {
            viewState = 1
        }
    }
    
    func stopScan() {
        scanner.stopScan()
        viewState = 0
    }
    
    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            self.selectedDiskPath = url
            self.selectedDiskName = url.lastPathComponent
        }
    }
    
    func enterNode(_ node: FileNode) {
        guard node.isDirectory else {
            focusedNodeID = node.id
            return
        }
        if let current = currentNode {
            navigationStack.append(current)
        }
        forwardNavigationStack.removeAll()
        activateNode(node)
    }
    
    func goBack() {
        guard let parent = navigationStack.popLast() else { return }
        if let current = currentNode {
            forwardNavigationStack.append(current)
        }
        activateNode(parent)
    }

    func goForward() {
        guard let next = forwardNavigationStack.popLast() else { return }
        if let current = currentNode {
            navigationStack.append(current)
        }
        activateNode(next)
    }

    private func navigateToBreadcrumb(_ index: Int, in path: [FileNode]) {
        guard path.indices.contains(index) else { return }
        navigationStack = Array(path.prefix(index))
        forwardNavigationStack = Array(path.dropFirst(index + 1).reversed())
        activateNode(path[index])
    }

    private func activateNode(_ node: FileNode) {
        currentNode = node
        focusedNodeID = node.children.first?.id

        guard !node.childrenLoaded, !loadingNodeIDs.contains(node.id) else { return }
        loadingNodeIDs.insert(node.id)

        Task {
            await scanner.loadChildren(for: node)
            await MainActor.run {
                loadingNodeIDs.remove(node.id)
                if currentNode?.id == node.id {
                    focusedNodeID = node.children.first?.id
                }
            }
        }
    }
    
    func iconForFile(_ node: FileNode?) -> NSImage? {
        guard let node = node else { return nil }
        return NSWorkspace.shared.icon(forFile: node.url.path)
    }
    
    // MARK: - Remove Logic
    func selectAllItems() {
        guard let current = currentNode else { return }
        for child in current.children {
            child.isSelected = true
        }
    }
    
    func deselectAllItems() {
        guard let current = currentNode else { return }
        for child in current.children {
            child.isSelected = false
        }
    }

    func ignoreNode(_ node: FileNode) {
        ScanResultIgnoreStore.shared.ignore(node.url)
        node.parent?.children.removeAll { $0.id == node.id }
        if currentNode?.id == node.id {
            goBack()
        }
    }
    
    func prepareForRemoval() {
        // Collect selected items from current node's children
        // We only support removing what is visible/selected in the list or the node itself?
        // Usually, deletion operates on the selected checkboxes in the list.
        guard let current = currentNode else { return }
        
        // Find visible children that are selected
        let selected = current.children.filter { $0.isSelected }
        
        if !selected.isEmpty {
            self.itemsToRemove = selected
            self.showRemoveConfirmation = true
        } else {
            // Maybe show a tooltip "Select items to remove"?
            print("No items selected")
        }
    }
    
    func deleteSelectedItems() {
        Task {
            let fileManager = FileManager.default
            var deletedIDs: Set<UUID> = []
            var deletedSize: Int64 = 0
            var failedDeletions: [FailedFileInfo] = []
            
            // First attempt: Try direct deletion
            for item in itemsToRemove {
                do {
                    try fileManager.removeItem(at: item.url)
                    deletedIDs.insert(item.id)
                    deletedSize += item.size
                    print("Deleted: \(item.url.path)")
                } catch {
                    print("Failed to delete \(item.url.path): \(error)")
                    // Track failed deletion for retry with admin privileges
                    failedDeletions.append(FailedFileInfo(
                        fileName: item.name,
                        filePath: item.url.path,
                        fileSize: item.size,
                        errorReason: error.localizedDescription
                    ))
                }
            }
            
            // Second attempt: If there are failures, try with admin privileges
            if !failedDeletions.isEmpty {
                let failedPaths = failedDeletions.map { $0.filePath }
                let adminSuccess = await deleteWithAdminPrivileges(paths: failedPaths)
                
                if adminSuccess {
                    // All admin deletions succeeded
                    let adminDeletedSize = failedDeletions.reduce(0) { $0 + $1.fileSize }
                    deletedSize += adminDeletedSize
                    
                    // Mark items as deleted by matching paths
                    for failedItem in failedDeletions {
                        if let matchingItem = itemsToRemove.first(where: { $0.url.path == failedItem.filePath }) {
                            deletedIDs.insert(matchingItem.id)
                        }
                    }
                    
                    failedDeletions.removeAll()
                }
            }
            
            // Update UI on main thread
            await MainActor.run {
                // Remove deleted nodes from current children
                if let current = currentNode {
                    current.children.removeAll { deletedIDs.contains($0.id) }
                    current.size -= deletedSize
                    if current.size < 0 { current.size = 0 } // Safety
                    
                    self.focusedNodeID = current.children.first?.id
                    
                    // Update total scanned size
                    scanner.totalSize -= deletedSize
                }
                
                // Store cleanup results
                self.cleanupResults = (
                    success: deletedIDs.count,
                    failed: failedDeletions.count,
                    size: deletedSize
                )
                self.failedFiles = failedDeletions
                
                // Dismiss confirmation and show results
                showRemoveConfirmation = false
                itemsToRemove = []
                
                // Play success sound and transition to results
                playScanCompleteSound {
                    withAnimation {
                        self.viewState = 3
                    }
                }
            }
        }
    }
    
    /// Attempts to delete files with admin privileges using AppleScript
    private func deleteWithAdminPrivileges(paths: [String]) async -> Bool {
        var safePaths: [String] = []
        
        // Validate paths for safety
        for path in paths {
            if !path.contains("..") && !path.isEmpty {
                safePaths.append(path)
            }
        }
        
        if safePaths.isEmpty {
            return false
        }
        
        // Build rm commands
        let rmCommands = safePaths.map { "rm -rf '\($0)'" }.joined(separator: "; ")
        
        let script = """
        do shell script "\(rmCommands)" with administrator privileges
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            return error == nil
        }
        
        return false
    }
    
    func resetToLanding() {
        viewState = 0
        navigationStack = []
        forwardNavigationStack = []
        currentNode = nil
        focusedNodeID = nil
        loadingNodeIDs.removeAll()
        cleanupResults = nil
        failedFiles = []
        scanner.stopScan()
    }
}

// MARK: - File List Row
struct FileListRow: View {
    @ObservedObject var node: FileNode
    let isFocused: Bool
    let isRemovable: Bool
    let onFocus: () -> Void
    let onEnter: () -> Void
    let onIgnore: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            if isRemovable {
                CleanMyMacSelectionButton(rowHeight: 55) {
                    node.isSelected.toggle()
                } indicator: {
                    if node.isSelected {
                        Circle()
                            .fill(Color(red: 0.32, green: 0.84, blue: 0.96))
                            .frame(width: 14, height: 14)
                            .overlay {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                            }
                    } else {
                        Circle()
                            .stroke(Color.white.opacity(0.46), lineWidth: 1)
                            .frame(width: 14, height: 14)
                    }
                }
            } else {
                Color.clear.frame(width: 44, height: 55)
            }

            let icon = NSWorkspace.shared.icon(forFile: node.url.path)
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 37, height: 37)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(node.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.90))
                    .lineLimit(1)

                if node.isDirectory {
                    Text("\(node.itemCount) \(LocalizationManager.shared.text("项", "items"))")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.42))
                }
            }

            Spacer(minLength: 4)

            Text(node.formattedSize)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.82))

            Button(action: onEnter) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(node.isDirectory ? 0.65 : 0.16))
                    .frame(width: 24, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(!node.isDirectory)
        }
        .padding(.leading, 1)
        .padding(.trailing, 4)
        .frame(height: 55)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isFocused ? Color.black.opacity(0.28) : Color.clear)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if node.isDirectory {
                onEnter()
            } else {
                onFocus()
            }
        }
        .scanResultContextMenu(
            isSelected: node.isSelected,
            displayName: node.name,
            url: node.url,
            onToggleSelection: {
                if isRemovable { node.isSelected.toggle() }
            },
            onIgnore: onIgnore
        )
    }
}
