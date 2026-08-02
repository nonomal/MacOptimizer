import SwiftUI

struct LargeFileDetailsSplitView: View {
    @ObservedObject var scanner: LargeFileScanner
    @ObservedObject private var loc = LocalizationManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedCategory: String = "All"
    @State private var searchText = ""
    @State private var sortOption: SortOption = .size
    @State private var showDeleteConfirmation = false
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""
    @State private var showDeleteSuccess = false
    @State private var successMessage = ""
    
    enum SortOption {
        case size, name, date
    }
    
    // Categories matching the design
    private let categories = [
        "All", 
        "Archives", "Documents", "Movies", "Music", "Pictures", "Others", // Type based
        "Huge", "Medium", "Small", // Size based
        "One Month Ago", "One Week Ago", "One Year Ago" // Date based
    ]
    
    // Filter logic helper
    private func filterFiles(for category: String) -> [FileItem] {
        let files = scanner.foundFiles
        switch category {
        case "All": return files
        case "Movies": return files.filter { ["mp4", "mov", "avi", "mkv", "m4v"].contains($0.type.lowercased()) }
        case "Archives": return files.filter { ["zip", "rar", "7z", "tar", "gz", "dmg", "iso", "pkg"].contains($0.type.lowercased()) }
        case "Music": return files.filter { ["mp3", "wav", "aac", "flac", "m4a"].contains($0.type.lowercased()) }
        case "Pictures": return files.filter { ["jpg", "jpeg", "png", "gif", "heic", "tiff", "bmp", "svg"].contains($0.type.lowercased()) }
        case "Documents": return files.filter { ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "md"].contains($0.type.lowercased()) }
        case "Others":
            let knownTypes = ["mp4", "mov", "avi", "mkv", "m4v", "zip", "rar", "7z", "tar", "gz", "dmg", "iso", "pkg", "mp3", "wav", "aac", "flac", "m4a", "jpg", "jpeg", "png", "gif", "heic", "tiff", "bmp", "svg", "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "md"]
            return files.filter { !knownTypes.contains($0.type.lowercased()) }
            
        case "Huge": return files.filter { $0.size > 1024 * 1024 * 1024 } // > 1GB
        case "Medium": return files.filter { $0.size >= 500 * 1024 * 1024 && $0.size <= 1024 * 1024 * 1024 } // 500MB - 1GB
        case "Small": return files.filter { $0.size >= 50 * 1024 * 1024 && $0.size < 500 * 1024 * 1024 } // 50MB - 500MB
            
        case "One Month Ago":
            let date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            return files.filter { $0.accessDate < date }
        case "One Week Ago":
            let date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            return files.filter { $0.accessDate < date }
        case "One Year Ago":
            let date = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
            return files.filter { $0.accessDate < date }
            
        default: return files
        }
    }

    var filteredFiles: [FileItem] {
        let baseFiles = filterFiles(for: selectedCategory)
        
        let files = baseFiles.filter { file in
            if searchText.isEmpty { return true }
            return file.name.localizedCaseInsensitiveContains(searchText)
        }
        
        // Sorting
        return files.sorted {
            switch sortOption {
            case .size: return $0.size > $1.size
            case .name: return $0.name < $1.name
            case .date: return $0.accessDate > $1.accessDate
            }
        }
    }
    
