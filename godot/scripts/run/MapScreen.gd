extends Control
## Map screen: shows the act, the party and gold, and sends the party to the chosen node.

## One line per node type for the hover bubble, in RunMap.NodeType order.
const NOTES := [
	"적 무리와 싸웁니다. 이기면 골드와 장비 3택 1.",
	"강한 정예와 싸웁니다. 골드가 많고 장비 3택 1.",
	"모닥불에서 쉬며 HP를 40% 회복합니다.",
	"이야기와 선택지. 2d6 판정이 걸리기도 합니다.",
	"보물 상자. 골드와 장비 3택 1.",
	"막의 끝. 잿불 사제가 기다립니다.",
]


## Speech bubble with a tail pointing at the node below (or above, near the top edge).
class MapBubble extends Control:
	const PAD := Vector2(14, 10)
	const TAIL := 12.0
	const GAP := 30.0
	var column: VBoxContainer
	var title: Label
	var note: Label
	var state: Label
	var below := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false
		column = VBoxContainer.new()
		column.add_theme_constant_override("separation", 2)
		column.position = PAD
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(column)
		title = line(17, Color("e6dcc6"))
		note = line(14, Color("d8d1c1"))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size.x = 210
		state = line(13, Color("8fae7c"))

	func line(font_size: int, color: Color) -> Label:
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", color)
		column.add_child(label)
		return label

	func show_at(anchor: Vector2, heading: String, text: String, status: String, open: bool, bounds: Vector2) -> void:
		title.text = heading
		note.text = text
		state.text = status
		state.add_theme_color_override("font_color", Color("8fae7c") if open else Color("978f80"))
		column.reset_size()
		size = column.get_combined_minimum_size() + PAD * 2.0
		below = anchor.y - GAP - TAIL - size.y < 4.0
		var y := anchor.y + GAP + TAIL if below else anchor.y - GAP - TAIL - size.y
		var x := clampf(anchor.x - size.x / 2.0, 6.0, bounds.x - size.x - 6.0)
		position = Vector2(x, y)
		set_meta("tail_x", anchor.x - x)
		visible = true
		queue_redraw()

	func _draw() -> void:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(FantasyTheme.PAPER, 0.97)
		box.border_color = FantasyTheme.EDGE
		box.set_border_width_all(2)
		box.set_corner_radius_all(10)
		box.shadow_color = Color(0, 0, 0, 0.45)
		box.shadow_size = 6
		draw_style_box(box, Rect2(Vector2.ZERO, size))
		var tip_x: float = clampf(get_meta("tail_x", size.x / 2.0), 14.0, size.x - 14.0)
		var base_y := 0.0 if below else size.y
		var point_y := -TAIL if below else size.y + TAIL
		var tail := PackedVector2Array([Vector2(tip_x - 9, base_y), Vector2(tip_x + 9, base_y), Vector2(tip_x, point_y)])
		draw_colored_polygon(tail, Color(FantasyTheme.PAPER, 0.97))
		draw_polyline(PackedVector2Array([tail[0], tail[2], tail[1]]), FantasyTheme.EDGE, 2.0, true)
		# Cover the border under the tail's mouth so bubble and tail read as one shape.
		draw_line(Vector2(tip_x - 7, base_y), Vector2(tip_x + 7, base_y), Color(FantasyTheme.PAPER, 1.0), 3.0)

const PARCHMENT_SHADER := """
shader_type canvas_item;
uniform vec2 resolution = vec2(700.0, 1100.0);

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

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 5; octave++) {
		value += amplitude * noise(p);
		p *= 2.1;
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 px = UV * resolution;
	float grain = fbm(px / 60.0);
	float stain = fbm(px / 260.0 + 7.0);
	vec3 base = mix(vec3(0.52, 0.49, 0.41), vec3(0.66, 0.62, 0.52), grain);
	base *= 1.0 - smoothstep(0.55, 0.85, stain) * 0.12;
	// A little warmth towards the edges, like an old storybook page.
	base *= 1.0 - smoothstep(0.35, 0.8, distance(UV, vec2(0.5, 0.5))) * 0.14;
	vec2 edge_distance = min(px, resolution - px);
	float ragged = min(edge_distance.x, edge_distance.y) + (fbm(px / 18.0) - 0.5) * 22.0;
	float burn = smoothstep(4.0, 34.0, ragged);
	base = mix(vec3(0.22, 0.19, 0.15), base, burn);
	COLOR = vec4(base, smoothstep(0.0, 5.0, ragged));
}
"""

var run: RunState
var canvas: MapCanvas
var scroll: ScrollContainer
var info: Label
var bubble: MapBubble


func _ready() -> void:
	run = RunState.active
	if run == null:
		leave_to.call_deferred(SceneRouter.MAIN_MENU)
		return
	if run.finished:
		leave_to.call_deferred(SceneRouter.RUN_END)
		return
	if not run.node_resolved and run.current_node() != null:
		# Came back mid-node (e.g. via the main menu): finish that node first.
		enter_current.call_deferred()
		return
	build()


