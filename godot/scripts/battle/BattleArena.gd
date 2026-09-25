class_name BattleArena
extends Control
## 2D side-view battlefield: a muddy road through a ruined village, party on the left, foes
## on the right. Plays resolved actions as motion; it never changes game state.

signal unit_clicked(unit: CharacterUnit)

const RANGED := [&"wizard", &"goblin_archer", &"ember_priest", &"cult_hexer"]
const SPACING := 200.0
const MISSILE_COLORS := {
	SkillData.DamageType.PHYSICAL: Color("7a5a3a"),
	SkillData.DamageType.ARCANE: Color("b48cff"),
	SkillData.DamageType.FIRE: Color("ff7a1f"),
	SkillData.DamageType.RADIANT: Color("ffe08a"),
	SkillData.DamageType.TRUE_DAMAGE: Color("ffffff"),
}

var fighters: Dictionary = {}
var order: Array[CharacterUnit] = []
var busy_until: float = 0.0
var time: float = 0.0


class Missile extends Node2D:
	var color: Color
	var arrow: bool = false
	var heading: Vector2 = Vector2.RIGHT

	func _draw() -> void:
		if arrow:
			draw_line(-heading * 16.0, heading * 10.0, Color("6b4a2b"), 3.0, true)
			draw_colored_polygon(PackedVector2Array([heading * 16.0, heading * 8.0 + heading.orthogonal() * 4.0, heading * 8.0 - heading.orthogonal() * 4.0]), Color("cfd4da"))
			return
		for step in 5:
			draw_circle(Vector2.ZERO, 9.0 + step * 5.0, Color(color, 0.22 - step * 0.04))
		draw_circle(-heading * 10.0, 7.0, Color(color, 0.35))
		draw_circle(Vector2.ZERO, 8.0, color)
		draw_circle(Vector2.ZERO, 4.0, Color(1, 1, 1, 0.9))


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(layout)
	# Brush strokes over the painted ground only; the fighters are added above it.
	var strokes := Painting.brush(0.45)
	strokes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(strokes)
	var embers := CPUParticles2D.new()
	embers.name = "Embers"
	embers.amount = 50
	embers.lifetime = 5.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(700, 10)
	# Dust and ash lifted off the road by a cold wind.
	embers.direction = Vector2.UP
	embers.spread = 50.0
	embers.gravity = Vector2(14, -2)
	embers.initial_velocity_min = 8.0
	embers.initial_velocity_max = 26.0
	embers.scale_amount_min = 1.0
	embers.scale_amount_max = 2.2
	embers.color = Color(0.8, 0.8, 0.76, 0.5)
	add_child(embers)


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func ground_y() -> float:
	return size.y - 26.0


func _draw() -> void:
	var w := size.x
	var h := size.y
	Painting.paint(self, Rect2(Vector2.ZERO, size), 0.58, true, time)
	# Rusted lanterns on leaning posts at both edges: the only warm light on the field.
	var road_top := h * 0.58 + h * 0.42 * Painting.ROAD.x
	for side in [0.035, 0.965]:
		var tx: float = w * side
		var ty := road_top - 150.0
		var flicker := 0.85 + 0.15 * sin(time * 3.0 + side * 10.0) * sin(time * 7.3)
		for ring in 5:
			draw_circle(Vector2(tx, ty), (20.0 + ring * 18.0) * flicker, Color(0.95, 0.62, 0.3, 0.07 - ring * 0.012))
		var lean := 6.0 * (1.0 if side < 0.5 else -1.0)
		draw_line(Vector2(tx + lean, ty - 14), Vector2(tx, road_top + 20), Painting.WOOD, 6.0)
		draw_line(Vector2(tx + lean, ty - 14), Vector2(tx + lean + 18.0 * (1.0 if side < 0.5 else -1.0), ty - 14), Painting.WOOD, 4.0)
		draw_rect(Rect2(Vector2(tx - 8, ty - 8), Vector2(16, 20)), Color(0.86, 0.66, 0.4, 0.85 * flicker))
		draw_rect(Rect2(Vector2(tx - 8, ty - 8), Vector2(16, 20)), Painting.RUST.darkened(0.4), false, 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(tx - 11, ty - 8), Vector2(tx + 11, ty - 8), Vector2(tx, ty - 19)]), Painting.RUST.darkened(0.45))


func setup(party: Array[CharacterUnit], enemies: Array[CharacterUnit]) -> void:
	# Back rows first so the front line draws over them.
	for side in [party, enemies]:
		for index in range(side.size() - 1, -1, -1):
			var unit: CharacterUnit = side[index]
			var fighter := FighterView.new()
			add_child(fighter)
			fighter.setup(unit, side == party)
			fighter.pressed.connect(func(): unit_clicked.emit(unit))
			fighters[unit] = fighter
			order.append(unit)
	move_child(get_node("Embers"), get_child_count() - 1)
	layout()


