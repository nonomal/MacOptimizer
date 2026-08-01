import SwiftUI
import AppKit

private enum ExtensionGroup: String, CaseIterable, Identifiable {
    case safari
    case internet
    case preferences
    case spotlight

    var id: String { rawValue }
    var chineseTitle: String {
        switch self {
        case .safari: return "Safari 扩展"
        case .internet: return "Internet 插件"
        case .preferences: return "偏好设置面板"
        case .spotlight: return "聚焦插件"
        }
    }
    var englishTitle: String {
        switch self {
        case .safari: return "Safari Extensions"
        case .internet: return "Internet Plug-ins"
        case .preferences: return "Preference Panes"
        case .spotlight: return "Spotlight Plugins"
        }
    }
    var chineseDescription: String {
        switch self {
        case .safari: return "Safari 浏览器为许多扩展和附加项目提供了一个平台，您可以轻松进行管理，无需进入 Safari 浏览器的偏好设置。"
        case .internet: return "Mac 的所有浏览器以及其他联网应用程序共享插件。通过 CleanMyMac，您可以在一个地方管理它们。"
        case .preferences: return "这里列出了以系统偏好设置面板形式存在的所有应用程序。在 CleanMyMac 内轻松管理它们。"
        case .spotlight: return "Spotlight 作为您 Mac 的主要搜索工具会安装一些不需要的插件，您可以轻松地对这些插件进行完整移除或临时禁用。"
        }
    }
    var asset: String {
        switch self {
        case .safari: return "extensions_safari"
        case .internet: return "extensions_internet"
        case .preferences: return "extensions_preferences"
        case .spotlight: return "extensions_spotlight"
        }
    }

    var acceptedPathExtensions: Set<String> {
        switch self {
        case .safari: return ["safariextension", "safariextz", "appex"]
        case .internet: return ["plugin", "webplugin"]
        case .preferences: return ["prefpane"]
        case .spotlight: return ["mdimporter"]
        }
    }
}

private struct ExtensionItem: Identifiable, Equatable {
    let id: URL
    let name: String
    let url: URL
    let group: ExtensionGroup
    let size: Int64
    var isSelected = false
}

private final class ExtensionsService: ObservableObject {
    @Published var items: [ExtensionItem] = []
    @Published var isScanning = false
    @Published var isRemoving = false

    func scan() {
        isScanning = true
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let roots: [(ExtensionGroup, [URL])] = [
            (.safari, [home.appendingPathComponent("Library/Safari/Extensions")]),
            (.internet, [home.appendingPathComponent("Library/Internet Plug-Ins"), URL(fileURLWithPath: "/Library/Internet Plug-Ins")]),
            (.preferences, [home.appendingPathComponent("Library/PreferencePanes"), URL(fileURLWithPath: "/Library/PreferencePanes")]),
            (.spotlight, [home.appendingPathComponent("Library/Spotlight"), URL(fileURLWithPath: "/Library/Spotlight")])
        ]

        Task.detached {
            func allocatedSize(of url: URL) -> Int64 {
                let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey]
                let values = try? url.resourceValues(forKeys: keys)
                if values?.isDirectory != true {
                    return Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
                }

                guard let enumerator = fileManager.enumerator(
                    at: url,
                    includingPropertiesForKeys: Array(keys),
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else { return 0 }

                var total: Int64 = 0
                for case let child as URL in enumerator {
                    let childValues = try? child.resourceValues(forKeys: keys)
                    if childValues?.isDirectory != true {
                        total += Int64(childValues?.totalFileAllocatedSize ?? childValues?.fileAllocatedSize ?? 0)
                    }
                }
                return total
            }

            var discovered: [ExtensionItem] = []
            for (group, paths) in roots {
                for root in paths {
                    guard let children = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { continue }
                    for child in children {
                        guard group.acceptedPathExtensions.contains(child.pathExtension.lowercased()) else { continue }
                        let size = allocatedSize(of: child)
                        discovered.append(ExtensionItem(id: child, name: child.deletingPathExtension().lastPathComponent, url: child, group: group, size: size))
                    }
                }
            }
            let sortedItems = discovered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            await MainActor.run {
                self.items = sortedItems.filter { ScanResultIgnoreStore.shouldInclude($0.url) }
                self.isScanning = false
            }
        }
    }

    func removeSelected() async {
        await MainActor.run { isRemoving = true }
        let selected = items.filter(\.isSelected)
        for item in selected {
            _ = DeletionLogService.shared.logAndDelete(at: item.url, category: "Extensions")
        }
        await MainActor.run {
            isRemoving = false
            scan()
        }
    }
}

struct ExtensionsReplicaView: View {
    @StateObject private var service = ExtensionsService()
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var screen = 0
    @State private var selectedGroup: ExtensionGroup = .safari
    @State private var searchText = ""
    @State private var showRemoveConfirmation = false
    @State private var orbHovered = false

