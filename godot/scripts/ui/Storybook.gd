class_name Storybook
extends RefCounted
## Paints the storybook landscape (sky, clouds, far mountains, a hilltop castle, forest,
## a small village and a flowered meadow) onto any CanvasItem, in soft watercolor tones.
## Shared by the menu backdrop and the battle field so every screen feels like one book.

const SKY_TOP := Color("a9cbe6")
const SKY_LOW := Color("f8ead0")
const MOUNTAIN := Color("a8a4c8")
const MOUNTAIN_FAR := Color("c4c2dc")
const HILL := Color("9dbb7a")
const FOREST := [Color("6e9152"), Color("5d8047"), Color("7fa35e")]
const PINE := Color("4f7247")
const WALL := Color("f1e4c8")
const ROOF := Color("c46e48")
const ROOF_DARK := Color("a55a3c")
const MEADOW_TOP := Color("b8cf86")
const MEADOW_LOW := Color("8fb064")
const PATH := Color("e3cfa4")
const INK := Color(0.35, 0.22, 0.12, 0.55)
## The dirt road's band, as fractions of the meadow's height.
const ROAD := Vector2(0.4, 0.98)

## Paper texture laid over a painting with a multiply blend: grain, soft blotches and
## darker edges, like watercolor on cold-press paper.
const PAPER_SHADER := """
shader_type canvas_item;
render_mode blend_mul;
uniform vec2 resolution = vec2(1280.0, 920.0);

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
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}
void fragment() {
	vec2 px = UV * resolution;
	float grain = hash(floor(px)) * 0.06 + fbm(px / 3.0) * 0.06;
	float blotch = fbm(px / 140.0) * 0.12;
	float edge = smoothstep(0.35, 0.85, distance(UV, vec2(0.5)));
	float shade = 1.0 - grain - blotch * 0.8 - edge * 0.16;
	COLOR = vec4(vec3(shade) * vec3(1.0, 0.985, 0.95), 1.0);
}
"""


