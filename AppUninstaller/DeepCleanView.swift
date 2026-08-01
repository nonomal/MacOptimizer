import SwiftUI

// MARK: - Deep Clean States
enum DeepCleanState {
    case initial
    case scanning
    case results
    case cleaning
    case finished
}

struct DeepCleanView: View {
    @Binding var selectedModule: AppModule
    @ObservedObject private var scanner = ScanServiceManager.shared.deepCleanScanner
    @State private var viewState: DeepCleanState = .initial
    @State private var showingDetails = false
    @State private var selectedCategoryForDetails: DeepCleanCategory?
    @ObservedObject private var loc = LocalizationManager.shared
    
    // Alert States
    @State private var showCleanConfirmation = false
    @State private var cleanResult: (count: Int, size: Int64)?
    
    var body: some View {
        ZStack {
            VStack {
                 switch viewState {
                 case .initial:
                     initialView.padding(.bottom, 100)
                 case .scanning:
                     scanningView.padding(.bottom, 100)
                 case .results:
                     resultsView.padding(.bottom, 100)
                 case .cleaning:
                     cleaningView.padding(.bottom, 100)
                 case .finished:
                     finishedView.padding(.bottom, 100)
                 }
            }
            
            // Fixed Bottom Action Button Overlay
            CleanMyMacBottomActionSlot {
                mainActionButton
            }
        }
        .onAppear {
            // Sync state if already scanning
            if scanner.isScanning {
                viewState = .scanning
            } else if scanner.isCleaning {
                viewState = .cleaning
            } else if scanner.totalSize > 0 && viewState == .initial {
                 viewState = .results // Resume results if available
            }
        }
        .onChange(of: scanner.isScanning) { isScanning in
             if isScanning { viewState = .scanning }
             else if scanner.totalSize > 0 { viewState = .results }
        }
        .onChange(of: scanner.isCleaning) { newValue in
             if newValue {
                 viewState = .cleaning
             } else if viewState == .cleaning {
                 // 清理完成，切换到完成页面
                 viewState = .finished
             }
        }
        .sheet(isPresented: $showingDetails) {
            DeepCleanDetailView(scanner: scanner, category: selectedCategoryForDetails, isPresented: $showingDetails)
        }
        .confirmationDialog(loc.L("confirm_clean"), isPresented: $showCleanConfirmation) {
            Button(loc.text(
    simplifiedChinese: "开始清理",
    traditionalChinese: "開始清理",
    english: "Start Cleaning",
    japanese: "清掃を開始",
    korean: "청소 시작",
    russian: "Начало уборки"
), role: .destructive) {
                Task { @MainActor in
                    let result = await scanner.cleanSelected()
                    cleanResult = result
                }
            }
            Button(loc.L("cancel"), role: .cancel) {}
        } message: {
            Text(loc.text(
    simplifiedChinese: "确定要清理选中的 \(scanner.selectedCount) 个项目吗？总大小 \(ByteCountFormatter.string(fromByteCount: scanner.selectedSize, countStyle: .file))",
    traditionalChinese: "確定要清理選取的\(scanner.selectedCount)個項目嗎？總大小\(ByteCountFormatter.string(fromByteCount: scanner.selectedSize, countStyle: .file))",
    english: "Are you sure you want to clean \(scanner.selectedCount) selected items? Total size: \(ByteCountFormatter.string(fromByteCount: scanner.selectedSize, countStyle: .file))",
    japanese: "\(scanner.selectedCount) 選択したアイテムをクリーニングしてもよろしいですか？合計サイズ： \(ByteCountFormatter.string(fromByteCount: scanner.selectedSize, countStyle: .file))",
    korean: "\(scanner.selectedCount) 선택한 품목을 청소하시겠습니까? 총 크기: \(ByteCountFormatter.string(fromByteCount: scanner.selectedSize, countStyle: .file))",
    russian: "Вы уверены, что хотите очистить \(scanner.selectedCount) выбранные элементы? Общий размер: \(ByteCountFormatter.string(fromByteCount: scanner.selectedSize, countStyle: .file))"
))
        }
    }
    
