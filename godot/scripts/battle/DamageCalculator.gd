class_name DamageCalculator
extends RefCounted
## 2d6 attack roll: natural total + attacker hit bonus − defender defence.
## RNG is injected so the same battle seed reproduces every roll.

enum Outcome { MISS, GLANCE, HIT, CRITICAL }

const GLANCE_AT := 7
const HIT_AT := 10
const OUTCOME_NAMES := ["빗나감", "스침", "명중", "치명타"]


static func modifier(attacker: CharacterUnit, defender: CharacterUnit, skill: SkillData) -> int:
	var defence := 0 if skill.damage_type == SkillData.DamageType.TRUE_DAMAGE else defender.defense
	return attacker.hit_bonus - defence


static func classify(first: int, second: int, attacker: CharacterUnit, defender: CharacterUnit, skill: SkillData) -> Outcome:
	if skill.auto_hit:
		return Outcome.HIT
	if first + second >= attacker.crit_threshold:
		return Outcome.CRITICAL
	var total := first + second + modifier(attacker, defender, skill)
	if total >= HIT_AT:
		return Outcome.HIT
	if total >= GLANCE_AT:
		return Outcome.GLANCE
	return Outcome.MISS


static func base_damage(attacker: CharacterUnit, skill: SkillData) -> int:
	return roundi(attacker.attack * skill.attack_multiplier) + skill.flat_value


static func damage_for(outcome: Outcome, base: int) -> int:
	match outcome:
		Outcome.GLANCE:
			return ceili(base / 2.0)
		Outcome.HIT:
			return base
		Outcome.CRITICAL:
			return base * 2
	return 0


static func roll(attacker: CharacterUnit, defender: CharacterUnit, skill: SkillData, rng: RandomNumberGenerator) -> Dictionary:
	var dice: Array[int] = []
	if not skill.auto_hit:
		dice = [rng.randi_range(1, 6), rng.randi_range(1, 6)]
	var outcome := Outcome.HIT
	var natural := 0
	if not dice.is_empty():
		outcome = classify(dice[0], dice[1], attacker, defender, skill)
		natural = dice[0] + dice[1]
	var bonus := modifier(attacker, defender, skill)
	return {
		"dice": dice,
		"natural": natural,
		"modifier": bonus,
		"total": natural + bonus,
		"outcome": outcome,
		"damage": damage_for(outcome, base_damage(attacker, skill)),
		"miss": outcome == Outcome.MISS,
		"critical": outcome == Outcome.CRITICAL,
		"auto": skill.auto_hit,
	}


## Exact chances over all 36 two-dice outcomes, for display.
static func odds(attacker: CharacterUnit, defender: CharacterUnit, skill: SkillData) -> Dictionary:
	var counts := [0, 0, 0, 0]
	if skill.auto_hit:
		counts[Outcome.HIT] = 36
	else:
		for first in range(1, 7):
			for second in range(1, 7):
				counts[classify(first, second, attacker, defender, skill)] += 1
	return {
		"miss": counts[Outcome.MISS] / 36.0,
		"glance": counts[Outcome.GLANCE] / 36.0,
		"hit": counts[Outcome.HIT] / 36.0,
		"critical": counts[Outcome.CRITICAL] / 36.0,
		"land": 1.0 - counts[Outcome.MISS] / 36.0,
	}


static func describe(roll_result: Dictionary) -> String:
	if roll_result.auto:
		return "자동 명중"
	return "2d6 [%d+%d] %+d = %d → %s" % [roll_result.dice[0], roll_result.dice[1], roll_result.modifier, roll_result.total, OUTCOME_NAMES[roll_result.outcome]]
