import AppKit
import SwiftUI

/// CleanMyMac X Mail Attachments reconstruction backed by the app's safe,
/// recoverable local-mail cleanup service.
struct MailAttachmentsReplicaView: View {
    @ObservedObject private var cleaner = ScanServiceManager.shared.junkCleaner
    @ObservedObject private var loc = LocalizationManager.shared

    @State private var showingDetails = false
    @State private var selectedSource: MailSource = .mail
    @State private var searchText = ""
    @State private var sortBySize = true
    @State private var cleaningFinished = false
    @State private var cleanedAmount: Int64 = 0
    @State private var showCleaningFailure = false
    @State private var wasScanning = false
    @State private var orbHovered = false

    private enum PageState {
        case initial, scanning, results, cleaning, finished
    }

    private enum CheckState {
        case none, partial, all
    }

    private enum MailSource: String, CaseIterable, Identifiable {
        case mail, outlook, spark
        var id: String { rawValue }
    }

    private var pageState: PageState {
        if cleaner.isScanningMailAttachments { return .scanning }
        if cleaner.isCleaningMailAttachments { return .cleaning }
        if cleaningFinished { return .finished }
        if cleaner.hasScannedMailAttachments || !mailItems.isEmpty { return .results }
        return .initial
    }

    private var mailItems: [JunkItem] {
        cleaner.junkItems.filter { $0.type == .mailAttachments }
    }

    private var selectedItems: [JunkItem] {
        mailItems.filter(\.isSelected)
    }

    private var selectedSize: Int64 {
        selectedItems.reduce(0) { $0 + $1.size }
    }

