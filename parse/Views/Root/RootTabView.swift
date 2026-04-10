import SwiftUI

struct RootTabView: View {
    @Environment(TabRouter.self) private var tabRouter

    var body: some View {
        @Bindable var bindableTabRouter = tabRouter

        TabView(selection: $bindableTabRouter.selectedTab) {
            ConversionHomeView()
                .tag(AppTab.conversion)
                .tabItem {
                    Label("转换", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                }

            ResultsHomeView()
                .tag(AppTab.results)
                .tabItem {
                    Label("结果", systemImage: "tray.full.fill")
                }

            TransferHomeView()
                .tag(AppTab.transfer)
                .tabItem {
                    Label("传输", systemImage: "paperplane.circle.fill")
                }

            PlaceholderTabView(
                title: AppLocalizer.localized("设置"),
                subtitle: AppLocalizer.localized("应用偏好、默认参数和更多配置会在这里逐步补齐。"),
                icon: "gear",
                accentColor: AppColors.accentPurple
            )
            .tag(AppTab.settings)
            .tabItem {
                Label("设置", systemImage: "gear")
            }
        }
        .tint(AppColors.accentBlue)
    }
}

#Preview {
    RootTabView()
        .environment(TabRouter.shared)
}
