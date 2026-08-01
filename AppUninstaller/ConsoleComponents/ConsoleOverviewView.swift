import SwiftUI

enum ConsoleProcessSortMode: String, CaseIterable, Identifiable {
    case memory
    case cpu

    var id: String { rawValue }
}

struct ConsoleOverviewView: View {
    @Binding var viewState: MonitorView.DashboardState
    @Binding var processSortMode: ConsoleProcessSortMode
    @ObservedObject var systemMonitor: SystemMonitorService
    @ObservedObject private var loc = LocalizationManager.shared

    private let accent = Color(red: 0.28, green: 0.82, blue: 0.96)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                overviewHeader
                metricStrip

                HStack(alignment: .top, spacing: 14) {
                    processRankingCard(
                        title: loc.text("内存使用排行", "Memory Usage"),
                        subtitle: loc.text("正在运行的前台应用", "Foreground applications"),
                        symbol: "memorychip",
                        processes: systemMonitor.topMemoryProcesses,
                        mode: .memory
                    )

                    processRankingCard(
                        title: loc.text("CPU 占用排行", "CPU Usage"),
                        subtitle: loc.text(
    simplifiedChinese: "按当前处理器占用排序",
    traditionalChinese: "按當前處理器佔用排序",
    english: "Sorted by current processor use",
    japanese: "現在のプロセッサ使用状況で並べ替え",
    korean: "현재 프로세서 용도에 따라 정렬",
    russian: "Сортировка по текущему использованию процессора"
),
                        symbol: "cpu",
                        processes: systemMonitor.topCPUProcesses,
                        mode: .cpu
                    )
                }

