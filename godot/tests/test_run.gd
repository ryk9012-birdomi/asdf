extends SceneTree
## Run with --headless --path godot --script res://tests/test_run.gd.

const SEEDS := 300

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)


func run_tests() -> void:
	test_map_rules()
	test_determinism_and_saves()
	test_travel()
	test_party_persistence()
	test_events()
	test_any_party()
	test_gear_and_upgrades()
	print("Run system: %d checks, %d failures" % [checks, failures])
	AudioDirector.shutdown()
	# Let the audio thread drop its playbacks before the leak check at exit.
	await create_timer(0.35).timeout
	quit(0 if failures == 0 else 1)


## Aggregates every seed into one check per rule so failures name the rule and seed.
func test_map_rules() -> void:
	var broken := {}
	var seen_types := {}
	var total_nodes := 0
	for map_seed in range(1, SEEDS + 1):
		var map := RunMap.generate(map_seed)
		total_nodes += map.nodes.size()
		for rule in rule_violations(map):
			if not broken.has(rule):
				broken[rule] = map_seed
		for current in map.nodes:
			seen_types[current.type] = true
	for rule in ["floors", "boss", "links", "crossing", "reachable", "exits", "fixed floors", "early elite", "early rest", "repeat", "starts"]:
		check(not broken.has(rule), "Map rule '%s' holds for %d seeds%s" % [rule, SEEDS, "" if not broken.has(rule) else " (first failure: seed %d)" % broken[rule]])
	# The checker itself must notice broken maps, or the rules above prove nothing.
	var tampered := RunMap.generate(3)
	tampered.start_nodes()[0].type = RunMap.NodeType.REST
	check("fixed floors" in rule_violations(tampered) and "early rest" in rule_violations(tampered), "Checker catches a rest on floor 1")
	tampered = RunMap.generate(3)
	for floor_index in RunMap.FLOORS - 2:
		var lower := tampered.floor_nodes(floor_index)
		var upper := tampered.floor_nodes(floor_index + 1)
		if lower.size() >= 2 and upper.size() >= 2:
			tampered.link(lower[0], upper[upper.size() - 1])
			tampered.link(lower[lower.size() - 1], upper[0])
			break
	check("crossing" in rule_violations(tampered), "Checker catches crossing links")
	tampered = RunMap.generate(3)
	tampered.nodes[0].next.clear()
	check("exits" in rule_violations(tampered), "Checker catches a dead end")
	for type in RunMap.NodeType.values():
		check(seen_types.has(type), "Node type %s appears somewhere" % RunMap.TYPE_NAMES[type])
	var average := float(total_nodes) / SEEDS
	check(average >= 20.0 and average <= 40.0, "Map size stays playable (avg %.1f nodes)" % average)


func rule_violations(map: RunMap) -> Array[String]:
	var found: Array[String] = []
	for floor_index in RunMap.FLOORS:
		if map.floor_nodes(floor_index).is_empty():
			found.append("floors")
	var boss := map.node(map.boss_id)
	if boss == null or boss.type != RunMap.NodeType.BOSS or map.floor_nodes(RunMap.BOSS_FLOOR).size() != 1:
		found.append("boss")
	elif boss.previous.size() != map.floor_nodes(RunMap.FLOORS - 1).size():
		found.append("boss")
	if map.start_nodes().size() < 2:
		found.append("starts")
	for current in map.nodes:
		if current.type != RunMap.NodeType.BOSS and current.next.is_empty():
			found.append("exits")
		for next_id in current.next:
			var upper := map.node(next_id)
			if upper.floor != current.floor + 1 or (upper.type != RunMap.NodeType.BOSS and absi(upper.column - current.column) > 1):
				found.append("links")
			if current.id not in upper.previous:
				found.append("links")
			if current.type == upper.type and current.type in [RunMap.NodeType.ELITE, RunMap.NodeType.REST] and upper.floor != RunMap.REST_FLOOR:
				found.append("repeat")
		match current.floor:
			0:
				if current.type != RunMap.NodeType.EVENT:
					found.append("fixed floors")
			1:
				if current.type == RunMap.NodeType.EVENT:
					found.append("fixed floors")
			RunMap.TREASURE_FLOOR:
				if current.type != RunMap.NodeType.TREASURE:
					found.append("fixed floors")
			RunMap.REST_FLOOR:
				if current.type != RunMap.NodeType.REST:
					found.append("fixed floors")
		if current.type == RunMap.NodeType.ELITE and current.floor < RunMap.ELITE_FROM:
			found.append("early elite")
		if current.type == RunMap.NodeType.REST and current.floor < RunMap.REST_FROM:
			found.append("early rest")
	# No two edges between the same floors may swap sides.
	for floor_index in RunMap.FLOORS - 1:
		var edges: Array[Vector2i] = []
		for current in map.floor_nodes(floor_index):
			for next_id in current.next:
				edges.append(Vector2i(current.column, map.node(next_id).column))
		for a in edges:
			for b in edges:
				if (a.x < b.x and a.y > b.y) or (a.x > b.x and a.y < b.y):
					found.append("crossing")
	# Every node sits on some start → boss route.
	var reached := {}
	var frontier: Array[int] = []
	for start in map.start_nodes():
		frontier.append(start.id)
	while not frontier.is_empty():
		var id: int = frontier.pop_back()
		if reached.has(id):
			continue
		reached[id] = true
		frontier.append_array(map.node(id).next)
	if reached.size() != map.nodes.size():
		found.append("reachable")
	return found


