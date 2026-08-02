import AppKit
import SwiftUI

/// Pixel-led reconstruction of CleanMyMac X's System Junk module.
struct SystemJunkReplicaView: View {
    @ObservedObject private var cleaner = ScanServiceManager.shared.junkCleaner
    @ObservedObject private var loc = LocalizationManager.shared

    @State private var showingDetails = false
    @State private var selectedCategoryID = "unusedDiskImages"
    @State private var searchText = ""
    @State private var sortBySize = true
    @State private var cleaningFinished = false
    @State private var cleanedAmount: Int64 = 0
    @State private var showAdminWarning = false
    @State private var wasScanning = false
    @State private var wasAnalyzing = false

    private enum PageState {
        case initial, scanning, results, cleaning, finished
    }

    private enum CheckState {
        case none, partial, all
    }

    private struct CategoryDescriptor: Identifiable {
        let id: String
        let type: JunkType?
        let zhTitle: String
        let enTitle: String
        let zhDescription: String
        let enDescription: String
        let symbol: String
        let colors: [Color]
    }

    private var state: PageState {
        if cleaner.isScanning { return .scanning }
        if cleaner.isCleaning { return .cleaning }
        if cleaningFinished { return .finished }
        if !cleaner.junkItems.isEmpty { return .results }
        return .initial
    }

