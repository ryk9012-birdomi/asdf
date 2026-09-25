class_name RunState
extends RefCounted
## One journey: the map, where the party stands, and what persists between nodes.
## Battles still build fresh CharacterUnits; only HP carries over through here.

## The journey in progress, shared by every screen. Null on the main menu before a run.
static var active: RunState

const REST_HEAL_FRACTION := 0.3

var seed_value: int = 0
var map: RunMap
var current_node_id: int = -1
var visited: Array[int] = []
var gold: int = 0
var party: Array[HeroState] = []
var finished: bool = false
var victory: bool = false


class HeroState:
	var definition: CharacterData
	var current_hp: int

	func _init(hero: CharacterData) -> void:
		definition = hero
		current_hp = hero.max_hp

	func max_hp() -> int:
		return definition.max_hp

	func is_alive() -> bool:
		return current_hp > 0


static func begin(run_seed: int, heroes: Array[CharacterData]) -> RunState:
	var run := RunState.new()
	run.seed_value = run_seed
	run.map = RunMap.generate(run_seed)
	for hero in heroes:
		run.party.append(HeroState.new(hero))
	active = run
	return run


func current_node() -> RunMap.MapNode:
	return map.node(current_node_id)


func current_floor() -> int:
	return -1 if current_node_id < 0 else current_node().floor


func available_nodes() -> Array[RunMap.MapNode]:
	if finished:
		return []
	if current_node_id < 0:
		return map.start_nodes()
	var result: Array[RunMap.MapNode] = []
	for next_id in current_node().next:
		result.append(map.node(next_id))
	return result


func can_travel(node_id: int) -> bool:
	return available_nodes().any(func(candidate: RunMap.MapNode): return candidate.id == node_id)


func travel(node_id: int) -> bool:
	if not can_travel(node_id):
		return false
	current_node_id = node_id
	visited.append(node_id)
	return true


## Same run seed and node always replay the same dice.
func encounter_seed(node_id: int) -> int:
	return absi(hash([seed_value, node_id]))


## Copies HP back from a finished battle. On victory, downed heroes get up with 1 HP.
func record_battle(units: Array[CharacterUnit], won: bool) -> void:
	for index in mini(units.size(), party.size()):
		party[index].current_hp = units[index].current_hp
		if won and not party[index].is_alive():
			party[index].current_hp = 1
	if not won:
		finish(false)
	elif current_node() != null and current_node().type == RunMap.NodeType.BOSS:
		finish(true)


func rest() -> int:
	var healed := 0
	for hero in party:
		if not hero.is_alive():
			continue
		var amount := mini(ceili(hero.max_hp() * REST_HEAL_FRACTION), hero.max_hp() - hero.current_hp)
		hero.current_hp += amount
		healed += amount
	return healed


func finish(won: bool) -> void:
	finished = true
	victory = won


func party_alive() -> bool:
	return party.any(func(hero: HeroState): return hero.is_alive())
