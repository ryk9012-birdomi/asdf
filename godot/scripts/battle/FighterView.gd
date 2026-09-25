class_name FighterView
extends Button
## One combatant on the 2D battlefield: a hand-drawn side-view figure with its HP / MP
## readout overhead. Clicking it picks it as a target. Presentation only.

const WIDTH := 176.0
const HEIGHT := 400.0
const ART_SCALE := 1.4
const FEET := 34.0
const OUTLINE := Color("1a0f08")

var unit: CharacterUnit
var kind: StringName
var facing: float = 1.0
var home: Vector2
var accent: Color
var figure: Figure
var name_label: Label
var hp_bar: ProgressBar
var hp_trail: ProgressBar
var hp_text: Label
var shield_text: Label
var mp_pips: HBoxContainer
var info: Label
var hud: VBoxContainer
var marker: int = 0
var down: bool = false
var motion: Tween
var bar_tween: Tween
## While a blow is in flight the readout keeps the old HP, so it drops on impact.
var hp_frozen: bool = false
## The figure moves; the overhead readout and click area stay put.
var stance: Vector2 = Vector2(-20, 110)


class Figure extends Control:
	## Draws the character around its feet at the bottom centre. Pose values are tweened.
	var kind: StringName
	var time: float = 0.0
	var phase: float = 0.0
	var bob: float = 0.0
	var arm: float = 0.0
	var glow: float = 0.0
	var marker: int = 0
	var fallen: float = 0.0

	func _process(delta: float) -> void:
		time += delta
		queue_redraw()

	func _draw() -> void:
		var feet := Vector2(size.x / 2.0, size.y - FighterView.FEET)
		var pulse := 0.5 + 0.5 * sin(time * 5.0)
		match marker:
			1:
				ground_ellipse(feet, Vector2(70, 15), Color(1.0, 0.76, 0.35, 0.55))
			2:
				ground_ellipse(feet, Vector2(72 + pulse * 6.0, 16 + pulse), Color(0.43, 0.88, 0.55, 0.35 + 0.3 * pulse))
		ground_ellipse(feet, Vector2(48, 10), Color(0, 0, 0, 0.45))
		var breathe := sin(time * 2.2 + phase) * 2.0 * (1.0 - fallen)
		draw_set_transform(feet + Vector2(0, -bob), fallen * -PI / 2.0 * 0.95, Vector2.ONE * FighterView.ART_SCALE)
		var art := FighterArt.new(self, breathe, arm, glow, time)
		art.draw(kind)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func ground_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
		var points := PackedVector2Array()
		for index in 24:
			points.append(center + Vector2(cos(TAU * index / 24.0) * radius.x, sin(TAU * index / 24.0) * radius.y))
		draw_colored_polygon(points, color)


