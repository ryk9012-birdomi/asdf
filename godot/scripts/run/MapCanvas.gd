class_name MapCanvas
extends Control
## Draws the act map on parchment and reports clicks on reachable nodes.

signal node_chosen(node_id: int)
signal node_hovered(node_id: int)

const ROW := 88.0
const COLUMN := 128.0
const MARGIN := Vector2(104, 96)
const RADIUS := 22.0
const BOSS_RADIUS := 42.0
const INK := Color("201a14")
const FADED_INK := Color(0.13, 0.1, 0.07, 0.5)
const PARCHMENT := Color("b2a88e")
const ROUTE := Color("6e3026")

var run: RunState
var positions: Dictionary = {}
var hovered: int = -1
var time: float = 0.0


func setup(active_run: RunState) -> void:
	run = active_run
	custom_minimum_size = Vector2(MARGIN.x * 2 + COLUMN * (RunMap.COLUMNS - 1), MARGIN.y * 2 + ROW * RunMap.BOSS_FLOOR + 40)
	positions.clear()
	for map_node in run.map.nodes:
		# Small seeded jitter keeps the grid from looking like a spreadsheet.
		var wobble := Vector2(float(hash([run.seed_value, map_node.id]) % 21 - 10), float(hash([map_node.id, run.seed_value]) % 15 - 7))
		if map_node.type == RunMap.NodeType.BOSS:
			wobble = Vector2.ZERO
		positions[map_node.id] = Vector2(MARGIN.x + COLUMN * map_node.column, custom_minimum_size.y - MARGIN.y - ROW * map_node.floor) + wobble
	queue_redraw()


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func reachable() -> Array[int]:
	var ids: Array[int] = []
	for map_node in run.available_nodes():
		ids.append(map_node.id)
	return ids


func node_at(point: Vector2) -> int:
	for id in positions:
		var reach := BOSS_RADIUS if id == run.map.boss_id else RADIUS + 6.0
		if positions[id].distance_to(point) <= reach:
			return id
	return -1


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and hovered >= 0:
		hovered = -1
		node_hovered.emit(-1)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var id := node_at(event.position)
		if id != hovered:
			hovered = id
			node_hovered.emit(id)
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if id in reachable() else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id := node_at(event.position)
		if id in reachable():
			node_chosen.emit(id)
			accept_event()


func _draw() -> void:
	if run == null:
		return
	var travelled := {}
	for index in range(1, run.visited.size()):
		travelled[Vector2i(run.visited[index - 1], run.visited[index])] = true
	for map_node in run.map.nodes:
		for next_id in map_node.next:
			var from: Vector2 = positions[map_node.id]
			var to: Vector2 = positions[next_id]
			var gap := (BOSS_RADIUS if next_id == run.map.boss_id else RADIUS) + 6.0
			var direction := (to - from).normalized()
			var start := from + direction * (RADIUS + 6.0)
			var finish := to - direction * gap
			if travelled.has(Vector2i(map_node.id, next_id)):
				draw_line(start, finish, ROUTE, 4.0, true)
			else:
				draw_dashes(start, finish, INK if map_node.id == run.current_node_id or (run.current_node_id < 0 and map_node.floor == 0) else FADED_INK)
	var open := reachable()
	for map_node in run.map.nodes:
		draw_node(map_node, positions[map_node.id], map_node.id in open)


func draw_dashes(from: Vector2, to: Vector2, color: Color) -> void:
	var length := from.distance_to(to)
	var direction := (to - from) / maxf(length, 0.001)
	var offset := 0.0
	while offset < length:
		draw_line(from + direction * offset, from + direction * minf(offset + 7.0, length), color, 2.5, true)
		offset += 13.0


