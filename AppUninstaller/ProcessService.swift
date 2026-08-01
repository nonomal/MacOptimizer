import SwiftUI
import AppKit
import Foundation

struct ProcessItem: Identifiable {
    let id = UUID()
    let pid: Int32
    let name: String
    let icon: NSImage?
    let isApp: Bool // true for GUI Apps, false for background processes
    let validationPath: String? // For apps, the bundle path
    let memoryUsage: Int64 // 内存使用量（字节）
    let cpuUsage: Double
    let user: String
    let commandPath: String
    
    var formattedPID: String {
        String(pid)
    }
    
    /// 格式化的内存使用量
    var formattedMemory: String {
        ByteCountFormatter.string(fromByteCount: memoryUsage, countStyle: .memory)
    }
}

class ProcessService: ObservableObject {
    @Published var processes: [ProcessItem] = []
    @Published var isScanning = false
    @Published var lastError: String?
    
    // 缓存 PID 到内存使用量的映射 - 使用 Set 进行高效查找
    private var memoryCache: [Int32: Int64] = [:]
    private var cpuCache: [Int32: Double] = [:]
    private var processIdSet: Set<Int32> = []
    
    // UI Update Batching
    private let uiUpdater = BatchedUIUpdater(debounceDelay: 0.05)
    func scanProcesses(showApps: Bool) async {
        await uiUpdater.batch {
            self.isScanning = true
            self.lastError = nil
        }
        
        // 首先获取所有进程的内存使用量
        await fetchMemoryUsage()
        
        var items: [ProcessItem] = []
        
        if showApps {
            // Get Running Applications (GUI)
            let apps = NSWorkspace.shared.runningApplications
            for app in apps {
                // Filter out some system daemons that might show up as apps but have no icon or interface
                guard app.activationPolicy == .regular else { continue }
                
                let memory = memoryCache[app.processIdentifier] ?? 0
                
                let item = ProcessItem(
                    pid: app.processIdentifier,
                    name: app.localizedName ?? "Unknown App",
                    icon: app.icon,
                    isApp: true,
                    validationPath: app.bundleURL?.path,
                    memoryUsage: memory,
                    cpuUsage: cpuCache[app.processIdentifier] ?? 0,
                    user: NSUserName(),
                    commandPath: app.executableURL?.path ?? app.bundleURL?.path ?? ""
                )
                items.append(item)
            }
        } else {
            // Get Background Processes using ps command
            // We focus on user processes to avoid listing thousands of system kernel threads
            let task = Process()
            task.launchPath = "/bin/ps"
            task.arguments = ["-x", "-o", "pid,%cpu,rss,user,comm"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            
            do {
                try task.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let lines = output.components(separatedBy: "\n")
                    // Skip header
                    for (index, line) in lines.enumerated() {
                        if index == 0 || line.isEmpty { continue }
                        
                        let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                        guard parts.count >= 5,
                              let pid = Int32(parts[0]),
                              let cpu = Double(parts[1]),
                              let rssKB = Int64(parts[2]) else { continue }
                        
                        // Extract name (everything after PID and RSS)
                        let user = parts[3]
                        let cmdParts = parts.dropFirst(4)
                        // Determine name from path (e.g. /usr/sbin/distnoted -> distnoted)
                        let fullPath = cmdParts.joined(separator: " ")
                        let name = URL(fileURLWithPath: fullPath).lastPathComponent
                        
                        // Filter out this app itself
                        if pid == ProcessInfo.processInfo.processIdentifier { continue }
                        
                        // RSS is in KB, convert to bytes
                        let memoryBytes = rssKB * 1024
                        
                        let item = ProcessItem(
                            pid: pid,
                            name: name,
                            icon: nil,
                            isApp: false,
                            validationPath: nil,
                            memoryUsage: memoryBytes,
                            cpuUsage: cpu,
                            user: user,
                            commandPath: fullPath
                        )
                        items.append(item)
                    }
                }
            } catch {
                print("Error scanning background processes: \(error)")
                await uiUpdater.batch {
                    self.lastError = error.localizedDescription
                }
            }
        }
        
        // Sort: Apps by memory (descending), then by name
        let sortedItems = items.sorted { 
            if $0.memoryUsage != $1.memoryUsage {
                return $0.memoryUsage > $1.memoryUsage // 内存大的排前面
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending 
        }
        
        // Update process ID set for efficient lookups
        let pidSet = Set(sortedItems.map { $0.pid })
        
        // Batch UI update
        await uiUpdater.batch {
            self.processes = sortedItems
            self.processIdSet = pidSet
            self.isScanning = false
        }
    }
    
    /// 获取所有进程的内存使用量
    private func fetchMemoryUsage() async {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-ax", "-o", "pid,%cpu,rss"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                var cache: [Int32: Int64] = [:]
                var cpuValues: [Int32: Double] = [:]
                let lines = output.components(separatedBy: "\n")
                for (index, line) in lines.enumerated() {
                    if index == 0 || line.isEmpty { continue }
                    
                    let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    guard parts.count >= 3,
                          let pid = Int32(parts[0]),
                          let cpu = Double(parts[1]),
                          let rssKB = Int64(parts[2]) else { continue }
                    
                    // RSS is in KB, convert to bytes
                    cache[pid] = rssKB * 1024
                    cpuValues[pid] = cpu
                }
                memoryCache = cache
                cpuCache = cpuValues
            }
        } catch {
            print("Error fetching memory usage: \(error)")
            await uiUpdater.batch {
                self.lastError = error.localizedDescription
            }
        }
    }
    
    func terminateProcess(_ item: ProcessItem) {
        if item.isApp {
            // Try nice termination first for Apps
            if let app = NSRunningApplication(processIdentifier: item.pid) {
                app.terminate()
                
                // If not responding ?? Maybe force option later.
                // For now, let's update list after short delay
            }
        } else {
            // Force kill for background processes
            let task = Process()
            task.launchPath = "/bin/kill"
            task.arguments = ["-9", String(item.pid)]
            try? task.run()
        }
        
        // Batch UI removal
        Task {
            await uiUpdater.batch {
                self.processes.removeAll { $0.id == item.id }
                self.processIdSet.remove(item.pid)
            }
        }
    }

    
    func forceTerminateProcess(_ item: ProcessItem) {
        // Always use "kill -9" for force quit
        let task = Process()
        task.launchPath = "/bin/kill"
        task.arguments = ["-9", String(item.pid)]
        try? task.run()
        
        // Batch UI removal
        Task {
            await uiUpdater.batch {
                self.processes.removeAll { $0.id == item.id }
                self.processIdSet.remove(item.pid)
            }
        }
    }

    /// 清理应用数据（重置应用）
    func cleanAppData(for item: ProcessItem) async {
        // 1. 强制退出应用
        forceTerminateProcess(item)
        
        // 等待进程结束
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        
        // 2. 识别应用信息
        guard let pathString = item.validationPath else {
            return
        }
        
        let url = URL(fileURLWithPath: pathString)
        let bundle = Bundle(url: url)
        let bundleId = bundle?.bundleIdentifier
        
        // 如果没有 Bundle ID，可能无法准确找到残留文件，简单跳过或仅用名字试图扫描
        guard let bId = bundleId else { return }
        
        let icon = item.icon ?? NSImage()
        
        // 创建临时 InstalledApp 模型用于扫描
        let app = InstalledApp(
            name: item.name,
            path: url,
            bundleIdentifier: bId,
            icon: icon,
            size: 0
        )
        
        // 3. 扫描残留文件
        let scanner = ResidualFileScanner()
        let files = await scanner.scanResidualFiles(for: app)
        
        // 选中所有文件
        await MainActor.run {
            for file in files {
                file.isSelected = true
            }
            app.residualFiles = files
        }
        
        // 4. 删除数据 (保留应用本体)
        let remover = FileRemover()
        _ = await remover.removeResidualFiles(of: app, moveToTrash: true)
    }
}
