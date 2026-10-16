# MobileTouchAim · PTF-05

独立可注入触摸适配场景：`res://ui/mobile/mobile_touch_aim.tscn`。默认关闭，正式布局尚待真人选择；没有在Sandbox自动挂载，也没有新增Autoload。

## 接入顺序（A / D）

依赖C的PTF-03公开指针API，原提交`c1e753a`，PR #257。本E分支只安全引入该提交，未改其实现。

```gdscript
# 宿主进入树后，使用已批准的MobileTouchLayout Resource。
var touch: MobileTouchAim = preload("res://ui/mobile/mobile_touch_aim.tscn").instantiate()
add_child(touch)
touch.layout = approved_layout
if not touch.bind_attack_input(attack_charge_input):
    return
var region: Rect2 = barrage_area.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, barrage_area.size)
touch.configure_regions(region)
touch.set_enabled(true)
```

- 坐标统一为InputEvent.position的Viewport坐标；组件转换屏幕安全区与密度，C继续执行准心移动/实际蓄力/快照/飞行/结算。
- `configure_regions(aim_rect, touch_rect=Rect2())`分别控制瞄准区和可起手区。区域更新会取消旧手势，A在阶段切换/布局变化后更新。
- `set_enabled(false)`取消该组件捕获的手指并恢复C原生触摸读取；宿主仍须正确设置战斗阶段。Root暂停/Rest/阶段对白等由A控制。
- `get_safe_viewport_rect()`返回安全Viewport矩形，`safe_area_changed(rect)`只在实际几何变化时发出。D/A用同一矩形布局触摸UI；此组件只自动排自己的状态条。
- `gesture_cancelled(reason)`区分系统取消、暂停、失焦、视口/安全区变化、停用和离树；`aim_changed(position)`可供额外HUD反馈读取。
- 更换布局前先关闭组件，再赋新Resource并启用。禁止生产Root预载`data/test_only/ptf05`里的审核配置；正式参数批准后写入正式data/mobile配置。

## 当前方案

V0 A：上方12密度换算毫米、顶部独立蓄力条；V0 B：左10/上9、底部独立蓄力条。数据仅在TEST_ONLY配置。DPI来自平台密度分组，物理毫米只是估算，真机舒适度待验收。

一根手指负责当前攻击；其他手指保留给UI。已捕获手指在UI上释放也会清理。重复鼠标模拟由C原输入API过滤；没有关闭全局鼠标模拟，菜单仍能使用原生按钮。

## 真实预览

`res://tests/presentation/ptf05_mobile_review.tscn`：默认可在六个屏内用鼠标长按/拖动（转为ScreenTouch），或使用真实ScreenTouch。三比例1920×1080、2340×1080、2400×1080，DPI模拟320/480/640。A/B并排。

`-- --replay --media=D:/tmp/...`复播触摸事件并保存实际GPU图；正式0.8秒攻击时序保留。测位目标使用公开静止生成入口，内存寿命延长至120秒以适应慢于实时的MovieWriter；没有PK调试推进。

2026-10-16：6次真实攻击快照与准心同点/命中目标，短按、额外手指、取消、失焦通知、视口尺寸变化模拟通过。原生Android旋转、系统返回、长期拖动/设备DPI和手感仍未验收；当前ADB无设备、未安装模拟器。

媒体仅存`D:\tmp\ptf05-review-20261016\mobile-final`，6.03秒Godot MovieWriter AVI和18张原生比例PNG，未入Git。详见`docs/Integration/移动与内容_PTF-05_2026-10-16_log.md`。
