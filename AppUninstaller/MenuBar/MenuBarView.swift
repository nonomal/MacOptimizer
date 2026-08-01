import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var manager: MenuBarManager
    @EnvironmentObject private var systemMonitor: SystemMonitorService
    @ObservedObject private var diskManager = DiskSpaceManager.shared
    @ObservedObject private var protectionService = ProtectionService.shared

    private let panelBackground = Color(red: 0.18, green: 0.09, blue: 0.30)
    private let cardBackground = Color.white.opacity(0.065)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.24, green: 0.08, blue: 0.32),
                    Color(red: 0.10, green: 0.035, blue: 0.25)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                recommendations
                overview
                footer
            }

            if systemMonitor.showHighMemoryAlert {
                MemoryAlertView(systemMonitor: systemMonitor) {
                    manager.openMainApp(module: .monitor)
                }
                .padding(.top, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .frame(width: 430, height: 743)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
        }
    }

    private var recommendations: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("推荐")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    RecommendationCard(
                        icon: "arrow.up.app",
                        title: "更新应用程序以获得新功能\n和更高的稳定性。",
                        buttonTitle: "更新应用程序",
                        isPrimary: true
                    ) {
                        manager.openMainApp(module: .updater)
                    }

                    RecommendationCard(
                        icon: "folder",
                        title: "找出长久未打开过的大文件。",
                        buttonTitle: "查看文件"
                    ) {
                        manager.openMainApp(module: .largeFiles)
                    }

                    RecommendationCard(
                        icon: "arrow.clockwise.circle",
                        title: "清除无用的系统文件，释放更多空间。",
                        buttonTitle: "开始扫描"
                    ) {
                        manager.openMainApp(module: .cleaner)
                    }
                }
                .padding(.horizontal, 10)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 18)
        .frame(height: 226, alignment: .top)
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mac 概览")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)

            protectionCard

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    storageCard
                    memoryCard
                }
                .frame(height: 76)

                HStack(spacing: 10) {
                    batteryCard
                    cpuCard
                }
                .frame(height: 56)

                HStack(alignment: .top, spacing: 10) {
                    networkCard
                        .frame(height: 124)
                    devicesCard
                        .frame(height: 66)
                }
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 473, alignment: .top)
    }

    private var protectionCard: some View {
        Button {
            manager.openMainApp(module: .malware)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: protectionService.isMonitoring ? "checkmark.shield.fill" : "shield.slash.fill")
                        .font(.system(size: 23))
                        .foregroundColor(protectionService.isMonitoring ? Color.green : Color.orange)

                    Text("防护服务提供者：")
                        .font(.system(size: 13, weight: .semibold))

                    Image("malware_moonlock_logo_small")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 18)

                    Spacer(minLength: 6)

                    Image(systemName: protectionService.isMonitoring ? "checkmark" : "exclamationmark")
                        .font(.system(size: 11, weight: .bold))
                    Text(protectionService.isMonitoring ? "受保护" : "未开启")
                        .font(.system(size: 12, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(protectionService.isMonitoring ? "实时恶意软件监控开启" : "实时恶意软件监控未开启")
                        .font(.system(size: 13, weight: .semibold))

                    Text("安全防护状态会在主应用中持续更新")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.68))

                    HStack {
                        Text("打开防护模块查看扫描记录")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.68))
                        Spacer()
                        Text("马上检查")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
            }
            .foregroundColor(.white)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            }
        }
        .buttonStyle(MenuBarPressButtonStyle())
        .padding(.horizontal, 10)
        .frame(height: 120)
    }

    private var storageCard: some View {
        MenuOverviewCard(action: { manager.showDetail(route: .storage) }) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "internaldrive")
                    .font(.system(size: 18))
                    .frame(width: 23)
                VStack(alignment: .leading, spacing: 2) {
                    Text("mac")
                        .font(.system(size: 14, weight: .semibold))
                    Text("可用：\(diskManager.formattedFree)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.yellow)
                }
                Spacer(minLength: 0)
            }
            HStack {
                Spacer()
                Text("释放")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.72))
            }
        }
    }

    private var memoryCard: some View {
        MenuOverviewCard(action: { manager.showDetail(route: .memory) }) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "memorychip")
                    .font(.system(size: 18))
                    .frame(width: 23)
                VStack(alignment: .leading, spacing: 2) {
                    Text("内存")
                        .font(.system(size: 14, weight: .semibold))
                    Text("可用：\(availableMemory)")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.68))
                }
                Spacer(minLength: 0)
            }
            HStack {
                Spacer()
                Text("释放")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.72))
            }
        }
    }

    private var batteryCard: some View {
        MenuOverviewCard(action: { manager.showDetail(route: .battery) }) {
            HStack(spacing: 10) {
                Image(systemName: systemMonitor.isCharging ? "battery.100.bolt" : "battery.100")
                    .font(.system(size: 18))
                    .frame(width: 23)
                VStack(alignment: .leading, spacing: 2) {
                    Text("电池")
                        .font(.system(size: 14, weight: .semibold))
                    Text(systemMonitor.batteryTimeRemaining.isEmpty
                         ? systemMonitor.batteryState
                         : systemMonitor.batteryTimeRemaining)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.68))
                }
                Spacer()
                Text("\(Int(systemMonitor.batteryLevel * 100))%")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.yellow)
            }
        }
    }

    private var cpuCard: some View {
        MenuOverviewCard(action: { manager.showDetail(route: .cpu) }, highlighted: true) {
            HStack(spacing: 10) {
                Image(systemName: "cpu")
                    .font(.system(size: 18))
                    .frame(width: 23)
                VStack(alignment: .leading, spacing: 2) {
                    Text("CPU")
                        .font(.system(size: 14, weight: .semibold))
                    Text("加载：\(Int(systemMonitor.cpuUsage * 100))%")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.68))
                }
                Spacer()
            }
        }
    }

    private var networkCard: some View {
        MenuOverviewCard(action: { manager.showDetail(route: .network) }) {
            HStack(spacing: 10) {
                Image(systemName: "wifi")
                    .font(.system(size: 18))
                    .frame(width: 23)
                Text(systemMonitor.wifiSSID)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("↑ \(systemMonitor.formatSpeed(systemMonitor.uploadSpeed))")
                Text("↓ \(systemMonitor.formatSpeed(systemMonitor.downloadSpeed))")
            }
            .font(.system(size: 11, weight: .medium))

            HStack {
                Spacer()
                Button("测试速度") {
                    systemMonitor.runSpeedTest()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .disabled(systemMonitor.isTestingSpeed)
            }
        }
    }

    private var devicesCard: some View {
        MenuOverviewCard(action: {}) {
            Text("已连接的设备")
                .font(.system(size: 13, weight: .semibold))
            Text(connectedDeviceCount == 0 ? "尚未连接任何设备" : "已连接 \(connectedDeviceCount) 个设备")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.68))
            Spacer(minLength: 0)
        }
    }

    private var footer: some View {
        HStack {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 22, height: 22)

            Spacer()

            Button("打开 Mac优化大师") {
                manager.openMainApp()
            }
            .buttonStyle(.plain)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white.opacity(0.78))

            Spacer()

            Menu {
                Button("关于 Mac优化大师") { manager.openMainApp() }
                Button("提供反馈...") { manager.openMainApp() }
                Divider()
                Button("偏好设置...") { manager.openMainApp() }
                Divider()
                Button("退出") {
                    UserDefaults.standard.set(true, forKey: "ForceQuitApp")
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.9))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Color.black.opacity(0.08))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.055))
                .frame(height: 0.5)
        }
    }

    private var availableMemory: String {
        let total = ProcessInfo.processInfo.physicalMemory
        let available = Double(total) * max(0, 1 - systemMonitor.memoryUsage)
        return ByteCountFormatter.string(fromByteCount: Int64(available), countStyle: .memory)
    }

    private var connectedDeviceCount: Int {
        let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeIsLocalKey],
            options: [.skipHiddenVolumes]
        ) ?? []

        return volumes.filter { volume in
            volume.path != "/" && !volume.path.hasPrefix("/System/Volumes/")
        }.count
    }
}