## Paints the whole landscape into `rect`. `ground` is the fraction of the height where
## the meadow starts; `path` adds an open dirt road across the meadow for fighters.
static func paint(canvas: CanvasItem, rect: Rect2, ground: float = 0.68, path: bool = false, time: float = 0.0) -> void:
	var w := rect.size.x
	var h := rect.size.y
	var o := rect.position
	var horizon := h * ground
	# Sky in bands so the gradient looks brushed rather than perfectly smooth.
	for band in 24:
		var t := band / 23.0
		canvas.draw_rect(Rect2(o + Vector2(0, horizon * t), Vector2(w, horizon / 23.0 + 1.0)), SKY_TOP.lerp(SKY_LOW, pow(t, 1.3)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	# Clouds: clusters of soft cream puffs drifting very slowly.
	for cloud in 6:
		var cx := fposmod(rng.randf_range(0.0, 1.2) * w + time * (6.0 + cloud), w * 1.3) - w * 0.15
		var cy := rng.randf_range(0.08, 0.42) * horizon
		var scale := rng.randf_range(0.6, 1.3)
		for puff in 7:
			var offset := Vector2(rng.randf_range(-70, 70), rng.randf_range(-16, 14)) * scale
			blob(canvas, o + Vector2(cx, cy) + offset, Vector2(rng.randf_range(34, 60), rng.randf_range(20, 32)) * scale, Color(1.0, 0.98, 0.93, 0.55))
	# Far mountains, pale and lavender, with snowy caps.
	ridge(canvas, o, w, horizon * 0.62, horizon * 0.3, MOUNTAIN_FAR, 3, 0.7)
	ridge(canvas, o, w, horizon * 0.72, horizon * 0.34, MOUNTAIN, 5, 1.9)
	# The castle on its hill, right of centre.
	var hill_x := w * 0.74
	var hill_top := horizon * 0.6
	var hill := PackedVector2Array()
	for step in 25:
		var t := step / 24.0
		hill.append(o + Vector2(hill_x + (t - 0.5) * w * 0.46, hill_top + (1.0 - sin(t * PI)) * horizon * 0.36))
	hill.append(o + Vector2(hill_x + w * 0.23, horizon))
	hill.append(o + Vector2(hill_x - w * 0.23, horizon))
	canvas.draw_colored_polygon(hill, HILL.lerp(MOUNTAIN, 0.25))
	castle(canvas, o + Vector2(hill_x, hill_top + 4.0), clampf(h / 1400.0, 0.3, 0.62))
	# Rolling forest line and pines.
	var forest_y := horizon * 0.86
	for tree in 34:
		var tx := rng.randf_range(-0.05, 1.05) * w
		var size := rng.randf_range(26.0, 52.0) * (h / 900.0 + 0.4)
		if rng.randf() < 0.35:
			pine(canvas, o + Vector2(tx, forest_y + rng.randf_range(-6, 16)), size * 1.3)
		else:
			canopy(canvas, o + Vector2(tx, forest_y + rng.randf_range(-4, 14)), size, FOREST[rng.randi_range(0, 2)])
	# A few village cottages at the forest edge, left of centre.
	for house in 4:
		cottage(canvas, o + Vector2(w * (0.1 + house * 0.08) + rng.randf_range(-10, 10), horizon * 0.96), rng.randf_range(0.8, 1.1) * (h / 900.0 + 0.3))
	# Meadow.
	for band in 12:
		var t := band / 11.0
		canvas.draw_rect(Rect2(o + Vector2(0, horizon + (h - horizon) * t), Vector2(w, (h - horizon) / 11.0 + 1.0)), MEADOW_TOP.lerp(MEADOW_LOW, t))
	if path:
		var road := PackedVector2Array()
		var top := horizon + (h - horizon) * ROAD.x
		var bottom := horizon + (h - horizon) * ROAD.y
		for step in 21:
			road.append(o + Vector2(w * step / 20.0, top + sin(step * 0.7) * 5.0))
		for step in range(20, -1, -1):
			road.append(o + Vector2(w * step / 20.0, bottom + sin(step * 0.9 + 1.0) * 6.0))
		canvas.draw_colored_polygon(road, PATH)
		for stone in 26:
			var sp := o + Vector2(rng.randf() * w, rng.randf_range(top + 8, bottom - 8))
			blob(canvas, sp, Vector2(rng.randf_range(10, 22), rng.randf_range(5, 9)), Color("d6bf92").lerp(Color("c9ae80"), rng.randf()))
	# Grass tufts and wildflowers.
	for tuft in 90:
		var gp := o + Vector2(rng.randf() * w, rng.randf_range(horizon + 6, h))
		if path and gp.y > horizon + (h - horizon) * (ROAD.x - 0.03):
			continue
		for blade in 3:
			canvas.draw_line(gp, gp + Vector2(rng.randf_range(-6, 6), -rng.randf_range(8, 16)), Color("6f9448"), 1.6, true)
	var petals := [Color("fffaf0"), Color("f6b8c4"), Color("ffd66e"), Color("b9a4e0")]
	for flower in 70:
		var fp := o + Vector2(rng.randf() * w, rng.randf_range(horizon + 10, h - 4))
		if path and fp.y > horizon + (h - horizon) * (ROAD.x - 0.03):
			continue
		var tint: Color = petals[rng.randi_range(0, 3)]
		for petal in 5:
			var angle := TAU * petal / 5.0
			canvas.draw_circle(fp + Vector2(cos(angle), sin(angle)) * 3.2, 2.6, tint)
		canvas.draw_circle(fp, 1.8, Color("e8a93a"))


static func blob(canvas: CanvasItem, center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 20:
		var angle := TAU * index / 20.0
		var wobble := 1.0 + 0.08 * sin(angle * 3.0 + center.x * 0.05)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * wobble)
	canvas.draw_colored_polygon(points, color)


static func ridge(canvas: CanvasItem, o: Vector2, w: float, base: float, rise: float, color: Color, peaks: int, seed_shift: float) -> void:
	var points := PackedVector2Array([o + Vector2(0, base + rise)])
	var snow := []
	for step in 41:
		var t := step / 40.0
		var height := 0.5 + 0.5 * sin(t * PI * peaks + seed_shift) * (0.7 + 0.3 * sin(t * 17.0 + seed_shift))
		var point := o + Vector2(t * w, base + rise - height * rise * 1.6)
		points.append(point)
		if height > 0.85:
			snow.append(point)
	points.append(o + Vector2(w, base + rise))
	canvas.draw_colored_polygon(points, color)
	for cap in snow:
		canvas.draw_colored_polygon(PackedVector2Array([cap, cap + Vector2(-14, 12), cap + Vector2(14, 12)]), Color(1, 1, 1, 0.55))


static func canopy(canvas: CanvasItem, base: Vector2, size: float, color: Color) -> void:
	canvas.draw_rect(Rect2(base + Vector2(-size * 0.08, -size * 0.2), Vector2(size * 0.16, size * 0.4)), Color("7a5a3a"))
	blob(canvas, base + Vector2(0, -size * 0.55), Vector2(size * 0.62, size * 0.5), color)
	blob(canvas, base + Vector2(-size * 0.28, -size * 0.35), Vector2(size * 0.4, size * 0.32), color.darkened(0.08))
	blob(canvas, base + Vector2(size * 0.18, -size * 0.8), Vector2(size * 0.3, size * 0.24), color.lightened(0.12))


static func pine(canvas: CanvasItem, base: Vector2, size: float) -> void:
	for tier in 3:
		var y := base.y - size * (0.25 + tier * 0.28)
		var half := size * (0.36 - tier * 0.08)
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(base.x - half, y + size * 0.3), Vector2(base.x + half, y + size * 0.3), Vector2(base.x, y - size * 0.1)]), PINE.lightened(tier * 0.05))


