class_name AssimilationData
extends Resource

@export var completed_streamer_ids: Array[StringName] = []
@export var defeated_streamer_ids: Array[StringName] = []

# 键为稳定词库 ID，值为该词库继承后的出现权重。
@export var inherited_word_weights: Dictionary = {}

@export var inherited_trait_ids: Array[StringName] = []
