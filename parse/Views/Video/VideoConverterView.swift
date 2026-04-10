import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct VideoConverterView: View {
    @Environment(RouterManager.self) private var router
    @Environment(TabRouter.self) private var tabRouter
    @StateObject private var viewModel = VideoConverterViewModel()
    @State private var selectedVideos: [PhotosPickerItem] = []
    @State private var isFileImporterPresented = false
    @State private var isFileExporterPresented = false
    @State private var isSaveActionSheetPresented = false
    @State private var saveMessage: String?
    @State private var showSaveAlert = false

    private var importContentTypes: [UTType] {
        var types: [UTType] = [.movie, .video]
        if let tsType = UTType(filenameExtension: "ts", conformingTo: .movie) {
            types.append(tsType)
        }
        return types
    }
    
    var body: some View {
        let isBusy = viewModel.isConverting || viewModel.isImporting
        
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            LinearGradient(
                colors: [AppColors.accentGreen.opacity(0.15), Color.clear],
                startPoint: .topLeading,
                endPoint: .center
            )
            .ignoresSafeArea()
            
            Group {
                if viewModel.videoItems.isEmpty {
                    VideoEmptyStateView(
                        isFileImporterPresented: $isFileImporterPresented,
                        selectedVideos: $selectedVideos
                    )
                    .allowsHitTesting(!viewModel.isImporting)
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
            
            // 导入时的加载动画
            if viewModel.isImporting {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        Text("正在导入视频...")
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
        }
        .navigationTitle("视频格式转换")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            if !viewModel.videoItems.isEmpty {
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
            if !viewModel.videoItems.isEmpty {
                bottomActionPanel
            }
        }
        .onChange(of: selectedVideos) { _, newVideos in
            viewModel.processVideoSelections(newVideos)
            selectedVideos.removeAll()
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: importContentTypes,
            allowsMultipleSelection: true
        ) { result in
            viewModel.handleFileImportResult(result)
        }
        .fileExporter(
            isPresented: $isFileExporterPresented,
            document: viewModel.exportDocument,
            contentType: .folder,
            defaultFilename: "ConvertedVideos"
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
                onSaveToAlbum: {
                    isSaveActionSheetPresented = false
                    Task {
                        let result = await viewModel.saveToPhotoLibrary()
                        switch result {
                        case .success(let count):
                            saveMessage = AppLocalizer.formatted("成功保存 %lld 个视频到相册", count)
                            showSaveAlert = true
                        case .failure(let error):
                            saveMessage = AppLocalizer.formatted("保存到相册失败：\n%@", error.localizedDescription)
                            showSaveAlert = true
                        }
                    }
                },
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
            .presentationDetents([.height(356)])
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
    
    private var summaryPanel: some View {
        VStack(spacing: 16) {
            // 状态统计和进度
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
                
                // 仅在有任务进行过或进行中时显示进度条
                if viewModel.totalCount > 0 && (viewModel.isConverting || viewModel.successCount > 0 || viewModel.failedCount > 0) {
                    VStack(spacing: 8) {
                        HStack {
                            Text(viewModel.isConverting ? "处理中" : "处理完成")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(viewModel.isConverting ? AppColors.accentBlue : AppColors.accentGreen)
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
                                    .fill(viewModel.isConverting ? AppColors.accentBlue : AppColors.accentGreen)
                                    .frame(width: geometry.size.width * CGFloat(viewModel.conversionProgress), height: 4)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.conversionProgress)
                                    .animation(.easeInOut(duration: 0.3), value: viewModel.isConverting)
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
            
                // 模式选择和统一转换选项
                VStack(spacing: 12) {
                    HStack {
                        Text("转换模式")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .fontWeight(.medium)
                        Spacer()
                        Picker("转换模式", selection: $viewModel.conversionMode) {
                            ForEach(VideoConverterViewModel.ConversionMode.allCases) { mode in
                                Text(mode.localizedTitle).tag(mode)
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
                            ForEach(VideoFormat.allCases) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 240)
                        .allowsHitTesting(!viewModel.isConverting)
                    }
                    
                    Divider().background(AppColors.secondaryBackground)
                    
                    HStack {
                        Text("并发处理数量")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .fontWeight(.medium)
                        Spacer()
                        Stepper(value: $viewModel.maxConcurrentTasks, in: 1...10) {
                            Text("\(viewModel.maxConcurrentTasks)")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(AppColors.textPrimary)
                                .frame(minWidth: 30, alignment: .trailing)
                        }
                        .frame(width: 140)
                        .environment(\.colorScheme, .dark)
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
            ForEach(viewModel.videoItems) { item in
                VideoItemRow(
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
        .allowsHitTesting(!viewModel.isConverting)
        .padding(.horizontal)
        .padding(.bottom, 100)
    }
    
    @ViewBuilder
    private var bottomActionPanel: some View {
        let isConverting = viewModel.isConverting
        let isBusy = viewModel.isConverting || viewModel.isImporting
        let hasItems = !viewModel.videoItems.isEmpty || isConverting
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
            
            PhotosPicker(selection: $selectedVideos, matching: .videos, photoLibrary: .shared()) {
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
                    await viewModel.handlePrimaryAction()
                }
            }) {
                HStack(spacing: 6) {
                    Text(isConverting ? "停止" : "转换")
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundColor(hasItems ? .white : AppColors.textSecondary.opacity(0.5))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(hasItems ? AppColors.accentBlue : AppColors.secondaryBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: hasItems ? AppColors.accentBlue.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
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
        .allowsHitTesting(!viewModel.isImporting)
    }
    
}
