import Combine

/// Shared navigation state used by the main window and the menu-bar recommendations.
final class AppNavigationController: ObservableObject {
    static let shared = AppNavigationController()

    @Published var selectedModule: AppModule = .smartClean

    private init() {}
}
