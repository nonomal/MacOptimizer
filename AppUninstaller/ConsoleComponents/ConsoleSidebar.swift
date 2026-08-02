import SwiftUI

struct ConsoleSidebar: View {
    @Binding var selection: MonitorView.DashboardState
    @ObservedObject var loc = LocalizationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(loc.text(
    simplifiedChinese: "控制台",
    traditionalChinese: "主控台",
    english: "Console",
    japanese: "コンソール",
    korean: "콘솔",
    russian: "Консоль"
))
                .font(.title3)
                .bold()
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 10)
                .foregroundColor(.white)
            
            Group {
                SidebarButton(title: loc.text(
    simplifiedChinese: "概览",
    traditionalChinese: "概述",
    english: "Overview",
    japanese: "概要",
    korean: "개요",
    russian: "Обзор"
), icon: "square.grid.2x2", isSelected: selection == .dashboard) {
                    selection = .dashboard
                }
                
                SidebarButton(title: loc.text(
    simplifiedChinese: "应用管理",
    traditionalChinese: "應用管理",
    english: "App Manager",
    japanese: "アプリマネージャー",
    korean: "앱 관리자",
    russian: "Диспетчер приложений"
), icon: "app.badge", isSelected: selection == .appManager) {
                    selection = .appManager
                }
                
                SidebarButton(title: loc.text(
    simplifiedChinese: "进程管理",
    traditionalChinese: "行程管理",
    english: "Process Manager",
    japanese: "プロセス管理",
    korean: "프로세스 관리",
    russian: "Управление процессами"
), icon: "waveform.path.ecg", isSelected: selection == .processManager) {
                    selection = .processManager
                }
                
                SidebarButton(title: loc.text(
    simplifiedChinese: "网络诊断",
    traditionalChinese: "網路診斷",
    english: "Network",
    japanese: "ネットワーク",
    korean: "네트워크",
    russian: "Сеть"
), icon: "wifi", isSelected: selection == .networkOptimize) {
                    selection = .networkOptimize
                }
                
                SidebarButton(title: loc.text(
    simplifiedChinese: "端口管理",
    traditionalChinese: "連接埠管理",
    english: "Port Manager",
    japanese: "ポート管理",
    korean: "포트 관리",
    russian: "Управление портами"
), icon: "network", isSelected: selection == .portManager) {
                    selection = .portManager
                }
                
                SidebarButton(title: loc.text(
    simplifiedChinese: "安全中心",
    traditionalChinese: "安全中心",
    english: "Safety Center",
    japanese: "セキュリティセンター",
    korean: "보안 센터",
    russian: "Центр безопасности"
), icon: "shield.checkerboard", isSelected: selection == .protection) {
                    selection = .protection
                }
            }
            
            Spacer()
        }
        .frame(width: 200)
        .background(Color.white.opacity(0.03))
    }
}

struct SidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                
                Spacer()
                
                if isSelected {
                    Capsule()
                        .fill(Color(red: 0.28, green: 0.82, blue: 0.96))
                        .frame(width: 3, height: 16)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white.opacity(isHovering ? 0.38 : 0))
                }
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            .padding(.horizontal, 16)
            .frame(height: 42)
            .background(Color.white.opacity(isSelected ? 0.075 : (isHovering ? 0.035 : 0)))
            .cornerRadius(8)
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.14), value: isHovering)
        .animation(.easeOut(duration: 0.14), value: isSelected)
    }
}
