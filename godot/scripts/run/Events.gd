class_name Events
extends RefCounted
## Story events on the map. Each choice may call for a 2d6 check by one hero
## (2d6 + that hero's hit bonus ≥ target) and applies simple effects to the run:
##   gold: ±n   heal: n to every living hero   hurt: [hero index or -1 for all, n]
##   ward: n shield for every hero at the start of the next battle   cost: gold to pay
## Events never kill: hurt stops at 1 HP.

const PALADIN := 0
const ROGUE := 1
const WIZARD := 2
const ALL := -1

## The opening floor: the party sets out from the last village below the pass.
const OPENING := [
	{
		"id": "dawn_blessing",
		"title": "출정의 새벽",
		"text": "고갯길 아래 마지막 마을. 새벽 종이 울리자 늙은 사제가 신전 계단에서 일행을 불러 세운다. \"잿불 교단의 땅으로 가는가. 빈손으로 보낼 수는 없지.\"",
		"choices": [
			{"label": "사제의 축복을 받는다", "effects": {"ward": 2}, "text": "따뜻한 빛이 갑옷 틈으로 스며든다. 다음 전투에서 모두가 보호막 2를 두르고 시작한다."},
			{"label": "신전 창고의 보급품을 챙긴다", "effects": {"gold": 15, "heal": 1}, "text": "말린 약초와 동전 주머니를 받았다. 골드 +15, 모두 HP +1."},
		],
	},
	{
		"id": "broken_cart",
		"title": "고갯길 입구의 상인",
		"text": "비탈길 초입, 바퀴가 부러진 수레 아래에 상인이 깔려 신음한다. 수레를 들어 올리려면 누군가 힘을 써야 한다.",
		"choices": [
			{"label": "알데릭이 수레를 들어 올린다", "check": {"hero": PALADIN, "target": 8},
				"success": {"effects": {"gold": 25}, "text": "알데릭이 이를 악물고 수레를 들어 올렸다. 상인이 사례금을 쥐여 준다. 골드 +25."},
				"failure": {"effects": {"hurt": [PALADIN, 2]}, "text": "수레가 미끄러지며 알데릭의 어깨를 짓눌렀다. 상인은 겨우 빠져나왔지만 알데릭 HP −2."}},
			{"label": "시엔이 지렛대를 찾아 머리를 쓴다", "check": {"hero": ROGUE, "target": 9},
				"success": {"effects": {"gold": 20, "ward": 1}, "text": "부러진 창대 하나로 수레가 들렸다. 상인이 고갯길의 매복 지점을 귀띔해 준다. 골드 +20, 다음 전투 보호막 +1."},
				"failure": {"effects": {"hurt": [ROGUE, 1]}, "text": "창대가 부러지며 시엔의 손을 긁었다. 결국 모두 힘으로 들어 올렸다. 시엔 HP −1."}},
			{"label": "갈 길이 바쁘다. 지나친다", "effects": {}, "text": "뒤에서 상인의 욕설이 들려왔다."},
		],
	},
	{
		"id": "cult_mark",
		"title": "불길한 표식",
		"text": "길가 바위에 붉은 잿불로 새긴 교단의 표식이 아직 따뜻하다. 무언가를 부르는 주문 같다.",
		"choices": [
			{"label": "엘로웬이 표식을 해독한다", "check": {"hero": WIZARD, "target": 9},
				"success": {"effects": {"ward": 3, "gold": 10}, "text": "표식을 거꾸로 읽어 보호의 문장으로 바꾸었다. 표식 아래 숨겨진 헌금함도 찾았다. 다음 전투 보호막 +3, 골드 +10."},
				"failure": {"effects": {"hurt": [WIZARD, 2]}, "text": "표식이 불꽃을 토해 엘로웬의 소매를 태웠다. 엘로웬 HP −2."}},
			{"label": "알데릭이 표식을 부순다", "effects": {"ward": 1}, "text": "철퇴가 바위를 가르자 잿불이 꺼졌다. 다음 전투 보호막 +1."},
		],
	},
]

