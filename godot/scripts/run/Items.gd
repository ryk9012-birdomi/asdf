class_name Items
extends RefCounted
## Equipment a hero can wear in one of three slots. Bonuses add to the hero's base stats
## for every battle; "crit" lowers the critical threshold (11 instead of 12 per point).

const SLOTS := ["weapon", "armor", "trinket"]
const SLOT_NAMES := {"weapon": "무기", "armor": "방어구", "trinket": "장신구"}
const STAT_NAMES := {"attack": "공격", "defense": "방어", "hit_bonus": "명중", "max_hp": "최대 HP", "max_energy": "최대 MP", "crit": "치명 기준"}
const STARTING_STASH := ["leather_vest", "lucky_coin"]

const ALL := {
	"honed_sword": {"name": "벼린 장검", "slot": "weapon", "bonus": {"attack": 1}, "flavor": "순례자 초소에서 주운, 날이 잘 선 장검."},
	"keen_dagger": {"name": "예리한 단검", "slot": "weapon", "bonus": {"attack": 1, "crit": 1}, "flavor": "빛을 거의 반사하지 않는 검은 칼날."},
	"oak_staff": {"name": "떡갈나무 지팡이", "slot": "weapon", "bonus": {"hit_bonus": 1, "max_energy": 1}, "flavor": "옛 드루이드의 문양이 새겨진 지팡이."},
	"leather_vest": {"name": "낡은 가죽 조끼", "slot": "armor", "bonus": {"defense": 1}, "flavor": "여기저기 기웠지만 아직 쓸 만하다."},
	"chain_shirt": {"name": "사슬 셔츠", "slot": "armor", "bonus": {"defense": 1, "max_hp": 2}, "flavor": "왕국군 보급품. 무겁지만 든든하다."},
	"warding_cloak": {"name": "수호의 망토", "slot": "armor", "bonus": {"max_hp": 3}, "flavor": "안감에 보호의 룬이 수놓여 있다."},
	"lucky_coin": {"name": "행운의 동전", "slot": "trinket", "bonus": {"crit": 1}, "flavor": "앞뒤가 모두 앞면인 동전."},
	"eagle_feather": {"name": "독수리 깃털", "slot": "trinket", "bonus": {"hit_bonus": 1}, "flavor": "고갯길 독수리의 깃. 시야가 맑아진다."},
	"mana_pendant": {"name": "마나 펜던트", "slot": "trinket", "bonus": {"max_energy": 1}, "flavor": "푸른 빛이 맥박처럼 깜빡인다."},
}


static func item(id: String) -> Dictionary:
	return ALL.get(id, {})


static func describe(id: String) -> String:
	var parts := PackedStringArray()
	var bonus: Dictionary = item(id).get("bonus", {})
	for stat in bonus:
		var amount: int = bonus[stat]
		parts.append("%s −%d" % [STAT_NAMES[stat], amount] if stat == "crit" else "%s %+d" % [STAT_NAMES[stat], amount])
	return " · ".join(parts)


static func random_id(rng: RandomNumberGenerator) -> String:
	var ids := ALL.keys()
	return ids[rng.randi_range(0, ids.size() - 1)]
