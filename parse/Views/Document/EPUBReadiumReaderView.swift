import SwiftUI
import UIKit
import ReadiumNavigator
import ReadiumShared
import ReadiumStreamer

struct EPUBReadiumReaderView: View {
    let item: EbookLibraryItem

    @Environment(\.dismiss) private var dismiss
    @State private var session: EPUBReadiumReaderSession?
    @State private var loadError: String?
    @State private var isLoading = true
    @State private var chromeVisible = false
    @State private var activePanel: ReaderOverlayPanel?
    @State private var currentLocator: Locator?
    @State private var styleSettings = EbookReaderPreferencesStore.loadStyleSettings()

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                readerBackground

                Group {
                    if let session {
                        ReadiumNavigatorContainer(
                            navigator: session.navigator,
                            onToggleChrome: toggleChrome,
                            onLocationChange: handleLocationChange,
                            onPresentError: handleNavigatorError
                        )
                        .ignoresSafeArea()
                    } else if let loadError {
                        EPUBReadiumErrorView(message: loadError, onRetry: loadPublication)
                    } else {
                        readerLoadingView
                    }
                }

                if !chromeVisible, session != nil {
                    compactChapterOverlay(topInset: statusBarInset(fallback: proxy.safeAreaInsets.top))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .ignoresSafeArea(edges: .top)
                        .transition(.opacity)
                }

                if chromeVisible, session != nil {
                    ZStack {
                        readerChrome(topInset: statusBarInset(fallback: proxy.safeAreaInsets.top))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .transition(.move(edge: .top).combined(with: .opacity))

                        readerBottomOverlay(bottomInset: proxy.safeAreaInsets.bottom)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .ignoresSafeArea(edges: [.top, .bottom])
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(session != nil)
        .animation(.easeInOut(duration: 0.22), value: chromeVisible)
        .animation(.easeInOut(duration: 0.2), value: activePanel)
        .task(id: item.id) {
            loadPublication()
        }
    }

    private var readerBackground: some View {
        Color.black.ignoresSafeArea()
    }

    private var readerLoadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.white)

