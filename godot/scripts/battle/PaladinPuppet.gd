class_name PaladinPuppet
extends Puppet
## A knight: plate, tabard and cape, a weapon in the near hand and a shield in the far one.
## Any part set made by tools/generate_knight_art.py fits; Aldric wears art/heroes/paladin.

const ART := "res://art/heroes/paladin/"
const FAR_SIDE := Color(0.7, 0.72, 0.8)

## figure.arm → near shoulder, elbow, and the sword's angle from upright.
## -2.3 cheer · -2.1 raise for a prayer · -1.3 wind-up · -0.8 guard · 0 ready · 1.5 follow-through
const SWORD_ARM := [
	[-2.3, -2.95, -0.15, -0.1],
	[-2.1, -2.8, -0.25, 0.0],
	[-1.3, -2.55, -0.95, -1.25],
	[-0.8, -0.95, -1.35, 0.35],
	[0.0, -0.3, -1.05, 0.6],
	[1.5, -1.55, -0.1, 1.95],
]

var faces: Dictionary = {}
var head: Sprite2D
var glow: Sprite2D
var ward: Sprite2D
## Some knights fight two-handed with no shield; their guard light goes to the weapon.
var shielded := true
var cape := Spring.new()
var plume := Spring.new()
var stride: float = 0.0
var walk: float = 0.0


func _init(art: String = ART) -> void:
	art = art.trim_suffix("/") + "/"
	for face in ["head", "head_blink", "head_shout", "head_hurt", "head_down"]:
		faces[face] = load(art + face + ".svg")
	var thigh: Texture2D = load(art + "thigh.svg")
	var shin: Texture2D = load(art + "shin.svg")
	var upper: Texture2D = load(art + "arm_upper.svg")
	var lower: Texture2D = load(art + "arm_lower.svg")
	var fist: Texture2D = load(art + "hand.svg")
	root = Vector2(0, -60)
	bone(&"hip", null, Vector2.ZERO)
	bone(&"thigh_b", thigh, Vector2(11, 4), &"hip", Vector2(-3, 0))
	bone(&"shin_b", shin, Vector2(11, 4), &"thigh_b", Vector2(0, 28))
	bone(&"thigh_f", thigh, Vector2(11, 4), &"hip", Vector2(3, 0))
	bone(&"shin_f", shin, Vector2(11, 4), &"thigh_f", Vector2(0, 28))
	bone(&"torso", load(art + "torso.svg"), Vector2(24, 64), &"hip")
	bone(&"cape", load(art + "cape.svg"), Vector2(24, 4), &"torso", Vector2(-9, -46))
	head = bone(&"head", faces.head, Vector2(26, 56), &"torso", Vector2(1, -48))
	bone(&"plume", load(art + "plume.svg"), Vector2(24, 20), &"head", Vector2(-7, -40))
	bone(&"upper_b", upper, Vector2(14, 7), &"torso", Vector2(-6, -42))
	bone(&"lower_b", lower, Vector2(9, 3), &"upper_b", Vector2(0, 20))
	bone(&"hand_b", fist, Vector2(8, 2), &"lower_b", Vector2(0, 18))
	var buckler: Texture2D = load(art + "shield.svg")
	shielded = not buckler.get_image().is_invisible()
	bone(&"shield", buckler, Vector2(20, 22), &"hand_b", Vector2(0, 7))
	bone(&"upper_f", upper, Vector2(14, 7), &"torso", Vector2(4, -42))
	bone(&"lower_f", lower, Vector2(9, 3), &"upper_f", Vector2(0, 20))
	bone(&"hand_f", fist, Vector2(8, 2), &"lower_f", Vector2(0, 18))
	bone(&"sword", load(art + "weapon.svg"), Vector2(14, 90), &"hand_f", Vector2(0, 7))
	glow = bone(&"glow", load(art + "glow.svg"), Vector2(32, 32), &"sword", Vector2(0, -30))
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = additive
	ward = bone(&"ward", glow.texture, Vector2(32, 32), &"shield", Vector2(0, 2))
	ward.material = additive
	for far in [&"thigh_b", &"shin_b", &"upper_b", &"lower_b", &"hand_b"]:
		bones[far].sprite.self_modulate = FAR_SIDE
	layer([&"cape", &"thigh_b", &"shin_b", &"upper_b", &"lower_b", &"thigh_f", &"shin_f", &"torso",
		&"plume", &"head", &"hand_b", &"shield", &"ward", &"upper_f", &"lower_f", &"sword", &"glow", &"hand_f"])


