class_name RunMap
extends RefCounted
## Slay the Spire style act map: non-crossing paths climb a floor × column grid to one boss.
## Pure data and rules; the same seed always yields the same map.

enum NodeType { BATTLE, ELITE, REST, EVENT, TREASURE, BOSS }

const FLOORS := 10
const COLUMNS := 5
const PATHS := 4
const ELITE_FROM := 4
const REST_FROM := 3
const TREASURE_FLOOR := 5
const REST_FLOOR := FLOORS - 1
const BOSS_FLOOR := FLOORS
const TYPE_WEIGHTS := {NodeType.BATTLE: 45, NodeType.EVENT: 25, NodeType.ELITE: 16, NodeType.REST: 14}
const TYPE_NAMES := ["전투", "정예", "휴식", "이벤트", "보물", "보스"]

var seed_value: int = 0
var nodes: Array[MapNode] = []
var boss_id: int = -1


class MapNode:
	var id: int
	var floor: int
	var column: int
	var type: NodeType = NodeType.BATTLE
	var next: Array[int] = []
	var previous: Array[int] = []

	func _init(node_id: int, node_floor: int, node_column: int) -> void:
		id = node_id
		floor = node_floor
		column = node_column


static func generate(map_seed: int) -> RunMap:
	var map := RunMap.new()
	map.seed_value = map_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	map.carve_paths(rng)
	map.assign_types(rng)
	return map


func node(id: int) -> MapNode:
	return nodes[id] if id >= 0 and id < nodes.size() else null


func floor_nodes(floor_index: int) -> Array[MapNode]:
	var result: Array[MapNode] = []
	for candidate in nodes:
		if candidate.floor == floor_index:
			result.append(candidate)
	result.sort_custom(func(a: MapNode, b: MapNode): return a.column < b.column)
	return result


func start_nodes() -> Array[MapNode]:
	return floor_nodes(0)


func carve_paths(rng: RandomNumberGenerator) -> void:
	var grid := {}
	var first_start := -1
	for path in PATHS:
		var column := rng.randi_range(0, COLUMNS - 1)
		# Like the original, the first two paths never share a starting point.
		while path == 1 and column == first_start:
			column = rng.randi_range(0, COLUMNS - 1)
		if path == 0:
			first_start = column
		var current := node_at(grid, 0, column)
		for floor_index in range(0, FLOORS - 1):
			var options: Array[int] = []
			for step in [-1, 0, 1]:
				var target: int = current.column + step
				if target >= 0 and target < COLUMNS and not crosses(grid, floor_index, current.column, target):
					options.append(target)
			var upper := node_at(grid, floor_index + 1, options[rng.randi_range(0, options.size() - 1)])
			link(current, upper)
			current = upper
	var boss := MapNode.new(nodes.size(), BOSS_FLOOR, COLUMNS / 2)
	boss.type = NodeType.BOSS
	nodes.append(boss)
	boss_id = boss.id
	for top in floor_nodes(FLOORS - 1):
		link(top, boss)


func node_at(grid: Dictionary, floor_index: int, column: int) -> MapNode:
	var key := Vector2i(floor_index, column)
	if not grid.has(key):
		var created := MapNode.new(nodes.size(), floor_index, column)
		nodes.append(created)
		grid[key] = created
	return grid[key]


## An edge a→b on this floor crosses an existing x→y when they swap sides.
func crosses(grid: Dictionary, floor_index: int, from_column: int, to_column: int) -> bool:
	for column in COLUMNS:
		var key := Vector2i(floor_index, column)
		if not grid.has(key):
			continue
		for next_id in grid[key].next:
			var target: int = nodes[next_id].column
			if (column < from_column and target > to_column) or (column > from_column and target < to_column):
				return true
	return false


func link(lower: MapNode, upper: MapNode) -> void:
	if upper.id not in lower.next:
		lower.next.append(upper.id)
		upper.previous.append(lower.id)


func assign_types(rng: RandomNumberGenerator) -> void:
	for floor_index in FLOORS:
		for current in floor_nodes(floor_index):
			if floor_index == 0:
				current.type = NodeType.BATTLE
			elif floor_index == TREASURE_FLOOR:
				current.type = NodeType.TREASURE
			elif floor_index == REST_FLOOR:
				current.type = NodeType.REST
			else:
				current.type = pick_type(current, rng)


func pick_type(current: MapNode, rng: RandomNumberGenerator) -> NodeType:
	var banned: Array[NodeType] = []
	if current.floor < ELITE_FROM:
		banned.append(NodeType.ELITE)
	# Rest is kept off early floors and off the floor right below the all-rest floor.
	if current.floor < REST_FROM or current.floor == REST_FLOOR - 1:
		banned.append(NodeType.REST)
	for parent_id in current.previous:
		var parent := nodes[parent_id]
		if parent.type in [NodeType.ELITE, NodeType.REST]:
			banned.append(parent.type)
		# Siblings already typed should differ, so a fork is a real choice.
		for sibling_id in parent.next:
			var sibling := nodes[sibling_id]
			if sibling != current and sibling.floor == current.floor and sibling.column < current.column:
				if sibling.type != NodeType.BATTLE:
					banned.append(sibling.type)
	var total := 0
	for type in TYPE_WEIGHTS:
		if type not in banned:
			total += TYPE_WEIGHTS[type]
	if total == 0:
		return NodeType.BATTLE
	var roll := rng.randi_range(1, total)
	for type in TYPE_WEIGHTS:
		if type in banned:
			continue
		roll -= TYPE_WEIGHTS[type]
		if roll <= 0:
			return type
	return NodeType.BATTLE


func to_dict() -> Dictionary:
	var rows: Array = []
	for current in nodes:
		rows.append({"id": current.id, "floor": current.floor, "column": current.column, "type": current.type, "next": current.next.duplicate()})
	return {"seed": seed_value, "boss": boss_id, "nodes": rows}


static func from_dict(data: Dictionary) -> RunMap:
	var map := RunMap.new()
	map.seed_value = int(data.seed)
	map.boss_id = int(data.boss)
	for row in data.nodes:
		var restored := MapNode.new(int(row.id), int(row.floor), int(row.column))
		restored.type = int(row.type) as NodeType
		map.nodes.append(restored)
	for row in data.nodes:
		for next_id in row.next:
			map.link(map.nodes[int(row.id)], map.nodes[int(next_id)])
	return map
