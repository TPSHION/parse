const state = {
  activeView: "images",
  meta: null,
  files: [],
  images: [],
  videos: [],
  results: [],
  resultsQuery: "",
  resultsSort: "time_desc",
  photoAuthorization: "not_determined",
  videoAuthorization: "not_determined",
  language: normalizeLanguage(window.__PARSE_APP_LANGUAGE__ || "zh-Hans"),
  languageOverridden: false,
  topbarExpanded: !window.matchMedia("(max-width: 720px)").matches,
};

const elements = {
  menuItems: Array.from(document.querySelectorAll(".menu-item")),
  viewPanels: Array.from(document.querySelectorAll("[data-view-panel]")),
  langButtons: Array.from(document.querySelectorAll("[data-lang-option]")),
  topbar: document.querySelector(".topbar"),
  topbarToggleButton: document.getElementById("topbar-toggle-button"),
  connectionDot: document.getElementById("connection-dot"),
  connectionStateText: document.getElementById("connection-state-text"),
  shareAddress: document.getElementById("share-address"),
  copyAddressButton: document.getElementById("copy-address-button"),
  disconnectButton: document.getElementById("disconnect-button"),
  sidebarConnectionDot: document.getElementById("sidebar-connection-dot"),
  sidebarConnectionStateText: document.getElementById("sidebar-connection-state-text"),
  sidebarShareAddress: document.getElementById("sidebar-share-address"),
  sidebarCopyAddressButton: document.getElementById("sidebar-copy-address-button"),
  sidebarDisconnectButton: document.getElementById("sidebar-disconnect-button"),
  statusBanner: document.getElementById("status-banner"),
  deviceName: document.getElementById("device-name"),
  fileCount: document.getElementById("file-count"),
  totalSize: document.getElementById("total-size"),
  imagesGrid: document.getElementById("images-grid"),
  videosGrid: document.getElementById("videos-grid"),
  fileGrid: document.getElementById("file-grid"),
  resultsStack: document.getElementById("results-stack"),
  imagesEmpty: document.getElementById("images-empty"),
  videosEmpty: document.getElementById("videos-empty"),
  resultsEmpty: document.getElementById("results-empty"),
  resultsSearchInput: document.getElementById("results-search-input"),
  resultsSortSelect: document.getElementById("results-sort-select"),
  transferEmpty: document.getElementById("transfer-empty"),
  refreshImagesButton: document.getElementById("refresh-images-button"),
  refreshVideosButton: document.getElementById("refresh-videos-button"),
  refreshResultsButton: document.getElementById("refresh-results-button"),
  refreshTransferButton: document.getElementById("refresh-transfer-button"),
  dropzone: document.getElementById("dropzone"),
  fileInput: document.getElementById("file-input"),
  pickFilesButton: document.getElementById("pick-files-button"),
  uploadList: document.getElementById("upload-list"),
  fileTemplate: document.getElementById("file-card-template"),
  mediaTemplate: document.getElementById("media-card-template"),
  uploadTemplate: document.getElementById("upload-item-template"),
  toastStack: document.getElementById("toast-stack"),
  dialogBackdrop: document.getElementById("dialog-backdrop"),
  dialogTitle: document.getElementById("dialog-title"),
  dialogMessage: document.getElementById("dialog-message"),
  dialogCancelButton: document.getElementById("dialog-cancel-button"),
  dialogConfirmButton: document.getElementById("dialog-confirm-button"),
  previewBackdrop: document.getElementById("preview-backdrop"),
  previewTitle: document.getElementById("preview-title"),
  previewCloseButton: document.getElementById("preview-close-button"),
  previewVideo: document.getElementById("preview-video"),
  previewMessage: document.getElementById("preview-message"),
};