func setup(combatant: CharacterUnit, facing_right: bool) -> void:
	unit = combatant
	facing = 1.0 if facing_right else -1.0
	kind = unit.character_data.id if unit.character_data.id in FighterArt.KINDS else unit.character_data.class_id
	accent = unit.character_data.display_color
	size = Vector2(WIDTH, HEIGHT)
	custom_minimum_size = size
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	figure = Figure.new()
	figure.kind = kind
	figure.phase = randf() * TAU
	figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	figure.position = stance
	figure.size = Vector2(WIDTH + 40, HEIGHT - 110)
	figure.pivot_offset = Vector2(figure.size.x / 2.0, figure.size.y - FEET)
	figure.scale = Vector2(facing, 1.0)
	add_child(figure)
	hud = VBoxContainer.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.position = Vector2(8, 0)
	hud.size = Vector2(WIDTH - 16, 108)
	hud.add_theme_constant_override("separation", 2)
	add_child(hud)
	name_label = small_label(15, Color("f4e6c4"))
	name_label.theme_type_variation = "HeadingLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_outline_color", OUTLINE)
	name_label.add_theme_constant_override("outline_size", 5)
	var bars := Control.new()
	bars.custom_minimum_size.y = 15
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bars)
	hp_trail = make_bar(bars, Color("f3dcb0"), Color(0.08, 0.05, 0.03, 0.9))
	hp_bar = make_bar(bars, Color("c0392b") if facing < 0 else Color("4caf50"), Color(0, 0, 0, 0))
	hp_text = Label.new()
	hp_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_text.add_theme_font_size_override("font_size", 11)
	hp_text.add_theme_color_override("font_color", Color.WHITE)
	hp_text.add_theme_color_override("font_outline_color", OUTLINE)
	hp_text.add_theme_constant_override("outline_size", 4)
	bars.add_child(hp_text)
	var resources := HBoxContainer.new()
	resources.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resources.alignment = BoxContainer.ALIGNMENT_CENTER
	resources.add_theme_constant_override("separation", 3)
	hud.add_child(resources)
	var mp_label := Label.new()
	mp_label.text = "MP"
	mp_label.add_theme_font_size_override("font_size", 10)
	mp_label.add_theme_color_override("font_color", Color("8fb4ff"))
	resources.add_child(mp_label)
	mp_pips = HBoxContainer.new()
	mp_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mp_pips.add_theme_constant_override("separation", 2)
	resources.add_child(mp_pips)
	for _index in unit.max_energy:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(9, 9)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mp_pips.add_child(pip)
	shield_text = Label.new()
	shield_text.add_theme_font_size_override("font_size", 11)
	shield_text.add_theme_color_override("font_color", Color("9fc6ff"))
	shield_text.add_theme_color_override("font_outline_color", OUTLINE)
	shield_text.add_theme_constant_override("outline_size", 3)
	resources.add_child(shield_text)
	info = small_label(11, Color("e8dcc0"))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_color_override("font_outline_color", OUTLINE)
	info.add_theme_constant_override("outline_size", 4)
	hp_bar.max_value = unit.max_hp
	hp_trail.max_value = unit.max_hp
	hp_bar.value = unit.current_hp
	hp_trail.value = unit.current_hp


func small_label(font_size: int, color: Color) -> Label:
	var item := Label.new()
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	hud.add_child(item)
	return item


