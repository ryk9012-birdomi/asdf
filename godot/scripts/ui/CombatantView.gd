extends Button
## A clickable placeholder portrait; all state is read from CharacterUnit.

const SLOT_NAMES := ["FRONT  /  전열", "MIDDLE  /  중열", "BACK  /  후열"]

enum Glow { NONE, ACTIVE, TARGET }

var unit: CharacterUnit
var accent: Color
var content: MarginContainer
var emblem: Emblem
var name_label: Label
var details: Label
var health: ProgressBar
var health_trail: ProgressBar
var shield_bar: ProgressBar
var resources: Label
var energy_pips: HBoxContainer
var glow: Panel
var down_stamp: Label
var glow_state: Glow = Glow.NONE
var glow_tween: Tween
var feedback_tween: Tween
var bar_tween: Tween


class Emblem extends Control:
	## Procedural portrait: layered disc, spinning rings and a class glyph.
	var color: Color = Color.WHITE
	var glyph: String = ""
	var hostile: bool = false
	var alive: bool = true
	var spin: float = 0.0

	func _process(delta: float) -> void:
		if alive:
			spin += delta * (0.9 if hostile else 0.6)
			queue_redraw()

	func _draw() -> void:
		var center := size / 2.0
		var radius := minf(size.x, size.y) / 2.0 - 3.0
		var tint := color if alive else Color("59606d")
		draw_circle(center, radius, tint.darkened(0.86))
		for layer in 6:
			draw_circle(center + Vector2(0, -radius * 0.18), radius * (0.92 - layer * 0.14), Color(tint, 0.08 + layer * 0.03))
		var sides := 6 if hostile else 8
		var shape := PackedVector2Array()
		for index in sides + 1:
			var angle := TAU * index / sides - spin * 0.35
			shape.append(center + Vector2.from_angle(angle) * radius * 0.72)
		draw_polyline(shape, Color(tint, 0.55), 1.5, true)
		draw_arc(center, radius, spin, spin + PI * 0.7, 32, tint, 2.5, true)
		draw_arc(center, radius, spin + PI, spin + PI * 1.7, 32, Color(tint, 0.6), 2.5, true)
		draw_arc(center, radius * 0.86, -spin * 1.6, -spin * 1.6 + PI * 0.4, 16, Color(tint.lightened(0.4), 0.8), 1.5, true)
		var font := get_theme_default_font()
		var font_size := int(radius * 0.62)
		var text_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var baseline := center + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) - text_size.y / 2.0)
		draw_string_outline(font, baseline, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(tint, 0.35))
		draw_string(font, baseline, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint.lightened(0.55))


func setup(combatant: CharacterUnit, mirrored: bool = false) -> void:
	unit = combatant
	accent = unit.character_data.display_color
	custom_minimum_size = Vector2(0, 124)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_NONE
	glow = Panel.new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.modulate.a = 0.0
	add_child(glow)
	content = MarginContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		content.add_theme_constant_override("margin_" + side, 12)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	var layout := HBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation", 14)
	content.add_child(layout)
	emblem = Emblem.new()
	emblem.custom_minimum_size = Vector2(96, 96)
	emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.color = accent
	emblem.hostile = mirrored
	emblem.glyph = glyph_for(unit.character_data.class_name_label)
	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 5)
	layout.add_child(body)
	layout.add_child(emblem)
	if not mirrored:
		layout.move_child(emblem, 0)
	var title := HBoxContainer.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(title)
	name_label = make_label(title, 20)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_shadow_color", Color(accent, 0.55))
	name_label.add_theme_constant_override("shadow_outline_size", 6)
	name_label.add_theme_constant_override("shadow_offset_x", 0)
	name_label.add_theme_constant_override("shadow_offset_y", 0)
	var slot := make_label(title, 11)
	slot.text = SLOT_NAMES[unit.formation_slot]
	slot.add_theme_color_override("font_color", accent)
	var bars := Control.new()
	bars.custom_minimum_size.y = 12
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(bars)
	health_trail = make_bar(bars, Color("ffe1c2"), Color("0a121f"))
	health = make_bar(bars, accent, Color(0, 0, 0, 0))
	shield_bar = make_bar(body, Color("7eeaff"), Color("0a121f"))
	shield_bar.custom_minimum_size.y = 4
	var resource_row := HBoxContainer.new()
	resource_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resource_row.add_theme_constant_override("separation", 10)
	body.add_child(resource_row)
	resources = make_label(resource_row, 13)
	resources.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	energy_pips = HBoxContainer.new()
	energy_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energy_pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	energy_pips.add_theme_constant_override("separation", 3)
	resource_row.add_child(energy_pips)
	for _index in unit.max_energy:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(12, 7)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		energy_pips.add_child(pip)
	details = make_label(body, 13)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_color_override("font_color", Color("a9bad2"))
	down_stamp = Label.new()
	down_stamp.text = "K.I.A  /  전투 불능"
	down_stamp.add_theme_font_size_override("font_size", 22)
	down_stamp.add_theme_color_override("font_color", Color("ff6b73"))
	down_stamp.add_theme_color_override("font_outline_color", Color("1a0508"))
	down_stamp.add_theme_constant_override("outline_size", 8)
	down_stamp.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	down_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	down_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	down_stamp.rotation = -0.12
	down_stamp.visible = false
	add_child(down_stamp)
	health.max_value = unit.max_hp
	health.value = unit.current_hp
	health_trail.max_value = unit.max_hp
	health_trail.value = unit.current_hp
	resized.connect(func():
		pivot_offset = size / 2.0
		down_stamp.pivot_offset = down_stamp.size / 2.0)


