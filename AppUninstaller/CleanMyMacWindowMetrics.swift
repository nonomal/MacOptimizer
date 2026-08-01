import SwiftUI

/// Shared window geometry taken from the locally installed CleanMyMac X.
/// Bottom actions are positioned by their center instead of per-view padding,
/// so differently sized Scan/Stop/Remove buttons always use one baseline.
enum CleanMyMacWindowMetrics {
    static let titlebarContentInset: CGFloat = 23
    static let bottomActionCenterInset: CGFloat = 70
    static let actionOrbFrame = CGSize(width: 108, height: 96)
    static let actionOrbGlowDiameter: CGFloat = 108
    static let actionOrbOuterRingDiameter: CGFloat = 82
    static let actionOrbMainDiameter: CGFloat = 72
    static let actionOrbInnerRingDiameter: CGFloat = 64
}

/// The original UbiquitousButton keeps identical geometry in every module;
/// only its palette and state change.
struct CleanMyMacActionOrb: View {
    let title: String
    let gradient: LinearGradient
    let glowColor: Color
    let ringColor: Color
    var disabled = false
    var isHovered = false
    var progress: Double? = nil
    @State private var internalHovered = false

    private var hovering: Bool {
        !disabled && (isHovered || internalHovered)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(glowColor.opacity(disabled ? 0.10 : (hovering ? 0.42 : 0.30)))
                .frame(
                    width: CleanMyMacWindowMetrics.actionOrbGlowDiameter,
                    height: CleanMyMacWindowMetrics.actionOrbGlowDiameter
                )
                .blur(radius: 17)

            Circle()
                .stroke(Color.white.opacity(disabled ? 0.13 : 0.20), lineWidth: 3)
                .frame(
                    width: CleanMyMacWindowMetrics.actionOrbOuterRingDiameter,
                    height: CleanMyMacWindowMetrics.actionOrbOuterRingDiameter
                )

            Circle()
                .fill(gradient)
                .frame(
                    width: CleanMyMacWindowMetrics.actionOrbMainDiameter,
                    height: CleanMyMacWindowMetrics.actionOrbMainDiameter
                )
                .opacity(disabled ? 0.38 : 1)
                .overlay(
                    Circle().stroke(ringColor.opacity(disabled ? 0.30 : 0.94), lineWidth: 2.3)
                )
                .shadow(color: glowColor.opacity(disabled ? 0 : 0.38), radius: 9)

            if let progress {
                Circle()
                    .trim(from: 0.02, to: max(0.04, min(1, progress)))
                    .stroke(
                        Color.white.opacity(disabled ? 0.18 : 0.76),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(
                        width: CleanMyMacWindowMetrics.actionOrbInnerRingDiameter,
                        height: CleanMyMacWindowMetrics.actionOrbInnerRingDiameter
                    )
                    .rotationEffect(.degrees(-90))
            } else {
                Circle()
                    .stroke(Color.white.opacity(disabled ? 0.10 : 0.18), lineWidth: 1)
                    .frame(
                        width: CleanMyMacWindowMetrics.actionOrbInnerRingDiameter,
                        height: CleanMyMacWindowMetrics.actionOrbInnerRingDiameter
                    )
            }

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(disabled ? 0.38 : 0.76))
        }
        .frame(
            width: CleanMyMacWindowMetrics.actionOrbFrame.width,
            height: CleanMyMacWindowMetrics.actionOrbFrame.height
        )
        .contentShape(Circle())
        .scaleEffect(hovering ? 1.025 : 1)
        .offset(y: hovering ? -3 : 0)
        .animation(.easeOut(duration: 0.14), value: hovering)
        .onHover { internalHovered = $0 }
    }
}

struct CleanMyMacBottomActionSlot<Content: View>: View {
    let horizontalOffset: CGFloat
    private let content: Content

    init(
        horizontalOffset: CGFloat = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.horizontalOffset = horizontalOffset
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            content
                .position(
                    x: proxy.size.width / 2 + horizontalOffset,
                    y: proxy.size.height - CleanMyMacWindowMetrics.bottomActionCenterInset
                )
        }
    }
}

/// Keeps the action orb on the shared center point while status text is laid
/// out beside it. Accessory text must never move the button itself.
struct CleanMyMacBottomActionCluster<Action: View, Accessory: View>: View {
    let accessoryOffset: CGSize
    private let action: Action
    private let accessory: Accessory

    init(
        accessoryOffset: CGSize = CGSize(width: 108, height: 0),
        @ViewBuilder action: () -> Action,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.accessoryOffset = accessoryOffset
        self.action = action()
        self.accessory = accessory()
    }

    var body: some View {
        ZStack {
            action
            accessory
                .fixedSize()
                .offset(x: accessoryOffset.width, y: accessoryOffset.height)
        }
        .frame(
            width: CleanMyMacWindowMetrics.actionOrbFrame.width,
            height: CleanMyMacWindowMetrics.actionOrbFrame.height
        )
    }
}

/// A full-height hit target for the small selection circles in the left
/// category column. The visible indicator keeps its original size while the
/// interactive area follows the macOS 44pt control target.
struct CleanMyMacSelectionButton<Indicator: View>: View {
    let rowHeight: CGFloat
    let action: () -> Void
    private let indicator: Indicator
    @State private var isHovered = false

    init(
        rowHeight: CGFloat,
        action: @escaping () -> Void,
        @ViewBuilder indicator: () -> Indicator
    ) {
        self.rowHeight = rowHeight
        self.action = action
        self.indicator = indicator()
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(isHovered ? 0.075 : 0))
                    .frame(width: 30, height: 30)
                indicator
            }
            .frame(width: 44, height: rowHeight)
            .contentShape(Rectangle())
        }
        .frame(width: 44, height: rowHeight)
        .contentShape(Rectangle())
        .buttonStyle(CleanMyMacSelectionPressStyle())
        .onHover { isHovered = $0 }
        .allowsHitTesting(true)
        .zIndex(10)
    }
}

private struct CleanMyMacSelectionPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .brightness(configuration.isPressed ? 0.08 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
