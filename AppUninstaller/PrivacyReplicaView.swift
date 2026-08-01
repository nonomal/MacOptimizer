import AppKit
import SwiftUI

/// CleanMyMac X Privacy reconstruction. Scanning is read-only; cleanup remains
/// recoverable where possible and app-permission rows are review-only rather
/// than silently resetting unrelated macOS privacy grants.
struct PrivacyReplicaView: View {
    @ObservedObject private var service = ScanServiceManager.shared.privacyScanner
    @ObservedObject private var loc = LocalizationManager.shared

    @State private var selectedSource: PrivacySource = .permissions
    @State private var searchText = ""
    @State private var sortByName = true
    @State private var expandedPermissionGroups = Set<String>()
    @State private var showQuitPrompt = false
    @State private var quitPromptPurpose: QuitPurpose = .scan
    @State private var showPermissionReviewAlert = false
    @State private var showCleanupFailure = false
    @State private var cleanupFinished = false
    @State private var cleanedAmount: Int64 = 0
    @State private var orbHovered = false

    private enum PageState {
        case initial, scanning, details, cleaning, finished
    }

    private enum QuitPurpose {
        case scan, clean
    }

    private enum CheckState {
        case none, partial, all
    }

    private enum OrbStyle {
        case scan, stop, remove
    }

    private enum PrivacySource: Hashable, Identifiable, CaseIterable {
        case permissions, recentItems, chrome, safari, firefox, wifi, chat, development
        var id: String { String(describing: self) }
    }

    private var pageState: PageState {
        if service.isScanning { return .scanning }
        if service.isCleaning { return .cleaning }
        if cleanupFinished { return .finished }
        if service.hasScanned { return .details }
        return .initial
    }

