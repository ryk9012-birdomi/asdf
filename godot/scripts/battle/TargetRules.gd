class_name TargetRules
extends RefCounted

static func living(units: Array[CharacterUnit]) -> Array[CharacterUnit]:
	var result: Array[CharacterUnit] = []
	for unit in units:
		if unit.is_alive():
			result.append(unit)
	return result


static func legal_targets(actor: CharacterUnit, skill: SkillData, allies: Array[CharacterUnit], opponents: Array[CharacterUnit]) -> Array[CharacterUnit]:
	var friends := living(allies)
	var foes := living(opponents)
	match skill.target_type:
		SkillData.TargetType.SELF:
			var self_target: Array[CharacterUnit] = []
			if actor.is_alive():
				self_target.append(actor)
			return self_target
		SkillData.TargetType.ALLY, SkillData.TargetType.ALL_ALLIES:
			return friends
		SkillData.TargetType.FRONT_ENEMY, SkillData.TargetType.BACK_ENEMY:
			if foes.is_empty():
				return foes
			var rank: int = foes[0].formation_slot
			for foe in foes:
				if skill.target_type == SkillData.TargetType.FRONT_ENEMY:
					rank = mini(rank, foe.formation_slot)
				else:
					rank = maxi(rank, foe.formation_slot)
			var line: Array[CharacterUnit] = []
			for foe in foes:
				if foe.formation_slot == rank:
					line.append(foe)
			return line
	return foes
