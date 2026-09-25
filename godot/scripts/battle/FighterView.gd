class_name FighterView
extends Button
## One combatant on the 2D battlefield: a hand-drawn side-view figure with its HP / MP
## readout overhead. Clicking it picks it as a target. Presentation only.

const WIDTH := 196.0
const HEIGHT := 440.0
const HUD_HEIGHT := 150.0
const ART_SCALE := 1.4
const FEET := 34.0
## Cream halo behind overhead names and numbers, so dark ink reads on the painted field.
const OUTLINE := Color("fff6e0")

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
var mp_bar: ProgressBar
var mp_text: Label
var shields: ShieldRow
var info: Label
var hud: VBoxContainer
var marker: int = 0
var down: bool = false
var motion: Tween
var bar_tween: Tween
## While a blow is in flight the readout keeps the old HP, so it drops on impact.
var hp_frozen: bool = false
## The figure moves; the overhead readout and click area stay put.
var stance: Vector2 = Vector2(-20, HUD_HEIGHT)


class ShieldRow extends Control:
	## One shield icon with the shield points written beside it; hidden at zero.
	var amount: int = 0

	func _draw() -> void:
		if amount <= 0:
			return
		var font := get_theme_default_font()
		var text := str(amount)
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		var left := (size.x - 20.0 - 5.0 - width) / 2.0
		shield(Vector2(left + 10.0, size.y / 2.0))
		var baseline := Vector2(left + 25.0, size.y / 2.0 + 6.0)
		draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 5, FighterView.OUTLINE)
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("2a5ab0"))

	func shield(center: Vector2) -> void:
		var outline := PackedVector2Array([Vector2(-8, -9), Vector2(8, -9), Vector2(8, 1), Vector2(0, 10), Vector2(-8, 1)])
		var face := PackedVector2Array()
		for point in outline:
			face.append(center + point)
		draw_colored_polygon(face, Color("4f86f7"))
		var rim := face.duplicate()
		rim.append(face[0])
		draw_polyline(rim, FighterView.OUTLINE, 2.0, true)
		draw_colored_polygon(PackedVector2Array([center + Vector2(-5, -6), center + Vector2(0, -6), center + Vector2(0, 6), center + Vector2(-5, 0.5)]), Color("9fc2ff"))
		draw_line(center + Vector2(0, -7), center + Vector2(0, 7), Color("dce8ff"), 1.5)


