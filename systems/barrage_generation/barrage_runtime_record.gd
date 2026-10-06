## 单条弹幕的运行时数据快照，与关卡静态话语 Resource 分开。
class_name BarrageRuntimeRecord
extends RefCounted

## 弹幕实际显示的文本，在创建实例时从静态定义复制。
var text: String = ""

## 提供这条内容的来源稳定 ID，例如主播 ID。
var source_id: String = ""

## 倾向稳定 ID 由内容来源提供；当前不在弹幕系统另建枚举。
var tendency_id: String = ""

## 当前弹幕强度；具体数值由创建者按后续正式配置赋值。
var strength: float = 0.0

## 普通话语、复读或矛盾派生内容沿用同一个原句 ID。
var original_sentence_id: String = ""

## 生成时捕获的绝对到期时间，使用单调时钟毫秒值供后续生命周期管理读取。
var expires_at_msec: int = 0

## 只在实例生成时计算一次寿命；之后档位变化不会改写已保存的截止时间。
func capture_lifetime_at_spawn(spawn_time_msec: int, base_lifetime_seconds: float, lifetime_multiplier: float) -> void:
	var effective_lifetime_msec: int = roundi(base_lifetime_seconds * lifetime_multiplier * 1000.0)
	expires_at_msec = spawn_time_msec + effective_lifetime_msec
