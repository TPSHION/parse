import SwiftUI
import UniformTypeIdentifiers

struct EbookConverterView: View {
    @Environment(RouterManager.self) private var router
    @Environment(TabRouter.self) private var tabRouter
    @Environment(PurchaseManager.self) private var purchaseManager

    @StateObject private var viewModel = EbookConverterViewModel()
    @State private var isFileImporterPresented = false
    @State private var isFolderPickerPresented = false
    @State private var isExportSelectionPresented = false
    @State private var isShowingPaywall = false
    @State private var showAlert = false
    @State private var alertMessage: String?
    @State private var selectedExportItemIDs: Set<UUID> = []
    @State private var pendingExportAction: EbookPendingExportAction?

    private let importTypes = EbookConverterViewModel.supportedContentTypes

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            LinearGradient(
                colors: [AppColors.accentPurple.opacity(0.15), Color.clear],
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
                    .allowsHitTesting(!viewModel.isConverting)
                }
            }

            if viewModel.isImporting {
                loadingOverlay(title: AppLocalizer.localized("正在导入电子书..."))
            } else if viewModel.isConverting {
                loadingOverlay(title: AppLocalizer.localized("电子书处理中"))
            }
        }
        .navigationTitle(AppLocalizer.localized("电子书格式转换"))
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
                    .disabled(viewModel.isConverting)
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
            allowedContentTypes: importTypes,
            allowsMultipleSelection: true
        ) { result in
            viewModel.handleFileImportResult(result)
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
            EbookSaveSelectionSheet(
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
        .alert(AppLocalizer.localized("电子书格式转换"), isPresented: $showAlert) {
            Button(AppLocalizer.localized("确定"), role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .fullScreenCover(isPresented: $isShowingPaywall) {
            TrialPaywallView(allowsDismissal: true)
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
                                Label("Book Lab", systemImage: "book.closed.fill")
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
                                Text(AppLocalizer.localized("电子书格式转换"))
                                    .font(.system(size: 28, weight: .heavy))
                                    .foregroundColor(AppColors.textPrimary)

                                Text(AppLocalizer.localized("支持 EPUB 与 TXT 的格式转换和阅读"))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(AppColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(22)
                    }

                    HStack(spacing: 12) {
                        featureChip(icon: "bolt.fill", text: AppLocalizer.localized("本地处理"))
                        featureChip(icon: "lock.fill", text: AppLocalizer.localized("隐私安全"))
                        featureChip(icon: "doc.text.fill", text: AppLocalizer.localized("双向互转"))
                    }
                }

                Button {
                    isFileImporterPresented = true
                } label: {
                    actionCard(
                        icon: "book.closed.fill",
                        title: AppLocalizer.localized("电子书格式转换"),
                        detail: AppLocalizer.localized("支持从 iCloud Drive 或本地目录选择 EPUB、TXT 文件"),
                        accent: AppColors.accentPurple,
                        filled: true
                    )
                }
                .buttonStyle(.plain)

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
                            Text(viewModel.isConverting ? AppLocalizer.localized("处理中") : AppLocalizer.localized("处理完成"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(viewModel.isConverting ? AppColors.accentPurple : AppColors.accentGreen)
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
                                    .fill(viewModel.isConverting ? AppColors.accentPurple : AppColors.accentGreen)
                                    .frame(width: geometry.size.width * CGFloat(viewModel.progressValue), height: 4)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.progressValue)
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
                    ForEach(EbookTargetFormat.allCases) { format in
                        Text(format.shortLabel).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .allowsHitTesting(!viewModel.isConverting)
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
                EbookItemRow(
                    item: item,
                    onFormatChange: { newFormat in
                        viewModel.updateTargetFormat(for: item.id, to: newFormat)
                    },
                    onDelete: {
                        viewModel.removeItem(id: item.id)
                    }
                )
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 112)
    }

    private var bottomActionPanel: some View {
        let hasItems = !viewModel.items.isEmpty
        let hasSuccessItems = viewModel.hasSuccessItems

        return HStack(spacing: 8) {
            Button {
                isFileImporterPresented = true
            } label: {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(AppColors.secondaryBackground.opacity(0.8))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isConverting || viewModel.isImporting)

            Spacer(minLength: 4)

            HStack(spacing: 8) {
                Button {
                    Task {
                        if await purchaseManager.canUseCoreFeatures() {
                            await viewModel.startConversion()
                        } else {
                            isShowingPaywall = true
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if viewModel.isConverting {
                            ProgressView()
                                .tint(AppColors.textSecondary)
                                .scaleEffect(0.8)
                        }
                        Text(viewModel.isConverting ? AppLocalizer.localized("转换中") : AppLocalizer.localized("开始转换"))
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundColor(hasItems ? .white : AppColors.textSecondary.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(hasItems ? AppColors.accentPurple : AppColors.secondaryBackground.opacity(0.5))
                    .clipShape(Capsule())
                    .shadow(color: hasItems ? AppColors.accentPurple.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canConvert)

                Button {
                    selectedExportItemIDs = Set(viewModel.successfulItems.map(\.id))
                    isExportSelectionPresented = true
                } label: {
                    Text(AppLocalizer.localized("保存"))
                        .font(.system(size: 15, weight: .bold))
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
    }

    private func loadingOverlay(title: String) -> some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()

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

private enum EbookPendingExportAction {
    case pickFolder
}

private struct EbookSaveSelectionSheet: View {
    let items: [EbookItem]
    @Binding var selectedItemIDs: Set<UUID>
    let onSaveToFile: () -> Void
    let onOpenTransferGuide: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Color.white.opacity(0.12))
                .frame(width: 42, height: 5)
                .padding(.top, 10)

            VStack(spacing: 8) {
                Text(AppLocalizer.localized("选择导出文件"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Text(AppLocalizer.localized("先勾选要导出的电子书结果，再选择保存到文件夹或传输。"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(items) { item in
                        EbookExportSelectionRow(
                            item: item,
                            isSelected: selectedItemIDs.contains(item.id),
                            onToggle: { isSelected in
                                if isSelected {
                                    selectedItemIDs.insert(item.id)
                                } else {
                                    selectedItemIDs.remove(item.id)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }

            let selectedCount = selectedItemIDs.count

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                Button(action: onSaveToFile) {
                    actionButton(
                        icon: "folder.fill",
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
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private func actionButton(icon: String, title: String, accent: Color, foreground: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
            Text(title)
                .font(.system(size: 14, weight: .bold))
        }
        .foregroundColor(foreground)
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background(accent)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct EbookExportSelectionRow: View {
    let item: EbookItem
    let isSelected: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        Button {
            onToggle(!isSelected)
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.secondaryBackground)
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppColors.accentPurple)
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.extractedTitle ?? item.originalName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(item.sourceFormat.shortLabel)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(AppColors.secondaryBackground)
                            .foregroundColor(AppColors.textSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                        Text(item.targetFormat.shortLabel)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(AppColors.accentPurple.opacity(0.18))
                            .foregroundColor(AppColors.accentPurple)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(isSelected ? AppColors.accentBlue : AppColors.textSecondary.opacity(0.55))
            }
            .padding(14)
            .background(AppColors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? AppColors.accentBlue.opacity(0.45) : Color.white.opacity(0.05), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        EbookConverterView()
            .environment(RouterManager.shared)
            .environment(TabRouter.shared)
            .environment(PurchaseManager.shared)
    }
}