const translations = {
  "zh-Hans": {
    page_title: "Parse Transfer",
    topbar_connection_status: "连接状态",
    connection_connecting: "连接中",
    connection_connected: "已连接",
    connection_disconnected: "已断开",
    topbar_address: "连接地址",
    copy_address: "复制地址",
    disconnect: "断开连接",
    brand_title: "局域网工作台",
    menu_images: "图片",
    menu_videos: "视频",
    menu_results: "结果",
    menu_transfer: "传输",
    kicker_photos: "图片",
    kicker_videos: "视频",
    kicker_results: "结果",
    kicker_transfer: "传输",
    visit_tip_title: "访问提示",
    visit_tip_body: "保持手机端 App 处于前台，可获得更稳定的网页传输体验。",
    images_title: "手机相册图片",
    images_subtitle: "展示 iPhone 相册中的图片内容，可直接下载原文件。",
    refresh_images: "刷新图片",
    videos_title: "手机相册视频",
    videos_subtitle: "展示相册中的视频内容，可直接下载原文件。",
    refresh_videos: "刷新视频",
    results_title: "处理结果",
    results_subtitle: "集中展示转换和压缩结果，方便统一下载。",
    refresh_results: "刷新结果",
    search_label: "搜索",
    results_search_placeholder: "按文件名搜索结果",
    sort_label: "排序",
    sort_latest: "最新优先",
    sort_oldest: "最早优先",
    transfer_title: "共享传输中心",
    transfer_subtitle: "上传到共享目录，或下载、删除已有文件。",
    refresh_transfer: "刷新传输",
    dropzone_title: "拖拽上传到共享目录",
    dropzone_subtitle: "支持拖拽上传，或点击按钮选择文件。",
    pick_files: "选择文件",
    summary_file_count: "共享文件数量",
    summary_total_size: "共享总大小",
    summary_device: "当前设备",
    status_connected: "页面已连接到本地传输服务。",
    dialog_kicker: "Parse Prompt",
    preview_kicker: "结果预览",
    dialog_title: "确认操作",
    dialog_message: "是否继续执行当前操作？",
    dialog_cancel: "取消",
    dialog_confirm: "确认",
    preview_title: "视频预览",
    preview_close: "关闭",
    download: "下载",
    delete: "删除",
    download_original: "下载原文件",
    page_init_failed: "页面初始化失败：{message}",
    status_address_copied: "连接地址已复制到剪贴板。",
    disconnect_title: "断开连接",
    disconnect_message: "确认断开当前连接并关闭传输服务吗？已打开的网页将停止刷新。",
    disconnect_confirm: "确认断开",
    disconnecting_status: "服务正在断开，页面将在失去连接后停止刷新。",
    disconnecting_toast: "服务正在断开。",
    disconnect_failed: "断开失败：{message}",
    fetching_images: "正在拉取图片列表...",
    images_refreshed: "图片列表已刷新。",
    fetching_videos: "正在拉取视频列表...",
    videos_refreshed: "视频列表已刷新。",
    syncing_transfer: "正在同步共享目录...",
    transfer_refreshed: "共享目录已刷新。",
    syncing_results: "正在同步处理结果...",
    results_refreshed: "处理结果已刷新。",
    expand: "展开",
    collapse: "收起",
    photo_access_denied: "手机端尚未允许读取照片库。请回到 App 允许照片访问后，再刷新当前页面。",
    images_empty: "当前没有可展示的图片，或仍在等待权限授权。",
    videos_empty: "当前没有可展示的视频，或仍在等待权限授权。",
    media_badge_image: "图片",
    media_badge_video: "视频",
    transfer_empty: "共享目录还是空的。你可以从桌面拖拽文件上传，或者在手机端导入后再来这里下载。",
    results_empty_filtered: "没有匹配当前搜索条件的结果文件。",
    results_empty_default: "这里会展示图片、视频、音频转换和压缩后的结果文件。",
    results_section_empty: "当前还没有可下载的结果文件。",
    result_section_image_conversion: "图片转换",
    result_section_video_conversion: "视频转换",
    result_section_audio_conversion: "音频转换",
    result_section_compression: "压缩结果",
    preview: "预览",
    delete_result_title: "删除处理结果",
    delete_result_message: "确认删除 {filename} 吗？删除后该结果将不会再出现在列表中。",
    delete_confirm: "确认删除",
    deleted_status: "已删除 {filename}",
    delete_failed: "删除失败：{message}",
    upload_ready: "准备上传",
    uploading_progress: "上传中 {percent}%",
    upload_complete: "上传完成",
    upload_failed: "上传失败",
    upload_failed_named: "上传失败：{filename}",
    uploaded_status: "已上传 {filename}",
    delete_file_title: "删除共享文件",
    delete_file_message: "确认删除 {filename} 吗？删除后将无法继续访问该文件。",
    request_failed: "请求失败 ({status})",
    server_photo_access_not_granted: "尚未允许访问照片库，请回到 App 授权后重试。",
    server_asset_not_found: "未找到对应的相册资源。",
    server_asset_resource_not_found: "未找到可下载的相册资源。",
    server_thumbnail_render_failed: "缩略图生成失败，请稍后重试。",
    server_asset_download_failed: "资源下载失败，请稍后重试。",
    server_result_file_not_found: "未找到对应的结果文件。",
    server_result_stream_not_found: "未找到对应的预览资源。",
    server_result_thumbnail_not_found: "未找到对应的结果缩略图。",
    server_invalid_result_deletion_request: "删除结果请求无效。",
    server_delete_result_failed: "删除结果失败，请稍后重试。",
    server_invalid_asset_request: "资源请求无效。",
    server_shared_file_not_found: "未找到对应的共享文件。",
    server_invalid_upload_request: "上传请求无效。",
    server_delete_shared_file_failed: "删除共享文件失败，请稍后重试。",
    ts_not_supported: "当前浏览器不支持 TS 内嵌播放，请直接下载该文件后播放。",
    ts_preview_failed: "TS 预览失败：{message}",
    ts_preview_default_error: "浏览器无法解码当前视频",
    ts_preview_init_failed: "TS 预览初始化失败：{message}",
    just_updated: "刚刚更新",
    unknown_time: "时间未知",
  },
  en: {
    page_title: "Parse Transfer",
    topbar_connection_status: "Status",
    connection_connecting: "Connecting",
    connection_connected: "Connected",
    connection_disconnected: "Offline",
    topbar_address: "Address",
    copy_address: "Copy",
    disconnect: "Disconnect",
    brand_title: "LAN Desk",
    menu_images: "Images",
    menu_videos: "Videos",
    menu_results: "Results",
    menu_transfer: "Transfer",
    kicker_photos: "Photos",
    kicker_videos: "Videos",
    kicker_results: "Results",
    kicker_transfer: "Transfer",
    visit_tip_title: "Tip",
    visit_tip_body: "Keep the app in the foreground for more stable transfers.",
    images_title: "Photos",
    images_subtitle: "Browse iPhone photos and download originals.",
    refresh_images: "Refresh Photos",
    videos_title: "Videos",
    videos_subtitle: "Browse iPhone videos and download originals.",
    refresh_videos: "Refresh Videos",
    results_title: "Results",
    results_subtitle: "View converted and compressed files in one place.",
    refresh_results: "Refresh Results",
    search_label: "Search",
    results_search_placeholder: "Search by file name",
    sort_label: "Sort",
    sort_latest: "Newest First",
    sort_oldest: "Oldest First",
    transfer_title: "Transfer Hub",
    transfer_subtitle: "Upload to the shared folder, or download and delete files.",
    refresh_transfer: "Refresh Transfer",
    dropzone_title: "Drop Files to Upload",
    dropzone_subtitle: "Drag files here, or click the button to choose files.",
    pick_files: "Choose Files",
    summary_file_count: "Shared Files",
    summary_total_size: "Total Size",
    summary_device: "Device",
    status_connected: "Connected to the local transfer service.",
    dialog_kicker: "Parse Prompt",
    preview_kicker: "Result Preview",
    dialog_title: "Confirm",
    dialog_message: "Do you want to continue?",
    dialog_cancel: "Cancel",
    dialog_confirm: "Confirm",
    preview_title: "Video Preview",
    preview_close: "Close",
    download: "Download",
    delete: "Delete",
    download_original: "Download Original",
    page_init_failed: "Page failed to initialize: {message}",
    status_address_copied: "Address copied to clipboard.",
    disconnect_title: "Disconnect",
    disconnect_message: "Disconnect and stop the transfer service? The page will stop refreshing.",
    disconnect_confirm: "Disconnect",
    disconnecting_status: "Disconnecting. The page will stop refreshing once the service closes.",
    disconnecting_toast: "Disconnecting…",
    disconnect_failed: "Disconnect failed: {message}",
    fetching_images: "Loading photos...",
    images_refreshed: "Photos refreshed.",
    fetching_videos: "Loading videos...",
    videos_refreshed: "Videos refreshed.",
    syncing_transfer: "Syncing shared folder...",
    transfer_refreshed: "Shared folder refreshed.",
    syncing_results: "Syncing results...",
    results_refreshed: "Results refreshed.",
    expand: "Show",
    collapse: "Hide",
    photo_access_denied: "Photo Library access is not allowed yet. Go back to the app, allow access, then refresh this page.",
    images_empty: "No photos to show yet, or access is still pending.",
    videos_empty: "No videos to show yet, or access is still pending.",
    media_badge_image: "Image",
    media_badge_video: "Video",
    transfer_empty: "The shared folder is empty. Drag files in, or import from the phone first.",
    results_empty_filtered: "No result files match the current search.",
    results_empty_default: "Converted and compressed files appear here.",
    results_section_empty: "No downloadable files in this section yet.",
    result_section_image_conversion: "Images",
    result_section_video_conversion: "Videos",
    result_section_audio_conversion: "Audio",
    result_section_compression: "Compressed",
    preview: "Preview",
    delete_result_title: "Delete Result",
    delete_result_message: "Delete {filename}? It will be removed from this list.",
    delete_confirm: "Delete",
    deleted_status: "Deleted {filename}",
    delete_failed: "Delete failed: {message}",
    upload_ready: "Ready to upload",
    uploading_progress: "Uploading {percent}%",
    upload_complete: "Upload complete",
    upload_failed: "Upload failed",
    upload_failed_named: "Upload failed: {filename}",
    uploaded_status: "Uploaded {filename}",
    delete_file_title: "Delete File",
    delete_file_message: "Delete {filename}? It will no longer be available here.",
    request_failed: "Request failed ({status})",
    server_photo_access_not_granted: "Photo Library access is not granted yet. Allow it in the app and try again.",
    server_asset_not_found: "The requested library item could not be found.",
    server_asset_resource_not_found: "No downloadable asset resource was found.",
    server_thumbnail_render_failed: "Failed to generate the thumbnail. Please try again.",
    server_asset_download_failed: "Failed to download the asset. Please try again.",
    server_result_file_not_found: "The requested result file could not be found.",
    server_result_stream_not_found: "The requested preview stream could not be found.",
    server_result_thumbnail_not_found: "The requested result thumbnail could not be found.",
    server_invalid_result_deletion_request: "The result deletion request is invalid.",
    server_delete_result_failed: "Failed to delete the result. Please try again.",
    server_invalid_asset_request: "The asset request is invalid.",
    server_shared_file_not_found: "The requested shared file could not be found.",
    server_invalid_upload_request: "The upload request is invalid.",
    server_delete_shared_file_failed: "Failed to delete the shared file. Please try again.",
    ts_not_supported: "This browser can't play TS inline. Download the file to watch it.",
    ts_preview_failed: "TS preview failed: {message}",
    ts_preview_default_error: "The browser can't decode this video",
    ts_preview_init_failed: "Failed to start TS preview: {message}",
    just_updated: "Just updated",
    unknown_time: "Unknown time",
  },
};

