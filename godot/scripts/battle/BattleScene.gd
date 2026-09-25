extends Control
## Owns encounter creation, scene navigation and animation delays only.

@export var party_definitions: Array[CharacterData] = []
@export var enemy_definitions: Array[EnemyData] = []
@export_range(0.05, 3.0) var action_delay: float = 0.65
@export var battle_seed: int = -1

@onready var battle: BattleManager = $BattleManager
@onready var view: Control = $BattleUI
@onready var pace: Timer = $ActionTimer


func _ready() -> void:
	var players: Array[CharacterUnit] = []
	var foes: Array[CharacterUnit] = []
	for definition in party_definitions:
		var unit: CharacterUnit = preload("res://scenes/battle/CharacterUnit.tscn").instantiate()
		$Units.add_child(unit)
		if not unit.initialize(definition):
			push_error("Invalid party definition")
			return
		unit.formation_slot = mini(players.size(), 2) as CharacterUnit.FormationSlot
		players.append(unit)
	for definition in enemy_definitions:
		var unit: EnemyUnit = preload("res://scenes/battle/EnemyUnit.tscn").instantiate()
		$Units.add_child(unit)
		if not unit.initialize(definition):
			push_error("Invalid enemy definition")
			return
		unit.formation_slot = mini(foes.size(), 2) as CharacterUnit.FormationSlot
		unit.display_name += " %02d" % (foes.size() + 1)
		foes.append(unit)
	view.skill_requested.connect(battle.player_action)
	view.pass_requested.connect(battle.player_pass)
	view.restart_requested.connect(func(): get_tree().reload_current_scene())
	view.lab_requested.connect(func(): get_tree().change_scene_to_file("res://scenes/main/CharacterLab.tscn"))
	battle.message_logged.connect(view.append_log)
	battle.action_resolved.connect(view.animate_action)
	battle.hit_resolved.connect(view.show_hit)
	battle.hit_missed.connect(view.show_miss)
	battle.dice_rolled.connect(view.show_dice)
	battle.shield_granted.connect(view.show_shield)
	pace.timeout.connect(on_pace_timeout)
	if not battle.start_battle(players, foes, battle_seed):
		push_error("Encounter requires 1–3 heroes and 1–5 enemies.")
		return
	view.bind(battle)
	battle.changed.connect(on_battle_changed)
	on_battle_changed()


func on_battle_changed() -> void:
	view.refresh()
	pace.stop()
	if battle.phase in [BattleManager.Phase.RESOLVING, BattleManager.Phase.ENEMY_TURN]:
		pace.start(action_delay)


func on_pace_timeout() -> void:
	if battle.phase == BattleManager.Phase.ENEMY_TURN:
		battle.enemy_action()
	elif battle.phase == BattleManager.Phase.RESOLVING:
		battle.advance_turn()
