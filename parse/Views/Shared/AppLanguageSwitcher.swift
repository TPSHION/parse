import SwiftUI

struct AppLanguageSwitcher: View {
    let selectedLanguage: AppLanguage
    let onSelect: (AppLanguage) -> Void
    var iconSize: CGFloat = 12
    var textSize: CGFloat = 12
    var horizontalPadding: CGFloat = 12
    var verticalPadding: CGFloat = 8
    var backgroundColor: Color = Color.white.opacity(0.05)

    @State private var isDialogPresented = false

    var body: some View {
        Button {
            isDialogPresented = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.system(size: iconSize, weight: .semibold))

                Text(selectedLanguage.shortLabel)
                    .font(.system(size: textSize, weight: .bold))

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.72))
            }
            .foregroundColor(.white)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                Capsule()
                    .fill(backgroundColor.opacity(0.98))
            )
            .overlay(
                Capsule()
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .confirmationDialog(
            AppLocalizer.localized("语言切换"),
            isPresented: $isDialogPresented,
            titleVisibility: .visible
        ) {
            ForEach(AppLanguage.allCases) { language in
                Button(languageOptionTitle(for: language)) {
                    onSelect(language)
                }
            }

            Button(AppLocalizer.localized("取消"), role: .cancel) {}
        }
    }

    
    private func languageOptionTitle(for language: AppLanguage) -> String {
        if language == selectedLanguage {
            return "\(language.displayName) ✓"
        }

        return language.displayName
    }
}
