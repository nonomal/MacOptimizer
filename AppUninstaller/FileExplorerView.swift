import SwiftUI

struct FileExplorerView: View {
    @StateObject private var service = FileExplorerService()
    @ObservedObject private var loc = LocalizationManager.shared
    @State private var showNewFolderDialog = false
    @State private var showNewFileDialog = false
    @State private var showRenameDialog = false
    @State private var showDeleteConfirmation = false
    @State private var newItemName = ""
    @State private var selectedItem: ExplorerFileItem?
    @State private var pathInputText = ""
    @State private var isEditingPath = false
    @State private var viewMode: ViewMode = .list
    
    enum ViewMode {
        case list, grid
    }
    
    var body: some View {
        HSplitView {
            // 左侧边栏 - 快捷访问
            sidebarView
                .frame(width: 180)
            
            // 主内容区
            VStack(spacing: 0) {
                // 顶部工具栏
                toolbarView
                
                // 路径栏
                pathBarView
                
                // 文件列表
                if service.isLoading {
                    Spacer()
                    ProgressView()
                    Text(loc.L("loading"))
                        .foregroundColor(.secondaryText)
                    Spacer()
                } else if let error = service.error {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text(error)
                            .foregroundColor(.secondaryText)
                            .multilineTextAlignment(.center)
                        Button(loc.L("go_back")) {
                            service.goUp()
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.blue)
                    }
                    .padding()
                    Spacer()
                } else {
                    fileListView
                }
            }
        }
        .sheet(isPresented: $showNewFolderDialog) {
            newItemDialog(title: loc.text("新建文件夹", "New Folder"), placeholder: loc.text("文件夹名称", "Folder Name")) {
                try service.createFolder(name: newItemName)
            }
        }
        .sheet(isPresented: $showNewFileDialog) {
            newItemDialog(title: loc.text("新建文件", "New File"), placeholder: loc.text("文件名称", "File Name")) {
                try service.createFile(name: newItemName)
            }
        }
        .sheet(isPresented: $showRenameDialog) {
            renameDialog
        }
        .confirmationDialog(loc.text("确认删除", "Confirm Deletion"), isPresented: $showDeleteConfirmation) {
            Button(loc.text("移至废纸篓", "Move to Trash"), role: .destructive) {
                if let item = selectedItem {
                    try? service.deleteItem(item, moveToTrash: true)
                }
            }
            Button(loc.text("永久删除", "Delete Permanently"), role: .destructive) {
                if let item = selectedItem {
                    try? service.deleteItem(item, moveToTrash: false)
                }
            }
            Button(loc.text("取消", "Cancel"), role: .cancel) {}
        } message: {
            if let item = selectedItem {
                Text(loc.text("确定要删除“\(item.name)”吗？", "Are you sure you want to delete \"\(item.name)\"?"))
            }
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(loc.L("quick_access"))
                .font(.caption)
                .foregroundColor(.tertiaryText)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
            
            ForEach(service.quickAccessItems) { item in
                Button(action: { service.navigateTo(item.url) }) {
                    HStack(spacing: 10) {
                        Image(systemName: item.icon)
                            .frame(width: 20)
                            .foregroundColor(.blue)
                        Text(item.name)
                            .font(.system(size: 13))
                            .foregroundColor(.primaryText)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        service.currentPath == item.url
                            ? Color.white.opacity(0.1)
                            : Color.clear
                    )
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            // 显示隐藏文件开关
            Toggle(isOn: $service.showHiddenFiles) {
                Text(loc.L("show_hidden"))
                    .font(.caption)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .padding(16)
            .onChange(of: service.showHiddenFiles) { _ in
                service.refresh()
            }
        }
        .background(Color.black.opacity(0.2))
    }
    
    // MARK: - Toolbar
    
    private var toolbarView: some View {
        HStack(spacing: 12) {
            // 导航按钮
            HStack(spacing: 4) {
                Button(action: { service.goBack() }) {
                    Image(systemName: "chevron.left")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(!service.canGoBack)
                .foregroundColor(service.canGoBack ? .white : .gray)
                
                Button(action: { service.goForward() }) {
                    Image(systemName: "chevron.right")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(!service.canGoForward)
                .foregroundColor(service.canGoForward ? .white : .gray)
                
                Button(action: { service.goUp() }) {
                    Image(systemName: "chevron.up")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundColor(.white)
            }
            .padding(4)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            
            Spacer()
            
            // 操作按钮
            HStack(spacing: 8) {
                Button(action: { showNewFolderDialog = true }) {
                    Label(loc.L("new_folder"), systemImage: "folder.badge.plus")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.8))
                
                Button(action: { showNewFileDialog = true }) {
                    Label(loc.L("new_file"), systemImage: "doc.badge.plus")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.8))
                
                Divider().frame(height: 20)
                
                Button(action: { openTerminalAtCurrentPath() }) {
                    Label(loc.L("open_in_terminal"), systemImage: "terminal")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.8))
                
                Button(action: { service.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.15))
    }
    
    // MARK: - Path Bar
    
    private var pathBarView: some View {
        HStack(spacing: 8) {
            if isEditingPath {
                // 编辑模式 - 显示输入框
                TextField(loc.text("输入路径...", "Enter a path..."), text: $pathInputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(6)
                    .onSubmit {
                        navigateToInputPath()
                    }
                
                Button(loc.text("跳转", "Go")) {
                    navigateToInputPath()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.blue)
                
                Button(loc.text("取消", "Cancel")) {
                    isEditingPath = false
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondaryText)
            } else {
                // 正常模式 - 显示面包屑
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(service.pathComponents.enumerated()), id: \.offset) { index, component in
                            Button(action: { service.navigateTo(component.1) }) {
                                Text(component.0)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            
                            if index < service.pathComponents.count - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.tertiaryText)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // 编辑按钮
                Button(action: {
                    pathInputText = service.currentPath.path
                    isEditingPath = true
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundColor(.tertiaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.1))
    }
    
    private func navigateToInputPath() {
        let path = pathInputText.trimmingCharacters(in: .whitespaces)
        let expandedPath = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)
        
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            service.navigateTo(url)
            isEditingPath = false
        } else {
            service.error = loc.text("路径不存在或不是目录：\(path)", "The path does not exist or is not a folder: \(path)")
        }
    }
    
    // MARK: - File List
    
    private var fileListView: some View {
        List(service.items) { item in
            HStack(spacing: 0) {
                ExplorerFileRow(item: item, isSelected: selectedItem?.id == item.id)
                
                Spacer()
                
                // 进入目录按钮
                if item.isDirectory {
                    Button(action: { service.navigateTo(item.url) }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.tertiaryText)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                if item.isDirectory {
                    service.navigateTo(item.url)
                } else {
                    service.openItem(item)
                }
            }
            .onTapGesture {
                selectedItem = item
            }
            .contextMenu {
                contextMenuContent(for: item)
            }
            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
            .listRowBackground(
                selectedItem?.id == item.id
                    ? Color.blue.opacity(0.3)
                    : Color.clear
            )
            .compatibleListRowSeparatorHidden()
        }
        .listStyle(.plain)
        .compatibleScrollContentBackgroundHidden()
    }
    
    @ViewBuilder
    private func contextMenuContent(for item: ExplorerFileItem) -> some View {
        let svc = service
        
        Button(loc.text("打开", "Open"), systemImage: "arrow.up.forward.square") {
            svc.openItem(item)
        }
        
        if item.isDirectory {
            Button(loc.text("进入目录", "Open Folder"), systemImage: "folder") {
                svc.navigateTo(item.url)
            }
        }
        
        Divider()
        
        Button(loc.text("在 Finder 中显示", "Show in Finder"), systemImage: "folder.badge.gear") {
            svc.revealInFinder(item)
        }
        
        Divider()
        
        Button(loc.text("重命名", "Rename"), systemImage: "pencil") {
            selectedItem = item
            newItemName = item.name
            showRenameDialog = true
        }
        
        Divider()
        
        Button(loc.text("删除", "Delete"), systemImage: "trash", role: .destructive) {
            selectedItem = item
            showDeleteConfirmation = true
        }
    }
    
    // MARK: - Open Terminal
    
    private func openTerminalAtCurrentPath() {
        let path = service.currentPath.path
        let escapedPath = path.replacingOccurrences(of: "'", with: "'\\''")
        
        // 使用 osascript 命令 - 尝试在现有窗口执行，如果没有窗口则创建一个
        let script = """
        tell application "Terminal"
            if (count of windows) > 0 then
                do script "cd '\(escapedPath)'" in front window
            else
                do script "cd '\(escapedPath)'"
            end if
            activate
        end tell
        """
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        
        do {
            try process.run()
        } catch {
            print("Failed to open terminal: \(error)")
        }
    }
    
    // MARK: - Dialogs
    
    private func newItemDialog(title: String, placeholder: String, action: @escaping () throws -> Void) -> some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.headline)
            
            TextField(placeholder, text: $newItemName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
            
            HStack {
                Button(loc.text("取消", "Cancel")) {
                    showNewFolderDialog = false
                    showNewFileDialog = false
                    newItemName = ""
                }
                .keyboardShortcut(.escape)
                
                Button(loc.text("创建", "Create")) {
                    do {
                        try action()
                        showNewFolderDialog = false
                        showNewFileDialog = false
                        newItemName = ""
                    } catch {
                        service.error = error.localizedDescription
                    }
                }
                .keyboardShortcut(.return)
                .disabled(newItemName.isEmpty)
            }
        }
        .padding(30)
    }
    
    private var renameDialog: some View {
        VStack(spacing: 20) {
            Text(loc.text("重命名", "Rename"))
                .font(.headline)
            
            TextField(loc.text("新名称", "New Name"), text: $newItemName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
            
            HStack {
                Button(loc.text("取消", "Cancel")) {
                    showRenameDialog = false
                    newItemName = ""
                }
                .keyboardShortcut(.escape)
                
                Button(loc.text("确定", "OK")) {
                    if let item = selectedItem {
                        try? service.renameItem(item, to: newItemName)
                    }
                    showRenameDialog = false
                    newItemName = ""
                }
                .keyboardShortcut(.return)
                .disabled(newItemName.isEmpty)
            }
        }
        .padding(30)
    }
}

// MARK: - File Item Row

struct ExplorerFileRow: View {
    let item: ExplorerFileItem
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(nsImage: item.icon)
                .resizable()
                .frame(width: 24, height: 24)
            
            // 文件名
            Text(item.name)
                .font(.system(size: 13))
                .foregroundColor(.primaryText)
                .lineLimit(1)
            
            Spacer()
            
            // 大小
            Text(item.formattedSize)
                .font(.system(size: 11))
                .foregroundColor(.tertiaryText)
                .frame(width: 70, alignment: .trailing)
            
            // 修改时间
            Text(item.formattedDate)
                .font(.system(size: 11))
                .foregroundColor(.tertiaryText)
                .frame(width: 120, alignment: .trailing)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.blue.opacity(0.2) : Color.clear)
        )
    }
}