## Watercolor finish for a figure rendered on its own: pigment pools darker where colours
## meet and at the silhouette, colour mottles softly inside, and the paper's grain shows.
const LIT_SHADER := """
shader_type canvas_item;
uniform vec2 texel = vec2(0.002, 0.002);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (base.a < 0.01) {
		COLOR = vec4(0.0);
	} else {
		vec3 col = base.rgb;
		vec3 around = vec3(0.0);
		float solid = 0.0;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785398;
			vec4 s = texture(TEXTURE, UV + vec2(cos(a), sin(a)) * texel * 3.0);
			around += s.rgb * s.a;
			solid += s.a;
		}
		around /= max(solid, 0.001);
		float edge = clamp(length(col - around) * 1.6, 0.0, 1.0) + (1.0 - solid / 8.0) * 0.8;
		vec2 px = UV / texel;
		float mottle = noise(px / 22.0) * 0.6 + noise(px / 7.0) * 0.4;
		col *= 1.0 - clamp(edge, 0.0, 1.0) * 0.14;
		col *= 0.95 + mottle * 0.09;
		col = mix(col, vec3(1.0, 0.98, 0.94), 0.05);
		col *= 0.97 + hash(floor(px)) * 0.05;
		COLOR = vec4(col, base.a);
	}
}
"""
## Space around the figure inside its lit render, for raised weapons and falling bodies.
const LIT_MARGIN := Vector2(120, 120)
const LIT_RESOLUTION := 2.0


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
	var hurt: float = 0.0
	var lean: float = 0.0
	## Cut-out rig for characters that have one; the rest are drawn by FighterArt.
	var puppet: Puppet
	## When lit, the puppet renders into this viewport and shows through `lit_rect`.
	var lit_view: SubViewport
	var lit_rect: TextureRect

	func _process(delta: float) -> void:
		time += delta
		if puppet != null:
			var feet := Vector2(size.x / 2.0, size.y - FighterView.FEET - bob)
			var zoom := 1.0
			if lit_view != null:
				feet = (feet + FighterView.LIT_MARGIN) * FighterView.LIT_RESOLUTION
				zoom = FighterView.LIT_RESOLUTION
			puppet.position = feet
			puppet.rotation = fallen * -PI / 2.0 * 0.95
			puppet.scale = Vector2.ONE * FighterView.ART_SCALE * puppet.size * zoom
			puppet.drive(self, delta)
		queue_redraw()

	## Moves the puppet into its own render with the lighting shader on top.
	func light() -> void:
		if puppet == null or lit_view != null:
			return
		# Parts cut from a painted sheet are watercolour already.
		if puppet is HeroPuppet and not (puppet as HeroPuppet).sheet.is_empty():
			return
		var box := size + FighterView.LIT_MARGIN * Vector2(2, 1)
		lit_view = SubViewport.new()
		lit_view.transparent_bg = true
		lit_view.size = Vector2i(box * FighterView.LIT_RESOLUTION)
		lit_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		lit_view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(lit_view)
		puppet.get_parent().remove_child(puppet)
		lit_view.add_child(puppet)
		lit_rect = TextureRect.new()
		lit_rect.texture = lit_view.get_texture()
		lit_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lit_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lit_rect.stretch_mode = TextureRect.STRETCH_SCALE
		lit_rect.position = -FighterView.LIT_MARGIN
		var material := ShaderMaterial.new()
		material.shader = Shader.new()
		material.shader.code = FighterView.LIT_SHADER
		material.set_shader_parameter("texel", Vector2.ONE / Vector2(lit_view.size))
		lit_rect.material = material
		add_child(lit_rect)
		lit_rect.size = box

	func _draw() -> void:
		var feet := Vector2(size.x / 2.0, size.y - FighterView.FEET)
		var pulse := 0.5 + 0.5 * sin(time * 5.0)
		match marker:
			1:
				ground_ellipse(feet, Vector2(70, 15), Color(1.0, 0.76, 0.35, 0.55))
			2:
				ground_ellipse(feet, Vector2(72 + pulse * 6.0, 16 + pulse), Color(0.43, 0.88, 0.55, 0.35 + 0.3 * pulse))
		ground_ellipse(feet, Vector2(48, 10), Color(0, 0, 0, 0.45))
		if puppet != null:
			return
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
	var id := unit.character_data.id
	kind = id if HeroPuppet.RIGS.has(id) or id in FighterArt.KINDS else unit.character_data.class_id
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
	figure.size = Vector2(WIDTH + 40, HEIGHT - HUD_HEIGHT)
	figure.pivot_offset = Vector2(figure.size.x / 2.0, figure.size.y - FEET)
	figure.scale = Vector2(facing, 1.0)
	figure.puppet = Puppet.create(kind)
	if figure.puppet != null:
		figure.puppet.phase = figure.phase
		if figure.puppet is HeroPuppet and not unit.character_data.gear.is_empty():
			figure.puppet.wear(unit.character_data.gear)
		figure.add_child(figure.puppet)
	add_child(figure)
	# Every figure gets the watercolor finish.
	figure.light()
	hud = VBoxContainer.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.position = Vector2(6, 0)
	hud.size = Vector2(WIDTH - 12, HUD_HEIGHT)
	hud.add_theme_constant_override("separation", 3)
	add_child(hud)
	name_label = small_label(19, Color("4a3222"))
	name_label.theme_type_variation = "HeadingLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_outline_color", OUTLINE)
	name_label.add_theme_constant_override("outline_size", 6)
	var hp_row := bar_row(20)
	hp_trail = make_bar(hp_row, Color("f7e3b8"), Color(0.35, 0.25, 0.18, 0.85))
	hp_bar = make_bar(hp_row, Color("d0574a") if facing < 0 else Color("6fb34a"), Color(0, 0, 0, 0))
	hp_text = bar_text(hp_row, 14)
	var mp_row := bar_row(15)
	mp_bar = make_bar(mp_row, Color("5a8ae0"), Color(0.2, 0.22, 0.32, 0.85))
	mp_bar.max_value = maxi(1, unit.max_energy)
	mp_text = bar_text(mp_row, 12)
	shields = ShieldRow.new()
	shields.custom_minimum_size.y = 22
	shields.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(shields)
	info = small_label(15, Color("2a180c"))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_color_override("font_outline_color", OUTLINE)
	info.add_theme_constant_override("outline_size", 8)
	hp_bar.max_value = unit.max_hp
	hp_trail.max_value = unit.max_hp
	hp_bar.value = unit.current_hp
	hp_trail.value = unit.current_hp


func bar_row(height: int) -> Control:
	var row := Control.new()
	row.custom_minimum_size.y = height
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(row)
	return row


func bar_text(row: Control, font_size: int) -> Label:
	var text := Label.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", font_size)
	text.add_theme_color_override("font_color", Color.WHITE)
	text.add_theme_color_override("font_outline_color", Color("3a2414"))
	text.add_theme_constant_override("outline_size", 4)
	row.add_child(text)
	return text


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
	name_label.add_theme_color_override("font_color", Color("2e8a3e") if targetable else (Color("c0702a") if active else Color("4a3222")))
	mp_bar.value = unit.current_energy
	mp_text.text = "MP %d / %d" % [unit.current_energy, unit.max_energy]
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
	shields.amount = unit.current_shield
	shields.queue_redraw()
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
	move.parallel().tween_property(figure, "lean", 1.0, 0.24)
	for swing in maxi(1, swings):
		move.tween_property(figure, "arm", 1.5, 0.09).set_trans(Tween.TRANS_BACK)
		move.tween_property(figure, "arm", -0.6 if swing + 1 < swings else 0.0, 0.14)
	move.tween_interval(0.12)
	move.tween_property(figure, "position", stance, 0.3).set_trans(Tween.TRANS_SINE)
	move.parallel().tween_property(figure, "lean", 0.0, 0.3)
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
	knock.parallel().tween_property(figure, "hurt", 1.0, 0.06)
	knock.tween_property(figure, "position", stance, 0.22).set_trans(Tween.TRANS_SINE)
	knock.parallel().tween_property(figure, "hurt", 0.0, 0.4).set_trans(Tween.TRANS_SINE)


func dodge() -> void:
	var hop := restart_motion()
	hop.tween_property(figure, "position", stance - Vector2(30 * facing, 12), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.parallel().tween_property(figure, "lean", -0.8, 0.12)
	hop.tween_property(figure, "position", stance, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	hop.parallel().tween_property(figure, "lean", 0.0, 0.22)


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
