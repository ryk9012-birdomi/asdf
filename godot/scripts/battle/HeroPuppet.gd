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
	&"paladin": {"art": "res://art/heroes/paladin/", "style": &"knight", "shape": "realistic"},
	&"rogue": {"art": "res://art/heroes/rogue/", "style": &"rogue", "shape": "realistic"},
	&"wizard": {"art": "res://art/heroes/wizard/", "style": &"wizard", "shape": "realistic"},
	&"goblin_raider": {"art": "res://art/enemies/goblin_raider/", "style": &"rogue", "size": 0.76, "head": [16, 24], "shape": "realistic"},
	&"goblin_archer": {"art": "res://art/enemies/goblin_archer/", "style": &"rogue", "size": 0.74, "head": [16, 24], "shape": "realistic"},
	&"hobgoblin_captain": {"art": "res://art/enemies/hobgoblin_captain/", "style": &"knight", "size": 1.1, "head": [16, 24], "shape": "realistic"},
	&"ember_priest": {"art": "res://art/enemies/ember_priest/", "style": &"wizard", "size": 1.12, "head": [16, 24], "shape": "realistic"},
	&"skeleton_warrior": {"art": "res://art/enemies/skeleton_warrior/", "style": &"knight", "size": 1.0, "head": [16, 24], "shape": "realistic"},
	&"cult_zealot": {"art": "res://art/enemies/cult_zealot/", "style": &"rogue", "size": 0.98, "head": [6, 10], "shape": "realistic"},
	&"cult_hexer": {"art": "res://art/enemies/cult_hexer/", "style": &"wizard", "size": 1.0, "head": [6, 34], "shape": "realistic"},
	&"orc_berserker": {"art": "res://art/enemies/orc_berserker/", "style": &"knight", "size": 1.16, "head": [16, 24], "shape": "realistic"},
}

## Gear parts an item may carry (art/gear/<item>/<part>.svg) and the bones they dress.
const GEAR_PARTS := {"weapon": [&"sword"], "armor": [&"armor"], "sleeve": [&"sleeve_f", &"sleeve_b"],
	"cape": [&"cape"], "charm": [&"charm"], "feather": [&"feather"]}
## Where gear's vector weapon and cloak pin on, for rigs whose own parts are painted.
const GEAR_PIVOTS := {&"sword": Vector2(14, 90), &"cape": Vector2(24, 4)}

## Art Bible body: a smaller head on longer limbs, about 1:4.5 (the parts are drawn 1:3.5).
const REALISTIC := {"head": 0.86, "legs": 1.14, "arms": 1.06, "torso": 1.04}

var style: Dictionary
## Standing hip height; grows with longer legs.
var hip_height: float = 60.0
## Texture, offset and density the part set came with, restored when gear comes off.
var bare: Dictionary = {}
## A painted sheet rig (tools/sheet_rig.py): rig.json lists PNG parts with their pivots and
## pixel density, and joints that override the vector skeleton's. Empty for SVG part sets.
var sheet: Dictionary = {}
var art_path: String
## slot -> item id currently shown.
var worn: Dictionary = {}

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
	art_path = art
	if ResourceLoader.exists(art + "rig.json"):
		sheet = (load(art + "rig.json") as JSON).data
		# The sheet may carry its own far-arm rest and raise poses (shoulder, elbow).
		for pose in ["rest", "raise"]:
			if sheet.has(pose):
				style[pose] = Vector2(sheet[pose][0], sheet[pose][1])
	for face in ["head", "head_blink", "head_shout", "head_hurt", "head_down"]:
		faces[face] = piece(face)
	hip_height = sheet.get("hip", 60.0)
	root = Vector2(0, -hip_height)
	bone(&"hip", null, Vector2.ZERO)
	limb(&"thigh_b", "thigh", Vector2(11, 4), &"hip", at("thigh_b", Vector2(-3, 0)))
	limb(&"shin_b", "shin", Vector2(11, 4), &"thigh_b", at("shin", Vector2(0, 28)))
	limb(&"thigh_f", "thigh", Vector2(11, 4), &"hip", at("thigh_f", Vector2(3, 0)))
	limb(&"shin_f", "shin", Vector2(11, 4), &"thigh_f", at("shin", Vector2(0, 28)))
	limb(&"torso", "torso", Vector2(24, 64), &"hip", Vector2.ZERO)
	limb(&"cape", "cape", Vector2(24, 4), &"torso", at("cape", Vector2(-9, -46)))
	head = limb(&"head", "head", style.head, &"torso", at("head", Vector2(1, -48)))
	limb(&"plume", "plume", Vector2(24, 20), &"head", at("plume", Vector2(-7, -40)))
	limb(&"upper_b", "arm_upper", Vector2(14, 7), &"torso", at("upper_b", Vector2(-6, -42)))
	limb(&"lower_b", "arm_lower", Vector2(9, 3), &"upper_b", at("lower", Vector2(0, 20)))
	limb(&"hand_b", "hand", Vector2(8, 2), &"lower_b", at("hand", Vector2(0, 18)))
	var buckler := limb(&"shield", "shield", Vector2(20, 22), &"hand_b", at("shield", Vector2(0, 7)))
	shielded = not buckler.texture.get_image().is_invisible()
	limb(&"upper_f", "arm_upper", Vector2(14, 7), &"torso", at("upper_f", Vector2(4, -42)))
	limb(&"lower_f", "arm_lower", Vector2(9, 3), &"upper_f", at("lower", Vector2(0, 20)))
	limb(&"hand_f", "hand", Vector2(8, 2), &"lower_f", at("hand", Vector2(0, 18)))
	limb(&"sword", "weapon", Vector2(14, 90), &"hand_f", at("sword", Vector2(0, 7)))
	glow = bone(&"glow", load(art + "glow.svg"), Vector2(32, 32), &"sword", style.glow)
	# Empty slots for worn gear, drawn over the body parts they belong to.
	bone(&"armor", null, Vector2(24, 64), &"torso", Vector2.ZERO, true)
	bone(&"charm", null, Vector2(24, 64), &"torso", Vector2.ZERO, true)
	bone(&"sleeve_f", null, Vector2(14, 7), &"upper_f", Vector2.ZERO, true)
	bone(&"sleeve_b", null, Vector2(14, 7), &"upper_b", Vector2.ZERO, true)
	bone(&"feather", null, Vector2(4, 26), &"head", Vector2(-7, -33), true)
	for id in [&"sword", &"cape"]:
		bare[id] = [bones[id].sprite.texture, bones[id].sprite.offset, bones[id].density]
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = additive
	ward = bone(&"ward", glow.texture, Vector2(32, 32), &"shield", Vector2(0, 2))
	ward.material = additive
	for far in [&"thigh_b", &"shin_b", &"upper_b", &"sleeve_b", &"lower_b", &"hand_b"]:
		bones[far].sprite.self_modulate = FAR_SIDE
	var far_arm := [&"hand_b", &"shield", &"ward"]
	var body := [&"cape", &"thigh_b", &"shin_b", &"upper_b", &"sleeve_b", &"lower_b", &"thigh_f", &"shin_f", &"torso",
		&"armor", &"charm", &"plume", &"head", &"feather"]
	# A painted front-facing body hides the far hand behind it; a side-on vector one shows it.
	if sheet.get("far_arm_behind", false):
		body = far_arm + body
		far_arm = []
	layer(body + far_arm + [&"upper_f", &"sleeve_f", &"lower_f", &"sword", &"glow", &"hand_f"])


