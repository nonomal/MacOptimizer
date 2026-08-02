import AppKit
import Quartz
import SwiftUI

/// Persistent, exact-path exclusions shared by every file-producing scanner.
/// An ignored directory does not implicitly hide its descendants: this mirrors
/// the per-result-row action and avoids silently expanding the user's choice.
@MainActor
final class ScanResultIgnoreStore: ObservableObject {
    static let shared = ScanResultIgnoreStore()

    @Published private(set) var ignoredPaths: Set<String>

    private let defaultsKey = "ScanResultIgnoredPaths"

    private init() {
        ignoredPaths = Set(UserDefaults.standard.stringArray(forKey: defaultsKey) ?? [])
    }

    nonisolated static func normalizedPath(for url: URL) -> String {
        let path = url.standardizedFileURL.path
        if path.count > 1, path.hasSuffix("/") {
            return String(path.dropLast())
        }
        return path
    }

    /// Thread-safe read used by background scanners before publishing results.
    nonisolated static func shouldInclude(_ url: URL) -> Bool {
        let ignored = Set(UserDefaults.standard.stringArray(forKey: "ScanResultIgnoredPaths") ?? [])
        return !ignored.contains(normalizedPath(for: url))
    }

    func isIgnored(_ url: URL) -> Bool {
        ignoredPaths.contains(Self.normalizedPath(for: url))
    }

    func ignore(_ url: URL) {
        ignoredPaths.insert(Self.normalizedPath(for: url))
        persist()
    }

    func restore(_ url: URL) {
        ignoredPaths.remove(Self.normalizedPath(for: url))
        persist()
    }

    func restoreAll() {
        ignoredPaths.removeAll()
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(ignoredPaths.sorted(), forKey: defaultsKey)
    }
}

/// Retains the Quick Look data source for as long as the system panel is open.
@MainActor
private final class ScanResultQuickLookController: NSObject, @preconcurrency QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = ScanResultQuickLookController()
    private var previewURL: URL?

    func present(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path),
              let panel = QLPreviewPanel.shared() else { return }

        previewURL = url
        panel.dataSource = self
        panel.delegate = self
        panel.currentPreviewItemIndex = 0
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewURL == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        previewURL as NSURL?
    }
}

extension View {
    /// CleanMyMac-compatible menu used by every concrete scan result row.
    func scanResultContextMenu(
        isSelected: Bool,
        displayName: String,
        url: URL,
        onToggleSelection: @escaping () -> Void,
        onIgnore: (() -> Void)? = nil
    ) -> some View {
        contextMenu {
            Button {
                onToggleSelection()
            } label: {
                Text(isSelected
                    ? LocalizationManager.shared.text("取消选择“\(displayName)”", "Deselect \"\(displayName)\"")
                    : LocalizationManager.shared.text("选择“\(displayName)”", "Select \"\(displayName)\""))
            }

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } label: {
                Text(LocalizationManager.shared.text("在“访达”中显示", "Show in Finder"))
            }

            Button {
                ScanResultQuickLookController.shared.present(url)
            } label: {
                Text(LocalizationManager.shared.text("快速查看“\(displayName)”", "Quick Look \"\(displayName)\""))
            }

            Button {
                if isSelected { onToggleSelection() }
                ScanResultIgnoreStore.shared.ignore(url)
                onIgnore?()
            } label: {
                Text(LocalizationManager.shared.text("忽略", "Ignore"))
            }
        }
    }
}
