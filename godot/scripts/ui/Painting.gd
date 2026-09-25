class_name Painting
extends RefCounted
## The Art Bible's world (docs/ART_BIBLE.md), painted with draw calls: a heavy overcast
## sky, a ruined fort in the mist, grey-green woods with dead trees, a village of broken
## timber houses and crooked fences, and a muddy road. Everything is low in saturation;
## distance pushes shapes toward blue-grey. `brush()` returns an overlay that smears the
## painting under it into visible strokes and darkens the corners.

const SKY_TOP := Color("737c81")
const SKY_LOW := Color("bfc1b8")
const CLOUD := Color("5a6266")
const CLOUD_LIGHT := Color("d2d3cb")
const RIDGE_FAR := Color("8c959a")
const RIDGE := Color("6f797b")
const FOREST := [Color("4a564b"), Color("53604f"), Color("414d43")]
const DEAD := Color("3a3430")
const WOOD := Color("54483d")
const WOOD_LIGHT := Color("7a6a57")
const ROOF := Color("514740")
const HOLE := Color("2a2622")
const STONE := Color("7a7c76")
const GROUND_TOP := Color("5b5947")
const GROUND_LOW := Color("37332b")
const MUD := Color("6c6351")
const RUT := Color("4a4338")
const DRY_GRASS := Color("857752")
const FOG := Color("c6c9c3")
const RUST := Color("8a5a3c")
## The muddy road's band, as fractions of the ground's height.
const ROAD := Vector2(0.4, 0.98)

