class_name EnemyUnit
extends CharacterUnit

var pattern_cursor: int = 0


func initialize(definition: CharacterData) -> bool:
	if not definition is EnemyData:
		return false
	if not super.initialize(definition):
		return false
	pattern_cursor = 0
	return true


func intended_skill(before_turn: bool = false) -> SkillData:
	var definition := character_data as EnemyData
	if definition == null or not is_alive():
		return null
	var candidate := definition.skills[definition.action_pattern[pattern_cursor % definition.action_pattern.size()]]
	var available_energy := mini(max_energy, current_energy + (1 if before_turn else 0))
	var cooldown_reduction := 1 if before_turn else 0
	if candidate.energy_cost <= available_energy and remaining_cooldown(candidate) <= cooldown_reduction:
		return candidate
	for fallback in definition.skills:
		if fallback.energy_cost <= available_energy and remaining_cooldown(fallback) <= cooldown_reduction:
			return fallback
	return null
