extends Control
## Title screen. Starts or resumes a run; owns navigation only.

const TRIM := FantasyTheme.TRIM
const TEXT := FantasyTheme.TEXT
const MUTED := FantasyTheme.MUTED

var new_run_button: Button
var continue_button: Button
var camp_button: Button
var quit_button: Button
var music_slider: HSlider
var sfx_slider: HSlider


class Sigil extends Control:
	## Slowly turning rune circle drawn behind the title.
	var turn: float = 0.0

	func _process(delta: float) -> void:
		turn += delta * 0.08
		queue_redraw()

	func _draw() -> void:
		var center := size / 2.0
		var radius := minf(size.x, size.y) / 2.0 - 6.0
		var gold := Color("d8b25a")
		draw_arc(center, radius, 0, TAU, 128, Color(gold, 0.22), 2.0, true)
		draw_arc(center, radius * 0.9, 0, TAU, 128, Color(gold, 0.14), 1.0, true)
		draw_arc(center, radius * 0.62, 0, TAU, 96, Color(gold, 0.12), 1.0, true)
		for index in 48:
			var angle := TAU * index / 48.0 + turn
			var reach := 0.9 if index % 4 else 0.84
			draw_line(center + Vector2.from_angle(angle) * radius * reach, center + Vector2.from_angle(angle) * radius, Color(gold, 0.3), 1.5, true)
		for index in 7:
			var angle := TAU * index / 7.0 - turn * 1.6
			var point := center + Vector2.from_angle(angle) * radius * 0.76
			draw_colored_polygon(PackedVector2Array([point + Vector2(0, -7), point + Vector2(5, 0), point + Vector2(0, 7), point + Vector2(-5, 0)]), Color(gold, 0.35))
		var star := PackedVector2Array()
		for index in 8:
			star.append(center + Vector2.from_angle(TAU * index * 3.0 / 8.0 + turn * 0.5) * radius * 0.62)
		star.append(star[0])
		draw_polyline(star, Color(gold, 0.1), 1.0, true)


func _ready() -> void:
	theme = FantasyTheme.build()
	AudioDirector.music("menu")
	add_child(EmberBackdrop.new())
	var sigil := Sigil.new()
	sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sigil.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	sigil.custom_minimum_size = Vector2(560, 560)
	sigil.size = Vector2(560, 560)
	sigil.position = Vector2(-280, 40)
	add_child(sigil)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	centered(column, "잿빛 왕국 연대기   ·   제 1 막", 14, TRIM)
	var title := centered(column, "잿불 서약", 84, Color("f4e2b8"))
	title.theme_type_variation = "HeadingLabel"
	glow(title, Color("ff8a2a"), 18)
	var subtitle := centered(column, "O A T H    O F    E M B E R S", 18, TRIM)
	subtitle.theme_type_variation = "HeadingLabel"
	centered(column, "용의 교단이 왕국을 잠식하는 시대, 맹세로 묶인 세 모험가가 잿빛 고갯길로 향한다.", 15, MUTED)
	var gap := Control.new()
	gap.custom_minimum_size.y = 36
	column.add_child(gap)
	new_run_button = menu_button(column, "새 여정", "고갯길에서 새 모험을 시작합니다.", start_new_run)
	continue_button = menu_button(column, "이어하기", "진행 중인 여정으로 돌아갑니다.", func(): SceneRouter.go(get_tree(), SceneRouter.MAP))
	var run := RunState.active
	continue_button.disabled = run == null or run.finished
	if continue_button.disabled:
		continue_button.tooltip_text = "진행 중인 여정이 없습니다."
	camp_button = menu_button(column, "야영지", "일행의 능력치와 상태를 살펴봅니다.", func(): SceneRouter.go(get_tree(), SceneRouter.CAMP))
	quit_button = menu_button(column, "종료", "게임을 끝냅니다.", quit_game)
	var sound_gap := Control.new()
	sound_gap.custom_minimum_size.y = 18
	column.add_child(sound_gap)
	var sound := HBoxContainer.new()
	sound.alignment = BoxContainer.ALIGNMENT_CENTER
	sound.add_theme_constant_override("separation", 12)
	column.add_child(sound)
	music_slider = volume_slider(sound, "음악", "Music")
	sfx_slider = volume_slider(sound, "효과음", "SFX")
	var footer := Label.new()
	footer.text = "MVP 1 프로토타입   ·   Godot 4.7   ·   Enter / 방향키로도 선택할 수 있습니다"
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color("7d6f58"))
	footer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	footer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	footer.position.y -= 34
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(footer)
	new_run_button.grab_focus.call_deferred()
	column.modulate.a = 0.0
	create_tween().tween_property(column, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)


func volume_slider(parent: Node, caption: String, bus: String) -> HSlider:
	var name_label := Label.new()
	name_label.text = caption
	name_label.add_theme_color_override("font_color", MUTED)
	parent.add_child(name_label)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(140, 20)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = AudioDirector.volume(bus)
	slider.value_changed.connect(func(level: float):
		AudioDirector.set_volume(bus, level)
		if bus == "SFX":
			AudioDirector.sfx("ui_click", 0.0))
	parent.add_child(slider)
	return slider


func quit_game() -> void:
	AudioDirector.shutdown()
	await get_tree().create_timer(0.35).timeout
	get_tree().quit()


func start_new_run() -> void:
	RunState.begin_default(randi())
	SceneRouter.go(get_tree(), SceneRouter.MAP)


func centered(parent: Node, text_value: String, font_size: int, color: Color) -> Label:
	var item := Label.new()
	item.text = text_value
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	parent.add_child(item)
	return item


func glow(item: Label, color: Color, strength: int) -> void:
	item.add_theme_color_override("font_shadow_color", Color(color, 0.45))
	item.add_theme_constant_override("shadow_outline_size", strength)
	item.add_theme_constant_override("shadow_offset_x", 0)
	item.add_theme_constant_override("shadow_offset_y", 0)


func menu_button(parent: Node, caption: String, hint: String, callback: Callable) -> Button:
	var item := Button.new()
	item.text = caption
	item.tooltip_text = hint
	item.custom_minimum_size = Vector2(320, 52)
	item.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	item.theme_type_variation = "MenuButtonLarge"
	item.pressed.connect(func(): AudioDirector.sfx("ui_click", 0.1, -4.0))
	item.pressed.connect(callback)
	parent.add_child(item)
	return item
