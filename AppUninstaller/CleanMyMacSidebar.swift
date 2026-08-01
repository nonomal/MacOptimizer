import SwiftUI

/// Fixed primary navigation. Selection is committed immediately while every
/// scanner keeps publishing its own compact activity/result indicator here.
struct CleanMyMacSidebar: View {
    @Binding var selectedModule: AppModule
    @ObservedObject var appScanner: AppScanner

    @ObservedObject private var loc = LocalizationManager.shared
    @ObservedObject private var junkCleaner = ScanServiceManager.shared.junkCleaner
    @ObservedObject private var largeFileScanner = ScanServiceManager.shared.largeFileScanner
    @ObservedObject private var deepCleanScanner = ScanServiceManager.shared.deepCleanScanner
    @ObservedObject private var smartCleaner = ScanServiceManager.shared.smartCleanerService
    @ObservedObject private var trashScanner = ScanServiceManager.shared.trashScanner
    @ObservedObject private var malwareScanner = ScanServiceManager.shared.malwareScanner
    @ObservedObject private var privacyScanner = ScanServiceManager.shared.privacyScanner
    @ObservedObject private var spaceLensScanner = ScanServiceManager.shared.spaceLensScanner
    @ObservedObject private var shredderService = ScanServiceManager.shared.shredderService
    @ObservedObject private var updateChecker = UpdateCheckerService.shared

    @State private var hoveredModule: AppModule?

    private struct Section: Identifiable {
        let id: String
        let chineseTitle: String
        let englishTitle: String
        let items: [Item]
    }

    private struct Item: Identifiable {
        var id: AppModule { module }
        let module: AppModule
        let chineseTitle: String
        let englishTitle: String
        let icon: String

        init(_ module: AppModule, _ chinese: String, _ english: String, _ icon: String) {
            self.module = module
            chineseTitle = chinese
            englishTitle = english
            self.icon = icon
        }
    }

    private struct ActivityStatus {
        let text: String?
        let isBusy: Bool

        static let idle = ActivityStatus(text: nil, isBusy: false)
    }

    private var sections: [Section] {
        [
            Section(id: "primary", chineseTitle: "", englishTitle: "", items: [
                Item(.monitor, "控制台", "Monitor", "chart.bar.xaxis"),
                Item(.smartClean, "智能扫描", "Smart Scan", "display")
            ]),
            Section(id: "cleanup", chineseTitle: "清理", englishTitle: "Cleanup", items: [
                Item(.cleaner, "系统垃圾", "System Junk", "globe"),
                Item(.mailAttachments, "邮件附件", "Mail Attachments", "envelope"),
                Item(.trash, "废纸篓", "Trash Bins", "trash"),
                Item(.deepClean, "深度清理", "Deep Clean", "magnifyingglass.circle")
            ]),
            Section(id: "protection", chineseTitle: "保护", englishTitle: "Protection", items: [
                Item(.malware, "移除恶意软件", "Malware Removal", "ant"),
                Item(.privacy, "隐私", "Privacy", "hand.raised")
            ]),
            Section(id: "speed", chineseTitle: "速度", englishTitle: "Speed", items: [
                Item(.optimizer, "优化", "Optimization", "slider.horizontal.3"),
                Item(.maintenance, "维护", "Maintenance", "wrench")
            ]),
            Section(id: "applications", chineseTitle: "应用程序", englishTitle: "Applications", items: [
                Item(.uninstaller, "卸载器", "Uninstaller", "point.3.connected.trianglepath.dotted"),
                Item(.updater, "更新程序", "Updater", "arrow.triangle.2.circlepath"),
                Item(.extensions, "扩展", "Extensions", "puzzlepiece.extension")
            ]),
            Section(id: "files", chineseTitle: "文件", englishTitle: "Files", items: [
                Item(.spaceLens, "空间透镜", "Space Lens", "circle.hexagongrid"),
                Item(.largeFiles, "大型和旧文件", "Large & Old Files", "folder"),
                Item(.shredder, "碎纸机", "Shredder", "externaldrive.badge.xmark"),
                Item(.fileExplorer, "文件管理", "File Manager", "folder.badge.gearshape")
            ])
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 12)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(sections) { section in
                        if !section.chineseTitle.isEmpty {
                            Text(localized(section.chineseTitle, section.englishTitle))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.48))
                                .padding(.leading, 24)
                                .padding(.top, 9)
                                .padding(.bottom, 3)
                        }

