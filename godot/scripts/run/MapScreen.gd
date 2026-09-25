extends Control
## Map screen: shows the act, the party and gold, and sends the party to the chosen node.

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
	vec3 base = mix(vec3(0.80, 0.69, 0.50), vec3(0.93, 0.85, 0.68), grain);
	base *= 1.0 - smoothstep(0.55, 0.85, stain) * 0.22;
	vec2 edge_distance = min(px, resolution - px);
	float ragged = min(edge_distance.x, edge_distance.y) + (fbm(px / 18.0) - 0.5) * 22.0;
	float burn = smoothstep(4.0, 34.0, ragged);
	base = mix(vec3(0.28, 0.15, 0.07), base, burn);
	COLOR = vec4(base, smoothstep(0.0, 5.0, ragged));
}
"""

var run: RunState
var canvas: MapCanvas
var scroll: ScrollContainer
var info: Label


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
	add_child(EmberBackdrop.new())
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
	FantasyTheme.label(titles, "OATH OF EMBERS   ·   CHAPTER I", 12, FantasyTheme.TRIM)
	var title := FantasyTheme.label(titles, "잿빛 고갯길  ·  여정 지도", 32, Color("f4e2b8"), true)
	FantasyTheme.glow(title, Color("ff8a2a"), 10)
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
	scroll.add_child(sheet)
	canvas = MapCanvas.new()
	canvas.setup(run)
	sheet.custom_minimum_size = canvas.custom_minimum_size
	sheet_material.set_shader_parameter("resolution", canvas.custom_minimum_size)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.add_child(canvas)
	canvas.node_chosen.connect(choose)
	canvas.node_hovered.connect(describe)
	body.add_child(legend_panel())
	info = FantasyTheme.label(page, "", 15, FantasyTheme.TEXT)
	describe(-1)
	scroll_to_party.call_deferred()


func party_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 230
	panel.add_theme_stylebox_override("panel", FantasyTheme.panel())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	FantasyTheme.label(column, "일행", 18, FantasyTheme.TRIM, true)
	for hero in run.party:
		FantasyTheme.hero_row(column, hero)
	column.add_child(HSeparator.new())
	FantasyTheme.label(column, "골드   %d" % run.gold, 16, FantasyTheme.GOLD, true)
	var floor_text := "출발 전" if run.current_floor() < 0 else "%d층 / %d층" % [run.current_floor() + 1, RunMap.FLOORS]
	FantasyTheme.label(column, "위치   %s" % floor_text, 14, FantasyTheme.TEXT)
	FantasyTheme.label(column, "승리한 전투   %d" % run.battles_won, 14, FantasyTheme.TEXT)
	return panel


func legend_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 200
	panel.add_theme_stylebox_override("panel", FantasyTheme.panel())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	FantasyTheme.label(column, "범례", 18, FantasyTheme.TRIM, true)
	var notes := ["고블린 무리와 전투", "강력한 정예. 골드 더 많음", "모닥불. HP 40% 회복", "알 수 없는 조우", "보물 상자", "잿불 사제. 막의 끝"]
	for type in RunMap.NodeType.values():
		var line := VBoxContainer.new()
		column.add_child(line)
		FantasyTheme.label(line, RunMap.TYPE_NAMES[type], 15, Color("f4e6c4"), true)
		FantasyTheme.label(line, notes[type], 12, FantasyTheme.MUTED)
	column.add_child(HSeparator.new())
	var hint := FantasyTheme.label(column, "빛나는 노드를 클릭해 다음 목적지를 고릅니다. 한 번 고른 길은 되돌릴 수 없습니다.", 12, FantasyTheme.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return panel


func scroll_to_party() -> void:
	# Container sizes settle one frame after build; measure after that.
	await get_tree().process_frame
	var focus_floor := maxi(run.current_floor(), 0)
	var target_y := canvas.custom_minimum_size.y - MapCanvas.MARGIN.y - MapCanvas.ROW * focus_floor
	scroll.scroll_vertical = int(maxf(0.0, target_y - scroll.size.y * 0.82))


func describe(node_id: int) -> void:
	if info == null:
		return
	if node_id < 0:
		info.text = "다음 목적지를 고르세요." if not run.available_nodes().is_empty() else ""
		return
	var map_node := run.map.node(node_id)
	var state := "갈 수 있음" if node_id in canvas.reachable() else ("지나온 길" if node_id in run.visited else "지금은 갈 수 없음")
	info.text = "%d층 · %s  —  %s" % [map_node.floor + 1, RunMap.TYPE_NAMES[map_node.type], state] if map_node.type != RunMap.NodeType.BOSS else "보스 · 잿불 사제 모르간  —  %s" % state


func choose(node_id: int) -> void:
	if run.travel(node_id):
		AudioDirector.sfx("step")
		enter_current()


func enter_current() -> void:
	leave_to(SceneRouter.BATTLE if Encounters.is_combat(run.current_node()) else SceneRouter.NODE)


func leave_to(path: String) -> void:
	SceneRouter.go(get_tree(), path)
