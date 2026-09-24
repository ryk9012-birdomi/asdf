class_name TurnManager
extends Node

signal round_started(round_number: int)
signal turn_started(unit: CharacterUnit)
signal turn_finished(unit: CharacterUnit)

var combatants: Array[CharacterUnit] = []
var queue: Array[CharacterUnit] = []
var round_number: int = 0
var cursor: int = -1
var current_unit: CharacterUnit


func reset(units: Array[CharacterUnit]) -> void:
	combatants.assign(units)
	queue.clear()
	round_number = 0
	cursor = -1
	current_unit = null


func next_unit() -> CharacterUnit:
	current_unit = null
	while true:
		cursor += 1
		if cursor >= queue.size():
			queue.clear()
			for unit in combatants:
				if unit.is_alive():
					queue.append(unit)
			if queue.is_empty():
				return null
			queue.sort_custom(func(a: CharacterUnit, b: CharacterUnit):
				if a.speed == b.speed:
					return combatants.find(a) < combatants.find(b)
				return a.speed > b.speed)
			cursor = 0
			round_number += 1
			round_started.emit(round_number)
		if queue[cursor].is_alive():
			current_unit = queue[cursor]
			current_unit.begin_turn()
			turn_started.emit(current_unit)
			return current_unit
	return null


func finish_turn() -> void:
	if current_unit != null:
		turn_finished.emit(current_unit)
		current_unit = null


func upcoming() -> Array[CharacterUnit]:
	var result: Array[CharacterUnit] = []
	for index in range(maxi(0, cursor), queue.size()):
		if queue[index].is_alive():
			result.append(queue[index])
	return result
