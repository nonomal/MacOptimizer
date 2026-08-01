import SwiftUI
import AppKit

// MARK: - 1. Landing View
struct ShredderLandingView: View {
    @Binding var showFileImporter: Bool // Kept for signature compatibility if needed, but unused for logic now
    @Environment(\.localization) var loc
    var selectFiles: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 25) {
            VStack(alignment: .leading, spacing: 0) {
                Text(loc.L("shredder_title"))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)

                Text(loc.L("shredder_subtitle"))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.72))
                    .padding(.top, 10)

                VStack(alignment: .leading, spacing: 64) {
                    featureRow(
                        image: "shredder_benefit_secure",
                        title: loc.L("secure_erase"),
                        subtitle: loc.L("secure_erase_desc")
                    )

                    featureRow(
                        image: "shredder_benefit_finder",
                        title: loc.L("resolve_finder_errors"),
                        subtitle: loc.L("resolve_finder_errors_desc")
                    )
                }
                .padding(.top, 40)

                Button(action: { selectFiles() }) {
                    Text(loc.L("select_files"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 0.10, green: 0.20, blue: 0.25))
                        .frame(width: 92, height: 31)
                        .background(Color(red: 0.42, green: 0.82, blue: 0.94))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(ShredderLandingButtonStyle())
                .padding(.top, 48)
            }
            .frame(width: 320, alignment: .leading)

            resourceImage("shredder_module")
                .frame(width: 350, height: 350)
                .padding(.top, 7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.leading, 98)
        .padding(.top, 152)
    }
    
    private func featureRow(image: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 18) {
            resourceImage(image)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(subtitle)
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
}

private struct ShredderLandingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? -0.08 : 0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

// MARK: - 2. Selection View
struct ShredderSelectionView: View {
    @ObservedObject var service: ShredderService
    @Binding var showFileImporter: Bool
    @Environment(\.localization) var loc

