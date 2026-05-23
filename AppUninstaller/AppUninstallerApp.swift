import SwiftUI

@main
struct AppUninstallerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    // Hold a strong reference to the manager (Keep it, but access via shared in AppDelegate if needed)
    @StateObject var menuBarManager = MenuBarManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1100, minHeight: 750)
                .preferredColorScheme(.dark)
                .task {
                    // Check for Updates
                    await UpdateCheckerService.shared.checkForUpdates()
                }
        }
        .windowStyle(.hiddenTitleBar)
        
        // MenuBarExtra removed. Manager logic runs on init.
    }
}
