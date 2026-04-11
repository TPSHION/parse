import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct MediaCompressorView: View {
    @Environment(RouterManager.self) private var router
    @Environment(TabRouter.self) private var tabRouter
    @Environment(PurchaseManager.self) private var purchaseManager
    @StateObject private var viewModel = MediaCompressorViewModel()
    @State private var isFileImporterPresented = false
    @State private var selectedLibraryItems: [PhotosPickerItem] = []
    @State private var isFileExporterPresented = false
    @State private var isSaveActionSheetPresented = false
    @State private var saveMessage: String?
    @State private var showSaveAlert = false
    @State private var selectedSaveItemIDs: Set<UUID> = []
    @State private var isShowingPaywall = false

    var body: some View {
        let isBusy = viewModel.isCompressing || viewModel.isImporting

        ZStack {
            LinearGradient(
                colors: [AppColors.background, Color(hex: "#050B14")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerCard
                    statsCard
                    queueSection
                }
                .padding(20)
                .padding(.bottom, 32)
            }
            .allowsHitTesting(!isBusy)

            if viewModel.isImporting {
                importingOverlay
            }
        }
        .navigationTitle(AppLocalizer.localized("数据压缩"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            if !viewModel.items.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.clearAll() }) {
                        Text(AppLocalizer.localized("清空"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .disabled(viewModel.isCompressing)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if !viewModel.items.isEmpty {
                bottomActionPanel
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.image, .movie, .audio],
            allowsMultipleSelection: true,
            onCompletion: viewModel.handleFileImportResult
        )
        .fileExporter(
            isPresented: $isFileExporterPresented,
            document: viewModel.exportDocument,
            contentType: .folder,
            defaultFilename: "CompressedMedia"
        ) { result in
            switch result {
            case .success(let url):
                saveMessage = AppLocalizer.formatted("已成功保存至文件：\n%@", url.lastPathComponent)
                showSaveAlert = true
            case .failure(let error):
                saveMessage = AppLocalizer.formatted("保存失败：\n%@", error.localizedDescription)
                showSaveAlert = true
            }
        }
        .onChange(of: selectedLibraryItems) { _, newItems in
            viewModel.processPhotoLibrarySelections(newItems)
            selectedLibraryItems.removeAll()
        }
        .sheet(isPresented: $isSaveActionSheetPresented) {
            MediaSaveSelectionSheet(
                items: viewModel.successfulItems,
                selectedItemIDs: $selectedSaveItemIDs,
                onSaveToAlbum: {
                    isSaveActionSheetPresented = false
                    Task {
                        let result = await viewModel.saveToPhotoLibrary(selectedItemIDs: selectedSaveItemIDs)
                        switch result {
                        case .success(let summary):
                            if summary.skippedCount > 0 {
                                saveMessage = AppLocalizer.formatted("成功保存 %lld 项到相册，已跳过 %lld 项不支持的音频或视频格式", summary.savedCount, summary.skippedCount)
                            } else {
                                saveMessage = AppLocalizer.formatted("成功保存 %lld 项到相册", summary.savedCount)
                            }
                            showSaveAlert = true
                        case .failure(let error):
                            saveMessage = AppLocalizer.formatted("保存到相册失败：\n%@", error.localizedDescription)
                            showSaveAlert = true
                        }
                    }
                },
                onSaveToFile: {
                    isSaveActionSheetPresented = false
                    viewModel.prepareExportDocument(for: selectedSaveItemIDs)
                    isFileExporterPresented = viewModel.exportDocument != nil
                },
                onOpenTransferGuide: {
                    isSaveActionSheetPresented = false
                    router.popToRoot()
                    tabRouter.select(.transfer)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppColors.background)
        }
        .alert("保存结果", isPresented: $showSaveAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            if let message = saveMessage {
                Text(message)
            }
        }
        .fullScreenCover(isPresented: $isShowingPaywall) {
            TrialPaywallView(allowsDismissal: true)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppLocalizer.localized("数据压缩"))
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(AppColors.textPrimary)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(AppLocalizer.localized("压缩强度"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColors.textSecondary)

                Picker(AppLocalizer.localized("压缩强度"), selection: $viewModel.compressionLevel) {
                    ForEach(MediaCompressionLevel.allCases) { level in
                        Text(level.localizedTitle).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(viewModel.isCompressing)
            }
        }
        .padding(20)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var statsCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                StatItemView(title: AppLocalizer.localized("总数"), count: viewModel.totalCount, color: AppColors.textPrimary)
                StatItemView(title: AppLocalizer.localized("待压缩"), count: viewModel.pendingCount, color: AppColors.accentBlue)
                StatItemView(title: AppLocalizer.localized("成功"), count: viewModel.successCount, color: AppColors.accentGreen)
                StatItemView(title: AppLocalizer.localized("失败"), count: viewModel.failedCount, color: AppColors.accentRed)
            }

            if viewModel.totalCount > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(AppLocalizer.localized("整体进度"))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Text(viewModel.overallProgress.progressText)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(AppColors.secondaryBackground.opacity(0.4))

                            Capsule()
                                .fill(viewModel.isCompressing ? AppColors.accentOrange : AppColors.accentGreen)
                                .frame(width: geometry.size.width * max(min(viewModel.overallProgress, 1.0), 0.0))
                        }
                    }
                    .frame(height: 10)
                }
            }
        }
        .padding(18)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private var queueSection: some View {
        if viewModel.items.isEmpty {
            VStack(spacing: 14) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(AppColors.accentBlue)

                Text(AppLocalizer.localized("导入媒体文件开始压缩"))
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(AppColors.textPrimary)

                VStack(spacing: 12) {
                    PhotosPicker(selection: $selectedLibraryItems, matching: .any(of: [.images, .videos]), photoLibrary: .shared()) {
                        Text(AppLocalizer.localized("从相册导入"))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(AppColors.accentBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canImport)

                    Button {
                        isFileImporterPresented = true
                    } label: {
                        Text(AppLocalizer.localized("从文件导入"))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(AppColors.accentGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(!viewModel.canImport)
                }

                Text(AppLocalizer.localized("相册支持图片和视频，音频请从文件导入。"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(22)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        } else {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(AppLocalizer.localized("压缩队列"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Text(AppLocalizer.formatted("%lld 项", viewModel.totalCount))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColors.textSecondary)
                }

                VStack(spacing: 12) {
                    ForEach(viewModel.items) { item in
                        MediaCompressionItemRow(
                            item: item,
                            canDelete: !viewModel.isCompressing
                        ) {
                            viewModel.removeItem(id: item.id)
                        }
                    }
                }
            }
            .padding(.bottom, 96)
        }
    }

    @ViewBuilder
    private var bottomActionPanel: some View {
        let isBusy = viewModel.isCompressing || viewModel.isImporting
        let hasItems = !viewModel.items.isEmpty
        let hasSuccessItems = viewModel.hasSuccessItems

        HStack(spacing: 12) {
            Button(action: {
                isFileImporterPresented = true
            }) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 48, height: 48)
                    .background(AppColors.secondaryBackground.opacity(0.8))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isBusy)

            PhotosPicker(selection: $selectedLibraryItems, matching: .any(of: [.images, .videos]), photoLibrary: .shared()) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 48, height: 48)
                    .background(AppColors.secondaryBackground.opacity(0.8))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isBusy)

            Button(action: {
                Task {
                    if await purchaseManager.canUseCoreFeatures() {
                        await viewModel.startCompression()
                    } else {
                        isShowingPaywall = true
                    }
                }
            }) {
                HStack(spacing: 6) {
                    if viewModel.isCompressing {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(viewModel.isCompressing ? "压缩中" : "压缩")
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundColor(hasItems ? .white : AppColors.textSecondary.opacity(0.5))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(hasItems ? AppColors.accentOrange : AppColors.secondaryBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: hasItems ? AppColors.accentOrange.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canCompress)

            Button(action: {
                selectedSaveItemIDs = Set(viewModel.successfulItems.map(\.id))
                isSaveActionSheetPresented = true
            }) {
                saveButtonLabel(isEnabled: hasSuccessItems)
            }
            .buttonStyle(.plain)
            .disabled(!hasSuccessItems || isBusy)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(AppColors.cardBackground.opacity(0.85))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 16)
        .padding(.bottom, 0)
        .allowsHitTesting(!viewModel.isImporting)
    }

    private var importingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                        Text(AppLocalizer.localized("正在导入媒体文件..."))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(AppColors.cardBackground.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        }
        .zIndex(100)
    }

    private func saveButtonLabel(isEnabled: Bool) -> some View {
        HStack(spacing: 6) {
            Text(AppLocalizer.localized("保存"))
                .font(.system(size: 16, weight: .bold))
                .lineLimit(1)
        }
        .foregroundColor(isEnabled ? .white : AppColors.textSecondary.opacity(0.5))
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(isEnabled ? AppColors.accentGreen : AppColors.secondaryBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: isEnabled ? AppColors.accentGreen.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
    }
}

private struct MediaCompressionItemRow: View {
    let item: MediaCompressionItem
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            preview

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(item.filename)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text(item.typeLabel)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(typeColor.opacity(0.18))
                        .foregroundColor(typeColor)
                        .clipShape(Capsule())
                }

                Text(item.secondaryDescription)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)

                statusBlock
            }

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary.opacity(0.7))
            }
            .buttonStyle(.plain)
            .disabled(!canDelete)
            .opacity(canDelete ? 1.0 : 0.45)
        }
        .padding(14)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private var preview: some View {
        Group {
            if let previewImage = item.previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(typeColor.opacity(0.16))
                    .overlay {
                        Image(systemName: item.type.iconName)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(typeColor)
                    }
            }
        }
        .frame(width: 68, height: 68)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var statusBlock: some View {
        switch item.status {
        case .pending:
            Text(AppLocalizer.localized("等待压缩"))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.accentBlue)
        case .compressing:
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(AppLocalizer.localized("压缩中"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColors.accentOrange)
                    Spacer()
                    Text(item.compressionProgress.progressText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppColors.secondaryBackground.opacity(0.45))
                        Capsule()
                            .fill(AppColors.accentOrange)
                            .frame(width: geometry.size.width * max(min(item.compressionProgress, 1.0), 0.0))
                    }
                }
                .frame(height: 8)
            }
        case .success:
            VStack(alignment: .leading, spacing: 4) {
                Text(AppLocalizer.localized("压缩完成"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColors.accentGreen)

                if let compressedSizeText = item.compressedSizeText {
                    Text(AppLocalizer.formatted("压缩后 %@ · 节省 %@", compressedSizeText, item.savedPercentageText ?? "--"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        case .failed(let message):
            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppColors.accentRed)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var typeColor: Color {
        switch item.type {
        case .image:
            return AppColors.accentBlue
        case .video:
            return AppColors.accentGreen
        case .audio:
            return AppColors.accentOrange
        }
    }
}

#Preview {
    NavigationStack {
        MediaCompressorView()
    }
}
