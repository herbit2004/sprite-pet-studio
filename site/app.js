const repository = "herbit2004/sprite-pet-studio";
const fallbackDownload = `https://github.com/${repository}/releases/latest/download/SpritePetStudio-macOS.zip`;

const translations = {
  en: {
    pageTitle: "SpritePet Studio · Desktop companions, built your way",
    metaDescription: "SpritePet Studio is a native macOS desktop pet runner and interactive sprite atlas editor.",
    ogDescription: "Turn sprite atlases, animations, and system events into companions that live on your desktop.",
    homeLabel: "Back to home",
    productHomeLabel: "Back to product page",
    navLabel: "Main navigation",
    navFeatures: "Features",
    navWorkflow: "Workflow",
    navFormat: "Project format",
    installHelp: "Install help",
    installHelpLabel: "Open installation help",
    backToProduct: "Product",
    heroEyebrow: "Native macOS · Open-source pet studio",
    heroTitle: "Bring characters<br /><em>to life on your desktop.</em>",
    heroLede: "Start with NARUTO 小鸣人 and DIMOO Heartfelt Mix already in your library. Edit every frame, compose any animation, and connect mouse or system events.",
    downloadMac: "Download for macOS",
    viewSource: "View source",
    appInfo: "Application information",
    latestVersion: "Latest version",
    systemRequirement: "System requirement",
    nativeBuild: "Native build",
    windowTitle: "SpritePet Studio Settings",
    live: "Live",
    projectLibrary: "Project Library",
    mouseNearChip: "mouse · near",
    actionIdleChip: "action · idle",
    petAlt: "Little Naruto desktop pet preview",
    framePreviewLabel: "Animation frame preview",
    running: "running",
    sixFrames: "6 frames",
    eventInterface: "Event interface",
    mouseNear: "Mouse nearby",
    atlasSlot: "Atlas slot",
    normalized: "Normalized",
    coreTech: "Core technologies",
    codexAtlas: "Codex v2 atlas",
    includedProjects: "2 included projects",
    featuresIndex: "01 / Features",
    featuresTitle: "One framework.<br />Every kind of character.",
    featuresIntro: "Run, edit, and orchestrate events in one native application.",
    frameEditor: "Frame editor",
    frameTitle: "Make every frame<br />land exactly right.",
    frameDesc: "Command-select frames, apply relative scale and position changes, and work against a fixed viewport before normalizing back into the atlas.",
    frameOne: "Frame 01",
    scale: "Scale · X · Y",
    normalize: "Normalize",
    eventEngine: "Event engine",
    eventTitle: "Give every motion a reason to happen.",
    eventDesc: "Mouse distance, clicks, dragging, idle time, randomness, timers, and system events can all start an animation.",
    pet: "PET",
    mouse: "mouse",
    idle: "idle",
    system: "system",
    multiProject: "Multi-project",
    multiTitle: "One companion, two, or a whole crew.",
    multiDesc: "NARUTO 小鸣人 and DIMOO Heartfelt Mix arrive as complete projects, while every additional pet keeps its own atlas, triggers, position, and visibility.",
    openFormat: "Open format",
    formatCardTitle: "One big PNG. Freedom in both directions.",
    formatCardDesc: "Keep full compatibility with the fixed Codex v2 atlas while defining custom animations, frame counts, and grids.",
    workflowIndex: "02 / Workflow",
    workflowTitle: "From atlas to desktop<br />in three simple moves.",
    importTitle: "Import a project",
    importDesc: "Choose <code>pet.json</code>. The app loads the atlas and Studio configuration beside it.",
    composeTitle: "Compose animations",
    composeDesc: "Tune frames, set repeat counts and priorities, then choose an event trigger for each animation.",
    desktopTitle: "Bring it to the desktop",
    desktopDesc: "Turn on project visibility. Every pet runs, moves, and responds to events independently.",
    formatIndex: "03 / Project format",
    formatTitle: "Transparent and readable.<br />No hidden asset library.",
    formatIntro: "An exported project is simply JSON configuration plus one complete PNG—easy to back up and ready for other tools.",
    formatBadge: "Codex v2 compatible",
    formatSimpleTitle: "Keep it simple. Keep it free.",
    formatSimpleDesc: "<code>pet.json</code> describes identity and atlas location, <code>spritesheet.png</code> holds every frame, and <code>studio.json</code> records richer animation and trigger logic.",
    viewDocs: "Read the format docs",
    structureLabel: "Project directory structure",
    identityComment: "# identity and atlas path",
    atlasComment: "# the complete atlas",
    studioComment: "# animation and event logic",
    ready: "Ready when you are",
    downloadTitle: "Make a little room<br />for a lot of personality.",
    latestInline: "Latest",
    macRequirement: "macOS 14 or later",
    downloadProduct: "Download SpritePet Studio",
    privacyLine: "Open source · Runs locally · No data collection",
    footerTagline: "Native desktop companions, built frame by frame.",
    releases: "Releases",
    installPageTitle: "Install SpritePet Studio on macOS",
    installMetaDescription: "Install SpritePet Studio on macOS, add it to Applications, and safely handle the first-launch security warning.",
    installOgDescription: "A bilingual guide for installing SpritePet Studio and handling macOS Gatekeeper.",
    installEyebrow: "Install · macOS",
    installTitle: "From download<br /><em>to a real Mac app.</em>",
    installIntro: "A ZIP in Downloads has not been installed yet. Move SpritePetStudio.app to Applications first, then approve its first launch in macOS Privacy & Security.",
    downloadLatest: "Download latest release",
    solveWarning: "Solve the security warning",
    officialSource: "Use only the official GitHub Release and verify its checksum before overriding macOS security.",
    finderTitle: "Applications — Finder",
    searchable: "Searchable",
    installFlowIndex: "01 / Put it in the right place",
    installFlowTitle: "Three steps make it<br />a searchable Mac app.",
    installFlowIntro: "Downloads is only a holding area. macOS adds third-party apps to its app browser and Spotlight after they are placed in Applications.",
    unzipTitle: "Unzip the release",
    unzipDesc: "Open Downloads and double-click <code>SpritePetStudio-macOS.zip</code>. You should now see <code>SpritePetStudio.app</code>.",
    moveTitle: "Move the app",
    moveDesc: "In Finder, choose <strong>Go → Applications</strong> (⇧⌘A), then drag <code>SpritePetStudio.app</code> into that folder.",
    launchTitle: "Open from Applications",
    launchDesc: "Launch it once from Applications. It can then appear in Spotlight and the macOS Apps view; drag its icon to the Dock if you want it pinned.",
    finderTipTitle: "Can’t find it?",
    finderTipBody: "Check that the exact path is <code>/Applications/SpritePetStudio.app</code>—not the ZIP and not an app still inside Downloads. Then press ⌘ Space and search for <strong>SpritePetStudio</strong>.",
    securityIndex: "02 / First launch",
    securityTitle: "The warning is expected.<br />The source still matters.",
    securityIntro: "The current open-source build is ad-hoc signed and has not been notarized with an Apple Developer ID. macOS therefore cannot verify its developer automatically.",
    gatekeeperCardTitle: "Open it through Privacy & Security",
    securityStep1: "Try to open SpritePetStudio from Applications once. In the warning shown above, click Done—not Move to Trash.",
    securityStep2: "Open <strong>System Settings → Privacy & Security</strong>, then scroll down to the Security section.",
    securityStep3: "Find the message about SpritePetStudio and click <strong>Open Anyway</strong>. Apple keeps this button available for about one hour after the failed launch.",
    securityStep4: "Authenticate with your password or Touch ID, then confirm <strong>Open</strong>. macOS saves this app as an exception.",
    appleSecurityGuide: "Read Apple’s official security guide",
    verifyKicker: "Before you override",
    verifyTitle: "Verify the download.",
    verifyDesc: "Download both release files into the same folder, then run this command in Terminal. Continue only when it prints “OK”.",
    downloadAppFile: "App ZIP",
    downloadChecksum: "Checksum",
    whyKicker: "Why this happens",
    whyTitle: "Not a Finder problem.",
    whyDesc: "The alert is Gatekeeper reacting to an unnotarized build. Moving the app to Applications solves indexing; approving it in Privacy & Security solves first launch.",
    troubleIndex: "03 / Troubleshooting",
    troubleTitle: "Still stuck?<br />Check these first.",
    openAnywayMissing: "“Open Anyway” is missing",
    openAnywayMissingBody: "Try launching the app from Applications again, dismiss the warning, and immediately reopen Privacy & Security. On a managed work or school Mac, administrator policy may remove this option.",
    spotlightMissing: "The app is not in Spotlight",
    spotlightMissingBody: "Confirm the app is directly inside Applications, open it once from Finder, then wait a moment and search its exact name. A ZIP or an app left in Downloads is not installed.",
    terminalFallback: "Advanced fallback for a verified release",
    terminalWarning: "Only after verifying the official release checksum, the commands below remove the quarantine flag from this one app and open it. Never use this on an untrusted download.",
    appleAppsGuide: "Apple: add apps to Spotlight",
    reportIssue: "Report an issue on GitHub",
    readyToInstall: "Ready to install",
    installDownloadTitle: "Put your next companion<br />in Applications.",
    installDownloadMeta: "Official GitHub Release · macOS 14 or later",
    installSafetyLine: "Verify · Move to Applications · Approve once",
    languageTarget: "中文",
    languageAction: "Switch to Chinese",
  },
  zh: {
    pageTitle: "SpritePet Studio · 让桌宠真正活起来",
    metaDescription: "SpritePet Studio 是一款原生 macOS 桌宠运行器与可交互图集编辑器。",
    ogDescription: "把角色图集、动作和系统事件，组装成真正生活在桌面上的小伙伴。",
    homeLabel: "回到首页",
    productHomeLabel: "返回产品页",
    navLabel: "主导航",
    navFeatures: "能力",
    navWorkflow: "工作流",
    navFormat: "工程格式",
    installHelp: "安装帮助",
    installHelpLabel: "打开安装帮助",
    backToProduct: "产品页",
    heroEyebrow: "原生 macOS · 开源桌宠工作台",
    heroTitle: "让角色真正<br /><em>活在桌面上。</em>",
    heroLede: "下载后即可在工程库看到 NARUTO 小鸣人与 DIMOO 心动特调。继续编辑每一帧、组合任意动作，并绑定鼠标与系统事件。",
    downloadMac: "下载 macOS 版",
    viewSource: "查看源码",
    appInfo: "应用信息",
    latestVersion: "最新版本",
    systemRequirement: "系统要求",
    nativeBuild: "原生构建",
    windowTitle: "桌宠工坊设置",
    live: "运行中",
    projectLibrary: "工程库",
    mouseNearChip: "鼠标 · 靠近",
    actionIdleChip: "动作 · 空闲",
    petAlt: "小鸣人桌宠预览",
    framePreviewLabel: "动作帧预览",
    running: "执行任务",
    sixFrames: "6 帧",
    eventInterface: "事件接口",
    mouseNear: "鼠标靠近",
    atlasSlot: "图集格位",
    normalized: "已归一化",
    coreTech: "核心技术",
    codexAtlas: "Codex v2 图集",
    includedProjects: "内置 2 个完整工程",
    featuresIndex: "01 / 能力",
    featuresTitle: "一套框架，容纳<br />每一种角色性格。",
    featuresIntro: "运行、编辑和事件编排在同一个原生应用里完成。",
    frameEditor: "逐帧编辑器",
    frameTitle: "把每一帧调到<br />刚刚好的位置。",
    frameDesc: "按住 Command 多选帧，在固定视口中按各帧原值批量增减缩放与位移，再归一化回整张图集。",
    frameOne: "第 1 帧",
    scale: "整体 · 横向 · 纵向",
    normalize: "归一化",
    eventEngine: "事件引擎",
    eventTitle: "让动作有触发的理由。",
    eventDesc: "鼠标距离、点击、拖动、空闲、随机、定时与系统事件，都可以成为一套动作的开场。",
    pet: "桌宠",
    mouse: "鼠标",
    idle: "空闲",
    system: "系统",
    multiProject: "多工程",
    multiTitle: "一只、两只，或者整支小队。",
    multiDesc: "NARUTO 小鸣人与 DIMOO 心动特调作为完整工程随 App 提供；新增桌宠仍各自保存图集、触发器、位置与显示状态。",
    openFormat: "开放格式",
    formatCardTitle: "一张大 PNG，双向互通。",
    formatCardDesc: "保留 Codex v2 固定图集兼容，同时允许自定义动作数量、帧数和图集网格。",
    workflowIndex: "02 / 工作流",
    workflowTitle: "从图集到桌面，<br />只有三个动作。",
    importTitle: "导入工程",
    importDesc: "选择 <code>pet.json</code>，应用读取同目录的大图集和 Studio 配置。",
    composeTitle: "编排动作",
    composeDesc: "逐帧微调，设置播放次数与优先级，再为动作选择触发事件。",
    desktopTitle: "放到桌面",
    desktopDesc: "开启工程显示；每只桌宠独立运行、移动并响应自己的事件。",
    formatIndex: "03 / 工程格式",
    formatTitle: "透明、可读，<br />没有隐藏的素材库。",
    formatIntro: "导出的工程就是 JSON 配置加一张完整 PNG，易于备份，也方便继续交给其他工具。",
    formatBadge: "兼容 Codex v2",
    formatSimpleTitle: "保留简单，才能保持自由。",
    formatSimpleDesc: "<code>pet.json</code> 描述身份与图集位置，<code>spritesheet.png</code> 保存全部画面，<code>studio.json</code> 则记录更丰富的动作和触发逻辑。",
    viewDocs: "查看格式文档",
    structureLabel: "工程目录结构",
    identityComment: "# 身份与图集路径",
    atlasComment: "# 唯一完整图集",
    studioComment: "# 动作与事件逻辑",
    ready: "随时准备好",
    downloadTitle: "把桌面留一小块，<br />给一个有性格的角色。",
    latestInline: "最新版本",
    macRequirement: "macOS 14 或更新版本",
    downloadProduct: "下载 SpritePet Studio",
    privacyLine: "开源 · 本地运行 · 不收集数据",
    footerTagline: "原生桌宠，一帧一帧构建。",
    releases: "发布版本",
    installPageTitle: "在 macOS 上安装 SpritePet Studio",
    installMetaDescription: "把 SpritePet Studio 安装到 macOS 的应用程序文件夹，并安全处理首次启动时的系统拦截提示。",
    installOgDescription: "SpritePet Studio 的双语安装、应用索引与 macOS Gatekeeper 处理指南。",
    installEyebrow: "安装 · macOS",
    installTitle: "从下载文件<br /><em>变成真正的 Mac App。</em>",
    installIntro: "下载文件夹里的 ZIP 还不算安装。请先把 SpritePetStudio.app 移入“应用程序”，再到 macOS 的“隐私与安全性”中允许第一次启动。",
    downloadLatest: "下载最新版本",
    solveWarning: "解决系统拦截提示",
    officialSource: "只有从官方 GitHub Release 下载并核验校验值后，才建议覆盖 macOS 的安全拦截。",
    finderTitle: "应用程序 — 访达",
    searchable: "可以搜索",
    installFlowIndex: "01 / 放到正确的位置",
    installFlowTitle: "三个步骤，让它成为<br />可被索引的 Mac App。",
    installFlowIntro: "“下载”只是临时存放位置。第三方 App 被放入“应用程序”文件夹后，才会进入 macOS 的应用浏览与 Spotlight 索引。",
    unzipTitle: "解压发布包",
    unzipDesc: "打开“下载”，双击 <code>SpritePetStudio-macOS.zip</code>，解压后应当能看到 <code>SpritePetStudio.app</code>。",
    moveTitle: "移入应用程序",
    moveDesc: "在访达中选择<strong>前往 → 应用程序</strong>（⇧⌘A），再把 <code>SpritePetStudio.app</code> 拖入这个文件夹。",
    launchTitle: "从应用程序中打开",
    launchDesc: "先从“应用程序”里启动一次。之后它便可以出现在 Spotlight 和 macOS 的 App 视图中；也可以把图标拖到 Dock 固定。",
    finderTipTitle: "还是找不到？",
    finderTipBody: "确认准确路径是 <code>/Applications/SpritePetStudio.app</code>，而不是 ZIP，也不是仍留在“下载”里的 App。然后按 ⌘ Space 搜索 <strong>SpritePetStudio</strong>。",
    securityIndex: "02 / 第一次启动",
    securityTitle: "这个警告符合当前构建方式，<br />但下载来源依然重要。",
    securityIntro: "当前开源发布包采用临时签名，尚未使用 Apple Developer ID 完成公证，因此 macOS 无法自动验证开发者身份。",
    gatekeeperCardTitle: "通过“隐私与安全性”打开",
    securityStep1: "先从“应用程序”尝试打开一次 SpritePetStudio。出现截图中的警告时，点“完成”，不要点“移到废纸篓”。",
    securityStep2: "打开<strong>系统设置 → 隐私与安全性</strong>，向下滚动到“安全性”区域。",
    securityStep3: "找到关于 SpritePetStudio 被阻止的提示，点击<strong>仍要打开</strong>。Apple 通常只会在启动失败后的约一小时内显示这个按钮。",
    securityStep4: "使用登录密码或 Touch ID 验证，再确认<strong>打开</strong>。macOS 会把这个 App 保存为例外。",
    appleSecurityGuide: "查看 Apple 官方安全说明",
    verifyKicker: "放行之前",
    verifyTitle: "先核验下载文件。",
    verifyDesc: "把发布包和校验文件下载到同一目录，在终端运行下面的命令。只有结果显示“OK”时再继续。",
    downloadAppFile: "App 压缩包",
    downloadChecksum: "校验文件",
    whyKicker: "为什么会这样",
    whyTitle: "这不是访达故障。",
    whyDesc: "弹窗来自 Gatekeeper 对未公证构建的拦截。把 App 移入“应用程序”解决索引问题；在“隐私与安全性”中放行解决首次启动问题。",
    troubleIndex: "03 / 常见问题",
    troubleTitle: "还是卡住？<br />先检查这些地方。",
    openAnywayMissing: "找不到“仍要打开”",
    openAnywayMissingBody: "再从“应用程序”里启动一次，关闭警告后立刻重新打开“隐私与安全性”。如果这是受公司或学校管理的 Mac，管理员策略可能会隐藏这个选项。",
    spotlightMissing: "Spotlight 里没有这个 App",
    spotlightMissingBody: "确认 App 直接位于“应用程序”文件夹，先从访达打开一次，稍等片刻再搜索准确名称。ZIP 或仍留在“下载”里的 App 都不算安装。",
    terminalFallback: "已核验发布包的高级备用方式",
    terminalWarning: "只有在确认官方发布包校验值正确后，才可以用下面的命令清除这个 App 的隔离标记并打开。不要对来源不明的软件执行。",
    appleAppsGuide: "Apple：把 App 加入 Spotlight",
    reportIssue: "在 GitHub 提交问题",
    readyToInstall: "准备安装",
    installDownloadTitle: "把下一只桌宠，<br />放进“应用程序”。",
    installDownloadMeta: "GitHub 官方发布包 · macOS 14 或更新版本",
    installSafetyLine: "先核验 · 再移入应用程序 · 只放行一次",
    languageTarget: "English",
    languageAction: "切换到英语",
  },
};

