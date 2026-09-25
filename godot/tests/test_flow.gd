extends SceneTree
## Run with --headless --path godot --script res://tests/test_flow.gd.

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)


func settle() -> void:
	for _frame in 3:
		await process_frame


func step(battle: BattleManager, attack: bool) -> void:
	match battle.phase:
		BattleManager.Phase.RESOLVING:
			battle.advance_turn()
		BattleManager.Phase.ENEMY_TURN:
			battle.enemy_action()
		BattleManager.Phase.PLAYER_INPUT:
			if attack:
				for skill in battle.actor.character_data.skills:
					if skill.effect_type == SkillData.EffectType.DAMAGE and battle.skill_block_reason(skill).is_empty():
						battle.player_action(skill, battle.available_targets(skill)[0])
						return
			battle.player_pass()


func fight_out(battle: BattleManager, heroes_win: bool) -> void:
	var side := battle.party if heroes_win else battle.enemies
	for unit in side:
		unit.hit_bonus = 20
		unit.crit_threshold = 13
	for _index in 2000:
		if battle.phase == BattleManager.Phase.FINISHED:
			return
		step(battle, heroes_win)


func place(run: RunState, type: RunMap.NodeType) -> RunMap.MapNode:
	var target: RunMap.MapNode = run.map.nodes.filter(func(candidate): return candidate.type == type)[0]
	run.current_node_id = target.id
	run.visited.append(target.id)
	run.node_resolved = false
	return target


func run_tests() -> void:
	check(ProjectSettings.get_setting("application/run/main_scene") == SceneRouter.MAIN_MENU, "Project starts on the main menu")
	RunState.active = null
	change_scene_to_file(SceneRouter.MAIN_MENU)
	await settle()
	var menu := current_scene
	check(menu.name == "MainMenu", "Main menu loads")
	check(menu.new_run_button.text == "새 여정" and not menu.new_run_button.disabled, "New journey is available")
	check(menu.continue_button.disabled, "Continue is disabled without a journey")
	check(menu.camp_button.text == "야영지" and menu.quit_button.text == "종료", "Camp and quit entries exist")
	menu.camp_button.pressed.emit()
	await settle()
	check(current_scene.name == "CharacterLab", "Menu opens the camp")
	current_scene.get_node("%ResetButton").get_parent().get_node("MenuButton").pressed.emit()
	await settle()
	check(current_scene.name == "MainMenu", "Camp returns to the main menu")

	current_scene.new_run_button.pressed.emit()
	await settle()
	var run := RunState.active
	check(run != null and current_scene.name == "MapScreen", "New journey opens the map")
	check(current_scene.canvas.positions.size() == run.map.nodes.size(), "Map draws every node")
	var start: RunMap.MapNode = run.available_nodes()[0]
	current_scene.canvas.node_chosen.emit(start.id)
	await settle()
	check(current_scene.name == "BattleScene", "Choosing a floor-1 node starts its battle")
	var view = current_scene.view
	check(not view.restart_button.visible and not view.lab_button.visible, "Run battles offer no restart or camp detour")
	check(view.title_label.text.begins_with("1층"), "Battle title names the floor")
	check(current_scene.battle.enemies.size() == Encounters.enemies_for(run, start).size(), "Battle uses the node's encounter")
	fight_out(current_scene.battle, true)
	await settle()
	check(current_scene.battle.victory and view.continue_button.visible, "Victory offers the way back to the map")
	check(run.node_resolved and run.battles_won == 1 and run.gold > 0, "Victory resolves the node and pays gold")
	var carried: Array[int] = []
	for unit in current_scene.players:
		carried.append(maxi(unit.current_hp, 1))
	check(run.party.map(func(hero): return hero.current_hp) == carried, "Battle HP is written back to the party")
	view.continue_button.pressed.emit()
	await settle()
	check(current_scene.name == "MapScreen", "Continue returns to the map")
	check(current_scene.canvas.reachable().size() == start.next.size(), "Only the next floor's linked nodes are open")

	run.party[0].current_hp = 2
	place(run, RunMap.NodeType.REST)
	SceneRouter.go(self, SceneRouter.NODE)
	await settle()
	check(current_scene.name == "NodeScreen", "Rest node opens the camp fire screen")
	current_scene.actions.get_child(0).pressed.emit()
	await settle()
	check(run.party[0].current_hp == 6 and run.node_resolved, "Resting heals and resolves the node")
	current_scene.actions.get_node("ContinueButton").pressed.emit()
	await settle()
	check(current_scene.name == "MapScreen", "Rest returns to the map")
	var gold_before := run.gold
	place(run, RunMap.NodeType.TREASURE)
	SceneRouter.go(self, SceneRouter.NODE)
	await settle()
	current_scene.actions.get_child(0).pressed.emit()
	await settle()
	check(run.gold > gold_before, "Opening the chest adds gold")

	var fight := place(run, RunMap.NodeType.BATTLE)
	SceneRouter.go(self, SceneRouter.MAIN_MENU)
	await settle()
	check(not current_scene.continue_button.disabled, "Continue is offered while a journey is underway")
	current_scene.continue_button.pressed.emit()
	for _frame in 6:
		await process_frame
	check(current_scene.name == "BattleScene" and run.current_node_id == fight.id, "Continuing mid-node re-enters that battle")
	fight_out(current_scene.battle, false)
	await settle()
	check(run.finished and not run.victory, "A lost battle ends the journey")
	current_scene.view.continue_button.pressed.emit()
	await settle()
	check(current_scene.name == "RunEndScreen", "Defeat leads to the journey summary")
	current_scene.menu_button.pressed.emit()
	await settle()
	check(current_scene.name == "MainMenu" and RunState.active == null and current_scene.continue_button.disabled, "Leaving the summary clears the journey")
	await create_timer(0.6).timeout
	var veils := root.get_children().filter(func(node): return node is CanvasLayer)
	check(veils.is_empty(), "Transition veils clean themselves up")
	print("Game flow: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
