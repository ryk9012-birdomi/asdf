class_name Puppet
extends Node2D
## A cut-out figure: SVG parts pinned at their joints and posed bone by bone, like a
## paper doll. Subclasses list the parts and turn the fighter's motion values into angles.
## The origin is between the feet; +x faces the enemy, angles are in radians, clockwise.

## Parts are imported at three times their drawn size (with mipmaps) so they stay crisp
## from a small window up to a 4K screen.
const TEXTURE_SCALE := 3.0

var bones: Dictionary = {}
var order: Array[StringName] = []
var angles: Dictionary = {}
var root := Vector2.ZERO
var phase: float = 0.0
var last_x: float = NAN
## Scale of the whole figure on top of the fighter's art scale (goblins are small).
var size: float = 1.0


class Bone:
	var parent: StringName
	var joint: Vector2
	var sprite: Sprite2D


## Damped spring for hanging cloth and plumes that trail behind the body.
class Spring:
	var value: float = 0.0
	var velocity: float = 0.0

	func step(target: float, delta: float, stiffness: float = 70.0, damping: float = 9.0) -> float:
		velocity += (target - value) * stiffness * delta
		velocity *= exp(-damping * delta)
		value += velocity * delta
		return value


static func create(kind: StringName) -> Puppet:
	if not HeroPuppet.RIGS.has(kind):
		return null
	var rig: Dictionary = HeroPuppet.RIGS[kind]
	return hero(rig.art, rig.style, rig.get("size", 1.0), rig.get("head", []))


## Any part set from tools/generate_hero_art.py, posed in that style.
static func hero(art: String, style_id: StringName = &"knight", scale_by: float = 1.0, head_margins: Array = []) -> Puppet:
	var puppet := HeroPuppet.new(art, style_id, head_margins)
	puppet.size = scale_by
	puppet.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return puppet


## Declares a bone. Parents come first. `pivot` is the joint inside the part's own drawing;
## `joint` is where it pins onto the parent, measured from the parent's pivot. A `slot`
## bone gets a sprite even without a texture, for gear that may be worn later.
func bone(id: StringName, texture: Texture2D, pivot: Vector2, parent: StringName = &"", joint: Vector2 = Vector2.ZERO, slot: bool = false) -> Sprite2D:
	var entry := Bone.new()
	entry.parent = parent
	entry.joint = joint
	if texture != null or slot:
		entry.sprite = Sprite2D.new()
		entry.sprite.name = String(id)
		entry.sprite.texture = texture
		entry.sprite.centered = false
		entry.sprite.offset = -pivot * TEXTURE_SCALE
		add_child(entry.sprite)
	bones[id] = entry
	order.append(id)
	angles[id] = 0.0
	return entry.sprite


## Back-to-front drawing order, independent of the bone hierarchy.
func layer(ids: Array) -> void:
	var index := 0
	for id in ids:
		var sprite: Sprite2D = bones[id].sprite
		if sprite != null:
			move_child(sprite, index)
			index += 1


## Accumulated angle of a bone, for parts that must stay upright whatever the arm does.
func world_angle(id: StringName) -> float:
	var total := 0.0
	while id != &"":
		total += angles[id]
		id = bones[id].parent
	return total


func solve() -> void:
	var placed := {}
	var shrink := Transform2D(0.0, Vector2.ONE / TEXTURE_SCALE, 0.0, Vector2.ZERO)
	for id in order:
		var entry: Bone = bones[id]
		var local := Transform2D(angles[id], entry.joint)
		var xform: Transform2D = (placed[entry.parent] * local) if entry.parent != &"" else Transform2D(angles[id], root + entry.joint)
		placed[id] = xform
		if entry.sprite != null:
			entry.sprite.transform = xform * shrink


## Forward speed of the figure in its own facing, in pixels per second.
func pace(figure: Control, delta: float) -> float:
	var x := figure.position.x
	var speed := 0.0 if is_nan(last_x) or delta <= 0.0 else (x - last_x) / delta * signf(figure.scale.x)
	last_x = x
	return speed


## Called every frame by the fighter's figure with its motion values.
func drive(_figure: Control, _delta: float) -> void:
	solve()


## Piecewise-linear lookup in sorted [key, value...] rows; returns the blended values.
static func sample(rows: Array, key: float) -> Array:
	if key <= rows[0][0]:
		return rows[0].slice(1)
	for index in range(1, rows.size()):
		if key <= rows[index][0]:
			var low: Array = rows[index - 1]
			var high: Array = rows[index]
			var weight := inverse_lerp(low[0], high[0], key)
			var out := []
			for column in range(1, low.size()):
				out.append(lerpf(low[column], high[column], weight))
			return out
	return rows[-1].slice(1)
