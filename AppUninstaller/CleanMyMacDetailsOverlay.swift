import AppKit
import SwiftUI

private typealias DetailSelectionState = SmartCleanerService.SelectionState

/// In-window reconstruction of CleanMyMac X's Smart Scan review panel.
struct CleanMyMacDetailsOverlay: View {
    @ObservedObject var service: SmartCleanerService
    @ObservedObject var loc: LocalizationManager
    @Binding var isPresented: Bool

    private enum RootCategory: Hashable {
        case systemJunk
        case trash
    }

    private enum SortMode: String, CaseIterable {
        case size
        case name
    }

    private let systemCategories: [CleanerCategory] = [
        .systemCache, .userCache, .userLogs, .systemLogs
    ]

    @State private var selectedRoot: RootCategory
    @State private var expandedCategories: Set<CleanerCategory> = []
    @State private var sortMode: SortMode = .size

    init(
        service: SmartCleanerService,
        loc: LocalizationManager,
        isPresented: Binding<Bool>,
        initialCategory: CleanerCategory?
    ) {
        self.service = service
        self.loc = loc
        self._isPresented = isPresented
        self._selectedRoot = State(initialValue: initialCategory == .trash ? .trash : .systemJunk)
    }

    var body: some View {
        VStack(spacing: 0) {
            titleBar

            HStack(spacing: 0) {
                masterPane
                    .frame(width: 342)

                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 1)

                detailPane
            }
        }
        .background(panelGradient)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 15, y: 8)
    }

    private var titleBar: some View {
        ZStack {
            Text(localized("清理详情", "Cleanup Details"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.86))

            HStack {
                Button {
                    service.objectWillChange.send()
                    isPresented = false
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text(localized("返回摘要", "Back to Summary"))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(Color(red: 0.45, green: 0.88, blue: 0.98))
                    .padding(.horizontal, 9)
                    .frame(height: 25)
                    .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 44)
    }

    private var masterPane: some View {
        VStack(spacing: 0) {
            HStack {
                Button(allSelected ? localized("取消全选", "Deselect All") : localized("全选", "Select All")) {
                    setAllSelected(!allSelected)
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
            .padding(.horizontal, 12)
            .frame(height: 36)

            VStack(spacing: 1) {
                masterRow(.systemJunk)
                masterRow(.trash)
            }
            .padding(.horizontal, 9)

            Spacer()
        }
    }

    private func masterRow(_ root: RootCategory) -> some View {
        Button {
            selectedRoot = root
        } label: {
            HStack(spacing: 11) {
                replicaCheckbox(selectionState(for: root)) {
                    toggle(root)
                }

                rootIcon(root)

                Text(rootTitle(root))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.88))

                Spacer(minLength: 5)

                Text(formatBytes(totalSize(for: root)))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.83))
            }
            .padding(.horizontal, 10)
            .frame(height: 55)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(selectedRoot == root ? Color.black.opacity(0.23) : .clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var detailPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rootTitle(selectedRoot))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white.opacity(0.94))

                    Text(rootDescription(selectedRoot))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.68))
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(.leading, 9)
            .padding(.trailing, 18)
            .padding(.top, 7)
            .frame(height: 76, alignment: .top)

            HStack {
                Spacer()
                sortMenu
            }
            .padding(.trailing, 13)
            .frame(height: 27)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(detailCategories, id: \.self) { category in
                        detailGroup(category)
                    }
                }
                .padding(.horizontal, 11)
            }

            Spacer(minLength: 0)
        }
    }

    private var detailCategories: [CleanerCategory] {
        let categories = selectedRoot == .trash ? [.trash] : systemCategories
        return categories.filter { !service.filesFor(category: $0).isEmpty }
    }

    private func detailGroup(_ category: CleanerCategory) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.14)) {
                    if expandedCategories.contains(category) {
                        expandedCategories.remove(category)
                    } else {
                        expandedCategories.insert(category)
                    }
                }
            } label: {
                HStack(spacing: 11) {
                    replicaCheckbox(selectionState(for: category)) {
                        service.toggleCategorySelection(category)
                    }

                    categoryIcon(category)

                    Text(categoryTitle(category))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.83))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                        .rotationEffect(.degrees(expandedCategories.contains(category) ? 90 : 0))

                    Text(formatBytes(totalSize(category)))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.83))
                        .frame(width: 57, alignment: .trailing)
                }
                .padding(.horizontal, 8)
                .frame(height: 43)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expandedCategories.contains(category) {
                ForEach(sortedFiles(service.filesFor(category: category)), id: \.url) { file in
                    fileRow(file, category: category)
                }
            }
        }
    }

    private func fileRow(_ file: CleanerFileItem, category: CleanerCategory) -> some View {
        Button {
            service.toggleFileSelection(file: file, in: category)
        } label: {
            HStack(spacing: 10) {
                replicaCheckbox(file.isSelected ? .all : .none, action: {})

                Image(nsImage: file.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(file.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.78))
                        .lineLimit(1)
                    Text(file.url.deletingLastPathComponent().path)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.35))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Text(formatBytes(file.size))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
                    .frame(width: 57, alignment: .trailing)
            }
            .padding(.leading, 28)
            .padding(.trailing, 8)
            .frame(height: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scanResultContextMenu(
            isSelected: file.isSelected,
            displayName: file.name,
            url: file.url,
            onToggleSelection: { service.toggleFileSelection(file: file, in: category) },
            onIgnore: { service.ignoreFile(file, in: category) }
        )
    }

    private var sortMenu: some View {
        Menu {
            Button(localized("大小", "Size")) { sortMode = .size }
            Button(localized("名称", "Name")) { sortMode = .name }
        } label: {
            Text(localized("排序方式按 ", "Sort by ") + sortTitle + " ▾")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.58))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func replicaCheckbox(_ state: DetailSelectionState, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(state == .none ? Color.clear : Color(red: 0.36, green: 0.88, blue: 0.97))
                    .overlay(
                        Circle().stroke(
                            state == .none ? Color.white.opacity(0.38) : Color.white.opacity(0.12),
                            lineWidth: 1
                        )
                    )

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
        .buttonStyle(.plain)
    }

    private func rootIcon(_ root: RootCategory) -> some View {
        let colors: [Color] = root == .systemJunk
            ? [Color(red: 0.95, green: 0.46, blue: 0.68), Color(red: 0.68, green: 0.27, blue: 0.55)]
            : [Color(red: 0.24, green: 0.87, blue: 0.65), Color(red: 0.13, green: 0.62, blue: 0.60)]
        let symbol = root == .systemJunk ? "computermouse.fill" : "trash.fill"

        return ZStack {
            Circle().fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            Circle().stroke(Color.white.opacity(0.35), lineWidth: 1)
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .light))
                .foregroundColor(.white.opacity(0.82))
        }
        .frame(width: 32, height: 32)
    }

    private func categoryIcon(_ category: CleanerCategory) -> some View {
        let style = iconStyle(category)
        return ZStack {
            Circle().fill(LinearGradient(colors: style.colors, startPoint: .top, endPoint: .bottom))
            Image(systemName: style.symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.88))
        }
        .frame(width: 28, height: 28)
    }

    private func iconStyle(_ category: CleanerCategory) -> (symbol: String, colors: [Color]) {
        switch category {
        case .systemCache:
            return ("sparkles", [.cyan, Color(red: 0.28, green: 0.48, blue: 0.87)])
        case .userCache:
            return ("person.fill", [.orange, Color(red: 0.84, green: 0.38, blue: 0.42)])
        case .userLogs:
            return ("doc.text.fill", [Color(red: 0.55, green: 0.64, blue: 0.85), Color(red: 0.29, green: 0.35, blue: 0.62)])
        case .systemLogs:
            return ("doc.badge.gearshape.fill", [Color(red: 0.62, green: 0.68, blue: 0.88), Color(red: 0.34, green: 0.39, blue: 0.64)])
        case .trash:
            return ("trash.fill", [Color(red: 0.26, green: 0.86, blue: 0.68), Color(red: 0.13, green: 0.59, blue: 0.60)])
        default:
            return (category.icon, [.blue, .purple])
        }
    }

    private var allSelected: Bool {
        let categories = systemCategories + [.trash]
        let populated = categories.filter { !service.filesFor(category: $0).isEmpty }
        return !populated.isEmpty && populated.allSatisfy(service.isCategoryAllSelected)
    }

    private func setAllSelected(_ selected: Bool) {
        for category in systemCategories + [.trash] {
            service.toggleCategorySelection(category, forceTo: selected)
        }
    }

    private func toggle(_ root: RootCategory) {
        let categories = root == .trash ? [.trash] : systemCategories
        let populated = categories.filter { !service.filesFor(category: $0).isEmpty }
        let target = !populated.allSatisfy(service.isCategoryAllSelected)
        for category in categories {
            service.toggleCategorySelection(category, forceTo: target)
        }
    }

    private func selectionState(for root: RootCategory) -> DetailSelectionState {
        let categories = root == .trash ? [.trash] : systemCategories
        let files = categories.flatMap { service.filesFor(category: $0) }
        guard !files.isEmpty else { return .none }
        let selected = files.filter(\.isSelected).count
        if selected == 0 { return .none }
        return selected == files.count ? .all : .partial
    }

    private func selectionState(for category: CleanerCategory) -> DetailSelectionState {
        let files = service.filesFor(category: category)
        guard !files.isEmpty else { return .none }
        let selected = files.filter(\.isSelected).count
        if selected == 0 { return .none }
        return selected == files.count ? .all : .partial
    }

    private func totalSize(for root: RootCategory) -> Int64 {
        let categories = root == .trash ? [.trash] : systemCategories
        return categories.reduce(0) { $0 + totalSize($1) }
    }

    private func totalSize(_ category: CleanerCategory) -> Int64 {
        service.filesFor(category: category).reduce(0) { $0 + $1.size }
    }

    private func sortedFiles(_ files: [CleanerFileItem]) -> [CleanerFileItem] {
        switch sortMode {
        case .size: return files.sorted { $0.size > $1.size }
        case .name: return files.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    private var sortTitle: String {
        switch sortMode {
        case .size: return localized("大小", "Size")
        case .name: return localized("名称", "Name")
        }
    }

    private func rootTitle(_ root: RootCategory) -> String {
        root == .systemJunk ? localized("系统垃圾", "System Junk") : localized("废纸篓", "Trash Bins")
    }

    private func rootDescription(_ root: RootCategory) -> String {
        root == .systemJunk
            ? localized("清理您的系统来获得最大的性能和释放自由空间。", "Clean your system for maximum performance and free space.")
            : localized("倾倒 Mac 上所有废纸篓，包括邮件和照片图库垃圾。", "Empty all Trash bins on your Mac, including Mail and Photos trash.")
    }

    private func categoryTitle(_ category: CleanerCategory) -> String {
        localized(category.rawValue, category.englishName)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func localized(_ chinese: String, _ english: String) -> String {
        loc.text(chinese, english)
    }

    private var panelGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.59, green: 0.46, blue: 0.70),
                Color(red: 0.43, green: 0.39, blue: 0.62),
                Color(red: 0.28, green: 0.30, blue: 0.51)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
