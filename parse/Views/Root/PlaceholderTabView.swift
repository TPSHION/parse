import SwiftUI

struct PlaceholderTabView: View {
    let title: String
    let subtitle: String
    let icon: String
    let accentColor: Color

    var body: some View {
        ZStack {
            AppShellBackground()

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.16))
                        .frame(width: 128, height: 128)
                        .blur(radius: 2)

                    Image(systemName: icon)
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundColor(accentColor)
                }

                VStack(spacing: 12) {
                    Text(title)
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .frame(maxWidth: 320)

                Spacer()
            }
            .toolbar(.hidden, for: .navigationBar)
            .padding(24)
        }
    }
}

#Preview {
    PlaceholderTabView(
        title: "传输",
        subtitle: "局域网传输、链接导入和跨设备收发能力会放在这里。",
        icon: "paperplane.circle.fill",
        accentColor: AppColors.accentGreen
    )
}
