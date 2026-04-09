import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct MediaCompressorView: View {
    @StateObject private var viewModel = MediaCompressorViewModel()
    @State private var isFileImporterPresented = false
    @State private var selectedLibraryItems: [PhotosPickerItem] = []
    @State private var isFileExporterPresented = false
    @State private var isSaveActionSheetPresented = false
    @State private var saveMessage: String?
    @State private var showSaveAlert = false
    @State private var selectedSaveItemIDs: Set<UUID> = []

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
        .navigationTitle("数据压缩")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            if !viewModel.items.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.clearAll() }) {
                        Text("清空")
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
                saveMessage = "已成功保存至文件：\n\(url.lastPathComponent)"
                showSaveAlert = true
            case .failure(let error):
                saveMessage = "保存失败：\n\(error.localizedDescription)"
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
                shareableURLs: viewModel.shareableURLs(for: selectedSaveItemIDs),
                onSaveToAlbum: {
                    isSaveActionSheetPresented = false
                    Task {
                        let result = await viewModel.saveToPhotoLibrary(selectedItemIDs: selectedSaveItemIDs)
                        switch result {
                        case .success(let summary):
                            if summary.skippedCount > 0 {
                                saveMessage = "成功保存 \(summary.savedCount) 项到相册，已跳过 \(summary.skippedCount) 项不支持的音频或视频格式"
                            } else {
                                saveMessage = "成功保存 \(summary.savedCount) 项到相册"
                            }
                            showSaveAlert = true
                        case .failure(let error):
                            saveMessage = "保存到相册失败：\n\(error.localizedDescription)"
                            showSaveAlert = true
                        }
                    }
                },
                onSaveToFile: {
                    isSaveActionSheetPresented = false
                    viewModel.prepareExportDocument(for: selectedSaveItemIDs)
                    isFileExporterPresented = viewModel.exportDocument != nil
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
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("数据压缩")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(AppColors.textPrimary)

                    Text("图片、视频、音频混合导入，同一个队列里批量压缩，不改变原始格式。")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppColors.accentTeal.opacity(0.18))
                        .frame(width: 58, height: 58)

                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(AppColors.accentTeal)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("压缩强度")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColors.textSecondary)

                Picker("压缩强度", selection: $viewModel.compressionLevel) {
                    ForEach(MediaCompressionLevel.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(viewModel.isCompressing)
            }

            Text("压缩只会优化当前格式内部的体积，不会修改原始扩展名。部分 PNG、WAV、FLAC 的压缩空间可能有限。")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

        }
        .padding(20)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var statsCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                StatItemView(title: "总数", count: viewModel.totalCount, color: AppColors.textPrimary)
                StatItemView(title: "待压缩", count: viewModel.pendingCount, color: AppColors.accentBlue)
                StatItemView(title: "成功", count: viewModel.successCount, color: AppColors.accentGreen)
                StatItemView(title: "失败", count: viewModel.failedCount, color: AppColors.accentRed)
            }

            if viewModel.totalCount > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("整体进度")
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
            VStack(spacing: 16) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(AppColors.accentBlue)

                Text("导入媒体文件开始压缩")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(AppColors.textPrimary)

                Text("支持混合导入图片、视频和音频文件，压缩完成后可以直接分享结果。")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 12) {
                    PhotosPicker(selection: $selectedLibraryItems, matching: .any(of: [.images, .videos]), photoLibrary: .shared()) {
                        Text("从相册导入")
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
                        Text("从文件导入")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(AppColors.accentGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(!viewModel.canImport)
                }

                Text("相册支持图片和视频，音频请从文件导入。")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(22)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        } else {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("压缩队列")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Text("\(viewModel.totalCount) 项")
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
                    await viewModel.startCompression()
                }
            }) {
                HStack(spacing: 6) {
                    if viewModel.isCompressing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16, weight: .semibold))
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

                Text("正在导入媒体文件...")
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
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 16, weight: .semibold))
            Text("保存")
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
            Text("等待压缩")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.accentBlue)
        case .compressing:
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("压缩中")
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
                Text("压缩完成")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColors.accentGreen)

                if let compressedSizeText = item.compressedSizeText {
                    Text("压缩后 \(compressedSizeText) · 节省 \(item.savedPercentageText ?? "--")")
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
