import SwiftUI
import PhotosUI

struct VideoConverterView: View {
    @StateObject private var viewModel = VideoConverterViewModel()
    @State private var selectedVideos: [PhotosPickerItem] = []
    @State private var isFileImporterPresented = false
    @State private var isFileExporterPresented = false
    @State private var exportDocument: ConvertedVideosDocument?
    @State private var isSaveActionSheetPresented = false
    @State private var saveMessage: String?
    @State private var showSaveAlert = false
    
    private var shareableURLs: [URL] {
        viewModel.videoItems.compactMap { item in
            if item.status == .success {
                return item.convertedFileURL
            }
            return nil
        }
    }
    
    var body: some View {
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
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            summaryPanel
                            listSection
                        }
                        .padding(.top, 20)
                    }
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
                    .allowsHitTesting(!viewModel.isConverting)
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
            allowedContentTypes: [.movie, .video],
            allowsMultipleSelection: true
        ) { result in
            handleFileImporterResult(result)
        }
        .fileExporter(
            isPresented: $isFileExporterPresented,
            document: exportDocument,
            contentType: .folder,
            defaultFilename: "ConvertedVideos"
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
        .sheet(isPresented: $isSaveActionSheetPresented) {
            SaveActionSheetView(
                shareableURLs: shareableURLs,
                onSaveToAlbum: {
                    isSaveActionSheetPresented = false
                    Task {
                        let result = await viewModel.saveToPhotoLibrary()
                        switch result {
                        case .success(let count):
                            saveMessage = "成功保存 \(count) 个视频到相册"
                            showSaveAlert = true
                        case .failure(let error):
                            saveMessage = "保存到相册失败：\n\(error.localizedDescription)"
                            showSaveAlert = true
                        }
                    }
                },
                onSaveToFile: {
                    isSaveActionSheetPresented = false
                    exportConvertedVideos()
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
    }
    
    private var summaryPanel: some View {
        VStack(spacing: 16) {
            // 状态统计和进度
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    StatItemView(title: "总数", count: viewModel.totalCount, color: AppColors.textPrimary)
                    Divider().background(AppColors.secondaryBackground)
                    StatItemView(title: "待处理", count: viewModel.pendingCount + viewModel.convertingCount, color: AppColors.accentBlue)
                    Divider().background(AppColors.secondaryBackground)
                    StatItemView(title: "成功", count: viewModel.successCount, color: AppColors.accentGreen)
                    Divider().background(AppColors.secondaryBackground)
                    StatItemView(title: "失败", count: viewModel.failedCount, color: AppColors.accentRed)
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
                                Text(mode.rawValue).tag(mode)
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
    
    private var batchFormatPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("批量目标格式")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("统一设置待处理视频的默认导出格式")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
            }
            
            Picker("统一转换为", selection: $viewModel.batchTargetFormat) {
                ForEach(VideoFormat.allCases) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(.segmented)
            .allowsHitTesting(!viewModel.isConverting)
        }
        .padding(18)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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
                        if let index = viewModel.videoItems.firstIndex(where: { $0.id == item.id }) {
                            viewModel.removeItems(at: IndexSet(integer: index))
                        }
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
        let hasSuccessItems = viewModel.videoItems.contains { $0.status == .success }
        let canConvert = !viewModel.videoItems.isEmpty
        let canSave = hasSuccessItems && !viewModel.isConverting
        let isConverting = viewModel.isConverting
        
        HStack(spacing: 12) {
            Button(action: {
                isFileImporterPresented = true
            }) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 20))
                    .foregroundColor(isConverting ? AppColors.textSecondary.opacity(0.5) : AppColors.textPrimary)
                    .frame(width: 48, height: 48)
                    .background(AppColors.secondaryBackground.opacity(isConverting ? 0.3 : 0.8))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isConverting)
            
            PhotosPicker(selection: $selectedVideos, matching: .videos, photoLibrary: .shared()) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 20))
                    .foregroundColor(isConverting ? AppColors.textSecondary.opacity(0.5) : AppColors.textPrimary)
                    .frame(width: 48, height: 48)
                    .background(AppColors.secondaryBackground.opacity(isConverting ? 0.3 : 0.8))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isConverting)
            
            Button(action: {
                if isConverting {
                    viewModel.stopConversions()
                } else {
                    Task {
                        await viewModel.convertAll()
                    }
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isConverting ? "stop.fill" : "arrow.triangle.2.circlepath")
                        .font(.system(size: 16, weight: .semibold))
                    Text(isConverting ? "停止" : "转换")
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundColor(canConvert ? .white : AppColors.textSecondary.opacity(0.5))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(canConvert ? AppColors.accentBlue : AppColors.secondaryBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: canConvert ? AppColors.accentBlue.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(!canConvert)
            
            Button(action: {
                isSaveActionSheetPresented = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 16, weight: .semibold))
                    Text("保存")
                        .font(.system(size: 16, weight: .bold))
                        .lineLimit(1)
                }
                .foregroundColor(canSave ? .white : AppColors.textSecondary.opacity(0.5))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(canSave ? AppColors.accentGreen : AppColors.secondaryBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: canSave ? AppColors.accentGreen.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
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
    
    private func metricCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppColors.secondaryBackground.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func summaryBadge(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(AppColors.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AppColors.secondaryBackground.opacity(0.35))
        .clipShape(Capsule())
    }
    
    private func handleFileImporterResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            viewModel.isImporting = true
            
            Task {
                for url in urls {
                    guard url.startAccessingSecurityScopedResource() else { continue }
                    
                    let tempDirectory = FileManager.default.temporaryDirectory
                    let tempURL = tempDirectory.appendingPathComponent(UUID().uuidString + "_" + url.lastPathComponent)
                    
                    do {
                        try FileManager.default.copyItem(at: url, to: tempURL)
                        let name = url.deletingPathExtension().lastPathComponent
                        let format = url.pathExtension.uppercased()
                        await viewModel.addVideo(url: tempURL, name: name, format: format.isEmpty ? "未知" : format)
                    } catch {
                        print("Import failed: \(error.localizedDescription)")
                    }
                    
                    url.stopAccessingSecurityScopedResource()
                }
                viewModel.isImporting = false
            }
        case .failure(let error):
            print("Import failed: \(error.localizedDescription)")
        }
    }
    
    private func exportConvertedVideos() {
        let successItems = viewModel.videoItems.filter { $0.status == .success }
        exportDocument = ConvertedVideosDocument(items: successItems)
        isFileExporterPresented = true
    }
}

private extension Double {
    var progressText: String {
        "\(Int(self * 100))%"
    }
    
    var videoDurationText: String {
        guard isFinite, self > 0 else { return "--:--" }
        let totalSeconds = Int(self.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
