import SwiftUI

struct AppShellBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.background, Color(hex: "#050B14")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(AppColors.accentBlue.opacity(0.12))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(x: -150, y: -250)

            Circle()
                .fill(AppColors.accentPurple.opacity(0.12))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(x: 150, y: -100)
        }
    }
}

#Preview {
    AppShellBackground()
}
