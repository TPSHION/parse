import Observation
import SwiftUI

@MainActor
@Observable
final class RouterManager {
    static let shared = RouterManager()

    var path = NavigationPath()

    private init() {}

    func navigate(to route: AppRoute) {
        path.append(route)
    }

    func back() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
