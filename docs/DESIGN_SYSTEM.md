# SpritePet Studio 设置界面设计标准

设置界面采用可复用的 Apple Music 风格 SwiftUI 组件，避免各页面自行堆叠颜色和圆角。

## 基础原则

- 设置窗口使用固定在顶部的横向导航；工程库、配置库、通用和事件接口属于全局页面。动作编辑器是工程库中具体工程的子页面，不单独占用顶栏入口。
- 主要强调色使用 `StudioTheme.accent`，只用于选中、主要按钮和状态提示。
- 页面使用系统中性窗口底色，不铺设大面积红色或品牌色背景。
- 内容容器统一使用 `StudioCard`：16 pt 圆角、轻边框、低强度阴影。
- 页面标题统一使用 `StudioPageHeader`，包括眉题、标题、说明和右侧操作区。
- 标签状态统一使用 `StudioPill`。
- 页面背景统一使用 `StudioPageBackground`。
- 页面外边距 24 pt，主要区块间距 18 pt；列表与详情使用同样的 18 pt 间距。
- 页面内容宽度应自适应窗口，不能挤压或移走顶部导航。

## 工程标注

- 主题令牌与公共组件：`UI/StudioDesignSystem.swift`
- 设置导航：`UI/SettingsRootView.swift`
- 工程库：`UI/ProjectLibraryView.swift`
- 配置库：`UI/ConfigurationLibraryView.swift`
- 动作编辑器：`UI/ActionLibraryView.swift`
- 触发器组件：`UI/TriggerRuleEditor.swift`

新增页面应优先复用上述组件；只有表示不同语义状态时才引入新颜色。