static func cottage(canvas: CanvasItem, base: Vector2, scale: float) -> void:
	var w := 34.0 * scale
	var h := 22.0 * scale
	canvas.draw_rect(Rect2(base + Vector2(-w / 2, -h), Vector2(w, h)), WALL)
	canvas.draw_colored_polygon(PackedVector2Array([base + Vector2(-w * 0.62, -h), base + Vector2(w * 0.62, -h), base + Vector2(0, -h - 18 * scale)]), ROOF)
	canvas.draw_rect(Rect2(base + Vector2(-4 * scale, -10 * scale), Vector2(8 * scale, 10 * scale)), Color("8a5a38"))
	canvas.draw_rect(Rect2(base + Vector2(w * 0.22, -h * 0.75), Vector2(6 * scale, 6 * scale)), Color("f6d27a"))
	canvas.draw_rect(Rect2(base + Vector2(w * 0.18, -h - 16 * scale), Vector2(5 * scale, 10 * scale)), Color("9a8a78"))


static func castle(canvas: CanvasItem, base: Vector2, scale: float) -> void:
	var s := scale * 1.6
	canvas.draw_rect(Rect2(base + Vector2(-60, -34) * s, Vector2(120, 34) * s), WALL)
	for x in [-60.0, -20.0, 20.0, 60.0]:
		var tall := 56.0 if absf(x) < 30.0 else 44.0
		canvas.draw_rect(Rect2(base + Vector2(x - 9, -tall) * s, Vector2(18, tall) * s), WALL.darkened(0.04))
		canvas.draw_colored_polygon(PackedVector2Array([base + Vector2(x - 12, -tall) * s, base + Vector2(x + 12, -tall) * s, base + Vector2(x, -tall - 26) * s]), ROOF if absf(x) > 30.0 else ROOF_DARK)
		canvas.draw_rect(Rect2(base + Vector2(x - 2, -tall + 14) * s, Vector2(4, 7) * s), Color("6a5a78"))
	canvas.draw_rect(Rect2(base + Vector2(-2, -96) * s, Vector2(4, 30) * s), WALL)
	canvas.draw_colored_polygon(PackedVector2Array([base + Vector2(-6, -94) * s, base + Vector2(6, -94) * s, base + Vector2(0, -116) * s]), ROOF_DARK)
	canvas.draw_line(base + Vector2(0, -116) * s, base + Vector2(0, -126) * s, Color("7a5a3a"), 1.2)
	canvas.draw_colored_polygon(PackedVector2Array([base + Vector2(0, -126) * s, base + Vector2(9, -123) * s, base + Vector2(0, -120) * s]), Color("d0503a"))
	canvas.draw_rect(Rect2(base + Vector2(-8, -18) * s, Vector2(16, 18) * s), Color("8a6a4a"))


## Paper grain overlay for a painted area.
static func paper(size: Vector2) -> ColorRect:
	var sheet := ColorRect.new()
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = PAPER_SHADER
	material.set_shader_parameter("resolution", size)
	sheet.material = material
	return sheet
