# PA-05 特殊弹幕程序美术：材质与文字外观

> 状态：需求已定，待实施
> 类型：P0 / PresentationAssets
> 依赖：PA-04 普通弹幕底板与文字表现

## 开始前阅读
- `AGENTS.md`、`project.godot`、仓库已知问题记录
- `docs/System_Collaboration.md`
- `docs/Shared/PresentationAssets/README.md`
- `docs/Shared/PresentationAssets/tasks/PA-04_barrage-glossy-translucent-ui.md`
- `docs/4. BarrageTraits/README.md`
- `systems/barrage_generation/barrage_view.gd`、`systems/barrage_generation/barrage_view.tscn`
- `systems/barrage_traits/barrage_trait_set.gd`
- 当前相关系统最新 log

## 现有基础
- PA-04 定义普通弹幕的半透明亮面圆角玻璃底板、倾向底板配色、强度视觉层级与富文本。
- BarrageTraitSet 已使用 `occlusion`、`split`、`reflect`、`unselectable` 等稳定特性 ID。
- 弹幕现有表现入口 `apply_terminal_trait_presentation()` 可读取展示特性 ID。

## 本次任务

在 PA-04 普通弹幕基础上，为下列四种特性提供独立的**材质、静态外观和必要的常态视觉表现**。

### 1. 遮挡（occlusion）：铁质
- 将底板表现为**坚硬的铁质板**：金属色泽、坚实厚度、硬质边缘及局部金属反光。
- 通过底板整体材质让其与普通玻璃弹幕形成明显区别。
- 保留弹幕文本、既有倾向/强度信息及可调整的视觉参数。

### 2. 分裂（split）：预裂玻璃
- 沿用普通弹幕的玻璃底板，在表面叠加可辨认的**曲线裂痕**。
- 裂痕跟随底板尺寸适配，与文本保持良好可读性。
- 分裂产生的子弹幕显示为 PA-04 定义的**普通玻璃底板弹幕**。

### 3. 反弹（reflect）：果冻
- 设计**柔软、Q 弹、半透明的果冻材质**，用圆润轮廓、柔和明暗层次及湿润感的镜面反光区别普通玻璃。
- 加入轻微的**常态弹性形变 / 果冻颤动**，让静止观察时也能感受到柔软材质。
- 材质参数、常态形变幅度与视觉节奏可调整。

### 4. 不可选（unselectable）：空心描边文字
- 沿用 PA-04 的普通玻璃底板材质。
- 将正文呈现为**描边镂空字**：保留完整字形轮廓，字面内部透明，可透出下方底板。
- 与现有普通弹幕的实心文字形成明显视觉对比，同时保留文字辨认能力。

### 5. 统一接入
- 依据弹幕运行记录的实际特性 ID 选择对应外观。
- 尽量复用 PA-04 的底板、倾向配色、强度与文本样式参数，以及既有粉丝牌、复读标识。
- 优先使用 Godot `StyleBoxFlat`、`Theme`、`_draw()`、轻量 Shader 或程序生成的 SVG/PNG 图形。
- 通过已有 BarrageView 表现入口接入，保持现有弹幕交互、运动和生命周期正常。

## 验收
- 在同一战斗场景中可辨认普通玻璃、铁质遮挡、预裂玻璃、果冻反弹、空心文字五种外观。
- 果冻弹幕平时持续呈现柔软、Q 弹的材质感。
- 不可选弹幕正文为清晰可辨的空心描边字，玻璃底板保持一致。
- 分裂后的子弹幕使用普通玻璃外观。
- 多条弹幕同屏时材质特征仍清楚，运行画面与 Godot Output / Debugger 验证通过。

## 环境与完成记录
- Godot 4.7.2 / GDScript / Windows / Android
- Godot-MCP-Native；godot_mcp
- 完成后新增 `docs/Shared/PresentationAssets/表现资产_PA-05_2026-10-09_log.md`，记录实际资源、参数、接入位置与实机画面验证。
