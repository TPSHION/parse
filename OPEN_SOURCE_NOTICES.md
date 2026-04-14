# Open Source Notices

## 中文

本仓库中的原创源码采用 [MIT License](./LICENSE) 发布。  
第三方依赖不受本仓库根目录 `LICENSE` 覆盖，仍分别遵循其自身许可证。

### 当前主要第三方依赖

| Dependency | Version | License | Notes |
| --- | --- | --- | --- |
| `ffmpeg-kit-ios-full` | `6.0` | `LGPL-3.0` | 通过仓库内 vendored podspec 固定版本 |
| `GCDWebServer` | `3.5.4` | BSD-style | 用于局域网 Web 传输 |
| `ZIPFoundation` | `0.9.20` | `MIT` | 用于 ZIP 处理 |

### 许可证文本位置

- `ffmpeg-kit-ios-full`
  - [Vendor/ffmpeg-kit-ios-full-lgpl.podspec.json](./Vendor/ffmpeg-kit-ios-full-lgpl.podspec.json)
  - [Pods/ffmpeg-kit-ios-full/ffmpegkit.xcframework/ios-arm64/ffmpegkit.framework/LICENSE](./Pods/ffmpeg-kit-ios-full/ffmpegkit.xcframework/ios-arm64/ffmpegkit.framework/LICENSE)
- `GCDWebServer`
  - [Pods/GCDWebServer/LICENSE](./Pods/GCDWebServer/LICENSE)
- `ZIPFoundation`
  - [Pods/ZIPFoundation/LICENSE](./Pods/ZIPFoundation/LICENSE)
- CocoaPods 生成的统一致谢文件
  - [Pods/Target Support Files/Pods-parse/Pods-parse-acknowledgements.markdown](./Pods/Target%20Support%20Files/Pods-parse/Pods-parse-acknowledgements.markdown)

### 说明

- 本文件用于帮助识别第三方依赖及其许可证，不替代原始许可证正文。
- 发布应用时，请同时保留适当的许可证展示与源码获取说明，尤其是涉及 `ffmpeg-kit` / FFmpeg 的部分。

## English

The original source code in this repository is released under the [MIT License](./LICENSE).  
Third-party dependencies are not relicensed by the root `LICENSE` file and remain under their own terms.

### Current Primary Dependencies

| Dependency | Version | License | Notes |
| --- | --- | --- | --- |
| `ffmpeg-kit-ios-full` | `6.0` | `LGPL-3.0` | Pinned through a vendored podspec in this repository |
| `GCDWebServer` | `3.5.4` | BSD-style | Used for LAN web transfer |
| `ZIPFoundation` | `0.9.20` | `MIT` | Used for ZIP handling |

### License Text Locations

- `ffmpeg-kit-ios-full`
  - [Vendor/ffmpeg-kit-ios-full-lgpl.podspec.json](./Vendor/ffmpeg-kit-ios-full-lgpl.podspec.json)
  - [Pods/ffmpeg-kit-ios-full/ffmpegkit.xcframework/ios-arm64/ffmpegkit.framework/LICENSE](./Pods/ffmpeg-kit-ios-full/ffmpegkit.xcframework/ios-arm64/ffmpegkit.framework/LICENSE)
- `GCDWebServer`
  - [Pods/GCDWebServer/LICENSE](./Pods/GCDWebServer/LICENSE)
- `ZIPFoundation`
  - [Pods/ZIPFoundation/LICENSE](./Pods/ZIPFoundation/LICENSE)
- CocoaPods-generated combined acknowledgements
  - [Pods/Target Support Files/Pods-parse/Pods-parse-acknowledgements.markdown](./Pods/Target%20Support%20Files/Pods-parse/Pods-parse-acknowledgements.markdown)

### Notes

- This document is a convenience summary and does not replace the original license texts.
- When distributing the app, make sure license visibility and source-availability guidance are provided where required, especially for `ffmpeg-kit` / FFmpeg-related components.