                networkCard
                moduleEntries
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 28)
        }
        .onAppear {
            systemMonitor.startMonitoring()
        }
    }

    private var overviewHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(loc.text(
    simplifiedChinese: "系统概览",
    traditionalChinese: "系統概覽",
    english: "System Overview",
    japanese: "（システムの概説）",
    korean: "시스템 개요",
    russian: "Общие сведения о системе"
))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)

                Text(loc.text(
    simplifiedChinese: "实时查看这台 Mac 的负载、应用与网络状态",
    traditionalChinese: "即時查看這台Mac 的負載、應用程式與網路狀態",
    english: "Live load, application and network status for this Mac",
    japanese: "このMacのライブロード、アプリケーション、およびネットワークステータス",
    korean: "이 Mac의 라이브 로드, 응용 프로그램 및 네트워크 상태",
    russian: "Текущая нагрузка, состояние приложения и сети для этого Mac"
))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.52))
            }

            Spacer()

            HStack(spacing: 7) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                    .shadow(color: .green.opacity(0.55), radius: 4)
                Text(loc.text("每 2 秒实时更新", "Live · 2 sec"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.68))
            }
            .padding(.horizontal, 10)
            .frame(height: 27)
            .background(Color.black.opacity(0.16), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.7))
        }
    }

    private var metricStrip: some View {
        HStack(spacing: 10) {
            ConsoleMetricTile(
                title: "CPU",
                value: String(format: "%.0f%%", systemMonitor.cpuUsage * 100),
                detail: loc.text("系统总负载", "System load"),
                symbol: "cpu",
                progress: systemMonitor.cpuUsage,
                accent: accent
            )

            ConsoleMetricTile(
                title: loc.text(
    simplifiedChinese: "内存",
    traditionalChinese: "記憶體",
    english: "Memory",
    japanese: "メモリ",
    korean: "기억력",
    russian: "Память"
),
                value: systemMonitor.memoryUsedString,
                detail: memoryTotalDetail,
                symbol: "memorychip",
                progress: systemMonitor.memoryUsage,
                accent: accent
            )

            ConsoleMetricTile(
                title: loc.text(
    simplifiedChinese: "下载",
    traditionalChinese: "下載",
    english: "Download",
    japanese: "ダウンロード",
    korean: "다운로드",
    russian: "Загрузить"
),
                value: systemMonitor.formatSpeed(systemMonitor.downloadSpeed),
                detail: loc.text(
    simplifiedChinese: "当前速度",
    traditionalChinese: "目前速度",
    english: "Current speed",
    japanese: "現在の速度",
    korean: "현재속도",
    russian: "Текущая скорость"
),
                symbol: "arrow.down",
                progress: nil,
                accent: accent
            )

            ConsoleMetricTile(
                title: loc.text(
    simplifiedChinese: "上传",
    traditionalChinese: "上傳",
    english: "Upload",
    japanese: "アップロード",
    korean: "업로드",
    russian: "Загрузить"
),
                value: systemMonitor.formatSpeed(systemMonitor.uploadSpeed),
                detail: loc.text(
    simplifiedChinese: "当前速度",
    traditionalChinese: "目前速度",
    english: "Current speed",
    japanese: "現在の速度",
    korean: "현재속도",
    russian: "Текущая скорость"
),
                symbol: "arrow.up",
                progress: nil,
                accent: accent
            )
        }
        .frame(height: 92)
    }

    private func processRankingCard(
        title: String,
        subtitle: String,
        symbol: String,
        processes: [SystemMonitorService.AppProcess],
        mode: ConsoleProcessSortMode
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ConsoleCardHeader(title: title, subtitle: subtitle, symbol: symbol) {
                processSortMode = mode
                withAnimation(.easeOut(duration: 0.18)) {
                    viewState = .processManager
                }
            }

            if processes.isEmpty {
                ConsoleLoadingRows()
            } else {
                VStack(spacing: 7) {
                    ForEach(Array(processes.prefix(6).enumerated()), id: \.element.id) { index, process in
                        ConsoleProcessRankRow(
                            rank: index + 1,
                            process: process,
                            mode: mode,
                            maximum: maximumValue(in: processes, mode: mode),
                            accent: accent
                        )
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 286, maxHeight: 286, alignment: .top)
        .consoleCardStyle()
    }

    private func maximumValue(
        in processes: [SystemMonitorService.AppProcess],
        mode: ConsoleProcessSortMode
    ) -> Double {
        let first = processes.first
        return max(mode == .memory ? (first?.memory ?? 0) : (first?.cpu ?? 0), 0.0001)
    }

    private var networkCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ConsoleCardHeader(
                title: loc.text(
    simplifiedChinese: "网络流量",
    traditionalChinese: "網路流量",
    english: "Network Traffic",
    japanese: "ネットワークトラフィック",
    korean: "트래픽에 사용하는 것입니다.",
    russian: "Сетевой трафик"
),
                subtitle: loc.text(
    simplifiedChinese: "最近 40 秒的实时收发趋势",
    traditionalChinese: "最近40 秒的即時收發趨勢",
    english: "Live transfer trend for the last 40 seconds",
    japanese: "直近40秒間のライブ転送トレンド",
    korean: "지난 40초 동안의 실시간 이체 추세",
    russian: "Тенденция передачи в реальном времени за последние 40 секунд"
),
                symbol: "network"
            ) {
                withAnimation(.easeOut(duration: 0.18)) {
                    viewState = .networkOptimize
                }
            }

            NetworkWaveform(
                downloadHistory: systemMonitor.downloadSpeedHistory,
                uploadHistory: systemMonitor.uploadSpeedHistory
            )
            .frame(height: 66)

            HStack(spacing: 22) {
                networkLegend(
                    symbol: "arrow.down",
                    title: loc.text(
    simplifiedChinese: "总下载",
    traditionalChinese: "總下載",
    english: "Downloaded",
    japanese: "ダウンロード完了",
    korean: "다운로드 완료",
    russian: "Загружено"
),
                    value: systemMonitor.totalDownload
                )
                networkLegend(
                    symbol: "arrow.up",
                    title: loc.text(
    simplifiedChinese: "总上传",
    traditionalChinese: "總上傳",
    english: "Uploaded",
    japanese: "アップロード完了",
    korean: "업로드됨",
    russian: "Отправлено"
),
                    value: systemMonitor.totalUpload
                )
                Spacer()
            }
        }
        .padding(16)
        .consoleCardStyle()
    }

    private func networkLegend(symbol: String, title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(accent)
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.48))
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.82))
        }
    }

    private var moduleEntries: some View {
        HStack(spacing: 10) {
            ConsoleModuleEntry(
                title: loc.text(
    simplifiedChinese: "应用管理",
    traditionalChinese: "應用管理",
    english: "Applications",
    japanese: "用途",
    korean: "적용 분야",
    russian: "Сферы применения"
),
                subtitle: loc.text(
    simplifiedChinese: "运行状态与应用信息",
    traditionalChinese: "運作狀態與應用訊息",
    english: "Status and app information",
    japanese: "ステータスとアプリ情報",
    korean: "상태 및 앱 정보",
    russian: "Информация о статусе и приложении"
),
                symbol: "app.badge"
            ) { viewState = .appManager }

            ConsoleModuleEntry(
                title: loc.text(
    simplifiedChinese: "端口管理",
    traditionalChinese: "連接埠管理",
    english: "Ports",
    japanese: "ポート",
    korean: "포트",
    russian: "Порты"
),
                subtitle: loc.text(
    simplifiedChinese: "监听地址与占用进程",
    traditionalChinese: "監聽位址與佔用進程",
    english: "Listeners and owning processes",
    japanese: "リスナーと所有プロセス",
    korean: "청취자 및 소유 프로세스",
    russian: "Слушатели и процессы владения"
),
                symbol: "point.3.connected.trianglepath.dotted"
            ) { viewState = .portManager }

            ConsoleModuleEntry(
                title: loc.text(
    simplifiedChinese: "安全中心",
    traditionalChinese: "安全中心",
    english: "Safety Center",
    japanese: "セーフティセンター",
    korean: "CCTV 안전센터",
    russian: "Центр безопасности"
),
                subtitle: loc.text(
    simplifiedChinese: "下载监控与威胁记录",
    traditionalChinese: "下載監控與威脅記錄",
    english: "Downloads and threat history",
    japanese: "ダウンロードと脅威の履歴",
    korean: "다운로드 및 위협 내역",
    russian: "Загрузки и история угроз"
),
                symbol: "shield.checkered"
            ) { viewState = .protection }
        }
    }

    private var memoryTotalDetail: String {
        loc.text(
            simplifiedChinese: "共 \(systemMonitor.memoryTotalString)",
            traditionalChinese: "共 \(systemMonitor.memoryTotalString)",
            english: "of \(systemMonitor.memoryTotalString)",
            japanese: "合計 \(systemMonitor.memoryTotalString)",
            korean: "총 \(systemMonitor.memoryTotalString)",
            russian: "из \(systemMonitor.memoryTotalString)"
        )
    }
}

