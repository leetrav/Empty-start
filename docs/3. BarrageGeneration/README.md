# 3. BarrageGeneration 弹幕生成系统任务拆分

## 系统目标

弹幕生成系统负责把“这一关允许出现的内容”真正变成场上的弹幕，并管理这些弹幕从出现到消失的生命周期。

它主要负责：

1. 从【关卡配置系统】读取当前关卡可用内容；
2. 按三项倾向比例选择普通话语；
3. 按当前生成参数持续创建弹幕；
4. 给每个实例保存来源、倾向、强度和唯一原句标识；
5. 管理寿命、同屏上限、暂停和移除；
6. 接入【复读系统】的复读生成请求；
7. 在矛盾阶段改为生成真假矛盾；
8. 普通战斗结束时清理普通弹幕和未出现的普通复读。

弹幕生成系统不负责玩家瞄准、不负责计算 PK、不负责判断矛盾真假，也不负责弹幕特性的具体结算规则。

## 当前仓库状态

- BG-01～BG-03 已提供运行时记录、普通话抽取和单条可见弹幕；BG-04 持续生成，BG-05 应用后续倍率，BG-06 固定生成时寿命，BG-07 共享普通容量，BG-08 处理到期与离区移除。
- BG-06～BG-08 已完成；CombatStage 接线、全局暂停、命中移除和布局参数接线仍由后续任务负责。
- 2. LevelConfiguration 已拆出关卡资料、词库、倾向比例和基础生成参数任务。
- 4. BarrageTraits、5. CombatAttack、6. HitResolution、8. CombatStage、10. Repeat、12. ContradictionBreak 等依赖系统尚未实现时，对应联调任务只保留任务卡，不提前造临时接口。

## 任务顺序

| 任务卡 | 小功能 | 自动化测试 |
| --- | --- | --- |
| BG-01 | 定义单条弹幕运行时记录 | 无 |
| BG-02 | 读取当前关普通词库并按倾向比例抽取一句 | 无 |
| BG-03 | 生成单条普通弹幕实例 | 无 |
| BG-04 | 按基础数量与频率持续生成普通弹幕 | 无 |
| BG-05 | 当前档位倍率只影响后续生成 | 无 |
| BG-06 | 生成时固定弹幕寿命 | 2 个关键单元测试 |
| BG-07 | 普通话语与陷阱共用同屏上限 | 2 个关键单元测试 |
| BG-08 | 自然到期 / 离开有效区域移除 | 无 |
| BG-09 | 有效命中后的移除规则 | 无 |
| BG-10 | 接入复读生成请求与独立上限 | 2 个关键单元测试 |
| BG-11 | 全局暂停时停止生成与寿命计时 | 无 |
| BG-12 | 进入矛盾阶段时切换真假矛盾生成 | 无 |
| BG-13 | 普通战斗结束时清理普通弹幕和待生成复读 | 无 |
| BG-14 | 读取舞台布局尺寸 | 无 |

## 测试预算

本系统只给两个高风险边界写少量单元测试：

### 寿命边界
- 已经生成的弹幕，到期时间在档位变化后保持不变；
- 档位变化后新生成的弹幕使用新的寿命配置。

### 同屏上限
- 普通话语和陷阱共同占用普通弹幕上限；
- 普通弹幕腾出位置后可以继续生成；
- 复读上限与普通弹幕上限分别计算；
- 普通弹幕满时，如果复读仍有容量，复读仍可以生成。

总计最多 6 个核心 case。

下面这些不逐项写单元测试：

- 随机抽词结果；
- Resource / 实例字段；
- 生成动画和移动表现；
- 到期 / 离屏的场景行为；
- 暂停；
- 命中移除；
- 阶段清理；
- 矛盾阶段联调；
- 舞台布局。

这些继续用最小 Godot 解析、资源加载和实际场景运行确认。

## 依赖顺序

BG-01～BG-08、BG-11、BG-14 可以在大部分后续战斗系统尚未完成时开发。

BG-09 等【4. BarrageTraits】和【6. HitResolution】有真实结果接口后再接。

BG-10 等【10. Repeat】提供真实复读生成请求后再接。

BG-12 等【8. CombatStage】和【12. ContradictionBreak】确定真实阶段入口与矛盾数据后再接。

BG-13 等【8. CombatStage】和【10. Repeat】都存在真实清理接口后再做完整阶段清理。

## BG-01 已实现的运行时数据