func drive(figure: Control, delta: float) -> void:
	var t: float = figure.time + phase
	var arm: float = figure.arm
	var glow_amount: float = figure.glow
	var hurt: float = figure.hurt
	var lean: float = figure.lean
	var fallen: float = figure.fallen
	var alive := 1.0 - fallen
	var breathe := sin(t * 2.2)
	var speed := pace(figure, delta)
	walk = lerpf(walk, clampf(absf(speed) / 350.0, 0.0, 1.0), clampf(delta * 10.0, 0.0, 1.0))
	stride += delta * (4.0 + absf(speed) * 0.035) * walk
	var step := sin(stride * 2.0)

	# Legs: a braced stance that turns into a stride while the figure is moving.
	angles.thigh_f = (-0.3 - step * 0.55 * walk) * alive
	angles.thigh_b = (0.3 + step * 0.55 * walk) * alive
	angles.shin_f = (0.26 + maxf(0.0, -step) * 0.7 * walk) * alive
	angles.shin_b = (0.08 + maxf(0.0, step) * 0.7 * walk) * alive
	root = Vector2(0, -60 + 3.0 * alive + breathe * 0.6 - absf(step) * 2.5 * walk + hurt * 2.0)

	# Body: leans into swings and dashes, rocks back when struck.
	var swing := clampf(arm, 0.0, 1.5)
	angles.torso = (0.04 + lean * 0.28 + swing * 0.12 - hurt * 0.3 + breathe * 0.015) * alive
	angles.head = (-angles.torso * 0.55 - hurt * 0.2 + sin(t * 0.9) * 0.03) * alive + fallen * 0.25

	# Sword arm follows the motion value; the shield comes up for a guard or a prayer.
	var pose := sample(SWORD_ARM, arm)
	var limp := Vector3(0.35, -0.25, 0.1)
	angles.upper_f = lerpf(pose[0] + breathe * 0.03, limp.x, fallen)
	angles.lower_f = lerpf(pose[1], limp.y, fallen)
	angles.hand_f = 0.0
	angles.sword = lerpf(pose[2], limp.z, fallen) - world_angle(&"hand_f")
	var raise := clampf(glow_amount, 0.0, 1.0) * (1.0 if arm > -1.6 else 0.3) + hurt * 0.4
	angles.upper_b = lerpf(lerpf(-0.45, -1.45, raise) + breathe * 0.02, 0.25, fallen)
	angles.lower_b = lerpf(lerpf(-1.15, -0.55, raise), -0.3, fallen)
	angles.hand_b = 0.0
	angles.shield = lerpf(0.06 - 0.08 * raise, 0.6, fallen) - world_angle(&"hand_b")

	# Cloth trails the motion and settles with a little overshoot.
	var drift := clampf(speed / 300.0, -0.5, 0.8)
	angles.cape = cape.step(0.05 + sin(t * 1.4) * 0.04 + drift * 0.6 + hurt * 0.15, delta) - angles.torso * 0.7
	angles.plume = plume.step(sin(t * 1.9) * 0.08 + drift * 0.5 + hurt * 0.3, delta, 90.0, 7.0) - angles.head * 0.5

	# Holy light gathers on the blade for a prayer and on the shield for a guard.
	var light := clampf(glow_amount, 0.0, 1.0)
	var guarding := 1.0 if arm > -1.6 and shielded else 0.0
	glow.visible = light * (1.0 - guarding) > 0.01
	glow.modulate = Color(1, 1, 1, light * (1.0 - guarding))
	ward.visible = light * guarding > 0.01
	ward.modulate = Color(1, 1, 1, light * guarding)
	head.texture = faces[expression(t, arm, glow_amount, hurt, fallen)]
	solve()
	var pulse := 1.0 + 0.08 * sin(t * 9.0)
	glow.transform = glow.transform.scaled_local(Vector2(0.55, 1.25) * pulse)
	ward.transform = ward.transform.scaled_local(Vector2(0.95, 1.15) * pulse)


func expression(t: float, arm: float, glow_amount: float, hurt: float, fallen: float) -> String:
	if fallen > 0.4:
		return "head_down"
	if hurt > 0.3:
		return "head_hurt"
	if glow_amount > 0.4 or arm > 0.5 or arm < -1.0:
		return "head_shout"
	if fmod(t, 3.7) < 0.13:
		return "head_blink"
	return "head"
