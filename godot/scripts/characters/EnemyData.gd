class_name EnemyData
extends CharacterData
## Entries are indices into the inherited skills array, repeated in order.

@export var action_pattern: Array[int] = [0]


func get_validation_errors() -> PackedStringArray:
	var errors := super.get_validation_errors()
	if action_pattern.is_empty():
		errors.append("Enemy action pattern cannot be empty.")
	for index in action_pattern:
		if index < 0 or index >= skills.size():
			errors.append("Enemy pattern references a missing skill.")
	return errors
