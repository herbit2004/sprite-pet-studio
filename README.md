# SpritePet Studio / 桌宠工坊

[![Build](https://github.com/herbit2004/sprite-pet-studio/actions/workflows/ci.yml/badge.svg)](https://github.com/herbit2004/sprite-pet-studio/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/herbit2004/sprite-pet-studio?display_name=tag)](https://github.com/herbit2004/sprite-pet-studio/releases/latest)
[![GitHub Pages](https://img.shields.io/badge/website-GitHub%20Pages-10a37f)](https://herbit2004.github.io/sprite-pet-studio/)

[产品网站](https://herbit2004.github.io/sprite-pet-studio/) · [下载最新版](https://github.com/herbit2004/sprite-pet-studio/releases/latest/download/SpritePetStudio-macOS.zip) · [查看 Releases](https://github.com/herbit2004/sprite-pet-studio/releases)

一个原生 macOS 桌宠运行器与逐帧图集编辑器。它可以同时在桌面上运行多个独立桌宠；每个工程都有自己的图集、动作库、触发器、窗口位置和显示开关。

内置 `little-naruto` 示例工程，并提供与 Codex v2 宠物图集的互通能力。

> 运行环境：macOS 14（Sonoma）或更新版本；从源码构建需要 Xcode Command Line Tools 与 Swift 5.10 或更新版本。

## 获取与安装

### 直接安装（发布版）

在仓库的 **Releases** 页面下载 `SpritePetStudio-macOS.zip`，解压后将 `SpritePetStudio.app` 拖入“应用程序（Applications）”文件夹即可。也可以使用上方“下载最新版”的固定链接；它会始终指向最新正式 Release 的同名附件。

Release 同时提供 `SpritePetStudio-macOS.zip.sha256`。下载后可验证文件完整性：

```bash
shasum -a 256 -c SpritePetStudio-macOS.zip.sha256
```

当前本地打包版本使用临时（ad-hoc）签名，适合本机开发与测试。若 macOS 阻止首次打开，可在 Finder 中按住 `Control` 点按 App，选择“打开”。面向其他用户的正式发布应使用 Apple Developer ID 签名并完成公证。

### 从源码获取并运行

```bash
git clone <你的 GitHub 仓库地址>
cd sprite-pet-studio
make build
swift run SpritePetStudio
```

如果尚未安装开发工具，先执行：

```bash
xcode-select --install
```

## 打包与本地安装

在软件工程根目录执行：

```bash
# 编译 Debug 版本，检查是否可以通过编译
make build

# 编译 Release 版本并生成 macOS App
make app

# 生成用于 GitHub Release 的 App ZIP 与 SHA-256 文件
make release

# 本地打开打包结果
open dist/SpritePetStudio.app

# 重新打包、复制到 /Applications 并启动
make install
```

各命令的产物如下：

```text
make app
└── dist/SpritePetStudio.app

make release
├── dist/SpritePetStudio.app
├── dist/SpritePetStudio-macOS.zip
└── dist/SpritePetStudio-macOS.zip.sha256
```

`make install` 的目标路径是：

```text
/Applications/SpritePetStudio.app
```

若复制到 `/Applications` 时被系统拒绝，请以管理员身份重试该命令，或在 Finder 中手动将 `dist/SpritePetStudio.app` 拖入“应用程序”文件夹。

其他常用命令：

```bash
# 清除 Swift 编译缓存和打包产物
make clean

# 直接用 SwiftPM 运行开发版
swift run SpritePetStudio
```

### 打包脚本做了什么

`make app` 调用 `scripts/build-app.sh`，依次执行：

1. 用 SwiftPM 的 Release 配置编译 `SpritePetStudio` 和 `spritepetctl`；
2. 创建标准 `.app` Bundle，复制可执行文件、资源包、`Info.plist` 和 App 图标；
3. 将 `spritepetctl` 一并放入 App 的 `Contents/MacOS`；
4. 使用 ad-hoc 签名完成本地可运行的 App。

`make release` 再调用 `scripts/package-release.sh`，使用 macOS `ditto` 将整个 App Bundle 压缩为 ZIP，并生成 SHA-256 校验文件。使用 `ditto` 是为了保留 macOS Bundle 的目录和扩展属性；不要在 Finder 中随意重新压缩后替换自动发布附件。

## GitHub Actions 与发布流程

仓库包含三条工作流：

| 工作流 | 文件 | 触发条件 | 结果 |
| --- | --- | --- | --- |
| Build | `.github/workflows/ci.yml` | 推送到 `main`、Pull Request、手动触发 | 在 macOS Runner 上执行 `make build` |
| Release macOS app | `.github/workflows/release.yml` | 推送任意 `v*` Tag、手动触发 | 编译 App，创建或更新 Release，上传 ZIP 和 SHA-256 |
| Deploy GitHub Pages | `.github/workflows/pages.yml` | `main` 中的 `site/**` 或 Pages 工作流变化、手动触发 | 将 `site/` 部署到 GitHub Pages |

### 发布一个新版本

版本使用语义化 Tag，例如 `v0.1.0`。Tag 必须与 `Config/Info.plist` 中的 `CFBundleShortVersionString` 完全一致，否则 Release 工作流会主动失败，避免版本号与二进制不一致。

```bash
# 1. 修改 Config/Info.plist 中的版本号并提交到 main
git add Config/Info.plist
git commit -m "Bump version to 0.2.0"
git push origin main

# 2. 在准备发布的 main 提交上创建并推送 Tag
git tag -a v0.2.0 -m "SpritePet Studio v0.2.0"
git push origin v0.2.0
```

推送 Tag 后，Release 工作流自动执行 `make release`，并创建标题为 `SpritePet Studio v0.2.0` 的 GitHub Release。发布说明由 GitHub 根据上一个 Tag 以来的 Pull Request 自动生成，分类规则位于 `.github/release.yml`。

每个正式 Release 发布的是：

- `SpritePetStudio-macOS.zip`：可解压并拖入 Applications 的完整 App；
- `SpritePetStudio-macOS.zip.sha256`：下载完整性校验文件；
- GitHub 自动生成的 Source code ZIP/TAR：这是源码快照，不是可安装 App。

如果工作流中断，可以在 GitHub Actions 页面重新运行，或者通过 CLI 指定已经存在的 Tag：

```bash
gh workflow run release.yml -f tag=v0.2.0
```

重复运行不会创建重复 Release；工作流会覆盖同名 ZIP 和校验文件。

> 当前自动产物使用 ad-hoc 签名，适合开源测试分发。若要让其他 Mac 无警告安装，需要配置 Apple Developer ID 证书、签名 Secret 和 Apple 公证步骤。

### GitHub Pages

产品网站源码位于 `site/`，不依赖 Node.js 或外部构建工具。合并到 `main` 后，Pages 工作流会把该目录作为静态站点发布到：

```text
https://herbit2004.github.io/sprite-pet-studio/
```

页面中的下载按钮先使用稳定的 `releases/latest/download/SpritePetStudio-macOS.zip` 地址，并通过 GitHub Releases API 补充最新版本号和文件大小。即使 API 暂时不可用，下载链接仍然有效。

## 工程结构

```text
sprite-pet-studio/
├── Package.swift                         # Swift Package 定义、最低系统版本和构建目标
├── Makefile                              # build / app / install / clean 的快捷入口
├── Config/
│   └── Info.plist                        # App Bundle 元数据、URL Scheme 等
├── Sources/
│   ├── SpritePetStudio/
│   │   ├── App/                          # SwiftUI 入口、全局模型与窗口协调
│   │   ├── Core/                         # 数据模型、工程存储、Codex v2 图集协议
│   │   ├── Engine/                       # SpriteKit 场景、图集切片与帧渲染
│   │   ├── Events/                       # 系统事件监听与动作触发规则
│   │   ├── UI/                           # 设置、工程库、动作编辑器等界面
│   │   └── Resources/BuiltinProjects/    # 随 App 内置的示例桌宠工程
│   └── SpritePetCtl/                     # spritepetctl 命令行事件触发工具
├── scripts/
│   ├── build-app.sh                      # Release 构建、装配 App、临时签名
│   ├── package-release.sh                # 生成 Release ZIP 和 SHA-256
│   └── install-local.sh                  # 打包后复制到 /Applications
├── site/                                 # GitHub Pages 静态产品网站
├── .github/
│   ├── workflows/                        # CI、Release 与 Pages 工作流
│   └── release.yml                       # 自动 Release Notes 分类
├── docs/
│   ├── PROJECT_FORMAT.md                 # 图集、配置库和工程格式
│   └── DESIGN_SYSTEM.md                  # 设置窗口的 UI 设计规范
├── dist/                                 # 打包输出（不纳入 Git）
└── .build/                               # SwiftPM 缓存（不纳入 Git）
```

应用的核心分层是：`Core` 负责保存工程和配置，`Engine` 根据图集渲染桌宠，`Events` 将鼠标/系统事件映射到动作，`UI` 提供可视化编辑与项目管理。

## 功能概览

- 同时显示零个、一个或多个透明、无边框、跨桌面空间的 SpriteKit 桌宠窗口
- 每个工程独立保存图集、桌面位置、显示开关、动作库和触发规则
- 30 / 60 / 120 FPS 渲染；动作可设置原画帧率、指定播放次数或持续循环、优先级和打断规则
- 配置库可定义动作顺序、标签键、帧数、占用排数和单格尺寸；图集网格自动计算
- 内置只读 Codex v2 配置：8 列 × 11 排、每格 192 × 208 px
- 工程库支持透明空工程、新建、复制、重命名、删除、配置关联状态和交互预览
- 逐帧预览、缩放、X/Y 位移、停留时间调整；可单帧 PNG 导入/导出
- “归一化并写入图集”会将逐帧草稿大小和位移永久烘焙到 `spritesheet.png`
- 鼠标靠近、16 方向视线、单击、双击、右击、拖动、随机、空闲、定时和系统事件触发
- 菜单栏可快速显示/隐藏桌宠、播放动作和打开设置

## 桌宠工程格式

每个导出工程以一张完整图集为核心：

```text
my-pet/
├── pet.json          # 工程 ID、显示名称和图集路径
├── spritesheet.png   # 唯一的完整图集；不保存独立帧目录
└── studio.json       # 动作、触发器、逐帧草稿调整与配置快照
```

- `spritesheet.png` 是所有帧的唯一来源；单帧 PNG 仅用于导入/导出编辑。
- 使用 Codex v2 配置时，`pet.json` 和 `spritesheet.png` 可直接交给 Codex；Codex 会忽略附加的 `studio.json`。
- 自定义图集配置必须保留 `studio.json`，以记录动作布局；这类工程不保证被 Codex 固定协议识别。
- 图集格位、配置库与归一化规则的完整说明见 [工程格式文档](docs/PROJECT_FORMAT.md)。

## 用户数据与备份

源码仓库不会保存你在 App 内新建、导入或调整过的桌宠工程。运行时数据保存在：

```text
~/Library/Application Support/SpritePetStudio/
├── state.json
└── Projects/
    └── <每个桌宠的工作副本>/
```

若要迁移或备份桌宠，请在 App 内导出工程目录，或备份上述 `SpritePetStudio` 文件夹。删除 App 不会自动删除这里的工程数据。

## 外部动作触发

安装 App 后，可以使用 URL Scheme 触发名称事件：

```bash
open 'spritepet://trigger/task-running'
open 'spritepet://trigger/review'
open 'spritepet://trigger/failed'
open 'spritepet://trigger/idle'
```

打包 App 同时带有命令行工具：

```bash
/Applications/SpritePetStudio.app/Contents/MacOS/spritepetctl trigger task-running
```

## 许可与角色素材

应用代码使用 [MIT License](LICENSE)。`little-naruto` 图集是用户提供的同人角色素材，不包含在 MIT 授权范围内；公开分发或发布到应用商店前，请替换为你拥有完整权利的角色和素材。
