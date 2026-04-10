import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            ConversionHomeView()
                .tabItem {
                    Label("转换", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                }

            ResultsHomeView()
                .tabItem {
                    Label("结果", systemImage: "tray.full.fill")
                }

            TransferHomeView()
                .tabItem {
                    Label("传输", systemImage: "paperplane.circle.fill")
                }

            PlaceholderTabView(
                title: AppLocalizer.localized("设置"),
                subtitle: AppLocalizer.localized("应用偏好、默认参数和更多配置会在这里逐步补齐。"),
                icon: "gear",
                accentColor: AppColors.accentPurple
            )
            .tabItem {
                Label("设置", systemImage: "gear")
            }
        }
        .tint(AppColors.accentBlue)
    }
}

#Preview {
    RootTabView()
}