func build() -> void:
	theme = FantasyTheme.build()
	AudioDirector.music("map")
	add_child(Backdrop.new())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	var header := HBoxContainer.new()
	page.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	FantasyTheme.label(titles, "OATH OF EMBERS   ·   CHAPTER I", 14, FantasyTheme.TRIM)
	var title := FantasyTheme.label(titles, "잿빛 고갯길  ·  여정 지도", 32, Color("e6dcc6"), true)
	FantasyTheme.glow(title, Color("ff8a2a"), 10)
	header.add_theme_constant_override("separation", 10)
	var camp := FantasyTheme.button(header, "야영지", func(): SceneRouter.go(get_tree(), SceneRouter.CAMP))
	camp.name = "CampButton"
	camp.tooltip_text = "장비를 갈아입고 골드로 기술을 강화합니다. 노드를 쓰지 않습니다."
	FantasyTheme.button(header, "메인 메뉴", func(): SceneRouter.go(get_tree(), SceneRouter.MAIN_MENU))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	page.add_child(body)
	body.add_child(party_panel())
	scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var sheet := ColorRect.new()
	sheet.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sheet_material := ShaderMaterial.new()
	sheet_material.shader = Shader.new()
	sheet_material.shader.code = PARCHMENT_SHADER
	sheet.material = sheet_material
	# With the legend gone the scroll area is wide; keep the parchment in the middle.
	var middle := CenterContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(middle)
	middle.add_child(sheet)
	canvas = MapCanvas.new()
	canvas.setup(run)
	sheet.custom_minimum_size = canvas.custom_minimum_size
	sheet_material.set_shader_parameter("resolution", canvas.custom_minimum_size)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.add_child(canvas)
	canvas.node_chosen.connect(choose)
	canvas.node_hovered.connect(describe)
	bubble = MapBubble.new()
	bubble.name = "MapBubble"
	canvas.add_child(bubble)
	info = FantasyTheme.label(page, "", 17, FantasyTheme.TEXT)
	describe(-1)
	scroll_to_party.call_deferred()


func party_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 240
	panel.add_theme_stylebox_override("panel", FantasyTheme.panel())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	FantasyTheme.label(column, "일행", 18, FantasyTheme.TRIM, true)
	for hero in run.party:
		FantasyTheme.hero_row(column, hero)
	column.add_child(HSeparator.new())
	FantasyTheme.label(column, "골드   %d" % run.gold, 18, FantasyTheme.GOLD, true)
	var floor_text := "출발 전" if run.current_floor() < 0 else "%d층 / %d층" % [run.current_floor() + 1, RunMap.FLOORS]
	FantasyTheme.label(column, "위치   %s" % floor_text, 16, FantasyTheme.TEXT)
	FantasyTheme.label(column, "승리한 전투   %d" % run.battles_won, 16, FantasyTheme.TEXT)
	if run.ward > 0:
		FantasyTheme.label(column, "축복   다음 전투 보호막 +%d" % run.ward, 15, Color("8aa2c0"))
	return panel


func scroll_to_party() -> void:
	# Container sizes settle one frame after build; measure after that.
	await get_tree().process_frame
	var focus_floor := maxi(run.current_floor(), 0)
	var target_y := canvas.custom_minimum_size.y - MapCanvas.MARGIN.y - MapCanvas.ROW * focus_floor
	scroll.scroll_vertical = int(maxf(0.0, target_y - scroll.size.y * 0.82))


## Hovering a node pops a speech bubble over it: what it is, a line about it, and
## whether the party can go there.
func describe(node_id: int) -> void:
	if info == null:
		return
	info.text = "다음 목적지를 고르세요. 노드에 마우스를 올리면 설명이 나옵니다." if not run.available_nodes().is_empty() else ""
	if node_id < 0:
		bubble.hide()
		return
	var map_node := run.map.node(node_id)
	var open := node_id in canvas.reachable()
	var state := "갈 수 있음" if open else ("지나온 길" if node_id in run.visited else "지금은 갈 수 없음")
	var heading := "보스 · 잿불 사제 모르간" if map_node.type == RunMap.NodeType.BOSS else "%d층 · %s" % [map_node.floor + 1, RunMap.TYPE_NAMES[map_node.type]]
	bubble.show_at(canvas.positions[node_id], heading, NOTES[map_node.type], state, open, canvas.size)


func choose(node_id: int) -> void:
	if run.travel(node_id):
		AudioDirector.sfx("step")
		enter_current()


func enter_current() -> void:
	leave_to(SceneRouter.BATTLE if Encounters.is_combat(run.current_node()) else SceneRouter.NODE)


func leave_to(path: String) -> void:
	SceneRouter.go(get_tree(), path)
