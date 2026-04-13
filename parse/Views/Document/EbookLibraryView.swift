import SwiftUI
import UIKit
import Combine

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
        .fullScreenCover(isPresented: $isDownloadSheetPresented) {
            EbookDownloadSheet { importedItems in
                items = importedItems
                isDownloadSheetPresented = false
            }
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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel: EbookDownloadViewModel

    init(onImported: @escaping ([EbookLibraryItem]) -> Void) {
        _viewModel = StateObject(wrappedValue: EbookDownloadViewModel(onImported: onImported))
    }

    var body: some View {
        ZStack {
            AppShellBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Spacer()

                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.06))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(AppLocalizer.localized("下载电子书"))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)

                        Text(AppLocalizer.localized("输入可直接访问的 EPUB 或 TXT 文件链接，下载后会自动导入到书架。"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(AppLocalizer.localized("下载链接"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.82))

                        TextEditor(text: $viewModel.link)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundColor(.white)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                            .frame(minHeight: 108)
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )

                        if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppColors.accentRed)
                        }

                        Button {
                            viewModel.startOrResume()
                        } label: {
                            HStack(spacing: 8) {
                                if viewModel.state == .downloading || viewModel.state == .importing {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.9)
                                } else {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 15, weight: .bold))
                                }

                                Text(viewModel.primaryButtonTitle)
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(AppColors.accentGreen.opacity(viewModel.canStart ? 0.96 : 0.42))
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.canStart)

                        if viewModel.showsProgress {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(viewModel.statusTitle)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.86))

                                    if !viewModel.speedLabel.isEmpty {
                                        Text(viewModel.speedLabel)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(AppColors.accentBlue.opacity(0.92))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule(style: .continuous)
                                                    .fill(AppColors.accentBlue.opacity(0.12))
                                            )
                                    }

                                    Spacer(minLength: 0)

                                    Text(viewModel.progressLabel)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(AppColors.textSecondary)
                                }

                                ProgressView(value: viewModel.progress)
                                    .tint(AppColors.accentBlue)

                                HStack(spacing: 10) {
                                    if viewModel.state == .downloading {
                                        downloadActionButton(
                                            title: AppLocalizer.localized("暂停下载"),
                                            icon: "pause.fill",
                                            accent: AppColors.accentBlue,
                                            action: viewModel.pause
                                        )
                                    }

                                    if viewModel.state == .paused || viewModel.state == .downloading {
                                        downloadActionButton(
                                            title: AppLocalizer.localized("取消下载"),
                                            icon: "xmark",
                                            accent: AppColors.accentRed,
                                            action: viewModel.cancel
                                        )
                                    }
                                }
                            }
                            .padding(14)
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                        }
                    }

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
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 36)
            }
        }
        .alert(AppLocalizer.localized("下载电子书"), isPresented: Binding(
            get: { viewModel.errorMessage != nil && !viewModel.errorMessage!.isEmpty },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(AppLocalizer.localized("确定"), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func downloadActionButton(title: String, icon: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(0.92))
            )
        }
        .buttonStyle(.plain)
    }
}

private final class EbookDownloadViewModel: NSObject, ObservableObject {
    enum State {
        case idle
        case downloading
        case paused
        case importing
    }

    @Published var link = ""
    @Published var state: State = .idle
    @Published var progress: Double = 0
    @Published var errorMessage: String?
    @Published private var bytesPerSecond: Double = 0
    @Published private var bytesReceived: Int64 = 0
    @Published private var expectedBytes: Int64 = 0

    private let onImported: ([EbookLibraryItem]) -> Void
    private var session: URLSession?
    private var task: URLSessionDownloadTask?
    private var sizeProbeTask: URLSessionDataTask?
    private var resumeData: Data?
    private var currentRemoteURL: URL?
    private var lastSpeedSampleDate: Date?
    private var lastSpeedSampleBytes: Int64 = 0

    init(onImported: @escaping ([EbookLibraryItem]) -> Void) {
        self.onImported = onImported
    }

