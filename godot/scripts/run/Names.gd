class_name Names
extends RefCounted
## Random hero names built from syllables, flavoured by class: knights sound stern,
## rogues short and quick, wizards long and airy.

const SYLLABLES := {
	"paladin": [["알", "베", "가", "로", "하", "세", "레", "오", "카", "도", "브", "마", "그", "발"],
		["데", "르", "란", "스", "윈", "로", "라", "", ""],
		["릭", "드", "온", "린", "트", "벨", "란", "크", "문", "하트"]],
	"rogue": [["시", "카", "레", "니", "잭", "라", "벡", "미", "티", "엘", "주", "렌"],
		["엔", "리", "스", "오", "", "", ""],
		["엔", "스", "아", "린", "크", "라", "키", "로", "즈"]],
	"wizard": [["엘", "아", "세", "이", "오", "루", "미", "페", "실", "나", "에"],
		["로", "리", "벨", "나", "레", "스", "라"],
		["웬", "엘", "스", "라", "온", "린", "네", "니아", "디스"]],
}


## A new name for that class, different from every name in `taken`.
static func random(role: String, rng: RandomNumberGenerator, taken: Array = []) -> String:
	var parts: Array = SYLLABLES.get(role, SYLLABLES.paladin)
	for _attempt in 50:
		var name := ""
		for pool in parts:
			name += pool[rng.randi_range(0, pool.size() - 1)]
		if name.length() >= 2 and name not in taken and not stutters(name):
			return name
	return "나그네"


## Rejects names that repeat the same syllable back to back ("엘엘").
static func stutters(name: String) -> bool:
	for index in range(1, name.length()):
		if name[index] == name[index - 1]:
			return true
	return false
