extends Button
## A clickable heraldic portrait card; all state is read from CharacterUnit.

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
	## Procedural heraldry: a kite shield for heroes, a jagged war-crest for foes.
	var color: Color = Color.WHITE
	var glyph: String = ""
	var hostile: bool = false
	var alive: bool = true
	var time: float = 0.0

	func _process(delta: float) -> void:
		if alive:
			time += delta
			queue_redraw()

	func crest(center: Vector2, radius: float, scale_by: float) -> PackedVector2Array:
		var points := PackedVector2Array()
		if hostile:
			for index in 20:
				var reach := 1.0 if index % 2 == 0 else 0.78
				points.append(center + Vector2.from_angle(TAU * index / 20.0 - PI / 2.0) * radius * reach * scale_by)
			return points
		var half := radius * 0.82 * scale_by
		var top := center.y - radius * 0.88 * scale_by
		points.append(Vector2(center.x - half, top))
		points.append(Vector2(center.x + half, top))
		for step in 13:
			var t := step / 12.0
			var a := Vector2(center.x + half, center.y - radius * 0.1 * scale_by)
			var b := Vector2(center.x + half, center.y + radius * 0.55 * scale_by)
			var tip := Vector2(center.x, center.y + radius * scale_by)
			points.append(a.lerp(b, t).lerp(b.lerp(tip, t), t))
		for step in range(12, -1, -1):
			var mirrored := points[2 + step]
			points.append(Vector2(2.0 * center.x - mirrored.x, mirrored.y))
		return points

	func _draw() -> void:
		var center := size / 2.0
		var radius := minf(size.x, size.y) / 2.0 - 4.0
		var tint := color if alive else Color("5f5a52")
		var gold := Color("d8b25a") if alive else Color("6b665d")
		var pulse := 0.5 + 0.5 * sin(time * 1.8)
		for index in 12:
			var angle := TAU * index / 12.0 + time * 0.15
			draw_circle(center + Vector2.from_angle(angle) * radius * 1.02, 1.6, Color(gold, 0.25 + 0.2 * pulse))
		var outer := crest(center, radius, 1.0)
		draw_colored_polygon(outer, tint.darkened(0.84))
		draw_colored_polygon(crest(center, radius, 0.84), tint.darkened(0.58))
		draw_colored_polygon(crest(center + Vector2(0, -radius * 0.12), radius, 0.5), Color(tint.lightened(0.25), 0.16))
		var closed := outer.duplicate()
		closed.append(outer[0])
		draw_polyline(closed, gold.lerp(Color.WHITE, 0.25 * pulse) if not hostile else Color("9a6634").lerp(tint, 0.4), 3.0, true)
		var inner := crest(center, radius, 0.84)
		inner.append(inner[0])
		draw_polyline(inner, Color(tint.lightened(0.3), 0.7), 1.2, true)
		var font := get_theme_font("font", "HeadingLabel")
		var font_size := int(radius * 0.72)
		var text_size := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var baseline := center + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) - text_size.y / 2.0 - (radius * 0.06 if not hostile else 0.0))
		draw_string_outline(font, baseline, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0, 0, 0, 0.6))
		draw_string(font, baseline, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("f4e6c4") if alive else Color("8d877c"))


class Ornament extends Control:
	## Thin inset rule with gold diamond corners, like an illuminated frame.
	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var gold := Color("c9a24a")
		var inset := Rect2(Vector2(6, 6), size - Vector2(12, 12))
		draw_rect(inset, Color(gold, 0.18), false, 1.0)
		for corner in [inset.position, Vector2(inset.end.x, inset.position.y), inset.end, Vector2(inset.position.x, inset.end.y)]:
			var diamond := PackedVector2Array([corner + Vector2(0, -5), corner + Vector2(5, 0), corner + Vector2(0, 5), corner + Vector2(-5, 0)])
			draw_colored_polygon(diamond, Color(gold, 0.85))


