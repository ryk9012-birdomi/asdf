class_name BattleManager
extends Node
## Synchronous combat rules; the scene controller owns animation/AI pacing.

signal changed
signal message_logged(message: String)
signal action_resolved(actor: CharacterUnit, targets: Array[CharacterUnit], skill: SkillData)
signal battle_finished(victory: bool)
signal hit_resolved(target: CharacterUnit, health_damage: int, shield_damage: int, critical: bool)
signal hit_missed(target: CharacterUnit)
signal shield_granted(target: CharacterUnit, amount: int)

enum Phase { IDLE, PLAYER_INPUT, ENEMY_TURN, RESOLVING, FINISHED }

@onready var turns: TurnManager = $TurnManager
var party: Array[CharacterUnit] = []
var enemies: Array[CharacterUnit] = []
var actor: CharacterUnit
var phase: Phase = Phase.IDLE
var victory: bool = false
var rng := RandomNumberGenerator.new()


func start_battle(players: Array[CharacterUnit], foes: Array[CharacterUnit], battle_seed: int = -1) -> bool:
	if players.is_empty() or players.size() > 3 or foes.is_empty() or foes.size() > 5:
		return false
	var all_units: Array[CharacterUnit] = []
	for unit in players + foes:
		if unit == null or not unit.is_alive() or unit in all_units:
			return false
		all_units.append(unit)
	for foe in foes:
		if not foe is EnemyUnit:
			return false
	party.assign(players)
	enemies.assign(foes)
	if battle_seed < 0:
		rng.randomize()
	else:
		rng.seed = battle_seed
	victory = false
	actor = null
	turns.reset(all_units)
	phase = Phase.RESOLVING
	message_logged.emit("주도권 굴림! 고블린 약탈자들이 고갯길을 막아섰습니다.")
	advance_turn()
	return true


func advance_turn() -> void:
	if phase != Phase.RESOLVING or check_outcome():
		return
	actor = turns.next_unit()
	if actor == null:
		return
	phase = Phase.PLAYER_INPUT if actor in party else Phase.ENEMY_TURN
	changed.emit()


func available_targets(skill: SkillData) -> Array[CharacterUnit]:
	if actor == null or skill == null:
		return []
	var allies := party if actor in party else enemies
	var opponents := enemies if actor in party else party
	return TargetRules.legal_targets(actor, skill, allies, opponents)


func skill_block_reason(skill: SkillData) -> String:
	if actor == null or not actor.is_alive():
		return "행동할 수 없음"
	if skill == null or skill not in actor.character_data.skills:
		return "보유하지 않은 스킬"
	if actor.remaining_cooldown(skill) > 0:
		return "재사용 대기 %d턴" % actor.remaining_cooldown(skill)
	if not actor.can_spend_energy(skill.energy_cost):
		return "기력 부족"
	if available_targets(skill).is_empty():
		return "유효한 대상 없음"
	return ""


func player_action(skill: SkillData, target: CharacterUnit) -> bool:
	if phase != Phase.PLAYER_INPUT:
		return false
	return perform_action(skill, target)


func enemy_action() -> void:
	if phase != Phase.ENEMY_TURN:
		return
	var enemy := actor as EnemyUnit
	var skill := enemy.intended_skill()
	if skill != null:
		var targets := available_targets(skill)
		if not targets.is_empty() and perform_action(skill, targets[0]):
			return
	pass_action()


func player_pass() -> bool:
	if phase != Phase.PLAYER_INPUT:
		return false
	pass_action()
	return true


func pass_action() -> void:
	phase = Phase.RESOLVING
	message_logged.emit("%s · 대기" % actor.display_name)
	finish_action()


func perform_action(skill: SkillData, target: CharacterUnit) -> bool:
	if phase not in [Phase.PLAYER_INPUT, Phase.ENEMY_TURN] or not skill_block_reason(skill).is_empty():
		return false
	var legal := available_targets(skill)
	if target not in legal:
		return false
	var targets: Array[CharacterUnit] = [target]
	if skill.target_type in [SkillData.TargetType.ALL_ALLIES, SkillData.TargetType.ALL_ENEMIES]:
		targets = legal
	elif skill.target_type == SkillData.TargetType.RANDOM_ENEMY:
		targets = [legal[rng.randi_range(0, legal.size() - 1)]]
	phase = Phase.RESOLVING
	actor.spend_energy(skill.energy_cost)
	if skill.cooldown > 0:
		actor.cooldowns[skill.id] = skill.cooldown + 1
	message_logged.emit("%s → %s" % [actor.display_name, skill.skill_name])
	for recipient in targets:
		for hit in skill.hit_count:
			if not recipient.is_alive():
				break
			if skill.effect_type == SkillData.EffectType.SHIELD:
				var amount := roundi(actor.attack * skill.attack_multiplier) + skill.flat_value
				var gained := recipient.add_shield(amount)
				shield_granted.emit(recipient, gained)
				message_logged.emit("  %s · 보호막 +%d" % [recipient.display_name, gained])
			else:
				apply_hit(recipient, skill)
	action_resolved.emit(actor, targets, skill)
	finish_action()
	return true


func apply_hit(recipient: CharacterUnit, skill: SkillData) -> void:
	var roll := DamageCalculator.roll(actor, recipient, skill, rng)
	if roll.miss:
		hit_missed.emit(recipient)
		message_logged.emit("  %s · 빗나감 (d20 %d)" % [recipient.display_name, roll.d20])
		return
	var old_shield := recipient.current_shield
	var hp_damage := recipient.receive_damage(roll.damage)
	hit_resolved.emit(recipient, hp_damage, old_shield - recipient.current_shield, roll.critical)
	message_logged.emit("  %s · HP −%d / 보호막 −%d%s  (d20 %d)" % [recipient.display_name, hp_damage, old_shield - recipient.current_shield, " / 치명타" if roll.critical else "", roll.d20])
	if not recipient.is_alive():
		message_logged.emit("  %s · 쓰러짐" % recipient.display_name)


func finish_action() -> void:
	if actor is EnemyUnit:
		(actor as EnemyUnit).pattern_cursor += 1
	turns.finish_turn()
	if not check_outcome():
		changed.emit()


func check_outcome() -> bool:
	if phase == Phase.FINISHED:
		return true
	if TargetRules.living(party).is_empty() or TargetRules.living(enemies).is_empty():
		victory = not TargetRules.living(party).is_empty()
		phase = Phase.FINISHED
		message_logged.emit("승리 · 고갯길을 되찾았습니다" if victory else "패배 · 일행이 모두 쓰러졌습니다")
		battle_finished.emit(victory)
		changed.emit()
		return true
	return false
