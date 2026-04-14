# Parse

[中文](#中文) | [English](#english)

## 中文

### 项目简介

Parse 是一款面向 iPhone 的本地处理工具，聚焦文件转换、媒体压缩、局域网传输与文档处理。大部分核心操作都在设备上完成，尽量减少对外部服务的依赖，兼顾速度、隐私与可控性。

### 主要功能

- 图片转换
- 视频转换
- 音频转换
- 图片、视频、音频批量压缩
- 局域网浏览器传输
- 图片转文字（OCR）
- 图片转文档
- EPUB / TXT 电子书导入、转换与阅读

### 技术栈

- SwiftUI
- StoreKit 2
- CocoaPods
- `ffmpeg-kit-ios-full` (`LGPL-3.0`)
- `GCDWebServer`
- `ZIPFoundation`

### 项目结构

```text
parse/
├── parse/               # App 源码
├── parse.xcodeproj      # Xcode 工程
├── parse.xcworkspace    # CocoaPods Workspace
├── Podfile              # CocoaPods 依赖声明
├── Vendor/              # 仓库内固定的第三方配置
└── Pods/                # 已提交的依赖代码与二进制
```

### 本地开发

#### 环境要求

- Xcode 16 或更高版本（建议）
- iOS 18.6 SDK
- CocoaPods 1.16+

#### 安装依赖

```bash
pod install
```

#### 打开项目

```bash
open parse.xcworkspace
```

#### 命令行构建

```bash
xcodebuild -workspace parse.xcworkspace -scheme parse -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

### 许可证与合规说明

- 本项目源码采用 [MIT License](./LICENSE)
- 第三方依赖说明见 [OPEN_SOURCE_NOTICES.md](./OPEN_SOURCE_NOTICES.md)
- FFmpeg / `ffmpeg-kit` 发布注意事项见 [FFMPEG_COMPLIANCE.md](./FFMPEG_COMPLIANCE.md)

### 说明

- 仓库中的 MIT 许可证仅适用于本项目作者编写的源码，不覆盖第三方依赖。
- 第三方库仍然遵循各自许可证条款，分发时需要一并遵守。

## English

### Overview

Parse is an iPhone app focused on on-device processing for file conversion, media compression, LAN transfer, and document workflows. The goal is to keep the core experience local-first, fast, and privacy-conscious.

### Features

- Image conversion
- Video conversion
- Audio conversion
- Batch compression for images, videos, and audio
- Browser-based LAN transfer
- OCR from images
- Image-to-document workflows
- EPUB / TXT import, conversion, and reading

### Tech Stack

- SwiftUI
- StoreKit 2
- CocoaPods
- `ffmpeg-kit-ios-full` (`LGPL-3.0`)
- `GCDWebServer`
- `ZIPFoundation`

### Repository Layout

```text
parse/
├── parse/               # App source code
├── parse.xcodeproj      # Xcode project
├── parse.xcworkspace    # CocoaPods workspace
├── Podfile              # CocoaPods dependencies
├── Vendor/              # Vendored third-party configuration
└── Pods/                # Checked-in dependencies and binaries
```

### Development

#### Requirements

- Xcode 16 or later recommended
- iOS 18.6 SDK
- CocoaPods 1.16+

#### Install dependencies

```bash
pod install
```

#### Open the workspace

```bash
open parse.xcworkspace
```

#### Build from the command line

```bash
xcodebuild -workspace parse.xcworkspace -scheme parse -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

### License and Compliance

- This repository's original source code is licensed under the [MIT License](./LICENSE)
- Third-party dependency notices are listed in [OPEN_SOURCE_NOTICES.md](./OPEN_SOURCE_NOTICES.md)
- FFmpeg / `ffmpeg-kit` release notes and compliance checklist are documented in [FFMPEG_COMPLIANCE.md](./FFMPEG_COMPLIANCE.md)

### Notes

- The MIT license in this repository applies only to source code authored for this project.
- Third-party dependencies remain under their own licenses and must be handled accordingly when distributing the app.
