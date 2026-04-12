import SwiftUI
import UIKit

struct EbookLibraryView: View {
    @State private var items: [EbookLibraryItem] = []
    @State private var isImporting = false
    @State private var isDownloadSheetPresented = false
    @State private var isImportPickerPresented = false
    @State private var isFormatConversionPresented = false
    @State private var selectedEPUBReaderItem: EbookLibraryItem?
    @State private var selectedTXTReaderItem: EbookLibraryItem?
    @State private var pendingDeletion: EbookLibraryItem?
    @State private var showAlert = false
    @State private var alertMessage: String?

    private let importTypes = EbookConverterViewModel.supportedContentTypes
    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ZStack {
            AppShellBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    EbookLibraryHeader(
                        onImport: { isImportPickerPresented = true },
                        onConvert: { isFormatConversionPresented = true },
                        onDownload: { isDownloadSheetPresented = true }
                    )

                    if items.isEmpty {
                        EbookShelfEmptyState()
                    } else {
                        LazyVGrid(columns: columns, spacing: 18) {
                            ForEach(items) { item in
                                EbookShelfCard(
                                    item: item,
                                    onRead: { openReader(for: item) },
                                    onDelete: { pendingDeletion = item }
                                )
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 36)
            }

            if isImporting {
                loadingOverlay
            }
        }
        .navigationTitle(AppLocalizer.localized("电子书"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear(perform: reloadLibrary)
        .fileImporter(
            isPresented: $isImportPickerPresented,
            allowedContentTypes: importTypes,
            allowsMultipleSelection: true
        ) { result in
            importBooks(from: result)
        }
        .sheet(isPresented: $isDownloadSheetPresented) {
            EbookDownloadSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppColors.background)
        }
        .navigationDestination(item: $selectedEPUBReaderItem) { item in
            EPUBReadiumReaderView(item: item)
        }
        .navigationDestination(item: $selectedTXTReaderItem) { item in
            TXTEbookReaderView(item: item)
        }
        .navigationDestination(isPresented: $isFormatConversionPresented) {
            EbookConverterView()
        }
        .alert(AppLocalizer.localized("删除电子书"), isPresented: .constant(pendingDeletion != nil), presenting: pendingDeletion) { item in
            Button(AppLocalizer.localized("取消"), role: .cancel) {
                pendingDeletion = nil
            }
            Button(AppLocalizer.localized("删除"), role: .destructive) {
                remove(item)
            }
        } message: { item in
            Text(AppLocalizer.formatted("确认从书架移除 %@？", item.title))
        }
        .alert(AppLocalizer.localized("电子书"), isPresented: $showAlert) {
            Button(AppLocalizer.localized("确定"), role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.36).ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .scaleEffect(1.4)
                    .tint(.white)

                Text(AppLocalizer.localized("正在处理电子书..."))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .background(AppColors.cardBackground.opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func reloadLibrary() {
        items = EbookLibraryService.loadItems()

        Task {
            do {
                let refreshedItems = try await Task.detached(priority: .utility) {
                    try EbookLibraryService.refreshCoverAssetsIfNeeded()
                }.value

                await MainActor.run {
                    items = refreshedItems
                }
            } catch {
                // Keep the bookshelf available even if cover repair fails.
            }
        }
    }

    private func importBooks(from result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            isImporting = true

            Task {
                do {
                    let updatedItems = try await Task.detached(priority: .userInitiated) {
                        try EbookLibraryService.importItems(from: urls)
                    }.value
                    await MainActor.run {
                        items = updatedItems
                    }
                } catch {
                    await MainActor.run {
                        alertMessage = error.localizedDescription
                        showAlert = true
                    }
                }

                await MainActor.run {
                    isImporting = false
                }
            }
        case .failure(let error):
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func remove(_ item: EbookLibraryItem) {
        do {
            items = try EbookLibraryService.remove(item)
            pendingDeletion = nil
        } catch {
            pendingDeletion = nil
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func openReader(for item: EbookLibraryItem) {
        switch item.sourceFormat {
        case .epub:
            selectedEPUBReaderItem = item
        case .txt:
            selectedTXTReaderItem = item
        }
    }
}

private struct EbookLibraryHeader: View {
    let onImport: () -> Void
    let onConvert: () -> Void
    let onDownload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Parse Bookshelf")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppColors.accentPurple)
                    .textCase(.uppercase)
                    .tracking(1.4)

                Text(AppLocalizer.localized("电子书"))
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundColor(.white)

                Text(AppLocalizer.localized("在一个页面里管理已导入电子书，快速阅读或进入格式转换。"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                ActionPillButton(icon: "square.and.arrow.down.fill", title: AppLocalizer.localized("导入"), filled: true, accent: AppColors.accentPurple, action: onImport)
                ActionPillButton(icon: "arrow.triangle.2.circlepath.doc.on.clipboard", title: AppLocalizer.localized("格式转换"), filled: false, accent: AppColors.accentBlue, action: onConvert)
                ActionPillButton(icon: "arrow.down.circle.fill", title: AppLocalizer.localized("下载"), filled: false, accent: AppColors.accentGreen, action: onDownload)
            }
        }
    }
}

private struct ActionPillButton: View {
    let icon: String
    let title: String
    let filled: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundColor(filled ? .white : .white.opacity(0.9))
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(filled ? accent.opacity(0.95) : AppColors.cardBackground.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(filled ? Color.clear : .white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct EbookShelfEmptyState: View {
    var body: some View {
        VStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppColors.cardBackground, AppColors.secondaryBackground.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 220)
                .overlay {
                    VStack(spacing: 14) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundColor(AppColors.accentPurple)

                        Text(AppLocalizer.localized("书架还是空的"))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)

                        Text(AppLocalizer.localized("先导入 EPUB 或 TXT 文件，就可以在这里统一管理和阅读。"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
        }
    }
}

private struct EbookShelfCard: View {
    let item: EbookLibraryItem
    let onRead: () -> Void
    let onDelete: () -> Void

    private var coverImage: UIImage? {
        guard
            let coverURL = EbookLibraryService.coverURL(for: item),
            let image = UIImage(contentsOfFile: coverURL.path)
        else {
            return nil
        }
        return image
    }

    private var fallbackCoverTitle: String {
        let compact = item.title
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return compact.isEmpty ? AppLocalizer.localized("电子书") : compact
    }

    var body: some View {
        Button(action: onRead) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    coverBackground
                        .frame(maxWidth: .infinity)
                        .aspectRatio(0.72, contentMode: .fit)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(.white.opacity(0.06), lineWidth: 1)
                        )

                    Menu {
                        Button(AppLocalizer.localized("阅读"), action: onRead)
                        Button(AppLocalizer.localized("删除"), role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.88))
                            .frame(width: 30, height: 30)
                            .background(.black.opacity(0.18))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                }

                Text(item.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, minHeight: 42, alignment: .topLeading)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var coverBackground: some View {
        if let coverImage {
            Image(uiImage: coverImage)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardGradient)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer()
                        Text(fallbackCoverTitle)
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundColor(.white)
                            .lineLimit(4)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(16)
                }
        }
    }

    private var cardGradient: LinearGradient {
        let colors: [Color]
        switch item.sourceFormat {
        case .epub:
            colors = [AppColors.accentPurple.opacity(0.95), AppColors.accentBlue.opacity(0.72)]
        case .txt:
            colors = [AppColors.accentTeal.opacity(0.92), AppColors.accentBlue.opacity(0.58)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private struct EbookDownloadSheet: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(.white.opacity(0.12))
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 8) {
                Text(AppLocalizer.localized("下载电子书"))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)

                Text(AppLocalizer.localized("从合法公版站点获取 EPUB 资源，再导入到书架中。"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, 20)

            VStack(spacing: 12) {
                DownloadSourceRow(
                    title: "Project Gutenberg",
                    detail: AppLocalizer.localized("免费公版书资源，适合下载 EPUB 测试样本。"),
                    action: { openURL(URL(string: "https://www.gutenberg.org/")!) }
                )
                DownloadSourceRow(
                    title: "Standard Ebooks",
                    detail: AppLocalizer.localized("排版更精致的公版 EPUB 资源。"),
                    action: { openURL(URL(string: "https://standardebooks.org/ebooks")!) }
                )
                DownloadSourceRow(
                    title: "Open Library",
                    detail: AppLocalizer.localized("可浏览和借阅部分公开电子书资源。"),
                    action: { openURL(URL(string: "https://openlibrary.org/")!) }
                )
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 10)
        }
    }
}

private struct DownloadSourceRow: View {
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColors.secondaryBackground)
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "globe")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppColors.accentBlue)
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)

                    Text(detail)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(16)
            .background(AppColors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.06), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct TXTBookContent {
    let title: String
    let chapters: [TXTBookChapter]
}

private struct TXTBookChapter: Identifiable, Hashable {
    let id: Int
    let title: String
    let text: String
}

private enum TXTReaderService {
    nonisolated static func loadBook(from url: URL, fallbackTitle: String) throws -> TXTBookContent {
        let rawText = try readText(from: url)
        let normalized = normalize(rawText)
        let trimmed = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TXTReaderError.emptyContent
        }

        let chapters = makeChapters(from: trimmed)
        return TXTBookContent(title: fallbackTitle, chapters: chapters)
    }

    nonisolated private static func readText(from url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let encodings: [String.Encoding] = [
            .utf8,
            .unicode,
            .utf16,
            .utf16LittleEndian,
            .utf16BigEndian,
            .utf32,
            .ascii,
            .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))),
            .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_2312_80.rawValue)))
        ]

        for encoding in encodings {
            if let text = String(data: data, encoding: encoding) {
                return text
            }
        }

        throw TXTReaderError.unreadableFile
    }

    nonisolated private static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{feff}", with: "")
    }

    nonisolated private static func makeChapters(from text: String) -> [TXTBookChapter] {
        let lines = text.components(separatedBy: "\n")
        var headings: [(index: Int, title: String)] = []
        for (index, line) in lines.enumerated() {
            let heading = normalizedHeading(from: line)
            if isChapterHeading(heading) {
                headings.append((index, heading))
            }
        }

        if headings.isEmpty {
            return [TXTBookChapter(id: 0, title: AppLocalizer.localized("正文"), text: text)]
        }

        var chapters: [TXTBookChapter] = []
        if let firstHeading = headings.first, firstHeading.index > 0 {
            let leadingSlice = lines[..<firstHeading.index]
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if shouldKeepLeadingContent(leadingSlice) {
                chapters.append(
                    TXTBookChapter(
                        id: chapters.count,
                        title: AppLocalizer.localized("正文"),
                        text: leadingSlice
                    )
                )
            }
        }

        for (position, heading) in headings.enumerated() {
            let start = heading.index
            let end = position + 1 < headings.count ? headings[position + 1].index : lines.count
            let slice = lines[start..<end].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !slice.isEmpty else { continue }
            chapters.append(TXTBookChapter(id: chapters.count, title: heading.title, text: slice))
        }

        return chapters.isEmpty ? [TXTBookChapter(id: 0, title: AppLocalizer.localized("正文"), text: text)] : chapters
    }

    nonisolated private static func normalizedHeading(from line: String) -> String {
        line
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
    }

    nonisolated private static func isChapterHeading(_ line: String) -> Bool {
        guard !line.isEmpty else { return false }
        guard line.count >= 2, line.count <= 48 else { return false }
        guard !looksLikeSeparator(line) else { return false }
        guard !looksLikeSentence(line) else { return false }

        let patterns = [
            #"^第\s*[0-9零〇一二三四五六七八九十百千万两０-９]+\s*[章回节卷篇部集册幕]\s*[\p{Han}A-Za-z0-9《》〈〉「」『』【】\(\)（）、，,:：.!！？?·\-_—\s]{0,28}$"#,
            #"^[卷部篇册集]\s*[0-9零〇一二三四五六七八九十百千万两０-９]+\s*[\p{Han}A-Za-z0-9《》〈〉「」『』【】\(\)（）、，,:：.!！？?·\-_—\s]{0,28}$"#,
            #"^(序章|序言|前言|楔子|引子|正文|终章|尾声|后记|跋|番外(?:篇)?|附录|完本感言|作品相关)(?:\s*[：:·\-_—]\s*.*)?$"#,
            #"^(chapter|book|part|section)\s+([0-9]+|[ivxlcdm]+|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\b.*$"#,
            #"^(prologue|epilogue|preface|introduction|foreword|afterword)\b.*$"#
        ]

        return patterns.contains { matches($0, in: line, options: [.caseInsensitive]) }
    }

    nonisolated private static func shouldKeepLeadingContent(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let paragraphs = text
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return text.count >= 120 || paragraphs.count >= 5
    }

    nonisolated private static func looksLikeSeparator(_ line: String) -> Bool {
        let separators = CharacterSet(charactersIn: "-_=~*#·•— ")
        return line.unicodeScalars.allSatisfy { separators.contains($0) }
    }

    nonisolated private static func looksLikeSentence(_ line: String) -> Bool {
        let sentenceEndings = CharacterSet(charactersIn: "。！？；;，,")
        guard let lastScalar = line.unicodeScalars.last else { return false }
        if sentenceEndings.contains(lastScalar) {
            return true
        }

        let punctuationCount = line.unicodeScalars.reduce(into: 0) { count, scalar in
            if sentenceEndings.contains(scalar) {
                count += 1
            }
        }
        return punctuationCount >= 2
    }

    nonisolated private static func matches(
        _ pattern: String,
        in line: String,
        options: NSRegularExpression.Options = []
    ) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return false
        }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return regex.firstMatch(in: line, options: [], range: range) != nil
    }
}