let dialogResolver = null;
let previewPlayer = null;

function normalizeLanguage(language) {
  return language === "en" ? "en" : "zh-Hans";
}

function currentLocale() {
  return state.language === "en" ? "en-US" : "zh-CN";
}

function t(key, variables = {}) {
  const fallback = translations["zh-Hans"][key] || key;
  const template = (translations[state.language] && translations[state.language][key]) || fallback;
  return template.replace(/\{(\w+)\}/g, (_, name) => `${variables[name] ?? ""}`);
}

function localizeServerError(payload, status) {
  const errorCode = payload?.errorCode;
  if (errorCode) {
    const translationKey = `server_${errorCode}`;
    if (translations["zh-Hans"][translationKey] || translations.en[translationKey]) {
      return t(translationKey);
    }
  }

  return payload?.error || t("request_failed", { status });
}

function syncLanguageButtons() {
  elements.langButtons.forEach((button) => {
    button.classList.toggle("is-active", button.dataset.langOption === state.language);
  });
}

function applyStaticTranslations() {
  document.documentElement.lang = state.language === "en" ? "en" : "zh-CN";
  document.title = t("page_title");

  document.querySelectorAll("[data-i18n]").forEach((node) => {
    const key = node.dataset.i18n;
    if (key) {
      node.textContent = t(key);
    }
  });

  document.querySelectorAll("[data-i18n-placeholder]").forEach((node) => {
    const key = node.dataset.i18nPlaceholder;
    if (key) {
      node.placeholder = t(key);
    }
  });

  syncLanguageButtons();
}