            Text(AppLocalizer.localized("正在处理电子书..."))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.92))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func compactChapterOverlay(topInset: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            HStack(spacing: 0) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(compactOverlayTextColor)
                        .frame(width: 12, height: 24, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Text(compactChapterTitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(compactOverlayTextColor)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)

                Text(compactOverlayTimeString(for: context.date))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(compactOverlayTextColor)
                    .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .padding(.top, compactOverlayTopPadding(for: topInset) + 3)
            .padding(.bottom, 6)
            .background(
                compactOverlayBackgroundColor
                    .ignoresSafeArea(edges: .top)
            )
        }
    }

    private func readerChrome(topInset: CGFloat) -> some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(readerOverlayPrimaryText)
                    .frame(width: 36, height: 36)
                    .background(readerOverlaySecondarySurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            VStack(spacing: 2) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(readerOverlayPrimaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.top, max(topInset, 0))
        .padding(.bottom, 10)
        .background(
            readerOverlaySurface
                .ignoresSafeArea(edges: .top)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(readerOverlayStroke)
                        .frame(height: 1)
                }
        )
    }

    private func readerBottomOverlay(bottomInset: CGFloat) -> some View {
        VStack(spacing: 12) {
            if activePanel == .tableOfContents {
                tableOfContentsPanel
            } else if activePanel == .appearance {
                appearancePanel
            }

            bottomControlsStack
        }
        .padding(.horizontal, 16)
        .padding(.bottom, max(bottomInset, 0) + 12)
    }

    private var tableOfContentsPanel: some View {
        let entries = session?.tocEntries ?? []

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(AppLocalizer.localized("目录"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10)

                if entries.isEmpty {
                    Text(AppLocalizer.localized("当前电子书暂时没有可用目录"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 18)
                } else {
                    ForEach(entries) { entry in
                        Button {
                            session?.go(to: entry.link)
                            activePanel = nil
                            chromeVisible = false
                        } label: {
                            HStack(spacing: 12) {
                                Text(entry.title)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                                    .padding(.leading, CGFloat(entry.level) * 12)

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if entry.id != entries.last?.id {
                            Divider()
                                .overlay(Color.white.opacity(0.06))
                                .padding(.leading, 16)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 300)
        .background(readerOverlaySurface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(readerOverlayStroke, lineWidth: 1)
        )
    }

    private var appearancePanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(AppLocalizer.localized("阅读样式"))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 12) {
                Text(AppLocalizer.localized("翻页方式"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.76))

                HStack(spacing: 10) {
                    ReaderModeButton(
                        title: AppLocalizer.localized("分页"),
                        isSelected: !styleSettings.isScrollEnabled
                    ) {
                        updateScrollMode(false)
                    }

                    ReaderModeButton(
                        title: AppLocalizer.localized("滚动"),
                        isSelected: styleSettings.isScrollEnabled
                    ) {
                        updateScrollMode(true)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(AppLocalizer.localized("字号"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.76))

                    Spacer(minLength: 0)

                    Text(fontSizeLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                }

                HStack(spacing: 12) {
                    ReaderMiniIconButton(systemName: "textformat.size.smaller") {
                        updateFontSize(by: -0.1)
                    }
                    .disabled(styleSettings.fontSize <= 0.8)

                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 8)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(AppColors.accentBlue)
                                .frame(width: fontProgressWidth)
                        }

                    ReaderMiniIconButton(systemName: "textformat.size.larger") {
                        updateFontSize(by: 0.1)
                    }
                    .disabled(styleSettings.fontSize >= 1.6)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(AppLocalizer.localized("字间距"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.76))

                    Spacer(minLength: 0)

                    Text(letterSpacingLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                }

                HStack(spacing: 12) {
                    ReaderMiniIconButton(systemName: "minus") {
                        updateLetterSpacing(by: -0.02)
                    }
                    .disabled(styleSettings.letterSpacing <= 0)

                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 8)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(AppColors.accentBlue)
                                .frame(width: letterSpacingProgressWidth)
                        }

                    ReaderMiniIconButton(systemName: "plus") {
                        updateLetterSpacing(by: 0.02)
                    }
                    .disabled(styleSettings.letterSpacing >= 0.16)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(AppLocalizer.localized("行间距"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.76))

                    Spacer(minLength: 0)

                    Text(lineHeightLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                }

                HStack(spacing: 12) {
                    ReaderMiniIconButton(systemName: "minus") {
                        updateLineHeight(by: -0.1)
                    }
                    .disabled(styleSettings.lineHeight <= 1.2)

                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 8)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(AppColors.accentBlue)
                                .frame(width: lineHeightProgressWidth)
                        }

                    ReaderMiniIconButton(systemName: "plus") {
                        updateLineHeight(by: 0.1)
                    }
                    .disabled(styleSettings.lineHeight >= 2.2)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(AppLocalizer.localized("主题"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.76))

                HStack(spacing: 10) {
                    ForEach(ReaderThemeOption.allCases) { option in
                        Button {
                            updateTheme(option)
                        } label: {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(option.swatch)
                                    .frame(width: 26, height: 26)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                option == currentThemeOption
                                                    ? AppColors.accentBlue
                                                    : Color.white.opacity(0.12),
                                                lineWidth: option == currentThemeOption ? 2 : 1
                                            )
                                    )

                                Text(option.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(option == currentThemeOption ? 0.96 : 0.72))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(option == currentThemeOption
                                        ? AppColors.accentBlue.opacity(0.16)
                                        : Color.white.opacity(0.04))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(18)
        .background(readerOverlaySurface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(readerOverlayStroke, lineWidth: 1)
        )
    }

    private var bottomControlsStack: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ReaderActionButton(
                    title: AppLocalizer.localized("目录"),
                    systemName: "list.bullet",
                    isActive: activePanel == .tableOfContents,
                    foregroundColor: readerOverlayPrimaryText,
                    backgroundColor: readerOverlaySecondarySurface
                ) {
                    togglePanel(.tableOfContents)
                }

                ReaderActionButton(
                    title: AppLocalizer.localized("样式"),
                    systemName: "textformat.size",
                    isActive: activePanel == .appearance,
                    foregroundColor: readerOverlayPrimaryText,
                    backgroundColor: readerOverlaySecondarySurface
                ) {
                    togglePanel(.appearance)
                }
            }

            HStack(spacing: 12) {
                Text(progressDescription)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(readerOverlaySecondaryText)

                GeometryReader { proxy in
                    Capsule()
                        .fill(readerOverlaySecondarySurface)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(readerProgressFill)
                                .frame(width: max(22, proxy.size.width * progressValue))
                        }
                }
                .frame(height: 12)

                Text(AppLocalizer.localized("阅读中"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(readerOverlaySecondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(readerOverlaySurface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(readerOverlayStroke, lineWidth: 1)
            )
        }
    }

    private var readerBottomBar: some View {
        HStack(spacing: 10) {
            ReaderActionButton(
                title: AppLocalizer.localized("目录"),
                systemName: "list.bullet",
                isActive: activePanel == .tableOfContents,
                foregroundColor: readerOverlayPrimaryText,
                backgroundColor: readerOverlaySecondarySurface
            ) {
                togglePanel(.tableOfContents)
            }

            ReaderActionButton(
                title: AppLocalizer.localized("样式"),
                systemName: "textformat.size",
                isActive: activePanel == .appearance,
                foregroundColor: readerOverlayPrimaryText,
                backgroundColor: readerOverlaySecondarySurface
            ) {
                togglePanel(.appearance)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(readerOverlaySurface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(readerOverlayStroke, lineWidth: 1)
        )
        .shadow(color: readerOverlayShadow, radius: 18, x: 0, y: 10)
    }

    private var progressDescription: String {
        guard let totalProgression = currentLocator?.locations.totalProgression else {
            return AppLocalizer.localized("阅读中")
        }
        let percent = max(1, Int((totalProgression * 100).rounded()))
        return "\(percent)%"
    }

    private var compactChapterTitle: String {
        currentTOCTitle ?? item.title
    }

    private var compactOverlayTextColor: SwiftUI.Color {
        currentThemeOption.compactOverlayTextColor
    }

    private var compactOverlayBackgroundColor: SwiftUI.Color {
        currentThemeOption.compactOverlayBackgroundColor
    }

    private var compactOverlayDividerColor: SwiftUI.Color {
        currentThemeOption.compactOverlayDividerColor
    }

    private var currentTOCTitle: String? {
        guard let session, let locatorHref = currentLocator?.href else { return nil }
        let normalizedLocator = normalizeResourcePath(String(describing: locatorHref))
        guard !normalizedLocator.isEmpty else { return nil }

        if let exact = session.tocEntries.first(where: {
            normalizeResourcePath(String(describing: $0.link.href)) == normalizedLocator
        }) {
            return exact.title
        }

        if let prefix = session.tocEntries.first(where: {
            let entryPath = normalizeResourcePath(String(describing: $0.link.href))
            return !entryPath.isEmpty && normalizedLocator.hasPrefix(entryPath)
        }) {
            return prefix.title
        }

        return nil
    }

    private var fontSizeLabel: String {
        "\(Int((styleSettings.fontSize * 100).rounded()))%"
    }

    private var letterSpacingLabel: String {
        if styleSettings.letterSpacing <= 0.0001 {
            return AppLocalizer.localized("默认")
        }
        return String(format: "+%.2f", styleSettings.letterSpacing)
    }

    private var lineHeightLabel: String {
        String(format: "%.1f", styleSettings.lineHeight)
    }

    private var progressValue: CGFloat {
        CGFloat(currentLocator?.locations.totalProgression ?? 0)
    }

    private var currentThemeOption: ReaderThemeOption {
        ReaderThemeOption(rawValue: styleSettings.themeRawValue) ?? .dark
    }

    private var fontProgressWidth: CGFloat {
        let clamped = min(max(styleSettings.fontSize, 0.8), 1.6)
        let progress = (clamped - 0.8) / 0.8
        return max(28, progress * 116)
    }

    private var letterSpacingProgressWidth: CGFloat {
        let clamped = min(max(styleSettings.letterSpacing, 0), 0.16)
        let progress = clamped / 0.16
        return max(28, progress * 116)
    }

    private var lineHeightProgressWidth: CGFloat {
        let clamped = min(max(styleSettings.lineHeight, 1.2), 2.2)
        let progress = (clamped - 1.2) / 1.0
        return max(28, progress * 116)
    }

    private func statusBarInset(fallback: CGFloat) -> CGFloat {
        let windowInset = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.top ?? 0
        if windowInset > 0 {
            return windowInset
        }

        let sceneInset = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .statusBarManager?
            .statusBarFrame.height ?? 0
        return sceneInset > 0 ? sceneInset : fallback
    }

    private func normalizeResourcePath(_ href: String) -> String {
        var value = href.trimmingCharacters(in: .whitespacesAndNewlines)
        if let fragmentIndex = value.firstIndex(of: "#") {
            value = String(value[..<fragmentIndex])
        }
        if let queryIndex = value.firstIndex(of: "?") {
            value = String(value[..<queryIndex])
        }
        return value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func compactOverlayTopPadding(for topInset: CGFloat) -> CGFloat {
        if topInset >= 44 {
            return min(max(topInset - 4, 40), 46)
        }
        return max(topInset + 12, 16)
    }

    private func compactOverlayTimeString(for date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }

    private var readerOverlaySurface: SwiftUI.Color {
        Color(hex: "#10161F")
    }

    private var readerOverlaySecondarySurface: SwiftUI.Color {
        Color(hex: "#1B2430")
    }

    private var readerAccentSurface: SwiftUI.Color {
        AppColors.accentBlue.opacity(0.2)
    }

    private var readerOverlayPrimaryText: SwiftUI.Color {
        .white
    }

    private var readerOverlaySecondaryText: SwiftUI.Color {
        Color.white.opacity(0.7)
    }

    private var readerOverlayStroke: SwiftUI.Color {
        Color.white.opacity(0.08)
    }

    private var readerOverlayShadow: SwiftUI.Color {
        Color.black.opacity(0.22)
    }

    private var readerProgressFill: SwiftUI.Color {
        AppColors.accentBlue
    }

    private func loadPublication() {
        guard item.sourceFormat == .epub else {
            loadError = AppLocalizer.localized("当前版本暂不支持打开该电子书格式")
            isLoading = false
            return
        }

        isLoading = true
        loadError = nil
        session = nil
        activePanel = nil

        let fileURL = EbookLibraryService.fileURL(for: item)
        let savedLocator = EbookReaderPreferencesStore.loadLocator(for: item.id)
        let currentStyleSettings = styleSettings

        Task {
            do {
                let createdSession = try await EPUBReadiumReaderSession.make(
                    fileURL: fileURL,
                    displayTitle: item.title,
                    initialLocator: savedLocator,
                    styleSettings: currentStyleSettings
                )
                await MainActor.run {
                    session = createdSession
                    currentLocator = createdSession.navigator.currentLocation ?? savedLocator
                    isLoading = false
                    chromeVisible = false
                }
            } catch {
                await MainActor.run {
                    loadError = error.localizedDescription
                    isLoading = false
                    chromeVisible = true
                }
            }
        }
    }

    private func toggleChrome() {
        guard session != nil else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            chromeVisible.toggle()
            if !chromeVisible {
                activePanel = nil
            }
        }
    }

    private func togglePanel(_ panel: ReaderOverlayPanel) {
        withAnimation(.easeInOut(duration: 0.2)) {
            activePanel = activePanel == panel ? nil : panel
            chromeVisible = true
        }
    }

    private func handleLocationChange(_ locator: Locator) {
        currentLocator = locator
        EbookReaderPreferencesStore.saveLocator(locator, for: item.id)
    }

    private func handleNavigatorError(_ message: String) {
        loadError = message
        chromeVisible = true
    }

    private func updateFontSize(by delta: Double) {
        let nextValue = min(max(styleSettings.fontSize + delta, 0.8), 1.6)
        guard nextValue != styleSettings.fontSize else { return }
        styleSettings.fontSize = nextValue
        session?.apply(styleSettings: styleSettings)
        EbookReaderPreferencesStore.saveStyleSettings(styleSettings)
    }

    private func updateLetterSpacing(by delta: Double) {
        let nextValue = min(max(styleSettings.letterSpacing + delta, 0), 0.16)
        guard abs(nextValue - styleSettings.letterSpacing) > 0.0001 else { return }
        styleSettings.letterSpacing = nextValue
        session?.apply(styleSettings: styleSettings)
        EbookReaderPreferencesStore.saveStyleSettings(styleSettings)
    }

    private func updateLineHeight(by delta: Double) {
        let nextValue = min(max(styleSettings.lineHeight + delta, 1.2), 2.2)
        guard abs(nextValue - styleSettings.lineHeight) > 0.0001 else { return }
        styleSettings.lineHeight = nextValue
        session?.apply(styleSettings: styleSettings)
        EbookReaderPreferencesStore.saveStyleSettings(styleSettings)
    }

    private func updateScrollMode(_ isEnabled: Bool) {
        guard styleSettings.isScrollEnabled != isEnabled else { return }
        styleSettings.isScrollEnabled = isEnabled
        session?.apply(styleSettings: styleSettings)
        EbookReaderPreferencesStore.saveStyleSettings(styleSettings)
    }

    private func updateTheme(_ option: ReaderThemeOption) {
        guard currentThemeOption != option else { return }
        styleSettings.themeRawValue = option.rawValue
        session?.apply(styleSettings: styleSettings)
        EbookReaderPreferencesStore.saveStyleSettings(styleSettings)
    }
}

private enum ReaderOverlayPanel {
    case tableOfContents
    case appearance
}

private enum ReaderThemeOption: String, CaseIterable, Identifiable {
    case dark
    case light
    case mint
    case cream

    var id: String { rawValue }

    var readiumTheme: Theme {
        switch self {
        case .dark:
            return .dark
        case .light:
            return .light
        case .mint, .cream:
            return .light
        }
    }

    var backgroundColor: ReadiumNavigator.Color? {
        switch self {
        case .dark, .light:
            return nil
        case .mint:
            return ReadiumNavigator.Color(hex: "#E8F5EE")
        case .cream:
            return ReadiumNavigator.Color(hex: "#F6EEDB")
        }
    }

    var textColor: ReadiumNavigator.Color? {
        switch self {
        case .dark, .light:
            return nil
        case .mint:
            return ReadiumNavigator.Color(hex: "#23352B")
        case .cream:
            return ReadiumNavigator.Color(hex: "#4A4032")
        }
    }

    var title: String {
        switch self {
        case .dark:
            return AppLocalizer.localized("夜间")
        case .light:
            return AppLocalizer.localized("浅色")
        case .mint:
            return AppLocalizer.localized("薄荷")
        case .cream:
            return AppLocalizer.localized("米白")
        }
    }

    var swatch: SwiftUI.Color {
        switch self {
        case .dark:
            return SwiftUI.Color.black
        case .light:
            return SwiftUI.Color.white
        case .mint:
            return SwiftUI.Color(hex: "#CFE6D9")
        case .cream:
            return SwiftUI.Color(hex: "#E9D9B6")
        }
    }

    var compactOverlayBackgroundColor: SwiftUI.Color {
        switch self {
        case .dark:
            return SwiftUI.Color(hex: "#05070C")
        case .light:
            return SwiftUI.Color(hex: "#F7F7F2")
        case .mint:
            return SwiftUI.Color(hex: "#E8F5EE")
        case .cream:
            return SwiftUI.Color(hex: "#F6EEDB")
        }
    }

    var compactOverlayTextColor: SwiftUI.Color {
        switch self {
        case .dark:
            return SwiftUI.Color.white.opacity(0.7)
        case .light:
            return SwiftUI.Color(hex: "#1F2937").opacity(0.62)
        case .mint:
            return SwiftUI.Color(hex: "#23352B").opacity(0.58)
        case .cream:
            return SwiftUI.Color(hex: "#4A4032").opacity(0.58)
        }
    }

    var compactOverlayDividerColor: SwiftUI.Color {
        switch self {
        case .dark:
            return SwiftUI.Color.white.opacity(0.08)
        case .light:
            return SwiftUI.Color.black.opacity(0.08)
        case .mint, .cream:
            return compactOverlayTextColor.opacity(0.18)
        }
    }
}

private struct ReaderActionButton: View {
    let title: String
    let systemName: String
    var isActive = false
    let foregroundColor: SwiftUI.Color
    let backgroundColor: SwiftUI.Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemName)
                    .font(.system(size: 14, weight: .semibold))

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(isActive ? AppColors.accentBlue : foregroundColor)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(backgroundColor)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ReaderModeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(isSelected ? 0.98 : 0.72))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isSelected ? Color(hex: "#1C2740") : Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isSelected ? AppColors.accentBlue.opacity(0.78) : Color.white.opacity(0.06), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct ReaderMiniIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(Color.white.opacity(0.06))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct ReadiumNavigatorContainer: UIViewControllerRepresentable {
    let navigator: EPUBNavigatorViewController
    let onToggleChrome: () -> Void
    let onLocationChange: (Locator) -> Void
    let onPresentError: (String) -> Void

    func makeUIViewController(context: Context) -> EPUBNavigatorViewController {
        navigator.delegate = context.coordinator
        context.coordinator.onToggleChrome = onToggleChrome
        context.coordinator.onLocationChange = onLocationChange
        context.coordinator.onPresentError = onPresentError
        return navigator
    }

    func updateUIViewController(_ uiViewController: EPUBNavigatorViewController, context: Context) {
        uiViewController.delegate = context.coordinator
        context.coordinator.onToggleChrome = onToggleChrome
        context.coordinator.onLocationChange = onLocationChange
        context.coordinator.onPresentError = onPresentError
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onToggleChrome: onToggleChrome,
            onLocationChange: onLocationChange,
            onPresentError: onPresentError
        )
    }

    @MainActor
    final class Coordinator: NSObject, EPUBNavigatorDelegate {
        var onToggleChrome: () -> Void
        var onLocationChange: (Locator) -> Void
        var onPresentError: (String) -> Void

        init(
            onToggleChrome: @escaping () -> Void,
            onLocationChange: @escaping (Locator) -> Void,
            onPresentError: @escaping (String) -> Void
        ) {
            self.onToggleChrome = onToggleChrome
            self.onLocationChange = onLocationChange
            self.onPresentError = onPresentError
        }

        func navigator(_ navigator: VisualNavigator, didTapAt point: CGPoint) {
            DispatchQueue.main.async {
                self.onToggleChrome()
            }
        }

        func navigator(_ navigator: Navigator, locationDidChange locator: Locator) {
            DispatchQueue.main.async {
                self.onLocationChange(locator)
            }
        }

        func navigator(_ navigator: Navigator, presentError error: NavigatorError) {
            DispatchQueue.main.async {
                self.onPresentError(String(describing: error))
            }
        }
    }
}

private struct EPUBReadiumErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "book.closed")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(AppColors.accentBlue)

            Text(AppLocalizer.localized("电子书打开失败"))
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(.white)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onRetry) {
                Text(AppLocalizer.localized("重试"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 120, height: 42)
                    .background(AppColors.accentBlue)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private enum EPUBReadiumReaderError: LocalizedError {
    case invalidFileURL
    case openFailed

    var errorDescription: String? {
        switch self {
        case .invalidFileURL:
            return AppLocalizer.localized("无法读取该 EPUB 文件")
        case .openFailed:
            return AppLocalizer.localized("当前 EPUB 文件暂时无法打开")
        }
    }
}

private struct ReaderTOCEntry: Identifiable, Hashable {
    let id: String
    let title: String
    let link: ReadiumShared.Link
    let level: Int
}

@MainActor
private final class EPUBReadiumReaderSession {
    let navigator: EPUBNavigatorViewController
    let tocEntries: [ReaderTOCEntry]

    private let publication: Publication
    private let httpServer: ReadiumGCDHTTPServer

    private init(
        navigator: EPUBNavigatorViewController,
        publication: Publication,
        httpServer: ReadiumGCDHTTPServer,
        tocEntries: [ReaderTOCEntry]
    ) {
        self.navigator = navigator
        self.publication = publication
        self.httpServer = httpServer
        self.tocEntries = tocEntries
    }

    static func make(
        fileURL: URL,
        displayTitle: String,
        initialLocator: Locator?,
        styleSettings: ReaderStyleSettings
    ) async throws -> EPUBReadiumReaderSession {
        guard let absoluteURL = FileURL(url: fileURL) else {
            throw EPUBReadiumReaderError.invalidFileURL
        }

        let httpClient = DefaultHTTPClient()
        let assetRetriever = AssetRetriever(httpClient: httpClient)
        let publicationOpener = PublicationOpener(
            parser: DefaultPublicationParser(
                httpClient: httpClient,
                assetRetriever: assetRetriever,
                pdfFactory: DefaultPDFDocumentFactory()
            )
        )
        let httpServer = ReadiumGCDHTTPServer(assetRetriever: assetRetriever)

        let asset = try await assetRetriever.retrieve(url: absoluteURL).get()
        let publication = try await publicationOpener.open(asset: asset, allowUserInteraction: false).get()

        let navigator = try EPUBNavigatorViewController(
            publication: publication,
            initialLocation: initialLocator,
            config: EPUBNavigatorViewController.Configuration(
                preferences: preferences(from: styleSettings),
                contentInset: [
                    .compact: (top: 0, bottom: 0),
                    .regular: (top: 0, bottom: 0)
                ]
            ),
            httpServer: httpServer
        )

        let tocEntries = await makeTOCEntries(from: publication)

        return EPUBReadiumReaderSession(
            navigator: navigator,
            publication: publication,
            httpServer: httpServer,
            tocEntries: tocEntries
        )
    }

    func apply(styleSettings: ReaderStyleSettings) {
        navigator.submitPreferences(Self.preferences(from: styleSettings))
    }

    func go(to link: ReadiumShared.Link) {
        Task { _ = await navigator.go(to: link, options: .animated) }
    }

    private static func preferences(from styleSettings: ReaderStyleSettings) -> EPUBPreferences {
        let themeOption = ReaderThemeOption(rawValue: styleSettings.themeRawValue) ?? .dark
        return EPUBPreferences(
            backgroundColor: themeOption.backgroundColor,
            fontSize: styleSettings.fontSize,
            letterSpacing: styleSettings.letterSpacing,
            lineHeight: styleSettings.lineHeight,
            publisherStyles: false,
            scroll: styleSettings.isScrollEnabled,
            textColor: themeOption.textColor,
            theme: themeOption.readiumTheme
        )
    }

    private static func makeTOCEntries(from publication: Publication) async -> [ReaderTOCEntry] {
        let toc = (try? await publication.tableOfContents().get()) ?? []
        return flattenTOCEntries(toc)
    }

    private static func flattenTOCEntries(_ links: [ReadiumShared.Link], level: Int = 0) -> [ReaderTOCEntry] {
        var entries: [ReaderTOCEntry] = []

        for (index, link) in links.enumerated() {
            let title = (link.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
                ? link.title!.trimmingCharacters(in: .whitespacesAndNewlines)
                : link.href

            entries.append(
                ReaderTOCEntry(
                    id: "\(level)-\(index)-\(link.href)",
                    title: title,
                    link: link,
                    level: level
                )
            )

            if !link.children.isEmpty {
                entries.append(contentsOf: flattenTOCEntries(link.children, level: level + 1))
            }
        }

        return entries
    }
}