private enum TXTReaderError: LocalizedError {
    case unreadableFile
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            return AppLocalizer.localized("无法读取该 TXT 文件")
        case .emptyContent:
            return AppLocalizer.localized("当前 TXT 文件内容为空")
        }
    }
}

private enum TXTReaderOverlayPanel {
    case tableOfContents
    case appearance
}

private enum TXTReaderThemeOption: String, CaseIterable, Identifiable {
    case dark
    case light
    case mint
    case cream

    var id: String { rawValue }

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

    var backgroundColor: UIColor {
        switch self {
        case .dark:
            return UIColor(hex: "#05070C")
        case .light:
            return UIColor(hex: "#F7F7F2")
        case .mint:
            return UIColor(hex: "#E8F5EE")
        case .cream:
            return UIColor(hex: "#F6EEDB")
        }
    }

    var textColor: UIColor {
        switch self {
        case .dark:
            return UIColor(hex: "#F5F7FA")
        case .light:
            return UIColor(hex: "#1F2937")
        case .mint:
            return UIColor(hex: "#23352B")
        case .cream:
            return UIColor(hex: "#4A4032")
        }
    }

    var swatch: Color {
        switch self {
        case .dark:
            return .black
        case .light:
            return .white
        case .mint:
            return Color(hex: "#CFE6D9")
        case .cream:
            return Color(hex: "#E9D9B6")
        }
    }
}

