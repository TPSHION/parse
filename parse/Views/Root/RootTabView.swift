import SwiftUI

struct RootTabView: View {
    @Environment(TabRouter.self) private var tabRouter

    var body: some View {
        @Bindable var bindableTabRouter = tabRouter

        TabView(selection: $bindableTabRouter.selectedTab) {
            ConversionHomeView()
                .tag(AppTab.conversion)
                .tabItem {
                    Label(AppLocalizer.localized("转换"), systemImage: "arrow.triangle.2.circlepath.circle.fill")
                }

            ResultsHomeView()
                .tag(AppTab.results)
                .tabItem {
                    Label(AppLocalizer.localized("结果"), systemImage: "tray.full.fill")
                }

            TransferHomeView()
                .tag(AppTab.transfer)
                .tabItem {
                    Label(AppLocalizer.localized("传输"), systemImage: "paperplane.circle.fill")
                }

            SettingsHomeView()
                .tag(AppTab.settings)
                .tabItem {
                    Label(AppLocalizer.localized("设置"), systemImage: "gear")
                }
        }
        .tint(AppColors.accentBlue)
    }
}

#Preview {
    RootTabView()
        .environment(TabRouter.shared)
}
