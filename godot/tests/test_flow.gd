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
	check(menu.quit_button.text == "종료" and not "training_button" in menu, "Menu has quit and no training grounds")
	check(AudioDirector.instance != null and AudioDirector.instance.current_track == "menu", "Main menu plays the menu theme")
	check(menu.music_slider != null and menu.sfx_slider != null, "Menu offers music and effect volume sliders")

	current_scene.new_run_button.pressed.emit()
	await settle()
	var run := RunState.active
	check(run != null and current_scene.name == "MapScreen", "New journey opens the map")
	check(AudioDirector.instance.current_track == "map", "Map plays the travel theme")
	check(current_scene.canvas.positions.size() == run.map.nodes.size(), "Map draws every node")
	var opening: RunMap.MapNode = run.available_nodes()[0]
	check(opening.type == RunMap.NodeType.EVENT, "The journey opens with an event")
	current_scene.canvas.node_chosen.emit(opening.id)
	await settle()
	check(current_scene.name == "NodeScreen", "Choosing the first node opens its event")
	var blessing: Dictionary = Events.for_node(run, opening)
	check(current_scene.actions.get_child_count() == blessing.choices.size(), "Every event choice is offered")
	current_scene.actions.get_child(0).pressed.emit()
	await settle()
	check(run.node_resolved and current_scene.outcome.text != "", "Picking a choice resolves the event and tells the outcome")
	current_scene.actions.get_node("ContinueButton").pressed.emit()
	await settle()
	check(current_scene.name == "MapScreen", "The event returns to the map")
	var start: RunMap.MapNode = run.map.node(opening.next[0])
	run.ward = 2
	current_scene.canvas.node_chosen.emit(start.id)
	await settle()
	if current_scene.name != "BattleScene":
		place(run, RunMap.NodeType.BATTLE)
		SceneRouter.go(self, SceneRouter.BATTLE)
		await settle()
		start = run.current_node()
	check(current_scene.name == "BattleScene", "A floor-2 fight starts its battle")
	check(current_scene.players[1].current_shield == current_scene.players[1].character_data.starting_shield + 2 and run.ward == 0, "An event blessing shields the party once")
	check(AudioDirector.instance.current_track == "battle" and "step" in AudioDirector.instance.played, "Travel steps into the battle theme")
	var view = current_scene.view
	check(not view.restart_button.visible, "Run battles offer no restart or camp detour")
	check(view.title_label.text.begins_with("%d층" % (start.floor + 1)), "Battle title names the floor")
	check(current_scene.battle.enemies.size() == Encounters.enemies_for(run, start).size(), "Battle uses the node's encounter")
	fight_out(current_scene.battle, true)
	await settle()
	check(current_scene.battle.victory and view.reward_row.visible and not view.continue_button.visible, "Victory first offers spoils")
	var cards: Array = view.reward_row.get_children().filter(func(child): return child.name.begins_with("Reward_"))
	check(cards.size() == 3 and view.reward_row.get_node("RewardSkip") != null, "Three pieces of gear to choose from, or skip")
	var stash_before := run.stash.size()
	cards[0].pressed.emit()
	check(run.stash.size() == stash_before + 1 and view.continue_button.visible, "Picking gear stashes it and opens the way back")
	check(AudioDirector.instance.current_track == "victory", "Victory jingle plays")
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
	var chest_picks: Array = current_scene.actions.get_children().filter(func(child): return child.name.begins_with("Reward_"))
	check(chest_picks.size() == 3, "A chest also offers three pieces of gear")
	var chest_stash := run.stash.size()
	chest_picks[1].pressed.emit()
	await settle()
	check(run.stash.size() == chest_stash + 1 and run.node_resolved, "Taking one item from the chest resolves it")
	current_scene.actions.get_node("ContinueButton").pressed.emit()
	await settle()

	check(current_scene.name == "MapScreen", "Chest returns to the map")
	current_scene.find_child("CampButton", true, false).pressed.emit()
	await settle()
	check(current_scene.name == "CampScreen", "The map always offers the camp")
	run.stash.erase("lucky_coin")
	run.stash.append("lucky_coin")
	current_scene.find_child("Equip_lucky_coin_0", true, false).pressed.emit()
	check(run.party[0].equipment.get("trinket") == "lucky_coin" and "lucky_coin" not in run.stash, "Camp puts a trinket on Aldric")
	run.gold = 40
	var strike: SkillData = run.party[0].definition.skills[0]
	current_scene.find_child("Upgrade_0_%s" % strike.id, true, false).pressed.emit()
	check(run.party[0].skill_level(strike) == 2 and run.gold == 25, "Upgrading a skill spends 15 gold")
	current_scene.find_child("BackButton", true, false).pressed.emit()
	await settle()
	check(current_scene.name == "MapScreen", "Camp returns to the map without spending a node")

	var fight := place(run, RunMap.NodeType.BATTLE)
	SceneRouter.go(self, SceneRouter.MAIN_MENU)
	await settle()
	check(not current_scene.continue_button.disabled, "Continue is offered while a journey is underway")
	current_scene.continue_button.pressed.emit()
	for _frame in 6:
		await process_frame
	check(current_scene.name == "BattleScene" and run.current_node_id == fight.id, "Continuing mid-node re-enters that battle")
	var aldric: CharacterUnit = current_scene.players[0]
	check(aldric.crit_threshold == 11, "Worn gear changes battle stats")
	var upgraded_strike: SkillData = aldric.character_data.skills[0]
	check(upgraded_strike.flat_value == 1 and run.party[0].definition.skills[0].flat_value == 0, "Upgraded skill fights harder without touching shared data")
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
	AudioDirector.shutdown()
	# Let the audio thread drop its playbacks before the leak check at exit.
	await create_timer(0.35).timeout
	quit(0 if failures == 0 else 1)
