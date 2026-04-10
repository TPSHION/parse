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
  topbarExpanded: !window.matchMedia("(max-width: 720px)").matches,
};

const HEARTBEAT_VISIBLE_INTERVAL_MS = 5000;
const HEARTBEAT_HIDDEN_INTERVAL_MS = 10000;

const elements = {
  menuItems: Array.from(document.querySelectorAll(".menu-item")),
  viewPanels: Array.from(document.querySelectorAll("[data-view-panel]")),
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

let dialogResolver = null;
let previewPlayer = null;
let heartbeatTimer = null;
let heartbeatInFlight = false;
let heartbeatFailureCount = 0;

bootstrap().catch((error) => {
  setStatus(`页面初始化失败：${error.message}`, true);
});

async function bootstrap() {
  wireEvents();
  syncTopbarMode();
  switchView("images");
  await refreshMeta();
  startHeartbeatLoop();
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

  elements.topbarToggleButton.addEventListener("click", () => {
    state.topbarExpanded = !state.topbarExpanded;
    syncTopbarMode();
  });

  const handleCopyAddress = async () => {
    if (!state.meta?.address) return;
    await navigator.clipboard.writeText(state.meta.address);
    setStatus("连接地址已复制到剪贴板。");
    showToast("连接地址已复制到剪贴板。");
  };
  elements.copyAddressButton.addEventListener("click", handleCopyAddress);
  elements.sidebarCopyAddressButton?.addEventListener("click", handleCopyAddress);

  const handleDisconnect = async () => {
    const confirmed = await confirmAction({
      title: "断开连接",
      message: "确认断开当前连接并关闭传输服务吗？已打开的网页将停止刷新。",
      confirmText: "确认断开",
    });
    if (!confirmed) return;

    try {
      stopHeartbeatLoop();
      await requestJSON("/api/disconnect", { method: "POST", body: "" });
      setStatus("服务正在断开，页面将在失去连接后停止刷新。");
      showToast("服务正在断开。");
      updateConnectionUI(false);
    } catch (error) {
      setStatus(`断开失败：${error.message}`, true);
      showToast(`断开失败：${error.message}`, true);
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

  document.addEventListener("visibilitychange", restartHeartbeatLoop);
  window.addEventListener("pagehide", stopHeartbeatLoop);
  window.addEventListener("beforeunload", stopHeartbeatLoop);
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
  renderMeta();
}

async function refreshImages() {
  setStatus("正在拉取图片列表...");
  const payload = await requestJSON("/api/library/images");
  state.images = payload.items || [];
  state.photoAuthorization = payload.authorization;
  renderMediaGrid("images");
  setStatus("图片列表已刷新。");
}

async function refreshVideos() {
  setStatus("正在拉取视频列表...");
  const payload = await requestJSON("/api/library/videos");
  state.videos = payload.items || [];
  state.videoAuthorization = payload.authorization;
  renderMediaGrid("videos");
  setStatus("视频列表已刷新。");
}

async function refreshTransfer() {
  setStatus("正在同步共享目录...");
  const [meta, files] = await Promise.all([requestJSON("/api/meta"), requestJSON("/api/files")]);
  state.meta = meta;
  state.files = files.items || [];
  renderMeta();
  renderFiles();
  setStatus("共享目录已刷新。");
}

async function refreshResults() {
  setStatus("正在同步处理结果...");
  const payload = await requestJSON("/api/results");
  state.results = payload.sections || [];
  renderResults();
  setStatus("处理结果已刷新。");
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

  const isConnected = meta.connectionState === "connected" || meta.connectionState === "idle";
  updateConnectionUI(isConnected);
}

function syncTopbarMode() {
  const isMobile = window.matchMedia("(max-width: 720px)").matches;
  const collapsed = isMobile && !state.topbarExpanded;
  elements.topbar.classList.toggle("is-collapsed", collapsed);
  elements.topbarToggleButton.setAttribute("aria-expanded", String(!collapsed));
  elements.topbarToggleButton.textContent = collapsed ? "展开" : "收起";
}

function updateConnectionUI(isConnected) {
  const label = isConnected ? "已连接" : "已断开";
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

function startHeartbeatLoop() {
  stopHeartbeatLoop();
  void sendHeartbeat();
  heartbeatTimer = window.setInterval(() => {
    void sendHeartbeat();
  }, currentHeartbeatInterval());
}

function restartHeartbeatLoop() {
  if (heartbeatTimer === null) return;
  startHeartbeatLoop();
}

function stopHeartbeatLoop() {
  if (heartbeatTimer !== null) {
    window.clearInterval(heartbeatTimer);
    heartbeatTimer = null;
  }
}

function currentHeartbeatInterval() {
  return document.hidden ? HEARTBEAT_HIDDEN_INTERVAL_MS : HEARTBEAT_VISIBLE_INTERVAL_MS;
}

async function sendHeartbeat() {
  if (heartbeatInFlight) return;
  heartbeatInFlight = true;

  try {
    const response = await fetch("/api/ping", {
      method: "GET",
      cache: "no-store",
      headers: {
        Accept: "application/json",
      },
    });

    if (!response.ok) {
      throw new Error(`请求失败 (${response.status})`);
    }

    const payload = await response.json().catch(() => ({}));
    heartbeatFailureCount = 0;

    if (!state.meta) {
      state.meta = {};
    }
    state.meta.connectionState = payload.connectionState || "connected";
    updateConnectionUI(true);
  } catch (_error) {
    heartbeatFailureCount += 1;
    if (heartbeatFailureCount >= 2) {
      updateConnectionUI(false);
    }
  } finally {
    heartbeatInFlight = false;
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
    empty.textContent = "手机端尚未允许读取照片库。请回到 App 允许照片访问后，再刷新当前页面。";
    empty.classList.remove("hidden");
    return;
  }

  if (!items.length) {
    empty.textContent = isImage ? "当前没有可展示的图片，或仍在等待权限授权。" : "当前没有可展示的视频，或仍在等待权限授权。";
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
    badge.textContent = isImage ? "Image" : "Video";
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
    elements.transferEmpty.textContent = "共享目录还是空的。你可以从桌面拖拽文件上传，或者在手机端导入后再来这里下载。";
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
      ? "没有匹配当前搜索条件的结果文件。"
      : "这里会展示图片转换、视频转换、音频转换和压缩后的结果文件。先在 App 内完成处理，再回到网页端下载。";
    elements.resultsEmpty.classList.remove("hidden");
    return;
  }

  elements.resultsEmpty.classList.add("hidden");

  sections.forEach((section) => {
    const wrapper = document.createElement("section");
    wrapper.className = "result-section";

    const head = document.createElement("div");
    head.className = "result-section-head";
    head.innerHTML = `<h3>${section.title}</h3><span class="result-count">${section.count || 0}</span>`;
    wrapper.appendChild(head);

    const list = document.createElement("div");
    list.className = "result-list";

    if (!section.items?.length) {
      const empty = document.createElement("div");
      empty.className = "result-empty";
      empty.textContent = "当前还没有可下载的结果文件。";
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
            <span class="result-count">${section.title}</span>
            ${renderResultPreviewButton(section.key, item)}
            <a class="download-button result-download" href="${item.downloadURL}" target="_blank" rel="noopener">下载</a>
            <button class="delete-button result-delete-button" type="button">删除</button>
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
  return `<button class="soft-button result-preview-button" type="button" data-category="${escapeHTML(category)}" data-name="${escapeHTML(item.name)}">预览</button>`;
}

async function deleteResult(category, filename, row) {
  const confirmed = await confirmAction({
    title: "删除处理结果",
    message: `确认删除 ${filename} 吗？删除后该结果将不会再出现在网页结果列表中。`,
    confirmText: "确认删除",
  });
  if (!confirmed) return;

  row.style.opacity = "0.48";

  try {
    await requestJSON(`/api/results?category=${encodeURIComponent(category)}&name=${encodeURIComponent(filename)}`, {
      method: "DELETE",
    });
    await refreshResults();
    showToast(`已删除 ${filename}`);
    setStatus(`已删除 ${filename}`);
  } catch (error) {
    row.style.opacity = "1";
    showToast(`删除失败：${error.message}`, true);
    setStatus(`删除失败：${error.message}`, true);
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
    stateLabel.textContent = "准备上传";
    elements.uploadList.prepend(fragment);

    const formData = new FormData();
    formData.append("file", file, file.name);

    const xhr = new XMLHttpRequest();
    xhr.open("POST", "/api/upload", true);

    xhr.upload.onprogress = (event) => {
      if (!event.lengthComputable) return;
      const percent = Math.min(100, Math.round((event.loaded / event.total) * 100));
      progress.style.width = `${percent}%`;
      stateLabel.textContent = `上传中 ${percent}%`;
    };

    xhr.onload = () => {
      progress.style.width = "100%";
      if (xhr.status >= 200 && xhr.status < 300) {
        stateLabel.textContent = "上传完成";
        setStatus(`已上传 ${file.name}`);
        showToast(`已上传 ${file.name}`);
      } else {
        stateLabel.textContent = "上传失败";
        item.style.borderColor = "rgba(255, 127, 142, 0.55)";
        setStatus(`上传失败：${file.name}`, true);
        showToast(`上传失败：${file.name}`, true);
      }
      resolve();
    };

    xhr.onerror = () => {
      stateLabel.textContent = "上传失败";
      item.style.borderColor = "rgba(255, 127, 142, 0.55)";
      setStatus(`上传失败：${file.name}`, true);
      showToast(`上传失败：${file.name}`, true);
      resolve();
    };

    xhr.send(formData);
  });
}

async function deleteFile(filename, card) {
  const confirmed = await confirmAction({
    title: "删除共享文件",
    message: `确认删除 ${filename} 吗？删除后将无法在传输页面继续访问该文件。`,
    confirmText: "确认删除",
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
    setStatus(`已删除 ${filename}`);
    showToast(`已删除 ${filename}`);
  } catch (error) {
    card.style.opacity = "1";
    setStatus(`删除失败：${error.message}`, true);
    showToast(`删除失败：${error.message}`, true);
  }
}

async function requestJSON(url, options = {}) {
  const response = await fetch(url, options);
  const text = await response.text();
  const payload = text ? JSON.parse(text) : {};

  if (!response.ok) {
    throw new Error(payload.error || `请求失败 (${response.status})`);
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
  title = "确认操作",
  message = "是否继续执行当前操作？",
  confirmText = "确认",
  cancelText = "取消",
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
      elements.previewMessage.textContent = "当前浏览器不支持 TS 内嵌播放，请直接下载该文件后播放。";
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
          elements.previewMessage.textContent = `TS 预览失败：${errorInfo?.msg || "浏览器无法解码当前视频"}`;
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
      elements.previewMessage.textContent = `TS 预览初始化失败：${error.message}`;
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
  const formatter = new Intl.NumberFormat("zh-CN", {
    maximumFractionDigits: bytes > 1024 * 1024 ? 1 : 0,
  });

  if (bytes >= 1024 * 1024 * 1024) return `${formatter.format(bytes / (1024 * 1024 * 1024))} GB`;
  if (bytes >= 1024 * 1024) return `${formatter.format(bytes / (1024 * 1024))} MB`;
  if (bytes >= 1024) return `${formatter.format(bytes / 1024)} KB`;
  return `${formatter.format(bytes)} B`;
}

function formatDate(value) {
  if (!value) return "刚刚更新";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "时间未知";
  return new Intl.DateTimeFormat("zh-CN", {
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