func setup(combatant: CharacterUnit, mirrored: bool = false) -> void:
	unit = combatant
	accent = unit.character_data.display_color
	custom_minimum_size = Vector2(0, 134)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_NONE
	glow = Panel.new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.modulate.a = 0.0
	add_child(glow)
	var ornament := Ornament.new()
	ornament.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ornament)
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
	emblem.custom_minimum_size = Vector2(88, 88)
	emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.color = accent
	emblem.hostile = mirrored
	emblem.glyph = glyph_for(unit.character_data.class_name_label)
	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 3)
	layout.add_child(body)
	layout.add_child(emblem)
	if not mirrored:
		layout.move_child(emblem, 0)
	var title := HBoxContainer.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(title)
	name_label = make_label(title, 21)
	name_label.theme_type_variation = "HeadingLabel"
	name_label.add_theme_color_override("font_color", Color("f4e6c4"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_shadow_color", Color(accent, 0.35))
	name_label.add_theme_constant_override("shadow_outline_size", 6)
	name_label.add_theme_constant_override("shadow_offset_x", 0)
	name_label.add_theme_constant_override("shadow_offset_y", 0)
	var slot := make_label(title, 11)
	slot.text = SLOT_NAMES[unit.formation_slot]
	slot.add_theme_color_override("font_color", accent)
	var bars := Control.new()
	bars.custom_minimum_size.y = 10
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(bars)
	health_trail = make_bar(bars, Color("f3dcb0"), Color("140d09"))
	health = make_bar(bars, accent, Color(0, 0, 0, 0))
	shield_bar = make_bar(body, Color("9fc6ff"), Color("140d09"))
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
		pip.custom_minimum_size = Vector2(10, 10)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		energy_pips.add_child(pip)
	details = make_label(body, 12)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_color_override("font_color", Color("b8a88a"))
	down_stamp = Label.new()
	down_stamp.text = "쓰러짐  /  DOWNED"
	down_stamp.add_theme_font_size_override("font_size", 22)
	down_stamp.add_theme_color_override("font_color", Color("e0503f"))
	down_stamp.theme_type_variation = "HeadingLabel"
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
	resources.text = "HP %d/%d   보호막 %d" % [unit.current_hp, unit.max_hp, unit.current_shield]
	details.text = detail if alive else "의식 없음"
	shield_bar.max_value = maxi(1, unit.max_hp / 2)
	shield_bar.value = unit.current_shield
	update_health_bars()
	for index in energy_pips.get_child_count():
		var pip_style := StyleBoxFlat.new()
		pip_style.set_corner_radius_all(4)
		pip_style.bg_color = Color("f0b44c") if index < unit.current_energy else Color("2e2217")
		pip_style.border_color = Color("8a6a36")
		pip_style.set_border_width_all(1)
		if index < unit.current_energy:
			pip_style.shadow_color = Color(1.0, 0.7, 0.3, 0.55)
			pip_style.shadow_size = 3
		energy_pips.get_child(index).add_theme_stylebox_override("panel", pip_style)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("1c140e").lerp(accent, 0.06)
	frame.bg_color.a = 0.94
	frame.border_color = Color("6e5431")
	frame.set_border_width_all(1)
	frame.border_width_left = 4
	frame.set_corner_radius_all(6)
	frame.shadow_color = Color(0, 0, 0, 0.45)
	frame.shadow_size = 8
	frame.shadow_offset = Vector2(0, 4)
	var hover := frame.duplicate() as StyleBoxFlat
	hover.bg_color = frame.bg_color.lerp(Color("6ee08e"), 0.1)
	for state in ["normal", "pressed", "disabled"]:
		add_theme_stylebox_override(state, frame)
	add_theme_stylebox_override("hover", hover if targetable else frame)
	emblem.alive = alive
	emblem.queue_redraw()
	if not alive and not down_stamp.visible:
		play_down()
	self_modulate = Color.WHITE if alive else Color("6f675c")
	content.modulate = Color.WHITE if alive else Color(0.6, 0.56, 0.5, 0.8)
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
	var color := Color("6ee08e") if state == Glow.TARGET else Color("ffc15a")
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
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