    private var categories: [CategoryDescriptor] {
        [
            descriptor("unusedDiskImages", .unusedDiskImages, "不使用的磁盘镜像", "Unused Disk Images",
                       "磁盘镜像在 Mac 上最常见以 DMG 文件形式存在。在技术上，它们设计用于复制所有类型的物理驱动器的结构。结果，我们安装完软件后通常会留下许多不使用的 DMG。在这里，它们将被跟踪并被彻底移除。",
                       "Disk images most often exist as DMG files. After installing software, many unused images remain and can be removed.",
                       "externaldrive.fill", [.white, Color(red: 0.68, green: 0.77, blue: 0.84)]),
            descriptor("userCache", .userCache, "用户缓存文件", "User Cache Files",
                       "应用程序的缓存文件原本用来缩短开机时间，但最终会大量堆积，并导致无法正常运行或整体性能下降。",
                       "Application cache files speed up launch times, but can accumulate and reduce overall performance.",
                       "lamp.desk.fill", [.orange, Color(red: 0.92, green: 0.42, blue: 0.48)]),
            descriptor("downloads", .downloads, "下载", "Downloads",
                       "每当您下载文件时，它都会存储在您的 Mac 上。随着时间的推移，这些文件会累积并占用大量空间。考虑删除不完整的下载以及不再需要的文件。",
                       "Downloads accumulate over time and take up space. Review incomplete and unneeded files.",
                       "arrow.down", [.cyan, Color(red: 0.28, green: 0.50, blue: 0.88)]),
            descriptor("universalBinaries", .universalBinaries, "通用二进制文件", "Universal Binaries",
                       "Apple 自研处理器已经发布，开发者需要在自己的应用程序中使用两种代码版本。您的 Mac 只需要采用一种副本。",
                       "Universal applications contain code for multiple architectures. Your Mac only needs one copy.",
                       "circle.lefthalf.filled", [Color(red: 0.98, green: 0.63, blue: 0.43), Color(red: 0.31, green: 0.70, blue: 0.84)]),
            descriptor("systemCache", .systemCache, "系统缓存文件", "System Cache Files",
                       "系统应用程序会产生并保存大量的缓存文件。它们最终导致更长的开机时间，整体性能下降甚至有时会使功能失常。",
                       "System applications create caches that may slow startup and reduce performance.",
                       "sparkles", [.cyan, Color(red: 0.28, green: 0.48, blue: 0.87)]),
            descriptor("userLogs", .userLogs, "用户日志文件", "User Log Files",
                       "应用程序的活动会不断被捕捉并保存到众多日志文件中。一段时间之后，这些文件就会占用大量磁盘空间，却没有任何用处，尤其是那些旧日志。",
                       "Application activity is stored in log files that can grow over time, especially old logs.",
                       "doc.text.fill", [Color(red: 0.54, green: 0.65, blue: 0.86), Color(red: 0.31, green: 0.38, blue: 0.66)]),
            descriptor("systemLogs", .systemLogs, "系统日志文件", "System Log Files",
                       "系统应用程序和服务的活动会被采集并保存到各个日志文件中。这些日志文件仅可能对应用程序的开发调试有用。",
                       "System application and service activity is stored in logs that are mainly useful for debugging.",
                       "doc.badge.gearshape.fill", [Color(red: 0.55, green: 0.66, blue: 0.87), Color(red: 0.29, green: 0.36, blue: 0.63)]),
            descriptor("deletedUsers", .deletedUsers, "已删除用户", "Deleted Users",
                       "如果您曾经从 Mac 上删除了某个用户帐户，该用户的文件夹中可能仍然有残留数据。",
                       "Deleted user accounts may leave data behind that you can review and remove.",
                       "person.crop.circle.badge.xmark", [.gray, Color(red: 0.44, green: 0.36, blue: 0.61)]),
            descriptor("iosBackups", .iosBackups, "iOS 设备备份", "iOS Device Backups",
                       "所有 iOS 设备备份都储存在 Mac 上。您可以轻松移除旧备份，而且不丢失任何数据。",
                       "All iOS device backups are stored on your Mac. Old backups can be reviewed and removed.",
                       "iphone", [Color(red: 0.40, green: 0.61, blue: 0.86), Color(red: 0.32, green: 0.40, blue: 0.68)]),
            descriptor("oldUpdates", .oldUpdates, "旧更新", "Old Updates",
                       "部分应用程序因为有旧更新文件所以浪费了大量空间。您可以安全将其移除。",
                       "Old application update files can waste space and may be safely removed.",
                       "arrow.down.doc.fill", [Color(red: 0.84, green: 0.54, blue: 0.53), Color(red: 0.50, green: 0.40, blue: 0.66)]),
            descriptor("brokenLoginItems", .brokenLoginItems, "损坏的登录项", "Broken Login Items",
                       "在某些情况下，应用程序或服务被移除后，它的破损链接仍留在登录项中。",
                       "Broken links can remain in Login Items after an application or service is removed.",
                       "person.badge.minus", [Color(red: 0.83, green: 0.52, blue: 0.49), Color(red: 0.48, green: 0.38, blue: 0.64)]),
            descriptor("brokenPreferences", nil, "损坏的偏好设置", "Broken Preferences",
                       "应用程序的偏好设置文件可能会损坏，并导致程序行为失常。",
                       "Damaged preference files can cause applications to behave unexpectedly.",
                       "slider.horizontal.3", [.gray, Color(red: 0.43, green: 0.37, blue: 0.60)]),
            descriptor("xcodeJunk", .xcodeDerivedData, "Xcode 垃圾", "Xcode Junk",
                       "Xcode 会生成大量中间版本信息和项目索引。清理这些项目可以恢复空间。",
                       "Xcode generates build intermediates and indexes that can be removed to recover space.",
                       "hammer.fill", [Color(red: 0.36, green: 0.68, blue: 0.86), Color(red: 0.32, green: 0.39, blue: 0.66)]),
            descriptor("documentVersions", .documentVersions, "文稿版本", "Document Versions",
                       "许多应用程序会为正在操作的文稿创建多个版本。移除过期版本可以释放空间。",
                       "Many applications retain document versions. Removing obsolete versions frees space.",
                       "doc.on.doc.fill", [Color(red: 0.47, green: 0.65, blue: 0.85), Color(red: 0.35, green: 0.39, blue: 0.67)]),
            descriptor("languageFiles", .languageFiles, "语言文件", "Language Files",
                       "您可以移除应用程序内不需要的本地化语言包，从而节省磁盘空间。",
                       "Remove unneeded application localization packs to save disk space.",
                       "globe", [Color(red: 0.42, green: 0.70, blue: 0.78), Color(red: 0.36, green: 0.40, blue: 0.67)])
        ]
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                switch state {
                case .initial:
                    initialPage
                case .scanning:
                    scanningPage
                case .results:
                    if showingDetails { detailsPage } else { resultsPage }
                case .cleaning:
                    cleaningPage
                case .finished:
                    finishedPage
                }

                if state != .initial {
                    moduleHeader
                }

                bottomAction
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .onAppear {
            if !cleaner.junkItems.isEmpty, selectedDescriptor.type == nil {
                selectedCategoryID = firstPopulatedCategoryID
            }
        }
        .onReceive(cleaner.$isScanning) { scanning in
            if wasScanning && !scanning && !cleaner.junkItems.isEmpty {
                selectedCategoryID = firstPopulatedCategoryID
                applySmartSelection()
                playCompletionSound()
            }
            wasScanning = scanning
        }
        .onReceive(cleaner.$isAnalyzingRecommendations) { analyzing in
            if wasAnalyzing && !analyzing {
                applySmartSelection()
            }
            wasAnalyzing = analyzing
        }
        .alert(localized("部分文件需要管理员权限", "Some Files Require Admin Privileges"), isPresented: $showAdminWarning) {
            Button(localized("完成", "Done"), role: .cancel) { cleaningFinished = true }
        } message: {
            Text(localized("部分文件因权限不足无法删除。", "Some files could not be deleted because of insufficient privileges."))
        }
    }