                        ForEach(section.items) { item in
                            sidebarButton(item)
                        }
                    }
                }
                .padding(.bottom, 14)
            }

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(sidebarBackground)
        .shadow(color: .black.opacity(0.24), radius: 16, x: 3, y: 8)
        .onChange(of: selectedModule) { _ in
            // Moving between modules can replace the hit-test subtree before
            // AppKit sends mouseExited. Clear it explicitly so an old hover can
            // never look like a second selection.
            hoveredModule = nil
        }
    }

    private func sidebarButton(_ item: Item) -> some View {
        let isSelected = selectedModule == item.module
        let status = activityStatus(for: item.module)

        return Button {
            hoveredModule = nil
            guard selectedModule != item.module else { return }
            selectedModule = item.module
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(isSelected ? 0.90 : 0.62))
                    .frame(width: 17)

                Text(localized(item.chineseTitle, item.englishTitle))
                    .font(.system(size: 12.2, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(.white.opacity(isSelected ? 0.94 : 0.82))
                    .lineLimit(1)

                Spacer(minLength: 3)

                activityIndicator(status)
            }
            .padding(.horizontal, 7)
            .frame(height: 27)
            .background {
                RoundedRectangle(cornerRadius: 7)
                    .fill(
                        isSelected
                            ? Color.black.opacity(0.24)
                            : (hoveredModule == item.module ? Color.white.opacity(0.055) : Color.clear)
                    )
            }
            .padding(.leading, 17)
            .padding(.trailing, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(CleanMyMacSidebarButtonStyle())
        .onHover { hovering in
            hoveredModule = hovering ? item.module : (hoveredModule == item.module ? nil : hoveredModule)
        }
    }

    @ViewBuilder
    private func activityIndicator(_ status: ActivityStatus) -> some View {
        if status.isBusy {
            ProgressView()
                .controlSize(.mini)
                .tint(.white.opacity(0.82))
                .frame(width: 12, height: 12)
        }

        if let text = status.text {
            Text(text)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundColor(.white.opacity(status.isBusy ? 0.62 : 0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }

    private var sidebarBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.17), Color.black.opacity(0.12)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.075), lineWidth: 0.8)
            }
    }

    private func activityStatus(for module: AppModule) -> ActivityStatus {
        switch module {
        case .smartClean:
            if smartCleaner.isCleaning {
                return ActivityStatus(text: localized("清理中", "Cleaning"), isBusy: true)
            }
            if smartCleaner.isScanning {
                return ActivityStatus(text: formattedSize(smartCleaner.totalCleanableSize), isBusy: true)
            }
            return completedSizeStatus(scanned: smartCleaner.totalCleanableSize, cleaned: smartCleaner.totalCleanedSize)

        case .cleaner:
            let cleaned = junkCleaner.categoryCleanedSize.values.reduce(0, +)
            if junkCleaner.isCleaning {
                return ActivityStatus(text: localized("清理中", "Cleaning"), isBusy: true)
            }
            if junkCleaner.isScanning {
                return ActivityStatus(text: formattedSize(junkCleaner.totalSize), isBusy: true)
            }
            return completedSizeStatus(scanned: junkCleaner.totalSize, cleaned: cleaned)

        case .mailAttachments:
            let size = junkCleaner.junkItems
                .filter { $0.type == .mailAttachments }
                .reduce(Int64(0)) { $0 + $1.size }
            if junkCleaner.isCleaningMailAttachments {
                return ActivityStatus(text: localized("清理中", "Cleaning"), isBusy: true)
            }
            if junkCleaner.isScanningMailAttachments {
                return ActivityStatus(text: formattedSize(size), isBusy: true)
            }
            return completedSizeStatus(scanned: size, cleaned: junkCleaner.mailCleanedSize)

        case .trash:
            if trashScanner.isCleaning {
                return ActivityStatus(text: localized("清理中", "Cleaning"), isBusy: true)
            }
            if trashScanner.isScanning {
                return ActivityStatus(text: formattedSize(trashScanner.totalSize), isBusy: true)
            }
            return completedSizeStatus(scanned: trashScanner.totalSize, cleaned: trashScanner.cleanedSize)

        case .deepClean:
            if deepCleanScanner.isCleaning {
                return ActivityStatus(text: localized("清理中", "Cleaning"), isBusy: true)
            }
            if deepCleanScanner.isScanning {
                return ActivityStatus(text: formattedSize(deepCleanScanner.totalSize), isBusy: true)
            }
            return completedSizeStatus(scanned: deepCleanScanner.totalSize, cleaned: deepCleanScanner.cleanedSize)

        case .malware:
            let size = malwareScanner.threats.reduce(Int64(0)) { $0 + $1.size }
            if malwareScanner.isRemoving {
                return ActivityStatus(text: localized("移除中", "Removing"), isBusy: true)
            }
            if malwareScanner.isScanning {
                return ActivityStatus(text: formattedSize(size), isBusy: true)
            }
            if size > 0 { return sizeStatus(size) }
            if malwareScanner.scanComplete {
                return ActivityStatus(text: localized("安全", "Safe"), isBusy: false)
            }
            return .idle

        case .privacy:
            if privacyScanner.isCleaning {
                return ActivityStatus(text: localized("清理中", "Cleaning"), isBusy: true)
            }
            if privacyScanner.isScanning {
                return ActivityStatus(text: formattedSize(privacyScanner.totalSize), isBusy: true)
            }
            return completedSizeStatus(scanned: privacyScanner.totalSize, cleaned: privacyScanner.cleanedSize)

        case .uninstaller:
            let size = appScanner.apps.reduce(Int64(0)) { $0 + $1.size }
            if appScanner.isScanning {
                return ActivityStatus(text: formattedSize(size), isBusy: true)
            }
            return sizeStatus(size)

        case .updater:
            return updateChecker.isChecking
                ? ActivityStatus(text: localized("检查中", "Checking"), isBusy: true)
                : .idle

        case .spaceLens:
            if spaceLensScanner.isScanning {
                return ActivityStatus(text: formattedSize(spaceLensScanner.totalSize), isBusy: true)
            }
            return sizeStatus(spaceLensScanner.totalSize)

        case .largeFiles:
            if largeFileScanner.isCleaning {
                return ActivityStatus(text: localized("清理中", "Cleaning"), isBusy: true)
            }
            if largeFileScanner.isScanning {
                return ActivityStatus(text: formattedSize(largeFileScanner.totalSize), isBusy: true)
            }
            return completedSizeStatus(scanned: largeFileScanner.totalSize, cleaned: largeFileScanner.cleanedSize)

        case .shredder:
            let selectedSize = shredderService.items.reduce(Int64(0)) { $0 + $1.size }
            if shredderService.isProcessing {
                return ActivityStatus(text: formattedSize(selectedSize), isBusy: true)
            }
            return sizeStatus(selectedSize, fallback: shredderService.totalSizeCleared)

        default:
            return .idle
        }
    }

    private func sizeStatus(_ size: Int64, fallback: Int64 = 0) -> ActivityStatus {
        let value = size > 0 ? size : fallback
        guard value > 0 else { return .idle }
        return ActivityStatus(text: formattedSize(value), isBusy: false)
    }

    /// A completed cleanup reports the amount actually recovered, even when
    /// unselected or failed items remain in the previous scan result.
    private func completedSizeStatus(scanned: Int64, cleaned: Int64) -> ActivityStatus {
        sizeStatus(cleaned > 0 ? cleaned : scanned)
    }

    private func formattedSize(_ size: Int64) -> String? {
        guard size > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private func localized(_ chinese: String, _ english: String) -> String {
        loc.text(chinese, english)
    }
}

private struct CleanMyMacSidebarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.992 : 1)
    }
}
