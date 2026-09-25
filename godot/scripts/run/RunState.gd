class_name RunState
extends RefCounted
## One journey: the map, where the party stands, and what persists between nodes.
## Battles still build fresh CharacterUnits; only HP carries over through here.

## The journey in progress, shared by every screen. Null on the main menu before a run.
static var active: RunState

const REST_HEAL_FRACTION := 0.4
const MAX_SKILL_LEVEL := 3
const DEFAULT_PARTY := ["res://data/classes/paladin.tres", "res://data/classes/rogue.tres", "res://data/classes/wizard.tres"]
## Classes a player can pick for each of the three places in the party.
const CLASSES := {
	"paladin": "res://data/classes/paladin.tres",
	"rogue": "res://data/classes/rogue.tres",
	"wizard": "res://data/classes/wizard.tres",
}

var seed_value: int = 0
var map: RunMap
var current_node_id: int = -1
var visited: Array[int] = []
var gold: int = 0
var party: Array[HeroState] = []
var finished: bool = false
var victory: bool = false
## False from arriving at a node until its screen is done, so a reload re-enters it.
var node_resolved: bool = true
var battles_won: int = 0
## Shield every hero starts the next battle with (event blessings); spent by that battle.
var ward: int = 0
## Item ids carried but not worn.
var stash: Array[String] = []


class HeroState:
	var definition: CharacterData
	var current_hp: int
	## slot name -> item id
	var equipment: Dictionary = {}
	## skill id -> level (1 when absent)
	var skill_levels: Dictionary = {}

	func _init(hero: CharacterData) -> void:
		definition = hero
		current_hp = hero.max_hp

	func bonus(stat: String) -> int:
		var total := 0
		for slot in equipment:
			total += int(Items.item(equipment[slot]).get("bonus", {}).get(stat, 0))
		return total

	func max_hp() -> int:
		return definition.max_hp + bonus("max_hp")

	func skill_level(skill: SkillData) -> int:
		return int(skill_levels.get(skill.id, 1))

	## Each level past 1 adds 1 damage or shield; level 3 also costs 1 MP less.
	func upgraded(skill: SkillData) -> SkillData:
		var level := skill_level(skill)
		if level <= 1:
			return skill
		var copy := skill.duplicate() as SkillData
		copy.flat_value += level - 1
		if level >= 3:
			copy.energy_cost = maxi(0, copy.energy_cost - 1)
		return copy

	## The hero as they fight today: base definition plus gear and skill levels.
	func battle_definition() -> CharacterData:
		var fighter := definition.duplicate() as CharacterData
		fighter.max_hp = max_hp()
		fighter.attack += bonus("attack")
		fighter.defense += bonus("defense")
		fighter.hit_bonus += bonus("hit_bonus")
		fighter.max_energy += bonus("max_energy")
		fighter.crit_threshold = clampi(definition.crit_threshold - bonus("crit"), 7, 12)
		var skills: Array[SkillData] = []
		for skill in definition.skills:
			skills.append(upgraded(skill))
		fighter.skills = skills
		fighter.gear = equipment.duplicate()
		return fighter

	func is_alive() -> bool:
		return current_hp > 0


static func begin(run_seed: int, heroes: Array[CharacterData]) -> RunState:
	var run := RunState.new()
	run.seed_value = run_seed
	run.map = RunMap.generate(run_seed)
	for hero in heroes:
		run.party.append(HeroState.new(hero))
	for id in Items.STARTING_STASH:
		run.stash.append(id)
	active = run
	return run


## A party picked on the setup screen: one class per place (repeats allowed) and a name
## each. Every hero gets its own copy of the class data carrying that name.
static func begin_party(run_seed: int, classes: Array, names: Array) -> RunState:
	var heroes: Array[CharacterData] = []
	for index in classes.size():
		var hero := (load(CLASSES[classes[index]]) as CharacterData).duplicate() as CharacterData
		hero.character_name = names[index]
		heroes.append(hero)
	return begin(run_seed, heroes)


static func begin_default(run_seed: int) -> RunState:
	var heroes: Array[CharacterData] = []
	for path in DEFAULT_PARTY:
		heroes.append(load(path))
	return begin(run_seed, heroes)


func current_node() -> RunMap.MapNode:
	return map.node(current_node_id)


func current_floor() -> int:
	return -1 if current_node_id < 0 else current_node().floor


func available_nodes() -> Array[RunMap.MapNode]:
	if finished:
		return []
	if not node_resolved:
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
	node_resolved = false
	return true


func resolve_current() -> void:
	node_resolved = true


func hero_definitions() -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	for hero in party:
		result.append(hero.battle_definition())
	return result


## Wears a stashed item; whatever filled that slot goes back to the stash.
func equip(hero_index: int, item_id: String) -> bool:
	if item_id not in stash or Items.item(item_id).is_empty():
		return false
	var hero := party[hero_index]
	var slot: String = Items.item(item_id).slot
	stash.erase(item_id)
	if hero.equipment.has(slot):
		unequip(hero_index, slot)
	var before := hero.max_hp()
	hero.equipment[slot] = item_id
	if hero.is_alive():
		hero.current_hp += hero.max_hp() - before
	return true


func unequip(hero_index: int, slot: String) -> bool:
	var hero := party[hero_index]
	if not hero.equipment.has(slot):
		return false
	stash.append(hero.equipment[slot])
	hero.equipment.erase(slot)
	if hero.is_alive():
		hero.current_hp = clampi(hero.current_hp, 1, hero.max_hp())
	return true


func upgrade_cost(hero_index: int, skill: SkillData) -> int:
	return 15 * party[hero_index].skill_level(skill)


func can_upgrade(hero_index: int, skill: SkillData) -> bool:
	return party[hero_index].skill_level(skill) < MAX_SKILL_LEVEL and gold >= upgrade_cost(hero_index, skill)


func upgrade_skill(hero_index: int, skill: SkillData) -> bool:
	if not can_upgrade(hero_index, skill):
		return false
	gold -= upgrade_cost(hero_index, skill)
	party[hero_index].skill_levels[skill.id] = party[hero_index].skill_level(skill) + 1
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
		return
	battles_won += 1
	resolve_current()
	if current_node() != null and current_node().type == RunMap.NodeType.BOSS:
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