    var body: some View {
        ZStack {
            screen == 0 ? AnyView(introView) : AnyView(detailsView)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { service.scan() }
        .alert(localized("移除扩展", "Remove Extensions"), isPresented: $showRemoveConfirmation) {
            Button(localized("移除", "Remove"), role: .destructive) {
                Task { await service.removeSelected() }
            }
            Button(localized("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(localized("选中的扩展将被移入废纸篓，可从废纸篓恢复。", "Selected extensions will be moved to Trash and can be restored."))
        }
    }

    private var introView: some View {
        HStack(spacing: 20) {
            ZStack(alignment: .topLeading) {
                Text(localized("扩展", "Extensions"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .offset(y: 0)
                Text(localized("控制各种系统扩展，包括小部件、插件、词典和其他项目。", "Control system extensions, widgets, plug-ins, dictionaries and more."))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.80))
                    .frame(width: 300, alignment: .leading)
                    .offset(y: 40)

                benefit(asset: "extensions_benefit_remove", title: localized("正确移除扩展", "Remove extensions correctly"), detail: localized("允许安全移除任何不想要的扩展以及所有相关项目。", "Safely remove unwanted extensions and related items."))
                    .offset(y: 110)
                benefit(asset: "extensions_benefit_disable", title: localized("按照需要禁用扩展", "Disable extensions as needed"), detail: localized("不仅能彻底移除扩展，而且还能根据需要临时禁用它们。", "Temporarily disable extensions without removing them."))
                    .offset(y: 208)

                Button { screen = 1 } label: {
                    Text(localized("查看扩展", "View Extensions"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 0.08, green: 0.15, blue: 0.22))
                        .padding(.horizontal, 15)
                        .frame(height: 30)
                        .background(LinearGradient(colors: [Color(red: 0.48, green: 0.93, blue: 0.98), Color(red: 0.27, green: 0.78, blue: 0.98)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(ExtensionsCompactButtonStyle())
                .offset(y: 302)
            }
            .frame(width: 337, height: 332, alignment: .topLeading)

            asset("extensions_module")
                .frame(width: 315, height: 315)
                .scaleEffect(1.073)
                .offset(x: 13, y: 5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(x: -4, y: -18)
    }

    private func benefit(asset: String, title: String, detail: String) -> some View {
        HStack(spacing: 20) {
            self.asset(asset).frame(width: 40, height: 40).opacity(0.48)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.86))
                Text(detail).font(.system(size: 10.5)).foregroundColor(.white.opacity(0.55)).lineLimit(2)
            }
        }
    }

    private var detailsView: some View {
        CleanMyMacThreeColumnLayout(categoryWidth: 371) {
            VStack(alignment: .leading, spacing: 0) {
                Button { screen = 0 } label: {
                    HStack(spacing: 5) { Image(systemName: "chevron.left"); Text(localized("返回", "Back")) }
                        .font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.65))
                }
                .buttonStyle(.plain).padding(.leading, 14).padding(.top, 19).padding(.bottom, 20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 3) {
                        ForEach(ExtensionGroup.allCases) { group in groupRow(group) }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 100)
                }
            }
        } detail: {
            detailPanel
        } bottomOverlay: {
            orbButton(title: localized("移除", "Remove"), disabled: selectedItems.isEmpty) {
                showRemoveConfirmation = true
            }
        }
    }

    private func groupRow(_ group: ExtensionGroup) -> some View {
        let count = items(for: group).count
        let selectedCount = items(for: group).filter(\.isSelected).count
        return Button {
            selectedGroup = group
            guard count > 0 else { return }
            let shouldSelect = selectedCount != count
            for index in service.items.indices where service.items[index].group == group {
                service.items[index].isSelected = shouldSelect
            }
        } label: {
            HStack(spacing: 12) {
                extensionGroupCheckBox(selectedCount: selectedCount, totalCount: count)
                asset(group.asset).frame(width: 40, height: 40)
                Text(loc.currentLanguage == .chinese ? group.chineseTitle : group.englishTitle).font(.system(size: 12, weight: .semibold)).foregroundColor(.white.opacity(count == 0 ? 0.30 : 0.84))
                Spacer()
                if count > 0 { Text("\(count)").font(.system(size: 10, weight: .semibold)).foregroundColor(.white.opacity(0.72)) }
            }
            .padding(.horizontal, 10).frame(height: 55)
            .background(RoundedRectangle(cornerRadius: 9).fill(selectedGroup == group ? Color.black.opacity(0.13) : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(ExtensionsCategoryButtonStyle())
    }

    private func extensionGroupCheckBox(selectedCount: Int, totalCount: Int) -> some View {
        ZStack {
            Circle()
                .stroke(selectedCount > 0 ? Color.cyan.opacity(0.92) : Color.white.opacity(0.42), lineWidth: 1.4)
                .frame(width: 15, height: 15)
            if selectedCount > 0 {
                Circle().fill(Color.cyan.opacity(0.92)).frame(width: 15, height: 15)
                Image(systemName: selectedCount == totalCount ? "checkmark" : "minus")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(Color(red: 0.18, green: 0.28, blue: 0.42))
            }
        }
    }

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(localized("扩展", "Extensions")).font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.56))
                Spacer()
                HStack(spacing: 7) { Image(systemName: "magnifyingglass").font(.system(size: 10)); TextField(localized("搜索", "Search"), text: $searchText).textFieldStyle(.plain).font(.system(size: 11)).foregroundColor(.white.opacity(0.78)) }
                    .padding(.horizontal, 10).frame(width: 200, height: 30).background(Color.black.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 38).padding(.top, 14)

            Text(loc.currentLanguage == .chinese ? selectedGroup.chineseTitle : selectedGroup.englishTitle)
                .font(.system(size: 22, weight: .bold)).foregroundColor(.white).padding(.horizontal, 38).padding(.top, 15)
            Text(loc.currentLanguage == .chinese ? selectedGroup.chineseDescription : selectedGroup.englishTitle)
                .font(.system(size: 11)).foregroundColor(.white.opacity(0.76)).lineSpacing(3).fixedSize(horizontal: false, vertical: true).padding(.horizontal, 38).padding(.top, 5)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 3) {
                    ForEach(filteredItems) { item in
                        itemRow(item)
                    }
                    if filteredItems.isEmpty {
                        Text(localized("没有项目需要清理或修复，一切正常。", "No items need cleaning or repair."))
                            .font(.system(size: 12)).foregroundColor(.white.opacity(0.36)).frame(maxWidth: .infinity).padding(.top, 46)
                    }
                }
                .padding(.horizontal, 38).padding(.top, 26).padding(.bottom, 110)
            }
        }
    }