func test_determinism_and_saves() -> void:
	var first := RunMap.generate(77)
	var second := RunMap.generate(77)
	check(first.to_dict() == second.to_dict(), "Same seed builds the identical map")
	var differs := false
	for map_seed in range(78, 90):
		if RunMap.generate(map_seed).to_dict() != first.to_dict():
			differs = true
	check(differs, "Different seeds build different maps")
	var restored := RunMap.from_dict(JSON.parse_string(JSON.stringify(first.to_dict())))
	check(restored.to_dict() == first.to_dict(), "Map survives a JSON save round trip")
	check(restored.node(restored.boss_id).previous.size() == first.node(first.boss_id).previous.size(), "Restored map keeps backward links")


func heroes() -> Array[CharacterData]:
	var list: Array[CharacterData] = []
	for role in ["paladin", "rogue", "wizard"]:
		list.append(load("res://data/classes/%s.tres" % role))
	return list


func test_travel() -> void:
	var run := RunState.begin(2024, heroes())
	check(RunState.active == run, "Beginning a run makes it the active run")
	check(run.current_node_id == -1 and run.current_floor() == -1, "Run starts below the first floor")
	var starts := run.available_nodes()
	check(starts.size() == run.map.start_nodes().size(), "First choice is any starting node")
	var upper := run.map.floor_nodes(1)[0]
	check(not run.travel(upper.id), "Cannot skip the first floor")
	check(run.travel(starts[0].id) and run.current_floor() == 0, "Travel to a start node")
	check(run.visited == [starts[0].id], "Visited path is recorded")
	check(run.available_nodes().is_empty(), "Cannot move on before the node is resolved")
	run.resolve_current()
	var off_path := run.map.nodes.filter(func(candidate): return candidate.floor == 1 and candidate.id not in starts[0].next)
	if not off_path.is_empty():
		check(not run.travel(off_path[0].id), "Cannot jump to an unconnected node")
	check(not run.travel(starts[0].id), "Cannot stay on the same node")
	while run.current_node().type != RunMap.NodeType.BOSS:
		check(run.travel(run.available_nodes()[0].id), "Climb floor %d" % (run.current_floor() + 1))
		run.resolve_current()
	check(run.visited.size() == RunMap.FLOORS + 1, "A full climb visits one node per floor plus the boss")
	check(run.available_nodes().is_empty(), "Nothing lies beyond the boss")
	check(run.encounter_seed(5) == RunState.begin(2024, heroes()).encounter_seed(5), "Encounter seeds are reproducible")


func test_party_persistence() -> void:
	var run := RunState.begin(9, heroes())
	check(run.party.size() == 3 and run.party[0].current_hp == 10, "Party starts at full HP")
	run.travel(run.available_nodes()[0].id)
	var units: Array[CharacterUnit] = []
	for hero in run.party:
		var unit := CharacterUnit.new()
		root.add_child(unit)
		unit.initialize(hero.definition)
		units.append(unit)
	units[0].receive_damage(3 + units[0].current_shield)
	units[2].receive_damage(99)
	run.record_battle(units, true)
	check(run.party[0].current_hp == 7, "Damage carries over between battles")
	check(run.party[2].current_hp == 1, "Downed hero gets up with 1 HP after a victory")
	check(not run.finished, "Winning an ordinary battle keeps the run going")
	var healed := run.rest()
	check(run.party[0].current_hp == 10 and run.party[2].current_hp == 4, "Rest heals 40% of max HP, rounded up and capped")
	check(healed == 6, "Rest reports total healing")
	for unit in units:
		unit.receive_damage(99)
	run.record_battle(units, false)
	check(run.finished and not run.victory, "A lost battle ends the run in defeat")
	check(run.available_nodes().is_empty(), "A finished run offers no travel")
	var boss_run := RunState.begin(9, heroes())
	while boss_run.current_node() == null or boss_run.current_node().type != RunMap.NodeType.BOSS:
		boss_run.travel(boss_run.available_nodes()[0].id)
		if boss_run.current_node().type != RunMap.NodeType.BOSS:
			boss_run.resolve_current()
	for unit in units:
		unit.initialize(unit.character_data)
	boss_run.record_battle(units, true)
	check(boss_run.finished and boss_run.victory, "Beating the boss wins the run")
	for unit in units:
		unit.free()