func glyph_for(label_text: String) -> String:
	var letters := ""
	for word in label_text.split(" ", false):
		letters += word.substr(0, 1).to_upper()
	return letters.substr(0, 2) if not letters.is_empty() else "?"


func make_label(parent: Node, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func make_bar(parent: Control, fill_color: Color, back_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(3)
	var back := StyleBoxFlat.new()
	back.bg_color = back_color
	back.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	if parent is Container:
		bar.custom_minimum_size.y = 12
		parent.add_child(bar)
	else:
		parent.add_child(bar)
		bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return bar


func refresh(active: bool, targetable: bool, detail: String) -> void:
	var alive := unit.is_alive()
	disabled = not targetable
	name_label.text = ("▶ " if active else "") + unit.display_name
	resources.text = "HP %d/%d   실드 %d" % [unit.current_hp, unit.max_hp, unit.current_shield]
	details.text = detail if alive else "신호 소실"
	shield_bar.max_value = maxi(1, unit.max_hp / 2)
	shield_bar.value = unit.current_shield
	update_health_bars()
	for index in energy_pips.get_child_count():
		var pip_style := StyleBoxFlat.new()
		pip_style.set_corner_radius_all(2)
		pip_style.bg_color = Color("7aa2ff") if index < unit.current_energy else Color("1d2a40")
		if index < unit.current_energy:
			pip_style.shadow_color = Color(0.48, 0.64, 1.0, 0.6)
			pip_style.shadow_size = 3
		energy_pips.get_child(index).add_theme_stylebox_override("panel", pip_style)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("0c1627").lerp(accent, 0.07)
	frame.bg_color.a = 0.9
	frame.border_color = accent.darkened(0.45)
	frame.set_border_width_all(1)
	frame.border_width_left = 4
	frame.set_corner_radius_all(12)
	frame.shadow_color = Color(0, 0, 0, 0.45)
	frame.shadow_size = 8
	frame.shadow_offset = Vector2(0, 4)
	var hover := frame.duplicate() as StyleBoxFlat
	hover.bg_color = frame.bg_color.lerp(Color("69e6c3"), 0.12)
	for state in ["normal", "pressed", "disabled"]:
		add_theme_stylebox_override(state, frame)
	add_theme_stylebox_override("hover", hover if targetable else frame)
	emblem.alive = alive
	emblem.queue_redraw()
	if not alive and not down_stamp.visible:
		play_down()
	self_modulate = Color.WHITE if alive else Color("6d7481")
	content.modulate = Color.WHITE if alive else Color(0.55, 0.58, 0.64, 0.8)
	tooltip_text = "클릭하여 대상 확정" if targetable else unit.character_data.description
	set_glow(Glow.TARGET if targetable else (Glow.ACTIVE if active and alive else Glow.NONE))


func update_health_bars() -> void:
	if is_equal_approx(health.value, unit.current_hp) and is_equal_approx(health_trail.value, unit.current_hp):
		return
	if bar_tween != null:
		bar_tween.kill()
	bar_tween = create_tween()
	bar_tween.tween_property(health, "value", float(unit.current_hp), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bar_tween.tween_interval(0.25)
	bar_tween.tween_property(health_trail, "value", float(unit.current_hp), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func set_glow(state: Glow) -> void:
	if state == glow_state:
		return
	glow_state = state
	if glow_tween != null:
		glow_tween.kill()
	if state == Glow.NONE:
		glow.modulate.a = 0.0
		return
	var color := Color("69e6c3") if state == Glow.TARGET else Color("ffc76b")
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(color, 0.5)
	style.shadow_size = 16
	glow.add_theme_stylebox_override("panel", style)
	glow.modulate.a = 1.0
	glow_tween = create_tween().set_loops()
	glow_tween.tween_property(glow, "modulate:a", 0.35, 0.7).set_trans(Tween.TRANS_SINE)
	glow_tween.tween_property(glow, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)


func flash(color: Color, shake: float = 0.0) -> void:
	if feedback_tween != null:
		feedback_tween.kill()
	modulate = color * 1.6
	scale = Vector2.ONE * 1.04
	content.position = Vector2.ZERO
	feedback_tween = create_tween()
	feedback_tween.tween_property(self, "modulate", Color.WHITE, 0.4)
	feedback_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if shake > 0.0:
		var jolt := create_tween()
		for step in 5:
			var offset := Vector2(randf_range(-shake, shake), randf_range(-shake, shake) * 0.5) * (1.0 - step / 5.0)
			jolt.tween_property(content, "position", offset, 0.035)
		jolt.tween_property(content, "position", Vector2.ZERO, 0.05)


func play_down() -> void:
	down_stamp.visible = true
	down_stamp.pivot_offset = down_stamp.size / 2.0
	down_stamp.scale = Vector2.ONE * 2.2
	down_stamp.modulate.a = 0.0
	var stamp := create_tween()
	stamp.tween_property(down_stamp, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	stamp.parallel().tween_property(down_stamp, "modulate:a", 1.0, 0.2)