function applyLanguage(language, { fromUser = true } = {}) {
  state.language = normalizeLanguage(language);
  if (fromUser) {
    state.languageOverridden = true;
  }

  applyStaticTranslations();
  syncTopbarMode();

  if (state.meta) {
    renderMeta();
  }
  renderMediaGrid("images");
  renderMediaGrid("videos");
  renderFiles();
  renderResults();
}

bootstrap().catch((error) => {
  setStatus(t("page_init_failed", { message: error.message }), true);
});

async function bootstrap() {
  applyStaticTranslations();
  wireEvents();
  syncTopbarMode();
  switchView("images");
  await refreshMeta();
  await Promise.all([refreshImages(), refreshVideos(), refreshResults(), refreshTransfer()]);
}

function wireEvents() {
  window.matchMedia("(max-width: 720px)").addEventListener("change", () => {
    state.topbarExpanded = !window.matchMedia("(max-width: 720px)").matches;
    syncTopbarMode();
  });

  elements.menuItems.forEach((item) => {
    item.addEventListener("click", () => switchView(item.dataset.view));
  });

  elements.langButtons.forEach((button) => {
    button.addEventListener("click", () => {
      applyLanguage(button.dataset.langOption);
    });
  });

  elements.topbarToggleButton.addEventListener("click", () => {
    state.topbarExpanded = !state.topbarExpanded;
    syncTopbarMode();
  });

  const handleCopyAddress = async () => {
    if (!state.meta?.address) return;
    await navigator.clipboard.writeText(state.meta.address);
    setStatus(t("status_address_copied"));
    showToast(t("status_address_copied"));
  };
  elements.copyAddressButton.addEventListener("click", handleCopyAddress);
  elements.sidebarCopyAddressButton?.addEventListener("click", handleCopyAddress);

  const handleDisconnect = async () => {
    const confirmed = await confirmAction({
      title: t("disconnect_title"),
      message: t("disconnect_message"),
      confirmText: t("disconnect_confirm"),
    });
    if (!confirmed) return;

    try {
      await requestJSON("/api/disconnect", { method: "POST", body: "" });
      setStatus(t("disconnecting_status"));
      showToast(t("disconnecting_toast"));
      updateConnectionUI(false);
    } catch (error) {
      setStatus(t("disconnect_failed", { message: error.message }), true);
      showToast(t("disconnect_failed", { message: error.message }), true);
    }
  };
  elements.disconnectButton.addEventListener("click", handleDisconnect);
  elements.sidebarDisconnectButton?.addEventListener("click", handleDisconnect);

  elements.refreshImagesButton.addEventListener("click", refreshImages);
  elements.refreshVideosButton.addEventListener("click", refreshVideos);
  elements.refreshResultsButton.addEventListener("click", refreshResults);
  elements.refreshTransferButton.addEventListener("click", refreshTransfer);
  elements.resultsSearchInput.addEventListener("input", (event) => {
    state.resultsQuery = event.target.value.trim().toLowerCase();
    renderResults();
  });
  elements.resultsSortSelect.addEventListener("change", (event) => {
    state.resultsSort = event.target.value;
    renderResults();
  });

  elements.pickFilesButton.addEventListener("click", () => elements.fileInput.click());
  elements.fileInput.addEventListener("change", () => {
    if (elements.fileInput.files?.length) {
      uploadFiles(Array.from(elements.fileInput.files));
      elements.fileInput.value = "";
    }
  });

  ["dragenter", "dragover"].forEach((eventName) => {
    elements.dropzone.addEventListener(eventName, (event) => {
      event.preventDefault();
      elements.dropzone.classList.add("dragover");
    });
  });

  ["dragleave", "dragend", "drop"].forEach((eventName) => {
    elements.dropzone.addEventListener(eventName, (event) => {
      event.preventDefault();
      if (eventName === "drop" && event.dataTransfer?.files?.length) {
        uploadFiles(Array.from(event.dataTransfer.files));
      }
      elements.dropzone.classList.remove("dragover");
    });
  });

}