struct TXTEbookReaderView: View {
    let item: EbookLibraryItem

    @Environment(\.dismiss) private var dismiss
    @State private var book: TXTBookContent?
    @State private var loadError: String?
    @State private var isLoading = true
    @State private var chromeVisible = false
    @State private var activePanel: TXTReaderOverlayPanel?
    @State private var styleSettings = EbookReaderPreferencesStore.loadStyleSettings()
    @State private var currentChapterIndex = 0
    @State private var chapterScrollProgress = 0.0
    @State private var chapterScrollTarget = 0.0
    @State private var lastSavedProgress = TXTReaderProgress(chapterIndex: 0, chapterProgress: 0)

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(uiColor: readerTheme.backgroundColor).ignoresSafeArea()

                Group {
                    if let book {
                        TXTReaderTextView(
                            text: currentChapter(in: book).text,
                            styleSettings: styleSettings,
                            theme: readerTheme,
                            targetProgress: chapterScrollTarget,
                            onTap: toggleChrome,
                            onProgressChange: handleScrollProgressChange
                        )
                        .id("txt-\(item.id.uuidString)-\(currentChapterIndex)")
                        .ignoresSafeArea()
                    } else if let loadError {
                        TXTEbookErrorView(message: loadError, onRetry: loadBook)
                    } else {
                        loadingView
                    }
                }

