import SwiftUI

struct MemoryAlertView: View {
    @ObservedObject var systemMonitor: SystemMonitorService
    @ObservedObject private var loc = LocalizationManager.shared
    var openAppAction: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Pointer (Triangle)
            Triangle()
                .fill(Color(hex: "F2F2F7")) // Match background
                .frame(width: 20, height: 10)
                .padding(.bottom, -1) // Overlap slightly to hide seam
            
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc.text("内存占用过高", "High Memory Usage"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.black.opacity(0.85))
                    
                    Text(loc.text("Mac优化大师发现您的 Mac 物理内存和虚拟内存占用率过高。让我们为您解决这个问题！", "MacOptimizer detected high physical and virtual memory usage on your Mac. Let's fix it."))
                        .font(.system(size: 13))
                        .foregroundColor(Color.black.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }
                
                // App Launch Action
                Button(action: {
                    openAppAction()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 14))
                        Text(loc.text("启动 Mac优化大师", "Open MacOptimizer"))
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(Color.black)
                }
                .buttonStyle(.plain)
                
                // Memory Visualization Card
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "FFFFFF")) // White background for the card
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    
                    HStack(spacing: 12) {
                        // Icon
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: "00C7BE"))
                                .frame(width: 40, height: 40)
                            
                            Text("RAM")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .offset(y: -5)
                            
                            // Mock "pins" or chip look
                            VStack(spacing: 2) {
                                Spacer()
                                HStack(spacing: 2) {
                                    ForEach(0..<5) { _ in
                                        Rectangle()
                                            .fill(Color.white.opacity(0.5))
                                            .frame(width: 2, height: 6)
                                    }
                                }
                                .padding(.bottom, 4)
                            }
                            .frame(width: 40, height: 40)
                        }
                        
                        // Progress
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("RAM + Swap")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color.black.opacity(0.85))
                                Spacer()
                                Text(systemMonitor.memoryUsage > 0.9 ? loc.text("快满了", "Almost Full") : loc.text("正常", "Normal"))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(hex: "FF6B6B"))
                            }
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.gray.opacity(0.15))
                                        .frame(height: 8)
                                    
                                    Capsule()
                                        .fill(LinearGradient(gradient: Gradient(colors: [Color(hex: "FF9F6B"), Color(hex: "FF6B6B")]), startPoint: .leading, endPoint: .trailing))
                                        .frame(width: geometry.size.width * CGFloat(systemMonitor.memoryUsage), height: 8)
                                        .animation(.easeInOut, value: systemMonitor.memoryUsage)
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                    .padding(12)
                }
                .frame(height: 72)
                .background(Color(hex: "F2F2F7"))
                
                Divider()
                    .background(Color.gray.opacity(0.2))
                
                // Footer Actions
                HStack {
                    Menu {
                        Button(loc.text("10 分钟后提醒", "Remind Me in 10 Minutes")) {
                            systemMonitor.ignoreCurrentHighMemoryApp() // Simplified for now
                        }
                        Button(loc.text("1 小时后提醒", "Remind Me in 1 Hour")) {
                             systemMonitor.ignoreCurrentHighMemoryApp()
                        }
                        Divider()
                        Button(loc.text("从不提醒", "Never Remind Me")) {
                             systemMonitor.ignoreCurrentHighMemoryApp()
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Text(loc.text("忽略", "Ignore"))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.7))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            systemMonitor.terminateHighMemoryApp()
                        }
                    }) {
                        Text(loc.text("释放", "Free Up"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.black.opacity(0.8))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .background(Color(hex: "F2F2F7")) // Light gray background for modern macOS popover style
            .cornerRadius(16)
        }
        .frame(width: 320)
        .compositingGroup() // Ensure shadow applies to the unified shape
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

// Simple Triangle Shape
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
