extends PanelContainer
## Presentation only. Lab controls emit requests; they never calculate combat results.

signal action_requested(unit: CharacterUnit, action: StringName)

@export var character_data: CharacterData
@export var formation_slot: CharacterUnit.FormationSlot = CharacterUnit.FormationSlot.FRONT

@onready var unit: CharacterUnit = $CharacterUnit
@onready var content: VBoxContainer = $Margin/Content

var health_bar: ProgressBar
var energy_bar: ProgressBar
var health_label: Label
var resource_label: Label
var state_label: Label
var portrait: ColorRect
var action_buttons: Array[Button] = []


func _ready() -> void:
	if character_data == null or not character_data.get_validation_errors().is_empty():
		add_label("CharacterData를 확인하세요.", 18)
		return
	unit.formation_slot = formation_slot
	var accent := character_data.display_color
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("1c140e")
	frame.border_color = Color("6e5431")
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", frame)
	add_label(["01   ·   전열", "02   ·   중열", "03   ·   후열"][formation_slot], 13, accent)
	portrait = ColorRect.new()
	portrait.custom_minimum_size.y = 52
	portrait.color = accent.darkened(0.70)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(portrait)
	var emblem := Label.new()
	emblem.text = "◆  %s  ◆" % character_data.class_name_label.to_upper()
	emblem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emblem.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emblem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	emblem.add_theme_color_override("font_color", accent)
	portrait.add_child(emblem)
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Batang", "Noto Serif CJK KR", "Noto Serif KR", "Nanum Myeongjo", "serif"])
	serif.font_weight = 600
	add_label(character_data.character_name, 26).add_theme_font_override("font", serif)
	add_label(character_data.class_name_label, 15, accent)
	var description := add_label(character_data.description, 13, Color("b8a88a"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.y = 40
	add_label("ATK %d   /   DEF %d   /   SPD %d" % [character_data.attack, character_data.defense, character_data.speed], 14)
	add_label("명중 %d%%   회피 %d%%   치명 %d%%" % [roundi(character_data.accuracy * 100), roundi(character_data.evasion * 100), roundi(character_data.critical_chance * 100)], 12, Color("b8a88a"))
	health_label = add_label("", 14)
	health_bar = add_bar(accent, 10)
	resource_label = add_label("", 13, Color("d6c7a8"))
	energy_bar = add_bar(Color("f0b44c"), 5)
	state_label = add_label("", 12, accent)
	content.add_child(HSeparator.new())
	add_label("주문과 기술", 12, Color("b8a88a"))
	for skill in character_data.skills:
		var entry := add_label("%s   ·   기력 %d / 대기 %d" % [skill.skill_name, skill.energy_cost, skill.cooldown], 14)
		entry.tooltip_text = "%s\n대상: %s\n피해 유형: %s" % [skill.description, SkillData.TargetType.keys()[skill.target_type], SkillData.DamageType.keys()[skill.damage_type]]
	content.add_child(HSeparator.new())
	add_label("상태 시험", 12, Color("b8a88a"))
	var actions := GridContainer.new()
	actions.columns = 2
	content.add_child(actions)
	var labels := ["피해 30", "치유 25", "보호막 +20", "기력 −2", "기력 +2", "치명상"]
	var ids: Array[StringName] = [&"damage", &"heal", &"shield", &"spend", &"restore", &"lethal"]
	for index in ids.size():
		var button := Button.new()
		button.name = String(ids[index])
		button.text = labels[index]
		button.custom_minimum_size.y = 32
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func(): action_requested.emit(unit, ids[index]))
		actions.add_child(button)
		action_buttons.append(button)
	unit.initialized.connect(refresh)
	unit.health_changed.connect(func(_current: int, _maximum: int): refresh())
	unit.shield_changed.connect(func(_current: int): refresh())
	unit.energy_changed.connect(func(_current: int, _maximum: int): refresh())
	unit.initialize(character_data)


func refresh() -> void:
	health_label.text = "HP   %d / %d" % [unit.current_hp, unit.max_hp]
	health_bar.max_value = unit.max_hp
	health_bar.value = unit.current_hp
	resource_label.text = "보호막 %d     ·     기력 %d / %d" % [unit.current_shield, unit.current_energy, unit.max_energy]
	energy_bar.max_value = maxi(1, unit.max_energy)
	energy_bar.value = unit.current_energy
	state_label.text = "●  모험 가능" if unit.is_alive() else "×  쓰러짐 · 긴 휴식으로 복구"
	portrait.modulate = Color.WHITE if unit.is_alive() else Color("4f463c")
	for button in action_buttons:
		button.disabled = not unit.is_alive()


func add_label(value: String, font_size: int, color: Color = Color("eadcc0")) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	content.add_child(label)
	return label


func add_bar(color: Color, height: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = height
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("2e2217")
	background.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", background)
	content.add_child(bar)
	return bar
