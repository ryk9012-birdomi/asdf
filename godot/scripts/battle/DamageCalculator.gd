class_name DamageCalculator
extends RefCounted
## RNG is injected so the same battle seed can reproduce all rolls.

static func roll(attacker: CharacterUnit, defender: CharacterUnit, skill: SkillData, rng: RandomNumberGenerator) -> Dictionary:
	var hit_chance := clampf(attacker.accuracy - defender.evasion, 0.0, 1.0)
	var hit_roll := rng.randf()
	# Presentation only: the same roll bucketed onto a d20, where higher reads as better.
	var d20 := clampi(20 - int(hit_roll * 20.0), 1, 20)
	if hit_roll >= hit_chance:
		return {"damage": 0, "miss": true, "critical": false, "d20": d20}
	var critical := rng.randf() < attacker.critical_chance
	var base := (attacker.attack * skill.attack_multiplier + skill.flat_value) * (1.5 if critical else 1.0)
	var armor := 0 if skill.damage_type == SkillData.DamageType.TRUE_DAMAGE else defender.defense
	var damage := maxi(1, roundi(base) - armor) if base > 0.0 else 0
	return {"damage": damage, "miss": false, "critical": critical, "d20": d20}
