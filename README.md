# Roamie — 像素旅行动图 iOS App

记录你的旅行路线，生成像素风格地图动图，一键分享到微信、微博、Instagram。

## 功能

- **城市搜索 / GPS 定位**：手动搜索城市或自动读取当前位置
- **多站点行程管理**：拖动排序、添加/删除城市
- **打卡照片上传**：每个城市可上传多张打卡照片
- **像素风格地图**：像素地形图 / 像素行政区划图（两种风格）
- **像素角色**：旗帜小车 🚗 / 像素飞机 ✈️ / 蒸汽火车 🚂 / 背包旅者 🧍
- **两种导出模式**：
  - **GIF 动图**（480×480，无照片，可分享到任意平台）
  - **含照片视频 MP4**（720×720，角色到站弹出打卡照，仅在上传了照片时显示）
- **社交分享**：iOS 系统分享 / 微信 / 微博 / Instagram

## 本地运行

### 前提

- macOS 14+
- Xcode 15+
- iOS 17+ 设备或模拟器
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（用于生成 .xcodeproj）

### 步骤

```bash
# 1. 克隆仓库
git clone <repo-url>
cd Roamie

# 2. 生成 Xcode 项目
brew install xcodegen
xcodegen generate

# 3. 打开项目
open Roamie.xcodeproj
```

然后在 Xcode 中选择目标设备，按 ⌘R 运行。

## 精灵图资源

项目中的像素角色精灵图（`car_flag@2x.png`、`plane@2x.png`、`train@2x.png`、`traveler@2x.png`）  
需要放置在对应的 `Assets.xcassets/Sprites/*.imageset/` 目录中。

每张精灵图格式：
- 尺寸：128×32 px（4帧 × 32×32 px 横向排列）
- 分辨率：@2x（即实际文件为 256×64 px）
- 格式：PNG（支持透明）

可使用 [Piskel](https://www.piskelapp.com/) 或 [Aseprite](https://www.aseprite.org/) 绘制像素风格精灵图。

## 架构

```
SwiftUI + SwiftData (iOS 17+)
├── Models: Trip, Waypoint (SwiftData @Model)
├── Services
│   ├── LocationService (actor)     — CoreLocation GPS
│   ├── SearchService (@Observable) — MKLocalSearch
│   ├── PixelMapService             — MKMapSnapshot + CIPixellate 管线
│   ├── AnimationRenderService      — CGContext 帧合成引擎
│   ├── VideoExportService          — AVAssetWriter H.264
│   ├── GIFExportService            — ImageIO CGImageDestination
│   └── ShareService                — UIActivityViewController + URL Scheme
├── ViewModels (@Observable)
└── Views (SwiftUI)
```

**零第三方依赖** — 全部使用 Apple 原生框架。

## 开发路线

- [x] Phase 1: 数据层 + 导航 + 照片管理
- [ ] Phase 2: GPS 定位 + 像素地图预览
- [ ] Phase 3: 像素动画引擎（GIF 模式）
- [ ] Phase 4: 视频导出 + 照片弹出动画
- [ ] Phase 5: UI 打磨 + TestFlight
