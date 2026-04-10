import Observation

@MainActor
@Observable
final class TabRouter {
    static let shared = TabRouter()

    var selectedTab: AppTab = .conversion

    private init() {}

    func select(_ tab: AppTab) {
        selectedTab = tab
    }
}

enum AppTab: Hashable {
    case conversion
    case results
    case transfer
    case settings
}