private struct ConsoleMetricTile: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String
    let progress: Double?
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(accent)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                Spacer()
            }

            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            if let progress {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(accent.opacity(0.88))
                            .frame(width: geometry.size.width * min(max(progress, 0), 1))
                    }
                }
                .frame(height: 3)
            } else {
                Text(detail)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.38))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .consoleCardStyle()
    }
}

private struct ConsoleCardHeader: View {
    let title: String
    let subtitle: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(red: 0.28, green: 0.82, blue: 0.96))
                .frame(width: 25, height: 25)
                .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.92))
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.38))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button(action: action) {
                HStack(spacing: 4) {
                    Text(LocalizationManager.shared.text(
    simplifiedChinese: "查看详情",
    traditionalChinese: "查看詳情",
    english: "Details",
    japanese: "詳細",
    korean: "세부사항",
    russian: "Подробнее"
))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.66))
                .padding(.horizontal, 9)
                .frame(height: 25)
                .background(Color.white.opacity(0.06), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.07), lineWidth: 0.7))
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ConsoleProcessRankRow: View {
    let rank: Int
    let process: SystemMonitorService.AppProcess
    let mode: ConsoleProcessSortMode
    let maximum: Double
    let accent: Color

    private var value: Double {
        mode == .memory ? process.memory : process.cpu
    }

    var body: some View {
        HStack(spacing: 7) {
            Text("\(rank)")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.30))
                .frame(width: 12, alignment: .trailing)

            Group {
                if let icon = process.icon {
                    Image(nsImage: icon).resizable().scaledToFit()
                } else {
                    Image(systemName: "gearshape.fill").foregroundColor(.white.opacity(0.30))
                }
            }
            .frame(width: 17, height: 17)

            Text(process.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.86))
                .lineLimit(1)
                .frame(width: 92, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule()
                        .fill(accent.opacity(0.82))
                        .frame(width: geometry.size.width * CGFloat(min(max(value / maximum, 0), 1)))
                }
            }
            .frame(height: 5)

            Text(mode == .memory ? String(format: "%.2f GB", value) : String(format: "%.1f%%", value))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.56))
                .frame(width: 54, alignment: .trailing)
        }
        .frame(height: 27)
    }
}

private struct ConsoleLoadingRows: View {
    var body: some View {
        VStack(spacing: 9) {
            ForEach(0..<6, id: \.self) { index in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.07))
                        .frame(width: 18, height: 18)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.07))
                        .frame(width: CGFloat(68 + (index % 3) * 10), height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.055))
                        .frame(maxWidth: .infinity)
                        .frame(height: 5)
                }
                .frame(height: 27)
            }
        }
        .redacted(reason: .placeholder)
    }
}

private struct ConsoleModuleEntry: View {
    let title: String
    let subtitle: String
    let symbol: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(red: 0.28, green: 0.82, blue: 0.96))
                    .frame(width: 31, height: 31)
                    .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.90))
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.40))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Text(LocalizationManager.shared.text(
    simplifiedChinese: "查看详情",
    traditionalChinese: "查看詳情",
    english: "Details",
    japanese: "詳細",
    korean: "세부사항",
    russian: "Подробнее"
))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.50))
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white.opacity(0.34))
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(Color.white.opacity(isHovering ? 0.075 : 0.04), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(isHovering ? 0.12 : 0.06), lineWidth: 0.7))
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.008 : 1)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.14), value: isHovering)
    }
}

private extension View {
    func consoleCardStyle() -> some View {
        background(Color.black.opacity(0.13), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.065), lineWidth: 0.7)
            )
    }
}

// Retained for compatibility with older console call sites.
struct StatsDetailCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundColor(.secondaryText)
                Text(value).font(.headline).foregroundColor(.white)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
    }
}
