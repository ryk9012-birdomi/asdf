extends SceneTree

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)


func fixture(seed_value: int = 42) -> BattleManager:
	var battle: BattleManager = load("res://scenes/battle/BattleManager.tscn").instantiate()
	root.add_child(battle)
	var party: Array[CharacterUnit] = []
	var enemies: Array[CharacterUnit] = []
	for role in ["vanguard", "sword_master", "sharpshooter"]:
		var unit := CharacterUnit.new()
		battle.add_child(unit)
		unit.initialize(load("res://data/classes/%s.tres" % role))
		unit.formation_slot = party.size() as CharacterUnit.FormationSlot
		party.append(unit)
	for index in 3:
		var unit := EnemyUnit.new()
		battle.add_child(unit)
		unit.initialize(load("res://data/enemies/soldier.tres"))
		unit.formation_slot = index as CharacterUnit.FormationSlot
		enemies.append(unit)
	check(battle.start_battle(party, enemies, seed_value), "Valid 3v3 encounter starts")
	return battle


func step(battle: BattleManager, attack: bool) -> void:
	match battle.phase:
		BattleManager.Phase.RESOLVING:
			battle.advance_turn()
		BattleManager.Phase.ENEMY_TURN:
			battle.enemy_action()
		BattleManager.Phase.PLAYER_INPUT:
			if attack:
				var options := battle.actor.character_data.skills.duplicate()
				options.reverse()
				for skill in options:
					if skill.effect_type == SkillData.EffectType.DAMAGE and battle.skill_block_reason(skill).is_empty():
						battle.player_action(skill, battle.available_targets(skill)[0])
						return
			battle.player_pass()