    private var selectedSize: Int64 {
        service.items.reduce(Int64(0)) { $0 + $1.size }
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ZStack {
                    Text(loc.L("shredder_title"))
                        .foregroundColor(.white.opacity(0.58))
                        .font(.system(size: 12, weight: .medium))

                    HStack {
                        Button(action: { service.reset() }) {
                            HStack(spacing: 5) {
                                Image(systemName: "chevron.left")
                                Text(loc.L("restart"))
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.68))
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                }
                .frame(height: 52)
                .padding(.horizontal, 18)

                List {
                    ForEach(service.items) { item in
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "4DDEE8"))
                            
                            Image(nsImage: item.icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 28, height: 28)
                            
                            Text(item.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.88))
                            
                            Spacer()
                            
                            Text(item.formattedSize)
                                .foregroundColor(.white.opacity(0.66))
                                .font(.system(size: 12))
                        }
                        .frame(height: 50)
                        .listRowInsets(EdgeInsets(top: 0, leading: 26, bottom: 0, trailing: 22))
                        .listRowBackground(Color.clear)
                        .compatibleListRowSeparatorHidden()
                        .scanResultContextMenu(
                            isSelected: true,
                            displayName: item.name,
                            url: item.url,
                            onToggleSelection: {},
                            onIgnore: { service.removeItem(id: item.id) }
                        )
                    }
                    .onDelete { indexSet in
                        service.removeItems(at: indexSet)
                    }
                }
                .listStyle(.plain)
                .compatibleScrollContentBackgroundHidden()
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.top, 38)
                .padding(.bottom, 108)
            }

            CleanMyMacBottomActionSlot {
                ZStack {
                    Menu {
                        Button(loc.L("remove_now")) {
                            Task { await service.startShredding() }
                        }
                    } label: {
                        Text(loc.L("remove_now"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.66))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .offset(x: -95)

                    Button {
                        Task { await service.startShredding() }
                    } label: {
                        CleanMyMacActionOrb(
                            title: loc.L("shred"),
                            gradient: LinearGradient(
                                colors: [
                                    Color(red: 0.52, green: 0.62, blue: 0.75),
                                    Color(red: 0.34, green: 0.40, blue: 0.61)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            glowColor: Color(red: 0.25, green: 0.82, blue: 0.98),
                            ringColor: Color(red: 0.35, green: 0.86, blue: 0.98)
                        )
                    }
                    .buttonStyle(.plain)

                    Text(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.62))
                        .fixedSize()
                        .offset(x: 70)
                }
                .frame(width: 390, height: CleanMyMacWindowMetrics.actionOrbFrame.height)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - 3. Progress View
struct ShreddingProgressView: View {
    @ObservedObject var service: ShredderService
    @Environment(\.localization) var loc
    
    var body: some View {
        VStack {
            Spacer()
            
            ShredderIconView(isAnimating: true)
                .frame(width: 200, height: 200)
            
            Spacer()
            
            Text(loc.L("cleaning_system"))
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.bottom, 16)
            
            // Current Item
            if !service.currentItemName.isEmpty {
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundColor(.white)
                    Text(service.currentItemName)
                        .foregroundColor(.white)
                    Spacer()
                }
                .frame(maxWidth: 400)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Stop button
            Button(action: { service.stopShredding() }) {
                ZStack {
                    Circle()
                        .stroke(Color.green, lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    Text(service.isStopping
                         ? (loc.text("正在停止", "Stopping"))
                         : loc.L("stop"))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - 4. Result View
struct ShredderResultView: View {
    @ObservedObject var service: ShredderService
    @Environment(\.localization) var loc
    
    var body: some View {
        HStack {
            ShredderIconView(isAnimating: false)
                .frame(width: 300, height: 300)
                .padding(.leading, 40)
            
            VStack(alignment: .leading, spacing: 16) {
                Text(loc.L("cleaning_complete"))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 24))
                    
                    Text(ByteCountFormatter.string(fromByteCount: service.totalSizeCleared, countStyle: .file))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(loc.L("cleaned"))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Text(String(format: loc.L("free_space_available"), Double(Helpers.getFreeDiskSpace()) / 1_000_000_000))
                    .foregroundColor(.white.opacity(0.7))
                
                Button(action: { /* Share? */ }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text(loc.L("share_results"))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
            }
            .padding(.leading, 40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottomLeading) {
            Button(loc.L("view_log")) {
                // View log
            }
            .foregroundColor(.white.opacity(0.7))
            .buttonStyle(.plain)
            .padding(24)
        }
        .overlay(alignment: .topLeading) {
             Button(action: { service.reset() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text(loc.L("restart"))
                }
                .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .padding(16)
        }
    }
}

// MARK: - Components

struct ShredderIconView: View {
    let isAnimating: Bool
    
    @State private var dripOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.1, green: 0.6, blue: 1.0), Color(red: 0.1, green: 0.4, blue: 0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(radius: 10)
            
            // Paper
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                
                ZStack {
                    // Main Paper Body
                    Path { path in
                        let paperW = w * 0.5
                        let paperH = h * 0.6
                        let x = w * 0.25
                        let y = h * 0.2
                        
                        // Main Rect
                        path.move(to: CGPoint(x: x, y: y))
                        path.addLine(to: CGPoint(x: x + paperW - 40, y: y)) // Top edge minus fold
                        path.addLine(to: CGPoint(x: x + paperW, y: y + 40)) // Fold diagonal end
                        path.addLine(to: CGPoint(x: x + paperW, y: y + paperH)) // Right edge
                        path.addLine(to: CGPoint(x: x, y: y + paperH)) // Bottom edge
                        path.closeSubpath()
                    }
                    .fill(Color.white)
                    
                    // Folded Corner
                    Path { path in
                        let paperW = w * 0.5
                        let x = w * 0.25
                        let y = h * 0.2
                        
                        path.move(to: CGPoint(x: x + paperW - 40, y: y))
                        path.addLine(to: CGPoint(x: x + paperW - 40, y: y + 40))
                        path.addLine(to: CGPoint(x: x + paperW, y: y + 40))
                        path.closeSubpath()
                    }
                    .fill(Color.white.opacity(0.8))
                    .shadow(radius: 2)
                    
                    // Shredding/Melting Effect at Bottom
                    // We mask the bottom of the paper with "drips"
                    if isAnimating {
                        ForEach(0..<6) { i in
                             RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white)
                                .frame(width: (w * 0.5) / 9, height: 40)
                                .offset(x: (CGFloat(i) - 2.5) * ((w * 0.5) / 7), y: (h * 0.4) + (isAnimating ? 20 : 0))
                                .animation(Animation.linear(duration: 0.8).repeatForever(autoreverses: true).delay(Double(i) * 0.1), value: isAnimating)
                        }
                    } else {
                         // Static drips for design match
                         HStack(alignment: .top, spacing: 8) {
                             ForEach(0..<5) { i in
                                 RoundedRectangle(cornerRadius: 3)
                                     .fill(Color.white)
                                     .frame(width: 15, height: [30.0, 50.0, 20.0, 60.0, 40.0][i])
                             }
                         }
                         .offset(y: h * 0.3)
                    }
                }
            }
        }
    }
}

struct Helpers {
    static func getFreeDiskSpace() -> Int64 {
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()) {
             return attrs[.systemFreeSize] as? Int64 ?? 0
        }
        return 0
    }
}
