class_name Encounters
extends RefCounted
## Which enemies wait at a map node and what they pay. Seeded per node, so reloading
## a run meets the same foes.

const RAIDER := "res://data/enemies/goblin_raider.tres"
const ARCHER := "res://data/enemies/goblin_archer.tres"
const CAPTAIN := "res://data/enemies/hobgoblin_captain.tres"
const PRIEST := "res://data/enemies/ember_priest.tres"
const ARCHERS_FROM := 2


static func enemies_for(run: RunState, map_node: RunMap.MapNode) -> Array[EnemyData]:
	var rng := RandomNumberGenerator.new()
	rng.seed = run.encounter_seed(map_node.id)
	var paths: Array[String] = []
	match map_node.type:
		RunMap.NodeType.ELITE:
			paths = [CAPTAIN, RAIDER]
		RunMap.NodeType.BOSS:
			paths = [RAIDER, PRIEST]
		_:
			var count := 2 if map_node.floor < 3 else 3
			var front: Array[String] = []
			var back: Array[String] = []
			for index in count:
				# Keep at least one raider up front so melee always has a target line.
				if index > 0 and map_node.floor >= ARCHERS_FROM and rng.randf() < 0.4:
					back.append(ARCHER)
				else:
					front.append(RAIDER)
			paths = front + back
	var result: Array[EnemyData] = []
	for path in paths:
		result.append(scaled(load(path), map_node.floor))
	return result


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
