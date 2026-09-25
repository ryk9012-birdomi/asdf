class_name Encounters
extends RefCounted
## Which enemies wait at a map node and what they pay. Seeded per node, so reloading
## a run meets the same foes.

const RAIDER := "res://data/enemies/goblin_raider.tres"
const ARCHER := "res://data/enemies/goblin_archer.tres"
const CAPTAIN := "res://data/enemies/hobgoblin_captain.tres"
const PRIEST := "res://data/enemies/ember_priest.tres"
const SKELETON := "res://data/enemies/skeleton_warrior.tres"
const ZEALOT := "res://data/enemies/cult_zealot.tres"
const HEXER := "res://data/enemies/cult_hexer.tres"
const BERSERKER := "res://data/enemies/orc_berserker.tres"
## First floor (counting from 0) on which each foe joins the pools.
const FRONT_LINE := [[RAIDER, 0], [SKELETON, 3], [ZEALOT, 4]]
const BACK_LINE := [[ARCHER, 2], [HEXER, 5]]
const BACK_CHANCE := 0.4


static func enemies_for(run: RunState, map_node: RunMap.MapNode) -> Array[EnemyData]:
	var rng := RandomNumberGenerator.new()
	rng.seed = run.encounter_seed(map_node.id)
	var paths: Array[String] = []
	match map_node.type:
		RunMap.NodeType.ELITE:
			# Two elite bands; the orc warband only turns up deeper in the pass.
			paths.assign([BERSERKER, ZEALOT] if map_node.floor >= 6 and rng.randf() < 0.5 else [CAPTAIN, RAIDER])
		RunMap.NodeType.BOSS:
			paths = [RAIDER, PRIEST]
		_:
			var count := 2 if map_node.floor < 3 else 3
			var front: Array[String] = []
			var back: Array[String] = []
			var backs := pool(BACK_LINE, map_node.floor)
			for index in count:
				# Keep at least one foe up front so melee always has a target line.
				if index > 0 and not backs.is_empty() and rng.randf() < BACK_CHANCE:
					back.append(backs[rng.randi_range(0, backs.size() - 1)])
				else:
					var fronts := pool(FRONT_LINE, map_node.floor)
					front.append(fronts[rng.randi_range(0, fronts.size() - 1)])
			paths = front + back
	var result: Array[EnemyData] = []
	for path in paths:
		result.append(scaled(load(path), map_node.floor))
	return result


## Who leads the fight sets the scene: bosses and elites first, else the foe up front.
const OPENINGS := {
	&"ember_priest": "잿불 사제 모르간이 성소 앞에서 잿불을 피워 올립니다.",
	&"orc_berserker": "오크 광전사가 대도끼를 치켜들고 포효합니다.",
	&"hobgoblin_captain": "홉고블린 대장이 부하를 이끌고 길을 막았습니다.",
	&"goblin_raider": "고블린 약탈자들이 고갯길을 막아섰습니다.",
	&"skeleton_warrior": "무너진 묘지에서 일어난 해골 병사들이 길을 막아섰습니다.",
	&"cult_zealot": "교단 광신도들이 광기 어린 외침과 함께 달려듭니다.",
}


static func opening_line(ids: Array) -> String:
	var line := "적이 길을 막아섰습니다."
	for leader in OPENINGS:
		if leader in ids:
			line = OPENINGS[leader]
			break
	if &"cult_hexer" in ids:
		line += " 뒤에서 잿불 주술사가 저주를 읊조립니다."
	elif &"goblin_archer" in ids:
		line += " 바위 뒤에서 고블린 궁수가 시위를 당깁니다."
	return line


## Foes whose first floor has been reached.
static func pool(line: Array, floor_index: int) -> Array[String]:
	var out: Array[String] = []
	for entry in line:
		if floor_index >= entry[1]:
			out.append(entry[0])
	return out


## Deeper floors field tougher foes, so gear and upgrades keep mattering.
## Floors count from 0: +1 HP every two floors and +1 accuracy from floor 6 (7층).
## Tuned by full-run simulation: a careful bot that wears gear and upgrades skills
## wins about half its runs; one that ignores the camp rarely does.
static func scaled(data: EnemyData, floor_index: int) -> EnemyData:
	var foe := data.duplicate() as EnemyData
	foe.max_hp += floor_index / 2
	foe.hit_bonus += 1 if floor_index >= 6 else 0
	return foe


static func gold_for(run: RunState, map_node: RunMap.MapNode) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = run.encounter_seed(map_node.id) + 1
	match map_node.type:
		RunMap.NodeType.ELITE:
			return rng.randi_range(25, 35)
		RunMap.NodeType.BOSS:
			return rng.randi_range(60, 80)
		RunMap.NodeType.TREASURE:
			return rng.randi_range(30, 50)
	return rng.randi_range(8, 14)


## Three different pieces of gear to choose one from after a fight or at a chest.
static func reward_options(run: RunState, map_node: RunMap.MapNode) -> Array[String]:
	var options: Array[String] = []
	if map_node.type not in [RunMap.NodeType.BATTLE, RunMap.NodeType.ELITE, RunMap.NodeType.TREASURE]:
		return options
	var rng := RandomNumberGenerator.new()
	rng.seed = run.encounter_seed(map_node.id) + 2
	var pool: Array = Items.ALL.keys()
	while options.size() < 3 and not pool.is_empty():
		options.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return options


static func is_combat(map_node: RunMap.MapNode) -> bool:
	return map_node != null and map_node.type in [RunMap.NodeType.BATTLE, RunMap.NodeType.ELITE, RunMap.NodeType.BOSS]