function switchView(view) {
  state.activeView = view;
  elements.menuItems.forEach((item) => {
    item.classList.toggle("is-active", item.dataset.view === view);
  });
  elements.viewPanels.forEach((panel) => {
    panel.classList.toggle("is-active", panel.dataset.viewPanel === view);
  });
}

async function refreshMeta() {
  const meta = await requestJSON("/api/meta");
  state.meta = meta;
  if (!state.languageOverridden && meta.appLanguage) {
    applyLanguage(meta.appLanguage, { fromUser: false });
  }
  renderMeta();
}

async function refreshImages() {
  setStatus(t("fetching_images"));
  const payload = await requestJSON("/api/library/images");
  state.images = payload.items || [];
  state.photoAuthorization = payload.authorization;
  renderMediaGrid("images");
  setStatus(t("images_refreshed"));
}

async function refreshVideos() {
  setStatus(t("fetching_videos"));
  const payload = await requestJSON("/api/library/videos");
  state.videos = payload.items || [];
  state.videoAuthorization = payload.authorization;
  renderMediaGrid("videos");
  setStatus(t("videos_refreshed"));
}

async function refreshTransfer() {
  setStatus(t("syncing_transfer"));
  const [meta, files] = await Promise.all([requestJSON("/api/meta"), requestJSON("/api/files")]);
  state.meta = meta;
  if (!state.languageOverridden && meta.appLanguage) {
    applyLanguage(meta.appLanguage, { fromUser: false });
  }
  state.files = files.items || [];
  renderMeta();
  renderFiles();
  setStatus(t("transfer_refreshed"));
}

async function refreshResults() {
  setStatus(t("syncing_results"));
  const payload = await requestJSON("/api/results");
  state.results = payload.sections || [];
  renderResults();
  setStatus(t("results_refreshed"));
}

function renderMeta() {
  const meta = state.meta || {};
  elements.deviceName.textContent = meta.deviceName || "Parse";
  elements.shareAddress.textContent = meta.address || "--";
  if (elements.sidebarShareAddress) {
    elements.sidebarShareAddress.textContent = meta.address || "--";
  }
  elements.fileCount.textContent = String(meta.fileCount ?? 0);
  elements.totalSize.textContent = formatBytes(meta.totalBytes ?? 0);

  const isConnected = meta.connectionState === "connected";
  updateConnectionUI(isConnected);
}

function syncTopbarMode() {
  const isMobile = window.matchMedia("(max-width: 720px)").matches;
  const collapsed = isMobile && !state.topbarExpanded;
  elements.topbar.classList.toggle("is-collapsed", collapsed);
  elements.topbarToggleButton.setAttribute("aria-expanded", String(!collapsed));
  elements.topbarToggleButton.textContent = collapsed ? t("expand") : t("collapse");
}

function updateConnectionUI(isConnected) {
  const label = isConnected ? t("connection_connected") : t("connection_disconnected");
  const color = isConnected ? "var(--green)" : "var(--red)";
  const shadow = isConnected
    ? "0 0 0 6px rgba(145, 245, 175, 0.18)"
    : "0 0 0 6px rgba(255, 127, 142, 0.18)";

  elements.connectionStateText.textContent = label;
  elements.connectionDot.style.background = color;
  elements.connectionDot.style.boxShadow = shadow;

  if (elements.sidebarConnectionStateText) {
    elements.sidebarConnectionStateText.textContent = label;
  }
  if (elements.sidebarConnectionDot) {
    elements.sidebarConnectionDot.style.background = color;
    elements.sidebarConnectionDot.style.boxShadow = shadow;
  }
}

function renderMediaGrid(kind) {
  const isImage = kind === "images";
  const items = isImage ? state.images : state.videos;
  const authorization = isImage ? state.photoAuthorization : state.videoAuthorization;
  const grid = isImage ? elements.imagesGrid : elements.videosGrid;
  const empty = isImage ? elements.imagesEmpty : elements.videosEmpty;

  grid.innerHTML = "";

  if (authorization === "denied" || authorization === "restricted") {
    empty.textContent = t("photo_access_denied");
    empty.classList.remove("hidden");
    return;
  }

  if (!items.length) {
    empty.textContent = isImage ? t("images_empty") : t("videos_empty");
    empty.classList.remove("hidden");
    return;
  }

  empty.classList.add("hidden");

  items.forEach((item) => {
    const fragment = elements.mediaTemplate.content.cloneNode(true);
    const image = fragment.querySelector(".media-thumb");
    const badge = fragment.querySelector(".media-kind-badge");
    const name = fragment.querySelector(".media-name");
    const meta = fragment.querySelector(".media-meta");
    const download = fragment.querySelector(".download-button");

    image.src = item.thumbnailURL;
    image.alt = item.name;
    badge.textContent = isImage ? t("media_badge_image") : t("media_badge_video");
    name.textContent = item.name;
    meta.textContent = isImage
      ? `${formatDate(item.createdAt)}`
      : `${formatDate(item.createdAt)} · ${formatDuration(item.duration || 0)}`;
    download.href = item.downloadURL;

    grid.appendChild(fragment);
  });
}