`systems/barrage_generation/barrage_runtime_record.gd` 定义 `BarrageRuntimeRecord`（`RefCounted`），运行时实例保存显示文本、来源稳定 ID、倾向 ID、强度和稳定 `original_sentence_id`。来源 ID 表示内容拥有者，当前关话语可取主播 ID；强度默认 `0.0`，创建方按正式参数赋值。它是运行时数据快照，不改写 `LevelSpeech` 或 `LevelContradiction` 静态 Resource。

当前记录不包含弹幕类别、场景节点、移动或寿命状态；后续任务确实需要区分时再增加对应字段。`tendency_id` 继续沿用关卡内容提供的字符串，不在弹幕生成系统另建枚举。

## BG-02 普通话语抽取

`NormalSpeechSelector.select_next_normal_speech(current_level)` 每次直接读取传入关卡的当前词库与倾向比例，不缓存旧内容。倾向 ID 使用 `orthodox`、`heretical`、`absurd`；先按关卡比例选择倾向，再按该倾向下各条 `LevelSpeech.appearance_weight` 选择话语。

返回值是原始 `LevelSpeech` Resource，可继续读取文本、倾向和稳定原句 ID；没有有效候选时返回 `null`。本步骤不创建场上实例。

### BG-03 单条普通弹幕实例

`systems/barrage_generation/barrage_area.tscn` 是可复用弹幕区域，公开 `spawn_normal_barrage(LevelProfile, LevelSpeech)` 入口；调用后创建 `BarrageRuntimeRecord` 并实例化 `barrage_view.tscn`。视图显示原句文本，并按当前关 `base_move_speed_pixels_per_second` 从右向左移动。

当前项目实际游戏入口仍指向技术 Sandbox，BG-03 将弹幕区域接入该场景用于原型验证。强度暂用 `1.0` 占位；没有增加到期、离屏移除、命中或连续生成逻辑，等待对应任务卡。

### BG-04 普通弹幕持续生成

`BarrageArea.start_normal_generation(LevelProfile)` 打开普通生成，立即生成第一批，随后使用 `base_spawn_interval_seconds` 驱动内置 `Timer`，每批调用 `spawn_normal_barrage()` 共 `base_batch_count` 次。`stop_normal_generation()` 停止后续批次；已经在场的视图继续移动。

Sandbox 当前负责调用启动入口；未来战斗阶段可调用相同的启动 / 停止方法。此卡尚未接入 Tier 倍率、同屏上限、暂停或弹幕移除，因此临时参数下同一通道的话语可能重叠。

### BG-05 后续生成倍率

`BarrageArea.set_generation_multipliers(generation_count_multiplier, generation_frequency_multiplier, movement_speed_multiplier)` 提供给 CombatStage 的倍率更新入口，字段语义对应 `CombatStageTierConfig`，但当前不直接依赖 8 号系统脚本。

后续批次数量按 `roundi(base_batch_count * generation_count_multiplier)` 取整；Timer 间隔为 `base_spawn_interval_seconds / generation_frequency_multiplier`；新视图速度为 `base_move_speed_pixels_per_second * movement_speed_multiplier`。倍率更新重置下一批计时，已生成视图保留创建时的速度。BG-06 的寿命倍率同样只作用于新实例。

### BG-06 生成时固定弹幕寿命

BarrageArea 暴露可编辑的 `base_lifetime_seconds` 临时基础值（默认 10 秒），并提供 `set_lifetime_multiplier()` 接收当前档位寿命倍率。生成新实例时，`BarrageRuntimeRecord` 保存单调时钟毫秒截止时间。倍率变化只影响之后新建的记录，既有截止时间保持不变。公共数值表尚未落地，基础值可在 Inspector 调整；到期移除留给 BG-08，暂停补偿留给 BG-11。

### BG-07 普通弹幕共享同屏上限

BarrageArea 从 `LevelProfile.normal_barrage_screen_cap` 读取普通上限。普通话语创建时自动登记，节点离开场景树时自动释放；陷阱等普通容量占用者通过 `try_register_normal_capacity_occupant()` 和 `release_normal_capacity_occupant()` 复用同一账本。达到上限时普通批次 Timer 暂停，释放容量后继续。BG-07 不实现弹幕特性规则；到期和离屏移除仍由 BG-08 负责。

### BG-08 到期与离开区域自然移除

生成时由 `BarrageArea` 把所属 `Control` 注入 `BarrageView`。视图每帧比较当前单调时钟与 `BarrageRuntimeRecord.expires_at_msec`；到期后调用 `queue_free()`。移动后，视图矩形与所属 Control 当前矩形不相交时也会自然结束。Node 离树触发 BG-07 的容量释放。当前有效区域使用 BarrageArea 实际边界，BG-14 布局读取完成后再接入舞台参数。命中移除由 BG-09 处理，全局暂停补偿由 BG-11 处理。