func run_tests() -> void:
	test_damage()
	test_targets_and_costs()
	test_turns_and_intent()
	test_encounter_limits()
	test_group_skills()
	test_endings()
	await test_ui()
	print("Battle system: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func test_damage() -> void:
	var battle := fixture()
	var attacker := battle.actor
	var target := battle.enemies[0]
	var skill := attacker.character_data.skills[0].duplicate() as SkillData
	attacker.attack = 20
	attacker.accuracy = 1.0
	attacker.critical_chance = 0.0
	target.evasion = 0.0
	target.defense = 4
	check(DamageCalculator.roll(attacker, target, skill, battle.rng).damage == 16, "Armor subtracts once from normal hit")
	attacker.critical_chance = 1.0
	check(DamageCalculator.roll(attacker, target, skill, battle.rng).damage == 26, "Critical multiplies damage before armor")
	skill.damage_type = SkillData.DamageType.TRUE_DAMAGE
	check(DamageCalculator.roll(attacker, target, skill, battle.rng).damage == 30, "True damage ignores defense")
	attacker.accuracy = 0.0
	check(DamageCalculator.roll(attacker, target, skill, battle.rng).miss, "Zero accuracy reliably misses")
	battle.free()


func test_targets_and_costs() -> void:
	var battle := fixture()
	var actor := battle.actor
	var basic := actor.character_data.skills[0]
	var double := actor.character_data.skills[1]
	check(actor == battle.party[1], "Fastest hero acts first")
	check(battle.available_targets(basic) == [battle.enemies[0]], "Melee targets only living front")
	check(not battle.player_action(double, battle.enemies[2]), "Illegal rear target is rejected")
	check(actor.current_energy == 5 and actor.cooldowns.is_empty(), "Invalid target spends no energy or cooldown")
	check(not battle.player_action(battle.party[2].character_data.skills[0], battle.enemies[0]), "Unowned skill is rejected")
	actor.accuracy = 1.0
	actor.critical_chance = 0.0
	battle.enemies[0].evasion = 0.0
	check(battle.player_action(double, battle.enemies[0]), "Double slash accepted")
	check(battle.enemies[0].current_hp == 60, "Both hits resolve separately through shield and armor")
	check(actor.current_energy == 3 and actor.remaining_cooldown(double) == 2, "Multi-hit costs energy once and arms cooldown")
	check(not battle.player_action(double, battle.enemies[0]), "Double click cannot cause a second action")
	check(actor.current_energy == 3, "Rejected duplicate does not consume energy")
	for _index in 30:
		step(battle, false)
		if battle.phase == BattleManager.Phase.PLAYER_INPUT and battle.actor == actor:
			break
	check(actor.remaining_cooldown(double) == 1 and actor.current_energy == 4, "Next personal turn restores one energy but blocks cooldown-one skill")
	check(not battle.player_action(double, battle.enemies[0]), "Cooldown prevents reuse")
	battle.player_pass()
	for _index in 30:
		step(battle, false)
		if battle.phase == BattleManager.Phase.PLAYER_INPUT and battle.actor == actor:
			break
	check(actor.remaining_cooldown(double) == 0, "Skill is available after one skipped personal turn")
	battle.enemies[0].receive_damage(9999)
	check(battle.available_targets(basic) == [battle.enemies[1]], "Dead front exposes middle")
	var rear_skill: SkillData = battle.party[2].character_data.skills[1]
	check(battle.available_targets(rear_skill) == [battle.enemies[2]], "Rear skill targets living back")
	battle.enemies[2].receive_damage(9999)
	check(battle.available_targets(rear_skill) == [battle.enemies[1]], "Dead rear falls back to last living enemy")
	battle.free()


func test_turns_and_intent() -> void:
	var battle := fixture()
	var enemy := battle.enemies[0] as EnemyUnit
	check(enemy.intended_skill().id == &"soldier_shot", "Soldier opens with attack")
	for _index in 20:
		if battle.actor == enemy and battle.phase == BattleManager.Phase.ENEMY_TURN:
			break
		step(battle, false)
	battle.enemy_action()
	check(enemy.pattern_cursor == 1 and enemy.intended_skill(true).id == &"soldier_guard", "Next intent advances to shield")
	enemy.pattern_cursor = 2
	check(enemy.intended_skill(true).id == &"soldier_burst", "Third pattern entry is heavy shot")
	enemy.current_energy = 0
	check(enemy.intended_skill().id == &"soldier_shot", "Unaffordable AI action falls back to basic")
	battle.enemies[1].receive_damage(9999)
	battle.advance_turn()
	check(battle.actor == battle.enemies[2], "Dead queued actor is skipped; equal-speed order stays stable")
	battle.free()


func test_encounter_limits() -> void:
	var battle := fixture()
	var foes: Array[CharacterUnit] = battle.enemies.duplicate()
	for index in 2:
		var extra := EnemyUnit.new()
		battle.add_child(extra)
		extra.initialize(load("res://data/enemies/soldier.tres"))
		extra.formation_slot = CharacterUnit.FormationSlot.BACK
		foes.append(extra)
	check(battle.start_battle(battle.party, foes, 7), "Three heroes versus five enemies is supported")
	check(battle.turns.queue.size() == 8, "Eight participants enter the queue")
	foes.append(foes[0])
	check(not battle.start_battle(battle.party, foes), "Six enemies are rejected")
	check(battle.enemies.size() == 5, "Invalid encounter leaves active state intact")
	var repeated: Array[CharacterUnit] = [battle.enemies[0], battle.enemies[0]]
	check(not battle.start_battle(battle.party, repeated), "Duplicate combatant instances are rejected")
	battle.free()


func test_group_skills() -> void:
	for target_type in [SkillData.TargetType.ALL_ENEMIES, SkillData.TargetType.ALL_ALLIES, SkillData.TargetType.RANDOM_ENEMY, SkillData.TargetType.ALLY, SkillData.TargetType.SELF]:
		var battle := fixture()
		var actor := battle.actor
		var definition := actor.character_data.duplicate(true) as CharacterData
		var skill := SkillData.new()
		skill.id = &"test_effect"
		skill.target_type = target_type as SkillData.TargetType
		skill.energy_cost = 2
		var allied: bool = target_type in [SkillData.TargetType.ALL_ALLIES, SkillData.TargetType.ALLY, SkillData.TargetType.SELF]
		skill.effect_type = SkillData.EffectType.SHIELD if allied else SkillData.EffectType.DAMAGE
		skill.attack_multiplier = 0.0
		skill.flat_value = 20
		definition.skills.append(skill)
		actor.initialize(definition)
		actor.accuracy = 1.0
		actor.critical_chance = 0.0
		for foe in battle.enemies:
			foe.evasion = 0.0
		var legal := battle.available_targets(skill)
		check(battle.player_action(skill, legal[0]), "Generic target type executes: %d" % target_type)
		check(actor.current_energy == actor.max_energy - 2, "Group/random skill charges cost once")
		if target_type == SkillData.TargetType.ALL_ENEMIES:
			check(battle.enemies.all(func(foe): return foe.current_hp == 70), "AoE reaches all living opponents")
		elif target_type == SkillData.TargetType.ALL_ALLIES:
			check(battle.party.all(func(hero): return hero.current_shield == hero.character_data.starting_shield + 20), "Party shield reaches every ally")
		elif target_type == SkillData.TargetType.RANDOM_ENEMY:
			check(battle.enemies.filter(func(foe): return foe.current_hp < foe.max_hp).size() == 1, "Random target hits exactly one opponent")
		else:
			check(legal[0].current_shield == legal[0].character_data.starting_shield + 20, "Single ally/self receives shield")
		battle.free()


func test_endings() -> void:
	for seed_value in range(1, 9):
		var battle := fixture(seed_value)
		var events := [0]
		battle.battle_finished.connect(func(_won: bool): events[0] += 1)
		for _index in 1000:
			if battle.phase == BattleManager.Phase.FINISHED:
				break
			step(battle, true)
		check(battle.phase == BattleManager.Phase.FINISHED and battle.victory, "Offensive play wins complete battle, seed %d" % seed_value)
		battle.check_outcome()
		battle.advance_turn()
		check(events[0] == 1, "Victory emits once; finished battle cannot restart turns")
		print("Seed %d: victory=%s, rounds=%d" % [seed_value, battle.victory, battle.turns.round_number])
		battle.free()
	var losing_battle := fixture()
	for _index in 1000:
		if losing_battle.phase == BattleManager.Phase.FINISHED:
			break
		step(losing_battle, false)
	check(losing_battle.phase == BattleManager.Phase.FINISHED and not losing_battle.victory, "Passive play reaches party-wipe defeat")
	check(not losing_battle.player_pass(), "No actions allowed after defeat")
	losing_battle.free()


func test_ui() -> void:
	var scene: Control = load("res://scenes/battle/BattleScene.tscn").instantiate()
	scene.battle_seed = 42
	scene.action_delay = 0.05
	root.add_child(scene)
	current_scene = scene
	await process_frame
	check(scene.view.cards.size() == 6, "Battle UI displays six combatants")
	scene.view.skill_row.get_child(0).pressed.emit()
	var front: CharacterUnit = scene.battle.enemies[0]
	check(not scene.view.cards[front].disabled and scene.view.cards[scene.battle.enemies[1]].disabled, "Skill button highlights only legal target")
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://test-output")
		check(root.get_texture().get_image().save_png("res://test-output/battle.png") == OK, "Battle screenshot saved")
	scene.view.cards[front].pressed.emit()
	check(scene.battle.phase == BattleManager.Phase.RESOLVING and scene.view.selected_skill == null, "Target click resolves and locks commands")
	await create_timer(0.15).timeout
	check(scene.battle.actor == scene.battle.party[2], "Scene timer advances to next hero")
	for enemy in scene.battle.enemies:
		enemy.accuracy = 1.0
	scene.battle.party[0].evasion = 0.0
	scene.view.pass_requested.emit()
	await create_timer(0.65).timeout
	check(scene.battle.phase == BattleManager.Phase.PLAYER_INPUT and scene.battle.actor == scene.battle.party[0], "AI timer chain resolves all three enemies then returns player control")
	check(scene.battle.party[0].current_hp < 140, "Automated enemies apply actual damage")
	scene.view.skill_row.get_child(1).pressed.emit()
	scene.view.cards[scene.battle.party[0]].pressed.emit()
	check(scene.battle.party[0].current_shield == 25 and scene.battle.party[0].current_energy == 3, "Guard UI applies self shield and cost")
	for _index in 1000:
		if scene.battle.phase == BattleManager.Phase.FINISHED:
			break
		step(scene.battle, true)
	check(scene.battle.victory and scene.view.result_label.visible and scene.pace.is_stopped(), "Victory panel appears and AI timer stops")
	scene.view.restart_requested.emit()
	await process_frame
	await process_frame
	check(current_scene != scene and current_scene.battle.party[0].current_hp == 140, "Restart creates a fresh encounter")
	current_scene.view.lab_requested.emit()
	await process_frame
	await process_frame
	check(current_scene.name == "CharacterLab", "Battle can navigate to lab")
	current_scene.get_node("%BattleButton").pressed.emit()
	await process_frame
	await process_frame
	check(current_scene.name == "BattleScene", "Lab can return to battle")
	for _index in 1000:
		if current_scene.battle.phase == BattleManager.Phase.FINISHED:
			break
		step(current_scene.battle, false)
	check(not current_scene.battle.victory and current_scene.view.result_label.visible and current_scene.pace.is_stopped(), "Defeat panel appears and AI timer stops")
	current_scene.free()
