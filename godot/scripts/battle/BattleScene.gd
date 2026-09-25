extends Control
## Owns encounter creation, scene navigation and animation delays only.

@export var party_definitions: Array[CharacterData] = []
@export var enemy_definitions: Array[EnemyData] = []
@export_range(0.05, 3.0) var action_delay: float = 0.55
@export var battle_seed: int = -1
## Hold the next action until the 3D blow has played out. Tests switch it off.
@export var wait_for_animations: bool = true

@onready var battle: BattleManager = $BattleManager
@onready var view: Control = $BattleUI
@onready var pace: Timer = $ActionTimer

var run: RunState
var players: Array[CharacterUnit] = []


func _ready() -> void:
	run = RunState.active
	var in_run := run != null and not run.finished and not run.node_resolved and Encounters.is_combat(run.current_node())
	if not in_run:
		run = null
	else:
		party_definitions = run.hero_definitions()
		enemy_definitions = Encounters.enemies_for(run, run.current_node())
		battle_seed = run.encounter_seed(run.current_node().id)
	var foes: Array[CharacterUnit] = []
	for definition in party_definitions:
		var unit: CharacterUnit = preload("res://scenes/battle/CharacterUnit.tscn").instantiate()
		$Units.add_child(unit)
		if not unit.initialize(definition):
			push_error("Invalid party definition")
			return
		if run != null:
			unit.current_hp = run.party[players.size()].current_hp
			unit.current_shield += run.ward
		unit.formation_slot = mini(players.size(), 2) as CharacterUnit.FormationSlot
		players.append(unit)
	for definition in enemy_definitions:
		var unit: EnemyUnit = preload("res://scenes/battle/EnemyUnit.tscn").instantiate()
		$Units.add_child(unit)
		if not unit.initialize(definition):
			push_error("Invalid enemy definition")
			return
		unit.formation_slot = mini(foes.size(), 2) as CharacterUnit.FormationSlot
		foes.append(unit)
	if run != null:
		run.ward = 0
	# Number look-alikes only ("고블린 약탈자 01"), so a lone boss keeps its name.
	for foe in foes:
		if foes.filter(func(other): return other.character_data.id == foe.character_data.id).size() > 1:
			foe.display_name += " %02d" % (foes.find(foe) + 1)
	view.skill_requested.connect(battle.player_action)
	view.pass_requested.connect(battle.player_pass)
	view.restart_requested.connect(func(): get_tree().reload_current_scene())
	view.lab_requested.connect(func(): SceneRouter.go(get_tree(), SceneRouter.CAMP))
	view.menu_requested.connect(func(): SceneRouter.go(get_tree(), SceneRouter.MAIN_MENU))
	view.continue_requested.connect(on_continue)
	battle.battle_finished.connect(on_battle_finished)
	battle.message_logged.connect(view.append_log)
	battle.action_resolved.connect(view.animate_action)
	battle.hit_resolved.connect(view.show_hit)
	battle.hit_missed.connect(view.show_miss)
	battle.dice_rolled.connect(view.show_dice)
	battle.shield_granted.connect(view.show_shield)
	pace.timeout.connect(on_pace_timeout)
	if run != null:
		match run.current_node().type:
			RunMap.NodeType.ELITE:
				battle.opening_line = "주도권 굴림! 홉고블린 대장이 부하를 이끌고 길을 막았습니다."
			RunMap.NodeType.BOSS:
				battle.opening_line = "주도권 굴림! 잿불 사제 모르간이 성소 앞에서 잿불을 피워 올립니다."
	if not battle.start_battle(players, foes, battle_seed):
		push_error("Encounter requires 1–3 heroes and 1–5 enemies.")
		return
	view.bind(battle)
	var boss_fight := run != null and run.current_node().type == RunMap.NodeType.BOSS
	AudioDirector.music("boss" if boss_fight else "battle")
	battle.battle_finished.connect(func(victory: bool): AudioDirector.music("victory" if victory else "defeat"))
	if run != null:
		var map_node := run.current_node()
		var kind: String = "보스 · 잿불 사제" if map_node.type == RunMap.NodeType.BOSS else RunMap.TYPE_NAMES[map_node.type]
		view.set_run_mode("%d층  ·  %s" % [map_node.floor + 1, kind] if map_node.type != RunMap.NodeType.BOSS else kind)
	battle.changed.connect(on_battle_changed)
	on_battle_changed()


func on_battle_changed() -> void:
	view.refresh()
	pace.stop()
	if battle.phase == BattleManager.Phase.RESOLVING and wait_for_animations:
		pace.start(maxf(action_delay, view.animation_time_left() + 0.1))
	elif battle.phase in [BattleManager.Phase.RESOLVING, BattleManager.Phase.ENEMY_TURN]:
		pace.start(action_delay)


func on_pace_timeout() -> void:
	if battle.phase == BattleManager.Phase.ENEMY_TURN:
		battle.enemy_action()
	elif battle.phase == BattleManager.Phase.RESOLVING:
		battle.advance_turn()


func on_battle_finished(victory: bool) -> void:
	if run == null:
		return
	var map_node := run.current_node()
	run.record_battle(players, victory)
	if not victory:
		view.show_run_result("쓰러진 일행을 거둘 이도 없이, 여정이 여기서 끝났다.", "여정 결과 보기")
		return
	var gold := Encounters.gold_for(run, map_node)
	run.gold += gold
	var revived := PackedStringArray()
	for index in players.size():
		if not players[index].is_alive():
			revived.append(players[index].display_name)
	var note := "골드 +%d" % gold
	if not revived.is_empty():
		note += "   ·   %s 간신히 일어남 (HP 1)" % ", ".join(revived)
	view.show_run_result(note, "여정 결과 보기" if run.finished else "지도로 돌아가기")


func on_continue() -> void:
	if run != null:
		SceneRouter.go(get_tree(), SceneRouter.RUN_END if run.finished else SceneRouter.MAP)
