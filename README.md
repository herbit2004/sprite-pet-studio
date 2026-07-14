# SpritePet Studio / 桌宠工坊

一个原生 macOS 桌宠运行器与逐帧图集编辑器。它可以同时在桌面上运行多个独立桌宠；每个工程都有自己的图集、动作库、触发器、窗口位置和显示开关。

内置 `little-naruto` 示例工程，并提供与 Codex v2 宠物图集的互通能力。

> 运行环境：macOS 14（Sonoma）或更新版本；从源码构建需要 Xcode Command Line Tools 与 Swift 5.10 或更新版本。

## 获取与安装

### 直接安装（发布版）

当本仓库发布 GitHub Release 后，在仓库的 **Releases** 页面下载 `SpritePetStudio.app.zip`，解压后将 `SpritePetStudio.app` 拖入“应用程序（Applications）”文件夹即可。

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

# 本地打开打包结果
open dist/SpritePetStudio.app

# 重新打包、复制到 /Applications 并启动
make install
```

打包产物为 `dist/SpritePetStudio.app`。`make install` 的目标路径是：

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
│   └── install-local.sh                  # 打包后复制到 /Applications
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
