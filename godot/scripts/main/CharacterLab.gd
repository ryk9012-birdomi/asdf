extends Control
## A disposable manual test harness, not a BattleManager.

@onready var party: HBoxContainer = %Party
@onready var event_log: RichTextLabel = %EventLog
var messages: PackedStringArray = []


func _ready() -> void:
	for card in party.get_children():
		card.action_requested.connect(on_action_requested)
		card.unit.unit_died.connect(on_unit_died)
	%ResetButton.pressed.connect(reset_party)
	%BattleButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/battle/BattleScene.tscn"))
	log_message("잔광 인양단 연결 완료. 각 대원의 상태 테스트 버튼을 눌러 보세요.")


func on_action_requested(unit: CharacterUnit, action: StringName) -> void:
	var result := ""
	match action:
		&"damage":
			var previous_shield := unit.current_shield
			var hp_damage := unit.receive_damage(30)
			result = "피해 30 → 실드 흡수 %d / HP 감소 %d" % [previous_shield - unit.current_shield, hp_damage]
		&"heal":
			result = "HP %d 회복" % unit.heal(25)
		&"shield":
			result = "실드 %d 획득" % unit.add_shield(20)
		&"spend":
			result = "에너지 2 사용" if unit.spend_energy(2) else "에너지 부족: 상태 변화 없음"
		&"restore":
			result = "에너지 %d 충전" % unit.restore_energy(2)
		&"lethal":
			unit.receive_damage(unit.current_hp + unit.current_shield)
			result = "치명상 테스트 완료"
	log_message("%s · %s" % [unit.character_data.character_name, result])


func on_unit_died(unit: CharacterUnit) -> void:
	log_message("%s 전투 불능. unit_died Signal 수신." % unit.character_data.character_name)


func reset_party() -> void:
	for card in party.get_children():
		card.unit.reset_to_starting_state()
	log_message("파티 초기화 · HP, 실드, 에너지를 원본 Resource의 시작 값으로 복구했습니다.")


func log_message(message: String) -> void:
	messages.append(message)
	while messages.size() > 4:
		messages.remove_at(0)
	event_log.text = "\n".join(messages)
