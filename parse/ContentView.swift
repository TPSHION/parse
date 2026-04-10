import SwiftUI

struct ContentView: View {
    @AppStorage(AppLanguage.storageKey) private var language: String = AppLanguage.automaticValue
    
    var body: some View {
        RootTabView()
            .id(language)
    }
}

#Preview {
    ContentView()
        .environment(TabRouter.shared)
}