func test_events() -> void:
	var run := RunState.begin(31, heroes())
	for map_node in run.map.start_nodes():
		check(Events.for_node(run, map_node) in Events.OPENING, "Floor 1 draws from the opening events")
	var deeper: RunMap.MapNode = run.map.nodes.filter(func(candidate): return candidate.floor > 0 and candidate.type == RunMap.NodeType.EVENT)[0]
	check(Events.for_node(run, deeper) in Events.JOURNEY, "Later events draw from the journey pool")
	for event in Events.OPENING + Events.JOURNEY:
		check(event.choices.size() >= 2, "Event %s offers a real choice" % event.id)
		for choice in event.choices:
			if choice.has("check"):
				var odds := Events.chance(run, choice.check)
				check(odds > 0.0 and odds < 1.0 and choice.has("success") and choice.has("failure"), "Check in %s can go either way (%d%%)" % [event.id, roundi(odds * 100)])
	var gamble: Dictionary = Events.JOURNEY.filter(func(event): return event.id == "goblin_gambler")[0].choices[0]
	check(is_equal_approx(Events.chance(run, gamble.check), 15 / 36.0), "Plain 2d6 >= 8 is 15/36")
	run.gold = 5
	check(not Events.affordable(run, gamble), "A bet needs the gold up front")
	for hero in run.party:
		hero.current_hp = 2
	Events.apply(run, {"hurt": [Events.ALL, 5]})
	check(run.party.all(func(hero): return hero.current_hp == 1), "Events wound but never kill")
	Events.apply(run, {"heal": 3, "gold": -99, "ward": 2})
	check(run.party[0].current_hp == 4 and run.gold == 0 and run.ward == 2, "Heal, gold floor at zero and ward stack up")
	var cart: Dictionary = Events.OPENING.filter(func(event): return event.id == "broken_cart")[0]
	var start := run.map.start_nodes()[0]
	var first := Events.resolve(RunState.begin(31, heroes()), start, cart.choices[0])
	var second := Events.resolve(RunState.begin(31, heroes()), start, cart.choices[0])
	check(first.roll.dice == second.roll.dice and first.roll.total == first.roll.dice[0] + first.roll.dice[1] + 1, "Event rolls are seeded and add the hero's bonus")


func test_any_party() -> void:
	var twins := RunState.begin_party(12, ["rogue", "rogue", "wizard"], ["미렌", "카시", "아리엘"])
	check(twins.party[0].definition != twins.party[1].definition and twins.party[1].definition.character_name == "카시", "Repeated classes get their own named copies")
	var cart: Dictionary = Events.OPENING.filter(func(event): return event.id == "broken_cart")[0]
	check(not Events.available(twins, cart.choices[0]) and Events.blocked_reason(twins, cart.choices[0]) == "일행에 기사가 없습니다", "A knight's check needs a knight")
	check(Events.available(twins, cart.choices[1]) and Events.describe_check(twins, cart.choices[1]).begins_with("미렌 판정"), "The first hero of a class takes its check")
	check(Events.text(twins, "{rogue/이} 웃었다. {wizard/은} 보았다. {rogue/을} 불렀다.") == "미렌이 웃었다. 아리엘은 보았다. 미렌을 불렀다.", "Names take the right particle after a closed syllable")
	var open := RunState.begin_party(12, ["paladin", "rogue", "wizard"], ["세라", "카시", "아리"])
	check(Events.text(open, "{paladin/이} {rogue/은} {wizard/을} {paladin/과}") == "세라가 카시는 아리를 세라와", "Names take the right particle after an open syllable")
	check(Events.text(twins, "{paladin/이} 표식을 부순다") == "미렌이 표식을 부순다", "A missing class falls back to the first hero")
	for hero in twins.party:
		hero.current_hp = 5
	Events.apply(twins, {"hurt": ["wizard", 3]})
	check(twins.party[2].current_hp == 2 and twins.party[0].current_hp == 5, "Hurting a class hurts that hero only")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var names := []
	for _index in 40:
		names.append(Names.random("wizard", rng, names))
	check(names.size() == 40 and names.all(func(name): return name.length() >= 2 and not Names.stutters(name)), "Random names are unique and read well")


