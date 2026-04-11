import SwiftUI

struct ContentView: View {
    @AppStorage(AppLanguage.storageKey) private var language: String = AppLanguage.automaticValue
    @AppStorage("has_completed_onboarding") private var hasCompletedOnboarding = false
    @Environment(PurchaseManager.self) private var purchaseManager
    
    var body: some View {
        Group {
            if hasCompletedOnboarding {
                RootTabView()
                    .id(language)
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
        .task {
            await purchaseManager.prepareIfNeeded()
        }
    }
}

#Preview {
    ContentView()
        .environment(TabRouter.shared)
        .environment(RouterManager.shared)
        .environment(PurchaseManager.shared)
}
