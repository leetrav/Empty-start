extends Node

var _definitions: Dictionary = {}


func set_definitions(definitions: Array) -> void:
	for definition in definitions:
		if definition is Dictionary:
			_definitions[str(definition.get("word_id", ""))] = definition.duplicate(true)


func get_word_definition(word_id: String) -> Dictionary:
	return _definitions.get(word_id, {}).duplicate(true)