function renderFiles() {
  elements.fileGrid.innerHTML = "";

  if (!state.files.length) {
    elements.transferEmpty.textContent = t("transfer_empty");
    elements.transferEmpty.classList.remove("hidden");
    return;
  }

  elements.transferEmpty.classList.add("hidden");

  state.files.forEach((file) => {
    const fragment = elements.fileTemplate.content.cloneNode(true);
    const card = fragment.querySelector(".file-card");
    const name = fragment.querySelector(".file-name");
    const ext = fragment.querySelector(".file-ext");
    const meta = fragment.querySelector(".file-meta");
    const download = fragment.querySelector(".download-button");
    const remove = fragment.querySelector(".delete-button");

    name.textContent = file.name;
    ext.textContent = file.extension || "file";
    meta.textContent = `${formatBytes(file.bytes)} · ${formatDate(file.modifiedAt)}`;
    download.href = `/api/download?name=${encodeURIComponent(file.name)}`;
    remove.addEventListener("click", () => deleteFile(file.name, card));

    elements.fileGrid.appendChild(fragment);
  });
}

function renderResults() {
  elements.resultsStack.innerHTML = "";

  const sections = (state.results || []).map((section) => ({
    ...section,
    items: filterAndSortResultItems(section.items || []),
  }));
  const hasItems = sections.some((section) => section.items.length > 0);

  if (!hasItems) {
    elements.resultsEmpty.textContent = state.resultsQuery
      ? t("results_empty_filtered")
      : t("results_empty_default");
    elements.resultsEmpty.classList.remove("hidden");
    return;
  }

  elements.resultsEmpty.classList.add("hidden");

  sections.forEach((section) => {
    const localizedSectionTitle = t(`result_section_${section.key}`);
    const wrapper = document.createElement("section");
    wrapper.className = "result-section";

    const head = document.createElement("div");
    head.className = "result-section-head";
    head.innerHTML = `<h3>${localizedSectionTitle}</h3><span class="result-count">${section.count || 0}</span>`;
    wrapper.appendChild(head);

    const list = document.createElement("div");
    list.className = "result-list";

    if (!section.items?.length) {
      const empty = document.createElement("div");
      empty.className = "result-empty";
      empty.textContent = t("results_section_empty");
      list.appendChild(empty);
    } else {
      section.items.forEach((item) => {
        const row = document.createElement("div");
        row.className = "result-row";
        const preview = renderResultPreview(item);
        row.innerHTML = `
          <div class="result-main">
            ${preview}
            <div class="result-copy">
              <p class="result-name">${escapeHTML(item.name)}</p>
              <p class="result-meta">${formatBytes(item.bytes)} · ${formatDate(item.modifiedAt)}</p>
            </div>
          </div>
          <div class="result-actions">
            <span class="result-count">${localizedSectionTitle}</span>
            ${renderResultPreviewButton(section.key, item)}
            <a class="download-button result-download" href="${item.downloadURL}" target="_blank" rel="noopener">${t("download")}</a>
            <button class="delete-button result-delete-button" type="button">${t("delete")}</button>
          </div>
        `;
        const previewButton = row.querySelector(".result-preview-button");
        if (previewButton) {
          previewButton.addEventListener("click", () => {
            openResultPreview(section.key, item);
          });
        }
        row.querySelector(".result-delete-button").addEventListener("click", () => {
          deleteResult(section.key, item.name, row);
        });
        list.appendChild(row);
      });
    }

    wrapper.appendChild(list);
    elements.resultsStack.appendChild(wrapper);
  });
}

function filterAndSortResultItems(items) {
  const query = state.resultsQuery;
  const filtered = query
    ? items.filter((item) => (item.name || "").toLowerCase().includes(query))
    : [...items];

  filtered.sort((lhs, rhs) => {
    const leftTime = lhs.modifiedAt ? new Date(lhs.modifiedAt).getTime() : 0;
    const rightTime = rhs.modifiedAt ? new Date(rhs.modifiedAt).getTime() : 0;
    return state.resultsSort === "time_asc" ? leftTime - rightTime : rightTime - leftTime;
  });

  return filtered;
}

function renderResultPreview(item) {
  if (item.previewKind === "image" || item.previewKind === "video") {
    return `<img class="result-thumb" src="${item.thumbnailURL}" alt="${escapeHTML(item.name)}">`;
  }

  return `<div class="result-thumb is-placeholder">${escapeHTML(extensionLabel(item.name))}</div>`;
}

function renderResultPreviewButton(category, item) {
  if (item.previewKind !== "video") {
    return "";
  }
  return `<button class="soft-button result-preview-button" type="button" data-category="${escapeHTML(category)}" data-name="${escapeHTML(item.name)}">${t("preview")}</button>`;
}

