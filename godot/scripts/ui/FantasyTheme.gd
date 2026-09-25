class_name FantasyTheme
extends RefCounted
## Shared look for the menu, map and node screens: parchment text on dark leather, gold trim.

const SERIF := ["Batang", "Noto Serif CJK KR", "Noto Serif KR", "Nanum Myeongjo", "serif"]
const TRIM := Color("d8b25a")
const GOLD := Color("ffc15a")
const TEXT := Color("eadcc0")
const MUTED := Color("a8977a")
const INK := Color("3a2414")
const BLOOD := Color("d9533f")


static func build() -> Theme:
	var ui_theme := Theme.new()
	var sans := SystemFont.new()
	sans.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "sans-serif"])
	ui_theme.default_font = sans
	ui_theme.default_font_size = 17
	ui_theme.set_color("font_color", "Label", TEXT)
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(SERIF)
	serif.font_weight = 600
	ui_theme.set_type_variation("HeadingLabel", "Label")
	ui_theme.set_font("font", "HeadingLabel", serif)
	for variation in ["Button", "MenuButtonLarge"]:
		if variation != "Button":
			ui_theme.set_type_variation(variation, "Button")
			ui_theme.set_font("font", variation, serif)
			ui_theme.set_font_size("font_size", variation, 22)
		ui_theme.set_color("font_color", variation, TEXT)
		ui_theme.set_color("font_hover_color", variation, Color("fff3d6"))
		ui_theme.set_color("font_focus_color", variation, Color("fff3d6"))
		ui_theme.set_color("font_disabled_color", variation, Color("5f5446"))
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			ui_theme.set_stylebox(state, variation, button_style(state, variation == "Button"))
	return ui_theme


static func button_style(state: String, compact: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.07, 0.04, 0.82)
	style.border_color = Color("6e5431")
	style.set_border_width_all(1)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.set_corner_radius_all(3)
	var pad := 14 if compact else 0
	style.content_margin_left = pad
	style.content_margin_right = pad
	style.content_margin_top = 8 if compact else 0
	style.content_margin_bottom = 8 if compact else 0
	match state:
		"hover", "focus":
			style.bg_color = Color(0.2, 0.13, 0.07, 0.92)
			style.border_color = TRIM
			style.shadow_color = Color(1.0, 0.6, 0.2, 0.35)
			style.shadow_size = 14
		"pressed":
			style.bg_color = Color("4a3016")
			style.border_color = Color("ffd98a")
		"disabled":
			style.bg_color = Color(0.07, 0.05, 0.03, 0.7)
			style.border_color = Color("3b2f22")
	return style


static func panel(border: Color = Color("7a5c2e"), alpha: float = 0.86, padding: int = 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.06, 0.04, alpha)
	style.border_color = Color(border, 0.9)
	style.set_border_width_all(1)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 10
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, padding)
	return style


static func label(parent: Node, text_value: String, font_size: int = 14, color: Color = TEXT, heading: bool = false) -> Label:
	var item := Label.new()
	item.text = text_value
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	if heading:
		item.theme_type_variation = "HeadingLabel"
	parent.add_child(item)
	return item


static func glow(item: Label, color: Color, strength: int) -> void:
	item.add_theme_color_override("font_shadow_color", Color(color, 0.45))
	item.add_theme_constant_override("shadow_outline_size", strength)
	item.add_theme_constant_override("shadow_offset_x", 0)
	item.add_theme_constant_override("shadow_offset_y", 0)


static func button(parent: Node, caption: String, callback: Callable, large: bool = false) -> Button:
	var item := Button.new()
	item.text = caption
	if large:
		item.theme_type_variation = "MenuButtonLarge"
		item.custom_minimum_size = Vector2(320, 52)
		item.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	item.pressed.connect(func(): AudioDirector.sfx("ui_click", 0.1, -6.0))
	item.pressed.connect(callback)
	parent.add_child(item)
	return item


## HP bar row used on the map and node screens.
static func hero_row(parent: Node, hero: RunState.HeroState) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	parent.add_child(row)
	var color := hero.definition.display_color
	var title := HBoxContainer.new()
	row.add_child(title)
	var name_label := label(title, hero.definition.character_name, 18, Color("f4e6c4"), true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label(title, "HP %d/%d" % [hero.current_hp, hero.max_hp()], 15, TEXT if hero.is_alive() else BLOOD)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	bar.max_value = hero.max_hp()
	bar.value = hero.current_hp
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	var back := StyleBoxFlat.new()
	back.bg_color = Color("140d09")
	back.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	row.add_child(bar)
	label(row, hero.definition.class_name_label, 13, color)