const savedLanguage = (() => {
  try {
    return localStorage.getItem("spritepet-language");
  } catch {
    return null;
  }
})();

let currentLanguage = savedLanguage === "zh" ? "zh" : "en";

const applyLanguage = (language) => {
  const nextLanguage = language === "zh" ? "zh" : "en";
  const copy = translations[nextLanguage];
  const isInstallPage = document.body.dataset.page === "install";
  currentLanguage = nextLanguage;

  document.documentElement.lang = nextLanguage === "zh" ? "zh-CN" : "en";
  document.documentElement.dataset.language = nextLanguage;
  const pageTitle = isInstallPage ? copy.installPageTitle : copy.pageTitle;
  const metaDescription = isInstallPage ? copy.installMetaDescription : copy.metaDescription;
  const ogDescription = isInstallPage ? copy.installOgDescription : copy.ogDescription;
  document.title = pageTitle;
  document.querySelector('meta[name="description"]')?.setAttribute("content", metaDescription);
  document.querySelector('meta[property="og:title"]')?.setAttribute("content", pageTitle);
  document.querySelector('meta[property="og:description"]')?.setAttribute("content", ogDescription);

  document.querySelectorAll("[data-i18n]").forEach((node) => {
    const value = copy[node.dataset.i18n];
    if (value != null) node.textContent = value;
  });
  document.querySelectorAll("[data-i18n-html]").forEach((node) => {
    const value = copy[node.dataset.i18nHtml];
    if (value != null) node.innerHTML = value;
  });
  document.querySelectorAll("[data-i18n-aria]").forEach((node) => {
    const value = copy[node.dataset.i18nAria];
    if (value != null) node.setAttribute("aria-label", value);
  });
  document.querySelectorAll("[data-i18n-alt]").forEach((node) => {
    const value = copy[node.dataset.i18nAlt];
    if (value != null) node.setAttribute("alt", value);
  });

  const toggle = document.querySelector("[data-language-toggle]");
  const toggleLabel = document.querySelector("[data-language-label]");
  if (toggle) {
    toggle.setAttribute("aria-label", copy.languageAction);
    toggle.setAttribute("title", copy.languageAction);
  }
  if (toggleLabel) toggleLabel.textContent = copy.languageTarget;

  try {
    localStorage.setItem("spritepet-language", nextLanguage);
  } catch {
    // Language switching still works when storage is unavailable.
  }
};

