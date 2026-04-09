import SwiftUI

struct ConversionHomeView: View {
    @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.simplifiedChinese.rawValue
    @State private var appearAnimation = false

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    private var appLanguage: AppLanguage {
        AppLanguage.resolve(from: appLanguageRawValue)
    }

    var body: some View {
        ZStack {
            AppShellBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    ConversionWelcomeHeader(
                        appearAnimation: appearAnimation,
                        selectedLanguage: appLanguage
                    ) { language in
                        appLanguageRawValue = language.rawValue
                    }

                    ToolSectionView(
                        title: AppLocalizer.localized("媒体处理"),
                        icon: "photo.on.rectangle.angled",
                        color: AppColors.accentBlue,
                        appearAnimation: appearAnimation,
                        offset: 30
                    ) {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ToolRouteCard(route: .imageConverter) {
                                ToolGridCard(icon: "photo.badge.arrow.down.fill", title: AppLocalizer.localized("图片转换"), description: AppLocalizer.localized("极速批量转换主流图片格式"), color: AppColors.accentBlue)
                            }

                            ToolRouteCard(route: .videoConverter) {
                                ToolGridCard(icon: "video.fill.badge.ellipsis", title: AppLocalizer.localized("视频转换"), description: AppLocalizer.localized("高效互转 MP4, MOV, GIF, AVI, MKV 等格式"), color: AppColors.accentGreen)
                            }

                            ToolRouteCard(route: .audioConverter) {
                                ToolGridCard(icon: "waveform.circle.fill", title: AppLocalizer.localized("音频转换"), description: AppLocalizer.localized("提取音频，或互转 MP3, WAV, M4A 等"), color: AppColors.accentOrange)
                            }

                            ToolRouteCard(route: .mediaCompressor) {
                                ToolGridCard(icon: "bolt.fill", title: AppLocalizer.localized("数据压缩"), description: AppLocalizer.localized("混合批量压缩图片、视频与音频数据"), color: AppColors.accentTeal)
                            }
                        }
                    }

                    ToolSectionView(
                        title: AppLocalizer.localized("文档处理"),
                        icon: "doc.on.doc.fill",
                        color: AppColors.accentPurple,
                        appearAnimation: appearAnimation,
                        offset: 40
                    ) {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ToolRouteCard(route: .pdfConverter) {
                                ToolGridCard(icon: "doc.text.viewfinder", title: AppLocalizer.localized("PDF 转换"), description: AppLocalizer.localized("支持转为 DOCX, TXT, MD, PNG 等"), color: AppColors.accentPurple)
                            }

                            ToolRouteCard(route: .documentTool(.imageToText)) {
                                ToolGridCard(icon: "text.viewfinder", title: AppLocalizer.localized("图片转文字"), description: AppLocalizer.localized("精准提取图片中的文字内容"), color: AppColors.accentPurple)
                            }

                            ToolRouteCard(route: .documentTool(.ebookConvert)) {
                                ToolGridCard(icon: "book.closed.fill", title: AppLocalizer.localized("电子书转换"), description: AppLocalizer.localized("EPUB, MOBI 等格式完美互转"), color: AppColors.accentPurple)
                            }

                            ToolRouteCard(route: .documentTool(.textWebConvert)) {
                                ToolGridCard(icon: "network", title: AppLocalizer.localized("网页转文档"), description: AppLocalizer.localized("输入链接一键生成 PDF"), color: AppColors.accentPurple)
                            }
                        }
                    }
                }
                .padding(24)
                .padding(.bottom, 40)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appearAnimation = true
            }
        }
    }
}

private struct ConversionWelcomeHeader: View {
    let appearAnimation: Bool
    let selectedLanguage: AppLanguage
    let onSelectLanguage: (AppLanguage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Text("Welcome to Parse")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.accentBlue)
                    .textCase(.uppercase)
                    .tracking(1.5)

                Spacer(minLength: 0)

                LanguageSwitcherMenu(selectedLanguage: selectedLanguage, onSelect: onSelectLanguage)
            }

            Text("超级转换工具箱")
                .font(.system(size: 32, weight: .heavy))
                .foregroundColor(.white)

            Text("本地处理，安全高效，极简体验。")
                .font(.body)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 20)
    }
}

private struct LanguageSwitcherMenu: View {
    let selectedLanguage: AppLanguage
    let onSelect: (AppLanguage) -> Void

    var body: some View {
        Menu {
            ForEach(AppLanguage.allCases) { language in
                Button {
                    onSelect(language)
                } label: {
                    HStack {
                        Text(language.displayName)

                        if language == selectedLanguage {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.system(size: 13, weight: .semibold))

                Text(selectedLanguage.shortLabel)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(AppColors.cardBackground.opacity(0.92))
            )
            .overlay(
                Capsule()
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

private struct ToolSectionView<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let appearAnimation: Bool
    let offset: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)

                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 4)

            content
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : offset)
    }
}

private struct ToolRouteCard<Content: View>: View {
    @Environment(RouterManager.self) private var router
    let route: AppRoute
    @ViewBuilder let content: Content

    var body: some View {
        Button {
            router.navigate(to: route)
        } label: {
            content
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ConversionHomeView()
        .environment(RouterManager.shared)
}
