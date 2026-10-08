class_name EndingJudgementTextConfig
extends Resource

const IDENTITY_RESULT = preload("res://core/ending/ending_identity_result_classifier.gd")

## 四类判词由策划填写；正式文本尚未提供时允许留空。
@export_multiline var no_effective_behavior_text: String = ""
@export_multiline var primary_tied_text: String = ""
@export_multiline var consistent_text: String = ""
@export_multiline var shifted_text: String = ""


# 直接按 EN-05 稳定分类读取配置文本；未知分类返回空文本。
func get_judgement_text(result_class: StringName) -> String:
	match result_class:
		IDENTITY_RESULT.NO_EFFECTIVE_BEHAVIOR:
			return no_effective_behavior_text
		IDENTITY_RESULT.PRIMARY_TIED:
			return primary_tied_text
		IDENTITY_RESULT.CONSISTENT:
			return consistent_text
		IDENTITY_RESULT.SHIFTED:
			return shifted_text
		_:
			return ""