    // MARK: - Main Action Button (Unified)
    @ViewBuilder
    private var mainActionButton: some View {
        switch viewState {
        case .initial:
            deepCleanOrb(
                title: loc.text(
    simplifiedChinese: "扫描",
    traditionalChinese: "掃描",
    english: "Scan",
    japanese: "スキャン",
    korean: "스캔",
    russian: "Сканировать"
),
                colors: [Color(hex: "007AFF"), Color(hex: "0055D4")],
                glow: Color(hex: "0A84FF"),
                ring: Color.white.opacity(0.60)
            ) {
                Task { await scanner.startScan() }
            }
            .transition(.scale.combined(with: .opacity))
            
        case .scanning:
            CleanMyMacBottomActionCluster {
                deepCleanOrb(
                    title: loc.text(
    simplifiedChinese: "停止",
    traditionalChinese: "停止",
    english: "Stop",
    japanese: "停止",
    korean: "정지",
    russian: "Остановить"
),
                    colors: [Color(hex: "5E5CE6"), Color(hex: "3A3A8A")],
                    glow: Color(hex: "7D7AFF"),
                    ring: Color.white.opacity(0.62),
                    progress: scanner.scanProgress
                ) {
                    scanner.stopScan()
                    viewState = .initial
                }
            } accessory: {
                Text(ByteCountFormatter.string(fromByteCount: scanner.totalSize, countStyle: .file))
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, y: 1)
            }
            
        case .results:
            CleanMyMacBottomActionCluster {
                deepCleanOrb(
                    title: loc.text(
    simplifiedChinese: "清理",
    traditionalChinese: "清理",
    english: "Clean",
    japanese: "洗う",
    korean: "지우기",
    russian: "Очистить"
),
                    colors: [Color(hex: "34C759"), Color(hex: "248A3D")],
                    glow: Color(hex: "34C759"),
                    ring: Color.white.opacity(0.46),
                    disabled: scanner.selectedCount == 0
                ) {
                    showCleanConfirmation = true
                }
            } accessory: {
                if scanner.selectedCount > 0 {
                    Text(ByteCountFormatter.string(fromByteCount: scanner.selectedSize, countStyle: .file))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "40C4FF"))
                }
            }
            
        case .finished:
            deepCleanOrb(
                title: loc.text(
    simplifiedChinese: "完成",
    traditionalChinese: "完成",
    english: "Done",
    japanese: "完了",
    korean: "완료",
    russian: "Готово"
),
                colors: [Color(hex: "34C759"), Color(hex: "248A3D")],
                glow: Color(hex: "34C759"),
                ring: Color.white.opacity(0.46)
            ) {
                withAnimation {
                    viewState = .initial
                    scanner.reset()
                    cleanResult = nil
                }
            }
            
        default:
            EmptyView()
        }
    }

    private func deepCleanOrb(
        title: String,
        colors: [Color],
        glow: Color,
        ring: Color,
        disabled: Bool = false,
        progress: Double? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            CleanMyMacActionOrb(
                title: title,
                gradient: LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom),
                glowColor: glow,
                ringColor: ring,
                disabled: disabled,
                progress: progress
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
    
    // MARK: - 1. Initial View (初始化页面)
    var initialView: some View {
        HStack(spacing: 60) {
            // Left Content
            VStack(alignment: .leading, spacing: 30) {
                // Branding Header
                HStack(spacing: 8) {
                    Text(loc.text(
    simplifiedChinese: "深度系统清理",
    traditionalChinese: "深度系統清理",
    english: "Deep System Clean",
    japanese: "ディープシステムクリーン",
    korean: "딥 시스템 클린",
    russian: "Глубокая очистка системы"
))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    // Magnifying Glass Icon
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass.circle.fill")
                        Text(loc.text(
    simplifiedChinese: "全面扫描",
    traditionalChinese: "全面掃描",
    english: "Full Scan",
    japanese: "フルスキャン",
    korean: "전체 스캔",
    russian: "Full Scan"
))
                            .font(.system(size: 20, weight: .heavy))
                    }
                    .foregroundColor(.white)
                }
                
                Text(loc.text(
    simplifiedChinese: "扫描整个 Mac 的大文件、垃圾文件、缓存、日志及应用残留。\n上次扫描时间：从未",
    traditionalChinese: "掃描整個Mac 的大檔案、垃圾檔案、快取、日誌及應用殘留。\n上次掃描時間：從未",
    english: "Scan your entire Mac for large files, junk, caches, logs, and leftovers.\nLast scan: Never",
    japanese: "Mac全体をスキャンして、大きなファイル、ジャンク、キャッシュ、ログ、残り物を探します。\n前回のスキャン：なし",
    korean: "Mac 전체에서 대용량 파일, 정크, 캐시, 로그 및 남은 파일을 검사합니다.\n마지막 스캔: 없음",
    russian: "Сканируйте весь Mac на наличие больших файлов, ненужных файлов, кэшей, журналов и остатков.\nПоследнее сканирование: Никогда"
))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                    .lineSpacing(4)
                
                // Feature Rows
                VStack(alignment: .leading, spacing: 24) {
                    featureRow(
                        icon: "doc.text.magnifyingglass",
                        title: loc.text(
    simplifiedChinese: "查找大文件",
    traditionalChinese: "查找大文件",
    english: "Find Large Files",
    japanese: "巨大化ファイル",
    korean: "대용량 파일",
    russian: "Найти большие файлы"
),
                        desc: loc.text(
    simplifiedChinese: "快速定位占用空间的大文件和旧文件。",
    traditionalChinese: "快速定位佔用空間的大文件和舊文件。",
    english: "Quickly locate large and old files taking up space.",
    japanese: "スペースを占有している大きなファイルや古いファイルをすばやく見つけます。",
    korean: "공간을 차지하는 크고 오래된 파일을 빠르게 찾을 수 있습니다.",
    russian: "Быстро находите большие и старые файлы, занимающие место."
)
                    )
                    
                    featureRow(
                        icon: "trash.circle",
                        title: loc.text(
    simplifiedChinese: "清理系统垃圾",
    traditionalChinese: "清理系統垃圾",
    english: "Clean System Junk",
    japanese: "クリーンなシステムのジャンク",
    korean: "시스템을 청소하십시오.",
    russian: "чистая установка"
),
                        desc: loc.text(
    simplifiedChinese: "移除缓存、日志和临时文件释放空间。",
    traditionalChinese: "移除快取、日誌和臨時檔案釋放空間。",
    english: "Remove caches, logs and temp files to free up space.",
    japanese: "キャッシュ、ログ、一時ファイルを削除して、スペースを解放します。",
    korean: "캐시, 로그 및 임시 파일을 제거하여 공간을 확보하십시오.",
    russian: "Удалите кэши, журналы и временные файлы, чтобы освободить место."
)
                    )
                    
                    featureRow(
                        icon: "app.badge",
                        title: loc.text(
    simplifiedChinese: "检测应用残留",
    traditionalChinese: "檢測應用殘留",
    english: "Detect App Residuals",
    japanese: "アプリの残留物を検出する",
    korean: "앱 잔여 감지",
    russian: "Обнаружение остатков приложения"
),
                        desc: loc.text(
    simplifiedChinese: "查找已卸载应用遗留的文件和数据。",
    traditionalChinese: "尋找已卸載應用程式遺留的檔案和資料。",
    english: "Find files and data left behind by uninstalled apps.",
    japanese: "アンインストールされたアプリによって残されたファイルやデータを見つけます。",
    korean: "제거된 앱이 남긴 파일과 데이터를 찾으세요.",
    russian: "Поиск файлов и данных, оставленных удаленными приложениями."
)
                    )
                }
                
                // Configure Button (Cyan)
                Button(action: {}) {
                    Text(loc.text(
    simplifiedChinese: "配置扫描选项...",
    traditionalChinese: "配置掃描選項...",
    english: "Configure Scan Options...",
    japanese: "スキャンオプションの設定...",
    korean: "스캔 옵션 구성...",
    russian: "Настроить параметры сканирования..."
))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: "4DDEE8")) // Cyan
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }
            .frame(maxWidth: 400)
            
            // Right Icon - Using shenduqingli.png
            ZStack {
                if let path = Bundle.main.path(forResource: "shenduqingli", ofType: "png"),
                   let nsImage = NSImage(contentsOfFile: path) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 320, height: 320)
                        .shadow(color: Color.black.opacity(0.3), radius: 20, y: 10)
                } else {
                    // Fallback
                    RoundedRectangle(cornerRadius: 40)
                        .fill(LinearGradient(
                            colors: [Color(hex: "00B4D8"), Color(hex: "0077B6")],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: 280, height: 280)
                        .overlay(
                            Image(systemName: "magnifyingglass.circle.fill")
                                .font(.system(size: 100))
                                .foregroundColor(.white)
                        )
                }
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 50)
    }
    
    // MARK: - Feature Row Helper
    private func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    // MARK: - 2. Scanning View (扫描中页面 - 铺满布局)
    var scanningView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // 自适应网格布局
            VStack(spacing: 20) {
                // Row 1: Large Files, System Junk, Log Files (铺满)
                HStack(spacing: 20) {
                    scanningCategoryCard(for: .largeFiles)
                    scanningCategoryCard(for: .junkFiles)
                    scanningCategoryCard(for: .systemLogs)
                }
                
                // Row 2: Caches, Residue (铺满左右)
                HStack(spacing: 20) {
                    scanningCategoryCard(for: .systemCaches)
                    scanningCategoryCard(for: .appResiduals)
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            Spacer()
            
            // Current scanning path
            Text(scanner.currentScanningUrl)
                .font(.caption)
                .foregroundColor(.secondaryText.opacity(0.6))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
                .frame(height: 20)
        }
    }
    
    // MARK: - Scanning Card (图片背景卡片 - 自适应宽度)
    func scanningCategoryCard(for category: DeepCleanCategory) -> some View {
        let isCompleted = scanner.completedCategories.contains(category)
        let isCurrent = scanner.currentCategory == category && scanner.isScanning && !isCompleted
        
        return ZStack(alignment: .topLeading) {
            // 图片作为整个卡片的背景
            GeometryReader { geometry in
                if let imageName = getCategoryImageName(category),
                   let nsImage = NSImage(named: imageName) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: 240)
                        .clipped()
                        .scaleEffect(isCurrent ? 1.05 : 1.0)
                        .animation(isCurrent ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: isCurrent)
                } else {
                    // 后备方案：渐变背景
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    getCategoryGradientTop(category),
                                    getCategoryGradientBottom(category)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: geometry.size.width, height: 240)
                        .overlay(
                            Image(systemName: getCategoryCustomIcon(category))
                                .font(.system(size: 80, weight: .medium))
                                .foregroundColor(.white.opacity(0.3))
                        )
                }
            }
            
            // 底部渐变遮罩（让文字更清晰）
            VStack {
                Spacer()
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 100)
            }
            
            // 左上角标记（参考设计图 - 所有卡片都显示）
            HStack(spacing: 8) {
                // 完成后显示勾选标记
                if isCompleted {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                // 分类名称（所有卡片都显示）
                Text(category.localizedName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            .padding(.leading, 16)
            .padding(.top, 16)
            
            // 扫描中的脉动边框
            if isCurrent {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(getCategoryGradientTop(category), lineWidth: 3)
                    .scaleEffect(1.05)
                    .opacity(0)
                    .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: isCurrent)
            }
            
            // 底部文字信息（统一样式）
            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    // 主要文字（文件大小或状态）
                    if isCompleted {
                        // 只统计选中的项目
                        let categoryItems = scanner.items.filter { $0.category == category && $0.isSelected }
                        let size = categoryItems.reduce(0) { $0 + $1.size }
                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                        
                        let itemCount = categoryItems.count
                        Text(loc.text(
    simplifiedChinese: "\(itemCount) 项",
    traditionalChinese: "\(itemCount)項",
    english: "\(itemCount) items",
    japanese: "項目",
    korean: "\(itemCount) 항목",
    russian: "\(itemCount) items"
))
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.85))
                            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                    } else if isCurrent {
                        Text(loc.text(
    simplifiedChinese: "扫描中...",
    traditionalChinese: "掃描中...",
    english: "Scanning...",
    japanese: "実行中…",
    korean: "스캔 중...",
    russian: "Сканирование..."
))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                        
                        // 显示当前扫描路径
                        if !scanner.currentScanningUrl.isEmpty {
                            Text(scanner.currentScanningUrl)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                        }
                    } else {
                        Text(loc.text(
    simplifiedChinese: "等待中...",
    traditionalChinese: "等待中...",
    english: "Waiting...",
    japanese: "待機中…",
    korean: "기다리는 중...",
    russian: "Ожидание..."
))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 240)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
    
    // MARK: - 3. Results View (扫描结果页面 - 与扫描中页面布局完全一致)
    var resultsView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // 大卡片网格（与扫描中页面完全一致的布局）
            VStack(spacing: 20) {
                // Row 1: 三张卡片铺满
                HStack(spacing: 20) {
                    resultCategoryCard(for: .largeFiles)
                    resultCategoryCard(for: .junkFiles)
                    resultCategoryCard(for: .systemLogs)
                }
                
                // Row 2: 两张卡片铺满左右
                HStack(spacing: 20) {
                    resultCategoryCard(for: .systemCaches)
                    resultCategoryCard(for: .appResiduals)
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            Spacer()
        }
    }
    
    // MARK: - Result Card (与扫描中页面完全一致)
    func resultCategoryCard(for category: DeepCleanCategory) -> some View {
        // 只统计选中的项目，这样用户取消勾选时卡片数字会变化
        let items = scanner.items.filter { $0.category == category && $0.isSelected }
        let totalSize = items.reduce(0) { $0 + $1.size }
        let isCompleted = !scanner.items.filter { $0.category == category }.isEmpty // 只要分类下有项目（不管有没有选中）就显示完成态
        
        return ZStack(alignment: .topLeading) {
                // 图片作为整个卡片的背景
                GeometryReader { geometry in
                    if let imageName = getCategoryImageName(category),
                       let nsImage = NSImage(named: imageName) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: 240)
                            .clipped()
                    } else {
                        // 后备方案：渐变背景
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        getCategoryGradientTop(category),
                                        getCategoryGradientBottom(category)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: geometry.size.width, height: 240)
                            .overlay(
                                Image(systemName: getCategoryCustomIcon(category))
                                    .font(.system(size: 80, weight: .medium))
                                    .foregroundColor(.white.opacity(0.3))
                            )
                    }
                }
                .allowsHitTesting(false) // 让点击穿透到下层的按钮
                
                // 底部渐变遮罩（和扫描中一致）
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, Color.black.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 100)
                }
                .allowsHitTesting(false) // 让点击穿透到下层的按钮
                
                // 左上角标记（和扫描中完全一致）
                HStack(spacing: 8) {
                    // 勾选标记（所有卡片都显示）
                    if isCompleted {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.25))
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    
                    // 分类名称
                    Text(category.localizedName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
                .padding(.leading, 16)
                .padding(.top, 16)
                
                // 底部文字信息（和扫描中完全一致）
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                            
                            Text(loc.text(
    simplifiedChinese: "\(items.count) 项",
    traditionalChinese: "\(items.count)項",
    english: "\(items.count) items",
    japanese: "項目",
    korean: "\(items.count) 항목",
    russian: "\(items.count) items"
))
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.85))
                                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                        }
                        
                        Spacer()
                        
                        // 右下角"查看详情"按钮
                        Button(action: {
                            selectedCategoryForDetails = category
                            showingDetails = true
                        }) {
                            Text(loc.text(
    simplifiedChinese: "查看详情",
    traditionalChinese: "查看詳情",
    english: "View Details",
    japanese: "詳細を表示",
    korean: "세부 정보 보기",
    russian: "Посмотреть детали"
))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.2))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 240)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
    
    // MARK: - 4. Cleaning View (类似智能扫描的清理页面)
    var cleaningView: some View {
        VStack {
            Spacer().frame(height: 60)
            
            HStack(spacing: 80) {
                // Left: Current Category Image
                Group {
                    if let category = scanner.cleaningCurrentCategory {
                        let imageName = getCategoryImageName(category)
                        if let imageName = imageName,
                           let nsImage = NSImage(named: imageName) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 240, height: 240)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .move(edge: .top).combined(with: .opacity)
                                ))
                                .id(category) // unique ID triggers transition
                                .modifier(CleaningLargeIconAnimation())
                        } else {
                            Image(systemName: "gearshape.2.fill")
                                .font(.system(size: 120))
                                .foregroundColor(.blue)
                        }
                    } else {
                        // Fallback
                        ProgressView()
                            .scaleEffect(2.0)
                            .frame(width: 240, height: 240)
                    }
                }
                .animation(.easeInOut(duration: 0.6), value: scanner.cleaningCurrentCategory)
                .frame(width: 300)
                
                // Right: Text & Task List
                VStack(alignment: .leading, spacing: 30) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(loc.text(
    simplifiedChinese: "正在清理系统...",
    traditionalChinese: "正在清理系統...",
    english: "Cleaning System...",
    japanese: "システムのクリーニング",
    korean: "세척 시스템(cleaning system)",
    russian: "Процедура уборки"
))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(loc.text(
    simplifiedChinese: "正在移除不需要的文件，优化您的 Mac。",
    traditionalChinese: "正在移除不需要的文件，優化您的Mac。",
    english: "Removing unwanted files and optimizing your Mac.",
    japanese: "不要なファイルを削除し、Macを最適化します。",
    korean: "원치 않는 파일을 제거하고 Mac을 최적화합니다.",
    russian: "Удаление нежелательных файлов и оптимизация Mac."
))
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    VStack(spacing: 16) {
                        // Only show categories with selected items (只显示有选中项目的分类)
                        let allCategories: [DeepCleanCategory] = [.junkFiles, .systemLogs, .systemCaches, .appResiduals, .largeFiles]
                        let categoriesToShow = allCategories.filter { cat in
                            scanner.items.contains { $0.category == cat && $0.isSelected }
                        }
                        
                        ForEach(categoriesToShow, id: \.self) { cat in
                            let isActive = scanner.cleaningCurrentCategory == cat
                            let isDone = scanner.cleanedCategories.contains(cat)
                            
                            HStack(spacing: 12) {
                                // Icon Circle
                                ZStack {
                                    Circle()
                                        .fill(getCategoryGradientTop(cat).opacity(0.2))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: cat.icon)
                                        .font(.system(size: 14))
                                        .foregroundColor(getCategoryGradientTop(cat))
                                }
                                
                                Text(cat.localizedName)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                if isActive {
                                    Text(scanner.cleaningDescription)
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.4))
                                    ProgressView()
                                        .scaleEffect(0.5)
                                        .frame(width: 20, height: 20)
                                } else if isDone {
                                    Text(ByteCountFormatter.string(fromByteCount: scanner.sizeFor(category: cat), countStyle: .file))
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.4))
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.green)
                                } else {
                                    Text("...")
                                        .foregroundColor(.white.opacity(0.2))
                                }
                            }
                            .frame(width: 340)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 500)
            
            Spacer()
        }
    }
    
    // MARK: - 5. Finished View (类似智能扫描的完成页面)
    var finishedView: some View {
        VStack {
            Spacer().frame(height: 100)
            
            HStack(spacing: 60) {
                // Left: Hero Image
                if let imagePath = Bundle.main.path(forResource: "welcome", ofType: "png"),
                   let nsImage = NSImage(contentsOfFile: imagePath) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 500, height: 500)
                } else {
                    Image(systemName: "desktopcomputer")
                        .resizable()
                        .frame(width: 300, height: 300)
                        .foregroundColor(.pink)
                }
                
                // Right: Results
                VStack(alignment: .leading, spacing: 30) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(loc.text(
    simplifiedChinese: "做得不错！",
    traditionalChinese: "做得很好！",
    english: "Well done!",
    japanese: "お疲れさまです！",
    korean: "잘하셨어요!",
    russian: "Отличный результат!"
))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        Text(loc.text(
    simplifiedChinese: "您的 Mac 状态很好。",
    traditionalChinese: "您的Mac 狀態很好。",
    english: "Your Mac is in good shape.",
    japanese: "お使いのMacは良好な状態です。",
    korean: "Mac의 상태가 양호합니다.",
    russian: "Ваш Mac в хорошей форме."
))
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    VStack(spacing: 12) {
                        // 1. Deep Cleanup Result
                        DeepCleanResultRow(
                            icon: getCategoryImageName(.junkFiles) ?? "system_clean",
                            title: loc.text(
    simplifiedChinese: "深度清理",
    traditionalChinese: "深度清理",
    english: "Deep Clean",
    japanese: "ディープクリーン",
    korean: "철저한 세척",
    russian: "Глубокая очистка"
),
                            subtitle: loc.text(
    simplifiedChinese: "不需要的文件已移除",
    traditionalChinese: "不需要的文件已移除",
    english: "Files removed",
    japanese: "削除されたファイル",
    korean: "파일 제거됨",
    russian: "Файлов удалено"
),
                            stat: ByteCountFormatter.string(fromByteCount: scanner.cleanedSize, countStyle: .file)
                        )
                        
                        // 2. Items Cleaned
                        if let result = cleanResult {
                            DeepCleanResultRow(
                                icon: "trash.fill",
                                title: loc.text(
    simplifiedChinese: "清理项目",
    traditionalChinese: "清理項目",
    english: "Items Cleaned",
    japanese: "掃除されたアイテム",
    korean: "청소한 물품",
    russian: "Элементы очищены"
),
                                subtitle: loc.text(
    simplifiedChinese: "已成功清理",
    traditionalChinese: "已成功清理",
    english: "Successfully cleaned",
    japanese: "正常にクリーニングされました",
    korean: "성공적으로 청소 완료",
    russian: "успешно очищен!"
),
                                stat: "\(result.count) " + (loc.text(
    simplifiedChinese: "个项目",
    traditionalChinese: "個項目",
    english: "items",
    japanese: "項目数",
    korean: "아이템",
    russian: "Объявления"
))
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 550)
            
            Spacer()

            Spacer()
        } // End VStack
        // Overlay removed (Moved to main ZStack)

    }
    
    // MARK: - 辅助函数
    private func getCategoryGradientTop(_ category: DeepCleanCategory) -> Color {
        switch category {
        case .largeFiles: return Color(hex: "FF6B9D") // 粉红
        case .junkFiles: return Color(hex: "FF5757") // 红色
        case .systemLogs: return Color(hex: "5B9BD5") // 蓝色
        case .systemCaches: return Color(hex: "70C1B3") // 青色
        case .appResiduals: return Color(hex: "FFD93D") // 黄色
        }
    }
    
    private func getCategoryGradientBottom(_ category: DeepCleanCategory) -> Color {
        switch category {
        case .largeFiles: return Color(hex: "C23B8C") // 深粉
        case .junkFiles: return Color(hex: "B80F0A") // 深红
        case .systemLogs: return Color(hex: "2E5C8A") // 深蓝
        case .systemCaches: return Color(hex: "29A39B") // 深青
        case .appResiduals: return Color(hex: "F77F00") // 橙色
        }
    }
    
    private func getCategoryCustomIcon(_ category: DeepCleanCategory) -> String {
        switch category {
        case .largeFiles: return "doc.fill"
        case .junkFiles: return "trash.fill"
        case .systemLogs: return "doc.text.fill"
        case .systemCaches: return "server.rack"
        case .appResiduals: return "app.badge"
        }
    }
    
    private func getCategoryImageName(_ category: DeepCleanCategory) -> String? {
        switch category {
        case .largeFiles: return "deepclean_large_files"
        case .junkFiles: return "deepclean_system_junk"
        case .systemLogs: return "deepclean_log_files"
        case .systemCaches: return "deepclean_cache_files"
        case .appResiduals: return "deepclean_app_residue"
        }
    }
}

