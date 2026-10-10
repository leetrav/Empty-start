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
- BarrageTraitSet 已使用 `occlusion`、`split`、`reflect`、`unselectable`、`fake_card`、`retaliation_copy` 等稳定特性 ID。
- 弹幕现有表现入口 `apply_terminal_trait_presentation()` 可读取展示特性 ID。

## 本次任务

在 PA-04 普通弹幕基础上，为下列六种特性提供可辨认的**材质、外观和必要的常态视觉表现**。

### 1. 遮挡（occlusion）：铁质
- 将底板表现为**坚硬的铁质板**：金属色泽、坚实厚度、硬质边缘及局部金属反光。
- 通过底板整体材质让其与普通玻璃弹幕形成明显区别。
- 保留弹幕文本、既有倾向/强度信息及可调整的视觉参数。

### 2. 分裂（split）：预裂玻璃
- 沿用普通弹幕的玻璃底板，在表面叠加可辨认的**曲线裂痕**。
- 裂痕跟随底板尺寸适配，与文本保持良好可读性。
- 分裂产生的子弹幕显示为 PA-04 定义的**较小的普通玻璃底板弹幕**，尺寸适配实际子句内容。

### 3. 反弹（reflect）：果冻
- 设计**柔软、Q 弹、半透明的果冻材质**，用圆润轮廓、柔和明暗层次及湿润感的镜面反光区别普通玻璃。
- 加入轻微的**常态弹性形变 / 果冻颤动**，让静止观察时也能感受到柔软材质。
- 材质参数、常态形变幅度与视觉节奏可调整。

### 4. 不可选（unselectable）：空心描边文字
- 沿用 PA-04 的普通玻璃底板材质。
- 将正文呈现为**描边镂空字**：保留完整字形轮廓，字面内部透明，可透出下方底板。
- 与现有普通弹幕的实心文字形成明显视觉对比，同时保留文字辨认能力。

### 5. 假复读（fake_card）：鲜艳椭圆气泡
- 正常复读沿用现有**圆角气泡外框**。
- 假复读采用**椭圆气泡外框**，保持与正常复读一致的气泡家族感。
- 假复读整体配色比正常复读**更鲜艳、更醒目**，形成吸引玩家攻击的视觉效果。
- 假复读属于携带 `fake_card` 特性的**前景普通话语实例**，采用清晰的前景文字描边与醒目配色；背景普通复读继续使用灰色、零文字描边样式。

### 6. 水军反击（retaliation_copy）：连体刷屏板
- 将**单个携带 `retaliation_copy` 的前景弹幕实例**视觉表现为**一整个连在一起的不规则 Panel**，形成成团涌现的刷屏块。一个 Panel 仍对应该实例原有的命中区域和一次结算。
- Panel 内部用**偏小字号**重复排布该实例已有的话语文本，位置疏密不一，视觉上属于一个整体；这些小字是同一实例内部的美术排版。
- 让内部重复文本呈现疏密变化，并保持文字可辨认。
- 外框轮廓、整体配色、内部字体尺寸与文本分布提供可调整的视觉参数。
- 显示时读取现有反击复制特性与文本内容，接入既有弹幕表现。

### 7. 统一接入
- 从每个 `BarrageView.runtime_record.trait_set.get_trait_ids()` 读取普通战斗的真实特性 ID，选择对应外观；根据当前 `BarrageView` 的显示入口绘制和接线。终局专用 `apply_terminal_trait_presentation()` 只作为另一路表现接口参考。
- 对普通与挂特性的前景话语复用 PA-04 的底板和文字样式参数；普通复读圆角气泡、假复读椭圆气泡分别显示。
- 当一个实例兼有多个特性时，**主底板只选择一套**，按现有结果优先级选择：`reflect → occlusion → fake_card → retaliation_copy → split → 普通玻璃`；`unselectable` 作为可兼容的镂空文字层叠加在最终主底板上。保持文本和原有实际命中区域一致。
- 优先使用 Godot `StyleBoxFlat`、`Theme`、`_draw()`、轻量 Shader 或程序生成的 SVG/PNG 图形。
- 通过已有 BarrageView 表现入口接入，保持现有弹幕交互、运动和生命周期正常。

## 验收
- 在同一战斗场景中可辨认普通玻璃、铁质遮挡、预裂玻璃、果冻反弹、空心文字、假复读和水军反击的外观。
- 果冻弹幕平时持续呈现柔软、Q 弹的材质感。
- 不可选弹幕正文为清晰可辨的空心描边字，玻璃底板保持一致。
- 分裂后的子弹幕使用普通玻璃外观。
- 正常复读是底层灰字、零文字描边的圆角气泡；假复读是带 `fake_card` 特性的前景话语，采用醒目椭圆气泡及有描边文字。
- 水军反击呈现为一个整体不规则 Panel，内部散布多处小字号重复短句；**单实例、单命中区域、单次结果**关系在运行画面中保持正确。
- 多特性组合以统一主底板优先级呈现，文字镂空层能够按现有兼容关系叠加。
- 多条弹幕同屏时材质特征仍清楚，运行画面与 Godot Output / Debugger 验证通过。

## 环境与完成记录
- Godot 4.7.2 / GDScript / Windows / Android
- Godot-MCP-Native；godot_mcp
- 完成后新增 `docs/Shared/PresentationAssets/表现资产_PA-05_2026-10-09_log.md`，记录实际资源、参数、接入位置与实机画面验证。
