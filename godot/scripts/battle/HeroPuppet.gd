class_name HeroPuppet
extends Puppet
## A hero on the shared skeleton: a weapon in the near hand, a shield (or off-hand dagger,
## or an open palm) in the far one. Any part set from tools/generate_hero_art.py fits; the
## style says how that class holds its weapon and where its light gathers.

const FAR_SIDE := Color(0.7, 0.72, 0.8)

## figure.arm → near shoulder, elbow, and the weapon's angle from upright.
## -2.3 cheer · -2.1 raise for a prayer or spell · -1.3 wind-up · -0.8 guard · 0 ready · 1.5 follow-through
const KNIGHT_ARM := [
	[-2.3, -2.95, -0.15, -0.1],
	[-2.1, -2.8, -0.25, 0.0],
	[-1.3, -2.55, -0.95, -1.25],
	[-0.8, -0.95, -1.35, 0.35],
	[0.0, -0.3, -1.05, 0.6],
	[1.5, -1.55, -0.1, 1.95],
]
## Daggers ride low and forward, then stab straight out.
const ROGUE_ARM := [
	[-2.3, -2.95, -0.2, -0.3],
	[-2.1, -2.7, -0.4, 0.2],
	[-1.3, -2.3, -1.1, -1.0],
	[-0.8, -0.8, -1.5, 0.8],
	[0.0, -0.5, -1.25, 1.15],
	[1.5, -1.62, 0.0, 1.7],
]
## The staff stands upright beside the wizard, rises for a spell and jabs forward to strike.
const WIZARD_ARM := [
	[-2.3, -2.9, -0.2, 0.0],
	[-2.1, -2.6, -0.35, 0.15],
	[-1.3, -2.1, -0.8, -0.5],
	[-0.8, -0.9, -1.2, 0.45],
	[0.0, -0.25, -0.95, 0.06],
	[1.5, -1.35, -0.15, 1.15],
]
## arm: pose rows · rest/raise: far shoulder and elbow · glow: where the light sits on the
## weapon and how it is stretched · palm: the far hand lights up while casting · head: the
## head pivot, lower for tall hats.
const STYLES := {
	&"knight": {"arm": KNIGHT_ARM, "rest": Vector2(-0.45, -1.15), "raise": Vector2(-1.45, -0.55),
		"glow": Vector2(0, -30), "glow_size": Vector2(0.55, 1.25), "palm": false, "head": Vector2(26, 56)},
	&"rogue": {"arm": ROGUE_ARM, "rest": Vector2(-0.7, -1.25), "raise": Vector2(-1.3, -0.7),
		"glow": Vector2(0, -16), "glow_size": Vector2(0.3, 0.6), "palm": false, "head": Vector2(26, 56)},
	&"wizard": {"arm": WIZARD_ARM, "rest": Vector2(-0.3, -0.6), "raise": Vector2(-1.5, -0.25),
		"glow": Vector2(0, -80), "glow_size": Vector2(0.75, 0.75), "palm": true, "head": Vector2(26, 80)},
}
## Battle art per fighter kind (hero class id or enemy id). size scales the whole figure;
## head gives the head canvas margins [left, top] when they differ from the style's.
const RIGS := {
	&"paladin": {"art": "res://art/heroes/paladin/", "style": &"knight"},
	&"rogue": {"art": "res://art/heroes/rogue/", "style": &"rogue"},
	&"wizard": {"art": "res://art/heroes/wizard/", "style": &"wizard"},
	&"goblin_raider": {"art": "res://art/enemies/goblin_raider/", "style": &"rogue", "size": 0.76, "head": [16, 24]},
	&"goblin_archer": {"art": "res://art/enemies/goblin_archer/", "style": &"rogue", "size": 0.74, "head": [16, 24]},
	&"hobgoblin_captain": {"art": "res://art/enemies/hobgoblin_captain/", "style": &"knight", "size": 1.1, "head": [16, 24]},
	&"ember_priest": {"art": "res://art/enemies/ember_priest/", "style": &"wizard", "size": 1.12, "head": [16, 24]},
	&"skeleton_warrior": {"art": "res://art/enemies/skeleton_warrior/", "style": &"knight", "size": 1.0, "head": [16, 24]},
	&"cult_zealot": {"art": "res://art/enemies/cult_zealot/", "style": &"rogue", "size": 0.98},
	&"cult_hexer": {"art": "res://art/enemies/cult_hexer/", "style": &"wizard", "size": 1.0},
	&"orc_berserker": {"art": "res://art/enemies/orc_berserker/", "style": &"knight", "size": 1.16, "head": [16, 24]},
}

var style: Dictionary

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


func _init(art: String, style_id: StringName = &"knight", head_margins: Array = []) -> void:
	art = art.trim_suffix("/") + "/"
	style = STYLES[style_id].duplicate()
	if head_margins.size() == 2:
		style.head = Vector2(20 + head_margins[0], 46 + head_margins[1])
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
	head = bone(&"head", faces.head, style.head, &"torso", Vector2(1, -48))
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
	glow = bone(&"glow", load(art + "glow.svg"), Vector2(32, 32), &"sword", style.glow)
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
	var pose := sample(style.arm, arm)
	var limp := Vector3(0.35, -0.25, 0.1)
	angles.upper_f = lerpf(pose[0] + breathe * 0.03, limp.x, fallen)
	angles.lower_f = lerpf(pose[1], limp.y, fallen)
	angles.hand_f = 0.0
	angles.sword = lerpf(pose[2], limp.z, fallen) - world_angle(&"hand_f")
	var raise := clampf(glow_amount, 0.0, 1.0) * (1.0 if arm > -1.6 else 0.3) + hurt * 0.4
	if style.palm:
		raise = clampf(glow_amount, 0.0, 1.0) + hurt * 0.4
	var rest: Vector2 = style.rest
	var lifted: Vector2 = style.raise
	angles.upper_b = lerpf(lerpf(rest.x, lifted.x, raise) + breathe * 0.02, 0.25, fallen)
	angles.lower_b = lerpf(lerpf(rest.y, lifted.y, raise), -0.3, fallen)
	angles.hand_b = 0.0
	angles.shield = lerpf(0.06 - 0.08 * raise, 0.6, fallen) - world_angle(&"hand_b")

	# Cloth trails the motion and settles with a little overshoot.
	var drift := clampf(speed / 300.0, -0.5, 0.8)
	angles.cape = cape.step(0.05 + sin(t * 1.4) * 0.04 + drift * 0.6 + hurt * 0.15, delta) - angles.torso * 0.7
	angles.plume = plume.step(sin(t * 1.9) * 0.08 + drift * 0.5 + hurt * 0.3, delta, 90.0, 7.0) - angles.head * 0.5

	# Light gathers on the weapon for a prayer or spell and on the shield for a guard; a
	# wizard's open far hand glows along with the staff.
	var light := clampf(glow_amount, 0.0, 1.0)
	var guarding := 1.0 if arm > -1.6 and shielded else 0.0
	var on_weapon := light * (1.0 - guarding)
	var on_hand := light if style.palm else light * guarding
	glow.visible = on_weapon > 0.01
	glow.modulate = Color(1, 1, 1, on_weapon)
	ward.visible = on_hand > 0.01
	ward.modulate = Color(1, 1, 1, on_hand)
	head.texture = faces[expression(t, arm, glow_amount, hurt, fallen)]
	solve()
	var pulse := 1.0 + 0.08 * sin(t * 9.0)
	glow.transform = glow.transform.scaled_local(style.glow_size * pulse)
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
