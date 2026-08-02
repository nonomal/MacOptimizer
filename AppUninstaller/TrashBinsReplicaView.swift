import AppKit
import SwiftUI

/// CleanMyMac X Trash Bins reconstruction. The visual states mirror the
/// locally installed application, while permanent deletion remains guarded by
/// an explicit confirmation and only successful filesystem removals disappear.
struct TrashBinsReplicaView: View {
    @ObservedObject private var scanner = ScanServiceManager.shared.trashScanner
    @ObservedObject private var loc = LocalizationManager.shared

    @State private var showingDetails = false
    @State private var selectedCategory: TrashCategory = .system
    @State private var searchText = ""
    @State private var sortBySize = true
    @State private var showEmptyConfirmation = false
    @State private var showCleaningFailure = false
    @State private var cleaningFinished = false
    @State private var cleanedAmount: Int64 = 0
    @State private var wasScanning = false
    @State private var orbHovered = false

    private enum PageState {
        case initial, scanning, results, cleaning, finished
    }

    private enum CheckState {
        case none, partial, all
    }

    private enum TrashCategory: String, CaseIterable, Identifiable {
        case system, external, mail
        var id: String { rawValue }
    }

    private enum OrbStyle {
        case scan, stop, empty
    }

    private var pageState: PageState {
        if scanner.isScanning { return .scanning }
        if scanner.isCleaning { return .cleaning }
        if cleaningFinished { return .finished }
        if scanner.hasCompletedScan || scanner.isStopped || !scanner.items.isEmpty { return .results }
        return .initial
    }

    private var selectedItems: [TrashItem] {
        scanner.items.filter(\.isSelected)
    }

    private var selectedSize: Int64 {
        selectedItems.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if pageState == .results && showingDetails {
                    detailsPage
                } else {
                    switch pageState {
                    case .initial: initialPage
                    case .scanning: scanningPage
                    case .results: resultsPage
                    case .cleaning: cleaningPage
                    case .finished: finishedPage
                    }
                }

                header.offset(x: -15)
                bottomAction
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .onAppear {
            selectedCategory = firstPopulatedCategory
        }
        .onReceive(scanner.$isScanning) { scanning in
            if wasScanning && !scanning && scanner.hasCompletedScan {
                selectedCategory = firstPopulatedCategory
                playCompletionSound()
            }
            wasScanning = scanning
        }
        .confirmationDialog(
            localized("确定清倒所选废纸篓？", "確定清空所選垃圾桶項目？", "Empty the selected Trash items?", "選択したゴミ箱の項目を完全に削除しますか？", "선택한 휴지통 항목을 완전히 비우시겠습니까?", "Удалить выбранные элементы из Корзины?"),
            isPresented: $showEmptyConfirmation,
            titleVisibility: .visible
        ) {
            Button(localized("永久清倒", "永久清空", "Empty Permanently", "完全に削除", "영구적으로 비우기", "Удалить навсегда"), role: .destructive) {
                performCleaning()
            }
            Button(localized("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(localized(
                "此操作不可撤销。只有成功永久删除的项目才会从结果中移除。",
                "此操作無法還原。只有成功永久刪除的項目才會從結果中移除。",
                "This cannot be undone. Only items permanently deleted successfully will be removed from the results.",
                "この操作は取り消せません。完全に削除できた項目のみ結果から除外されます。",
                "이 작업은 취소할 수 없습니다. 영구 삭제에 성공한 항목만 결과에서 제거됩니다.",
                "Это действие нельзя отменить. Из результатов исчезнут только успешно удалённые элементы."
            ))
        }
        .alert(localized("部分项目未能清倒", "部分項目未能清空", "Some items could not be emptied", "一部の項目を削除できませんでした", "일부 항목을 비우지 못했습니다", "Некоторые элементы не удалось удалить"), isPresented: $showCleaningFailure) {
            Button(localized("完成", "Done"), role: .cancel) {}
        } message: {
            Text(localized("这些项目可能正在使用中，或当前账户没有访问权限。", "這些項目可能正在使用中，或目前帳號沒有存取權限。", "These items may be in use or inaccessible to the current account.", "これらの項目は使用中か、現在のアカウントではアクセスできない可能性があります。", "이 항목은 사용 중이거나 현재 계정에서 접근할 수 없을 수 있습니다.", "Возможно, эти элементы используются или недоступны текущей учётной записи."))
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            ZStack {
                if pageState != .initial {
                    Text(localized("废纸篓", "Trash Bins"))
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
                            scanner.reset()
                            cleaningFinished = false
                            cleanedAmount = 0
                        }
                    }

                    Spacer()

                    if showingDetails {
                        searchField
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
        .buttonStyle(TrashHeaderButtonStyle())
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
            Spacer().frame(height: 134)

            HStack(alignment: .top, spacing: 26) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(localized("废纸篓", "Trash Bins"))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white.opacity(0.96))

                    Text(localized(
                        "清倒 Mac 上所有废纸篓，包括邮件和照片中的废纸篓。",
                        "清空 Mac 上所有垃圾桶，包括郵件和照片中的垃圾桶。",
                        "Empty all Trash on your Mac, including Mail and Photos trash.",
                        "メールや写真を含む、Mac上のすべてのゴミ箱を空にします。",
                        "Mail과 사진을 포함하여 Mac의 모든 휴지통을 비웁니다.",
                        "Очистите все Корзины на Mac, включая корзины Почты и Фото."
                    ))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.62))
                    .padding(.top, 9)

