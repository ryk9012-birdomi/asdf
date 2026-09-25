class_name FighterArt
extends RefCounted
## Hand-drawn side-view characters. Coordinates are around the feet (0, 0), y up is
## negative, facing right; the caller mirrors the canvas for enemies.

const KINDS := [&"paladin", &"rogue", &"wizard", &"goblin_raider", &"goblin_archer", &"hobgoblin_captain", &"ember_priest"]
const INK := Color("1a0f08")
const HEIGHTS := {&"paladin": 156.0, &"rogue": 152.0, &"wizard": 186.0, &"goblin_raider": 126.0, &"goblin_archer": 124.0, &"hobgoblin_captain": 172.0, &"ember_priest": 196.0, &"skeleton_warrior": 158.0, &"cult_zealot": 152.0, &"cult_hexer": 160.0, &"orc_berserker": 180.0}

var canvas: CanvasItem
var breathe: float
var arm: float
var glow: float
var time: float


static func height_of(kind: StringName) -> float:
	return HEIGHTS.get(kind, 140.0)


func _init(target: CanvasItem, breath: float, arm_angle: float, glow_amount: float, clock: float) -> void:
	canvas = target
	breathe = breath
	arm = arm_angle
	glow = glow_amount
	time = clock


func draw(kind: StringName) -> void:
	match kind:
		&"paladin":
			paladin()
		&"rogue":
			rogue()
		&"wizard":
			wizard()
		&"goblin_archer":
			goblin(true)
		&"hobgoblin_captain":
			captain()
		&"ember_priest":
			priest()
		_:
			goblin(false)


# --- primitives -----------------------------------------------------------------

func poly(points: PackedVector2Array, fill: Color, outline: float = 2.0) -> void:
	canvas.draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	closed.append(points[0])
	canvas.draw_polyline(closed, INK, outline, true)


func disc(center: Vector2, radius: float, fill: Color) -> void:
	canvas.draw_circle(center, radius + 1.8, INK)
	canvas.draw_circle(center, radius, fill)


func limb(from: Vector2, to: Vector2, width: float, fill: Color) -> void:
	canvas.draw_line(from, to, INK, width + 3.5, true)
	canvas.draw_circle(from, (width + 3.5) / 2.0, INK)
	canvas.draw_circle(to, (width + 3.5) / 2.0, INK)
	canvas.draw_line(from, to, fill, width, true)
	canvas.draw_circle(from, width / 2.0, fill)
	canvas.draw_circle(to, width / 2.0, fill)


func glow_disc(center: Vector2, radius: float, color: Color) -> void:
	for step in 5:
		canvas.draw_circle(center, radius * (1.0 + step * 0.45), Color(color, 0.16 - step * 0.028))
	canvas.draw_circle(center, radius, color)


## Rest points the arm forward and down; negative `arm` raises it, positive swings it back.
func arm_dir(offset: float = 0.0) -> Vector2:
	return Vector2.from_angle(PI / 2.0 - 0.6 + arm + offset)


