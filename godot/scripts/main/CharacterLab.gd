extends Control
## A disposable manual test harness, not a BattleManager.

@onready var party: HBoxContainer = %Party
@onready var event_log: RichTextLabel = %EventLog
var messages: PackedStringArray = []


func _ready() -> void:
	var backdrop := EmberBackdrop.new()
	add_child(backdrop)
	move_child(backdrop, 0)
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Batang", "Noto Serif CJK KR", "Noto Serif KR", "Nanum Myeongjo", "serif"])
	serif.font_weight = 600
	$Scroll/Margin/Content/Header/Title.add_theme_font_override("font", serif)
	$Scroll/Margin/Content/Header/Title.add_theme_color_override("font_color", Color("f4e2b8"))
	for card in party.get_children():
		card.action_requested.connect(on_action_requested)
		card.unit.unit_died.connect(on_unit_died)
	%ResetButton.pressed.connect(reset_party)
	%BattleButton.pressed.connect(func(): SceneRouter.go(get_tree(), SceneRouter.BATTLE))
	var menu_button := Button.new()
	menu_button.name = "MenuButton"
	menu_button.text = "메인 메뉴"
	menu_button.pressed.connect(func(): SceneRouter.go(get_tree(), SceneRouter.MAIN_MENU))
	%BattleButton.get_parent().add_child(menu_button)
	%BattleButton.get_parent().move_child(menu_button, %ResetButton.get_index())
	log_message("모닥불 곁에 일행이 모였습니다. 각 모험가의 상태 시험 버튼을 눌러 보세요.")


func on_action_requested(unit: CharacterUnit, action: StringName) -> void:
	var result := ""
	match action:
		&"damage":
			var previous_shield := unit.current_shield
			var hp_damage := unit.receive_damage(3)
			result = "피해 3 → 보호막 흡수 %d / HP 감소 %d" % [previous_shield - unit.current_shield, hp_damage]
		&"heal":
			result = "HP %d 회복" % unit.heal(2)
		&"shield":
			result = "보호막 %d 획득" % unit.add_shield(2)
		&"spend":
			result = "MP 2 사용" if unit.spend_energy(2) else "MP 부족: 상태 변화 없음"
		&"restore":
			result = "MP %d 회복" % unit.restore_energy(2)
		&"lethal":
			unit.receive_damage(unit.current_hp + unit.current_shield)
			result = "치명상 테스트 완료"
	log_message("%s · %s" % [unit.character_data.character_name, result])


func on_unit_died(unit: CharacterUnit) -> void:
	log_message("%s 쓰러짐. unit_died Signal 수신." % unit.character_data.character_name)


func reset_party() -> void:
	for card in party.get_children():
		card.unit.reset_to_starting_state()
	log_message("긴 휴식 · HP, 보호막, MP를 원본 Resource의 시작 값으로 복구했습니다.")


func log_message(message: String) -> void:
	messages.append(message)
	while messages.size() > 4:
		messages.remove_at(0)
	event_log.text = "\n".join(messages)
