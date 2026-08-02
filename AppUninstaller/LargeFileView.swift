import SwiftUI
import AppKit

struct LargeFileView: View {
    @Binding var selectedModule: AppModule
    @ObservedObject private var scanner = ScanServiceManager.shared.largeFileScanner
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var showCleaningFinished = false
    @State private var selectedScanRoot = URL(fileURLWithPath: "/")
    @State private var selectedScanName = "mac"
    @State private var showVolumePicker = false
    
    // For disk usage bar simulation/real data
    @State private var totalDiskSpace: Int64 = 500 * 1024 * 1024 * 1024 // Fake default
    @State private var usedDiskSpace: Int64 = 100 * 1024 * 1024 * 1024
    
    var body: some View {
        ZStack {
            if scanner.isScanning {
                scanningPage
            } else if scanner.isCleaning {
                cleaningPage
            } else if showCleaningFinished {
                finishedPage
            } else if !scanner.foundFiles.isEmpty {
                resultsPage
            } else if scanner.hasCompletedScan {
                cleanPage
            } else {
                initialPage
                    .onAppear {
                        updateDiskUsage()
                    }
            }
        }
    }
    
    private func updateDiskUsage() {
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: selectedScanRoot.path),
           let size = attrs[.systemSize] as? Int64,
           let free = attrs[.systemFreeSize] as? Int64 {
            totalDiskSpace = size
            usedDiskSpace = size - free
        }
    }
    
    // MARK: - 1. Initial Page (Image 0 UI)
    var initialPage: some View {
        ZStack {
            HStack(alignment: .top, spacing: 25) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(loc.text("大型和旧文件", "Large and Old Files"))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)

                    Text(loc.text("查找和移除大型文件和文件夹。", "Find and remove large files and folders."))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.72))
                        .padding(.top, 10)

                    VStack(alignment: .leading, spacing: 67) {
                        featureRow(
                            image: "large_files_benefit_discover",
                            title: loc.text("发现文件垃圾场", "Spot file dumps"),
                            desc: loc.text("让您轻松找出大量被遗忘的项目以确定删除它们。", "Easily find massive forgotten items to decide on their removal.")
                        )
                        featureRow(
                            image: "large_files_benefit_sort",
                            title: loc.text("轻松排列文件", "Sort files easily"),
                            desc: loc.text("提供简单、方便的过滤器，快速查看和移除不需要的文件。", "Simple filters to quickly review and remove unneeded files.")
                        )
                    }
                    .padding(.top, 42)

                    volumeSelector
                        .padding(.top, 45)
                }
                .frame(width: 320, alignment: .leading)

                resourceImage("large_files_module")
                    .frame(width: 350, height: 350)
                    .padding(.top, 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, 98)
            .padding(.top, 142)
        }
        .overlay(
            // Bottom Center Scan Button
            CleanMyMacBottomActionSlot {
                CircularActionButton(
                    title: loc.text(
    simplifiedChinese: "扫描",
    traditionalChinese: "掃描",
    english: "Scan",
    japanese: "スキャン",
    korean: "스캔",
    russian: "Сканировать"
),
                    gradient: GradientStyles.largeFiles,
                    action: {
                        Task { await scanner.scan(at: selectedScanRoot) }
                    }
                )
            }
        )
    }
    
    private func featureRow(image: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 18) {
            resourceImage(image)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func resourceImage(_ name: String) -> some View {
        if let path = Bundle.main.path(forResource: name, ofType: "png"),
           let image = NSImage(contentsOfFile: path) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "circle")
                .resizable()
                .scaledToFit()
                .foregroundColor(.white.opacity(0.65))
        }
    }

    private var volumeSelector: some View {
        Button {
            showVolumePicker.toggle()
        } label: {
            HStack(spacing: 13) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: selectedScanRoot.path))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text("\(selectedScanName): \(ByteCountFormatter.string(fromByteCount: totalDiskSpace, countStyle: .file))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                    }

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.black.opacity(0.58))
                            .frame(width: 184, height: 4)
                        Capsule()
                            .fill(Color(red: 1, green: 0.80, blue: 0.20))
                            .frame(width: 184 * min(max(diskUsageRatio, 0), 1), height: 4)
                    }
                    .frame(height: 4)

                    Text(loc.text("已使用 \(ByteCountFormatter.string(fromByteCount: usedDiskSpace, countStyle: .file))", "Used \(ByteCountFormatter.string(fromByteCount: usedDiskSpace, countStyle: .file))"))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.52))
                }

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.65))
            }
            .padding(.horizontal, 14)
            .frame(width: 319, height: 57)
            .background(Color.white.opacity(0.025))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.30), lineWidth: 0.7)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showVolumePicker, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                volumeChoice("mac") {
                    selectedScanRoot = URL(fileURLWithPath: "/")
                    selectedScanName = "mac"
                    updateDiskUsage()
                }
                volumeChoice(loc.text("用户文件夹", "User Home")) {
                    selectedScanRoot = FileManager.default.homeDirectoryForCurrentUser
                    selectedScanName = NSUserName()
                    updateDiskUsage()
                }
                Divider()
                volumeChoice(loc.text("选择文件夹…", "Select Folder…")) {
                    selectScanFolder()
                }
            }
            .padding(8)
            .frame(width: 180)
        }
        .frame(width: 319, height: 57)
    }

    private func volumeChoice(_ title: String, action: @escaping () -> Void) -> some View {
        Button {
            showVolumePicker = false
            action()
        } label: {
            Text(title)
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .frame(height: 27)
        }
        .buttonStyle(.plain)
    }

    private var diskUsageRatio: CGFloat {
        guard totalDiskSpace > 0 else { return 0 }
        return CGFloat(Double(usedDiskSpace) / Double(totalDiskSpace))
    }

    private func selectScanFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = loc.text("选择", "Select")

        if panel.runModal() == .OK, let url = panel.url {
            selectedScanRoot = url
            selectedScanName = url.lastPathComponent
            updateDiskUsage()
        }
    }
    
    // MARK: - 2. Scanning Page (Image 1 UI)
    var scanningPage: some View {
        ZStack(alignment: .top) {
            Text(loc.text("大型和旧文件", "Large and Old Files"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.52))
                .padding(.top, 3)

            VStack(spacing: 0) {
                Spacer().frame(height: 114)

                // CleanMyMac keeps the same LAOF artwork between intro and
                // scanning states. Its transparent canvas is 280pt while the
                // visible folder occupies about 242pt.
                resourceImage("large_files_module")
                    .frame(width: 280, height: 280)

                Text(loc.text("正在寻找大型和旧文件…", "Finding Large and Old Files…"))
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white.opacity(0.94))
                    .padding(.top, 12)

                Text(currentScanningPath)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.27))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: 520)
                    .padding(.top, 12)

                Text(loc.text("大型和旧文件", "Large and Old Files"))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.43))
                    .padding(.top, 12)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(scanningBottomAction)
    }

    private var currentScanningPath: String {
        let path = scanner.scanProgress?.currentPath.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return path.isEmpty ? selectedScanRoot.path : path
    }

    private var scanningBottomAction: some View {
        CleanMyMacBottomActionSlot {
            CleanMyMacBottomActionCluster(accessoryOffset: CGSize(width: 82, height: 0)) {
                Button {
                    scanner.stopScan()
                } label: {
                    CleanMyMacActionOrb(
                        title: loc.text(
    simplifiedChinese: "停止",
    traditionalChinese: "停止",
    english: "Stop",
    japanese: "停止",
    korean: "정지",
    russian: "Остановить"
),
                        gradient: LinearGradient(
                            colors: [Color.white.opacity(0.14), Color.black.opacity(0.12)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        glowColor: Color(red: 0.78, green: 0.37, blue: 0.63),
                        ringColor: Color(red: 0.78, green: 0.37, blue: 0.63),
                        progress: scanProgressValue
                    )
                }
                .buttonStyle(.plain)
            } accessory: {
                Text(ByteCountFormatter.string(fromByteCount: scanner.totalSize, countStyle: .file))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.72))
            }
        }
    }

    private var scanProgressValue: Double {
        guard let progress = scanner.scanProgress, progress.totalEstimated > 0 else { return 0 }
        return min(Double(progress.filesProcessed) / Double(progress.totalEstimated), 0.98)
    }
    
    // MARK: - 2.5 Clean Page (No files found)
    var cleanPage: some View {
        VStack(spacing: 30) {
            // Header
            HStack {
                Button(action: {
                    scanner.reset()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(loc.text("重新开始", "Start Over"))
                    }
                    .foregroundColor(.secondaryText)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(loc.text("大型和旧文件", "Large and Old Files"))
                    .font(.title2)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Placeholder for symmetry
                Text(loc.text("重新开始", "Start Over"))
                    .opacity(0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            Spacer()
            
            // Central Icon (Whale substitute)
            ZStack {
                RoundedRectangle(cornerRadius: 30)
                    .fill(
                        LinearGradient(colors: [Color.orange.opacity(0.8), Color.pink.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 250, height: 200)
                    .overlay(
                        VStack(spacing: 10) {
                             Image(systemName: "folder.fill")
                                 .font(.system(size: 80))
                                 .foregroundColor(.white.opacity(0.9))
                             Image(systemName: "checkmark")
                                  .font(.system(size: 40))
                                  .foregroundColor(.white)
                                  .padding(8)
                                  .background(Circle().fill(Color.green))
                                  .offset(x: 40, y: 20)
                        }
                    )
                    .shadow(radius: 20)
            }
            
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(loc.text("非常干净！", "Very Clean!"))
                        .font(.title)
                        .fontWeight(.bold)
                }
                
                Text(loc.text("没有发现大型或旧文件。", "No large or old files found."))
                    .font(.body)
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
            
            // Back or Rescan button
            CircularActionButton(
                title: loc.text(
    simplifiedChinese: "返回",
    traditionalChinese: "返回",
    english: "Back",
    japanese: "戻る",
    korean: "뒤로",
    russian: "Назад"
),
                gradient: GradientStyles.largeFiles,
                action: {
                    scanner.reset()
                }
            )
            .padding(.bottom, 22)
        }
    }

    // MARK: - 3. Results Page (Image 2 UI is DetailsSplitView, so this is just the transition or wrapper)
    // The design shows the SplitView IS the results page effectively.
    // So we should just show LargeFileDetailsSplitView directly here or embed it.
    var resultsPage: some View {
        LargeFileDetailsSplitView(scanner: scanner)
    }
    
    // MARK: - 4. Cleaning Page (Image 3 UI)
    var cleaningPage: some View {
        VStack(spacing: 40) {
            Text(loc.text("大型和旧文件", "Large and Old Files"))
                .font(.headline)
                .opacity(0.6)
                .padding(.top, 20)
            
            Spacer()
            
            ZStack {
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.orange.opacity(0.8))
                    .frame(width: 200, height: 160)
                     .overlay(
                        Image(systemName: "folder.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(.white.opacity(0.9))
                            .padding(30)
                    )
            }
            
            VStack(spacing: 16) {
                Text(loc.text("正在移除不需要的文件...", "Removing unwanted files..."))
                    .font(.title2)
                
                HStack {
                    Image(systemName: "folder")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.orange)
                        .cornerRadius(6)
                    Text(loc.text("大型和旧文件", "Large and Old Files"))
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: scanner.cleanedSize, countStyle: .file))
                    // Spinner
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.5)
                }
                .padding()
                .frame(maxWidth: 400)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
            }
            
            Spacer()
            
            CircularActionButton(
                title: loc.text(
    simplifiedChinese: "停止",
    traditionalChinese: "停止",
    english: "Stop",
    japanese: "停止",
    korean: "정지",
    russian: "Остановить"
),
                progress: 0.8, // Fake
                showProgress: true,
                action: {
                    // Handle stop cleaning
                }
            )
            .padding(.bottom, 22)
        }
    }
    
    // MARK: - 5. Finished Page (Image 4 UI)
    var finishedPage: some View {
        HStack {
            // Left: Summary
            VStack {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(Color.white.opacity(0.8)) // Light theme in finished
                        .frame(width: 250, height: 250)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                }
                .shadow(radius: 20)
                
                Spacer()
                
                Button(loc.text("查看日志", "View Log")) {
                    // Log action
                }
                .buttonStyle(.plain)
                .padding(.bottom, 20)
            }
            .frame(width: 300)
            
            // Right: Details & Recommendations
            VStack(alignment: .leading, spacing: 20) {
                Text(loc.text("推荐", "Recommendations"))
                    .font(.headline)
                
                HStack(spacing: 10) {
                    recommendationCard(
                        icon: "ladybug", 
                        title: loc.text("扫描并查找恶意软件", "Scan for Malware"),
                        desc: loc.text("检测可能潜伏在...", "Detect latent threats..."),
                        btn: loc.text("运行深度扫描", "Run Deep Scan")
                    )
                    
                    recommendationCard(
                        icon: "puzzlepiece.extension", 
                        title: loc.text("管理扩展程序", "Manage Extensions"),
                        desc: loc.text("包括插件、小部件...", "Includes plugins..."),
                        btn: loc.text("查看扩展程序", "View Extensions")
                    )
                    
                    recommendationCard(
                        icon: "wrench.and.screwdriver", 
                        title: loc.text("维护您的 Mac", "Maintain your Mac"),
                        desc: loc.text("运行一组脚本...", "Run scripts..."),
                        btn: loc.text("运行维护", "Run Maintenance")
                    )
                }
                
                Spacer()
                
                // Result Summary
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(loc.text("\(ByteCountFormatter.string(fromByteCount: scanner.cleanedSize, countStyle: .file)) 已移除", "\(ByteCountFormatter.string(fromByteCount: scanner.cleanedSize, countStyle: .file)) Removed"))
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    Text(loc.text("您现在启动磁盘中有更多可用空间。", "You now have more free space on startup disk."))
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                
                HStack(spacing: 16) {
                    Button(action: {
                         showCleaningFinished = false
                         scanner.reset()
                    }) {
                        Text(loc.text("查看剩余项目", "View Remaining Items"))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        // Share logic
                    }) {
                        Label(loc.text("分享成果", "Share Result"), systemImage: "square.and.arrow.up")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .buttonStyle(.plain)
                
                // Ad section style
                HStack {
                    ZStack {
                        Circle().fill(Color.white).frame(width: 40, height: 40)
                        Text("II").foregroundColor(.black).fontWeight(.bold)
                    }
                    VStack(alignment: .leading) {
                        Text(loc.text("删除重复的文件", "Remove Duplicate Files"))
                            .font(.headline)
                        Text(loc.text("通过 Gemini 移除重复项...", "Remove duplicates via Gemini..."))
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.3))
                .cornerRadius(12)
            }
            .padding()
        }
        .padding(40)
        .background(Color.black.opacity(0.2)) // Darker BG for overlay effect
    }
    
    private func recommendationCard(icon: String, title: String, desc: String, btn: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
            Text(title)
                .font(.headline)
                .lineLimit(2)
            Text(desc)
                .font(.caption)
                .foregroundColor(.secondaryText)
                .lineLimit(3)
            Spacer()
            Button(action: {}) {
                Text(btn)
                    .font(.caption)
                    .foregroundColor(.black)
                    .padding(8)
                    .background(Color.yellow)
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(width: 140, height: 200)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}