func draw_node(map_node: RunMap.MapNode, center: Vector2, open: bool) -> void:
	var boss := map_node.type == RunMap.NodeType.BOSS
	var radius := BOSS_RADIUS if boss else RADIUS
	var visited := map_node.id in run.visited
	var pulse := 0.5 + 0.5 * sin(time * 4.0)
	if open:
		var grow := 1.18 if map_node.id == hovered else 1.0
		radius *= grow
		draw_circle(center, radius + 9.0 + pulse * 4.0, Color(1.0, 0.72, 0.25, 0.18 + 0.12 * pulse))
		draw_arc(center, radius + 6.0 + pulse * 2.0, 0, TAU, 48, Color("a8825a"), 2.5, true)
	var ink := INK if open or visited or boss else FADED_INK
	draw_circle(center, radius, PARCHMENT if open else Color(0.6, 0.57, 0.49, 0.85))
	draw_arc(center, radius, 0, TAU, 48, ink, 2.5 if boss else 2.0, true)
	if boss:
		draw_arc(center, radius - 6.0, 0, TAU, 48, Color(ROUTE, 0.8), 1.5, true)
	draw_icon(map_node.type, center, radius * 0.62, ink)
	if visited:
		draw_arc(center, radius + 4.0, 0, TAU, 48, ROUTE, 3.0, true)
	if map_node.id == run.current_node_id:
		draw_colored_polygon(PackedVector2Array([center + Vector2(-8, -radius - 18), center + Vector2(8, -radius - 18), center + Vector2(0, -radius - 6)]), ROUTE)


func draw_icon(type: RunMap.NodeType, center: Vector2, size: float, ink: Color) -> void:
	match type:
		RunMap.NodeType.BATTLE:
			for side in [-1.0, 1.0]:
				var tip := center + Vector2(size * side, -size)
				var hilt := center + Vector2(-size * 0.7 * side, size * 0.7)
				draw_line(tip, hilt, ink, 3.0, true)
				var guard_dir := (tip - hilt).normalized().orthogonal() * size * 0.35
				var guard_at := hilt + (tip - hilt) * 0.18
				draw_line(guard_at - guard_dir, guard_at + guard_dir, ink, 3.0, true)
				draw_circle(hilt + (hilt - tip).normalized() * 3.0, 2.5, ink)
		RunMap.NodeType.ELITE:
			skull(center, size, ink)
			for side in [-1.0, 1.0]:
				draw_colored_polygon(PackedVector2Array([center + Vector2(side * size * 0.55, -size * 0.35), center + Vector2(side * size * 1.05, -size * 1.15), center + Vector2(side * size * 0.2, -size * 0.6)]), ink)
		RunMap.NodeType.REST:
			draw_line(center + Vector2(-size, size * 0.8), center + Vector2(size, size * 0.35), ink, 3.5, true)
			draw_line(center + Vector2(size, size * 0.8), center + Vector2(-size, size * 0.35), ink, 3.5, true)
			var flame := PackedVector2Array()
			for step in 17:
				var t := TAU * step / 16.0
				var r := size * (0.5 + 0.1 * sin(time * 9.0 + step))
				flame.append(center + Vector2(sin(t) * r * 0.75, -cos(t) * r - (size * 0.45 if cos(t) > 0.0 else 0.0) - size * 0.1))
			draw_colored_polygon(flame, Color("d8641c") if ink.a > 0.9 else Color(0.85, 0.4, 0.1, 0.45))
		RunMap.NodeType.EVENT:
			var font := get_theme_font("font", "HeadingLabel")
			var font_size := int(size * 2.1)
			var text_size := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			draw_string(font, center + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) - text_size.y / 2.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
		RunMap.NodeType.TREASURE:
			var body := Rect2(center + Vector2(-size, -size * 0.2), Vector2(size * 2.0, size * 1.1))
			draw_rect(body, ink, false, 2.5)
			draw_arc(center + Vector2(0, -size * 0.2), size, PI, TAU, 16, ink, 2.5, true)
			draw_rect(Rect2(center + Vector2(-size * 0.2, -size * 0.35), Vector2(size * 0.4, size * 0.45)), Color("9a7a3c") if ink.a > 0.9 else ink)
		RunMap.NodeType.BOSS:
			skull(center + Vector2(0, size * 0.1), size * 0.8, ink)
			for index in 5:
				var x := (index - 2) * size * 0.42
				draw_colored_polygon(PackedVector2Array([center + Vector2(x - size * 0.18, -size * 0.55), center + Vector2(x, -size * (1.15 + 0.15 * sin(time * 6.0 + index))), center + Vector2(x + size * 0.18, -size * 0.55)]), Color("b8321e"))


func skull(center: Vector2, size: float, ink: Color) -> void:
	draw_circle(center + Vector2(0, -size * 0.1), size * 0.62, ink)
	draw_rect(Rect2(center + Vector2(-size * 0.35, size * 0.3), Vector2(size * 0.7, size * 0.4)), ink)
	for side in [-1.0, 1.0]:
		draw_circle(center + Vector2(side * size * 0.24, -size * 0.1), size * 0.16, PARCHMENT)