    private var moduleHeader: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(localized("系统垃圾", "System Junk"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.58))

                HStack {
                    if state == .results || state == .finished {
                        Button {
                            if showingDetails {
                                showingDetails = false
                            } else {
                                cleaner.reset()
                                cleaningFinished = false
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "chevron.left")
                                Text(showingDetails ? localized("返回", "Back") : localized("重新开始", "Start Over"))
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.62))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    if showingDetails {
                        HStack(spacing: 7) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11, weight: .medium))
                            TextField(localized("搜索", "Search"), text: $searchText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.white.opacity(0.65))
                        .padding(.horizontal, 10)
                        .frame(width: 181, height: 27)
                        .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 7))
                    }
                }
            }
            .frame(height: 52)
            .padding(.horizontal, 12)

            Spacer()
        }
    }

    private var initialPage: some View {
        HStack(spacing: 68) {
            VStack(alignment: .leading, spacing: 0) {
                Text(localized("系统垃圾", "System Junk"))
                    .font(.system(size: 21, weight: .bold))
                    .foregroundColor(.white.opacity(0.94))

                Text(localized("清理您的系统来获得最大的性能和释放自由空间。", "Clean your system for maximum performance and free space."))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.67))
                    .padding(.top, 8)

                benefitRow(symbol: "waveform.path.ecg", title: localized("优化系统", "Optimize System"),
                           description: localized("移除临时文件以释放空间，提升 Mac 的性能。", "Remove temporary files to free space and improve performance."))
                    .padding(.top, 35)

                benefitRow(symbol: "capsule", title: localized("解决所有类型的错误", "Fix All Types of Errors"),
                           description: localized("删除各种可能会导致应用程序反应异常的破损项目。", "Delete broken items that may cause applications to behave unexpectedly."))
                    .padding(.top, 28)
            }
            .frame(width: 300, alignment: .leading)

            systemJunkImage(size: 270)
        }
        .offset(x: -8, y: -19)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func benefitRow(symbol: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .ultraLight))
                .foregroundColor(.white.opacity(0.37))
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.84))
                Text(description)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.47))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
        }
    }

    private var scanningPage: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 142)

            systemJunkImage(size: 224)

            Text(localized("正在分析系统…", "Analyzing System…"))
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white.opacity(0.94))
                .padding(.top, 25)

            Text(cleaner.currentScanningPath)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.27))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 500)
                .padding(.top, 8)

            Text(cleaner.currentScanningCategory)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.43))
                .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsPage: some View {
        HStack(spacing: 65) {
            systemJunkImage(size: 290)

            VStack(alignment: .leading, spacing: 0) {
                Text(localized("扫描完毕", "Scan Complete"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white.opacity(0.93))

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(formatBytes(moduleSelectedSize))
                        .font(.system(size: 39, weight: .ultraLight))
                        .foregroundColor(Color(red: 0.35, green: 0.84, blue: 0.96))
                    Text(localized("智能选择", "Smart Selection"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.44))
                }
                .padding(.top, 22)

                Text(localized("包括", "Includes"))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.53))
                    .padding(.top, 12)

                VStack(alignment: .leading, spacing: 7) {
                    ForEach(summaryCategories.prefix(5)) { category in
                        Text("•    \(title(category))")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.62))
                    }
                }
                .padding(.top, 8)

                HStack(spacing: 15) {
                    Button {
                        selectedCategoryID = firstPopulatedCategoryID
                        showingDetails = true
                    } label: {
                        Text(localized("查看项目", "Review Details"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(red: 0.41, green: 0.86, blue: 0.97))
                            .padding(.horizontal, 12)
                            .frame(height: 25)
                            .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)

                    Text(loc.text(
                        simplifiedChinese: "共发现 \(formatBytes(moduleTotalSize))",
                        traditionalChinese: "共發現 \(formatBytes(moduleTotalSize))",
                        english: "Found \(formatBytes(moduleTotalSize)) in total",
                        japanese: "合計 \(formatBytes(moduleTotalSize)) を検出",
                        korean: "총 \(formatBytes(moduleTotalSize)) 발견",
                        russian: "Всего найдено: \(formatBytes(moduleTotalSize))"
                    ))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.38))
                }
                .padding(.top, 31)
            }
            .frame(width: 285, alignment: .leading)
        }
        .offset(x: -5, y: -1)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var detailsPage: some View {
        HStack(spacing: 0) {
            categoryPane
                .frame(width: 410)

            Rectangle()
                .fill(Color.white.opacity(0.055))
                .frame(width: 1)

            itemPane
        }
        .padding(.top, 52)
    }

    private var categoryPane: some View {
        VStack(spacing: 0) {
            HStack {
                Button(anyItemsSelected ? localized("取消全选", "Deselect All") : localized("全选", "Select All")) {
                    setAllSelected(!anyItemsSelected)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.78))
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 5))

                Spacer()
                sortMenu
            }
            .padding(.horizontal, 10)
            .frame(height: 36)

            ScrollView(showsIndicators: true) {
                LazyVStack(spacing: 1) {
                    ForEach(categories) { category in
                        categoryRow(category)
                    }
                }
                .padding(.horizontal, 9)
            }

            Spacer(minLength: 45)
        }
    }

    private func categoryRow(_ category: CategoryDescriptor) -> some View {
        let items = items(for: category)
        let enabled = !items.isEmpty
        let selected = selectedCategoryID == category.id

        return ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: 32, height: 54)
                    .allowsHitTesting(false)

                Button {
                    selectedCategoryID = category.id
                } label: {
                    HStack(spacing: 11) {
                        categoryIcon(category, enabled: enabled)
                        Text(title(category))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(enabled ? 0.84 : 0.25))
                        Spacer()
                        if enabled {
                            Text(formatBytes(totalSize(items)))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.76))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }

            if enabled {
                CleanMyMacSelectionButton(rowHeight: 54) {
                    setSelected(items, checkState(items) != .all)
                } indicator: {
                    checkVisual(checkState(items))
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(selected ? Color.black.opacity(0.22) : .clear)
        )
    }

    private var itemPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title(selectedDescriptor))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white.opacity(0.94))

                Text(description(selectedDescriptor))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.67))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 34)
            .padding(.top, 5)
            .frame(height: 112, alignment: .top)

            HStack {
                Spacer()
                sortMenu
            }
            .padding(.horizontal, 13)
            .frame(height: 30)

            ScrollView(showsIndicators: true) {
                LazyVStack(spacing: 0) {
                    ForEach(filteredItems) { item in
                        itemRow(item)
                    }
                }
                .padding(.horizontal, 10)
            }

            Spacer(minLength: 52)
        }
    }

    private func itemRow(_ item: JunkItem) -> some View {
        Button {
            item.isSelected.toggle()
            publishSelectionChanges()
        } label: {
            HStack(spacing: 11) {
                checkVisual(item.isSelected ? .all : .none)

                Image(nsImage: NSWorkspace.shared.icon(forFile: item.path.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 25, height: 25)

                Text(item.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.81))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Text(formatBytes(item.size))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.67))
                    .frame(width: 61, alignment: .trailing)
            }
            .padding(.horizontal, 7)
            .frame(height: 41)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scanResultContextMenu(
            isSelected: item.isSelected,
            displayName: item.name,
            url: item.path,
            onToggleSelection: {
                item.isSelected.toggle()
                publishSelectionChanges()
            },
            onIgnore: {
                cleaner.junkItems.removeAll { $0.id == item.id }
            }
        )
    }

    private var cleaningPage: some View {
        HStack(spacing: 62) {
            systemJunkImage(size: 290)
                .modifier(SystemJunkCleaningMotion(active: true))

            VStack(alignment: .leading, spacing: 0) {
                Text(localized("正在清理系统...", "Cleaning System..."))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white.opacity(0.94))

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(cleaner.cleaningCategories, id: \.self) { type in
                        HStack(spacing: 9) {
                            Image(systemName: cleaner.categoryCleaningStatus[type] == .completed ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 13))
                                .foregroundColor(Color(red: 0.36, green: 0.87, blue: 0.95))
                            Text(displayTitle(type))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))
                            Spacer()
                            Text(formatBytes(cleaner.categoryCleanedSize[type] ?? 0))
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.45))
                        }
                    }
                }
                .padding(.top, 28)
            }
            .frame(width: 300, alignment: .leading)
        }
        .offset(y: -8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var finishedPage: some View {
        HStack(spacing: 65) {
            systemJunkImage(size: 290)

            VStack(alignment: .leading, spacing: 0) {
                Text(localized("清理完毕", "Cleanup Complete"))
                    .font(.system(size: 21, weight: .bold))
                    .foregroundColor(.white.opacity(0.94))

                Text(formatBytes(cleanedAmount))
                    .font(.system(size: 39, weight: .ultraLight))
                    .foregroundColor(Color(red: 0.35, green: 0.84, blue: 0.96))
                    .padding(.top, 20)

                Text(localized("不需要的系统垃圾已移除。", "Unneeded system junk has been removed."))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
                    .padding(.top, 12)

                Button {
                    showingDetails = true
                    cleaningFinished = false
                } label: {
                    Text(localized("查看剩余", "Review Remaining"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(red: 0.41, green: 0.86, blue: 0.97))
                        .padding(.horizontal, 12)
                        .frame(height: 25)
                        .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .padding(.top, 25)
            }
            .frame(width: 285, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var bottomAction: some View {
        CleanMyMacBottomActionSlot {
            switch state {
            case .initial:
                orbButton(localized("扫描", "Scan"), style: .scan) {
                    Task { await cleaner.scanJunk() }
                }
            case .scanning:
                CleanMyMacBottomActionCluster {
                    orbButton(localized("停止", "Stop"), style: .stop) {
                        cleaner.stopScanning()
                    }
                } accessory: {
                    Text(formatBytes(moduleTotalSize))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                }
            case .results:
                CleanMyMacBottomActionCluster {
                    orbButton(localized("清理", "Clean"), style: .clean, disabled: moduleSelectedSize == 0) {
                        startCleaning()
                    }
                } accessory: {
                    Text(formatBytes(moduleSelectedSize))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.72))
                }
            case .cleaning:
                orbButton(localized("停止", "Stop"), style: .stop) {
                    cleaner.stopCleaning()
                }
            case .finished:
                EmptyView()
            }
        }
    }

    private enum OrbStyle { case scan, stop, clean }

    private func orbButton(_ title: String, style: OrbStyle, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            CleanMyMacActionOrb(
                title: title,
                gradient: LinearGradient(
                    colors: [Color.white.opacity(disabled ? 0.04 : 0.14), Color.black.opacity(0.12)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                glowColor: orbColor(style),
                ringColor: orbColor(style),
                disabled: disabled,
                progress: style == .stop ? cleaner.scanProgress : nil
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func orbColor(_ style: OrbStyle) -> Color {
        switch style {
        case .scan: return Color(red: 0.65, green: 0.42, blue: 0.76)
        case .stop: return Color(red: 0.78, green: 0.37, blue: 0.63)
        case .clean: return Color(red: 0.32, green: 0.84, blue: 0.96)
        }
    }

    private var selectedDescriptor: CategoryDescriptor {
        categories.first(where: { $0.id == selectedCategoryID }) ?? categories[0]
    }

    private var firstPopulatedCategoryID: String {
        categories.first(where: { !items(for: $0).isEmpty })?.id ?? categories[0].id
    }

    private var summaryCategories: [CategoryDescriptor] {
        categories.filter { descriptor in
            let categoryItems = items(for: descriptor)
            return !categoryItems.isEmpty && categoryItems.contains(where: \.isSelected)
        }
    }

    private var filteredItems: [JunkItem] {
        var result = items(for: selectedDescriptor)
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.path.path.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result.sorted {
            sortBySize ? $0.size > $1.size : $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private var anyItemsSelected: Bool {
        moduleItems.contains(where: \.isSelected)
    }

    private var moduleItems: [JunkItem] {
        cleaner.junkItems.filter { $0.type != .mailAttachments }
    }

    private var moduleTotalSize: Int64 {
        totalSize(moduleItems)
    }

    private var moduleSelectedSize: Int64 {
        totalSize(moduleItems.filter(\.isSelected))
    }

    private func items(for descriptor: CategoryDescriptor) -> [JunkItem] {
        let types: Set<JunkType>
        switch descriptor.id {
        case "userCache":
            types = [.userCache, .browserCache, .appCache, .chatCache]
        case "systemCache":
            types = [.systemCache, .tempFiles]
        case "userLogs":
            types = [.userLogs, .crashReports]
        default:
            guard let type = descriptor.type else { return [] }
            types = [type]
        }
        return cleaner.junkItems.filter { types.contains($0.type) }
    }

    private func setAllSelected(_ selected: Bool) {
        setSelected(moduleItems, selected)
    }

    private func setSelected(_ items: [JunkItem], _ selected: Bool) {
        items.forEach { $0.isSelected = selected }
        publishSelectionChanges()
    }

    /// JunkItem is a reference type. Reassigning the published collection
    /// invalidates every visible row after a group-level selection change.
    private func publishSelectionChanges() {
        cleaner.junkItems = cleaner.junkItems
    }

    private func checkState(_ items: [JunkItem]) -> CheckState {
        let selected = items.filter(\.isSelected).count
        if selected == 0 { return .none }
        return selected == items.count ? .all : .partial
    }

    private func checkVisual(_ state: CheckState) -> some View {
        ZStack {
            Circle()
                .fill(state == .none ? Color.clear : Color(red: 0.36, green: 0.88, blue: 0.97))
                .overlay(Circle().stroke(state == .none ? Color.white.opacity(0.42) : .clear, lineWidth: 1))
            if state == .all {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(Color(red: 0.20, green: 0.36, blue: 0.53))
            } else if state == .partial {
                Capsule()
                    .fill(Color(red: 0.20, green: 0.36, blue: 0.53))
                    .frame(width: 7, height: 2)
            }
        }
        .frame(width: 14, height: 14)
    }

    private func categoryIcon(_ category: CategoryDescriptor, enabled: Bool) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: category.colors, startPoint: .top, endPoint: .bottom))
            Image(systemName: category.symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.88))
        }
        .frame(width: 32, height: 32)
        .opacity(enabled ? 1 : 0.35)
    }

    private var sortMenu: some View {
        Menu {
            Button(localized("大小", "Size")) { sortBySize = true }
            Button(localized("名称", "Name")) { sortBySize = false }
        } label: {
            Text(localized("排序方式按 ", "Sort by ") + (sortBySize ? localized("大小", "Size") : localized("名称", "Name")) + " ▾")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.57))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func systemJunkImage(size: CGFloat) -> some View {
        Group {
            if let url = Bundle.main.url(forResource: "system_clean_menu", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size * 1.5, height: size * 1.5)
            } else {
                Image(systemName: "computermouse.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.pink)
            }
        }
        .frame(width: size, height: size)
    }

    private func startCleaning() {
        guard moduleSelectedSize > 0 else { return }
        cleaner.junkItems.filter { $0.type == .mailAttachments }.forEach { $0.isSelected = false }
        let selectedBefore = moduleSelectedSize
        Task {
            cleaner.isCleaning = true
            let result = await cleaner.cleanSelectedByCategory()
            cleaner.isCleaning = false
            if cleaner.stopCleaningRequested { return }
            cleanedAmount = result.cleaned > 0 ? result.cleaned : selectedBefore - moduleSelectedSize
            showAdminWarning = result.requiresAdmin
            if !result.requiresAdmin { cleaningFinished = true }
        }
    }

    private func playCompletionSound() {
        guard let url = Bundle.main.url(forResource: "CleanDidFinish", withExtension: "m4a") else { return }
        NSSound(contentsOf: url, byReference: false)?.play()
    }

    private func applySmartSelection() {
        let recommended: Set<JunkType> = [
            .userCache, .systemCache, .userLogs, .systemLogs,
            .browserCache, .appCache, .chatCache, .tempFiles, .crashReports
        ]
        cleaner.junkItems.forEach { $0.isSelected = recommended.contains($0.type) }
        cleaner.objectWillChange.send()
    }

    private func descriptor(
        _ id: String,
        _ type: JunkType?,
        _ zhTitle: String,
        _ enTitle: String,
        _ zhDescription: String,
        _ enDescription: String,
        _ symbol: String,
        _ colors: [Color]
    ) -> CategoryDescriptor {
        CategoryDescriptor(id: id, type: type, zhTitle: zhTitle, enTitle: enTitle,
                           zhDescription: zhDescription, enDescription: enDescription,
                           symbol: symbol, colors: colors)
    }

    private func title(_ category: CategoryDescriptor) -> String {
        localized(category.zhTitle, category.enTitle)
    }

    private func description(_ category: CategoryDescriptor) -> String {
        localized(category.zhDescription, category.enDescription)
    }

    private func displayTitle(_ type: JunkType) -> String {
        categories.first(where: { $0.type == type }).map(title) ?? type.localizedName
    }

    private func totalSize(_ items: [JunkItem]) -> Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func localized(_ chinese: String, _ english: String) -> String {
        loc.text(chinese, english)
    }
}

private struct SystemJunkCleaningMotion: ViewModifier {
    let active: Bool
    @State private var phase = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(active && phase ? 2 : -2))
            .scaleEffect(active && phase ? 1.02 : 1)
            .animation(active ? .easeInOut(duration: 0.65).repeatForever(autoreverses: true) : .default, value: phase)
            .onAppear { phase = active }
    }
}