## Events deeper in the pass.
const JOURNEY := [
	{
		"id": "abandoned_camp",
		"title": "버려진 야영지",
		"text": "아직 식지 않은 모닥불 자리. 교단 척후병들이 급히 떠난 흔적이다. 풀숲에 약초가, 천막 아래에 짐 꾸러미가 보인다.",
		"choices": [
			{"label": "약초를 달여 상처를 돌본다", "effects": {"heal": 2}, "text": "쓴 약초 차가 몸을 데운다. 모두 HP +2."},
			{"label": "시엔이 짐 꾸러미를 뒤진다", "check": {"hero": ROGUE, "target": 8},
				"success": {"effects": {"gold": 30}, "text": "덫을 피해 꾸러미를 열었다. 교단의 군자금이다. 골드 +30."},
				"failure": {"effects": {"hurt": [ROGUE, 2], "gold": 5}, "text": "숨겨진 바늘 덫에 찔렸다. 동전 몇 닢만 건졌다. 시엔 HP −2, 골드 +5."}},
		],
	},
	{
		"id": "goblin_gambler",
		"title": "주사위 치는 고블린",
		"text": "바위 위에 걸터앉은 늙은 고블린이 뼈 주사위를 흔든다. \"금화 열 닢. 여덟 이상이면 세 배로 돌려주지. 아니면 내 거고.\"",
		"choices": [
			{"label": "금화 10을 건다 (주사위 2개 합이 8 이상)", "cost": 10, "check": {"hero": ALL, "target": 8},
				"success": {"effects": {"gold": 30}, "text": "고블린이 이를 갈며 금화를 내어 준다. 골드 +30."},
				"failure": {"effects": {}, "text": "고블린이 낄낄대며 금화를 쓸어 담았다."}},
			{"label": "고블린을 쫓아낸다", "effects": {"ward": 1}, "text": "고블린이 달아나며 떨어뜨린 부적을 주웠다. 다음 전투 보호막 +1."},
		],
	},
	{
		"id": "ruined_altar",
		"title": "무너진 제단",
		"text": "교단이 더럽히기 전의 옛 순례자 제단이다. 금 간 성상 아래에 붉은 보석이 박혀 있다.",
		"choices": [
			{"label": "알데릭이 무릎 꿇고 기도한다", "effects": {"heal": 3}, "text": "희미한 빛이 일행을 감싼다. 모두 HP +3."},
			{"label": "보석을 뜯어낸다", "effects": {"gold": 35, "hurt": [ALL, 1]}, "text": "보석을 떼어 내자 제단이 신음하듯 무너진다. 골드 +35, 모두 HP −1."},
		],
	},
	{
		"id": "wounded_scout",
		"title": "쓰러진 정찰병",
		"text": "왕국군 정찰병이 화살을 맞고 쓰러져 있다. 숨은 붙어 있지만 오래 버티지 못할 것 같다.",
		"choices": [
			{"label": "엘로웬이 치유 주문을 시도한다", "check": {"hero": WIZARD, "target": 8},
				"success": {"effects": {"gold": 15, "ward": 2}, "text": "정찰병이 눈을 떴다. 감사의 표시로 봉급과 교단 진지 위치를 알려 준다. 골드 +15, 다음 전투 보호막 +2."},
				"failure": {"effects": {"hurt": [WIZARD, 1]}, "text": "주문이 흩어지며 엘로웬이 비틀거렸다. 정찰병은 끝내 숨을 거두었다. 엘로웬 HP −1."}},
			{"label": "명복을 빌고 지나간다", "effects": {}, "text": "일행은 정찰병의 망토를 덮어 주고 발걸음을 옮겼다."},
		],
	},
]


static func for_node(run: RunState, map_node: RunMap.MapNode) -> Dictionary:
	var pool: Array = OPENING if map_node.floor == 0 else JOURNEY
	return pool[run.encounter_seed(map_node.id) % pool.size()]


static func bonus(run: RunState, check: Dictionary) -> int:
	var hero: int = check.hero
	return 0 if hero == ALL else run.party[hero].definition.hit_bonus


static func chance(run: RunState, check: Dictionary) -> float:
	var need: int = check.target - bonus(run, check)
	var wins := 0
	for first in range(1, 7):
		for second in range(1, 7):
			if first + second >= need:
				wins += 1
	return wins / 36.0


static func affordable(run: RunState, choice: Dictionary) -> bool:
	return run.gold >= int(choice.get("cost", 0))


## Resolves one choice with the node's own dice, applies it and returns what happened.
static func resolve(run: RunState, map_node: RunMap.MapNode, choice: Dictionary) -> Dictionary:
	run.gold -= int(choice.get("cost", 0))
	var outcome := {"effects": choice.get("effects", {}), "text": choice.get("text", "")}
	var roll := {}
	if choice.has("check"):
		var rng := RandomNumberGenerator.new()
		rng.seed = run.encounter_seed(map_node.id) + 17 * (hash(choice.label) % 1000)
		var dice := [rng.randi_range(1, 6), rng.randi_range(1, 6)]
		var check: Dictionary = choice.check
		var total: int = dice[0] + dice[1] + bonus(run, check)
		var passed: bool = total >= check.target
		roll = {"dice": dice, "bonus": bonus(run, check), "total": total, "target": check.target, "passed": passed}
		outcome = choice.success if passed else choice.failure
	apply(run, outcome.effects)
	return {"text": outcome.text, "roll": roll, "effects": outcome.effects}


static func apply(run: RunState, effects: Dictionary) -> void:
	run.gold = maxi(0, run.gold + int(effects.get("gold", 0)))
	var heal := int(effects.get("heal", 0))
	for hero in run.party:
		if hero.is_alive() and heal > 0:
			hero.current_hp = mini(hero.max_hp(), hero.current_hp + heal)
	if effects.has("hurt"):
		var who: int = effects.hurt[0]
		for index in run.party.size():
			if who == ALL or who == index:
				var hero := run.party[index]
				hero.current_hp = maxi(mini(1, hero.current_hp), hero.current_hp - int(effects.hurt[1]))
	run.ward += int(effects.get("ward", 0))


static func describe_check(run: RunState, choice: Dictionary) -> String:
	if not choice.has("check"):
		return ""
	var check: Dictionary = choice.check
	var who := "주사위" if check.hero == ALL else run.party[check.hero].definition.character_name
	var mod := bonus(run, check)
	return "%s 판정: 2d6%s ≥ %d  ·  성공 %d%%" % [who, (" %+d" % mod) if mod != 0 else "", check.target, roundi(chance(run, check) * 100.0)]