// MARK: - Detail View (详情页面 - 保持之前的实现)
struct DeepCleanDetailView: View {
    @ObservedObject var scanner: DeepCleanScanner
    var category: DeepCleanCategory?
    @Binding var isPresented: Bool
    @State private var selectedCategory: DeepCleanCategory?
    @ObservedObject private var loc = LocalizationManager.shared
    
    var body: some View {
        HSplitView {
            // Left Sidebar
            leftSidebar
                .frame(width: 280)
            
            // Right Content
            if let category = selectedCategory {
                rightPane(for: category)
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "arrow.left")
                        .font(.system(size: 48))
                        .foregroundColor(.secondaryText.opacity(0.5))
                    Text(loc.text("选择左侧分类查看详情", "Select a category to view details"))
                        .font(.title3)
                        .foregroundColor(.secondaryText)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(width: 900, height: 650)
        .background(BackgroundStyles.deepClean)
        .onAppear {
            if let initial = category {
                selectedCategory = initial
            } else if selectedCategory == nil {
                selectedCategory = DeepCleanCategory.allCases.first
            }
        }
    }
    
    // MARK: - Left Sidebar
    private var leftSidebar: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { isPresented = false }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text(loc.text("返回概要", "Back to Overview"))
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: selectAllItems) {
                    Text(loc.text(
    simplifiedChinese: "全选",
    traditionalChinese: "全選",
    english: "Select All",
    japanese: "すべてを選択",
    korean: "전체선택",
    russian: "Выбрать все"
))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "40C4FF"))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .background(Color.white.opacity(0.05))
            
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(DeepCleanCategory.allCases, id: \.self) { cat in
                        categorySidebarRow(cat)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .frame(width: 280)
        .background(Color.black.opacity(0.2))
    }
    
    private func categorySidebarRow(_ category: DeepCleanCategory) -> some View {
        let items = scanner.items.filter { $0.category == category }
        // 修改：只统计选中的项目大小
        let totalSize = items.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        let isSelected = selectedCategory == category
        
        // 计算勾选状态
        let selectedCount = items.filter { $0.isSelected }.count
        let checkState: SelectionState = {
            if items.isEmpty || selectedCount == 0 { return .none }
            if selectedCount == items.count { return .all }
            return .partial
        }()
        
        return Button(action: {
            selectedCategory = category
        }) {
            HStack(spacing: 10) {
                // 三态勾选框（紧凑型）
                ZStack {
                    Circle()
                        .stroke(checkState != .none ? Color(hex: "40C4FF") : Color.white.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                    
                    if checkState == .all {
                        Circle()
                            .fill(Color(hex: "40C4FF"))
                            .frame(width: 18, height: 18)
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    } else if checkState == .partial {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 18, height: 18)
                        Image(systemName: "minus")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    Task { @MainActor in
                        scanner.toggleCategorySelection(category, to: checkState != .all)
                    }
                }
                
                // 小图标（紧凑型）
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    getCategoryGradientTop(category).opacity(0.3),
                                    getCategoryGradientBottom(category).opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 14))
                        .foregroundColor(getCategoryGradientTop(category))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.localizedName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 3) {
                        // 修改：显示选中项数
                        Text("\(selectedCount)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondaryText)
                        
                        Text("·")
                            .font(.system(size: 10))
                            .foregroundColor(.secondaryText.opacity(0.5))
                        
                        Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "40C4FF"))
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    // 勾选状态枚举
    private enum SelectionState {
        case none, partial, all
    }
    
    // MARK: - Right Pane
    private func rightPane(for category: DeepCleanCategory) -> some View {
        let items = scanner.items.filter { $0.category == category }
        
        return VStack(spacing: 0) {
            // Header（紧凑型）
            VStack(alignment: .leading, spacing: 6) {
                Text(category.localizedName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                // 修改：只计算选中项的大小和数量
                let selectedItems = items.filter { $0.isSelected }
                let totalSize = selectedItems.reduce(0) { $0 + $1.size }
                Text("\(selectedItems.count) \(loc.text("个选定项目", "selected items")), \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.05))
            
            // Items List
            if items.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    Text(loc.text("该分类暂无项目", "No items in this category"))
                        .font(.title3)
                        .foregroundColor(.secondaryText)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { item in
                            DeepCleanItemRow(item: item, scanner: scanner)
                            
                            if item.id != items.last?.id {
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func selectAllItems() {
        guard let category = selectedCategory else { return }
        scanner.toggleCategorySelection(category, to: true)
    }
    
    // 辅助函数
    private func getCategoryGradientTop(_ category: DeepCleanCategory) -> Color {
        switch category {
        case .largeFiles: return Color(hex: "FF6B9D")
        case .junkFiles: return Color(hex: "FF5757")
        case .systemLogs: return Color(hex: "5B9BD5")
        case .systemCaches: return Color(hex: "70C1B3")
        case .appResiduals: return Color(hex: "FFD93D")
        }
    }
    
    private func getCategoryGradientBottom(_ category: DeepCleanCategory) -> Color {
        switch category {
        case .largeFiles: return Color(hex: "C23B8C")
        case .junkFiles: return Color(hex: "B80F0A")
        case .systemLogs: return Color(hex: "2E5C8A")
        case .systemCaches: return Color(hex: "29A39B")
        case .appResiduals: return Color(hex: "F77F00")
        }
    }
}

// MARK: - Item Row（紧凑型）
struct DeepCleanItemRow: View {
    let item: DeepCleanItem
    @ObservedObject var scanner: DeepCleanScanner
    @State private var isHovering: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox（紧凑型）
            ZStack {
                Circle()
                    .stroke(item.isSelected ? Color(hex: "40C4FF") : Color.white.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 16, height: 16)
                
                if item.isSelected {
                    Circle()
                        .fill(Color(hex: "40C4FF"))
                        .frame(width: 16, height: 16)
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                Task { @MainActor in
                    scanner.toggleSelection(for: item)
                }
            }
            
            // Icon（更小）
            Image(systemName: "doc.fill")
                .font(.system(size: 12))
                .foregroundColor(.blue.opacity(0.8))
                .frame(width: 20)
            
            // Name & Path（紧凑字体）
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(item.url.path)
                    .font(.system(size: 9))
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Size（更小）
            Text(item.formattedSize)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "40C4FF"))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovering ? Color.white.opacity(0.05) : Color.clear)
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .scanResultContextMenu(
            isSelected: item.isSelected,
            displayName: item.name,
            url: item.url,
            onToggleSelection: { scanner.toggleSelection(for: item) },
            onIgnore: {
                scanner.items.removeAll { $0.id == item.id }
                scanner.totalSize = scanner.items.reduce(0) { $0 + $1.size }
            }
        )
    }
}

// MARK: - Deep Clean Result Row (清理完成结果行)
struct DeepCleanResultRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let stat: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            if let nsImage = NSImage(named: icon) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
            } else {
                // Fallback SF Symbol
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                }
            }
            
            // Title & Subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            // Stat
            Text(stat)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color(hex: "40C4FF"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .frame(width: 400)
    }
}
