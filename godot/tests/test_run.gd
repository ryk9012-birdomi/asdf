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
				if current.type != RunMap.NodeType.BATTLE:
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