async function deleteResult(category, filename, row) {
  const confirmed = await confirmAction({
    title: t("delete_result_title"),
    message: t("delete_result_message", { filename }),
    confirmText: t("delete_confirm"),
  });
  if (!confirmed) return;

  row.style.opacity = "0.48";

  try {
    await requestJSON(`/api/results?category=${encodeURIComponent(category)}&name=${encodeURIComponent(filename)}`, {
      method: "DELETE",
    });
    await refreshResults();
    showToast(t("deleted_status", { filename }));
    setStatus(t("deleted_status", { filename }));
  } catch (error) {
    row.style.opacity = "1";
    showToast(t("delete_failed", { message: error.message }), true);
    setStatus(t("delete_failed", { message: error.message }), true);
  }
}

async function uploadFiles(files) {
  switchView("transfer");
  for (const file of files) {
    await uploadSingleFile(file);
  }
  await refreshTransfer();
}

function uploadSingleFile(file) {
  return new Promise((resolve) => {
    const fragment = elements.uploadTemplate.content.cloneNode(true);
    const item = fragment.querySelector(".upload-item");
    const name = fragment.querySelector(".upload-name");
    const stateLabel = fragment.querySelector(".upload-state");
    const progress = fragment.querySelector(".upload-progress");

    name.textContent = file.name;
    stateLabel.textContent = t("upload_ready");
    elements.uploadList.prepend(fragment);

    const formData = new FormData();
    formData.append("file", file, file.name);

    const xhr = new XMLHttpRequest();
    xhr.open("POST", "/api/upload", true);

    xhr.upload.onprogress = (event) => {
      if (!event.lengthComputable) return;
      const percent = Math.min(100, Math.round((event.loaded / event.total) * 100));
      progress.style.width = `${percent}%`;
      stateLabel.textContent = t("uploading_progress", { percent });
    };

    xhr.onload = () => {
      progress.style.width = "100%";
      if (xhr.status >= 200 && xhr.status < 300) {
        stateLabel.textContent = t("upload_complete");
        setStatus(t("uploaded_status", { filename: file.name }));
        showToast(t("uploaded_status", { filename: file.name }));
      } else {
        stateLabel.textContent = t("upload_failed");
        item.style.borderColor = "rgba(255, 127, 142, 0.55)";
        setStatus(t("upload_failed_named", { filename: file.name }), true);
        showToast(t("upload_failed_named", { filename: file.name }), true);
      }
      resolve();
    };

    xhr.onerror = () => {
      stateLabel.textContent = t("upload_failed");
      item.style.borderColor = "rgba(255, 127, 142, 0.55)";
      setStatus(t("upload_failed_named", { filename: file.name }), true);
      showToast(t("upload_failed_named", { filename: file.name }), true);
      resolve();
    };

    xhr.send(formData);
  });
}

async function deleteFile(filename, card) {
  const confirmed = await confirmAction({
    title: t("delete_file_title"),
    message: t("delete_file_message", { filename }),
    confirmText: t("delete_confirm"),
  });
  if (!confirmed) return;

  card.style.opacity = "0.48";

  try {
    await requestJSON(`/api/files?name=${encodeURIComponent(filename)}`, {
      method: "DELETE",
    });
    state.files = state.files.filter((file) => file.name !== filename);
    renderFiles();
    await refreshTransfer();
    setStatus(t("deleted_status", { filename }));
    showToast(t("deleted_status", { filename }));
  } catch (error) {
    card.style.opacity = "1";
    setStatus(t("delete_failed", { message: error.message }), true);
    showToast(t("delete_failed", { message: error.message }), true);
  }
}

async function requestJSON(url, options = {}) {
  const response = await fetch(url, options);
  const text = await response.text();
  const payload = text ? JSON.parse(text) : {};

  if (!response.ok) {
    throw new Error(localizeServerError(payload, response.status));
  }

  return payload;
}

function setStatus(message, isError = false) {
  elements.statusBanner.textContent = message;
  elements.statusBanner.style.color = isError ? "#ffd8dc" : "";
  elements.statusBanner.style.borderColor = isError ? "rgba(255, 127, 142, 0.35)" : "";
}

function showToast(message, isError = false) {
  const toast = document.createElement("div");
  toast.className = `toast ${isError ? "is-error" : "is-success"}`;
  toast.textContent = message;
  elements.toastStack.appendChild(toast);

  window.setTimeout(() => {
    toast.style.opacity = "0";
    toast.style.transform = "translateY(8px)";
    window.setTimeout(() => toast.remove(), 180);
  }, 2600);
}

function confirmAction({
  title = t("dialog_title"),
  message = t("dialog_message"),
  confirmText = t("dialog_confirm"),
  cancelText = t("dialog_cancel"),
}) {
  if (dialogResolver) {
    dialogResolver(false);
    dialogResolver = null;
  }

  elements.dialogTitle.textContent = title;
  elements.dialogMessage.textContent = message;
  elements.dialogCancelButton.textContent = cancelText;
  elements.dialogConfirmButton.textContent = confirmText;
  elements.dialogBackdrop.classList.remove("hidden");

  return new Promise((resolve) => {
    dialogResolver = resolve;
  });
}