func shifted(points: Array, origin: Vector2, scale_by: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(origin + point * scale_by)
	return result


func legs(s: float, hip: float, color: Color, boots: Color, stride: float = 1.0) -> void:
	var back_foot := Vector2(-10 * stride, -6) * s
	var front_foot := Vector2(11 * stride, -6) * s
	limb(Vector2(-5, hip) * s, back_foot, 9 * s, color.darkened(0.2))
	limb(Vector2(6, hip) * s, front_foot, 9 * s, color)
	poly(shifted([Vector2(-6, -4), Vector2(6, -4), Vector2(10, 6), Vector2(-7, 6)], back_foot, s), boots.darkened(0.15))
	poly(shifted([Vector2(-6, -4), Vector2(6, -4), Vector2(10, 6), Vector2(-7, 6)], front_foot, s), boots)


func sword(hand: Vector2, direction: Vector2, length: float, blade: Color, guard: Color, shine: float) -> void:
	var tip := hand + direction * length
	var side := direction.orthogonal()
	if shine > 0.0:
		canvas.draw_line(hand, tip, Color(1.0, 0.85, 0.4, 0.35 * shine), 16.0, true)
	poly(PackedVector2Array([hand + side * 3.5, tip + side * 1.0, tip + direction * 8.0, tip - side * 1.0, hand - side * 3.5]), blade)
	canvas.draw_line(hand + direction * 4.0, tip, blade.lightened(0.45), 1.5, true)
	limb(hand - side * 9.0, hand + side * 9.0, 4.0, guard)
	disc(hand - direction * 7.0, 3.5, guard)


# --- heroes -----------------------------------------------------------------------

func paladin() -> void:
	var s := 1.0
	var b := breathe
	var steel := Color("c9ced6")
	var gold := Color("e0b24a")
	var sway := sin(time * 1.7) * 3.0
	poly(PackedVector2Array([Vector2(-8, -106 + b), Vector2(-2, -100 + b), Vector2(-22 + sway, -10), Vector2(-36 + sway, -14)]), Color("2f4f9e"))
	legs(s, -58, Color("9aa3ad"), Color("4b4f58"))
	poly(PackedVector2Array([Vector2(-15, -56), Vector2(15, -56), Vector2(17, -104 + b), Vector2(-14, -106 + b)]), steel)
	poly(PackedVector2Array([Vector2(-9, -44), Vector2(10, -44), Vector2(11, -98 + b), Vector2(-8, -99 + b)]), Color("f1ead8"))
	canvas.draw_circle(Vector2(1, -76 + b * 0.5), 6.0, gold)
	for ray in 8:
		var angle := TAU * ray / 8.0
		canvas.draw_line(Vector2(1, -76 + b * 0.5) + Vector2.from_angle(angle) * 7.0, Vector2(1, -76 + b * 0.5) + Vector2.from_angle(angle) * 10.0, gold, 1.5)
	canvas.draw_rect(Rect2(Vector2(-15, -60), Vector2(31, 5)), gold)
	# Kite shield on the far arm, carried in front of the body.
	limb(Vector2(-4, -98 + b), Vector2(12, -74 + b), 8, steel.darkened(0.1))
	var shield := Vector2(16, -72 + b)
	poly(shifted([Vector2(-13, -22), Vector2(13, -22), Vector2(13, 4), Vector2(0, 27), Vector2(-13, 4)], shield, 1.0), Color("f1ead8"), 2.5)
	canvas.draw_polyline(shifted([Vector2(-10, -19), Vector2(10, -19), Vector2(10, 3), Vector2(0, 22), Vector2(-10, 3), Vector2(-10, -19)], shield, 1.0), gold, 2.0, true)
	canvas.draw_line(shield + Vector2(0, -16), shield + Vector2(0, 16), Color("2f4f9e"), 4.0)
	canvas.draw_line(shield + Vector2(-8, -6), shield + Vector2(8, -6), Color("2f4f9e"), 4.0)
	# Great helm with a plume.
	var head := Vector2(3, -122 + b)
	poly(shifted([Vector2(-16, -14), Vector2(8, -18), Vector2(15, -8), Vector2(15, 12), Vector2(-15, 13)], head, 1.0), steel)
	canvas.draw_rect(Rect2(head + Vector2(3, -3), Vector2(12, 4)), Color("20242b"))
	canvas.draw_line(head + Vector2(9, -16), head + Vector2(9, 12), gold, 2.0)
	poly(PackedVector2Array([head + Vector2(-4, -16), head + Vector2(2, -26), head + Vector2(-20 + sway * 0.5, -30), head + Vector2(-26 + sway * 0.5, -18)]), Color("c33b2e"))
	var shoulder := Vector2(6, -100 + b)
	var hand := shoulder + arm_dir() * 30.0
	limb(shoulder, hand, 9, steel)
	disc(hand, 5.0, Color("9aa3ad"))
	sword(hand, arm_dir(-1.25), 56.0, Color("dfe4ea"), gold, glow)


func rogue() -> void:
	var s := 0.95
	var b := breathe
	var cloak := Color("3d2b57")
	var sway := sin(time * 1.9) * 3.0
	poly(PackedVector2Array([Vector2(-6, -100 + b), Vector2(4, -96 + b), Vector2(-18 + sway, -8), Vector2(-40 + sway, -12)]), cloak.darkened(0.2))
	legs(s, -56, Color("2b2330"), Color("5b3a22"), 1.3)
	poly(PackedVector2Array([Vector2(-13, -54), Vector2(13, -54), Vector2(15, -98 + b), Vector2(-12, -100 + b)]), Color("5b4331"))
	canvas.draw_rect(Rect2(Vector2(-13, -60), Vector2(28, 5)), Color("2b1d12"))
	disc(Vector2(10, -56), 4.0, Color("8a6a40"))
	poly(PackedVector2Array([Vector2(-12, -96 + b), Vector2(16, -96 + b), Vector2(12, -86 + b), Vector2(-10, -86 + b)]), Color("3f8f5a"))
	var back_hand := Vector2(-2, -72 + b)
	limb(Vector2(-4, -94 + b), back_hand, 7, Color("4a3566"))
	sword(back_hand, Vector2(0.3, 1.0).normalized(), 22.0, Color("dfe4ea"), Color("6b4a2b"), 0.0)
	var head := Vector2(4, -114 + b)
	disc(head + Vector2(3, 2), 12.0, Color("e8c29c"))
	poly(shifted([Vector2(-16, 12), Vector2(-14, -10), Vector2(-4, -18), Vector2(10, -16), Vector2(16, -8), Vector2(9, -6), Vector2(4, 4), Vector2(-4, 14)], head, 1.0), cloak)
	canvas.draw_circle(head + Vector2(11, -1), 1.8, Color("fff3c0"))
	var shoulder := Vector2(6, -96 + b)
	var hand := shoulder + arm_dir() * 27.0
	limb(shoulder, hand, 7, Color("4a3566"))
	disc(hand, 4.0, Color("e8c29c"))
	sword(hand, arm_dir(-1.4), 26.0, Color("e8edf2"), Color("6b4a2b"), glow)


func wizard() -> void:
	var b := breathe
	var robe := Color("2d4c96")
	var gold := Color("e0b24a")
	var sway := sin(time * 1.5) * 2.0
	poly(PackedVector2Array([Vector2(-8, -118 + b), Vector2(-2, -110 + b), Vector2(-16, -70), Vector2(-24, -76)]), Color("d9dde6"))
	poly(PackedVector2Array([Vector2(-14, -2), Vector2(18, -2), Vector2(13, -60), Vector2(12, -104 + b), Vector2(-12, -106 + b), Vector2(-12, -60)]), robe)
	for star in [Vector2(-6, -24), Vector2(8, -40), Vector2(-4, -58), Vector2(10, -16), Vector2(2, -84)]:
		canvas.draw_circle(star + Vector2(0, b * 0.3 if star.y < -60 else 0.0), 1.8, gold)
	canvas.draw_rect(Rect2(Vector2(-12, -64), Vector2(26, 5)), gold)
	poly(PackedVector2Array([Vector2(-10, -4), Vector2(2, -4), Vector2(4, 0), Vector2(-11, 0)]), Color("3a2a1c"))
	poly(PackedVector2Array([Vector2(6, -4), Vector2(18, -4), Vector2(22, 0), Vector2(5, 0)]), Color("3a2a1c"))
	var head := Vector2(4, -118 + b)
	disc(head, 12.0, Color("f0d2b0"))
	poly(PackedVector2Array([head + Vector2(-2, -4), head + Vector2(-16, -12), head + Vector2(-8, 2)]), Color("f0d2b0"), 1.5)
	canvas.draw_circle(head + Vector2(7, -1), 1.6, INK)
	poly(PackedVector2Array([head + Vector2(-12, -2), head + Vector2(-14, 26), head + Vector2(-4, 14), head + Vector2(-2, -8)]), Color("d9dde6"), 1.5)
	# Pointed hat with a bent tip.
	poly(PackedVector2Array([head + Vector2(-22, -6), head + Vector2(24, -6), head + Vector2(20, -12), head + Vector2(-18, -12)]), robe.darkened(0.3))
	poly(PackedVector2Array([head + Vector2(-13, -11), head + Vector2(14, -11), head + Vector2(6, -34), head + Vector2(-10 + sway, -52), head + Vector2(-26 + sway, -50), head + Vector2(-6, -36)]), robe)
	canvas.draw_line(head + Vector2(-13, -14), head + Vector2(14, -14), gold, 3.0)
	var shoulder := Vector2(6, -100 + b)
	var hand := shoulder + arm_dir() * 26.0
	var staff_dir := arm_dir(-1.6)
	limb(hand - staff_dir * 34.0, hand + staff_dir * 50.0, 4.0, Color("6b4a2b"))
	limb(shoulder, hand, 8, robe.lightened(0.1))
	disc(hand, 4.0, Color("f0d2b0"))
	var orb := hand + staff_dir * 56.0
	var pulse := 0.6 + 0.4 * sin(time * 4.0)
	glow_disc(orb, 6.0 + glow * 4.0, Color(0.5, 0.88, 1.0, 0.9).lerp(Color(1.0, 0.6, 0.2), glow * 0.6) * Color(1, 1, 1, 0.8 + 0.2 * pulse))


# --- enemies ----------------------------------------------------------------------

func goblin(archer: bool) -> void:
	var s := 0.72
	var b := breathe * 0.7
	var skin := Color("86b44f")
	var eye := Color("ffd23c")
	if not archer:
		legs(s, -58, skin.darkened(0.25), Color("4a3524"), 1.2)
	else:
		legs(s, -58, Color("34502c"), Color("4a3524"), 1.2)
	var body := PackedVector2Array([Vector2(-12, -38), Vector2(12, -38), Vector2(13, -72 + b), Vector2(-11, -74 + b)])
	poly(body, Color("6b4a2b") if not archer else Color("34502c"))
	poly(PackedVector2Array([Vector2(-10, -40), Vector2(10, -40), Vector2(6, -26), Vector2(-7, -26)]), Color("7a5230"))
	if archer:
		poly(PackedVector2Array([Vector2(-16, -76 + b), Vector2(-8, -78 + b), Vector2(-12, -40), Vector2(-20, -42)]), Color("5b3a22"))
		for arrow in 3:
			canvas.draw_line(Vector2(-14 + arrow * 2, -78 + b), Vector2(-18 + arrow * 3, -92 + b), Color("d6c7a8"), 2.0)
	else:
		limb(Vector2(-4, -70 + b), Vector2(8, -52 + b), 6, skin.darkened(0.15))
		var shield := Vector2(12, -52 + b)
		disc(shield, 15.0, Color("7a5230"))
		canvas.draw_arc(shield, 15.0, 0, TAU, 24, Color("5a5a60"), 3.0, true)
		disc(shield, 4.0, Color("8a8a90"))
	var head := Vector2(6, -90 + b)
	poly(PackedVector2Array([head + Vector2(-10, -4), head + Vector2(-30, -16), head + Vector2(-12, 6)]), skin.darkened(0.1))
	disc(head, 17.0, skin)
	poly(PackedVector2Array([head + Vector2(14, -2), head + Vector2(24, 4), head + Vector2(14, 8)]), skin, 1.5)
	if archer:
		poly(PackedVector2Array([head + Vector2(-18, 8), head + Vector2(-16, -14), head + Vector2(0, -20), head + Vector2(14, -12), head + Vector2(6, -8), head + Vector2(-6, 10)]), Color("2a4024"))
	canvas.draw_circle(head + Vector2(9, -2), 4.0, eye)
	canvas.draw_circle(head + Vector2(10, -2), 1.7, Color("b0201a"))
	canvas.draw_line(head + Vector2(4, 9), head + Vector2(16, 8), INK, 2.0)
	canvas.draw_colored_polygon(PackedVector2Array([head + Vector2(8, 8), head + Vector2(10, 12), head + Vector2(12, 8)]), Color("f4efe0"))
	var shoulder := Vector2(6, -68 + b)
	var hand := shoulder + arm_dir(-0.2 if archer else 0.0) * 20.0
	if archer:
		var bow_dir := arm_dir(-1.6)
		var bow_center := hand + bow_dir.orthogonal() * -2.0
		canvas.draw_arc(bow_center + bow_dir.orthogonal() * -12.0, 26.0, bow_dir.angle() - 1.1 + PI / 2.0 - PI / 2.0, bow_dir.angle() + 1.1, 16, INK, 5.0, true)
		canvas.draw_arc(bow_center + bow_dir.orthogonal() * -12.0, 26.0, bow_dir.angle() - 1.1, bow_dir.angle() + 1.1, 16, Color("8a5a2b"), 3.0, true)
		limb(shoulder, hand, 6, skin)
	else:
		limb(shoulder, hand, 6, skin)
		disc(hand, 3.5, skin.darkened(0.1))
		var blade := arm_dir(-1.3)
		var tip := hand + blade * 38.0
		var curve := blade.orthogonal() * -8.0
		poly(PackedVector2Array([hand + blade.orthogonal() * 3.0, hand + blade * 20.0 + curve * 0.6 + blade.orthogonal() * 4.0, tip + curve, hand + blade * 22.0 + curve * 0.2 - blade.orthogonal() * 3.0, hand - blade.orthogonal() * 3.0]), Color("a88a6a"))
		limb(hand - blade.orthogonal() * 6.0, hand + blade.orthogonal() * 6.0, 3.0, Color("5a3a22"))


func captain() -> void:
	var s := 1.12
	var b := breathe
	var skin := Color("c8643c")
	var iron := Color("4a4a52")
	var sway := sin(time * 1.4) * 4.0
	poly(PackedVector2Array([Vector2(-10, -118 + b), Vector2(0, -112 + b), Vector2(-20 + sway, -10), Vector2(-30 + sway, -18), Vector2(-38 + sway, -12)]), Color("8e1c12"))
	legs(s, -60, Color("3a3036"), Color("2a2226"), 1.2)
	poly(PackedVector2Array([Vector2(-19, -64), Vector2(19, -64), Vector2(22, -118 + b), Vector2(-18, -120 + b)]), iron)
	poly(PackedVector2Array([Vector2(-19, -64), Vector2(19, -64), Vector2(16, -52), Vector2(-16, -52)]), Color("6b2a1c"))
	canvas.draw_line(Vector2(-16, -92 + b), Vector2(18, -92 + b), Color("a33a24"), 3.0)
	for rivet in [Vector2(-10, -108), Vector2(10, -106), Vector2(-10, -78), Vector2(10, -78)]:
		canvas.draw_circle(rivet + Vector2(0, b), 2.0, Color("8a8a90"))
	var head := Vector2(6, -134 + b)
	disc(head, 17.0, skin)
	canvas.draw_circle(head + Vector2(9, 0), 3.5, Color("ffd23c"))
	canvas.draw_line(head + Vector2(4, 10), head + Vector2(17, 9), INK, 2.5)
	poly(PackedVector2Array([head + Vector2(8, 9), head + Vector2(10, 16), head + Vector2(13, 9)]), Color("f4efe0"), 1.0)
	poly(shifted([Vector2(-18, 0), Vector2(-16, -14), Vector2(0, -20), Vector2(16, -12), Vector2(18, -2)], head, 1.0), iron)
	poly(PackedVector2Array([head + Vector2(-12, -14), head + Vector2(-26, -34), head + Vector2(-18, -12)]), Color("e8dcc0"))
	poly(PackedVector2Array([head + Vector2(8, -18), head + Vector2(18, -40), head + Vector2(14, -16)]), Color("e8dcc0"))
	var shoulder := Vector2(8, -114 + b)
	var hand := shoulder + arm_dir() * 34.0
	var haft := arm_dir(-1.35)
	limb(hand - haft * 26.0, hand + haft * 58.0, 5.0, Color("5a3a22"))
	var head_of_axe := hand + haft * 52.0
	var edge := haft.orthogonal() * -1.0
	poly(PackedVector2Array([head_of_axe - haft * 12.0, head_of_axe + edge * 26.0 - haft * 18.0, head_of_axe + edge * 30.0, head_of_axe + edge * 26.0 + haft * 18.0, head_of_axe + haft * 12.0]), Color("9aa0a8"))
	limb(shoulder, hand, 11, skin)
	disc(hand, 6.0, skin.darkened(0.1))


func priest() -> void:
	var b := breathe
	var robe := Color("8e1c2a")
	var trim := Color("2a1014")
	poly(PackedVector2Array([Vector2(-18, -2), Vector2(22, -2), Vector2(16, -70), Vector2(14, -120 + b), Vector2(-14, -122 + b), Vector2(-16, -70)]), robe)
	poly(PackedVector2Array([Vector2(-18, -2), Vector2(22, -2), Vector2(20, -10), Vector2(-17, -10)]), trim)
	canvas.draw_line(Vector2(2, -120 + b), Vector2(4, -10), trim, 5.0)
	for rune in 3:
		canvas.draw_circle(Vector2(3, -96 + rune * 26 + b * 0.4), 3.0, Color("ff8a2a"))
	var head := Vector2(6, -136 + b)
	poly(PackedVector2Array([head + Vector2(-18, 16), head + Vector2(-18, -8), head + Vector2(-8, -26), head + Vector2(-20, -40), head + Vector2(10, -20), head + Vector2(18, -4), head + Vector2(16, 16)]), robe.darkened(0.2))
	poly(shifted([Vector2(-6, -12), Vector2(12, -10), Vector2(15, 4), Vector2(8, 14), Vector2(-4, 12)], head, 1.0), Color("e8e0cc"))
	var ember := 0.6 + 0.4 * sin(time * 6.0)
	canvas.draw_line(head + Vector2(4, -3), head + Vector2(12, -3), Color(1.0, 0.25 + 0.3 * ember, 0.1), 3.0)
	var shoulder := Vector2(8, -114 + b)
	var hand := shoulder + arm_dir() * 28.0
	var staff_dir := arm_dir(-1.6)
	limb(hand - staff_dir * 40.0, hand + staff_dir * 48.0, 4.5, Color("241a1a"))
	limb(shoulder, hand, 9, robe.lightened(0.05))
	disc(hand, 4.0, Color("e8e0cc"))
	var top := hand + staff_dir * 56.0
	var flame := PackedVector2Array()
	for step in 13:
		var t := TAU * step / 12.0
		var flicker := 1.0 + 0.25 * sin(time * 11.0 + step * 1.7)
		var reach := (9.0 + glow * 6.0) * flicker
		flame.append(top + Vector2(sin(t) * reach * 0.7, -cos(t) * reach - (reach * 0.9 if cos(t) > 0.0 else 0.0)))
	glow_disc(top, 5.0 + glow * 3.0, Color(1.0, 0.55, 0.15, 0.9))
	canvas.draw_colored_polygon(flame, Color(1.0, 0.45, 0.1, 0.85))
	canvas.draw_circle(top, 4.0, Color(1.0, 0.9, 0.5))