    private var selectedItems: [PrivacyItem] {
        service.privacyItems.filter(\.isSelected)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                switch pageState {
                case .initial: initialPage
                case .scanning: scanningPage
                case .details: detailsPage
                case .cleaning: cleaningPage
                case .finished: finishedPage
                }

                header
                bottomAction
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .onChange(of: service.hasScanned) { scanned in
            if scanned { selectedSource = firstPopulatedSource }
        }
        .alert(localized("一些应用程序应该退出。", "Some applications should quit."), isPresented: $showQuitPrompt) {
            Button(localized("忽略", "Ignore")) { continueWithoutQuitting() }
            Button(localized("全部退出", "Quit All"), role: .destructive) {
                Task {
                    _ = await service.closeBrowsers()
                    continueAfterQuitPrompt()
                }
            }
            Button(localized("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(localized("请退出正在运行的浏览器，以扫描或清理所有与之相关的项目。", "Quit running browsers to scan or clean all related items."))
        }
        .alert(localized("应用权限需要在系统设置中管理", "Manage app permissions in System Settings"), isPresented: $showPermissionReviewAlert) {
            Button(localized("打开系统设置", "Open System Settings")) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button(localized("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(localized("为避免重置其他应用权限，本应用不会批量修改 TCC 数据库。其他已选隐私痕迹仍可正常清理。", "To avoid resetting unrelated grants, this app does not batch-edit the TCC database. Other selected privacy traces can still be cleaned."))
        }
        .alert(localized("部分隐私项目未能移除", "Some privacy items could not be removed"), isPresented: $showCleanupFailure) {
            Button(localized("完成", "Done"), role: .cancel) {}
        } message: {
            Text(localized("失败项目会继续保留在扫描结果中。", "Failed items remain in the scan results."))
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            ZStack {
                if pageState != .initial {
                    Text(localized("隐私", "Privacy"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.58))
                }

                HStack {
                    if pageState == .details {
                        Button {
                            service.reset()
                            cleanupFinished = false
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "chevron.left")
                                Text(localized("返回", "Back"))
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.58))
                        }
                        .buttonStyle(PrivacyHeaderButtonStyle())
                    } else if pageState == .finished {
                        Button {
                            service.reset()
                            cleanupFinished = false
                            cleanedAmount = 0
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "chevron.left")
                                Text(localized("重新开始", "Start Over"))
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.58))
                        }
                        .buttonStyle(PrivacyHeaderButtonStyle())
                    }

                    Spacer()

                    if pageState == .details {
                        searchField
                    }
                }
            }
            .frame(height: 52)
            .padding(.horizontal, 18)
            Spacer()
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.46))
            TextField(localized("搜索", "Search"), text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.82))
        }
        .padding(.horizontal, 10)
        .frame(width: 200, height: 29)
        .background(Color.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 7))
    }

    private var initialPage: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 180)

            HStack(alignment: .top, spacing: 35) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(localized("隐私", "Privacy"))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white.opacity(0.96))

                    Text(localized("立即移除浏览历史以及在线和离线活动的痕迹。", "Instantly remove browsing history and traces of online and offline activity."))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.62))
                        .padding(.top, 9)

                    benefit(
                        image: "privacy_benefit_browse",
                        title: localized("移除浏览痕迹", "Remove browsing traces"),
                        description: localized("清理浏览历史，包括常用浏览器存储的自动填写表单和其他数据。", "Clean browsing history, autofill forms, and other data stored by popular browsers.")
                    )
                    .padding(.top, 37)

                    benefit(
                        image: "privacy_benefit_chat",
                        title: localized("清理聊天数据", "Clean chat data"),
                        description: localized("让您可以清理 Skype 和其他信息应用程序的聊天历史记录。", "Clean chat history from Skype and other messaging applications.")
                    )
                    .padding(.top, 36)
                }
                .frame(width: 345, alignment: .leading)

                privacyImage(size: 315)
                    .offset(y: -26)
            }
            .frame(width: 720, alignment: .leading)

            Spacer(minLength: 80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func benefit(image: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 19) {
            resourceImage(image).frame(width: 40, height: 40).opacity(0.55)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundColor(.white.opacity(0.82))
                Text(description)
                    .font(.system(size: 11)).foregroundColor(.white.opacity(0.48))
                    .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var scanningPage: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 145)
            privacyImage(size: 280).modifier(PrivacyPulseMotion(active: true))
            Text(localized("正在查找隐私项...", "Searching for privacy items..."))
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white.opacity(0.96))
                .padding(.top, 4)

            if let last = service.privacyItems.last {
                Text(last.path.path)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.27))
                    .lineLimit(1).truncationMode(.middle)
                    .frame(width: 500)
                    .padding(.top, 10)
                Text(sourceTitle(source(for: last)))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.34))
                    .padding(.top, 8)
            }
            Spacer(minLength: 85)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(x: -15)
    }

    private var detailsPage: some View {
        HStack(spacing: 0) {
            sourcePane.frame(width: 398)
            Rectangle().fill(Color.white.opacity(0.055)).frame(width: 1)
            detailPane
        }
        .padding(.top, 52)
    }

    private var sourcePane: some View {
        VStack(spacing: 0) {
            HStack { Spacer(); sourceSortMenu }
                .padding(.horizontal, 10)
                .frame(height: 34)

            ScrollView(showsIndicators: true) {
                LazyVStack(spacing: 1) {
                    ForEach(visibleSources) { source in
                        sourceRow(source)
                    }
                }
                .padding(.horizontal, 9)
            }
            Spacer(minLength: 45)
        }
    }

    private func sourceRow(_ source: PrivacySource) -> some View {
        let items = items(for: source)
        let isWiFi = source == .wifi

        return ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: 32, height: 60)
                    .allowsHitTesting(false)

                Button { selectedSource = source } label: {
                    HStack(spacing: 11) {
                        sourceIcon(source)
                        Text(sourceTitle(source))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.84))
                        Spacer()
                        Text(localized("\(sourceCount(source)) 项", "\(sourceCount(source)) items"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.76))
                    }
                    .frame(maxWidth: .infinity).frame(height: 60).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }

            if isWiFi {
                Image(systemName: "info.circle")
                    .font(.system(size: 14)).foregroundColor(.white.opacity(0.62))
                    .frame(width: 44, height: 60)
                    .allowsHitTesting(false)
            } else {
                CleanMyMacSelectionButton(rowHeight: 60) {
                    setSelected(items, checkState(items) != .all)
                } indicator: {
                    checkVisual(checkState(items))
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 60)
        .background(RoundedRectangle(cornerRadius: 7).fill(selectedSource == source ? Color.black.opacity(0.22) : .clear))
    }

    private var detailPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(sourceTitle(selectedSource))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white.opacity(0.94))
                Text(sourceDescription(selectedSource))
                    .font(.system(size: 11)).foregroundColor(.white.opacity(0.67))
                    .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 10)
            .padding(.top, 5)
            .frame(height: 105, alignment: .top)

            HStack {
                if selectedSource == .permissions {
                    groupMenu
                }
                Spacer()
                sourceSortMenu
            }
            .padding(.horizontal, 13)
            .frame(height: 34)

            ScrollView(showsIndicators: true) {
                if selectedSource == .permissions {
                    permissionGroups
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredItems) { item in privacyItemRow(item) }
                    }
                    .padding(.horizontal, 10)
                }
            }
            Spacer(minLength: 52)
        }
    }

    private var permissionGroups: some View {
        LazyVStack(spacing: 0) {
            ForEach(filteredPermissionGroupNames, id: \.self) { group in
                permissionGroupRow(group)
                if expandedPermissionGroups.contains(group) {
                    ForEach(permissions(in: group)) { permission in
                        permissionAppRow(permission)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
    }

    private func permissionGroupRow(_ group: String) -> some View {
        let groupPermissions = permissions(in: group)
        return ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: 32, height: 45)
                    .allowsHitTesting(false)

                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        if expandedPermissionGroups.contains(group) { expandedPermissionGroups.remove(group) }
                        else { expandedPermissionGroups.insert(group) }
                    }
                } label: {
                    HStack(spacing: 11) {
                        permissionGroupIcon(group)
                        Text(group)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.82))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.58))
                            .rotationEffect(.degrees(expandedPermissionGroups.contains(group) ? 90 : 0))
                        Text(localized("\(groupPermissions.count) 项", "\(groupPermissions.count) items"))
                            .font(.system(size: 11)).foregroundColor(.white.opacity(0.62))
                            .frame(width: 52, alignment: .trailing)
                    }
                    .padding(.trailing, 7)
                    .frame(maxWidth: .infinity, minHeight: 45)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            CleanMyMacSelectionButton(rowHeight: 45) {
                setPermissionGroupSelected(group, checkState(itemsForPermissions(groupPermissions)) != .all)
            } indicator: {
                checkVisual(checkState(itemsForPermissions(groupPermissions)))
            }
        }
        .frame(height: 45)
    }

    private func permissionAppRow(_ permission: AppPermission) -> some View {
        let item = privacyItem(for: permission)
        return Button {
            if let item { service.toggleSelection(for: item.id) }
        } label: {
            HStack(spacing: 11) {
                checkVisual(item?.isSelected == true ? .all : .none)
                Image(nsImage: permission.appIcon).resizable().aspectRatio(contentMode: .fit).frame(width: 25, height: 25)
                Text(permission.appName)
                    .font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.79))
                Spacer()
                Text(localized("1 项", "1 item"))
                    .font(.system(size: 11)).foregroundColor(.white.opacity(0.62))
                    .frame(width: 52, alignment: .trailing)
            }
            .padding(.leading, 35).padding(.trailing, 7)
            .frame(height: 43).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func privacyItemRow(_ item: PrivacyItem) -> some View {
        Button { service.toggleSelection(for: item.id) } label: {
            HStack(spacing: 11) {
                checkVisual(item.isSelected ? .all : .none)
                Image(systemName: iconForItem(item))
                    .font(.system(size: 20, weight: .light)).foregroundColor(.white.opacity(0.72)).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayPath)
                        .font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.81))
                        .lineLimit(1).truncationMode(.middle)
                    Text(item.path.path)
                        .font(.system(size: 9)).foregroundColor(.white.opacity(0.34))
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                    .font(.system(size: 11)).foregroundColor(.white.opacity(0.62))
                    .frame(width: 61, alignment: .trailing)
            }
            .padding(.horizontal, 7).frame(height: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scanResultContextMenu(
            isSelected: item.isSelected,
            displayName: item.displayPath,
            url: item.path,
            onToggleSelection: { service.toggleSelection(for: item.id) },
            onIgnore: {
                service.privacyItems.removeAll { $0.id == item.id }
            }
        )
    }

    private var cleaningPage: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 145)
            privacyImage(size: 280).modifier(PrivacyPulseMotion(active: true))
            Text(localized("正在清理活动痕迹…", "Cleaning activity traces…"))
                .font(.system(size: 24, weight: .bold)).foregroundColor(.white.opacity(0.96)).padding(.top, 4)
            Text(ByteCountFormatter.string(fromByteCount: service.cleanedSize, countStyle: .file))
                .font(.system(size: 12)).foregroundColor(.white.opacity(0.36)).padding(.top, 27)
            Spacer(minLength: 85)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).offset(x: -15)
    }

    private var finishedPage: some View {
        HStack(spacing: 55) {
            privacyImage(size: 390)
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 28, weight: .medium)).foregroundColor(Color(red: 0.39, green: 0.88, blue: 0.65))
                VStack(alignment: .leading, spacing: 6) {
                    Text(localized("清理完毕", "Cleanup complete"))
                        .font(.system(size: 24, weight: .bold)).foregroundColor(.white.opacity(0.96))
                    Text(localized("您的 Mac 现在安全了！已清理 ", "Your Mac is safe now. Cleaned ") + ByteCountFormatter.string(fromByteCount: cleanedAmount, countStyle: .file))
                        .font(.system(size: 12)).foregroundColor(.white.opacity(0.52))
                }
            }
            .frame(width: 355, alignment: .leading)
        }
        .frame(width: 800, height: 400).padding(.top, 100)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top).offset(x: -15)
    }

    @ViewBuilder
    private var bottomAction: some View {
        CleanMyMacBottomActionSlot {
            switch pageState {
            case .initial:
                orbButton(localized("扫描", "Scan"), style: .scan) { prepareScan() }
            case .scanning:
                orbButton(localized("停止", "Stop"), style: .stop) { service.stopScan() }
            case .details:
                CleanMyMacBottomActionCluster {
                    orbButton(localized("移除", "Remove"), style: .remove, disabled: selectedItems.isEmpty) { prepareClean() }
                } accessory: {
                    Text(localized("\(selectedItems.count) 项", "\(selectedItems.count) items"))
                        .font(.system(size: 15, weight: .light)).foregroundColor(.white.opacity(0.60))
                }
            case .cleaning:
                orbButton(localized("停止", "Stop"), style: .stop) { service.stopCleaning() }
            case .finished:
                EmptyView()
            }
        }
    }

    private func orbButton(_ title: String, style: OrbStyle, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            CleanMyMacActionOrb(
                title: title,
                gradient: orbGradient(style),
                glowColor: orbGlow(style),
                ringColor: orbRing(style),
                disabled: disabled,
                isHovered: orbHovered
            )
        }
        .buttonStyle(PrivacyOrbPressStyle()).disabled(disabled).onHover { orbHovered = $0 }
    }

    private func orbGradient(_ style: OrbStyle) -> LinearGradient {
        switch style {
        case .scan, .remove:
            return LinearGradient(colors: [Color(red: 0.91, green: 0.46, blue: 0.66), Color(red: 0.58, green: 0.31, blue: 0.54)], startPoint: .top, endPoint: .bottom)
        case .stop:
            return LinearGradient(colors: [Color(red: 0.67, green: 0.40, blue: 0.68), Color(red: 0.42, green: 0.32, blue: 0.56)], startPoint: .top, endPoint: .bottom)
        }
    }

    private func orbGlow(_ style: OrbStyle) -> Color {
        style == .stop ? Color(red: 0.83, green: 0.45, blue: 0.85) : Color(red: 0.95, green: 0.43, blue: 0.72)
    }

    private func orbRing(_ style: OrbStyle) -> Color {
        style == .stop ? Color(red: 0.91, green: 0.64, blue: 0.93) : Color(red: 0.98, green: 0.67, blue: 0.84)
    }

    private var sourceSortMenu: some View {
        Menu {
            Button(localized("名称", "Name")) { sortByName = true }
            Button(localized("大小", "Size")) { sortByName = false }
        } label: {
            Text(localized("排序方式按 ", "Sort by ") + (sortByName ? localized("名称", "Name") : localized("大小", "Size")) + " ▾")
                .font(.system(size: 10, weight: .medium)).foregroundColor(.white.opacity(0.57))
        }
        .menuStyle(.borderlessButton).fixedSize()
    }

    private var groupMenu: some View {
        Menu { Button(localized("许可类型", "Permission Type")) {} } label: {
            Text(localized("分组方式 许可类型 ▾", "Group by Permission Type ▾"))
                .font(.system(size: 10, weight: .medium)).foregroundColor(.white.opacity(0.57))
        }
        .menuStyle(.borderlessButton).fixedSize()
    }

    private var visibleSources: [PrivacySource] {
        PrivacySource.allCases.filter { sourceCount($0) > 0 }
    }

    private var firstPopulatedSource: PrivacySource {
        visibleSources.first ?? .permissions
    }

    private func items(for source: PrivacySource) -> [PrivacyItem] {
        service.privacyItems.filter { item in self.source(for: item) == source }
    }

    private func source(for item: PrivacyItem) -> PrivacySource {
        if item.type == .permissions { return .permissions }
        if item.type == .recentItems { return .recentItems }
        if item.type == .wifi { return .wifi }
        if item.type == .chat { return .chat }
        if item.type == .development { return .development }
        switch item.browser {
        case .chrome: return .chrome
        case .safari: return .safari
        case .firefox: return .firefox
        case .system: return .recentItems
        }
    }

    private func sourceCount(_ source: PrivacySource) -> Int {
        if source == .permissions { return service.appPermissions.count }
        return items(for: source).count
    }

    private func sourceTitle(_ source: PrivacySource) -> String {
        switch source {
        case .permissions: return localized("应用权限", "Application Permissions")
        case .recentItems: return localized("最近项目列表", "Recent Items List")
        case .chrome: return "Chrome"
        case .safari: return "Safari"
        case .firefox: return "Firefox"
        case .wifi: return localized("Wi-Fi 网络", "Wi-Fi Networks")
        case .chat: return localized("聊天信息", "Chat Data")
        case .development: return localized("开发痕迹", "Development Traces")
        }
    }

    private func sourceDescription(_ source: PrivacySource) -> String {
        switch source {
        case .permissions:
            return localized("您的任何应用都可以请求获得更多权限，以访问您的 Mac 的部分功能、设备或系统功能。全面掌控这些权限。", "Any app can request additional access to Mac features, devices, or system functions. Stay in control of these permissions.")
        case .recentItems:
            return localized("包括 Apple 菜单“最近使用的项目”中列出的应用程序、文稿和服务器。", "Includes apps, documents, and servers listed under Recent Items in the Apple menu.")
        case .chrome:
            return localized("您可以选择移除使用 Chrome 浏览器后留下的所有本地储存的项目。", "Remove locally stored traces left by Chrome.")
        case .safari:
            return localized("您可以选择移除使用 Safari 浏览器后留下的所有本地储存的项目。", "Remove locally stored traces left by Safari.")
        case .firefox:
            return localized("您可以选择移除使用 Firefox 浏览器后留下的所有本地储存的项目。", "Remove locally stored traces left by Firefox.")
        case .wifi:
            return localized("您的 Mac 会保留先前连接的网络列表，包括不安全的开放式 Wi-Fi 热点。", "Your Mac remembers previously joined networks, including unsecured open Wi-Fi hotspots.")
        case .chat:
            return localized("可以轻松清理聊天历史和其他相关项目。", "Clean chat history and related items.")
        case .development:
            return localized("移除终端和开发工具留下的活动痕迹。", "Remove activity traces left by terminals and development tools.")
        }
    }

    private func sourceIcon(_ source: PrivacySource) -> some View {
        Group {
            switch source {
            case .permissions:
                resourceImage("privacy_permissions")
            case .chrome:
                appIcon("com.google.Chrome", fallback: "globe")
            case .safari:
                appIcon("com.apple.Safari", fallback: "safari")
            case .firefox:
                appIcon("org.mozilla.firefox", fallback: "flame")
            case .recentItems:
                Image(systemName: "face.smiling").resizable().aspectRatio(contentMode: .fit).foregroundColor(.white.opacity(0.82))
            case .wifi:
                Image(systemName: "wifi").resizable().aspectRatio(contentMode: .fit).foregroundColor(.white.opacity(0.82))
            case .chat:
                Image(systemName: "message.fill").resizable().aspectRatio(contentMode: .fit).foregroundColor(.white.opacity(0.82))
            case .development:
                Image(systemName: "terminal.fill").resizable().aspectRatio(contentMode: .fit).foregroundColor(.white.opacity(0.82))
            }
        }
        .frame(width: 34, height: 34)
    }

    private func appIcon(_ bundleID: String, fallback: String) -> some View {
        Group {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: fallback).resizable().aspectRatio(contentMode: .fit).foregroundColor(.white.opacity(0.82))
            }
        }
    }

    private var filteredItems: [PrivacyItem] {
        var values = items(for: selectedSource)
        if !searchText.isEmpty {
            values = values.filter { $0.displayPath.localizedCaseInsensitiveContains(searchText) || $0.path.path.localizedCaseInsensitiveContains(searchText) }
        }
        return values.sorted {
            sortByName ? $0.displayPath.localizedStandardCompare($1.displayPath) == .orderedAscending : $0.size > $1.size
        }
    }

    private var filteredPermissionGroupNames: [String] {
        let groups = Set(service.appPermissions.map(\.serviceName))
        return groups.filter { searchText.isEmpty || $0.localizedCaseInsensitiveContains(searchText) || permissions(in: $0).contains { $0.appName.localizedCaseInsensitiveContains(searchText) } }.sorted()
    }

    private func permissions(in group: String) -> [AppPermission] {
        service.appPermissions.filter { $0.serviceName == group }.sorted { $0.appName.localizedStandardCompare($1.appName) == .orderedAscending }
    }

    private func privacyItem(for permission: AppPermission) -> PrivacyItem? {
        let name = "\(permission.appName) - \(permission.serviceName)"
        return service.privacyItems.first { $0.type == .permissions && $0.displayPath == name }
    }

    private func itemsForPermissions(_ permissions: [AppPermission]) -> [PrivacyItem] {
        permissions.compactMap(privacyItem(for:))
    }

    private func setPermissionGroupSelected(_ group: String, _ selected: Bool) {
        setSelected(itemsForPermissions(permissions(in: group)), selected)
    }

    private func permissionGroupIcon(_ group: String) -> some View {
        Image(systemName: permissionSymbol(group))
            .font(.system(size: 20, weight: .light)).foregroundColor(.white.opacity(0.78)).frame(width: 28)
    }

    private func permissionSymbol(_ group: String) -> String {
        if group.contains("麦克风") { return "waveform" }
        if group.contains("摄像") { return "video.fill" }
        if group.contains("屏幕") { return "display" }
        if group.contains("辅助") { return "accessibility" }
        if group.contains("输入") { return "keyboard" }
        if group.contains("照片") { return "photo.fill" }
        if group.contains("位置") { return "location.fill" }
        if group.contains("自动化") { return "gearshape.2.fill" }
        return "folder.fill"
    }

    private func iconForItem(_ item: PrivacyItem) -> String {
        switch item.type {
        case .history: return "clock.arrow.circlepath"
        case .cookies: return "circle.hexagongrid.fill"
        case .downloads: return "arrow.down.circle"
        case .recentItems: return "clock"
        case .wifi: return "wifi"
        case .chat: return "message"
        case .development: return "terminal"
        case .permissions: return "lock.shield"
        }
    }

    private func setSelected(_ items: [PrivacyItem], _ selected: Bool) {
        let ids = Set(items.map(\.id))
        for index in service.privacyItems.indices where ids.contains(service.privacyItems[index].id) {
            service.privacyItems[index].isSelected = selected
            if let children = service.privacyItems[index].children {
                for childIndex in children.indices { service.privacyItems[index].children![childIndex].isSelected = selected }
            }
        }
    }

    private func checkState(_ items: [PrivacyItem]) -> CheckState {
        let count = items.filter(\.isSelected).count
        if count == 0 { return .none }
        return count == items.count ? .all : .partial
    }

    private func checkVisual(_ state: CheckState) -> some View {
        ZStack {
            Circle().fill(state == .none ? Color.clear : Color(red: 0.92, green: 0.60, blue: 0.81))
                .overlay(Circle().stroke(state == .none ? Color.white.opacity(0.42) : .clear, lineWidth: 1))
            if state == .all {
                Image(systemName: "checkmark").font(.system(size: 8, weight: .black)).foregroundColor(Color(red: 0.39, green: 0.25, blue: 0.45))
            } else if state == .partial {
                Capsule().fill(Color(red: 0.39, green: 0.25, blue: 0.45)).frame(width: 7, height: 2)
            }
        }
        .frame(width: 14, height: 14)
    }

    private func prepareScan() {
        if service.checkRunningBrowsers().isEmpty {
            startScan()
        } else {
            quitPromptPurpose = .scan
            showQuitPrompt = true
        }
    }

    private func prepareClean() {
        let selectedPermissions = selectedItems.filter { $0.type == .permissions }
        let selectedDeletable = selectedItems.filter { $0.type != .permissions && $0.type != .wifi }
        if !selectedPermissions.isEmpty && selectedDeletable.isEmpty {
            showPermissionReviewAlert = true
            return
        }
        if !selectedPermissions.isEmpty { showPermissionReviewAlert = true }
        guard !selectedDeletable.isEmpty else { return }

        if service.checkRunningBrowsers().isEmpty {
            startClean()
        } else {
            quitPromptPurpose = .clean
            showQuitPrompt = true
        }
    }

    private func continueWithoutQuitting() {
        continueAfterQuitPrompt()
    }

    private func continueAfterQuitPrompt() {
        switch quitPromptPurpose {
        case .scan: startScan()
        case .clean: startClean()
        }
    }

    private func startScan() {
        Task {
            await service.scanAll()
            if service.hasScanned {
                selectedSource = firstPopulatedSource
                playCompletionSound()
            }
        }
    }

    private func startClean() {
        Task {
            let result = await service.cleanSelected()
            cleanedAmount = result.cleaned
            if result.failed > 0 {
                showCleanupFailure = true
                return
            }
            cleanupFinished = true
            playCompletionSound()
        }
    }

    private func playCompletionSound() {
        guard let url = Bundle.main.url(forResource: "CleanDidFinish", withExtension: "m4a") else { return }
        NSSound(contentsOf: url, byReference: false)?.play()
    }

    private func privacyImage(size: CGFloat) -> some View {
        resourceImage("privacy_module").frame(width: size, height: size)
    }

    private func resourceImage(_ name: String) -> some View {
        Group {
            if let url = Bundle.main.url(forResource: name, withExtension: "png"), let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "hand.raised.fill").resizable().aspectRatio(contentMode: .fit).foregroundColor(.pink)
            }
        }
    }

    private func localized(_ chinese: String, _ english: String) -> String {
        loc.text(chinese, english)
    }
}

private struct PrivacyPulseMotion: ViewModifier {
    let active: Bool
    @State private var phase = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(active && phase ? 1.02 : 0.99)
            .rotationEffect(.degrees(active && phase ? 0.35 : -0.35))
            .animation(active ? .easeInOut(duration: 0.82).repeatForever(autoreverses: true) : .default, value: phase)
            .onAppear { phase = active }
            .onChange(of: active) { phase = $0 }
    }
}

private struct PrivacyOrbPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.958 : 1).brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.easeOut(duration: 0.09), value: configuration.isPressed)
    }
}

private struct PrivacyHeaderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.62 : 1).scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
