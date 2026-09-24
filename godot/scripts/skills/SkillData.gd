class_name SkillData
extends Resource
## Shared skill definition. BattleManager resolves costs, cooldowns and effects.

enum TargetType { SELF, ALLY, ALL_ALLIES, SINGLE_ENEMY, ALL_ENEMIES, FRONT_ENEMY, BACK_ENEMY, RANDOM_ENEMY }
enum DamageType { PHYSICAL, ENERGY, PLASMA, TRUE_DAMAGE }
enum EffectType { DAMAGE, SHIELD }

@export var id: StringName = &""
@export var skill_name: String = "New Skill"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var target_type: TargetType = TargetType.SINGLE_ENEMY
@export var damage_type: DamageType = DamageType.ENERGY
@export var effect_type: EffectType = EffectType.DAMAGE
@export_range(0.0, 10.0, 0.05) var attack_multiplier: float = 1.0
@export_range(0, 10000) var flat_value: int = 0
@export_range(1, 10) var hit_count: int = 1
@export_range(0, 100) var energy_cost: int = 0
@export_range(0, 20) var cooldown: int = 0
@export var animation_name: StringName = &""
@export var sound: AudioStream


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"" or skill_name.strip_edges().is_empty():
		errors.append("Skill ID and name are required.")
	if attack_multiplier < 0.0 or flat_value < 0 or hit_count < 1:
		errors.append("Skill damage values must be nonnegative and hit count must be positive.")
	if energy_cost < 0 or cooldown < 0:
		errors.append("Skill cost and cooldown must be nonnegative.")
	if target_type < 0 or target_type >= TargetType.size():
		errors.append("Invalid skill target type.")
	if damage_type < 0 or damage_type >= DamageType.size():
		errors.append("Invalid damage type.")
	if effect_type < 0 or effect_type >= EffectType.size():
		errors.append("Invalid effect type.")
	return errors
