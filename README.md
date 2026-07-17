# SpritePet Studio / 桌宠工坊

[![Build](https://github.com/herbit2004/sprite-pet-studio/actions/workflows/ci.yml/badge.svg)](https://github.com/herbit2004/sprite-pet-studio/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/herbit2004/sprite-pet-studio?display_name=tag)](https://github.com/herbit2004/sprite-pet-studio/releases/latest)
[![GitHub Pages](https://img.shields.io/badge/website-GitHub%20Pages-10a37f)](https://herbit2004.github.io/sprite-pet-studio/)

[产品网站](https://herbit2004.github.io/sprite-pet-studio/) · [安装帮助](https://herbit2004.github.io/sprite-pet-studio/install.html) · [下载最新版](https://github.com/herbit2004/sprite-pet-studio/releases/latest/download/SpritePetStudio-macOS.zip) · [查看 Releases](https://github.com/herbit2004/sprite-pet-studio/releases)

一个原生 macOS 桌宠运行器与逐帧图集编辑器。它可以同时在桌面上运行多个独立桌宠；每个工程都有自己的图集、动作库、触发器、窗口位置和显示开关。

首次启动即内置 `NARUTO 小鸣人` 与 `DIMOO 心动特调` 两个只读模板，并提供与 Codex v1/v2 宠物图集的互通能力。模板可以直接在桌面运行，也可以复制为完全独立、可逐帧编辑的个人工程。

> 运行环境：macOS 14（Sonoma）或更新版本；从源码构建需要 Xcode Command Line Tools 与 Swift 5.10 或更新版本。

## v0.6.0 更新

- 工程导入不再要求必须点选 `pet.json`：现在可直接选择工程文件夹，或 `pet.json`、`path.json`、`studio.json`、`spritesheet.png` / `.webp` 中的任意一个入口；应用会自动发现同目录的其他文件；
- `spritesheet` 成为唯一必需文件。缺少或无法读取 JSON 时，会根据图集尺寸自动匹配 Codex v1（8 × 9）或 Codex v2（8 × 11）标准布局，并在无法降级时给出具体缺失文件或尺寸错误；
- 动作编辑器的“播放整个动作”、桌宠右键菜单和 Dock 菜单现在都会以临时最高优先级完整播放一遍所选动作，不受该动作保存的循环次数、启用状态、优先级和打断规则影响，也不会修改工程配置；
- 工程身份恢复为一套不可编辑的 ID：同一个 ID 同时用于运行状态、个人工程目录、`pet.json`、`studio.json` 和导出文件夹；用户仍可独立修改显示名称与描述；
- 导入、重复导出和工程复制使用完整写入后再替换的事务流程，避免失败时留下半个工程或旧导出残留。

## v0.5.3 更新

- 修复本地构建与 GitHub Release 的界面差异：CI 和 Release runner 从 macOS 15 升级到 macOS 26，使线上安装包与本机使用同代 SDK 构建；
- “导入工程”等原生控件会使用与本地构建一致的新 SDK 外观，不再被旧 SDK 渲染成传统灰框样式；
- 设置顶栏与页面画布统一使用同一套显式自适应底色，消除顶栏材质与正文背景之间的割裂感。

## v0.5.2 更新

- 设置页面不再直接使用可能随 macOS 版本和窗口材质变深的系统窗口灰色；浅色模式固定为更轻盈的 `#F8F9FB`，深色模式继续使用自适应暗色背景；
- 页面背景标准同步写入设计规范，保证工程库、配置库、通用、事件接口和动作编辑等页面保持一致。

## v0.5.1 更新

- 设置窗口顶栏右侧新增 `Website` 按钮，可直接用默认浏览器打开 SpritePet Studio 的 GitHub Pages 官网。

## v0.5.0 更新

- 将当前已归一化的 `NARUTO 小鸣人 副本` 图集同步为新版内置 NARUTO 模板；模板仍保持只读，复制后即可继续逐帧编辑；
- 离散触发规则新增“触发延迟”，可以让桌宠启动、点击、随机、空闲、定时和系统事件在指定秒数后播放动作；旧工程自动按 `0` 秒兼容；
- 桌宠启动恢复直接显示 SpriteKit 内容，并在首个轮询周期前同步采样当前鼠标位置，避免鼠标静止时方向跟踪动作出现初始化闪烁；
- Dock 图标新增“打开设置”入口；设置页采用更稳定的系统自适应网格、全宽卡片和无刻度黑线的步进滑杆；
- 工程预览与桌面运行共享延迟触发语义，配置序列化与首次安装冒烟测试同步覆盖新字段。

## v0.4.0 更新

- NARUTO 与 DIMOO 两个内置模板采用同一套经过调校的动作播放次数和触发参数，同时保留各自独立的图像帧；
- 桌宠窗口会等 SpriteKit 完成首帧渲染后再显示，避免启动时闪出未初始化的黑色画面；
- 设置顶栏改为无填充的单行分区导航，保留完整点击热区，并提供悬停反馈和当前页面指示；
- 通用设置新增版本卡片，可从 GitHub Pages 的固定 `version.json` 清单检查新版本，并直接打开下载或发布说明。

## v0.3.0 更新

- 内置的 NARUTO 与 DIMOO 改为明确的只读模板：不能改名、编辑动作、归一化或删除，但仍可显示、复制和导出；
- “复制完整工程”会在用户工作区生成独立的 `pet.json`、`studio.json` 与 `spritesheet.png`，副本开放全部编辑能力；
- 个人工程以 `Projects/<id>/` 为独立工作副本保存，启动时会从目录重新发现；模板始终从 App 资源包加载，两类工程可以同时出现在工程库；
- 新增存储冒烟测试并接入 CI，覆盖首次安装、模板只读、复制、重载发现和模板导出。

## v0.2.1 修复

- 修复发布版 App 在 App Translocation 或 Applications 中启动时找不到 SwiftPM 内置资源、随后立即崩溃的问题；
- `make app` 与 `make release` 现在会校验 App 内的 SwiftPM 资源 Bundle 与两个内置工程文件，防止缺少图集的安装包再次发布；
- `make install` 会先退出旧进程并完整替换 Applications 中的 App，确保新版启动和内置工程迁移真正生效。

## v0.2.0 更新

- 首次启动直接提供 `NARUTO 小鸣人` 与 `DIMOO 心动特调`，两个工程均可独立显示与触发动作；
- 逐帧编辑新增横向/纵向缩放、固定参考画布，以及按住 Command 多选帧后的相对批量调整；
- 单帧与整套动作均支持复原参数、归一化写回图集，并在编辑后即时刷新桌宠画面。

## 获取与安装

### 直接安装（发布版）

在仓库的 **Releases** 页面下载 `SpritePetStudio-macOS.zip`，解压后将 `SpritePetStudio.app` 拖入“应用程序（Applications）”文件夹即可。也可以使用上方“下载最新版”的固定链接；它会始终指向最新正式 Release 的同名附件。

Release 同时提供 `SpritePetStudio-macOS.zip.sha256`。下载后可验证文件完整性：

```bash
shasum -a 256 -c SpritePetStudio-macOS.zip.sha256
```

当前发布包使用临时（ad-hoc）签名，尚未通过 Apple Developer ID 公证，因此首次打开时 macOS 会显示“Apple 无法验证”警告。完整的图文流程见双语[安装帮助页面](https://herbit2004.github.io/sprite-pet-studio/install.html)。面向其他用户的无警告正式发布需要 Apple Developer ID 签名与公证。

### 下载后找不到 App，或出现“Apple 无法验证”

下载 ZIP 并不等于安装。请按以下顺序操作：

1. 双击 `SpritePetStudio-macOS.zip` 解压；
2. 在访达选择“前往 → 应用程序”（快捷键 `⇧⌘A`）；
3. 将 `SpritePetStudio.app` 拖入“应用程序”，确保最终路径是 `/Applications/SpritePetStudio.app`；
4. 从“应用程序”中尝试打开一次。出现警告时点击“完成”，不要点“移到废纸篓”；
5. 立即打开“系统设置 → 隐私与安全性”，向下滚动到“安全性”，点击 SpritePetStudio 对应的“仍要打开”；
6. 使用登录密码或 Touch ID 验证，再确认“打开”。

“仍要打开”通常只会在尝试启动后的约一小时内显示；如果没有看到，请再次从“应用程序”启动 App，然后马上回到“隐私与安全性”。如果 Mac 受公司或学校管理，这个选项可能会被管理员策略禁用。

应用直接位于“应用程序”后，才会进入 Spotlight 和 macOS App 索引。可以按 `⌘ Space` 搜索 `SpritePetStudio`，或从访达的“应用程序”打开后将图标固定到 Dock。

只有在确认文件来自本仓库的正式 Release，并且 SHA-256 校验通过后，才可以使用下面的高级备用方式清除这个 App 的隔离标记：

```bash
xattr -dr com.apple.quarantine "/Applications/SpritePetStudio.app"
open "/Applications/SpritePetStudio.app"
```

不要对来源不明的软件执行此命令。Apple 官方参考：[覆盖安全设置打开 App](https://support.apple.com/guide/mac-help/open-an-app-by-overriding-security-settings-mh40617/mac)、[把 App 加入 Spotlight](https://support.apple.com/guide/mac-help/open-apps-in-spotlight-mh35840/mac)。

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

# 验证首次安装、模板只读、复制与个人工程重载
make test

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
| Build | `.github/workflows/ci.yml` | 推送到 `main`、Pull Request、手动触发 | 在 macOS Runner 上执行 `make build` 与 `make test` |
| Release macOS app | `.github/workflows/release.yml` | 推送任意 `v*` Tag、手动触发 | 编译 App，创建或更新 Release，上传 ZIP 和 SHA-256 |
| Deploy GitHub Pages | `.github/workflows/pages.yml` | `main` 中的 `site/**` 或 Pages 工作流变化、手动触发 | 将 `site/` 部署到 GitHub Pages |

### 发布一个新版本

版本使用语义化 Tag，例如 `vX.Y.Z`。Tag 必须与 `Config/Info.plist` 中的 `CFBundleShortVersionString` 完全一致，否则 Release 工作流会主动失败，避免版本号与二进制不一致。

```bash
# 1. 把 VERSION 换成 Config/Info.plist 中的新版本号并提交到 main
VERSION=X.Y.Z
git add Config/Info.plist
git commit -m "Release SpritePet Studio v${VERSION}"
git push origin main

# 2. 在准备发布的 main 提交上创建并推送 Tag
git tag -a "v${VERSION}" -m "SpritePet Studio v${VERSION}"
git push origin "v${VERSION}"
```

推送 Tag 后，Release 工作流自动执行 `make release`，并创建标题为 `SpritePet Studio vX.Y.Z` 的 GitHub Release。发布说明由 GitHub 根据上一个 Tag 以来的 Pull Request 自动生成，分类规则位于 `.github/release.yml`。

每个正式 Release 发布的是：

- `SpritePetStudio-macOS.zip`：可解压并拖入 Applications 的完整 App；
- `SpritePetStudio-macOS.zip.sha256`：下载完整性校验文件；
- GitHub 自动生成的 Source code ZIP/TAR：这是源码快照，不是可安装 App。

如果工作流中断，可以在 GitHub Actions 页面重新运行，或者通过 CLI 指定已经存在的 Tag：

```bash
gh workflow run release.yml -f tag=vX.Y.Z
```

重复运行不会创建重复 Release；工作流会覆盖同名 ZIP 和校验文件。

> 当前自动产物使用 ad-hoc 签名，适合开源测试分发。若要让其他 Mac 无警告安装，需要配置 Apple Developer ID 证书、签名 Secret 和 Apple 公证步骤。

### GitHub Pages

产品网站源码位于 `site/`，不依赖 Node.js 或外部构建工具。合并到 `main` 后，Pages 工作流会把该目录作为静态站点发布到：

```text
https://herbit2004.github.io/sprite-pet-studio/
```

页面中的下载按钮先使用稳定的 `releases/latest/download/SpritePetStudio-macOS.zip` 地址，并通过 GitHub Releases API 补充最新版本号和文件大小。即使 API 暂时不可用，下载链接仍然有效。

App 内的“检查更新”读取同一站点上的固定清单：

```text
https://herbit2004.github.io/sprite-pet-studio/version.json
```

`site/version.json` 中的 `version` 必须与 `Config/Info.plist` 和发布 Tag 保持一致；`downloadURL` 指向稳定的 latest-release 附件，`releaseNotesURL` 指向当前版本说明。当前检查器只获取这份公开 JSON，不上传设备信息或用户工程。

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
│   ├── install-local.sh                  # 打包后复制到 /Applications
│   └── test-workspace.sh                 # 模板与个人工程存储冒烟测试
├── Tests/WorkspaceStoreSmoke/            # 首次安装、复制、重载与导出验证
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
- 内置只读 Codex v1 / v2 配置：v1 为 8 列 × 9 排，v2 为 8 列 × 11 排；每格均为 192 × 208 px
- 工程导入支持选择文件夹、JSON 或 `spritesheet.png` / `.webp`；缺少配置时可按标准 v1/v2 图集尺寸恢复
- 工程库支持透明空工程、新建、复制、修改显示名称与描述、删除、配置关联状态和交互预览；内部工程 ID 始终只读
- 内置模板与个人工程分层管理；模板只读运行，复制后在用户工作区生成可编辑的完整工程
- 逐帧预览、整体缩放、横向/纵向缩放、X/Y 位移、停留时间调整；支持 ⌘ 多选帧并按各帧原值批量增减，可单帧 PNG 导入/导出
- “归一化并写入图集”会将逐帧草稿缩放和位移永久烘焙到 `spritesheet.png`；“复原参数”只清除草稿参数
- 鼠标靠近、16 方向视线、单击、双击、右击、拖动、随机、空闲、定时和系统事件触发；离散事件可单独设置触发延迟
- 动作编辑器、桌宠右键菜单和 Dock 菜单均可临时以最高优先级完整预览任意动作一遍
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
- 工程 ID 在创建或导入时确定，此后不可编辑；个人工程目录名、两个 JSON 内的 ID 与导出文件夹名始终一致。
- 导入时可以选择整个工程文件夹或上述任意文件。只有图集必需；JSON 缺失时应用会尝试按 Codex v1/v2 标准尺寸恢复布局。
- 使用 Codex v2 配置时，`pet.json` 和 `spritesheet.png` 可直接交给 Codex；Codex 会忽略附加的 `studio.json`。
- 自定义图集配置必须保留 `studio.json`，以记录动作布局；这类工程不保证被 Codex 固定协议识别。
- 图集格位、配置库与归一化规则的完整说明见 [工程格式文档](docs/PROJECT_FORMAT.md)。

## 用户数据与备份

源码仓库不会保存你在 App 内新建、导入或调整过的桌宠工程。运行时数据保存在：

```text
~/Library/Application Support/SpritePetStudio/
├── state.json
└── Projects/
    └── <个人工程 ID>/
        ├── pet.json
        ├── studio.json
        └── spritesheet.png
```

App 内置模板不复制到这个目录，它们始终从 App 包读取；只有新建、导入或由模板复制出的个人工程会保存在 `Projects/`。若要迁移或备份桌宠，请在 App 内导出工程目录，或备份上述 `SpritePetStudio` 文件夹。删除 App 不会自动删除这里的工程数据。

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

应用代码使用 [MIT License](LICENSE)。内置的 `NARUTO 小鸣人` 与 `DIMOO 心动特调` 图集属于角色示例素材，不包含在 MIT 授权范围内；公开分发或发布到应用商店前，请确认素材授权，或替换为你拥有完整权利的角色和素材。
