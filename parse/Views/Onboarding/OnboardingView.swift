import SwiftUI

struct OnboardingView: View {
    @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.automaticValue
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        .init(
            icon: "lock.shield.fill",
            accentColor: AppColors.accentBlue,
            eyebrowKey: "隐私优先",
            titleKey: "本地处理，更安心",
            descriptionKey: "所有转换、压缩与传输都在设备上完成，不上传云端，兼顾极致速度与您的隐私安全。"
        ),
        .init(
            icon: "square.grid.2x2.fill",
            accentColor: AppColors.accentPurple,
            eyebrowKey: "多媒体工作台",
            titleKey: "一站式全能工具",
            descriptionKey: "图片、视频、音频与文档工具无缝集成。再也不用在多个应用之间来回切换。"
        ),
        .init(
            icon: "paperplane.circle.fill",
            accentColor: AppColors.accentTeal,
            eyebrowKey: "局域网传输",
            titleKey: "浏览器秒传文件",
            descriptionKey: "同处一个 Wi-Fi 下，电脑浏览器也能快速下载、管理您的所有处理结果和共享文件。"
        )
    ]

    private var appLanguage: AppLanguage {
        AppLanguage.effective(from: appLanguageRawValue)
    }

    var body: some View {
        ZStack {
            AppShellBackground()

            VStack(spacing: 0) {
                topBar

                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page, language: appLanguage)
                            .padding(.horizontal, 24)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                bottomPanel
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()

            AppLanguageSwitcher(selectedLanguage: appLanguage) { language in
                appLanguageRawValue = language.rawValue
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var bottomPanel: some View {
        VStack(spacing: 24) {
            // Page indicators
            HStack(spacing: 8) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    Capsule()
                        .fill(index == currentPage ? page.accentColor : Color.white.opacity(0.15))
                        .frame(width: index == currentPage ? 28 : 8, height: 8)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentPage)
                }
            }
            .padding(.top, 8)
            
            // Trial notice
            if currentPage == pages.count - 1 {
                VStack(spacing: 6) {
                    Text(AppLocalizer.localized("免费试用 15 天"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(AppLocalizer.localized("体验全部核心功能后，再决定是否解锁终身版。"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Button(action: advance) {
                HStack {
                    Spacer()
                    Text(AppLocalizer.localized(currentPage == pages.count - 1 ? "开始体验" : "继续"))
                        .font(.system(size: 17, weight: .bold))
                    Spacer()
                }
                .padding(.vertical, 16)
                .foregroundColor(currentPage == pages.count - 1 ? .black : .white)
                .background(
                    Group {
                        if currentPage == pages.count - 1 {
                            Color.white
                        } else {
                            pages[currentPage].accentColor
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(
                    color: (currentPage == pages.count - 1 ? Color.white : pages[currentPage].accentColor).opacity(0.25),
                    radius: 12, x: 0, y: 6
                )
                .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
        .padding(.vertical, 8)
        .animation(.easeInOut(duration: 0.3), value: currentPage)
    }

    private func advance() {
        if currentPage < pages.count - 1 {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentPage += 1
            }
        } else {
            completeOnboarding()
        }
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    let language: AppLanguage
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 20)

            ZStack {
                // Outer glow
                Circle()
                    .fill(page.accentColor.opacity(0.15))
                    .frame(width: 180, height: 180)
                    .blur(radius: 30)
                    .scaleEffect(isAnimating ? 1.05 : 0.95)

                // Inner glass container
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                page.accentColor.opacity(0.2),
                                page.accentColor.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.5),
                                        .white.opacity(0.1),
                                        page.accentColor.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .rotation3DEffect(
                        .degrees(isAnimating ? 2 : -2),
                        axis: (x: 1.0, y: 0.5, z: 0.0)
                    )

                Image(systemName: page.icon)
                    .font(.system(size: 56, weight: .light))
                    .foregroundColor(.white)
                    .shadow(color: page.accentColor.opacity(0.6), radius: 10, x: 0, y: 4)
                    .scaleEffect(isAnimating ? 1.0 : 0.92)
            }
            .animation(
                .easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }

            VStack(spacing: 16) {
                Text(AppLocalizer.localized(page.eyebrowKey, language: language))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(page.accentColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(page.accentColor.opacity(0.15))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().strokeBorder(page.accentColor.opacity(0.3), lineWidth: 1)
                    )

                Text(AppLocalizer.localized(page.titleKey, language: language))
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(AppLocalizer.localized(page.descriptionKey, language: language))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 16)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct OnboardingPage {
    let icon: String
    let accentColor: Color
    let eyebrowKey: String
    let titleKey: String
    let descriptionKey: String
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
