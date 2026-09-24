class_name CharacterUnit
extends Node
## Runtime state only. UI observes signals; battle rules supply already-resolved damage.

signal initialized
signal health_changed(current: int, maximum: int)
signal shield_changed(current: int)
signal energy_changed(current: int, maximum: int)
signal damage_received(health_damage: int, shield_damage: int)
signal unit_died(unit: CharacterUnit)

enum FormationSlot { FRONT, MIDDLE, BACK }

@export var character_data: CharacterData
@export var formation_slot: FormationSlot = FormationSlot.FRONT

var current_hp: int = 0
var current_shield: int = 0
var current_energy: int = 0
var max_hp: int = 0
var max_energy: int = 0
var level: int = 1
var speed: int = 0
var attack: int = 0
var defense: int = 0
var accuracy: float = 0.0
var evasion: float = 0.0
var critical_chance: float = 0.0
var is_initialized: bool = false
var display_name: String = ""
var cooldowns: Dictionary = {}


func _ready() -> void:
	if character_data != null and not is_initialized:
		if not initialize(character_data):
			push_error("Invalid CharacterData on %s: %s" % [name, character_data.get_validation_errors()])


func initialize(definition: CharacterData) -> bool:
	# Validate first so a failed load cannot damage an existing unit's state.
	if definition == null or not definition.get_validation_errors().is_empty():
		return false
	character_data = definition
	display_name = definition.character_name
	cooldowns.clear()
	max_hp = definition.max_hp
	max_energy = definition.max_energy
	level = definition.level
	speed = definition.speed
	attack = definition.attack
	defense = definition.defense
	accuracy = definition.accuracy
	evasion = definition.evasion
	critical_chance = definition.critical_chance
	current_hp = max_hp
	current_shield = definition.starting_shield
	current_energy = max_energy
	is_initialized = true
	initialized.emit()
	health_changed.emit(current_hp, max_hp)
	shield_changed.emit(current_shield)
	energy_changed.emit(current_energy, max_energy)
	return true


func reset_to_starting_state() -> bool:
	return initialize(character_data)


func is_alive() -> bool:
	return is_initialized and current_hp > 0


func begin_turn() -> void:
	for skill_id in cooldowns.keys():
		cooldowns[skill_id] = maxi(0, int(cooldowns[skill_id]) - 1)
	restore_energy(1)


func remaining_cooldown(skill: SkillData) -> int:
	return int(cooldowns.get(skill.id, 0))


func receive_damage(amount: int, bypass_shield: bool = false) -> int:
	# No armor/crit calculation here: DamageCalculator resolves those once.
	if not is_alive() or amount <= 0:
		return 0
	var absorbed: int = 0 if bypass_shield else mini(current_shield, amount)
	var health_damage: int = mini(current_hp, amount - absorbed)
	current_shield -= absorbed
	current_hp -= health_damage
	if absorbed > 0:
		shield_changed.emit(current_shield)
	if health_damage > 0:
		health_changed.emit(current_hp, max_hp)
	damage_received.emit(health_damage, absorbed)
	if current_hp == 0:
		unit_died.emit(self)
	return health_damage


func heal(amount: int) -> int:
	# Healing cannot revive a dead unit. Reset is an explicit lab/new-run operation.
	if not is_alive() or amount <= 0:
		return 0
	var recovered: int = mini(amount, max_hp - current_hp)
	if recovered > 0:
		current_hp += recovered
		health_changed.emit(current_hp, max_hp)
	return recovered


func add_shield(amount: int) -> int:
	if not is_alive() or amount <= 0:
		return 0
	current_shield += amount
	shield_changed.emit(current_shield)
	return amount


func can_spend_energy(amount: int) -> bool:
	return is_alive() and amount >= 0 and current_energy >= amount


func spend_energy(amount: int) -> bool:
	if not can_spend_energy(amount):
		return false
	if amount > 0:
		current_energy -= amount
		energy_changed.emit(current_energy, max_energy)
	return true


func restore_energy(amount: int) -> int:
	if not is_alive() or amount <= 0:
		return 0
	var restored: int = mini(amount, max_energy - current_energy)
	if restored > 0:
		current_energy += restored
		energy_changed.emit(current_energy, max_energy)
	return restored
