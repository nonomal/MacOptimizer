import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set application icon for all windows
        if let appIconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let appIcon = NSImage(contentsOfFile: appIconPath) {
            NSApp.applicationIconImage = appIcon
        }

        // Match the locally installed CleanMyMac X primary content size.
        // Apply it after SwiftUI has created the WindowGroup window.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard let window = NSApp.windows.first else { return }
            window.minSize = NSSize(width: 980, height: 600)
            window.setContentSize(NSSize(width: 1090, height: 672))
            window.isOpaque = true
            window.backgroundColor = NSColor(red: 0.10, green: 0.11, blue: 0.22, alpha: 1)
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            window.contentView?.wantsLayer = true
            window.contentView?.layer?.backgroundColor = window.backgroundColor.cgColor

            window.center()
            AppMenuLocalizer.apply(LocalizationManager.shared.currentLanguage)
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