## A part's texture: the sheet's PNG when it has one, else the vector drawing.
func piece(name: String) -> Texture2D:
	return load(art_path + name + (".png" if sheet.get("parts", {}).has(name) else ".svg"))


## A bone drawn with a named part, pinned at the sheet's pivot or the vector default.
func limb(id: StringName, name: String, pivot: Vector2, parent: StringName, joint: Vector2) -> Sprite2D:
	var spec: Dictionary = sheet.get("parts", {}).get(name, {})
	if spec.is_empty():
		return bone(id, piece(name), pivot, parent, joint)
	var density: float = spec.density
	return bone(id, piece(name), Vector2(spec.pivot[0], spec.pivot[1]) / density, parent, joint, false, density)


## A joint position from the sheet, or the vector skeleton's.
func at(id: String, fallback: Vector2) -> Vector2:
	var joints: Dictionary = sheet.get("joints", {})
	return Vector2(joints[id][0], joints[id][1]) if joints.has(id) else fallback


## Reshapes the figure: head size and limb/torso lengths as factors (see REALISTIC).
func proportion(shape: Dictionary) -> void:
	var legs: float = shape.get("legs", 1.0)
	var arms: float = shape.get("arms", 1.0)
	var head_scale: float = shape.get("head", 1.0)
	for id in [&"thigh_b", &"shin_b", &"thigh_f", &"shin_f"]:
		bones[id].stretch = Vector2(1.0, legs)
	for id in [&"upper_b", &"lower_b", &"upper_f", &"lower_f"]:
		bones[id].stretch = Vector2(1.0, arms)
	bones[&"torso"].stretch = Vector2(1.0, shape.get("torso", 1.0))
	bones[&"head"].stretch = Vector2.ONE * head_scale
	# Worn overlays follow the part they cover.
	for id in [&"sleeve_b", &"sleeve_f"]:
		bones[id].stretch = Vector2(1.0, arms)
	for id in [&"armor", &"charm"]:
		bones[id].stretch = bones[&"torso"].stretch
	for id in [&"plume", &"feather"]:
		bones[id].stretch = Vector2.ONE * head_scale
	hip_height = 60.0 * legs


## Dresses the figure in its equipment (slot -> item id): a weapon replaces the one in
## hand, armor and sleeves go over the body, a cloak replaces the cape, trinkets hang on.
func wear(equipment: Dictionary) -> void:
	for id in bare:
		var entry: Bone = bones[id]
		entry.sprite.texture = bare[id][0]
		entry.sprite.offset = bare[id][1]
		entry.density = bare[id][2]
	for id in [&"armor", &"charm", &"sleeve_f", &"sleeve_b", &"feather"]:
		bones[id].sprite.texture = null
	worn = equipment.duplicate()
	# Vector armour and sleeves would sit badly over a painted body; those rigs skip them.
	var overlays: bool = sheet.get("overlays", true)
	for slot in equipment:
		var folder := "res://art/gear/%s/" % equipment[slot]
		for part in GEAR_PARTS:
			var path: String = folder + part + ".svg"
			if not ResourceLoader.exists(path) or (not overlays and part in ["armor", "sleeve"]):
				continue
			for id in GEAR_PARTS[part]:
				var entry: Bone = bones[id]
				entry.sprite.texture = load(path)
				if GEAR_PIVOTS.has(id):
					entry.sprite.offset = -GEAR_PIVOTS[id] * TEXTURE_SCALE
					entry.density = TEXTURE_SCALE


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
	root = Vector2(0, -hip_height + 3.0 * alive + breathe * 0.6 - absf(step) * 2.5 * walk + hurt * 2.0)

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
	angles.feather = -1.15 + sin(t * 2.3) * 0.05 - hurt * 0.2
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
