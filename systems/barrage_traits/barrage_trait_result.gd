class_name BarrageTraitResult
extends RefCounted

enum Kind { NORMAL, OCCLUSION, FAKE_CARD, RETALIATION_COPY }

var kind: Kind = Kind.NORMAL

# 普通结果才发放正常话语收益；遮挡、假牌和反击复制品结果都会跳过该收益。
var receives_normal_reward: bool:
	get:
		return kind == Kind.NORMAL

# 遮挡异常交给命中结算系统应用数值，这里只传递异常类型。
var anomaly_type: StringName:
	get:
		if kind == Kind.OCCLUSION:
			return &"occlusion"
		return &""


# 创建已经解析的目标结果，不在特性模块计算 PK 或扣分。
func _init(result_kind: Kind = Kind.NORMAL) -> void:
	kind = result_kind