const formatBytes = (bytes) => {
  if (!Number.isFinite(bytes) || bytes <= 0) return "";
  const units = ["B", "KB", "MB", "GB"];
  const exponent = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
  const value = bytes / 1024 ** exponent;
  return `${value.toFixed(value >= 10 || exponent === 0 ? 0 : 1)} ${units[exponent]}`;
};

const updateRelease = async () => {
  document.querySelectorAll("[data-release-download]").forEach((link) => {
    link.href = fallbackDownload;
  });

  try {
    const response = await fetch(`https://api.github.com/repos/${repository}/releases/latest`, {
      headers: { Accept: "application/vnd.github+json" },
    });
    if (!response.ok) return;

    const release = await response.json();
    const archive = release.assets?.find((asset) => asset.name === "SpritePetStudio-macOS.zip");
    document.querySelectorAll("[data-version]").forEach((node) => {
      node.textContent = release.tag_name || "v0.2.1";
    });
    if (archive?.browser_download_url) {
      document.querySelectorAll("[data-release-download]").forEach((link) => {
        link.href = archive.browser_download_url;
      });
      const size = formatBytes(archive.size);
      document.querySelectorAll("[data-size]").forEach((node) => {
        node.textContent = size;
      });
    }
  } catch {
    // The stable latest-release URL remains usable if the API is unavailable.
  }
};

const revealObserver = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add("is-visible");
      revealObserver.unobserve(entry.target);
    });
  },
  { rootMargin: "0px 0px -8%", threshold: 0.08 },
);

document.querySelectorAll(".reveal").forEach((element) => revealObserver.observe(element));
document.querySelectorAll("[data-year]").forEach((node) => {
  node.textContent = new Date().getFullYear();
});

document.querySelector("[data-language-toggle]")?.addEventListener("click", () => {
  applyLanguage(currentLanguage === "en" ? "zh" : "en");
});

applyLanguage(currentLanguage);
updateRelease();