func test_gear_and_upgrades() -> void:
	var run := RunState.begin(55, heroes())
	check(run.stash == Items.STARTING_STASH, "A journey starts with the starter gear stashed")
	check(not run.equip(0, "honed_sword"), "Only stashed gear can be worn")
	run.stash.append("chain_shirt")
	check(run.equip(0, "chain_shirt") and run.party[0].max_hp() == 12 and run.party[0].current_hp == 12, "Armor raises max and current HP")
	check(run.equip(0, "leather_vest") and "chain_shirt" in run.stash and run.party[0].max_hp() == 10, "Swapping armor returns the old piece to the stash")
	var fighter := run.party[0].battle_definition()
	check(fighter.defense == 3 and fighter.get_validation_errors().is_empty(), "Battle definition includes gear bonuses")
	check(run.unequip(0, "armor") and run.party[0].equipment.is_empty(), "Gear can be taken off")
	for item_id in Items.ALL:
		check(Items.item(item_id).slot in Items.SLOTS and not Items.describe(item_id).is_empty(), "Item %s has a slot and a bonus" % item_id)
	var strike: SkillData = run.party[0].definition.skills[0]
	var guard: SkillData = run.party[0].definition.skills[1]
	check(not run.can_upgrade(0, strike), "Upgrades cost gold")
	run.gold = 100
	check(run.upgrade_skill(0, guard) and run.upgrade_skill(0, guard), "A skill can be raised to level 3")
	check(run.gold == 55 and not run.can_upgrade(0, guard), "Costs 15 then 30 gold; level 3 is the cap")
	var improved := run.party[0].upgraded(guard)
	check(improved.flat_value == guard.flat_value + 2 and improved.energy_cost == guard.energy_cost - 1, "Level 3: +2 effect and 1 MP cheaper")
	check(guard.flat_value == 3, "The shared skill resource is untouched")
	var options := Encounters.reward_options(run, run.map.start_nodes()[0])
	check(options.is_empty(), "Events give no gear picks")
	var fight: RunMap.MapNode = run.map.nodes.filter(func(candidate): return candidate.type == RunMap.NodeType.BATTLE)[0]
	options = Encounters.reward_options(run, fight)
	check(options.size() == 3 and options[0] != options[1] and options[1] != options[2] and options[0] != options[2], "Battle spoils are three different items")
	check(options == Encounters.reward_options(run, fight), "Spoils are seeded per node")
	var raider_low := Encounters.scaled(load(Encounters.RAIDER), 1)
	var raider_high := Encounters.scaled(load(Encounters.RAIDER), 8)
	check(raider_high.max_hp == raider_low.max_hp + 4 and raider_high.hit_bonus == raider_low.hit_bonus + 1, "Deeper floors field tougher goblins")
	# Who turns up where: goblins early, the dead and the cult deeper, orcs as late elites.
	var seen := {}
	var lines_ok := true
	for floor_index in 10:
		for id in 40:
			var node := node_at(1000 + floor_index * 100 + id, floor_index, RunMap.NodeType.BATTLE)
			var foes := Encounters.enemies_for(run, node)
			lines_ok = lines_ok and foes.size() == (2 if floor_index < 3 else 3) and foes[0].id in [&"goblin_raider", &"skeleton_warrior", &"cult_zealot"]
			for foe in foes:
				seen[foe.id] = mini(seen.get(foe.id, 99), floor_index)
	check(lines_ok, "Every fight has the right size and a front-line foe first")
	check(seen.get(&"goblin_archer") == 2 and seen.get(&"skeleton_warrior") == 3 and seen.get(&"cult_zealot") == 4 and seen.get(&"cult_hexer") == 5, "New foes join the pools floor by floor")
	var elites := {}
	for id in 40:
		for foe in Encounters.enemies_for(run, node_at(3000 + id, 7, RunMap.NodeType.ELITE)):
			elites[foe.id] = true
	check(elites.has(&"orc_berserker") and elites.has(&"hobgoblin_captain"), "Deep elites are either the hobgoblin captain or the orc berserker")
	check(Encounters.enemies_for(run, node_at(3100, 5, RunMap.NodeType.ELITE))[0].id == &"hobgoblin_captain", "Early elites are always the captain")
	check(Encounters.opening_line([&"cult_zealot", &"orc_berserker"]).begins_with("오크 광전사") and Encounters.opening_line([&"skeleton_warrior", &"cult_hexer"]).ends_with("읊조립니다."), "The opening line names who leads the fight")
	for path in [Encounters.RAIDER, Encounters.ARCHER, Encounters.CAPTAIN, Encounters.PRIEST, Encounters.SKELETON, Encounters.ZEALOT, Encounters.HEXER, Encounters.BERSERKER]:
		var data: EnemyData = load(path)
		check(data.get_validation_errors().is_empty() and HeroPuppet.RIGS.has(data.id), "%s is valid and has a puppet" % data.character_name)
	check(load(Encounters.RAIDER).max_hp == 6, "Scaling never edits the shared enemy data")


func node_at(id: int, floor_index: int, type: RunMap.NodeType) -> RunMap.MapNode:
	var node := RunMap.MapNode.new(id, floor_index, 0)
	node.type = type
	return node