    private func itemRow(_ item: ExtensionItem) -> some View {
        Button {
            guard let index = service.items.firstIndex(where: { $0.id == item.id }) else { return }
            service.items[index].isSelected.toggle()
        } label: {
            HStack(spacing: 12) {
                Circle().fill(item.isSelected ? Color.cyan : Color.clear).overlay(Circle().stroke(item.isSelected ? Color.cyan : Color.white.opacity(0.42), lineWidth: 1.3)).frame(width: 15, height: 15)
                Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path)).resizable().aspectRatio(contentMode: .fit).frame(width: 28, height: 28)
                Text(item.name).font(.system(size: 12, weight: .semibold)).foregroundColor(.white.opacity(0.82)).lineLimit(1)
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file)).font(.system(size: 10)).foregroundColor(.white.opacity(0.46))
            }
            .frame(height: 45)
            .contentShape(Rectangle())
        }
        .buttonStyle(ExtensionsRowButtonStyle())
        .scanResultContextMenu(
            isSelected: item.isSelected,
            displayName: item.name,
            url: item.url,
            onToggleSelection: {
                guard let index = service.items.firstIndex(where: { $0.id == item.id }) else { return }
                service.items[index].isSelected.toggle()
            },
            onIgnore: { service.items.removeAll { $0.id == item.id } }
        )
    }

    private var filteredItems: [ExtensionItem] {
        items(for: selectedGroup).filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    private func items(for group: ExtensionGroup) -> [ExtensionItem] { service.items.filter { $0.group == group } }
    private var selectedItems: [ExtensionItem] { service.items.filter(\.isSelected) }

    private func orbButton(title: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            CleanMyMacActionOrb(
                title: title,
                gradient: LinearGradient(
                    colors: disabled
                        ? [Color.white.opacity(0.09), Color.white.opacity(0.035)]
                        : [Color(red: 0.58, green: 0.67, blue: 0.93), Color(red: 0.37, green: 0.25, blue: 0.65)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                glowColor: .cyan,
                ringColor: Color.white.opacity(0.40),
                disabled: disabled,
                isHovered: orbHovered
            )
        }
        .buttonStyle(ExtensionsOrbButtonStyle()).disabled(disabled).onHover { orbHovered = $0 }
    }

    private func asset(_ name: String) -> some View {
        Group {
            if let url = Bundle.main.url(forResource: name, withExtension: "png"), let image = NSImage(contentsOf: url) { Image(nsImage: image).resizable().aspectRatio(contentMode: .fit) } else { Color.clear }
        }
    }
    private func localized(_ chinese: String, _ english: String) -> String { loc.text(chinese, english) }
}

private struct ExtensionsCompactButtonStyle: ButtonStyle { func makeBody(configuration: Configuration) -> some View { configuration.label.scaleEffect(configuration.isPressed ? 0.965 : 1).brightness(configuration.isPressed ? -0.05 : 0) } }
private struct ExtensionsCategoryButtonStyle: ButtonStyle { func makeBody(configuration: Configuration) -> some View { configuration.label.opacity(configuration.isPressed ? 0.76 : 1) } }
private struct ExtensionsRowButtonStyle: ButtonStyle { func makeBody(configuration: Configuration) -> some View { configuration.label.opacity(configuration.isPressed ? 0.76 : 1) } }
private struct ExtensionsOrbButtonStyle: ButtonStyle { func makeBody(configuration: Configuration) -> some View { configuration.label.scaleEffect(configuration.isPressed ? 0.95 : 1).brightness(configuration.isPressed ? -0.06 : 0) } }
