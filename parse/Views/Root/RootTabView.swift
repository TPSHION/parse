import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            ConversionHomeView()
                .tabItem {
                    Label("转换", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                }

            PlaceholderTabView(
                title: "传输",
                subtitle: "局域网传输、链接导入和跨设备收发能力会放在这里。",
                icon: "paperplane.circle.fill",
                accentColor: AppColors.accentGreen
            )
            .tabItem {
                Label("传输", systemImage: "paperplane.circle.fill")
            }

            PlaceholderTabView(
                title: "设置",
                subtitle: "应用偏好、默认参数和更多配置会在这里逐步补齐。",
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