    private var totalSize: Int64 {
        mailItems.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if pageState == .results && showingDetails {
                    detailsPage
                } else {
                    switch pageState {
                    case .initial:
                        initialPage
                    case .scanning:
                        scanningPage
                    case .results:
                        resultsPage
                    case .cleaning:
                        cleaningPage
                    case .finished:
                        finishedPage
                    }
                }

                header
                    .offset(x: -15)
                bottomAction
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .onAppear {
            selectedSource = firstPopulatedSource
        }
        .onReceive(cleaner.$isScanningMailAttachments) { scanning in
            if wasScanning && !scanning && cleaner.mailScanProgress >= 1 {
                selectedSource = firstPopulatedSource
                playCompletionSound()
            }
            wasScanning = scanning
        }
        .alert(localized("部分邮件附件未能移除", "Some mail attachments could not be removed"), isPresented: $showCleaningFailure) {
            Button(localized("完成", "Done"), role: .cancel) {}
        } message: {
            Text(localized("这些项目可能正在使用中，或当前账户没有访问权限。", "These items may be in use or inaccessible to the current account."))
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            ZStack {
                if pageState != .initial {
                    Text(localized("邮件附件", "Mail Attachments"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.58))
                }

                HStack {
                    if showingDetails {
                        headerBackButton(localized("返回", "Back")) {
                            showingDetails = false
                            searchText = ""
                        }
                    } else if pageState == .results || pageState == .finished {
                        headerBackButton(localized("重新开始", "Start Over")) {
                            cleaner.resetMailAttachments()
                            cleaningFinished = false
                            cleanedAmount = 0
                        }
                    }

                    Spacer()

                    if showingDetails {
                        searchField
                    } else if pageState == .initial {
                        Button(action: {}) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color(red: 0.28, green: 0.82, blue: 0.95))
                                    .frame(width: 5, height: 5)
                                Text(localized("助手", "Assistant"))
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.white.opacity(0.74))
                            .padding(.horizontal, 17)
                            .frame(height: 25)
                            .background(Color.black.opacity(0.30), in: Capsule())
                        }
                        .buttonStyle(MailHeaderButtonStyle())
                        .padding(.trailing, 12)
                    }
                }
            }
            .frame(height: 52)
            .padding(.horizontal, 18)

            Spacer()
        }
    }

    private func headerBackButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "chevron.left")
                Text(title)
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white.opacity(0.58))
        }
        .buttonStyle(MailHeaderButtonStyle())
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
        .padding(.horizontal, 9)
        .frame(width: 181, height: 25)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 6))
    }

    private var initialPage: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 106)

            HStack(alignment: .top, spacing: 26) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(localized("邮件附件", "Mail Attachments"))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white.opacity(0.96))

                    Text(localized("移除电子邮件下载和附件的本地副本。", "Remove local copies of email downloads and attachments."))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.62))
                        .padding(.top, 9)

                    mailBenefit(
                        image: "mail_benefit_disk",
                        title: localized("节省本地磁盘空间", "Save local disk space"),
                        description: localized("移除 Mac 上的电子邮件附件，因为通过收件箱仍可以访问它们。", "Remove email attachments from your Mac while keeping them available in your inbox.")
                    )
                    .padding(.top, 39)

                    mailBenefit(
                        image: "mail_benefit_envelope",
                        title: localized("优化本地邮件数据", "Optimize local mail data"),
                        description: localized("您的邮件不会储存成千上百个公司徽标和其他小附件。", "Keep Mail from storing thousands of logos and other small attachments.")
                    )
                    .padding(.top, 41)
                }
                .frame(width: 310, alignment: .leading)
                .padding(.top, 45)

                mailImage(size: 315)
                    .padding(.top, 4)
            }
            .frame(width: 651, alignment: .leading)

            Spacer(minLength: 105)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func mailBenefit(image: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 19) {
            resourceImage(image)
                .frame(width: 36, height: 36)
                .opacity(0.58)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.82))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.48))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var scanningPage: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 125)

            mailImage(size: 285)
                .modifier(MailStampMotion(active: true))

            Text(localized("正在扫描邮件数据...", "Scanning mail data..."))
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white.opacity(0.96))
                .padding(.top, 4)

            Text(localized("发送邮件", "Mail"))
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.32))
                .padding(.top, 29)

            Spacer(minLength: 92)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(x: -15)
    }

    @ViewBuilder
    private var resultsPage: some View {
        if cleaner.mailAttachmentsHavePermissionError && mailItems.isEmpty {
            permissionPage
        } else if mailItems.isEmpty {
            cleanResultPage
        } else {
            foundResultPage
        }
    }

    private var cleanResultPage: some View {
        HStack(spacing: 55) {
            mailImage(size: 370)
                .offset(x: 14)

            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(Color(red: 0.39, green: 0.88, blue: 0.65))

                VStack(alignment: .leading, spacing: 6) {
                    Text(localized("非常干净！", "Very clean!"))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white.opacity(0.96))
                    Text(localized("邮件没有储存过多本地数据。", "Mail isn't storing too much local data."))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.52))
                }
            }
            .frame(width: 355, alignment: .leading)
            .offset(y: -4)
        }
        .frame(width: 780, height: 370)
        .padding(.top, 110)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .offset(x: -19)
    }

    private var foundResultPage: some View {
        HStack(spacing: 55) {
            mailImage(size: 350)

            VStack(alignment: .leading, spacing: 0) {
                Text(localized("扫描完毕", "Scan complete"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white.opacity(0.96))

                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(formattedSizeParts(selectedSize).value)
                        .font(.system(size: 45, weight: .ultraLight))
                    Text(formattedSizeParts(selectedSize).unit)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(Color(red: 0.42, green: 0.89, blue: 0.98))
                .padding(.top, 15)

                Text(localized("可恢复的本地邮件附件", "recoverable local mail attachments"))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.48))
                    .padding(.top, 2)

                Button {
                    selectedSource = firstPopulatedSource
                    showingDetails = true
                } label: {
                    Text(localized("查看项目", "Review Items"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.78))
                        .padding(.horizontal, 13)
                        .frame(height: 27)
                        .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(MailHeaderButtonStyle())
                .padding(.top, 21)

                Text(localized("共发现 ", "Found ") + formatBytes(totalSize))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.38))
                    .padding(.top, 14)
            }
            .frame(width: 355, alignment: .leading)
            .offset(y: -4)
        }
        .frame(width: 780, height: 370)
        .padding(.top, 105)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .offset(x: -15)
    }

    private var permissionPage: some View {
        HStack(spacing: 58) {
            mailImage(size: 350)

            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.white.opacity(0.78))
                Text(localized("授权全部磁盘访问以继续", "Grant Full Disk Access to continue"))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white.opacity(0.96))
                Text(localized("Mac优化大师需要全权访问您的磁盘才能查找邮件附件。", "Mac Optimizer needs Full Disk Access to find mail attachments."))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.52))
                    .fixedSize(horizontal: false, vertical: true)

                Button(localized("打开系统设置", "Open System Settings")) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(MailPermissionButtonStyle())
                .padding(.top, 12)
            }
            .frame(width: 350, alignment: .leading)
        }
        .frame(width: 780, height: 370)
        .padding(.top, 105)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .offset(x: -15)
    }

    private var detailsPage: some View {
        HStack(spacing: 0) {
            sourcePane
                .frame(width: 410)

            Rectangle()
                .fill(Color.white.opacity(0.055))
                .frame(width: 1)

            itemPane
        }
        .padding(.top, 52)
    }

    private var sourcePane: some View {
        VStack(spacing: 0) {
            HStack {
                Button(anyItemsSelected ? localized("取消全选", "Deselect All") : localized("全选", "Select All")) {
                    setSelected(mailItems, !anyItemsSelected)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.78))
                .buttonStyle(MailHeaderButtonStyle())
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
                    ForEach(MailSource.allCases) { source in
                        sourceRow(source)
                    }
                }
                .padding(.horizontal, 9)
            }

            Spacer(minLength: 45)
        }
    }

    private func sourceRow(_ source: MailSource) -> some View {
        let items = items(for: source)
        let enabled = !items.isEmpty
        let isCurrent = selectedSource == source

        return ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: 32, height: 54)
                    .allowsHitTesting(false)

                Button {
                    selectedSource = source
                } label: {
                    HStack(spacing: 11) {
                        sourceIcon(source, enabled: enabled)
                        Text(sourceTitle(source))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(enabled ? 0.84 : 0.25))
                        Spacer()
                        if enabled {
                            Text(formatBytes(items.reduce(0) { $0 + $1.size }))
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
                .fill(isCurrent ? Color.black.opacity(0.22) : .clear)
        )
    }

    private var itemPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(sourceTitle(selectedSource))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white.opacity(0.94))

                Text(sourceDescription(selectedSource))
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

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.81))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(item.path.deletingLastPathComponent().path)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.34))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Text(formatBytes(item.size))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.67))
                    .frame(width: 61, alignment: .trailing)
            }
            .padding(.horizontal, 7)
            .frame(height: 44)
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
        VStack(spacing: 0) {
            Spacer().frame(height: 125)

            mailImage(size: 285)
                .modifier(MailStampMotion(active: true))

            Text(localized("正在清理邮件附件...", "Cleaning mail attachments..."))
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white.opacity(0.96))
                .padding(.top, 4)

            Text(formatBytes(cleaner.mailCleanedSize))
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.36))
                .padding(.top, 27)

            Spacer(minLength: 92)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(x: -15)
    }

    private var finishedPage: some View {
        HStack(spacing: 55) {
            mailImage(size: 370)
                .offset(x: 14)

            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(Color(red: 0.39, green: 0.88, blue: 0.65))

                VStack(alignment: .leading, spacing: 6) {
                    Text(localized("清理完成！", "Cleanup complete!"))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white.opacity(0.96))
                    Text(localized("已释放 ", "Freed ") + formatBytes(cleanedAmount))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.52))
                }
            }
            .frame(width: 355, alignment: .leading)
            .offset(y: -4)
        }
        .frame(width: 780, height: 370)
        .padding(.top, 110)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .offset(x: -19)
    }

    @ViewBuilder
    private var bottomAction: some View {
        CleanMyMacBottomActionSlot {
            if showingDetails {
                CleanMyMacBottomActionCluster {
                    orbButton(localized("清理", "Clean"), style: .clean, disabled: selectedSize == 0) {
                        startCleaning()
                    }
                } accessory: {
                    Text(formatBytes(selectedSize))
                        .font(.system(size: 15, weight: .light))
                        .foregroundColor(.white.opacity(0.60))
                }
            } else {
                switch pageState {
                case .initial:
                    orbButton(localized("扫描", "Scan"), style: .scan) {
                        Task { await cleaner.scanMailAttachments() }
                    }
                case .scanning:
                    orbButton(localized("停止", "Stop"), style: .stop) {
                        cleaner.stopMailAttachmentsScan()
                    }
                case .results:
                    if mailItems.isEmpty {
                        orbButton(localized("清理", "Clean"), style: .clean, disabled: true) {}
                    } else {
                        orbButton(localized("清理", "Clean"), style: .clean, disabled: selectedSize == 0) {
                            startCleaning()
                        }
                    }
                case .cleaning:
                    orbButton(localized("停止", "Stop"), style: .stop) {
                        cleaner.stopMailAttachmentsCleaning()
                    }
                case .finished:
                    EmptyView()
                }
            }
        }
    }

    private enum OrbStyle {
        case scan, stop, clean
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
        .buttonStyle(MailOrbPressStyle())
        .disabled(disabled)
        .onHover { hovering in
            orbHovered = hovering
        }
    }

    private func orbGradient(_ style: OrbStyle) -> LinearGradient {
        switch style {
        case .scan:
            return LinearGradient(colors: [Color(red: 0.48, green: 0.66, blue: 0.81), Color(red: 0.35, green: 0.43, blue: 0.63)], startPoint: .top, endPoint: .bottom)
        case .stop:
            return LinearGradient(colors: [Color(red: 0.66, green: 0.39, blue: 0.68), Color(red: 0.40, green: 0.32, blue: 0.56)], startPoint: .top, endPoint: .bottom)
        case .clean:
            return LinearGradient(colors: [Color(red: 0.42, green: 0.69, blue: 0.84), Color(red: 0.31, green: 0.43, blue: 0.66)], startPoint: .top, endPoint: .bottom)
        }
    }

    private func orbGlow(_ style: OrbStyle) -> Color {
        switch style {
        case .scan, .clean: return Color(red: 0.26, green: 0.84, blue: 0.98)
        case .stop: return Color(red: 0.83, green: 0.45, blue: 0.85)
        }
    }

    private func orbRing(_ style: OrbStyle) -> Color {
        switch style {
        case .scan, .clean: return Color(red: 0.52, green: 0.91, blue: 0.98)
        case .stop: return Color(red: 0.91, green: 0.64, blue: 0.93)
        }
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

    private var filteredItems: [JunkItem] {
        var result = items(for: selectedSource)
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
        mailItems.contains(where: \.isSelected)
    }

    private var firstPopulatedSource: MailSource {
        MailSource.allCases.first(where: { !items(for: $0).isEmpty }) ?? .mail
    }

    private func items(for source: MailSource) -> [JunkItem] {
        mailItems.filter { item in
            let path = item.path.path.lowercased()
            switch source {
            case .outlook:
                return path.contains("outlook") || path.contains("ubf8t346g9.office")
            case .spark:
                return path.contains("spark") || path.contains("com.readdle.smartemail")
            case .mail:
                return !path.contains("outlook") && !path.contains("ubf8t346g9.office") &&
                    !path.contains("spark") && !path.contains("com.readdle.smartemail")
            }
        }
    }

    private func sourceTitle(_ source: MailSource) -> String {
        switch source {
        case .mail: return localized("发送邮件", "Mail")
        case .outlook: return "Outlook"
        case .spark: return "Spark"
        }
    }

    private func sourceDescription(_ source: MailSource) -> String {
        switch source {
        case .mail:
            return localized(
                "您的所有电子邮件附件都储存在 Mac 上，即使被移除也可以通过邮件来访问。Mac优化大师可以清理可恢复的附件，但会保留已经修改的附件。",
                "Your email attachments are stored on your Mac and remain available through Mail. Recoverable copies can be removed while modified attachments are kept."
            )
        case .outlook:
            return localized(
                "Outlook 将所有电子邮件附件和下载都储存在本地。您可以移除这些副本，因为它们仍在线上收件箱中。",
                "Outlook stores attachments and downloads locally. These copies can be removed because they remain in your online inbox."
            )
        case .spark:
            return localized(
                "Spark 应用程序将所有电子邮件附件和下载储存在本地。您可以移除这些副本，因为它们仍在线上收件箱中。",
                "Spark stores attachments and downloads locally. These copies can be removed because they remain in your online inbox."
            )
        }
    }

    private func sourceIcon(_ source: MailSource, enabled: Bool) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: sourceColors(source), startPoint: .top, endPoint: .bottom))
            Image(systemName: sourceSymbol(source))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.88))
        }
        .frame(width: 32, height: 32)
        .opacity(enabled ? 1 : 0.35)
    }

    private func sourceColors(_ source: MailSource) -> [Color] {
        switch source {
        case .mail: return [Color(red: 0.39, green: 0.73, blue: 0.98), Color(red: 0.27, green: 0.43, blue: 0.84)]
        case .outlook: return [Color(red: 0.27, green: 0.65, blue: 0.96), Color(red: 0.18, green: 0.37, blue: 0.72)]
        case .spark: return [Color(red: 0.38, green: 0.84, blue: 0.76), Color(red: 0.24, green: 0.52, blue: 0.73)]
        }
    }

    private func sourceSymbol(_ source: MailSource) -> String {
        switch source {
        case .mail: return "envelope.fill"
        case .outlook: return "tray.full.fill"
        case .spark: return "paperplane.fill"
        }
    }

    private func setSelected(_ items: [JunkItem], _ selected: Bool) {
        items.forEach { $0.isSelected = selected }
        publishSelectionChanges()
    }

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

    private func startCleaning() {
        let amountBeforeCleaning = selectedSize
        guard amountBeforeCleaning > 0 else { return }
        showingDetails = false

        Task {
            let result = await cleaner.cleanSelectedMailAttachments()
            if result.failed > 0 { showCleaningFailure = true }
            guard result.cleaned + result.failed >= amountBeforeCleaning else { return }
            cleanedAmount = result.cleaned
            cleaningFinished = true
            playCompletionSound()
        }
    }

    private func playCompletionSound() {
        guard let url = Bundle.main.url(forResource: "CleanDidFinish", withExtension: "m4a") else { return }
        NSSound(contentsOf: url, byReference: false)?.play()
    }

    private func mailImage(size: CGFloat) -> some View {
        resourceImage("mail_attachments_module")
            .frame(width: size, height: size)
    }

    private func resourceImage(_ name: String) -> some View {
        Group {
            if let url = Bundle.main.url(forResource: name, withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "envelope.badge.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.blue)
            }
        }
    }

    private func formattedSizeParts(_ bytes: Int64) -> (value: String, unit: String) {
        let text = formatBytes(bytes)
        let parts = text.split(separator: " ", maxSplits: 1).map(String.init)
        return (parts.first ?? "0", parts.count > 1 ? parts[1] : "")
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func localized(_ chinese: String, _ english: String) -> String {
        loc.text(chinese, english)
    }
}

private struct MailStampMotion: ViewModifier {
    let active: Bool
    @State private var phase = false

    func body(content: Content) -> some View {
        content
            .offset(y: active && phase ? -4 : 3)
            .rotationEffect(.degrees(active && phase ? 0.7 : -0.7))
            .scaleEffect(active && phase ? 1.012 : 0.995)
            .animation(active ? .easeInOut(duration: 0.72).repeatForever(autoreverses: true) : .default, value: phase)
            .onAppear { phase = active }
            .onChange(of: active) { phase = $0 }
    }
}

private struct MailOrbPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.958 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.easeOut(duration: 0.09), value: configuration.isPressed)
    }
}

private struct MailHeaderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.62 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

private struct MailPermissionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white.opacity(0.88))
            .padding(.horizontal, 15)
            .frame(height: 30)
            .background(
                LinearGradient(
                    colors: [Color.white.opacity(configuration.isPressed ? 0.12 : 0.20), Color.black.opacity(0.12)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: 7)
            )
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.white.opacity(0.13), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
