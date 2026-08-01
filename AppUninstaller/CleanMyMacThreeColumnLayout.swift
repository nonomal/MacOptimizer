import SwiftUI

/// Stable layout used by restored detail screens: the primary navigation is
/// owned by ContentView, while this container keeps the category column fixed
/// and anchors the action control to the center of the complete module area.
struct CleanMyMacThreeColumnLayout<CategoryPanel: View, DetailPanel: View, BottomOverlay: View>: View {
    let categoryWidth: CGFloat
    private let categoryPanel: CategoryPanel
    private let detailPanel: DetailPanel
    private let bottomOverlay: BottomOverlay

    init(
        categoryWidth: CGFloat,
        @ViewBuilder category: () -> CategoryPanel,
        @ViewBuilder detail: () -> DetailPanel,
        @ViewBuilder bottomOverlay: () -> BottomOverlay
    ) {
        self.categoryWidth = categoryWidth
        self.categoryPanel = category()
        self.detailPanel = detail()
        self.bottomOverlay = bottomOverlay()
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                categoryPanel
                    .frame(width: categoryWidth)
                    .fixedSize(horizontal: true, vertical: false)

                Rectangle()
                    .fill(Color.white.opacity(0.055))
                    .frame(width: 1)

                detailPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            CleanMyMacBottomActionSlot {
                bottomOverlay
            }
        }
    }
}
