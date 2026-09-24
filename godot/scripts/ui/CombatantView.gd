extends Button
## A clickable placeholder portrait; all state is read from CharacterUnit.

var unit: CharacterUnit
var name_label: Label
var details: Label
var health: ProgressBar
var resources: Label
var feedback_tween: Tween


func setup(combatant: CharacterUnit) -> void:
	unit = combatant
	custom_minimum_size = Vector2(200, 166)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 7)
	margin.add_child(body)
	name_label = make_label(body, 20)
	var position := make_label(body, 12)
	position.text = ["FRONT / 전열", "MIDDLE / 중열", "BACK / 후열"][unit.formation_slot]
	position.add_theme_color_override("font_color", unit.character_data.display_color)
	health = ProgressBar.new()
	health.custom_minimum_size.y = 8
	health.show_percentage = false
	health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = unit.character_data.display_color
	fill.set_corner_radius_all(3)
	health.add_theme_stylebox_override("fill", fill)
	body.add_child(health)
	resources = make_label(body, 13)
	details = make_label(body, 13)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size.y = 36


func make_label(parent: Node, size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


func refresh(active: bool, targetable: bool, detail: String) -> void:
	disabled = not targetable
	name_label.text = ("▶ " if active else "") + unit.display_name
	health.max_value = unit.max_hp
	health.value = unit.current_hp
	resources.text = "HP %d/%d  ·  실드 %d  ·  EN %d/%d" % [unit.current_hp, unit.max_hp, unit.current_shield, unit.current_energy, unit.max_energy]
	details.text = detail if unit.is_alive() else "전투 불능"
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("182d36") if targetable else Color("111d30")
	frame.border_color = Color("69e6c3") if targetable else (Color("efbb6e") if active else Color("34435a"))
	frame.set_border_width_all(2 if active or targetable else 1)
	frame.set_corner_radius_all(10)
	for state in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(state, frame)
	self_modulate = Color.WHITE if unit.is_alive() else Color("737b88")
	tooltip_text = "클릭하여 대상 확정" if targetable else unit.character_data.description


func flash(color: Color) -> void:
	if feedback_tween != null:
		feedback_tween.kill()
	modulate = color
	feedback_tween = create_tween()
	feedback_tween.tween_property(self, "modulate", Color.WHITE, 0.4)
