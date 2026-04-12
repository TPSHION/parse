import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ImageTextRecognitionView: View {
    @Environment(RouterManager.self) private var router
    @Environment(TabRouter.self) private var tabRouter
    @Environment(PurchaseManager.self) private var purchaseManager
    @StateObject private var viewModel = ImageTextRecognitionViewModel()
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isFileImporterPresented = false
    @State private var isLinkImportPresented = false
    @State private var isExportSelectionPresented = false
    @State private var isFolderPickerPresented = false
    @State private var alertMessage: String?
    @State private var showAlert = false
    @State private var isShowingPaywall = false
    @State private var previewItem: RecognizedTextItem?
    @State private var remoteImportPreview: RemoteImageImportPreview?
    @State private var selectedExportItemIDs: Set<UUID> = []
    @State private var pendingExportAction: OCRPendingExportAction?

    var body: some View {
        let isBusy = viewModel.isRecognizing || viewModel.isImporting

        ZStack {
            AppColors.background.ignoresSafeArea()

            LinearGradient(
                colors: [AppColors.accentBlue.opacity(0.15), Color.clear],
                startPoint: .topLeading,
                endPoint: .center
            )
            .ignoresSafeArea()

            Group {
                if viewModel.items.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            summaryPanel
                            listSection
                        }
                        .padding(.top, 20)
                    }
                    .allowsHitTesting(!isBusy)
                }
            }

            if viewModel.isImporting {
                loadingOverlay(title: AppLocalizer.localized("正在导入图片..."))
            } else if viewModel.isRecognizing {
                loadingOverlay(title: AppLocalizer.localized("识别中"))
            }
        }
        .navigationTitle(AppLocalizer.localized("图片转文字"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            if !viewModel.items.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: viewModel.clearAll) {
                        Text(AppLocalizer.localized("清空"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .disabled(isBusy)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if !viewModel.items.isEmpty {
                bottomActionPanel
            }
        }
        .onChange(of: selectedPhotos) { _, newValue in
            viewModel.processPhotoSelections(newValue)
            selectedPhotos.removeAll()
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            viewModel.handleFileImportResult(result)
        }
        .sheet(isPresented: $isLinkImportPresented) {
            ImageLinkImportSheet(
                resolver: { urlText in
                    try await viewModel.prepareRemoteImageImport(from: urlText)
                },
                onResolved: { preview in
                    remoteImportPreview = preview
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppColors.background)
        }
        .alert(AppLocalizer.localized("图片转文字"), isPresented: $showAlert) {
            Button(AppLocalizer.localized("确定"), role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .fullScreenCover(isPresented: $isShowingPaywall) {
            TrialPaywallView(allowsDismissal: true)
        }
        .sheet(item: $previewItem) { item in
            OCRResultPreviewSheet(item: item)
        }
        .sheet(item: $remoteImportPreview) { preview in
            RemoteImageImportPreviewSheet(
                preview: preview,
                onImport: {
                    viewModel.confirmRemoteImageImport(preview)
                    remoteImportPreview = nil
                },
                onCancel: {
                    viewModel.discardRemoteImageImport(preview)
                    remoteImportPreview = nil
                }
            )
            .presentationDetents([.height(340)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(AppColors.background)
        }
        .sheet(isPresented: $isExportSelectionPresented, onDismiss: {
            switch pendingExportAction {
            case .pickFolder:
                pendingExportAction = nil
                isFolderPickerPresented = true
            case .none:
                break
            }
        }) {
            OCRSaveSelectionSheet(
                items: viewModel.successfulItems,
                selectedItemIDs: $selectedExportItemIDs,
                onSaveToFile: {
                    isExportSelectionPresented = false
                    pendingExportAction = .pickFolder
                },
                onOpenTransferGuide: {
                    do {
                        _ = try viewModel.archiveExportAssets(selectedItemIDs: selectedExportItemIDs)
                        isExportSelectionPresented = false
                        router.popToRoot()
                        tabRouter.select(.transfer)
                    } catch {
                        alertMessage = AppLocalizer.formatted("保存失败：\n%@", error.localizedDescription)
                        showAlert = true
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(AppColors.background)
        }
        .sheet(isPresented: $isFolderPickerPresented) {
            FolderPicker(
                onPick: { url in
                    do {
                        let savedCount = try viewModel.saveExportAssets(to: url, selectedItemIDs: selectedExportItemIDs)
                        alertMessage = AppLocalizer.formatted("已成功保存 %lld 个文件到所选文件夹", savedCount)
                    } catch {
                        alertMessage = AppLocalizer.formatted("保存失败：\n%@", error.localizedDescription)
                    }
                    showAlert = true
                    isFolderPickerPresented = false
                },
                onCancel: {
                    isFolderPickerPresented = false
                }
            )
        }
    }

    private var emptyState: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.cardBackground, Color.black.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 220)

                        Circle()
                            .fill(AppColors.accentPurple.opacity(0.18))
                            .frame(width: 180, height: 180)
                            .blur(radius: 10)
                            .offset(x: 90, y: -40)

                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Label("OCR Lab", systemImage: "text.viewfinder")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(AppColors.accentPurple)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(AppColors.accentPurple.opacity(0.12))
                                    .clipShape(Capsule())
                                Spacer()
                            }

                            Spacer()

                            VStack(alignment: .leading, spacing: 8) {
                                Text(AppLocalizer.localized("提取图片中的文字内容 (OCR)"))
                                    .font(.system(size: 28, weight: .heavy))
                                    .foregroundColor(AppColors.textPrimary)

                                Text(AppLocalizer.localized("支持从相册、文件或链接导入图片，识别后可导出 TXT、Word 或 Markdown 文件。"))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(22)
                    }

                    HStack(spacing: 12) {
                        featureChip(icon: "bolt.fill", text: AppLocalizer.localized("本地处理"))
                        featureChip(icon: "square.stack.3d.up.fill", text: AppLocalizer.localized("批量导入"))
                        featureChip(icon: "doc.text.fill", text: AppLocalizer.localized("识别结果"))
                    }
                }

                VStack(spacing: 14) {
                    PhotosPicker(selection: $selectedPhotos, matching: .images, photoLibrary: .shared()) {
                        actionCard(
                            icon: "photo.stack.fill",
                            title: AppLocalizer.localized("从相册导入"),
                            detail: AppLocalizer.localized("适合批量挑选近期拍摄或已保存的图片"),
                            accent: AppColors.accentBlue,
                            filled: true
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        isFileImporterPresented = true
                    } label: {
                        actionCard(
                            icon: "folder.fill.badge.plus",
                            title: AppLocalizer.localized("从文件导入"),
                            detail: AppLocalizer.localized("支持从 iCloud Drive 或本地目录选择图片文件"),
                            accent: AppColors.accentGreen,
                            filled: false
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        isLinkImportPresented = true
                    } label: {
                        actionCard(
                            icon: "link",
                            title: AppLocalizer.localized("从链接导入"),
                            detail: AppLocalizer.localized("粘贴公开图片链接，先识别真实格式和尺寸，再确认导入"),
                            accent: AppColors.accentOrange,
                            filled: false
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
    }

    private var summaryPanel: some View {
        VStack(spacing: 16) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    StatItemView(title: AppLocalizer.localized("总数"), count: viewModel.totalCount, color: AppColors.textPrimary)
                    Divider().background(AppColors.secondaryBackground)
                    StatItemView(title: AppLocalizer.localized("待处理"), count: viewModel.pendingCount, color: AppColors.accentBlue)
                    Divider().background(AppColors.secondaryBackground)
                    StatItemView(title: AppLocalizer.localized("成功"), count: viewModel.successCount, color: AppColors.accentGreen)
                    Divider().background(AppColors.secondaryBackground)
                    StatItemView(title: AppLocalizer.localized("失败"), count: viewModel.failedCount, color: AppColors.accentRed)
                }
                .padding(.vertical, 12)

                if viewModel.shouldShowProgress {
                    VStack(spacing: 8) {
                        HStack {
                            Text(viewModel.isRecognizing ? AppLocalizer.localized("处理中") : AppLocalizer.localized("处理完成"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(viewModel.isRecognizing ? AppColors.accentBlue : AppColors.accentGreen)
                            Spacer()
                            Text(viewModel.progressText)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppColors.textPrimary)
                        }

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(AppColors.secondaryBackground.opacity(0.5))
                                    .frame(height: 4)

                                Rectangle()
                                    .fill(viewModel.isRecognizing ? AppColors.accentBlue : AppColors.accentGreen)
                                    .frame(width: geometry.size.width * CGFloat(viewModel.progressValue), height: 4)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.progressValue)
                                    .animation(.easeInOut(duration: 0.3), value: viewModel.isRecognizing)
                            }
                        }
                        .frame(height: 4)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(AppLocalizer.localized("格式"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColors.textSecondary)

                Picker(AppLocalizer.localized("格式"), selection: $viewModel.batchTargetFormat) {
                    ForEach(RecognizedTextExportFormat.allCases) { format in
                        Text(format.shortLabel).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .allowsHitTesting(!viewModel.isRecognizing)
            }
            .padding(20)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .padding(.horizontal)
    }

    private var listSection: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.items) { item in
                OCRItemRow(
                    item: item,
                    onFormatChange: { format in
                        viewModel.updateTargetFormat(for: item.id, to: format)
                    },
                    onPreview: {
                        previewItem = item
                    },
                    onDelete: {
                        viewModel.removeItem(id: item.id)
                    }
                )
            }
        }
        .allowsHitTesting(!viewModel.isRecognizing)
        .padding(.horizontal)
        .padding(.bottom, 112)
    }

    @ViewBuilder
    private var bottomActionPanel: some View {
        let isRecognizing = viewModel.isRecognizing
        let isBusy = viewModel.isRecognizing || viewModel.isImporting
        let hasItems = !viewModel.items.isEmpty
        let hasSuccessItems = viewModel.hasExportableItems

        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Button {
                    isFileImporterPresented = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(AppColors.secondaryBackground.opacity(0.8))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(isBusy)

                PhotosPicker(selection: $selectedPhotos, matching: .images, photoLibrary: .shared()) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(AppColors.secondaryBackground.opacity(0.8))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(isBusy)

                Button {
                    isLinkImportPresented = true
                } label: {
                    Image(systemName: "link")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(AppColors.secondaryBackground.opacity(0.8))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
            }

            Spacer(minLength: 4)

            HStack(spacing: 8) {
                Button {
                    Task {
                        if await purchaseManager.canUseCoreFeatures() {
                            await viewModel.startRecognition()
                        } else {
                            isShowingPaywall = true
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if isRecognizing {
                            ProgressView()
                                .tint(AppColors.textSecondary)
                                .scaleEffect(0.8)
                        }
                        Text(isRecognizing ? AppLocalizer.localized("识别中") : AppLocalizer.localized("识别"))
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundColor(hasItems ? .white : AppColors.textSecondary.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(hasItems ? AppColors.accentBlue : AppColors.secondaryBackground.opacity(0.5))
                    .clipShape(Capsule())
                    .shadow(color: hasItems ? AppColors.accentBlue.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canRecognize)

                Button {
                    selectedExportItemIDs = Set(viewModel.successfulItems.map(\.id))
                    isExportSelectionPresented = true
                } label: {
                    HStack(spacing: 4) {
                        Text(AppLocalizer.localized("保存"))
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(1)
                    }
                    .foregroundColor(hasSuccessItems ? .white : AppColors.textSecondary.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(hasSuccessItems ? AppColors.accentGreen : AppColors.secondaryBackground.opacity(0.5))
                    .clipShape(Capsule())
                    .shadow(color: hasSuccessItems ? AppColors.accentGreen.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(!hasSuccessItems)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(AppColors.cardBackground.opacity(0.85))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 16)
        .padding(.bottom, 0)
        .allowsHitTesting(!viewModel.isImporting)
    }

    private func loadingOverlay(title: String) -> some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text(title)
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

    private func actionCard(icon: String, title: String, detail: String, accent: Color, filled: Bool) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(filled ? accent.opacity(0.18) : AppColors.secondaryBackground.opacity(0.35))
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(filled ? .white : accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(filled ? .white : AppColors.textPrimary)
                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(filled ? Color.white.opacity(0.86) : AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(filled ? Color.white.opacity(0.78) : AppColors.textSecondary.opacity(0.6))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(filled ? accent.opacity(0.92) : AppColors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(filled ? Color.clear : Color.white.opacity(0.06), lineWidth: 1)
        )
        .foregroundColor(filled ? .white : AppColors.textPrimary)
        .shadow(color: filled ? accent.opacity(0.18) : Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
    }

    private func featureChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundColor(AppColors.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppColors.cardBackground)
        .clipShape(Capsule())
    }

}

private enum OCRPendingExportAction {
    case pickFolder
}

private struct OCRSaveSelectionSheet: View {
    let items: [RecognizedTextItem]
    @Binding var selectedItemIDs: Set<UUID>
    let onSaveToFile: () -> Void
    let onOpenTransferGuide: () -> Void

    private var selectedCount: Int {
        items.filter { selectedItemIDs.contains($0.id) }.count
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            selectionToolbar
            itemList
            actionButtons
        }
        .padding(20)
        .background(AppColors.background.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppLocalizer.localized("选择要导出的文件"))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppColors.textPrimary)

            Text(AppLocalizer.localized("先勾选要导出的识别结果，再选择保存到文件夹或传输。"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectionToolbar: some View {
        HStack {
            Text(AppLocalizer.formatted("已选 %lld/%lld", selectedCount, items.count))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Button(AppLocalizer.localized("全选")) {
                selectedItemIDs = Set(items.map(\.id))
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(AppColors.accentBlue)

            Button(AppLocalizer.localized("清空")) {
                selectedItemIDs.removeAll()
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(AppColors.accentRed)
        }
    }

    private var itemList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(items) { item in
                    OCRSaveSelectionRow(
                        item: item,
                        isSelected: selectedItemIDs.contains(item.id),
                        onToggle: {
                            toggleSelection(for: item.id)
                        }
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: onSaveToFile) {
                actionButton(
                    icon: "folder",
                    title: AppLocalizer.localized("文件夹"),
                    accent: selectedCount > 0 ? AppColors.accentOrange : AppColors.secondaryBackground.opacity(0.5),
                    foreground: selectedCount > 0 ? .white : AppColors.textSecondary.opacity(0.5)
                )
            }
            .buttonStyle(.plain)
            .disabled(selectedCount == 0)

            Button(action: onOpenTransferGuide) {
                actionButton(
                    icon: "wifi",
                    title: AppLocalizer.localized("传输"),
                    accent: selectedCount > 0 ? AppColors.accentPurple : AppColors.secondaryBackground.opacity(0.5),
                    foreground: selectedCount > 0 ? .white : AppColors.textSecondary.opacity(0.5)
                )
            }
            .buttonStyle(.plain)
            .disabled(selectedCount == 0)
        }
    }

    private func actionButton(icon: String, title: String, accent: Color, foreground: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
            Text(title)
                .font(.system(size: 15, weight: .bold))
            Spacer()
        }
        .foregroundColor(foreground)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(accent)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func toggleSelection(for id: UUID) {
        if selectedItemIDs.contains(id) {
            selectedItemIDs.remove(id)
        } else {
            selectedItemIDs.insert(id)
        }
    }
}

private struct OCRSaveSelectionRow: View {
    let item: RecognizedTextItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(isSelected ? AppColors.accentBlue : AppColors.textSecondary.opacity(0.6))

                preview

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(item.originalName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)

                        Text(item.targetFormat.shortLabel)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.accentBlue.opacity(0.18))
                            .foregroundColor(AppColors.accentBlue)
                            .clipShape(Capsule())
                    }

                    Text(item.originalFormat)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? AppColors.accentBlue.opacity(0.45) : Color.white.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var preview: some View {
        Group {
            if let previewImage = item.previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.secondaryBackground)
                    .overlay {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppColors.accentBlue)
                    }
            }
        }
        .frame(width: 54, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct OCRItemRow: View {
    let item: RecognizedTextItem
    let onFormatChange: (RecognizedTextExportFormat) -> Void
    let onPreview: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Group {
                if let previewImage = item.previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppColors.secondaryBackground.opacity(0.6))
                        Image(systemName: "photo")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Text(item.originalName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if case .success = item.status {
                        Button(action: onPreview) {
                            Text(AppLocalizer.localized("查看"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(AppColors.accentBlue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(AppColors.accentBlue.opacity(0.14))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 8) {
                    Text(item.originalFormat)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AppColors.secondaryBackground)
                        .foregroundColor(AppColors.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .fixedSize(horizontal: true, vertical: false)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppColors.textSecondary.opacity(0.5))

                    Picker("Format", selection: Binding(
                        get: { item.targetFormat },
                        set: { onFormatChange($0) }
                    )) {
                        ForEach(RecognizedTextExportFormat.allCases) { format in
                            Text(format.shortLabel).tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .tint(AppColors.accentBlue)
                    .font(.system(size: 10, weight: .bold))
                    .fixedSize()
                    .disabled(item.status == .success || {
                        if case .recognizing = item.status { return true }
                        return false
                    }())

                    Spacer(minLength: 8)

                    HStack(spacing: 8) {
                        statusView(for: item.status)

                        Button(action: onDelete) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppColors.textSecondary)
                                .frame(width: 22, height: 22)
                                .background(AppColors.secondaryBackground.opacity(0.8))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private func statusView(for status: RecognizedTextItem.RecognitionStatus) -> some View {
        switch status {
        case .pending:
            Image(systemName: "clock")
                .foregroundColor(AppColors.textSecondary)
        case .recognizing:
            ProgressView()
                .tint(AppColors.accentBlue)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppColors.accentGreen)
        case .failed(let error):
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(AppColors.accentRed)
                .help(error)
        }
    }
}

private struct OCRResultPreviewSheet: View {
    let item: RecognizedTextItem
    @Environment(\.dismiss) private var dismiss
    @State private var copiedMessageVisible = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                AppColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        SelectableTextView(text: item.recognizedText)
                            .frame(minHeight: 640)
                            .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(AppColors.cardBackground)
                            )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }

                if copiedMessageVisible {
                    Text(AppLocalizer.localized("已复制文字内容"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(AppColors.accentPurple.opacity(0.95))
                        .clipShape(Capsule())
                        .padding(.bottom, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle(item.originalName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UIPasteboard.general.string = item.recognizedText
                        withAnimation(.easeOut(duration: 0.2)) {
                            copiedMessageVisible = true
                        }

                        Task {
                            try? await Task.sleep(for: .seconds(1.2))
                            await MainActor.run {
                                withAnimation(.easeIn(duration: 0.2)) {
                                    copiedMessageVisible = false
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(AppColors.accentPurple.opacity(0.92))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(AppLocalizer.localized("复制文本"))
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(AppColors.secondaryBackground.opacity(0.92))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(AppLocalizer.localized("关闭"))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct SelectableTextView: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.textColor = UIColor(AppColors.textPrimary)
        textView.font = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.textContainerInset = UIEdgeInsets(top: 18, left: 14, bottom: 18, right: 14)
        textView.textContainer.lineFragmentPadding = 0
        textView.tintColor = UIColor(AppColors.accentPurple)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
    }
}

#Preview {
    NavigationStack {
        ImageTextRecognitionView()
            .environment(PurchaseManager.shared)
    }
}
