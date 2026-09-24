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
@export_range(1, 10000) var max_hp: int = 100
@export_range(0, 10000) var starting_shield: int = 0
@export_range(0, 100) var max_energy: int = 5
@export_range(0, 1000) var speed: int = 10
@export_range(0, 1000) var attack: int = 20
@export_range(0, 1000) var defense: int = 5
@export_range(0.0, 1.0, 0.01) var accuracy: float = 0.95
@export_range(0.0, 1.0, 0.01) var evasion: float = 0.05
@export_range(0.0, 1.0, 0.01) var critical_chance: float = 0.1

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
	for chance in [accuracy, evasion, critical_chance]:
		if chance < 0.0 or chance > 1.0:
			errors.append("Probabilities must be between zero and one.")
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
