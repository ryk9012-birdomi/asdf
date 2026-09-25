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
		result.append(load(path))
	return result


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


static func is_combat(map_node: RunMap.MapNode) -> bool:
	return map_node != null and map_node.type in [RunMap.NodeType.BATTLE, RunMap.NodeType.ELITE, RunMap.NodeType.BOSS]