                    benefit(
                        image: "trash_benefit_empty",
                        title: localized("立即清倒所有废纸篓", "立即清空所有垃圾桶", "Empty all Trash instantly", "すべてのゴミ箱をすぐに空にする", "모든 휴지통 즉시 비우기", "Мгновенная очистка всех Корзин"),
                        description: localized(
                            "无需逐个浏览驱动器和应用来查找废纸篓。",
                            "無需逐一瀏覽磁碟和應用程式來尋找垃圾桶。",
                            "No need to browse drives and apps looking for their Trash.",
                            "ドライブやアプリごとにゴミ箱を探す必要はありません。",
                            "드라이브와 앱을 하나씩 확인하며 휴지통을 찾을 필요가 없습니다.",
                            "Не нужно искать Корзину отдельно на каждом диске и в каждом приложении."
                        )
                    )
                    .padding(.top, 39)

                    benefit(
                        image: "trash_benefit_finder",
                        title: localized("避免各种“访达”错误", "避免各種 Finder 錯誤", "Avoid all kinds of Finder errors", "Finderのさまざまなエラーを回避", "다양한 Finder 오류 방지", "Защита от ошибок Finder"),
                        description: localized(
                            "即使遇到问题，也能可靠地清倒废纸篓。",
                            "即使遇到問題，也能可靠地清空垃圾桶。",
                            "Make sure your Trash is emptied regardless of any issues.",
                            "問題があっても、ゴミ箱を確実に空にします。",
                            "문제가 있어도 휴지통을 확실하게 비웁니다.",
                            "Надёжно очищает Корзину даже при возникновении проблем."
                        )
                    )
                    .padding(.top, 41)
                }
                .frame(width: 310, alignment: .leading)
                .padding(.top, 45)

                trashImage(size: 315)
                    .padding(.top, 4)
            }
            .frame(width: 651, alignment: .leading)

            Spacer(minLength: 105)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func benefit(image: String, title: String, description: String) -> some View {
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
            Spacer().frame(height: 150)

            trashImage(size: 285)
                .modifier(TrashFloatMotion(active: true))

            Text(localized("正在计算废纸篓大小…", "正在計算垃圾桶大小…", "Calculating the size of Trash folders…", "ゴミ箱のサイズを計算中…", "휴지통 크기 계산 중…", "Вычисление размера Корзин…"))
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white.opacity(0.96))
                .padding(.top, 4)

            Text(scanner.currentScanPath)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.28))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 430)
                .padding(.top, 8)

            Text(localized("系统废纸篓", "System Trash"))
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.34))
                .padding(.top, 8)

            Spacer(minLength: 92)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(x: -15)
    }

    @ViewBuilder
    private var resultsPage: some View {
        if scanner.needsPermission && scanner.items.isEmpty {
            permissionPage
        } else if scanner.items.isEmpty {
            emptyResultPage
        } else {
            foundResultPage
        }
    }

    private var emptyResultPage: some View {
        HStack(spacing: 55) {
            trashImage(size: 370).offset(x: 14)

            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(Color(red: 0.39, green: 0.88, blue: 0.65))

                VStack(alignment: .leading, spacing: 6) {
                    Text(localized("非常干净！", "Very clean!"))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white.opacity(0.96))
                    Text(localized("所有废纸篓都是空的。", "所有垃圾桶都是空的。", "There are no files in any Trash folder.", "すべてのゴミ箱は空です。", "모든 휴지통이 비어 있습니다.", "Все Корзины пусты."))
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
            trashImage(size: 350)

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
                .foregroundColor(Color(red: 0.38, green: 0.84, blue: 0.97))
                .padding(.top, 15)

                Text(localized("智能选择", "Smart Selection"))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.48))
                    .padding(.top, 2)

                Text(localized("包括", "包括", "Including", "含まれる項目", "포함 항목", "Включая"))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.42))
                    .padding(.top, 14)

                Text("•    " + categoryTitle(firstPopulatedCategory))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.58))
                    .padding(.top, 7)

                HStack(spacing: 13) {
                    Button {
                        selectedCategory = firstPopulatedCategory
                        showingDetails = true
                    } label: {
                        Text(localized("查看项目", "Review Items"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.78))
                            .padding(.horizontal, 13)
                            .frame(height: 27)
                            .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(TrashHeaderButtonStyle())

                    Text(localized("共发现 ", "共找到 ", "Found ", "検出：", "발견: ", "Найдено: ") + formatBytes(scanner.totalSize))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.38))
                }
                .padding(.top, 25)
            }
            .frame(width: 355, alignment: .leading)
            .offset(y: -4)
        }
        .frame(width: 780, height: 390)
        .padding(.top, 104)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .offset(x: -15)
    }

    private var permissionPage: some View {
        HStack(spacing: 58) {
            trashImage(size: 350)

            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.white.opacity(0.78))
                Text(localized("授予完全磁盘访问权限以清理更多内容", "授予完整磁碟存取權限以清理更多內容", "Grant Full Disk Access to clean more", "フルディスクアクセスを許可して、さらにクリーニング", "전체 디스크 접근 권한을 허용하여 더 많이 정리", "Предоставьте полный доступ к диску для более полной очистки"))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white.opacity(0.96))
                Text(localized("Mac优化大师需要完全磁盘访问权限才能查找废纸篓。", "Mac最佳化大師需要完整磁碟存取權限才能尋找垃圾桶。", "MacOptimizer needs Full Disk Access to find Trash folders.", "ゴミ箱を検索するには、Macオプティマイザーにフルディスクアクセスが必要です。", "휴지통을 찾으려면 Mac 최적화 도구에 전체 디스크 접근 권한이 필요합니다.", "Для поиска Корзин MacOptimizer требуется полный доступ к диску."))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.52))
                    .fixedSize(horizontal: false, vertical: true)

                Button(localized("打开系统设置", "Open System Settings")) {
                    scanner.openSystemPreferences()
                }
                .buttonStyle(TrashPermissionButtonStyle())
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
            categoryPane.frame(width: 398)

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
                    setSelected(scanner.items, !anyItemsSelected)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.78))
                .buttonStyle(TrashHeaderButtonStyle())
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 5))

                Spacer()
                sortMenu
            }
            .padding(.horizontal, 10)
            .frame(height: 34)

            ScrollView(showsIndicators: true) {
                LazyVStack(spacing: 1) {
                    ForEach(visibleCategories) { category in
                        categoryRow(category)
                    }
                }
                .padding(.horizontal, 9)
            }

            Spacer(minLength: 45)
        }
    }

    private func categoryRow(_ category: TrashCategory) -> some View {
        let items = items(for: category)
        let isCurrent = selectedCategory == category

        return ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: 32, height: 60)
                    .allowsHitTesting(false)

                Button {
                    selectedCategory = category
                } label: {
                    HStack(spacing: 13) {
                        categoryIcon(category)
                        Text(categoryTitle(category))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.84))
                        Spacer()
                        Text(formatBytes(items.reduce(0) { $0 + $1.size }))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.76))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }

            CleanMyMacSelectionButton(rowHeight: 60) {
                setSelected(items, checkState(items) != .all)
            } indicator: {
                checkVisual(checkState(items))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 60)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isCurrent ? Color.black.opacity(0.22) : .clear)
        )
    }

    private var itemPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(categoryTitle(selectedCategory))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white.opacity(0.94))

                Text(categoryDescription(selectedCategory))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.67))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 10)
            .padding(.top, 5)
            .frame(height: 75, alignment: .top)

            HStack {
                Spacer()
                sortMenu
            }
            .padding(.horizontal, 13)
            .frame(height: 34)

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

    private func itemRow(_ item: TrashItem) -> some View {
        Button {
            scanner.toggleSelection(item)
        } label: {
            HStack(spacing: 11) {
                checkVisual(item.isSelected ? .all : .none)

                Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 27, height: 27)

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
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scanResultContextMenu(
            isSelected: item.isSelected,
            displayName: item.name,
            url: item.url,
            onToggleSelection: { scanner.toggleSelection(item) },
            onIgnore: {
                scanner.items.removeAll { $0.id == item.id }
                scanner.totalSize = scanner.items.reduce(0) { $0 + $1.size }
            }
        )
    }

    private var cleaningPage: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 126)

            trashImage(size: 285)
                .modifier(TrashFloatMotion(active: true))

            Text(localized("正在清倒废纸篓…", "正在清空垃圾桶…", "Emptying Trash…", "ゴミ箱を空にしています…", "휴지통 비우는 중…", "Очистка Корзины…"))
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white.opacity(0.96))
                .padding(.top, 4)

            Text(formatBytes(scanner.cleanedSize))
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
            trashImage(size: 370).offset(x: 14)

            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(Color(red: 0.39, green: 0.88, blue: 0.65))

                VStack(alignment: .leading, spacing: 6) {
                    Text(localized("清倒完成！", "垃圾桶已清空！", "Trash emptied!", "ゴミ箱を空にしました！", "휴지통을 비웠습니다!", "Корзина очищена!"))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white.opacity(0.96))
                    Text(localized("已释放 ", "已釋放 ", "Freed ", "解放した容量：", "확보한 공간: ", "Освобождено: ") + formatBytes(cleanedAmount))
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
                    orbButton(localized("清倒", "Empty"), style: .empty, disabled: selectedSize == 0) {
                        showEmptyConfirmation = true
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
                        Task { await scanner.scan() }
                    }
                case .scanning:
                    orbButton(localized("停止", "Stop"), style: .stop) {
                        scanner.stopScan()
                    }
                case .results:
                    orbButton(localized("清倒", "Empty"), style: .empty, disabled: selectedSize == 0) {
                        showEmptyConfirmation = true
                    }
                case .cleaning:
                    orbButton(localized("停止", "Stop"), style: .stop) {
                        scanner.stopCleaning()
                    }
                case .finished:
                    EmptyView()
                }
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
        .buttonStyle(TrashOrbPressStyle())
        .disabled(disabled)
        .onHover { orbHovered = $0 }
    }

    private func orbGradient(_ style: OrbStyle) -> LinearGradient {
        switch style {
        case .scan, .empty:
            return LinearGradient(colors: [Color(red: 0.40, green: 0.76, blue: 0.84), Color(red: 0.29, green: 0.46, blue: 0.65)], startPoint: .top, endPoint: .bottom)
        case .stop:
            return LinearGradient(colors: [Color(red: 0.66, green: 0.39, blue: 0.68), Color(red: 0.40, green: 0.32, blue: 0.56)], startPoint: .top, endPoint: .bottom)
        }
    }

    private func orbGlow(_ style: OrbStyle) -> Color {
        style == .stop ? Color(red: 0.83, green: 0.45, blue: 0.85) : Color(red: 0.31, green: 0.86, blue: 0.95)
    }

    private func orbRing(_ style: OrbStyle) -> Color {
        style == .stop ? Color(red: 0.91, green: 0.64, blue: 0.93) : Color(red: 0.55, green: 0.94, blue: 0.97)
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

    private var filteredItems: [TrashItem] {
        var result = items(for: selectedCategory)
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.url.path.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result.sorted {
            sortBySize ? $0.size > $1.size : $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private var anyItemsSelected: Bool {
        scanner.items.contains(where: \.isSelected)
    }

    private var visibleCategories: [TrashCategory] {
        let populated = TrashCategory.allCases.filter { !items(for: $0).isEmpty }
        return populated.isEmpty ? [.system] : populated
    }

    private var firstPopulatedCategory: TrashCategory {
        TrashCategory.allCases.first(where: { !items(for: $0).isEmpty }) ?? .system
    }

    private func items(for category: TrashCategory) -> [TrashItem] {
        scanner.items.filter { item in
            let path = item.url.path.lowercased()
            switch category {
            case .external:
                return path.hasPrefix("/volumes/")
            case .mail:
                return path.contains("/library/mail/") || path.contains("maildata")
            case .system:
                return !path.hasPrefix("/volumes/") && !path.contains("/library/mail/") && !path.contains("maildata")
            }
        }
    }

    private func categoryTitle(_ category: TrashCategory) -> String {
        switch category {
        case .system: return localized("Mac 上的废纸篓", "Mac 上的垃圾桶", "Trash on Mac", "Macのゴミ箱", "Mac 휴지통", "Корзина Mac")
        case .external: return localized("外置驱动器", "外接磁碟", "External Drives", "外部ドライブ", "외장 드라이브", "Внешние диски")
        case .mail: return localized("本地邮件废纸篓", "本機郵件垃圾桶", "Local Mail Trash", "ローカルメールのゴミ箱", "로컬 메일 휴지통", "Локальная корзина Почты")
        }
    }

    private func categoryDescription(_ category: TrashCategory) -> String {
        switch category {
        case .system:
            return localized("系统废纸篓储存先前删除的项目，但它们仍占用磁盘空间。", "系統垃圾桶儲存先前刪除的項目，但它們仍占用磁碟空間。", "The system Trash stores previously deleted items, but they still take up disk space.", "システムのゴミ箱には以前削除した項目が保存され、ディスク容量を使用し続けます。", "시스템 휴지통에는 이전에 삭제한 항목이 저장되어 계속 디스크 공간을 차지합니다.", "В системной Корзине хранятся удалённые элементы, и они продолжают занимать место на диске.")
        case .external:
            return localized("外置驱动器有自己的废纸篓，用于储存先前删除的项目。", "外接磁碟有自己的垃圾桶，用於儲存先前刪除的項目。", "External drives have their own Trash folders for previously deleted items.", "外部ドライブには、以前削除した項目を保存する専用のゴミ箱があります。", "외장 드라이브에는 이전에 삭제한 항목을 보관하는 자체 휴지통이 있습니다.", "На внешних дисках есть собственные Корзины для ранее удалённых элементов.")
        case .mail:
            return localized("在邮件应用中删除的邮件会移到本地邮件废纸篓，因此仍保留在磁盘上。", "在郵件應用程式中刪除的郵件會移到本機郵件垃圾桶，因此仍保留在磁碟上。", "Deleted email is moved to a local Mail Trash folder and remains on disk.", "メールアプリで削除したメールはローカルのメールゴミ箱に移動され、ディスクに残ります。", "메일 앱에서 삭제한 이메일은 로컬 메일 휴지통으로 이동되어 디스크에 남아 있습니다.", "Удалённые письма перемещаются в локальную корзину Почты и остаются на диске.")
        }
    }

    private func categoryIcon(_ category: TrashCategory) -> some View {
        Group {
            switch category {
            case .system:
                Image(nsImage: NSWorkspace.shared.icon(forFile: scanner.trashURL.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            case .external:
                Image(systemName: "externaldrive.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.white.opacity(0.82))
            case .mail:
                Image(systemName: "envelope.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.white.opacity(0.82))
            }
        }
        .frame(width: 32, height: 32)
    }

    private func setSelected(_ items: [TrashItem], _ selected: Bool) {
        let ids = Set(items.map(\.id))
        for index in scanner.items.indices where ids.contains(scanner.items[index].id) {
            scanner.items[index].isSelected = selected
        }
    }

    private func checkState(_ items: [TrashItem]) -> CheckState {
        let selected = items.filter(\.isSelected).count
        if selected == 0 { return .none }
        return selected == items.count ? .all : .partial
    }

    private func checkVisual(_ state: CheckState) -> some View {
        ZStack {
            Circle()
                .fill(state == .none ? Color.clear : Color(red: 0.38, green: 0.88, blue: 0.97))
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

    private func performCleaning() {
        let amountBeforeCleaning = selectedSize
        guard amountBeforeCleaning > 0 else { return }
        showingDetails = false

        Task {
            let removed = await scanner.emptyTrash()
            cleanedAmount = removed

            if scanner.failedDeletionCount > 0 {
                showCleaningFailure = true
                return
            }
            guard !scanner.cleaningWasStopped else { return }

            cleaningFinished = true
            playCompletionSound()
        }
    }

    private func playCompletionSound() {
        guard let url = Bundle.main.url(forResource: "CleanDidFinish", withExtension: "m4a") else { return }
        NSSound(contentsOf: url, byReference: false)?.play()
    }

    private func trashImage(size: CGFloat) -> some View {
        resourceImage("trash_bins_module")
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
                Image(systemName: "trash.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.green)
            }
        }
    }

    private func formattedSizeParts(_ bytes: Int64) -> (value: String, unit: String) {
        let parts = formatBytes(bytes).split(separator: " ", maxSplits: 1).map(String.init)
        return (parts.first ?? "0", parts.count > 1 ? parts[1] : "")
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func localized(_ chinese: String, _ english: String) -> String {
        loc.text(chinese, english)
    }

    private func localized(
        _ simplifiedChinese: String,
        _ traditionalChinese: String,
        _ english: String,
        _ japanese: String,
        _ korean: String,
        _ russian: String
    ) -> String {
        loc.text(
            simplifiedChinese: simplifiedChinese,
            traditionalChinese: traditionalChinese,
            english: english,
            japanese: japanese,
            korean: korean,
            russian: russian
        )
    }
}

private struct TrashFloatMotion: ViewModifier {
    let active: Bool
    @State private var phase = false

    func body(content: Content) -> some View {
        content
            .offset(y: active && phase ? -4 : 3)
            .scaleEffect(active && phase ? 1.012 : 0.995)
            .animation(active ? .easeInOut(duration: 0.76).repeatForever(autoreverses: true) : .default, value: phase)
            .onAppear { phase = active }
            .onChange(of: active) { phase = $0 }
    }
}

private struct TrashOrbPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.958 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.easeOut(duration: 0.09), value: configuration.isPressed)
    }
}

private struct TrashHeaderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.62 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

private struct TrashPermissionButtonStyle: ButtonStyle {
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
    }
}
