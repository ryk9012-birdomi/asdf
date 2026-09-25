extends Control
## Title screen. Starts or resumes a run; owns navigation only.

const TRIM := FantasyTheme.TRIM
const TEXT := FantasyTheme.TEXT
const MUTED := FantasyTheme.MUTED

var new_run_button: Button
var continue_button: Button
var quit_button: Button
var music_slider: HSlider
var sfx_slider: HSlider


func _ready() -> void:
	theme = FantasyTheme.build()
	AudioDirector.music("menu")
	add_child(StoryBackdrop.new())
	# A paper card behind the title and choices, like a storybook's title page.
	var card := Panel.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", FantasyTheme.panel(FantasyTheme.EDGE, 0.9, 0))
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.offset_left = -330
	card.offset_right = 330
	card.offset_top = -300
	card.offset_bottom = 290
	add_child(card)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	centered(column, "잿빛 왕국 연대기   ·   제 1 막", 14, TRIM)
	var title := centered(column, "잿불 서약", 84, Color("6a3a1a"))
	title.theme_type_variation = "HeadingLabel"
	glow(title, Color("ff8a2a"), 18)
	var subtitle := centered(column, "O A T H    O F    E M B E R S", 18, TRIM)
	subtitle.theme_type_variation = "HeadingLabel"
	centered(column, "용의 교단이 왕국을 잠식하는 시대, 맹세로 묶인 세 모험가가 잿빛 고갯길로 향한다.", 15, MUTED)
	var gap := Control.new()
	gap.custom_minimum_size.y = 36
	column.add_child(gap)
	new_run_button = menu_button(column, "새 여정", "직업을 골라 일행을 꾸리고 새 모험을 시작합니다.", start_new_run)
	continue_button = menu_button(column, "이어하기", "진행 중인 여정으로 돌아갑니다.", func(): SceneRouter.go(get_tree(), SceneRouter.MAP))
	var run := RunState.active
	continue_button.disabled = run == null or run.finished
	if continue_button.disabled:
		continue_button.tooltip_text = "진행 중인 여정이 없습니다."
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
	footer.add_theme_color_override("font_color", Color("8c7458"))
	footer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	footer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	footer.position.y -= 34
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(footer)
	FantasyTheme.focus_later(new_run_button)
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
	SceneRouter.go(get_tree(), SceneRouter.PARTY)


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