func make_bar(parent: Control, fill_color: Color, back_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(3)
	var back := StyleBoxFlat.new()
	back.bg_color = back_color
	back.border_color = Color(0.85, 0.7, 0.35, 0.8) if back_color.a > 0.0 else Color(0, 0, 0, 0)
	back.set_border_width_all(1 if back_color.a > 0.0 else 0)
	back.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	parent.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return bar


## active: this unit's turn. targetable: legal for the chosen skill. line: odds or intent.
func refresh(active: bool, targetable: bool, line: String) -> void:
	var alive := unit.is_alive()
	disabled = not targetable
	name_label.text = ("▶ " if active and alive else "") + unit.display_name
	name_label.add_theme_color_override("font_color", Color("7ee89a") if targetable else (Color("ffd27a") if active else Color("f4e6c4")))
	for index in mp_pips.get_child_count():
		var pip_style := StyleBoxFlat.new()
		pip_style.set_corner_radius_all(5)
		pip_style.border_color = Color("2b3f73")
		pip_style.set_border_width_all(1)
		pip_style.bg_color = Color("6f9bff") if index < unit.current_energy else Color(0.07, 0.08, 0.14, 0.9)
		mp_pips.get_child(index).add_theme_stylebox_override("panel", pip_style)
	info.text = line if alive else "쓰러짐"
	if not hp_frozen:
		show_hp()
	marker = 2 if targetable else (1 if active and alive else 0)
	figure.marker = marker
	hud.modulate.a = 1.0 if alive or hp_frozen else 0.55


func freeze_hp() -> void:
	hp_frozen = true


func thaw_hp() -> void:
	hp_frozen = false
	show_hp()
	hud.modulate.a = 1.0 if unit.is_alive() else 0.55


func show_hp() -> void:
	hp_text.text = "HP %d / %d" % [unit.current_hp, unit.max_hp]
	shield_text.text = "  ◆ %d" % unit.current_shield if unit.current_shield > 0 else ""
	update_hp()


func update_hp() -> void:
	if is_equal_approx(hp_bar.value, unit.current_hp) and is_equal_approx(hp_trail.value, unit.current_hp):
		return
	if bar_tween != null:
		bar_tween.kill()
	bar_tween = create_tween()
	bar_tween.tween_property(hp_bar, "value", float(unit.current_hp), 0.2)
	bar_tween.tween_interval(0.25)
	bar_tween.tween_property(hp_trail, "value", float(unit.current_hp), 0.4)


## Screen-space anchors on the figure, relative to this control.
func head_offset() -> Vector2:
	return Vector2(WIDTH / 2.0, figure.position.y + figure.size.y - FEET - FighterArt.height_of(kind) * ART_SCALE - 10.0)


func chest_offset() -> Vector2:
	return Vector2(WIDTH / 2.0 + 12.0 * facing, figure.position.y + figure.size.y - FEET - FighterArt.height_of(kind) * ART_SCALE * 0.6)


func flash(color: Color, _shake: float = 0.0) -> void:
	figure.modulate = color * 1.8
	create_tween().tween_property(figure, "modulate", Color.WHITE if not down else Color(0.6, 0.55, 0.5), 0.35)


func restart_motion() -> Tween:
	if motion != null:
		motion.kill()
	motion = create_tween()
	return motion


## Dash to `spot`, swing, walk back. Returns the time of the blow.
func lunge(spot: Vector2, swings: int) -> float:
	var move := restart_motion()
	move.tween_property(figure, "arm", -1.3, 0.12)
	move.parallel().tween_property(figure, "position", stance + spot - home, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for swing in maxi(1, swings):
		move.tween_property(figure, "arm", 1.5, 0.09).set_trans(Tween.TRANS_BACK)
		move.tween_property(figure, "arm", -0.6 if swing + 1 < swings else 0.0, 0.14)
	move.tween_interval(0.12)
	move.tween_property(figure, "position", stance, 0.3).set_trans(Tween.TRANS_SINE)
	move.tween_property(figure, "arm", 0.0, 0.1)
	return 0.33


func cast(long: bool) -> float:
	var lift := restart_motion()
	var hold := 0.5 if long else 0.18
	lift.tween_property(figure, "arm", -2.1, 0.16).set_trans(Tween.TRANS_BACK)
	lift.parallel().tween_property(figure, "glow", 1.0, 0.16)
	lift.parallel().tween_property(figure, "bob", 6.0 if long else 2.0, 0.16)
	lift.tween_interval(hold)
	lift.tween_property(figure, "arm", 0.4, 0.1)
	lift.tween_property(figure, "arm", 0.0, 0.25)
	lift.parallel().tween_property(figure, "glow", 0.0, 0.4)
	lift.parallel().tween_property(figure, "bob", 0.0, 0.3)
	return 0.16 + hold + 0.1


func guard() -> void:
	var raise := restart_motion()
	raise.tween_property(figure, "glow", 1.0, 0.15)
	raise.parallel().tween_property(figure, "arm", -0.8, 0.15)
	raise.tween_interval(0.35)
	raise.tween_property(figure, "glow", 0.0, 0.4)
	raise.parallel().tween_property(figure, "arm", 0.0, 0.3)


func recoil() -> void:
	if down:
		return
	var knock := restart_motion()
	knock.tween_property(figure, "position", stance - Vector2(14 * facing, 0), 0.06)
	knock.tween_property(figure, "position", stance, 0.22).set_trans(Tween.TRANS_SINE)


func dodge() -> void:
	var hop := restart_motion()
	hop.tween_property(figure, "position", stance - Vector2(30 * facing, 12), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.tween_property(figure, "position", stance, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func fall() -> void:
	down = true
	var drop := restart_motion()
	drop.tween_property(figure, "position", stance, 0.1)
	drop.tween_property(figure, "fallen", 1.0, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	drop.parallel().tween_property(figure, "modulate", Color(0.6, 0.55, 0.5), 0.45)


func cheer(delay: float) -> void:
	if down:
		return
	var jump := restart_motion()
	jump.tween_interval(delay)
	for _hop in 2:
		jump.tween_property(figure, "bob", 18.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		jump.parallel().tween_property(figure, "arm", -2.3, 0.16)
		jump.tween_property(figure, "bob", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	jump.tween_property(figure, "arm", -2.0, 0.1)
