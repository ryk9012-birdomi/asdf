class_name FantasyTheme
extends RefCounted
## Shared look from the Art Bible (docs/ART_BIBLE.md): old records and field gear. Dark
## weathered parchment panels framed in dull iron, faded ink-and-parchment text, muted rust
## accents, Gowun Batang serif throughout (OFL, in assets/fonts).

const BODY_FONT := "res://assets/fonts/GowunBatang-Regular.ttf"
const TITLE_FONT := "res://assets/fonts/GowunBatang-Bold.ttf"
## Panel ground: dark, smoke-stained parchment.
const PAPER := Color("2a2722")
## Dull iron frame.
const EDGE := Color("5e5a50")
## Muted rust: headings and accents.
const TRIM := Color("b98260")
## Tarnished brass.
const GOLD := Color("b0915c")
## Cold parchment text.
const TEXT := Color("d8d1c1")
const MUTED := Color("978f80")
## Brightest text, for hover and emphasis.
const INK := Color("f0e9d8")
## Dried blood, lifted enough to read on the dark panels.
const BLOOD := Color("c0645a")
## Dark rim around text drawn straight onto a painting.
const HALO := Color("15130f")
## Good news (healing, gains) in a faded moss green.
const MOSS := Color("8fae7c")
const MUTED_SHADER := """
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(luma), 0.45) * vec3(0.94, 0.95, 0.96);
	COLOR = c;
}
"""
static var _muted: ShaderMaterial


static func build() -> Theme:
	var ui_theme := Theme.new()
	var body: FontFile = load(BODY_FONT)
	var title: FontFile = load(TITLE_FONT)
	ui_theme.default_font = body
	ui_theme.default_font_size = 17
	ui_theme.set_color("font_color", "Label", TEXT)
	ui_theme.set_type_variation("HeadingLabel", "Label")
	ui_theme.set_font("font", "HeadingLabel", title)
	ui_theme.set_color("font_color", "HeadingLabel", TRIM)
	for variation in ["Button", "MenuButtonLarge"]:
		if variation != "Button":
			ui_theme.set_type_variation(variation, "Button")
			ui_theme.set_font_size("font_size", variation, 23)
		ui_theme.set_font("font", variation, title)
		ui_theme.set_color("font_color", variation, TEXT)
		ui_theme.set_color("font_hover_color", variation, INK)
		ui_theme.set_color("font_focus_color", variation, INK)
		ui_theme.set_color("font_pressed_color", variation, INK)
		ui_theme.set_color("font_disabled_color", variation, Color("6c665b"))
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			ui_theme.set_stylebox(state, variation, button_style(state, variation == "Button"))
	ui_theme.set_color("font_color", "TooltipLabel", TEXT)
	var tip := panel(EDGE, 0.97, 8)
	ui_theme.set_stylebox("panel", "TooltipPanel", tip)
	return ui_theme


## Worn leather buttons with an iron rim; hover warms the rim like lantern light.
static func button_style(state: String, compact: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("39322a")
	style.border_color = Color("6a6152")
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	var pad := 14 if compact else 0
	style.content_margin_left = pad
	style.content_margin_right = pad
	style.content_margin_top = 6 if compact else 0
	style.content_margin_bottom = 6 if compact else 0
	match state:
		"hover", "focus":
			style.bg_color = Color("463d32")
			style.border_color = Color("a8825a")
			style.shadow_color = Color(0.85, 0.55, 0.25, 0.22)
			style.shadow_size = 6
			style.shadow_offset = Vector2.ZERO
		"pressed":
			style.bg_color = Color("2a251f")
			style.border_color = Color("8a6a4a")
		"disabled":
			style.bg_color = Color(0.2, 0.19, 0.17, 0.75)
			style.border_color = Color("48443c")
	return style


static func panel(border: Color = EDGE, alpha: float = 0.93, padding: int = 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PAPER, alpha)
	style.border_color = border.lerp(EDGE, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, padding)
	return style


## Takes bright item art down to the world's muted colours (shared material).
static func muted() -> ShaderMaterial:
	if _muted == null:
		_muted = ShaderMaterial.new()
		_muted.shader = Shader.new()
		_muted.shader.code = MUTED_SHADER
	return _muted


static func label(parent: Node, text_value: String, font_size: int = 14, color: Color = TEXT, heading: bool = false) -> Label:
	var item := Label.new()
	item.text = text_value
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	if heading:
		item.theme_type_variation = "HeadingLabel"
	parent.add_child(item)
	return item


## Title drawn on a painting: faded parchment letters with a dark rim.
static func glow(item: Label, _color: Color = TRIM, strength: int = 8) -> void:
	item.add_theme_color_override("font_color", Color("e6dcc6"))
	item.add_theme_color_override("font_outline_color", HALO)
	item.add_theme_constant_override("outline_size", maxi(6, strength))
	item.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	item.add_theme_constant_override("shadow_offset_x", 0)
	item.add_theme_constant_override("shadow_offset_y", 3)


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
	var name_label := label(title, hero.definition.character_name, 18, TEXT, true)
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


## Focus a control on the next frame, unless the screen changed in between.
static func focus_later(control: Control) -> void:
	var grab := func() -> void:
		if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
			control.grab_focus()
	grab.call_deferred()