    // Calculate total size for a category
    private func sizeForCategory(_ category: String) -> String {
        let files = filterFiles(for: category)
        let total = files.reduce(0) { $0 + $1.size }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }
    

    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(spacing: 0) {
                // Return button area
                HStack {
                    Button(action: {
                        withAnimation {
                            scanner.reset()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text(loc.text(
    simplifiedChinese: "返回",
    traditionalChinese: "返回",
    english: "Back",
    japanese: "戻る",
    korean: "뒤로",
    russian: "Назад"
))
                        }
                        .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(16)
                
                // Sidebar List
                ScrollView {
                    VStack(spacing: 2) {
                        groupHeader("All Files")
                        categoryRow(title: "All", isSelected: selectedCategory == "All")
                            .onTapGesture { selectedCategory = "All" }
                        
                        groupHeader("Type")
                        ForEach(["Archives", "Others"], id: \.self) { cat in
                            categoryRow(title: cat, isSelected: selectedCategory == cat)
                                .onTapGesture { selectedCategory = cat }
                        }
                        // Only show non-empty categories or main ones? User screenshot has limited list.
                        // I will add the others but maybe conditionally hide empty ones later if requested.
                        // For now showing specific requested ones + standard ones ensuring coverage.
                        ForEach(["Documents", "Movies", "Music", "Pictures"], id: \.self) { cat in
                            categoryRow(title: cat, isSelected: selectedCategory == cat)
                                .onTapGesture { selectedCategory = cat }
                        }
                        
                        groupHeader("Size")
                        ForEach(["Huge", "Medium", "Small"], id: \.self) { cat in
                            categoryRow(title: cat, isSelected: selectedCategory == cat)
                                .onTapGesture { selectedCategory = cat }
                        }
                        
                        groupHeader("Date")
                        ForEach(["One Week Ago", "One Month Ago", "One Year Ago"], id: \.self) { cat in
                            categoryRow(title: cat, isSelected: selectedCategory == cat)
                                .onTapGesture { selectedCategory = cat }
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
            .frame(width: 200)
            .background(Color.white.opacity(0.05))
            
            // Content
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Text(categoryTitle(selectedCategory))
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Sort Menu
                    Menu {
                        Button(loc.text("大小", "Size")) { sortOption = .size }
                        Button(loc.text("名称", "Name")) { sortOption = .name }
                        Button(loc.text("日期", "Date")) { sortOption = .date }
                    } label: {
                        HStack(spacing: 4) {
                            Text(loc.text("排序方式按", "Sort by"))
                            Text(sortOptionString)
                            Image(systemName: "chevron.down")
                        }
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    }
                    .menuStyle(.borderlessButton)
                    
                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondaryText)
                        TextField(loc.text(
    simplifiedChinese: "搜索",
    traditionalChinese: "搜尋",
    english: "Search",
    japanese: "検索する",
    korean: "검색",
    russian: "Поиск"
), text: $searchText)
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)
                    }
                    .padding(6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
                    .frame(width: 200)
                }
                .padding(12)
                .background(Color.white.opacity(0.05))
                
                // File List
                List {
                    ForEach(filteredFiles) { file in
                        LargeFileItemRow(file: file, isSelected: scanner.selectedFiles.contains(file.id), onToggle: {
                            if scanner.selectedFiles.contains(file.id) {
                                scanner.selectedFiles.remove(file.id)
                            } else {
                                scanner.selectedFiles.insert(file.id)
                            }
                        }, onIgnore: {
                            scanner.foundFiles.removeAll { $0.id == file.id }
                            scanner.selectedFiles.remove(file.id)
                            scanner.totalSize = scanner.foundFiles.reduce(0) { $0 + $1.size }
                        })
                        .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                        .listRowBackground(Color.clear)
                        .compatibleListRowSeparatorHidden()
                    }
                }
                .listStyle(.plain)
                .compatibleScrollContentBackgroundHidden()
                
                // Bottom Bar
                HStack(spacing: 20) {
                    Spacer()
                    
                    // Left side: Immediate Remove options
                    Menu {
                        Button(loc.L("selectAll")) {
                            scanner.selectedFiles = Set(filteredFiles.map { $0.id })
                        }
                        Button(loc.text("取消选择", "Deselect All")) {
                            scanner.selectedFiles.removeAll()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(loc.text("立即移除", "Remove Immediately"))
                            Image(systemName: "chevron.up")
                        }
                        .foregroundColor(.secondaryText)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    
                    // Center: Circular Action Button
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        ZStack {
                            Circle()
                                .fill(scanner.selectedFiles.isEmpty ? Color.gray.opacity(0.3) : Color.white.opacity(0.2))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                            
                            VStack(spacing: 4) {
                                Text(loc.text("移除", "Remove"))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                Text(ByteCountFormatter.string(fromByteCount: scanner.totalSelectedSize, countStyle: .file))
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(scanner.selectedFiles.isEmpty)
                    .alert(loc.text("确认删除", "Confirm Deletion"), isPresented: $showDeleteConfirmation) {
                        Button(loc.text("取消", "Cancel"), role: .cancel) { }
                        Button(loc.text("删除", "Delete"), role: .destructive) {
                            Task {
                                let result = await scanner.deleteItems(scanner.selectedFiles)
                                if result.isSuccessful {
                                    successMessage = String(format: loc.text("已删除 %d 个文件，释放了 %@", "Deleted %d files, freed %@"), result.successCount, ByteCountFormatter.string(fromByteCount: result.recoveredSize, countStyle: .file))
                                    showDeleteSuccess = true
                                } else {
                                    let failedList = result.failedFiles.prefix(5).joined(separator: "\n")
                                    let moreCount = result.failedFiles.count > 5 ? "\n..." + String(format: loc.text("还有 %d 个文件失败", "and %d more files failed"), result.failedFiles.count - 5) : ""
                                    deleteErrorMessage = String(format: loc.text("删除 %d 个文件失败:\n%s%s", "Failed to delete %d files:\n%s%s"), result.failedCount, failedList, moreCount)
                                    showDeleteError = true
                                }
                            }
                        }
                    } message: {
                        Text(String(format: loc.text("确定要删除 %d 个文件吗？", "Are you sure you want to delete %d files?"), scanner.selectedFiles.count))
                    }
                    
                    // Right Side: Hidden balancer
                    Menu { } label: {
                        HStack(spacing: 4) {
                            Text(loc.text("立即移除", "Remove Immediately"))
                            Image(systemName: "chevron.up") 
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .opacity(0)
                    .disabled(true)
                    
                    Spacer()
                }
                .padding()
                .padding(.bottom, 20)
            }
        }
        .alert(loc.text("删除失败", "Deletion Failed"), isPresented: $showDeleteError) {
            Button(loc.text("确定", "OK")) { }
        } message: {
            Text(deleteErrorMessage)
        }
        .alert(loc.text("删除成功", "Deletion Successful"), isPresented: $showDeleteSuccess) {
            Button(loc.text("确定", "OK")) { }
        } message: {
            Text(successMessage)
        }
    }
    
    private var sortOptionString: String {
        switch sortOption {
        case .size: return loc.text("大小", "Size")
        case .name: return loc.text("名称", "Name")
        case .date: return loc.text("日期", "Date")
        }
    }
    
    private func groupHeader(_ title: String) -> some View {
        HStack {
            Text(categoryLocalized(title))
                .font(.caption)
                .foregroundColor(.tertiaryText)
                .padding(.top, 8)
                .padding(.bottom, 4)
            Spacer()
        }
        .padding(.horizontal, 12)
    }
    
    private func categoryRow(title: String, isSelected: Bool) -> some View {
        HStack {
            // Circle Checkbox style indicator
            ZStack {
                Circle()
                    .stroke(isSelected ? Color.blue : Color.white.opacity(0.3), lineWidth: 1)
                    .frame(width: 14, height: 14)
                if isSelected {
                    Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                }
            }
            
            Text(categoryLocalized(title))
                .foregroundColor(.white)
                .font(.system(size: 13))
            
            Spacer()
            
            // Show Size
            Text(sizeForCategory(title))
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
    
    private func categoryLocalized(_ title: String) -> String {
        let translations: [String: [AppLanguage: String]] = [
            "All Files": [.chinese: "所有文件", .traditionalChinese: "所有檔案", .english: "All Files", .japanese: "すべてのファイル", .korean: "모든 파일", .russian: "Все файлы"],
            "Type": [.chinese: "按类型", .traditionalChinese: "依類型", .english: "Type", .japanese: "種類別", .korean: "유형별", .russian: "По типу"],
            "Size": [.chinese: "按大小", .traditionalChinese: "依大小", .english: "Size", .japanese: "サイズ別", .korean: "크기별", .russian: "По размеру"],
            "Date": [.chinese: "按访问日期", .traditionalChinese: "依存取日期", .english: "Date", .japanese: "アクセス日別", .korean: "접근 날짜별", .russian: "По дате доступа"],
            "All": [.chinese: "所有文件", .traditionalChinese: "所有檔案", .english: "All", .japanese: "すべて", .korean: "전체", .russian: "Все"],
            "Movies": [.chinese: "视频", .traditionalChinese: "影片", .english: "Movies", .japanese: "ムービー", .korean: "동영상", .russian: "Видео"],
            "Archives": [.chinese: "存档", .traditionalChinese: "封存檔", .english: "Archives", .japanese: "アーカイブ", .korean: "압축 파일", .russian: "Архивы"],
            "Music": [.chinese: "音乐", .traditionalChinese: "音樂", .english: "Music", .japanese: "ミュージック", .korean: "음악", .russian: "Музыка"],
            "Pictures": [.chinese: "图片", .traditionalChinese: "圖片", .english: "Pictures", .japanese: "画像", .korean: "사진", .russian: "Изображения"],
            "Documents": [.chinese: "文档", .traditionalChinese: "文件", .english: "Documents", .japanese: "書類", .korean: "문서", .russian: "Документы"],
            "Others": [.chinese: "其他", .traditionalChinese: "其他", .english: "Others", .japanese: "その他", .korean: "기타", .russian: "Другие"],
            "Huge": [.chinese: "巨大", .traditionalChinese: "超大", .english: "Huge", .japanese: "特大", .korean: "매우 큼", .russian: "Очень большие"],
            "Small": [.chinese: "较小", .traditionalChinese: "較小", .english: "Small", .japanese: "小", .korean: "작음", .russian: "Небольшие"],
            "Medium": [.chinese: "中等", .traditionalChinese: "中等", .english: "Medium", .japanese: "中", .korean: "중간", .russian: "Средние"],
            "One Year Ago": [.chinese: "一年前", .traditionalChinese: "一年前", .english: "One Year Ago", .japanese: "1年以上前", .korean: "1년 전", .russian: "Год назад"],
            "One Month Ago": [.chinese: "一个月前", .traditionalChinese: "一個月前", .english: "One Month Ago", .japanese: "1か月以上前", .korean: "1개월 전", .russian: "Месяц назад"],
            "One Week Ago": [.chinese: "一周前", .traditionalChinese: "一週前", .english: "One Week Ago", .japanese: "1週間以上前", .korean: "1주 전", .russian: "Неделю назад"]
        ]
        return translations[title]?[loc.currentLanguage] ?? title
        }
    
    private func categoryTitle(_ title: String) -> String {
        return categoryLocalized(title)
    }
}

struct LargeFileItemRow: View {
    let file: FileItem
    let isSelected: Bool
    let onToggle: () -> Void
    let onIgnore: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .gray)
            
            Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path))
                .resizable()
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading) {
                Text(file.name)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(file.url.path)
                    .font(.system(size: 11))
                    .foregroundColor(.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(file.formattedSize)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .background(isHovering ? Color.white.opacity(0.05) : Color.clear)
        .cornerRadius(4)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                onToggle()
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .scanResultContextMenu(
            isSelected: isSelected,
            displayName: file.name,
            url: file.url,
            onToggleSelection: onToggle,
            onIgnore: onIgnore
        )
    }
}