private struct RecommendationCard: View {
    let icon: String
    let title: String
    let buttonTitle: String
    var isPrimary = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .regular))

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                Text(buttonTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isPrimary ? Color(red: 0.10, green: 0.16, blue: 0.42) : .white.opacity(0.88))
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background(isPrimary ? Color(red: 1, green: 0.82, blue: 0.27) : Color.white.opacity(isHovered ? 0.28 : 0.20))
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .foregroundColor(.white)
            .padding(10)
            .frame(width: 185, height: 172)
            .background(Color.white.opacity(isHovered ? 0.11 : 0.075))
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Color.white.opacity(isHovered ? 0.18 : 0.09), lineWidth: 0.5)
            }
            .scaleEffect(isHovered ? 1.008 : 1)
        }
        .buttonStyle(MenuBarPressButtonStyle())
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

private struct MenuOverviewCard<Content: View>: View {
    let action: () -> Void
    var highlighted = false
    @ViewBuilder let content: () -> Content

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                content()
            }
            .foregroundColor(.white)
            .padding(11)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                Color.white.opacity(
                    isHovered ? 0.15 : (highlighted ? 0.13 : 0.065)
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(highlighted || isHovered ? 0.32 : 0.07), lineWidth: 0.5)
            }
        }
        .buttonStyle(MenuBarPressButtonStyle())
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

private struct MenuBarPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.992 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
