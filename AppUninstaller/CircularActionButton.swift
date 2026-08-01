import SwiftUI

struct CircularActionButton: View {
    let title: String
    var icon: String? = nil
    var gradient: LinearGradient? = nil
    var progress: Double? = nil
    var showProgress: Bool = false
    var scanSize: String? = nil
    let action: () -> Void
    
    // Gradient definitions
    static let blueGradient = LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let greenGradient = LinearGradient(colors: [.green.opacity(0.8), .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let grayGradient = LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let stopGradient = LinearGradient(colors: [Color(hex: "E0B0FF"), Color(hex: "BF5AF2")], startPoint: .topLeading, endPoint: .bottomTrailing) // Lighter pink/purple for Stop

    var body: some View {
        HStack(spacing: 16) {
            Button(action: action) {
                CleanMyMacActionOrb(
                    title: title,
                    gradient: gradient ?? CircularActionButton.grayGradient,
                    glowColor: .cyan,
                    ringColor: Color.cyan.opacity(0.92),
                    progress: showProgress ? progress : nil
                )
            }
            .buttonStyle(.plain)
            
            // Scan Size Text (only for Stop button usually)
            if let size = scanSize {
                Text(size)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}