elements.dialogCancelButton.addEventListener("click", () => closeDialog(false));
elements.dialogConfirmButton.addEventListener("click", () => closeDialog(true));
elements.dialogBackdrop.addEventListener("click", (event) => {
  if (event.target === elements.dialogBackdrop) {
    closeDialog(false);
  }
});
window.addEventListener("keydown", (event) => {
  if (event.key !== "Escape") {
    return;
  }

  if (dialogResolver) {
    closeDialog(false);
  }

  if (!elements.previewBackdrop.classList.contains("hidden")) {
    closePreview();
  }
});

  elements.previewCloseButton.addEventListener("click", closePreview);
  elements.previewBackdrop.addEventListener("click", (event) => {
    if (event.target === elements.previewBackdrop) {
      closePreview();
    }
  });

function closeDialog(result) {
  if (!dialogResolver) return;
  const resolve = dialogResolver;
  dialogResolver = null;
  elements.dialogBackdrop.classList.add("hidden");
  resolve(result);
}

async function openResultPreview(category, item) {
  const streamURL = `/api/results/stream?category=${encodeURIComponent(category)}&name=${encodeURIComponent(item.name)}`;
  const extension = (item.name.split(".").pop() || "").toLowerCase();

  closePreview();
  elements.previewTitle.textContent = item.name;
  elements.previewBackdrop.classList.remove("hidden");
  elements.previewMessage.classList.add("hidden");
  elements.previewMessage.textContent = "";
  elements.previewVideo.controls = true;
  elements.previewVideo.playsInline = true;

  if (isMpegTsFamily(extension)) {
    if (
      !window.mpegts ||
      typeof window.mpegts.createPlayer !== "function" ||
      typeof window.mpegts.isSupported !== "function" ||
      !window.mpegts.isSupported()
    ) {
      elements.previewMessage.textContent = t("ts_not_supported");
      elements.previewMessage.classList.remove("hidden");
      return;
    }

    try {
      previewPlayer = window.mpegts.createPlayer({
        type: mpegtsPlaybackType(extension),
        isLive: false,
        url: streamURL,
      });
      if (typeof previewPlayer.on === "function" && window.mpegts.Events?.ERROR) {
        previewPlayer.on(window.mpegts.Events.ERROR, (_errorType, _errorDetail, errorInfo) => {
          elements.previewMessage.textContent = t("ts_preview_failed", {
            message: errorInfo?.msg || t("ts_preview_default_error"),
          });
          elements.previewMessage.classList.remove("hidden");
        });
      }
      previewPlayer.attachMediaElement(elements.previewVideo);
      previewPlayer.load();
      if (typeof previewPlayer.play === "function") {
        await previewPlayer.play().catch(() => {});
      } else {
        await elements.previewVideo.play().catch(() => {});
      }
    } catch (error) {
      elements.previewMessage.textContent = t("ts_preview_init_failed", { message: error.message });
      elements.previewMessage.classList.remove("hidden");
    }
    return;
  }

  elements.previewVideo.src = streamURL;
  elements.previewVideo.load();
  await elements.previewVideo.play().catch(() => {});
}

function closePreview() {
  if (previewPlayer) {
    if (typeof previewPlayer.pause === "function") {
      previewPlayer.pause();
    }
    if (typeof previewPlayer.unload === "function") {
      previewPlayer.unload();
    }
    if (typeof previewPlayer.detachMediaElement === "function") {
      previewPlayer.detachMediaElement();
    }
    if (typeof previewPlayer.destroy === "function") {
      previewPlayer.destroy();
    }
  }
  previewPlayer = null;
  elements.previewVideo.pause();
  elements.previewVideo.removeAttribute("src");
  elements.previewVideo.load();
  elements.previewMessage.textContent = "";
  elements.previewMessage.classList.add("hidden");
  elements.previewBackdrop.classList.add("hidden");
}

function isMpegTsFamily(extension) {
  return ["ts", "mts", "m2ts"].includes(extension);
}

function mpegtsPlaybackType(extension) {
  return extension === "ts" ? "mpegts" : "m2ts";
}

function formatBytes(bytes) {
  const formatter = new Intl.NumberFormat(currentLocale(), {
    maximumFractionDigits: bytes > 1024 * 1024 ? 1 : 0,
  });

  if (bytes >= 1024 * 1024 * 1024) return `${formatter.format(bytes / (1024 * 1024 * 1024))} GB`;
  if (bytes >= 1024 * 1024) return `${formatter.format(bytes / (1024 * 1024))} MB`;
  if (bytes >= 1024) return `${formatter.format(bytes / 1024)} KB`;
  return `${formatter.format(bytes)} B`;
}

function formatDate(value) {
  if (!value) return t("just_updated");
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return t("unknown_time");
  return new Intl.DateTimeFormat(currentLocale(), {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(date);
}

function formatDuration(seconds) {
  const total = Math.max(0, Math.round(seconds));
  const minutes = Math.floor(total / 60);
  const remain = total % 60;
  return `${String(minutes).padStart(2, "0")}:${String(remain).padStart(2, "0")}`;
}

function escapeHTML(value) {
  const div = document.createElement("div");
  div.textContent = value || "";
  return div.innerHTML;
}

function extensionLabel(filename) {
  const ext = (filename.split(".").pop() || "file").slice(0, 4);
  return ext.toUpperCase();
}
