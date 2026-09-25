class_name CharacterData
extends Resource
## Shared starting definition. Never store mutable HP, cooldowns or status stacks here.

@export_group("Identity")
@export var id: StringName = &""
@export var character_name: String = "New Character"
@export var class_id: StringName = &""
@export var class_name_label: String = ""
@export_multiline var description: String = ""
@export var display_color: Color = Color("61dfcb")

@export_group("Starting Stats")
@export_range(1, 100) var level: int = 1
## Scale guide: level 1–2 units keep HP at 10 or below; level 5+ elites and bosses start at 20 or more.
@export_range(1, 999) var max_hp: int = 8
@export_range(0, 999) var starting_shield: int = 0
@export_range(0, 100) var max_energy: int = 5
@export_range(0, 1000) var speed: int = 10
@export_range(0, 99) var attack: int = 2
## Subtracted from the attacker's 2d6 total.
@export_range(0, 12) var defense: int = 1
## Added to this unit's own 2d6 attack total.
@export_range(-6, 12) var hit_bonus: int = 1
## A natural 2d6 of at least this value is a critical hit (12 = double sixes only).
@export_range(7, 12) var crit_threshold: int = 12

@export_group("Loadout")
@export var skills: Array[SkillData] = []


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"" or class_id == &"" or character_name.strip_edges().is_empty():
		errors.append("Character ID, class ID and name are required.")
	if level < 1 or max_hp < 1 or max_energy < 0 or starting_shield < 0:
		errors.append("Invalid character starting health, shield, energy or level.")
	if speed < 0 or attack < 0 or defense < 0:
		errors.append("Combat stats must be nonnegative.")
	if crit_threshold < 7 or crit_threshold > 12:
		errors.append("Critical threshold must be a natural 2d6 total from 7 to 12.")
	var skill_ids: Array[StringName] = []
	for skill in skills:
		if skill == null:
			errors.append("Skill slots cannot be empty.")
			continue
		errors.append_array(skill.get_validation_errors())
		if skill.id in skill_ids:
			errors.append("Duplicate skill ID: %s" % skill.id)
		skill_ids.append(skill.id)
	return errors