## Smears what was drawn beneath it along a slowly turning stroke field, blots the
## value, adds canvas tooth and pulls the corners into shadow.
const BRUSH_SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float vignette = 0.5;

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
	vec2 px = FRAGCOORD.xy;
	float angle = (noise(px / 90.0) * 0.7 + noise(px / 23.0) * 0.3) * 6.2832 * 1.3;
	vec2 axis = vec2(cos(angle), sin(angle));
	vec2 step = axis * SCREEN_PIXEL_SIZE * 2.4;
	vec3 sum = vec3(0.0);
	for (int i = -4; i <= 4; i++) {
		sum += texture(screen, SCREEN_UV + step * float(i)).rgb;
	}
	vec3 col = sum / 9.0;
	// Loose paint: broad blotches of more and less pigment, and short dabs.
	float blot = noise(px / 70.0) * 0.6 + noise(px / 16.0) * 0.4;
	col *= 0.93 + blot * 0.12;
	col *= 0.97 + hash(floor(px / 2.0)) * 0.05;
	float corner = smoothstep(0.32, 0.85, distance(UV, vec2(0.5)));
	col *= 1.0 - corner * vignette;
	COLOR = vec4(col, 1.0);
}
"""


## Paints the whole scene into `rect`. `ground` is the fraction of the height where the
## land starts; `path` adds the muddy road the fighters stand on.
static func paint(canvas: CanvasItem, rect: Rect2, ground: float = 0.64, path: bool = false, time: float = 0.0) -> void:
	var w := rect.size.x
	var h := rect.size.y
	var o := rect.position
	var horizon := h * ground
	var scale := clampf(h / 900.0, 0.45, 1.3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Overcast sky, brushed in bands, with heavy cloud masses drifting very slowly.
	for band in 30:
		var t := band / 29.0
		canvas.draw_rect(Rect2(o + Vector2(0, horizon * t), Vector2(w, horizon / 29.0 + 1.0)), SKY_TOP.lerp(SKY_LOW, pow(t, 1.5)))
	for cloud in 10:
		var cx := fposmod(rng.randf() * w * 1.4 + time * (2.0 + cloud * 0.5), w * 1.4) - w * 0.2
		var cy := rng.randf_range(0.0, 0.45) * horizon
		var size := rng.randf_range(0.7, 1.5) * scale
		for puff in 8:
			var at := o + Vector2(cx, cy) + Vector2(rng.randf_range(-110, 110), rng.randf_range(-18, 18)) * size
			blob(canvas, at, Vector2(rng.randf_range(50, 90), rng.randf_range(18, 32)) * size, Color(CLOUD, rng.randf_range(0.12, 0.26)))
			blob(canvas, at + Vector2(0, -10) * size, Vector2(rng.randf_range(30, 60), rng.randf_range(8, 14)) * size, Color(CLOUD_LIGHT, 0.12))
	# Far ridge with the broken fort, nearly lost in the haze.
	ridge(canvas, o, w, horizon * 0.66, horizon * 0.24, RIDGE_FAR, 5, 0.4)
	fort(canvas, o + Vector2(w * 0.72, horizon * 0.62), scale, RIDGE_FAR.lerp(STONE, 0.35))
	mist(canvas, o, w, horizon * 0.72, 46.0 * scale, 0.35, time, 1)
	ridge(canvas, o, w, horizon * 0.82, horizon * 0.2, RIDGE, 7, 2.3)
	mist(canvas, o, w, horizon * 0.84, 36.0 * scale, 0.3, time, 2)
	# Woods: grey-green crowns with dead trees standing among them.
	var wood_y := horizon * 0.95
	for tree in 46:
		var tx := rng.randf_range(-0.05, 1.05) * w
		var size := rng.randf_range(24.0, 48.0) * scale
		if rng.randf() < 0.28:
			dead_tree(canvas, o + Vector2(tx, wood_y + rng.randf_range(0, 12)), size * 2.0, rng)
		else:
			canopy(canvas, o + Vector2(tx, wood_y + rng.randf_range(-4, 12)), size, FOREST[rng.randi_range(0, 2)], rng)
	# The abandoned village at the wood's edge: broken houses, a cart, crooked fences.
	var village := [[0.07, 1.25, true], [0.2, 1.05, false], [0.33, 1.15, true], [0.87, 1.3, true]]
	for spot in village:
		house(canvas, o + Vector2(w * spot[0], horizon * 1.0), scale * spot[1], spot[2], rng)
	fence(canvas, o + Vector2(w * 0.38, horizon * 1.03), 7, scale, rng)
	fence(canvas, o + Vector2(w * 0.62, horizon * 1.02), 6, scale, rng)
	cart(canvas, o + Vector2(w * 0.5, horizon * 1.02), scale * 0.9)
	mist(canvas, o, w, horizon * 1.0, 24.0 * scale, 0.28, time, 3)
	# Wet ground, darker toward the viewer, laid in with short strokes.
	for band in 14:
		var t := band / 13.0
		canvas.draw_rect(Rect2(o + Vector2(0, horizon + (h - horizon) * t), Vector2(w, (h - horizon) / 13.0 + 1.0)), GROUND_TOP.lerp(GROUND_LOW, t))
	for mark in 220:
		var at := o + Vector2(rng.randf() * w, rng.randf_range(horizon + 4, h))
		var tint := GROUND_TOP.lerp(MUD, rng.randf()).lerp(DRY_GRASS, rng.randf() * 0.4)
		stroke(canvas, at, at + Vector2(rng.randf_range(14, 40) * scale, rng.randf_range(-3, 3)), rng.randf_range(3, 7) * scale, Color(tint, 0.5))
	if path:
		var top := horizon + (h - horizon) * ROAD.x
		var bottom := horizon + (h - horizon) * ROAD.y
		var road := PackedVector2Array()
		for step in 25:
			road.append(o + Vector2(w * step / 24.0, top + sin(step * 0.8) * 6.0))
		for step in range(24, -1, -1):
			road.append(o + Vector2(w * step / 24.0, bottom + sin(step * 0.9 + 1.0) * 7.0))
		canvas.draw_colored_polygon(road, MUD)
		# Ruts, clods of mud and puddles that catch the grey sky.
		for rut in 3:
			var y := lerpf(top, bottom, 0.3 + rut * 0.22)
			for seg in 18:
				var x := w * seg / 18.0
				stroke(canvas, o + Vector2(x, y + sin(seg * 1.3 + rut) * 3.0), o + Vector2(x + w / 18.0, y + sin(seg * 1.3 + rut + 1.3) * 3.0), 3.0 * scale, Color(RUT, 0.55))
		for clod in 60:
			var at := o + Vector2(rng.randf() * w, rng.randf_range(top + 6, bottom - 6))
			stroke(canvas, at, at + Vector2(rng.randf_range(8, 22) * scale, 0), rng.randf_range(2, 5) * scale, Color(MUD.lerp(RUT, rng.randf()), 0.6))
		for puddle in 7:
			var at := o + Vector2(rng.randf_range(0.05, 0.95) * w, rng.randf_range(top + 14, bottom - 14))
			blob(canvas, at, Vector2(rng.randf_range(30, 70), rng.randf_range(6, 11)) * scale, Color(SKY_LOW.darkened(0.12), 0.55))
			stroke(canvas, at + Vector2(-18, -2) * scale, at + Vector2(10, -2) * scale, 1.5, Color(FOG, 0.35))
	# Dead grass: dry tufts, thicker off the road.
	for tuft in 110:
		var at := o + Vector2(rng.randf() * w, rng.randf_range(horizon + 6, h))
		if path and at.y > horizon + (h - horizon) * (ROAD.x - 0.02) and at.y < horizon + (h - horizon) * ROAD.y:
			continue
		for blade in 4:
			var tip := at + Vector2(rng.randf_range(-7, 7), -rng.randf_range(8, 20)) * scale
			canvas.draw_line(at, tip, DRY_GRASS.lerp(GROUND_LOW, rng.randf() * 0.5), 1.6 * scale, true)
	# Dark, rough foreground brush in the lower corners frames the scene.
	for side in [0.0, 1.0]:
		for leaf in 26:
			var at := o + Vector2(w * side + (rng.randf() * 0.18 * w) * (1.0 - 2.0 * side), h - rng.randf_range(0, 60) * scale)
			stroke(canvas, at, at + Vector2(rng.randf_range(-20, 20), -rng.randf_range(30, 80)) * scale, rng.randf_range(4, 9) * scale, Color(Color("22241f"), 0.55))


## A soft irregular patch of paint.
static func blob(canvas: CanvasItem, center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for step in 14:
		var angle := TAU * step / 14.0
		var wobble := 0.82 + 0.18 * sin(angle * 3.0 + center.x * 0.13) * cos(angle * 2.0 + center.y * 0.07)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * wobble)
	canvas.draw_colored_polygon(points, color)


## One brush stroke: a thick line with round ends.
static func stroke(canvas: CanvasItem, from: Vector2, to: Vector2, width: float, color: Color) -> void:
	canvas.draw_line(from, to, color, width, true)
	canvas.draw_circle(from, width * 0.5, color)
	canvas.draw_circle(to, width * 0.5, color)


static func ridge(canvas: CanvasItem, o: Vector2, w: float, base: float, rise: float, color: Color, bumps: int, shift: float) -> void:
	var line := PackedVector2Array()
	for step in 49:
		var t := step / 48.0
		var lift := sin(t * PI * bumps * 0.5 + shift) * 0.5 + 0.5
		lift = lift * 0.7 + sin(t * 37.0 + shift * 3.0) * 0.06 + 0.2
		line.append(o + Vector2(w * t, base - rise * lift))
	line.append(o + Vector2(w, base + rise))
	line.append(o + Vector2(0, base + rise))
	canvas.draw_colored_polygon(line, color)


## Horizontal banks of mist drifting at `y`.
static func mist(canvas: CanvasItem, o: Vector2, w: float, y: float, thickness: float, alpha: float, time: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90 + seed
	for bank in 9:
		var x := fposmod(rng.randf() * w * 1.3 + time * (5.0 + bank), w * 1.3) - w * 0.15
		var at := o + Vector2(x, y + rng.randf_range(-0.6, 0.6) * thickness)
		blob(canvas, at, Vector2(rng.randf_range(140, 260), thickness * rng.randf_range(0.5, 1.0)), Color(FOG, alpha * rng.randf_range(0.5, 1.0)))


static func canopy(canvas: CanvasItem, base: Vector2, size: float, color: Color, rng: RandomNumberGenerator) -> void:
	stroke(canvas, base, base + Vector2(0, -size * 0.8), size * 0.12, DEAD)
	for clump in 5:
		var at := base + Vector2(rng.randf_range(-0.5, 0.5) * size, -size * rng.randf_range(0.8, 1.6))
		blob(canvas, at, Vector2(size * rng.randf_range(0.4, 0.62), size * rng.randf_range(0.34, 0.5)), color.lerp(RIDGE, rng.randf() * 0.25))


## A leafless tree: a leaning trunk that forks into bare branches.
static func dead_tree(canvas: CanvasItem, base: Vector2, height: float, rng: RandomNumberGenerator) -> void:
	var lean := rng.randf_range(-0.12, 0.12)
	var top := base + Vector2(lean * height, -height)
	stroke(canvas, base, top, height * 0.05, DEAD)
	for branch in 5:
		var from := base.lerp(top, rng.randf_range(0.45, 0.95))
		var side := -1.0 if branch % 2 == 0 else 1.0
		var tip := from + Vector2(side * rng.randf_range(0.15, 0.32), -rng.randf_range(0.08, 0.24)) * height
		stroke(canvas, from, tip, height * 0.018, DEAD)
		stroke(canvas, tip, tip + Vector2(side * 0.06, -0.08) * height, height * 0.01, DEAD)


## A timber house, leaning a little; `broken` caves in part of the roof.
static func house(canvas: CanvasItem, base: Vector2, s: float, broken: bool, rng: RandomNumberGenerator) -> void:
	var sag := rng.randf_range(-6.0, 6.0) * s
	var wall := PackedVector2Array([base + Vector2(-46, 0) * s, base + Vector2(46, 0) * s, base + Vector2(46 * s + sag, -54 * s), base + Vector2(-46 * s + sag, -52 * s)])
	canvas.draw_colored_polygon(wall, WOOD)
	for plank in 8:
		var x := -40.0 + plank * 11.0
		stroke(canvas, base + Vector2(x, -2) * s, base + Vector2(x * s + sag * 0.9, -50 * s), 1.4 * s, Color(WOOD_LIGHT, 0.45))
	canvas.draw_rect(Rect2(base + Vector2(-10 * s + sag * 0.5, -40 * s), Vector2(16, 18) * s), HOLE)
	stroke(canvas, base + Vector2(-12 * s + sag * 0.5, -31 * s), base + Vector2(8 * s + sag * 0.5, -29 * s), 2.0 * s, WOOD_LIGHT)
	var peak := base + Vector2(sag + 4 * s, -92 * s)
	var roof := PackedVector2Array([base + Vector2(-58 * s + sag, -48 * s), peak, base + Vector2(58 * s + sag, -50 * s)])
	canvas.draw_colored_polygon(roof, ROOF)
	if broken:
		# Collapsed section: dark rafters showing through a hole in the thatch.
		var hole := PackedVector2Array([peak + Vector2(6, 6) * s, peak + Vector2(34, 30) * s, peak + Vector2(16, 36) * s, peak + Vector2(2, 20) * s])
		canvas.draw_colored_polygon(hole, HOLE)
		for rafter in 3:
			stroke(canvas, peak + Vector2(4 + rafter * 9, 8 + rafter * 4) * s, peak + Vector2(14 + rafter * 9, 34) * s, 1.6 * s, WOOD_LIGHT)
	stroke(canvas, base + Vector2(-58 * s + sag, -48 * s), peak, 2.4 * s, Color(HOLE, 0.7))
	stroke(canvas, peak, base + Vector2(58 * s + sag, -50 * s), 2.4 * s, Color(HOLE, 0.7))


static func fence(canvas: CanvasItem, start: Vector2, posts: int, s: float, rng: RandomNumberGenerator) -> void:
	var previous := Vector2.ZERO
	for post in posts:
		var foot := start + Vector2(post * 22.0 * s, rng.randf_range(-2, 2) * s)
		var tip := foot + Vector2(rng.randf_range(-6, 6), -rng.randf_range(20, 28)) * s
		stroke(canvas, foot, tip, 3.0 * s, WOOD)
		if post > 0 and rng.randf() > 0.25:
			stroke(canvas, previous, foot.lerp(tip, 0.6), 2.2 * s, WOOD_LIGHT.darkened(0.2))
		previous = foot.lerp(tip, 0.6)


## An abandoned cart with one wheel off.
static func cart(canvas: CanvasItem, base: Vector2, s: float) -> void:
	var bed := PackedVector2Array([base + Vector2(-36, -22) * s, base + Vector2(30, -30) * s, base + Vector2(32, -18) * s, base + Vector2(-34, -10) * s])
	canvas.draw_colored_polygon(bed, WOOD)
	stroke(canvas, base + Vector2(30, -24) * s, base + Vector2(62, -8) * s, 2.4 * s, WOOD)
	canvas.draw_arc(base + Vector2(-16, -10) * s, 12.0 * s, 0.0, TAU, 20, WOOD_LIGHT.darkened(0.25), 2.6 * s, true)
	canvas.draw_arc(base + Vector2(48, -2) * s, 12.0 * s, 0.3, TAU - 0.3, 20, WOOD_LIGHT.darkened(0.3), 2.4 * s, true)


## A ruined hill fort: broken wall runs and one shattered tower with a faded banner.
static func fort(canvas: CanvasItem, base: Vector2, s: float, color: Color) -> void:
	var runs := [[-120, -40, 34], [-30, 40, 42], [56, 120, 30]]
	for run in runs:
		var top := PackedVector2Array()
		var steps := 8
		for step in steps + 1:
			var x := lerpf(run[0], run[1], float(step) / steps)
			top.append(base + Vector2(x, -run[2] + (8.0 if step % 3 == 1 else 0.0) + sin(x) * 3.0) * s)
		top.append(base + Vector2(run[1], 10) * s)
		top.append(base + Vector2(run[0], 10) * s)
		canvas.draw_colored_polygon(top, color)
	var tower := PackedVector2Array([base + Vector2(-16, 10) * s, base + Vector2(16, 10) * s, base + Vector2(14, -92) * s,
		base + Vector2(6, -84) * s, base + Vector2(0, -100) * s, base + Vector2(-8, -88) * s, base + Vector2(-15, -96) * s])
	canvas.draw_colored_polygon(tower, color.darkened(0.08))
	canvas.draw_rect(Rect2(base + Vector2(-3, -70) * s, Vector2(6, 12) * s), color.darkened(0.3))
	stroke(canvas, base + Vector2(0, -100) * s, base + Vector2(0, -128) * s, 1.4 * s, color.darkened(0.35))
	canvas.draw_colored_polygon(PackedVector2Array([base + Vector2(0, -128) * s, base + Vector2(20, -123) * s, base + Vector2(14, -118) * s, base + Vector2(0, -116) * s]), RUST.lerp(color, 0.45))


## The brush overlay: add it above a painting (and below anything that must stay crisp).
static func brush(vignette: float = 0.5) -> ColorRect:
	var sheet := ColorRect.new()
	sheet.name = "Brush"
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = BRUSH_SHADER
	material.set_shader_parameter("vignette", vignette)
	sheet.material = material
	return sheet