    var canStart: Bool {
        switch state {
        case .downloading, .importing:
            return false
        case .idle, .paused:
            return !link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var showsProgress: Bool {
        state != .idle
    }

    var primaryButtonTitle: String {
        switch state {
        case .paused:
            return AppLocalizer.localized("继续下载")
        case .importing:
            return AppLocalizer.localized("正在导入电子书...")
        default:
            return AppLocalizer.localized("下载并导入")
        }
    }

    var statusTitle: String {
        switch state {
        case .downloading:
            return AppLocalizer.localized("下载中")
        case .paused:
            return AppLocalizer.localized("已暂停")
        case .importing:
            return AppLocalizer.localized("正在导入电子书...")
        case .idle:
            return ""
        }
    }

    var progressLabel: String {
        if expectedBytes > 0 {
            let boundedProgress = min(max(progress, 0), 1)
            return "\(Int((boundedProgress * 100).rounded()))%"
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytesReceived)
    }

    var speedLabel: String {
        guard state == .downloading, bytesPerSecond > 0 else { return "" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return "\(formatter.string(fromByteCount: Int64(bytesPerSecond)))/s"
    }

    var transferSizeLabel: String {
        guard bytesReceived > 0 || expectedBytes > 0 else { return "" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true

        let receivedText = formatter.string(fromByteCount: bytesReceived)
        if expectedBytes > 0 {
            let expectedText = formatter.string(fromByteCount: expectedBytes)
            return "\(receivedText)/\(expectedText)"
        }

        return receivedText
    }

    func startOrResume() {
        guard state != .downloading, state != .importing else { return }
        errorMessage = nil

        if let resumeData {
            let task = makeSession().downloadTask(withResumeData: resumeData)
            self.resumeData = nil
            self.task = task
            resetSpeedTracking(keepingTransferSize: true)
            if expectedBytes <= 0, let currentRemoteURL {
                prefetchExpectedBytes(for: currentRemoteURL)
            }
            state = .downloading
            task.resume()
            return
        }

        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let remoteURL = URL(string: trimmed),
            let scheme = remoteURL.scheme?.lowercased(),
            scheme == "https" || scheme == "http"
        else {
            errorMessage = AppLocalizer.localized("请输入有效的下载链接")
            return
        }

        currentRemoteURL = remoteURL
        progress = 0
        resetSpeedTracking()
        prefetchExpectedBytes(for: remoteURL)
        let request = URLRequest(url: remoteURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 90)
        let task = makeSession().downloadTask(with: request)
        self.task = task
        state = .downloading
        task.resume()
    }

    func pause() {
        guard state == .downloading, let task else { return }
        task.cancel(byProducingResumeData: { [weak self] data in
            DispatchQueue.main.async {
                guard let self else { return }
                self.resumeData = data
                self.task = nil
                self.bytesPerSecond = 0
                self.lastSpeedSampleDate = nil
                self.lastSpeedSampleBytes = 0
                self.state = data == nil ? .idle : .paused
            }
        })
    }

    func cancel() {
        task?.cancel()
        sizeProbeTask?.cancel()
        task = nil
        sizeProbeTask = nil
        resumeData = nil
        currentRemoteURL = nil
        progress = 0
        bytesPerSecond = 0
        bytesReceived = 0
        expectedBytes = 0
        lastSpeedSampleDate = nil
        lastSpeedSampleBytes = 0
        state = .idle
        errorMessage = nil
    }

    private func makeSession() -> URLSession {
        if let session {
            return session
        }
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        self.session = session
        return session
    }

    private func resetSpeedTracking(keepingTransferSize: Bool = false) {
        bytesPerSecond = 0
        if !keepingTransferSize {
            bytesReceived = 0
            expectedBytes = 0
        }
        lastSpeedSampleDate = Date()
        lastSpeedSampleBytes = 0
    }

    private func prefetchExpectedBytes(for remoteURL: URL) {
        sizeProbeTask?.cancel()

        var request = URLRequest(url: remoteURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "HEAD"

        let task = URLSession.shared.dataTask(with: request) { [weak self] _, response, _ in
            guard let self else { return }
            let resolvedExpectedBytes: Int64 = {
                if let responseExpected = response?.expectedContentLength, responseExpected > 0 {
                    return responseExpected
                }
                if let httpResponse = response as? HTTPURLResponse,
                   let contentLengthHeader = httpResponse.value(forHTTPHeaderField: "Content-Length"),
                   let contentLength = Int64(contentLengthHeader),
                   contentLength > 0 {
                    return contentLength
                }
                return 0
            }()

            if resolvedExpectedBytes > 0 {
                DispatchQueue.main.async {
                    self.expectedBytes = max(self.expectedBytes, resolvedExpectedBytes)
                    if self.expectedBytes > 0, self.bytesReceived > 0 {
                        self.progress = Double(self.bytesReceived) / Double(self.expectedBytes)
                    }
                }
                return
            }

            self.prefetchExpectedBytesUsingRangeProbe(for: remoteURL)
        }
        sizeProbeTask = task
        task.resume()
    }

    private func prefetchExpectedBytesUsingRangeProbe(for remoteURL: URL) {
        sizeProbeTask?.cancel()

        var request = URLRequest(url: remoteURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = "GET"
        request.setValue("bytes=0-0", forHTTPHeaderField: "Range")

        let task = URLSession.shared.dataTask(with: request) { [weak self] _, response, _ in
            guard let self else { return }
            guard let httpResponse = response as? HTTPURLResponse else { return }

            let resolvedExpectedBytes: Int64 = {
                if let contentRange = httpResponse.value(forHTTPHeaderField: "Content-Range"),
                   let slashIndex = contentRange.lastIndex(of: "/") {
                    let suffix = contentRange[contentRange.index(after: slashIndex)...]
                    if let totalBytes = Int64(suffix), totalBytes > 0 {
                        return totalBytes
                    }
                }

                if let contentLengthHeader = httpResponse.value(forHTTPHeaderField: "Content-Length"),
                   let contentLength = Int64(contentLengthHeader),
                   contentLength > 0,
                   httpResponse.statusCode == 200 {
                    return contentLength
                }

                if response?.expectedContentLength ?? 0 > 0 {
                    return response?.expectedContentLength ?? 0
                }

                return 0
            }()

            guard resolvedExpectedBytes > 0 else { return }
            DispatchQueue.main.async {
                self.expectedBytes = max(self.expectedBytes, resolvedExpectedBytes)
                if self.expectedBytes > 0, self.bytesReceived > 0 {
                    self.progress = Double(self.bytesReceived) / Double(self.expectedBytes)
                }
            }
        }
        sizeProbeTask = task
        task.resume()
    }
}

extension EbookDownloadViewModel: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        DispatchQueue.main.async {
            let inferredExpectedBytes: Int64 = {
                if totalBytesExpectedToWrite > 0 { return totalBytesExpectedToWrite }
                if let responseExpected = downloadTask.response?.expectedContentLength, responseExpected > 0 { return responseExpected }
                let taskExpected = downloadTask.countOfBytesExpectedToReceive
                return taskExpected > 0 ? taskExpected : 0
            }()

            self.bytesReceived = totalBytesWritten
            if inferredExpectedBytes > 0 {
                self.expectedBytes = max(self.expectedBytes, inferredExpectedBytes)
            }
            if self.expectedBytes > 0 {
                self.progress = Double(totalBytesWritten) / Double(self.expectedBytes)
            } else {
                self.progress = 0
            }

            let now = Date()
            if self.lastSpeedSampleDate == nil {
                self.lastSpeedSampleDate = now
                self.lastSpeedSampleBytes = totalBytesWritten
                self.bytesPerSecond = max(Double(bytesWritten), 0)
                return
            }

            let elapsed = now.timeIntervalSince(self.lastSpeedSampleDate ?? now)
            if elapsed >= 0.2 {
                let deltaBytes = totalBytesWritten - self.lastSpeedSampleBytes
                let rawBytesPerSecond = elapsed > 0 ? Double(deltaBytes) / elapsed : 0
                if self.bytesPerSecond == 0 {
                    self.bytesPerSecond = rawBytesPerSecond
                } else {
                    self.bytesPerSecond = (self.bytesPerSecond * 0.45) + (rawBytesPerSecond * 0.55)
                }
                self.lastSpeedSampleDate = now
                self.lastSpeedSampleBytes = totalBytesWritten
            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let remoteURL = currentRemoteURL, let response = downloadTask.response else { return }

        do {
            let fileInfo = try EbookLibraryService.resolvedDownloadFileInfo(for: remoteURL, response: response)
            let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
            let localURL = tempDirectory.appendingPathComponent(fileInfo.filename)
            try FileManager.default.moveItem(at: location, to: localURL)

            DispatchQueue.main.async {
                self.state = .importing
                self.progress = 1
                self.bytesPerSecond = 0
                self.bytesReceived = self.expectedBytes > 0 ? self.expectedBytes : self.bytesReceived
            }

            Task.detached(priority: .userInitiated) {
                defer {
                    try? FileManager.default.removeItem(at: localURL)
                    try? FileManager.default.removeItem(at: tempDirectory)
                }

                do {
                    let importedItems = try EbookLibraryService.importDownloadedFile(at: localURL)
                    await MainActor.run {
                        self.task = nil
                        self.sizeProbeTask = nil
                        self.resumeData = nil
                        self.currentRemoteURL = nil
                        self.state = .idle
                        self.progress = 0
                        self.bytesPerSecond = 0
                        self.bytesReceived = 0
                        self.expectedBytes = 0
                        self.onImported(importedItems)
                    }
                } catch {
                    await MainActor.run {
                        self.task = nil
                        self.sizeProbeTask = nil
                        self.resumeData = nil
                        self.currentRemoteURL = nil
                        self.state = .idle
                        self.progress = 0
                        self.bytesPerSecond = 0
                        self.bytesReceived = 0
                        self.expectedBytes = 0
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.task = nil
                self.sizeProbeTask = nil
                self.resumeData = nil
                self.currentRemoteURL = nil
                self.state = .idle
                self.progress = 0
                self.bytesPerSecond = 0
                self.bytesReceived = 0
                self.expectedBytes = 0
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        guard let error else { return }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }

        DispatchQueue.main.async {
            self.task = nil
            self.sizeProbeTask = nil
            self.resumeData = nil
            self.currentRemoteURL = nil
            self.state = .idle
            self.progress = 0
            self.bytesPerSecond = 0
            self.bytesReceived = 0
            self.expectedBytes = 0
            self.errorMessage = error.localizedDescription
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

nonisolated private struct TXTBookContent {
    let title: String
    var chapters: [TXTBookChapter]
    var isParsingComplete: Bool
}

nonisolated private struct TXTBookChapter: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let text: String
}

nonisolated private struct CachedTXTBookChapterSummary: Codable, Hashable {
    let id: Int
    let title: String
}

nonisolated private struct TXTBookParsingState {
    let text: String
    let contentRange: NSRange
    var nextLocation: Int
    var pendingHeading: TXTBookPendingHeading?
    var didHandleLeadingContent: Bool
}

nonisolated private struct TXTBookPendingHeading: Codable {
    let title: String
    let start: Int
}

nonisolated private struct CachedTXTBookSnapshot: Codable {
    let title: String
    let chapters: [CachedTXTBookChapterSummary]
    let isParsingComplete: Bool
    let parsingState: CachedTXTBookParsingState?
    let sourceFileSize: Int64
    let sourceModificationTime: TimeInterval
}

nonisolated private struct CachedTXTBookParsingState: Codable {
    let contentLocation: Int
    let contentLength: Int
    let nextLocation: Int
    let pendingHeading: TXTBookPendingHeading?
    let didHandleLeadingContent: Bool
}

private enum TXTReaderService {
    nonisolated private static let parsingChunkChapterCount = 24
    nonisolated private static let libraryFolderName = "EbookLibrary"
    nonisolated private static let cacheFolderName = "TXTReaderCache"
    nonisolated private static let memoryCacheLock = NSLock()
    nonisolated(unsafe) private static var memoryCacheEntries: [String: TXTBookContent] = [:]
    nonisolated(unsafe) private static var signatureCacheEntries: [String: String] = [:]

    nonisolated static func loadBook(
        from url: URL,
        item: EbookLibraryItem,
        preferredChapterIndex: Int = 0,
        preloadRadius: Int = 3
    ) throws -> TXTBookContent {
        if let cachedBook = loadCachedBookIfAvailable(
            from: url,
            item: item,
            preferredChapterIndex: preferredChapterIndex,
            preloadRadius: preloadRadius
        ) {
            return cachedBook
        }

        let sourceSignature = try sourceSignature(for: url)
        if let snapshot = loadCachedSnapshot(for: item, signature: sourceSignature), !snapshot.isParsingComplete {
            let payload = try readTextPayload(from: url)
            let normalized = normalize(payload.text)
            let partialBook = makeBook(from: snapshot, item: item, loadChapterTexts: true)
            var state = makeParsingState(from: snapshot, normalizedText: normalized)
            let resumedBook = try parseEntireBook(
                title: item.title,
                initialBook: partialBook,
                state: &state,
                item: item,
                signature: sourceSignature
            )
            persistCache(for: item, book: resumedBook, signature: sourceSignature, parsingState: nil)
            storeInMemoryCache(resumedBook, for: item, signature: sourceSignature)
            return resumedBook
        }

        let payload = try readTextPayload(from: url)
        let normalized = normalize(payload.text)
        let contentRange = trimmedContentRange(in: normalized)
        guard contentRange.length > 0 else {
            throw TXTReaderError.emptyContent
        }

        var state = TXTBookParsingState(
            text: normalized,
            contentRange: contentRange,
            nextLocation: contentRange.location,
            pendingHeading: nil,
            didHandleLeadingContent: false
        )
        let book = try parseEntireBook(
            title: item.title,
            initialBook: TXTBookContent(
                title: item.title,
                chapters: [],
                isParsingComplete: false
            ),
            state: &state,
            item: item,
            signature: sourceSignature
        )
        persistCache(for: item, book: book, signature: sourceSignature, parsingState: nil)
        storeInMemoryCache(book, for: item, signature: sourceSignature)
        return book
    }

    nonisolated static func loadCachedBookIfAvailable(
        from url: URL,
        item: EbookLibraryItem,
        preferredChapterIndex: Int,
        preloadRadius: Int
    ) -> TXTBookContent? {
        guard let signature = try? sourceSignature(for: url) else {
            return nil
        }
        if let memoryCached = loadMemoryCachedBook(for: item, signature: signature) {
            let hydrated = hydrateChapterWindow(
                in: memoryCached,
                for: item,
                centerIndex: preferredChapterIndex,
                radius: preloadRadius
            )
            storeInMemoryCache(hydrated, for: item, signature: signature)
            return hydrated
        }
        guard let snapshot = loadCachedSnapshot(for: item, signature: signature), snapshot.isParsingComplete else {
            return nil
        }

        let book = hydrateChapterWindow(
            in: makeBook(from: snapshot, item: item, loadChapterTexts: false),
            for: item,
            centerIndex: preferredChapterIndex,
            radius: preloadRadius
        )
        storeInMemoryCache(book, for: item, signature: signature)
        return book
    }

    nonisolated private static func readTextPayload(from url: URL) throws -> (text: String, byteCount: Int) {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
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
                return (text, data.count)
            }
        }

        throw TXTReaderError.unreadableFile
    }

    nonisolated private static func normalize(_ text: String) -> String {
        guard text.contains("\r") || text.contains("\u{feff}") else {
            return text
        }

        return text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{feff}", with: "")
    }

    nonisolated private static func trimmedContentRange(in text: String) -> NSRange {
        let source = text as NSString
        var start = 0
        var end = source.length
        let whitespace = CharacterSet.whitespacesAndNewlines

        while start < end {
            let scalar = source.character(at: start)
            guard let unicodeScalar = UnicodeScalar(scalar), whitespace.contains(unicodeScalar) else {
                break
            }
            start += 1
        }

        while end > start {
            let scalar = source.character(at: end - 1)
            guard let unicodeScalar = UnicodeScalar(scalar), whitespace.contains(unicodeScalar) else {
                break
            }
            end -= 1
        }

        return NSRange(location: start, length: max(end - start, 0))
    }

    nonisolated private static func sourceSignature(for url: URL) throws -> (fileSize: Int64, modificationTime: TimeInterval) {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return (
            Int64(values.fileSize ?? 0),
            values.contentModificationDate?.timeIntervalSince1970 ?? 0
        )
    }

    nonisolated private static func persistCache(
        for item: EbookLibraryItem,
        book: TXTBookContent,
        signature: (fileSize: Int64, modificationTime: TimeInterval),
        parsingState: TXTBookParsingState?,
        updatedChapters: [TXTBookChapter]? = nil
    ) {
        let snapshot = CachedTXTBookSnapshot(
            title: book.title,
            chapters: book.chapters.map { CachedTXTBookChapterSummary(id: $0.id, title: $0.title) },
            isParsingComplete: book.isParsingComplete,
            parsingState: makeCachedParsingState(from: parsingState),
            sourceFileSize: signature.fileSize,
            sourceModificationTime: signature.modificationTime
        )

        do {
            _ = try metadataDirectory()
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            let data = try encoder.encode(snapshot)
            try data.write(to: metadataURL(for: item), options: .atomic)
            try writeChapterShards(updatedChapters ?? book.chapters, for: item)
        } catch {
            #if DEBUG
            print("Failed to cache TXT book:", error.localizedDescription)
            #endif
        }
    }

    nonisolated private static func loadCachedSnapshot(
        for item: EbookLibraryItem,
        signature: (fileSize: Int64, modificationTime: TimeInterval)
    ) -> CachedTXTBookSnapshot? {
        guard
            let data = try? Data(contentsOf: metadataURL(for: item))
        else {
            return nil
        }

        let snapshot =
            (try? PropertyListDecoder().decode(CachedTXTBookSnapshot.self, from: data))
            ?? (try? JSONDecoder().decode(CachedTXTBookSnapshot.self, from: data))

        guard
            let snapshot,
            snapshot.sourceFileSize == signature.fileSize,
            abs(snapshot.sourceModificationTime - signature.modificationTime) < 0.5
        else {
            return nil
        }

        return snapshot
    }

    nonisolated private static func isParsingComplete(_ state: TXTBookParsingState) -> Bool {
        state.nextLocation >= NSMaxRange(state.contentRange) && state.pendingHeading == nil
    }

    nonisolated private static func parseEntireBook(
        title: String,
        initialBook: TXTBookContent,
        state: inout TXTBookParsingState,
        item: EbookLibraryItem,
        signature: (fileSize: Int64, modificationTime: TimeInterval)
    ) throws -> TXTBookContent {
        var book = initialBook

        while true {
            let wasComplete = isParsingComplete(state)
            if wasComplete {
                book.isParsingComplete = true
                break
            }

            let targetCount = max(book.chapters.count + parsingChunkChapterCount, parsingChunkChapterCount)
            let chunk = scanChapters(into: &state, existingCount: book.chapters.count, targetCount: targetCount)
            if !chunk.isEmpty {
                book.chapters.append(contentsOf: chunk)
            }

            book.isParsingComplete = isParsingComplete(state)
            persistCache(
                for: item,
                book: book,
                signature: signature,
                parsingState: book.isParsingComplete ? nil : state,
                updatedChapters: chunk
            )

            if book.isParsingComplete {
                break
            }

            try Task.checkCancellation()

            if chunk.isEmpty {
                break
            }
        }

        guard book.isParsingComplete else {
            persistCache(for: item, book: book, signature: signature, parsingState: state)
            throw TXTReaderError.incompleteParsing
        }

        return TXTBookContent(
            title: title,
            chapters: book.chapters,
            isParsingComplete: true
        )
    }

    nonisolated private static func makeBook(
        from snapshot: CachedTXTBookSnapshot,
        item: EbookLibraryItem,
        loadChapterTexts: Bool
    ) -> TXTBookContent {
        TXTBookContent(
            title: snapshot.title,
            chapters: snapshot.chapters.map { summary in
                TXTBookChapter(
                    id: summary.id,
                    title: summary.title,
                    text: loadChapterTexts ? (loadChapterText(for: item, chapterID: summary.id) ?? "") : ""
                )
            },
            isParsingComplete: snapshot.isParsingComplete
        )
    }

    nonisolated private static func makeParsingState(from snapshot: CachedTXTBookSnapshot, normalizedText: String) -> TXTBookParsingState {
        if let cachedParsingState = snapshot.parsingState {
            return TXTBookParsingState(
                text: normalizedText,
                contentRange: NSRange(location: cachedParsingState.contentLocation, length: cachedParsingState.contentLength),
                nextLocation: cachedParsingState.nextLocation,
                pendingHeading: cachedParsingState.pendingHeading,
                didHandleLeadingContent: cachedParsingState.didHandleLeadingContent
            )
        }

        let contentRange = trimmedContentRange(in: normalizedText)
        return TXTBookParsingState(
            text: normalizedText,
            contentRange: contentRange,
            nextLocation: contentRange.location,
            pendingHeading: nil,
            didHandleLeadingContent: false
        )
    }

    nonisolated private static func makeCachedParsingState(from parsingState: TXTBookParsingState?) -> CachedTXTBookParsingState? {
        guard let parsingState else { return nil }
        return CachedTXTBookParsingState(
            contentLocation: parsingState.contentRange.location,
            contentLength: parsingState.contentRange.length,
            nextLocation: parsingState.nextLocation,
            pendingHeading: parsingState.pendingHeading,
            didHandleLeadingContent: parsingState.didHandleLeadingContent
        )
    }

    nonisolated private static func memoryCacheKey(for item: EbookLibraryItem) -> String {
        item.id.uuidString.lowercased()
    }

    nonisolated private static func signatureString(for signature: (fileSize: Int64, modificationTime: TimeInterval)) -> String {
        "\(signature.fileSize)-\(signature.modificationTime)"
    }

    nonisolated private static func loadMemoryCachedBook(
        for item: EbookLibraryItem,
        signature: (fileSize: Int64, modificationTime: TimeInterval)
    ) -> TXTBookContent? {
        let key = memoryCacheKey(for: item)
        let signatureValue = signatureString(for: signature)

        memoryCacheLock.lock()
        defer { memoryCacheLock.unlock() }

        guard let cachedSignature = signatureCacheEntries[key] else {
            return nil
        }
        guard cachedSignature == signatureValue else {
            memoryCacheEntries.removeValue(forKey: key)
            signatureCacheEntries.removeValue(forKey: key)
            return nil
        }
        return memoryCacheEntries[key]
    }

    nonisolated private static func storeInMemoryCache(
        _ book: TXTBookContent,
        for item: EbookLibraryItem,
        signature: (fileSize: Int64, modificationTime: TimeInterval)
    ) {
        let key = memoryCacheKey(for: item)
        memoryCacheLock.lock()
        memoryCacheEntries[key] = book
        signatureCacheEntries[key] = signatureString(for: signature)
        if memoryCacheEntries.count > 8, let staleKey = memoryCacheEntries.keys.first(where: { $0 != key }) {
            memoryCacheEntries.removeValue(forKey: staleKey)
            signatureCacheEntries.removeValue(forKey: staleKey)
        }
        memoryCacheLock.unlock()
    }

    nonisolated static func hydrateChapterWindow(
        in book: TXTBookContent,
        for item: EbookLibraryItem,
        centerIndex: Int,
        radius: Int
    ) -> TXTBookContent {
        guard !book.chapters.isEmpty else { return book }

        let lowerBound = max(centerIndex - radius, 0)
        let upperBound = min(centerIndex + radius, book.chapters.count - 1)
        var hydratedBook = book
        var mutated = false

        for index in lowerBound...upperBound {
            guard hydratedBook.chapters[index].text.isEmpty else { continue }
            guard let text = loadChapterText(for: item, chapterID: hydratedBook.chapters[index].id) else { continue }
            hydratedBook.chapters[index] = TXTBookChapter(
                id: hydratedBook.chapters[index].id,
                title: hydratedBook.chapters[index].title,
                text: text
            )
            mutated = true
        }

        return mutated ? hydratedBook : book
    }

    nonisolated private static func metadataDirectory() throws -> URL {
        let root = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root
            .appendingPathComponent(libraryFolderName, isDirectory: true)
            .appendingPathComponent(cacheFolderName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    nonisolated private static func chaptersDirectory(for item: EbookLibraryItem) throws -> URL {
        let directory = try metadataDirectory()
            .appendingPathComponent(item.id.uuidString.lowercased(), isDirectory: true)
            .appendingPathComponent("chapters", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    nonisolated private static func metadataURL(for item: EbookLibraryItem) -> URL {
        (try? metadataDirectory().appendingPathComponent("\(item.id.uuidString.lowercased()).plist"))
        ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(item.id.uuidString.lowercased()).plist")
    }

    nonisolated private static func chapterURL(for item: EbookLibraryItem, chapterID: Int) -> URL {
        (try? chaptersDirectory(for: item).appendingPathComponent("\(chapterID).txt"))
        ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(item.id.uuidString.lowercased())-\(chapterID).txt")
    }

    nonisolated private static func writeChapterShards(_ chapters: [TXTBookChapter], for item: EbookLibraryItem) throws {
        guard !chapters.isEmpty else { return }
        for chapter in chapters {
            let url = chapterURL(for: item, chapterID: chapter.id)
            if let data = chapter.text.data(using: .utf8) {
                try data.write(to: url, options: .atomic)
            } else {
                try chapter.text.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    nonisolated private static func loadChapterText(for item: EbookLibraryItem, chapterID: Int) -> String? {
        let url = chapterURL(for: item, chapterID: chapterID)
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    nonisolated private static func scanChapters(
        into state: inout TXTBookParsingState,
        existingCount: Int,
        targetCount: Int
    ) -> [TXTBookChapter] {
        let source = state.text as NSString
        let contentRange = state.contentRange
        let contentEnd = NSMaxRange(contentRange)
        var chapters: [TXTBookChapter] = []
        var nextLocation = state.nextLocation
        var pendingHeading = state.pendingHeading
        var didHandleLeadingContent = state.didHandleLeadingContent

        func appendChapter(title: String, start: Int, end: Int) {
            guard end > start else { return }
            let slice = source.substring(with: NSRange(location: start, length: end - start))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !slice.isEmpty else { return }
            chapters.append(
                TXTBookChapter(
                    id: existingCount + chapters.count,
                    title: title,
                    text: slice
                )
            )
        }

        let remainingRange = NSRange(location: nextLocation, length: max(contentEnd - nextLocation, 0))
        if remainingRange.length > 0 {
            source.enumerateSubstrings(in: remainingRange, options: [.byLines, .substringNotRequired]) { _, substringRange, enclosingRange, stop in
                let line = source.substring(with: substringRange)
                let heading = normalizedHeading(from: line)

                if isChapterHeading(heading) {
                    if let pending = pendingHeading {
                        appendChapter(title: pending.title, start: pending.start, end: substringRange.location)
                        if existingCount + chapters.count >= targetCount {
                            pendingHeading = TXTBookPendingHeading(title: heading, start: substringRange.location)
                            didHandleLeadingContent = true
                            nextLocation = NSMaxRange(enclosingRange)
                            stop.pointee = true
                            return
                        }
                    } else if !didHandleLeadingContent && substringRange.location > contentRange.location {
                        let leadingText = source.substring(with: NSRange(location: contentRange.location, length: substringRange.location - contentRange.location))
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if shouldKeepLeadingContent(leadingText) {
                            chapters.append(
                                TXTBookChapter(
                                    id: existingCount + chapters.count,
                                    title: AppLocalizer.localized("正文"),
                                    text: leadingText
                                )
                            )
                        }
                    }

                    didHandleLeadingContent = true
                    pendingHeading = TXTBookPendingHeading(title: heading, start: substringRange.location)
                }

                nextLocation = NSMaxRange(enclosingRange)
            }
        }

        if nextLocation >= contentEnd {
            if let pending = pendingHeading {
                appendChapter(title: pending.title, start: pending.start, end: contentEnd)
                pendingHeading = nil
            } else if existingCount + chapters.count == 0 && !didHandleLeadingContent {
                chapters.append(
                    TXTBookChapter(
                        id: existingCount,
                        title: AppLocalizer.localized("正文"),
                        text: source.substring(with: contentRange)
                    )
                )
            }
        }

        state.nextLocation = nextLocation
        state.pendingHeading = pendingHeading
        state.didHandleLeadingContent = didHandleLeadingContent

        return chapters
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
    case incompleteParsing

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            return AppLocalizer.localized("无法读取该 TXT 文件")
        case .emptyContent:
            return AppLocalizer.localized("当前 TXT 文件内容为空")
        case .incompleteParsing:
            return AppLocalizer.localized("电子书解析未完成，请重试")
        }
    }
}

private enum TXTReaderOverlayPanel {
    case tableOfContents
    case appearance
}

private enum TXTChapterBoundaryDirection {
    case previous
    case next
}

private struct TXTReaderWindow: Equatable {
    let startChapterIndex: Int
    let chapters: [TXTBookChapter]
    let chapterRanges: [TXTReaderWindowChapterRange]

    var endChapterIndex: Int {
        startChapterIndex + chapters.count - 1
    }

    func contains(chapterIndex: Int) -> Bool {
        chapterIndex >= startChapterIndex && chapterIndex <= endChapterIndex
    }
}

private struct TXTReaderWindowChapterRange: Equatable {
    let chapterIndex: Int
    let chapterID: Int
    let title: String
    let displayRange: NSRange
    let bodyRange: NSRange
}

private func normalizedTXTChapterHeading(_ text: String) -> String {
    text
        .replacingOccurrences(of: "\u{3000}", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func deduplicatedTXTChapterBody(text: String, title: String) -> String {
    let normalizedTitle = normalizedTXTChapterHeading(title)
    guard !normalizedTitle.isEmpty else { return text }

    let normalizedBody = text.replacingOccurrences(of: "\r\n", with: "\n")
    let lines = normalizedBody.components(separatedBy: "\n")
    guard let firstNonEmptyLine = lines.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
        return text
    }

    guard normalizedTXTChapterHeading(firstNonEmptyLine) == normalizedTitle else {
        return text
    }

    var didRemoveHeading = false
    let filteredLines = lines.filter { line in
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if !didRemoveHeading, !trimmed.isEmpty, normalizedTXTChapterHeading(line) == normalizedTitle {
            didRemoveHeading = true
            return false
        }
        return true
    }

    let stripped = filteredLines.joined(separator: "\n").trimmingCharacters(in: .newlines)
    return stripped.isEmpty ? text : stripped
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

    var loadingTextColor: UIColor {
        switch self {
        case .dark:
            return UIColor(hex: "#F5F7FA").withAlphaComponent(0.9)
        case .light:
            return UIColor(hex: "#1F2937").withAlphaComponent(0.82)
        case .mint:
            return UIColor(hex: "#23352B").withAlphaComponent(0.82)
        case .cream:
            return UIColor(hex: "#4A4032").withAlphaComponent(0.82)
        }
    }

    var loadingIndicatorColor: UIColor {
        switch self {
        case .dark:
            return UIColor(hex: "#F5F7FA").withAlphaComponent(0.88)
        case .light:
            return UIColor(hex: "#4B5563")
        case .mint:
            return UIColor(hex: "#2F6B4F")
        case .cream:
            return UIColor(hex: "#7A5B2E")
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
    @State private var scrollRequest: TXTReaderScrollRequest?
    @State private var lastSavedProgress = TXTReaderProgress(chapterIndex: 0, chapterProgress: 0)
    @State private var loadTask: Task<Void, Never>?
    @State private var prewarmTask: Task<Void, Never>?
    @State private var readerWindow: TXTReaderWindow?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(uiColor: readerTheme.backgroundColor).ignoresSafeArea()

                Group {
                    if let book {
                        readerContent(for: book)
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
            loadTask?.cancel()
            prewarmTask?.cancel()
            loadTask = nil
            prewarmTask = nil
            saveProgress(force: true)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color(uiColor: readerTheme.loadingIndicatorColor))

            Text(AppLocalizer.localized("正在处理电子书..."))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(uiColor: readerTheme.loadingTextColor))

            Button {
                cancelLoadingAndDismiss()
            } label: {
                Text(AppLocalizer.localized("取消"))
                    .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(uiColor: readerTheme.loadingTextColor))
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(uiColor: readerTheme.textColor).opacity(readerTheme == .dark ? 0.12 : 0.08))
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
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

    @ViewBuilder
    private func readerContent(for book: TXTBookContent) -> some View {
        let window = readerWindow ?? makeReaderWindow(from: book, centerIndex: currentChapterIndex)
        TXTReaderTextView(
            cacheKey: "\(item.id.uuidString.lowercased())-window-\(window.startChapterIndex)-\(window.endChapterIndex)",
            window: window,
            styleSettings: styleSettings,
            theme: readerTheme,
            scrollRequest: scrollRequest,
            onTap: toggleChrome,
            onReadingPositionChange: handleReadingPositionChange,
            onBoundaryCross: handleChapterBoundaryCross
        )
        .id("txt-\(item.id.uuidString)-\(window.startChapterIndex)-\(window.endChapterIndex)")
        .ignoresSafeArea()
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
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
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
                                    .foregroundColor(index == currentChapterIndex ? AppColors.accentBlue : Color.white.opacity(0.84))
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                            .buttonStyle(.plain)
                            .id(chapter.id)

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
            .onAppear {
                scrollTOCToCurrentChapter(with: proxy)
            }
            .onChange(of: currentChapterIndex) { _, _ in
                scrollTOCToCurrentChapter(with: proxy)
                scheduleNearbyChapterPrewarm()
            }
            .onChange(of: styleSettings) { _, _ in
                scheduleNearbyChapterPrewarm()
            }
        }
        .frame(maxHeight: 360)
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
        loadTask?.cancel()
        loadError = nil
        activePanel = nil

        let fileURL = EbookLibraryService.fileURL(for: item)
        let savedProgress = EbookReaderPreferencesStore.loadTXTProgress(for: item.id) ?? TXTReaderProgress(chapterIndex: 0, chapterProgress: 0)
        let requestedChapter = max(savedProgress.chapterIndex, 0)
        let safeProgress = min(max(savedProgress.chapterProgress, 0), 1)

        isLoading = true
        book = nil

        loadTask = Task {
            do {
                let loadedBook = try await Task.detached(priority: .userInitiated) {
                    try TXTReaderService.loadBook(
                        from: fileURL,
                        item: item,
                        preferredChapterIndex: requestedChapter,
                        preloadRadius: 3
                    )
                }.value
                guard !Task.isCancelled else { return }
                let safeChapter = min(requestedChapter, max(loadedBook.chapters.count - 1, 0))

                await MainActor.run {
                    book = loadedBook
                    currentChapterIndex = safeChapter
                    chapterScrollProgress = safeProgress
                    readerWindow = makeReaderWindow(from: loadedBook, centerIndex: safeChapter)
                    scrollRequest = TXTReaderScrollRequest(chapterIndex: safeChapter, chapterProgress: safeProgress)
                    lastSavedProgress = TXTReaderProgress(chapterIndex: safeChapter, chapterProgress: safeProgress)
                    isLoading = false
                    chromeVisible = false
                    loadTask = nil
                    scheduleNearbyChapterPrewarm()
                }
            } catch is CancellationError {
                await MainActor.run {
                    loadTask = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    loadError = error.localizedDescription
                    isLoading = false
                    chromeVisible = true
                    loadTask = nil
                }
            }
        }
    }

    private func cancelLoadingAndDismiss() {
        loadTask?.cancel()
        loadTask = nil
        dismiss()
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

    private func handleReadingPositionChange(_ position: TXTVisibleReadingPosition) {
        if currentChapterIndex != position.chapterIndex {
            currentChapterIndex = position.chapterIndex
            if
                let currentBook = book,
                shouldShiftReaderWindow(
                    currentWindow: readerWindow,
                    toKeepVisibleChapterIndex: position.chapterIndex
                )
            {
                let shiftedWindow = makeReaderWindow(from: currentBook, centerIndex: position.chapterIndex)
                if readerWindow != shiftedWindow {
                    readerWindow = shiftedWindow
                    scrollRequest = TXTReaderScrollRequest(
                        chapterIndex: position.chapterIndex,
                        chapterProgress: position.chapterProgress
                    )
                }
            }
            scheduleNearbyChapterPrewarm()
        }
        chapterScrollProgress = min(max(position.chapterProgress, 0), 1)
        saveProgress(force: false)
    }

    private func handleChapterBoundaryCross(_ direction: TXTChapterBoundaryDirection) {
        _ = direction
    }

    private func jumpToChapter(_ index: Int) {
        transitionToChapter(index, progress: 0, hideChrome: true)
    }

    private func transitionToChapter(_ index: Int, progress: Double, hideChrome: Bool) {
        guard let currentBook = book, currentBook.chapters.indices.contains(index) else { return }

        let normalizedProgress = min(max(progress, 0), 1)
        let targetChapter = currentBook.chapters[index]
        let cacheKey = "\(item.id.uuidString.lowercased())-\(targetChapter.id)"
        let targetReady =
            !targetChapter.text.isEmpty &&
            TXTAttributedTextCache.shared.hasValue(
                for: cacheKey,
                textLength: targetChapter.text.utf16.count,
                styleSettings: styleSettings,
                theme: readerTheme
            )

        if targetReady {
            currentChapterIndex = index
            chapterScrollProgress = normalizedProgress
            readerWindow = makeReaderWindow(from: currentBook, centerIndex: index)
            scrollRequest = TXTReaderScrollRequest(chapterIndex: index, chapterProgress: normalizedProgress)
            if hideChrome {
                activePanel = nil
                chromeVisible = false
            }
            saveProgress(force: true)
            scheduleNearbyChapterPrewarm()
            return
        }

        prewarmTask?.cancel()
        let currentBookSnapshot = currentBook
        let targetIndex = index
        let targetTheme = readerTheme
        let targetStyle = styleSettings
        let shouldHideChrome = hideChrome

        prewarmTask = Task {
            let hydratedBook = await Task.detached(priority: .userInitiated) {
                TXTReaderService.hydrateChapterWindow(
                    in: currentBookSnapshot,
                    for: item,
                    centerIndex: targetIndex,
                    radius: 3
                )
            }.value
            guard !Task.isCancelled else { return }

            let lowerBound = max(targetIndex - 3, 0)
            let upperBound = min(targetIndex + 3, hydratedBook.chapters.count - 1)
            let chapters = Array(hydratedBook.chapters[lowerBound...upperBound]).filter { !$0.text.isEmpty }
            let baseCacheKey = item.id.uuidString.lowercased()
            TXTAttributedTextCache.shared.prewarm(
                chapters: chapters,
                baseCacheKey: baseCacheKey,
                styleSettings: targetStyle,
                theme: targetTheme
            )
            guard !Task.isCancelled else { return }

            await MainActor.run {
                book = hydratedBook
                currentChapterIndex = targetIndex
                chapterScrollProgress = normalizedProgress
                readerWindow = makeReaderWindow(from: hydratedBook, centerIndex: targetIndex)
                scrollRequest = TXTReaderScrollRequest(chapterIndex: targetIndex, chapterProgress: normalizedProgress)
                if shouldHideChrome {
                    activePanel = nil
                    chromeVisible = false
                }
                saveProgress(force: true)
            }
        }
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

    private func scrollTOCToCurrentChapter(with proxy: ScrollViewProxy) {
        guard let book, book.chapters.indices.contains(currentChapterIndex) else { return }
        let chapterID = book.chapters[currentChapterIndex].id
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.18)) {
                proxy.scrollTo(chapterID, anchor: .center)
            }
        }
    }

    private func scheduleNearbyChapterPrewarm() {
        guard let currentBook = book, !currentBook.chapters.isEmpty else { return }
        let centerIndex = currentChapterIndex
        let baseCacheKey = item.id.uuidString.lowercased()
        let style = styleSettings
        let theme = readerTheme

        prewarmTask?.cancel()
        prewarmTask = Task {
            let hydratedBook = await Task.detached(priority: .utility) {
                TXTReaderService.hydrateChapterWindow(
                    in: currentBook,
                    for: item,
                    centerIndex: centerIndex,
                    radius: 3
                )
            }.value
            guard !Task.isCancelled else { return }

            await MainActor.run {
                if
                    currentChapterIndex == centerIndex,
                    book?.title == hydratedBook.title,
                    book?.chapters.count == hydratedBook.chapters.count
                {
                    book = hydratedBook
                }
            }

            let lowerBound = max(centerIndex - 3, 0)
            let upperBound = min(centerIndex + 3, hydratedBook.chapters.count - 1)
            let chapters = Array(hydratedBook.chapters[lowerBound...upperBound]).filter { !$0.text.isEmpty }
            TXTAttributedTextCache.shared.prewarm(
                chapters: chapters,
                baseCacheKey: baseCacheKey,
                styleSettings: style,
                theme: theme
            )
        }
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

    private func shouldShiftReaderWindow(
        currentWindow: TXTReaderWindow?,
        toKeepVisibleChapterIndex chapterIndex: Int
    ) -> Bool {
        guard let currentWindow, !currentWindow.chapters.isEmpty else {
            return true
        }

        guard currentWindow.contains(chapterIndex: chapterIndex) else {
            return true
        }

        let localIndex = chapterIndex - currentWindow.startChapterIndex
        let lastVisibleIndex = currentWindow.chapters.count - 1
        return localIndex <= 1 || localIndex >= max(lastVisibleIndex - 1, 0)
    }

    private func makeReaderWindow(from book: TXTBookContent, centerIndex: Int) -> TXTReaderWindow {
        guard !book.chapters.isEmpty else {
            return TXTReaderWindow(startChapterIndex: 0, chapters: [], chapterRanges: [])
        }

        let lowerBound = max(centerIndex - 5, 0)
        let upperBound = min(centerIndex + 5, book.chapters.count - 1)
        var chapters = Array(book.chapters[lowerBound...upperBound]).filter { !$0.text.isEmpty }
        if chapters.isEmpty, book.chapters.indices.contains(centerIndex) {
            chapters = [book.chapters[centerIndex]]
        }

        var location = 0
        var ranges: [TXTReaderWindowChapterRange] = []

        for (offset, chapter) in chapters.enumerated() {
            let heading = chapter.title + "\n\n"
            let separator = offset == chapters.count - 1 ? "" : "\n\n\n"
            let headingLength = (heading as NSString).length
            let displayBody = deduplicatedTXTChapterBody(text: chapter.text, title: chapter.title)
            let bodyLength = (displayBody as NSString).length
            let separatorLength = (separator as NSString).length
            let displayLength = headingLength + bodyLength + separatorLength

            ranges.append(
                TXTReaderWindowChapterRange(
                    chapterIndex: book.chapters.firstIndex(where: { $0.id == chapter.id }) ?? (lowerBound + offset),
                    chapterID: chapter.id,
                    title: chapter.title,
                    displayRange: NSRange(location: location, length: displayLength),
                    bodyRange: NSRange(location: location + headingLength, length: bodyLength)
                )
            )

            location += displayLength
        }

        return TXTReaderWindow(
            startChapterIndex: lowerBound,
            chapters: chapters,
            chapterRanges: ranges
        )
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
    let cacheKey: String
    let window: TXTReaderWindow
    let styleSettings: ReaderStyleSettings
    let theme: TXTReaderThemeOption
    let scrollRequest: TXTReaderScrollRequest?
    let onTap: () -> Void
    let onReadingPositionChange: (TXTVisibleReadingPosition) -> Void
    let onBoundaryCross: (TXTChapterBoundaryDirection) -> Void

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView(usingTextLayoutManager: false)
        textView.delegate = context.coordinator
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = true
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
        context.coordinator.onReadingPositionChange = onReadingPositionChange
        context.coordinator.onBoundaryCross = onBoundaryCross
        context.coordinator.configure(
            textView,
            cacheKey: cacheKey,
            window: window,
            styleSettings: styleSettings,
            theme: theme,
            scrollRequest: scrollRequest
        )
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.onReadingPositionChange = onReadingPositionChange
        context.coordinator.onBoundaryCross = onBoundaryCross
        context.coordinator.configure(
            uiView,
            cacheKey: cacheKey,
            window: window,
            styleSettings: styleSettings,
            theme: theme,
            scrollRequest: scrollRequest
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onTap: onTap,
            onReadingPositionChange: onReadingPositionChange,
            onBoundaryCross: onBoundaryCross
        )
    }

    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var onTap: () -> Void
        var onReadingPositionChange: (TXTVisibleReadingPosition) -> Void
        var onBoundaryCross: (TXTChapterBoundaryDirection) -> Void
        private var lastWindow: TXTReaderWindow?
        private var lastStyle = ReaderStyleSettings.default
        private var lastTheme: TXTReaderThemeOption = .dark
        private var appliedScrollRequest: TXTReaderScrollRequest?
        private var isApplyingProgrammaticScroll = false

        init(
            onTap: @escaping () -> Void,
            onReadingPositionChange: @escaping (TXTVisibleReadingPosition) -> Void,
            onBoundaryCross: @escaping (TXTChapterBoundaryDirection) -> Void
        ) {
            self.onTap = onTap
            self.onReadingPositionChange = onReadingPositionChange
            self.onBoundaryCross = onBoundaryCross
        }

        func configure(
            _ textView: UITextView,
            cacheKey: String,
            window: TXTReaderWindow,
            styleSettings: ReaderStyleSettings,
            theme: TXTReaderThemeOption,
            scrollRequest: TXTReaderScrollRequest?
        ) {
            let textChanged = lastWindow != window
            let styleChanged = lastStyle != styleSettings || lastTheme != theme

            if textChanged || styleChanged {
                textView.attributedText = attributedText(
                    for: window,
                    cacheKey: cacheKey,
                    styleSettings: styleSettings,
                    theme: theme
                )
                textView.backgroundColor = theme.backgroundColor
                textView.tintColor = UIColor(AppColors.accentBlue)
                lastWindow = window
                lastStyle = styleSettings
                lastTheme = theme
                appliedScrollRequest = nil

                if let scrollRequest {
                    apply(scrollRequest: scrollRequest, to: textView)
                }
            } else if let scrollRequest, appliedScrollRequest != scrollRequest {
                apply(scrollRequest: scrollRequest, to: textView)
            }
        }

        private func applyReadingPositionIfNeeded(_ textView: UITextView) {
            let position = readingPosition(for: textView)
            DispatchQueue.main.async {
                self.onReadingPositionChange(position)
            }
        }

        private func attributedText(
            for window: TXTReaderWindow,
            cacheKey: String,
            styleSettings: ReaderStyleSettings,
            theme: TXTReaderThemeOption
        ) -> NSAttributedString {
            let windowTextLength = window.chapterRanges.last.map { NSMaxRange($0.displayRange) } ?? 0
            if let cached = TXTAttributedTextCache.shared.value(
                for: cacheKey,
                textLength: windowTextLength,
                styleSettings: styleSettings,
                theme: theme
            ) {
                return cached
            }

            let attributed = NSMutableAttributedString()
            let titleFontSize = 20 * styleSettings.fontSize

            for (offset, chapter) in window.chapters.enumerated() {
                let titleParagraph = NSMutableParagraphStyle()
                titleParagraph.lineBreakMode = .byWordWrapping
                titleParagraph.alignment = .natural
                titleParagraph.lineSpacing = max(0, (titleFontSize * styleSettings.lineHeight) - titleFontSize)

                attributed.append(
                    NSAttributedString(
                        string: chapter.title + "\n\n",
                        attributes: [
                            .font: UIFont.systemFont(ofSize: titleFontSize, weight: .semibold),
                            .foregroundColor: theme.textColor,
                            .kern: styleSettings.letterSpacing * 4,
                            .paragraphStyle: titleParagraph
                        ]
                    )
                )

                let chapterCacheKey = "\(cacheKey)-chapter-\(chapter.id)"
                let displayBody = deduplicatedTXTChapterBody(text: chapter.text, title: chapter.title)
                let bodyLength = displayBody.utf16.count
                let chapterAttributed =
                    TXTAttributedTextCache.shared.value(
                        for: chapterCacheKey,
                        textLength: bodyLength,
                        styleSettings: styleSettings,
                        theme: theme
                    ) ?? {
                        let generated = makeChapterAttributedText(
                            for: displayBody,
                            styleSettings: styleSettings,
                            theme: theme
                        )
                        TXTAttributedTextCache.shared.store(
                            generated,
                            for: chapterCacheKey,
                            textLength: bodyLength,
                            styleSettings: styleSettings,
                            theme: theme
                        )
                        return generated
                    }()

                attributed.append(chapterAttributed)

                if offset != window.chapters.count - 1 {
                    attributed.append(NSAttributedString(string: "\n\n\n"))
                }
            }

            TXTAttributedTextCache.shared.store(
                attributed,
                for: cacheKey,
                textLength: windowTextLength,
                styleSettings: styleSettings,
                theme: theme
            )
            return attributed
        }

        private func makeChapterAttributedText(
            for text: String,
            styleSettings: ReaderStyleSettings,
            theme: TXTReaderThemeOption
        ) -> NSAttributedString {
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

        private func apply(scrollRequest: TXTReaderScrollRequest, to textView: UITextView) {
            appliedScrollRequest = scrollRequest
            DispatchQueue.main.async {
                self.scroll(textView, to: scrollRequest)
            }
        }

        private func scroll(_ textView: UITextView, to request: TXTReaderScrollRequest) {
            guard let window = lastWindow else { return }
            guard let range = window.chapterRanges.first(where: { $0.chapterIndex == request.chapterIndex }) else { return }
            let progress = min(max(request.chapterProgress, 0), 1)
            let bodyLength = max(range.bodyRange.length - 1, 0)
            let boundedCharacter = range.bodyRange.location + min(max(Int((Double(bodyLength) * progress).rounded()), 0), bodyLength)

            textView.layoutManager.ensureLayout(for: textView.textContainer)
            let glyphIndex = textView.layoutManager.glyphIndexForCharacter(at: boundedCharacter)
            let glyphRect = textView.layoutManager.boundingRect(
                forGlyphRange: NSRange(location: glyphIndex, length: 1),
                in: textView.textContainer
            )

            let visibleHeight = textView.bounds.height - textView.adjustedContentInset.top - textView.adjustedContentInset.bottom
            let minOffsetY = -textView.adjustedContentInset.top
            let maxOffsetY = max(textView.contentSize.height - visibleHeight, minOffsetY)
            let targetOffsetY = min(
                max(glyphRect.minY - textView.textContainerInset.top - 12, minOffsetY),
                maxOffsetY
            )
            isApplyingProgrammaticScroll = true
            textView.setContentOffset(CGPoint(x: 0, y: targetOffsetY), animated: false)
            DispatchQueue.main.async {
                self.isApplyingProgrammaticScroll = false
                self.onReadingPositionChange(self.readingPosition(for: textView))
            }
        }

        private func readingPosition(for textView: UITextView) -> TXTVisibleReadingPosition {
            guard textView.attributedText.length > 0, let window = lastWindow else {
                return TXTVisibleReadingPosition(chapterIndex: 0, chapterProgress: 0)
            }

            textView.layoutManager.ensureLayout(for: textView.textContainer)

            let probePoint = CGPoint(
                x: textView.textContainerInset.left + 6,
                y: textView.contentOffset.y + textView.adjustedContentInset.top + 36
            )
            let containerPoint = CGPoint(
                x: probePoint.x - textView.textContainerInset.left,
                y: probePoint.y - textView.textContainerInset.top
            )
            let glyphIndex = textView.layoutManager.glyphIndex(for: containerPoint, in: textView.textContainer)
            let characterIndex = min(
                max(textView.layoutManager.characterIndexForGlyph(at: glyphIndex), 0),
                max(textView.attributedText.length - 1, 0)
            )

            guard let currentRange = window.chapterRanges.first(where: { NSLocationInRange(characterIndex, $0.displayRange) }) ?? window.chapterRanges.last else {
                return TXTVisibleReadingPosition(chapterIndex: 0, chapterProgress: 0)
            }

            let relative = characterIndex - currentRange.bodyRange.location
            let progress = currentRange.bodyRange.length > 1
                ? min(max(Double(relative) / Double(max(currentRange.bodyRange.length - 1, 1)), 0), 1)
                : 0

            return TXTVisibleReadingPosition(
                chapterIndex: currentRange.chapterIndex,
                chapterProgress: progress
            )
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let textView = scrollView as? UITextView else { return }
            guard !isApplyingProgrammaticScroll else { return }
            let position = readingPosition(for: textView)
            DispatchQueue.main.async {
                self.onReadingPositionChange(position)
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

private final class TXTAttributedTextCache {
    static let shared = TXTAttributedTextCache()

    private let cache = NSCache<NSString, NSAttributedString>()

    private init() {
        cache.countLimit = 12
    }

    func value(
        for cacheKey: String,
        textLength: Int,
        styleSettings: ReaderStyleSettings,
        theme: TXTReaderThemeOption
    ) -> NSAttributedString? {
        cache.object(forKey: key(for: cacheKey, textLength: textLength, styleSettings: styleSettings, theme: theme))
    }

    func hasValue(
        for cacheKey: String,
        textLength: Int,
        styleSettings: ReaderStyleSettings,
        theme: TXTReaderThemeOption
    ) -> Bool {
        value(for: cacheKey, textLength: textLength, styleSettings: styleSettings, theme: theme) != nil
    }

    func store(
        _ attributedText: NSAttributedString,
        for cacheKey: String,
        textLength: Int,
        styleSettings: ReaderStyleSettings,
        theme: TXTReaderThemeOption
    ) {
        cache.setObject(
            attributedText,
            forKey: key(for: cacheKey, textLength: textLength, styleSettings: styleSettings, theme: theme)
        )
    }

    func prewarm(
        chapters: [TXTBookChapter],
        baseCacheKey: String,
        styleSettings: ReaderStyleSettings,
        theme: TXTReaderThemeOption
    ) {
        for chapter in chapters {
            let cacheKey = "\(baseCacheKey)-\(chapter.id)"
            let displayBody = deduplicatedTXTChapterBody(text: chapter.text, title: chapter.title)
            let textLength = displayBody.utf16.count
            if value(for: cacheKey, textLength: textLength, styleSettings: styleSettings, theme: theme) != nil {
                continue
            }
            let attributedText = makeAttributedText(
                for: displayBody,
                styleSettings: styleSettings,
                theme: theme
            )
            store(
                attributedText,
                for: cacheKey,
                textLength: textLength,
                styleSettings: styleSettings,
                theme: theme
            )
        }
    }

    private func key(
        for cacheKey: String,
        textLength: Int,
        styleSettings: ReaderStyleSettings,
        theme: TXTReaderThemeOption
    ) -> NSString {
        "\(cacheKey)|\(textLength)|\(styleSettings.fontSize)|\(styleSettings.letterSpacing)|\(styleSettings.lineHeight)|\(styleSettings.themeRawValue)|\(theme.rawValue)" as NSString
    }

    private func makeAttributedText(
        for text: String,
        styleSettings: ReaderStyleSettings,
        theme: TXTReaderThemeOption
    ) -> NSAttributedString {
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
}

private struct TXTReaderScrollRequest: Equatable {
    let chapterIndex: Int
    let chapterProgress: Double
    let token: UUID

    init(chapterIndex: Int, chapterProgress: Double, token: UUID = UUID()) {
        self.chapterIndex = chapterIndex
        self.chapterProgress = chapterProgress
        self.token = token
    }
}

private struct TXTVisibleReadingPosition: Equatable {
    let chapterIndex: Int
    let chapterProgress: Double
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