func layout() -> void:
	var center := size.x / 2.0
	var embers: CPUParticles2D = get_node_or_null("Embers")
	if embers != null:
		embers.position = Vector2(center, ground_y())
		embers.emission_rect_extents = Vector2(size.x / 2.0, 10)
	for unit in fighters:
		var fighter: FighterView = fighters[unit]
		var side_units := order.filter(func(other): return fighters[other].facing == fighter.facing)
		var index: int = side_units.size() - 1 - side_units.find(unit)
		var slot := mini(index, 2)
		var extra := index - slot
		var reach := 100.0 + slot * SPACING + extra * 70.0
		var x := center - fighter.facing * reach - FighterView.WIDTH / 2.0
		var y := ground_y() - FighterView.HEIGHT - slot * 16.0 + extra * 30.0
		fighter.home = Vector2(x, y)
		fighter.position = fighter.home


## Point over a figure's head or chest, in this control's coordinates.
func head_point(unit: CharacterUnit) -> Vector2:
	var fighter: FighterView = fighters[unit]
	return fighter.position + fighter.head_offset()


func chest_point(unit: CharacterUnit) -> Vector2:
	var fighter: FighterView = fighters[unit]
	return fighter.position + fighter.chest_offset()


func hud_top(unit: CharacterUnit) -> Vector2:
	var fighter: FighterView = fighters[unit]
	return fighter.position + Vector2(FighterView.WIDTH / 2.0, 0)


func animation_time_left() -> float:
	return maxf(0.0, busy_until - time)


## Plays a resolved action and returns seconds until the blow lands.
func perform(actor: CharacterUnit, targets: Array[CharacterUnit], skill: SkillData, missed: Array[CharacterUnit]) -> float:
	if not fighters.has(actor):
		return 0.0
	var fighter: FighterView = fighters[actor]
	var impact := 0.3
	for target in targets:
		if fighters.has(target):
			fighters[target].freeze_hp()
	if skill.effect_type == SkillData.EffectType.SHIELD:
		fighter.guard()
		busy_until = time + 0.8
	elif fighter.kind not in RANGED and skill.target_type == SkillData.TargetType.FRONT_ENEMY and fighters.has(targets[0]):
		var target: FighterView = fighters[targets[0]]
		var spot := target.home - Vector2(signf(target.home.x - fighter.home.x) * 92.0, 0)
		impact = fighter.lunge(spot, skill.hit_count)
		busy_until = time + 0.24 + 0.23 * maxi(1, skill.hit_count) + 0.55
	else:
		var release := fighter.cast(skill.target_type == SkillData.TargetType.ALL_ENEMIES)
		impact = release + 0.26
		for target in targets:
			if fighters.has(target) and target != actor:
				launch(fighter, fighters[target], skill, release, 0.26)
		busy_until = time + impact + 0.45
	for target in targets:
		if fighters.has(target):
			react(fighters[target], target in missed, impact, target != actor and skill.effect_type != SkillData.EffectType.SHIELD)
	return impact


func launch(from: FighterView, to: FighterView, skill: SkillData, delay: float, travel: float) -> void:
	var missile := Missile.new()
	missile.color = MISSILE_COLORS.get(skill.damage_type, Color.WHITE)
	missile.arrow = from.kind == &"goblin_archer"
	var start := from.position + from.chest_offset() + Vector2(from.facing * 30.0, -20.0)
	var finish := to.home + to.chest_offset()
	missile.heading = (finish - start).normalized()
	missile.position = start
	missile.visible = false
	add_child(missile)
	var flight := missile.create_tween()
	flight.tween_interval(delay)
	flight.tween_callback(missile.show)
	var arc := -40.0 if not missile.arrow else -18.0
	flight.tween_method(func(t: float): missile.position = start.lerp(finish, t) + Vector2(0, sin(t * PI) * arc), 0.0, 1.0, travel)
	flight.tween_callback(missile.queue_free)


func react(fighter: FighterView, missed: bool, delay: float, struck: bool) -> void:
	var beat := fighter.create_tween()
	beat.tween_interval(delay)
	beat.tween_callback(func() -> void:
		fighter.thaw_hp()
		if not struck:
			return
		if missed:
			fighter.dodge()
		elif not fighter.unit.is_alive():
			fighter.fall()
		else:
			fighter.recoil())


func celebrate(victory: bool) -> void:
	var wait := animation_time_left() + 0.2
	for unit in fighters:
		var fighter: FighterView = fighters[unit]
		if not unit.is_alive() and not fighter.down:
			fighter.fall()
		elif (fighter.facing > 0.0) == victory:
			fighter.cheer(wait)