                if !chromeVisible, book != nil {
                    compactChapterOverlay(topInset: statusBarInset(fallback: proxy.safeAreaInsets.top))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .ignoresSafeArea(edges: .top)
                        .transition(.opacity)
                }

                if chromeVisible, book != nil {
                    ZStack {
                        topChrome(topInset: statusBarInset(fallback: proxy.safeAreaInsets.top))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .transition(.move(edge: .top).combined(with: .opacity))

                        bottomOverlay(bottomInset: proxy.safeAreaInsets.bottom)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .ignoresSafeArea(edges: [.top, .bottom])
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(book != nil)
        .animation(.easeInOut(duration: 0.22), value: chromeVisible)
        .animation(.easeInOut(duration: 0.2), value: activePanel)
        .task(id: item.id) {
            loadBook()
        }
        .onDisappear {
            saveProgress(force: true)
        }
    }

    private var loadingView: some View {
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

    private var readerTheme: TXTReaderThemeOption {
        TXTReaderThemeOption(rawValue: styleSettings.themeRawValue) ?? .dark
    }

    private func currentChapter(in book: TXTBookContent) -> TXTBookChapter {
        let safeIndex = min(max(currentChapterIndex, 0), max(book.chapters.count - 1, 0))
        return book.chapters[safeIndex]
    }

    private var compactChapterTitle: String {
        guard let book else { return item.title }
        return currentChapter(in: book).title
    }

    private func topChrome(topInset: CGFloat) -> some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color(hex: "#1B2430"))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Text(item.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer(minLength: 0)

            Color.clear
                .frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.top, max(topInset, 0))
        .padding(.bottom, 10)
        .background(
            Color(hex: "#10161F")
                .ignoresSafeArea(edges: .top)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                }
        )
    }

    private func compactChapterOverlay(topInset: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            HStack(spacing: 0) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(uiColor: readerTheme.textColor).opacity(readerTheme == .dark ? 0.7 : 0.58))
                        .frame(width: 12, height: 24, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Text(compactChapterTitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(uiColor: readerTheme.textColor).opacity(readerTheme == .dark ? 0.7 : 0.58))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)

                Text(compactOverlayTimeString(for: context.date))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(uiColor: readerTheme.textColor).opacity(readerTheme == .dark ? 0.7 : 0.58))
                    .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .padding(.top, compactOverlayTopPadding(for: topInset) + 3)
            .padding(.bottom, 6)
            .background(
                Color(uiColor: readerTheme.backgroundColor)
                    .ignoresSafeArea(edges: .top)
            )
        }
    }

    private func bottomOverlay(bottomInset: CGFloat) -> some View {
        VStack(spacing: 12) {
            if activePanel == .tableOfContents {
                tocPanel
            } else if activePanel == .appearance {
                appearancePanel
            }

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    TXTReaderActionButton(
                        title: AppLocalizer.localized("目录"),
                        systemName: "list.bullet",
                        isActive: activePanel == .tableOfContents
                    ) {
                        togglePanel(.tableOfContents)
                    }

                    TXTReaderActionButton(
                        title: AppLocalizer.localized("样式"),
                        systemName: "textformat.size",
                        isActive: activePanel == .appearance
                    ) {
                        togglePanel(.appearance)
                    }
                }

                HStack(spacing: 12) {
                    Text(progressDescription)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.7))

                    GeometryReader { proxy in
                        Capsule()
                            .fill(Color(hex: "#1B2430"))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(AppColors.accentBlue)
                                    .frame(width: max(22, proxy.size.width * overallProgress))
                            }
                    }
                    .frame(height: 12)

                    Text(AppLocalizer.localized("阅读中"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(hex: "#10161F"))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, max(bottomInset, 0) + 12)
    }

    private var tocPanel: some View {
        ScrollView {
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

                if let book, !book.chapters.isEmpty {
                    ForEach(Array(book.chapters.enumerated()), id: \.element.id) { index, chapter in
                        Button {
                            jumpToChapter(index)
                        } label: {
                            HStack(spacing: 12) {
                                Text(chapter.title)
                                    .font(.system(size: 14, weight: index == currentChapterIndex ? .bold : .medium))
                                    .foregroundColor(index == currentChapterIndex ? .white : Color.white.opacity(0.84))
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index != book.chapters.count - 1 {
                            Divider()
                                .overlay(Color.white.opacity(0.06))
                                .padding(.leading, 16)
                        }
                    }
                } else {
                    Text(AppLocalizer.localized("当前电子书暂时没有可用目录"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 18)
                }
            }
        }
        .frame(maxHeight: 300)
        .background(Color(hex: "#10161F"))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var appearancePanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(AppLocalizer.localized("阅读样式"))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            txtProgressControl(
                title: AppLocalizer.localized("字号"),
                valueText: fontSizeLabel,
                progress: fontProgressWidth / 116,
                decreaseSystemName: "textformat.size.smaller",
                increaseSystemName: "textformat.size.larger",
                canDecrease: styleSettings.fontSize > 0.8,
                canIncrease: styleSettings.fontSize < 1.6,
                onDecrease: { updateFontSize(by: -0.1) },
                onIncrease: { updateFontSize(by: 0.1) }
            )

            txtProgressControl(
                title: AppLocalizer.localized("字间距"),
                valueText: letterSpacingLabel,
                progress: letterSpacingProgressWidth / 116,
                decreaseSystemName: "minus",
                increaseSystemName: "plus",
                canDecrease: styleSettings.letterSpacing > 0,
                canIncrease: styleSettings.letterSpacing < 0.16,
                onDecrease: { updateLetterSpacing(by: -0.02) },
                onIncrease: { updateLetterSpacing(by: 0.02) }
            )

            txtProgressControl(
                title: AppLocalizer.localized("行间距"),
                valueText: lineHeightLabel,
                progress: lineHeightProgressWidth / 116,
                decreaseSystemName: "minus",
                increaseSystemName: "plus",
                canDecrease: styleSettings.lineHeight > 1.2,
                canIncrease: styleSettings.lineHeight < 2.2,
                onDecrease: { updateLineHeight(by: -0.1) },
                onIncrease: { updateLineHeight(by: 0.1) }
            )

            VStack(alignment: .leading, spacing: 12) {
                Text(AppLocalizer.localized("主题"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.76))

                HStack(spacing: 10) {
                    ForEach(TXTReaderThemeOption.allCases) { option in
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
                                                option == readerTheme ? AppColors.accentBlue : Color.white.opacity(0.12),
                                                lineWidth: option == readerTheme ? 2 : 1
                                            )
                                    )

                                Text(option.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(option == readerTheme ? 0.96 : 0.72))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(option == readerTheme ? AppColors.accentBlue.opacity(0.16) : Color.white.opacity(0.04))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(18)
        .background(Color(hex: "#10161F"))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func txtProgressControl(
        title: String,
        valueText: String,
        progress: CGFloat,
        decreaseSystemName: String,
        increaseSystemName: String,
        canDecrease: Bool,
        canIncrease: Bool,
        onDecrease: @escaping () -> Void,
        onIncrease: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.76))

                Spacer(minLength: 0)

                Text(valueText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
            }

            HStack(spacing: 12) {
                TXTReaderMiniIconButton(systemName: decreaseSystemName, action: onDecrease)
                    .disabled(!canDecrease)

                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 8)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(AppColors.accentBlue)
                            .frame(width: max(28, min(max(progress, 0), 1) * 116))
                    }

                TXTReaderMiniIconButton(systemName: increaseSystemName, action: onIncrease)
                    .disabled(!canIncrease)
            }
        }
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

    private var fontProgressWidth: CGFloat {
        let clamped = min(max(styleSettings.fontSize, 0.8), 1.6)
        return ((clamped - 0.8) / 0.8) * 116
    }

    private var letterSpacingProgressWidth: CGFloat {
        let clamped = min(max(styleSettings.letterSpacing, 0), 0.16)
        return (clamped / 0.16) * 116
    }

    private var lineHeightProgressWidth: CGFloat {
        let clamped = min(max(styleSettings.lineHeight, 1.2), 2.2)
        return ((clamped - 1.2) / 1.0) * 116
    }

    private var overallProgress: CGFloat {
        guard let book, !book.chapters.isEmpty else { return 0 }
        let chapterCount = Double(book.chapters.count)
        let normalized = (Double(currentChapterIndex) + chapterScrollProgress) / chapterCount
        return CGFloat(min(max(normalized, 0), 1))
    }

    private var progressDescription: String {
        let percent = max(1, Int((overallProgress * 100).rounded()))
        return "\(percent)%"
    }

    private func loadBook() {
        isLoading = true
        loadError = nil
        book = nil
        activePanel = nil

        let fileURL = EbookLibraryService.fileURL(for: item)

        Task {
            do {
                let loadedBook = try await Task.detached(priority: .userInitiated) {
                    try TXTReaderService.loadBook(from: fileURL, fallbackTitle: item.title)
                }.value

                let savedProgress = EbookReaderPreferencesStore.loadTXTProgress(for: item.id) ?? TXTReaderProgress(chapterIndex: 0, chapterProgress: 0)
                let safeChapter = min(max(savedProgress.chapterIndex, 0), max(loadedBook.chapters.count - 1, 0))
                let safeProgress = min(max(savedProgress.chapterProgress, 0), 1)

                await MainActor.run {
                    book = loadedBook
                    currentChapterIndex = safeChapter
                    chapterScrollProgress = safeProgress
                    chapterScrollTarget = safeProgress
                    lastSavedProgress = TXTReaderProgress(chapterIndex: safeChapter, chapterProgress: safeProgress)
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
        guard book != nil else { return }
        withAnimation(.easeInOut(duration: 0.22)) {
            chromeVisible.toggle()
            if !chromeVisible {
                activePanel = nil
            }
        }
    }

    private func togglePanel(_ panel: TXTReaderOverlayPanel) {
        withAnimation(.easeInOut(duration: 0.2)) {
            activePanel = activePanel == panel ? nil : panel
            chromeVisible = true
        }
    }

    private func handleScrollProgressChange(_ progress: Double) {
        let safeValue = min(max(progress, 0), 1)
        chapterScrollProgress = safeValue
        saveProgress(force: false)
    }

    private func jumpToChapter(_ index: Int) {
        currentChapterIndex = index
        chapterScrollProgress = 0
        chapterScrollTarget = 0
        activePanel = nil
        chromeVisible = false
        saveProgress(force: true)
    }

    private func saveProgress(force: Bool) {
        let progress = TXTReaderProgress(chapterIndex: currentChapterIndex, chapterProgress: chapterScrollProgress)
        let shouldSave = force
            || progress.chapterIndex != lastSavedProgress.chapterIndex
            || abs(progress.chapterProgress - lastSavedProgress.chapterProgress) >= 0.02

        guard shouldSave else { return }
        EbookReaderPreferencesStore.saveTXTProgress(progress, for: item.id)
        lastSavedProgress = progress
    }

    private func updateFontSize(by delta: Double) {
        let nextValue = min(max(styleSettings.fontSize + delta, 0.8), 1.6)
        guard nextValue != styleSettings.fontSize else { return }
        styleSettings.fontSize = nextValue
        EbookReaderPreferencesStore.saveStyleSettings(styleSettings)
    }

    private func updateLetterSpacing(by delta: Double) {
        let nextValue = min(max(styleSettings.letterSpacing + delta, 0), 0.16)
        guard abs(nextValue - styleSettings.letterSpacing) > 0.0001 else { return }
        styleSettings.letterSpacing = nextValue
        EbookReaderPreferencesStore.saveStyleSettings(styleSettings)
    }

    private func updateLineHeight(by delta: Double) {
        let nextValue = min(max(styleSettings.lineHeight + delta, 1.2), 2.2)
        guard abs(nextValue - styleSettings.lineHeight) > 0.0001 else { return }
        styleSettings.lineHeight = nextValue
        EbookReaderPreferencesStore.saveStyleSettings(styleSettings)
    }

    private func updateTheme(_ option: TXTReaderThemeOption) {
        guard readerTheme != option else { return }
        styleSettings.themeRawValue = option.rawValue
        EbookReaderPreferencesStore.saveStyleSettings(styleSettings)
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

    private func compactOverlayTopPadding(for topInset: CGFloat) -> CGFloat {
        if topInset >= 44 {
            return min(max(topInset - 4, 40), 46)
        }
        return max(topInset + 12, 16)
    }

    private func compactOverlayTimeString(for date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }
}

private struct TXTEbookErrorView: View {
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

private struct TXTReaderTextView: UIViewRepresentable {
    let text: String
    let styleSettings: ReaderStyleSettings
    let theme: TXTReaderThemeOption
    let targetProgress: Double
    let onTap: () -> Void
    let onProgressChange: (Double) -> Void

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.isEditable = false
        textView.isSelectable = true
        textView.showsVerticalScrollIndicator = false
        textView.showsHorizontalScrollIndicator = false
        textView.alwaysBounceVertical = true
        textView.textContainerInset = UIEdgeInsets(top: 34, left: 24, bottom: 180, right: 24)
        textView.textContainer.lineFragmentPadding = 0
        textView.backgroundColor = theme.backgroundColor
        textView.keyboardDismissMode = .interactive

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        textView.addGestureRecognizer(tap)

        context.coordinator.onTap = onTap
        context.coordinator.onProgressChange = onProgressChange
        context.coordinator.configure(textView, text: text, styleSettings: styleSettings, theme: theme, targetProgress: targetProgress)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.onProgressChange = onProgressChange
        context.coordinator.configure(uiView, text: text, styleSettings: styleSettings, theme: theme, targetProgress: targetProgress)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap, onProgressChange: onProgressChange)
    }

    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var onTap: () -> Void
        var onProgressChange: (Double) -> Void
        private var lastText = ""
        private var lastStyle = ReaderStyleSettings.default
        private var lastTheme: TXTReaderThemeOption = .dark
        private var appliedTargetProgress = -1.0

        init(onTap: @escaping () -> Void, onProgressChange: @escaping (Double) -> Void) {
            self.onTap = onTap
            self.onProgressChange = onProgressChange
        }

        func configure(_ textView: UITextView, text: String, styleSettings: ReaderStyleSettings, theme: TXTReaderThemeOption, targetProgress: Double) {
            let textChanged = lastText != text
            let styleChanged = lastStyle != styleSettings || lastTheme != theme

            if textChanged || styleChanged {
                let currentProgress = normalizedProgress(for: textView)
                textView.attributedText = attributedText(for: text, styleSettings: styleSettings, theme: theme)
                textView.backgroundColor = theme.backgroundColor
                textView.tintColor = UIColor(AppColors.accentBlue)
                lastText = text
                lastStyle = styleSettings
                lastTheme = theme

                let nextProgress = textChanged ? targetProgress : currentProgress
                apply(targetProgress: nextProgress, to: textView)
            } else if abs(appliedTargetProgress - targetProgress) > 0.001 {
                apply(targetProgress: targetProgress, to: textView)
            }
        }

        private func attributedText(for text: String, styleSettings: ReaderStyleSettings, theme: TXTReaderThemeOption) -> NSAttributedString {
            let fontSize = 21 * styleSettings.fontSize
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byWordWrapping
            paragraphStyle.alignment = .natural
            paragraphStyle.lineSpacing = max(0, (fontSize * styleSettings.lineHeight) - fontSize)

            return NSAttributedString(
                string: text,
                attributes: [
                    .font: UIFont.systemFont(ofSize: fontSize, weight: .regular),
                    .foregroundColor: theme.textColor,
                    .kern: styleSettings.letterSpacing * 8,
                    .paragraphStyle: paragraphStyle
                ]
            )
        }

        private func apply(targetProgress: Double, to textView: UITextView) {
            let clamped = min(max(targetProgress, 0), 1)
            appliedTargetProgress = clamped
            DispatchQueue.main.async {
                let visibleHeight = textView.bounds.height - textView.adjustedContentInset.top - textView.adjustedContentInset.bottom
                let maxOffset = max(textView.contentSize.height - visibleHeight, 0)
                let targetOffsetY = maxOffset * clamped - textView.adjustedContentInset.top
                textView.setContentOffset(CGPoint(x: 0, y: max(targetOffsetY, -textView.adjustedContentInset.top)), animated: false)
            }
        }

        private func normalizedProgress(for textView: UITextView) -> Double {
            let visibleHeight = textView.bounds.height - textView.adjustedContentInset.top - textView.adjustedContentInset.bottom
            let maxOffset = max(textView.contentSize.height - visibleHeight, 0)
            guard maxOffset > 0 else { return 0 }
            let currentOffset = min(max(textView.contentOffset.y + textView.adjustedContentInset.top, 0), maxOffset)
            return currentOffset / maxOffset
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let textView = scrollView as? UITextView else { return }
            let progress = normalizedProgress(for: textView)
            DispatchQueue.main.async {
                self.onProgressChange(progress)
            }
        }

        @objc
        func handleTap() {
            DispatchQueue.main.async {
                self.onTap()
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

private struct TXTReaderActionButton: View {
    let title: String
    let systemName: String
    let isActive: Bool
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
            .foregroundColor(isActive ? AppColors.accentBlue : .white)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: "#1B2430"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct TXTReaderMiniIconButton: View {
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

private extension UIColor {
    convenience init(hex: String) {
        let hexString = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&int)
        let red, green, blue: UInt64
        switch hexString.count {
        case 6:
            (red, green, blue) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (red, green, blue) = (0, 0, 0)
        }

        self.init(
            red: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: 1
        )
    }
}

#Preview {
    NavigationStack {
        EbookLibraryView()
    }
}
