import SwiftUI
import UniformTypeIdentifiers

struct AudioConverterView: View {
    @Environment(RouterManager.self) private var router
    @Environment(TabRouter.self) private var tabRouter
    @Environment(PurchaseManager.self) private var purchaseManager
    @StateObject private var viewModel = AudioConverterViewModel()
    @State private var isFileImporterPresented = false
    @State private var isFileExporterPresented = false
    @State private var isSaveActionSheetPresented = false
    @State private var saveMessage: String?
    @State private var showSaveAlert = false
    @State private var isShowingPaywall = false
    
    private var isBusy: Bool {
        viewModel.isConverting || viewModel.isImporting
    }
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            LinearGradient(
                colors: [AppColors.accentOrange.opacity(0.15), Color.clear],
                startPoint: .topLeading,
                endPoint: .center
            )
            .ignoresSafeArea()
            
            Group {
                if viewModel.audioItems.isEmpty {
                    AudioEmptyStateView(
                        isFileImporterPresented: $isFileImporterPresented
                    )
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
                importingOverlay
            }
        }
        .navigationTitle("音频转换")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            if !viewModel.audioItems.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.clearAll() }) {
                        Text("清空")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .allowsHitTesting(!isBusy)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if !viewModel.audioItems.isEmpty {
                bottomActionPanel
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            viewModel.handleFileImportResult(result)
        }
        .fileExporter(
            isPresented: $isFileExporterPresented,
            document: viewModel.exportDocument,
            contentType: .folder,
            defaultFilename: "ConvertedAudios"
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
        .sheet(isPresented: $isSaveActionSheetPresented) {
            SaveActionSheetView(
                shareableURLs: viewModel.shareableURLs,
                onSaveToAlbum: nil,
                onSaveToFile: {
                    isSaveActionSheetPresented = false
                    viewModel.prepareExportDocument()
                    isFileExporterPresented = viewModel.exportDocument != nil
                },
                onOpenTransferGuide: {
                    isSaveActionSheetPresented = false
                    router.popToRoot()
                    tabRouter.select(.transfer)
                }
            )
            .presentationDetents([.height(280)])
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
    
    private var summaryPanel: some View {
        VStack(spacing: 16) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    StatItemView(title: AppLocalizer.localized("总数"), count: viewModel.totalCount, color: AppColors.textPrimary)
                    Divider().background(AppColors.secondaryBackground)
                    StatItemView(title: AppLocalizer.localized("待处理"), count: viewModel.pendingCount + viewModel.convertingCount, color: AppColors.accentBlue)
                    Divider().background(AppColors.secondaryBackground)
                    StatItemView(title: AppLocalizer.localized("成功"), count: viewModel.successCount, color: AppColors.accentGreen)
                    Divider().background(AppColors.secondaryBackground)
                    StatItemView(title: AppLocalizer.localized("失败"), count: viewModel.failedCount, color: AppColors.accentRed)
                }
                .padding(.vertical, 12)
                
                if viewModel.totalCount > 0 && (viewModel.isConverting || viewModel.successCount > 0 || viewModel.failedCount > 0) {
                    VStack(spacing: 8) {
                        HStack {
                            Text(viewModel.isConverting ? "处理中" : "处理完成")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(viewModel.isConverting ? AppColors.accentOrange : AppColors.accentGreen)
                            Spacer()
                            Text(viewModel.conversionProgress.progressText)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppColors.textPrimary)
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(AppColors.secondaryBackground.opacity(0.5))
                                    .frame(height: 4)
                                
                                Rectangle()
                                    .fill(viewModel.isConverting ? AppColors.accentOrange : AppColors.accentGreen)
                                    .frame(width: geometry.size.width * CGFloat(viewModel.conversionProgress), height: 4)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.conversionProgress)
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
            
            VStack(spacing: 12) {
                HStack {
                    Text("转换模式")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .fontWeight(.medium)
                    Spacer()
                    Picker("转换模式", selection: $viewModel.conversionMode) {
                        ForEach(AudioConversionMode.allCases) { mode in
                            Text(mode.localizedTitle)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                    .allowsHitTesting(!viewModel.isConverting)
                }
                
                Divider().background(AppColors.secondaryBackground)
                
                HStack {
                    Text("统一转换为")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .fontWeight(.medium)
                    Spacer()
                    Picker("统一转换为", selection: $viewModel.batchTargetFormat) {
                        ForEach(AudioFormat.allCases) { format in
                            Text(format.rawValue)
                                .tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 240)
                    .allowsHitTesting(!viewModel.isConverting)
                }
            }
            .padding(16)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.horizontal)
    }
    
    private var listSection: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.audioItems) { item in
                AudioItemRow(
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
        .padding(.bottom, 100)
    }
    
    @ViewBuilder
    private var bottomActionPanel: some View {
        let hasItems = !viewModel.audioItems.isEmpty
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
            
            Button(action: {
                Task {
                    if await purchaseManager.canUseCoreFeatures() {
                        await viewModel.startConversion()
                    } else {
                        isShowingPaywall = true
                    }
                }
            }) {
                HStack(spacing: 6) {
                    if viewModel.isConverting {
                        ProgressView()
                            .tint(AppColors.textSecondary)
                    }
                    Text(viewModel.isConverting ? "转换中" : "转换")
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
            .disabled(!viewModel.canConvert)
            
            Button(action: {
                isSaveActionSheetPresented = true
            }) {
                HStack(spacing: 6) {
                    Text("保存")
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                }
                .foregroundColor(hasSuccessItems ? .white : AppColors.textSecondary.opacity(0.5))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(hasSuccessItems ? AppColors.accentGreen : AppColors.secondaryBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: hasSuccessItems ? AppColors.accentGreen.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canSave)
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
    }
    
    private var importingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.5).tint(.white)
                Text("正在导入音频...").font(.system(size: 15, weight: .medium)).foregroundColor(.white)
            }
            .padding(32)
            .background(AppColors.cardBackground.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        }
        .zIndex(100)
    }
}

#Preview {
    NavigationStack {
        AudioConverterView()
    }
}
