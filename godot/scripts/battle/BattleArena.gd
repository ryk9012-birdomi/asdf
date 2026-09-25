class_name BattleArena
extends Control
## 2D side-view battlefield: a torch-lit pass with the party on the left and foes on the
## right. Plays resolved actions as motion; it never changes game state.

signal unit_clicked(unit: CharacterUnit)

const RANGED := [&"wizard", &"goblin_archer", &"ember_priest", &"cult_hexer"]
const SPACING := 200.0
const MISSILE_COLORS := {
	SkillData.DamageType.PHYSICAL: Color("e8dcc0"),
	SkillData.DamageType.ARCANE: Color("b48cff"),
	SkillData.DamageType.FIRE: Color("ff7a1f"),
	SkillData.DamageType.RADIANT: Color("ffe08a"),
	SkillData.DamageType.TRUE_DAMAGE: Color("ffffff"),
}

var fighters: Dictionary = {}
var order: Array[CharacterUnit] = []
var busy_until: float = 0.0
var time: float = 0.0
var rocks: Array = []


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
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for index in 12:
		rocks.append([rng.randf(), rng.randf_range(0.0, 1.0), rng.randf_range(6.0, 16.0)])
	var embers := CPUParticles2D.new()
	embers.name = "Embers"
	embers.amount = 50
	embers.lifetime = 5.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(700, 10)
	embers.direction = Vector2.UP
	embers.spread = 20.0
	embers.gravity = Vector2(6, -12)
	embers.initial_velocity_min = 12.0
	embers.initial_velocity_max = 36.0
	embers.scale_amount_min = 1.5
	embers.scale_amount_max = 3.0
	embers.color = Color(1.0, 0.62, 0.25, 0.8)
	add_child(embers)


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func ground_y() -> float:
	return size.y - 26.0


func _draw() -> void:
	var w := size.x
	var h := size.y
	var horizon := h * 0.5
	# Cave wall silhouettes, far to near.
	for layer in 3:
		var shade := Color("0c0806").lerp(Color("20150e"), layer / 2.0)
		var points := PackedVector2Array([Vector2(0, 0)])
		var steps := 14
		for step in steps + 1:
			var x := w * step / float(steps)
			var y := horizon * (0.35 + 0.18 * layer) + sin(step * 1.7 + layer * 2.3) * 26.0 + cos(step * 0.9 + layer) * 18.0
			points.append(Vector2(x, y + layer * 22.0))
		points.append(Vector2(w, 0))
		if layer == 0:
			draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color("070504"))
		var floor_points := points.duplicate()
		floor_points[0] = Vector2(0, h)
		floor_points[floor_points.size() - 1] = Vector2(w, h)
		draw_colored_polygon(floor_points, Color(shade, 0.9))
	# Ruined pillars of the old pass shrine.
	for pillar in [[0.3, 0.62, 0.55], [0.71, 0.4, 0.5]]:
		var px: float = w * pillar[0]
		var top: float = horizon * pillar[1]
		draw_rect(Rect2(Vector2(px - 22, top), Vector2(44, horizon * 1.25 - top)), Color("2a2019"))
		draw_rect(Rect2(Vector2(px - 28, top - 10), Vector2(56, 12)), Color("352a20"))
		draw_line(Vector2(px - 8, top + 20), Vector2(px - 12, horizon * 1.1), Color("2a1f16"), 2.0)
	# Ground band with pebbles.
	var ground_top := h * 0.66
	for band in 8:
		var y := ground_top + (h - ground_top) * band / 8.0
		draw_rect(Rect2(Vector2(0, y), Vector2(w, (h - ground_top) / 8.0 + 1.0)), Color("1c140e").lerp(Color("2e2218"), band / 8.0))
	draw_line(Vector2(0, ground_top), Vector2(w, ground_top), Color("22170f"), 3.0)
	for rock in rocks:
		var rock_pos := Vector2(rock[0] * w, ground_top + 12.0 + rock[1] * (h - ground_top - 20.0))
		var flat := PackedVector2Array()
		for step in 10:
			var angle := TAU * step / 10.0
			flat.append(rock_pos + Vector2(cos(angle) * rock[2], sin(angle) * rock[2] * 0.4 - (rock[2] * 0.25 if sin(angle) < 0.0 else 0.0)))
		draw_colored_polygon(flat, Color("1e1610"))
		draw_line(rock_pos + Vector2(-rock[2] * 0.6, -rock[2] * 0.35), rock_pos + Vector2(rock[2] * 0.3, -rock[2] * 0.45), Color("3e2f24"), 2.0)
	# Torches at both edges with a flickering glow.
	for side in [0.035, 0.965]:
		var tx: float = w * side
		var ty := ground_top - 110.0
		var flicker := 0.85 + 0.15 * sin(time * 9.0 + side * 10.0) * sin(time * 4.3)
		for ring in 6:
			draw_circle(Vector2(tx, ty), (40.0 + ring * 38.0) * flicker, Color(1.0, 0.5, 0.18, 0.08 - ring * 0.011))
		# A warm pool of light on the ground under each torch; everything else stays dark.
		for ring in 5:
			var pool := PackedVector2Array()
			for step in 24:
				var angle := TAU * step / 24.0
				pool.append(Vector2(tx, ground_top + 30.0) + Vector2(cos(angle) * (70.0 + ring * 36.0), sin(angle) * (16.0 + ring * 8.0)) * flicker)
			draw_colored_polygon(pool, Color(1.0, 0.52, 0.2, 0.06 - ring * 0.01))
		draw_line(Vector2(tx, ty + 6), Vector2(tx, ground_top + 20), Color("2a1a10"), 6.0)
		var flame := PackedVector2Array()
		for step in 13:
			var t := TAU * step / 12.0
			var reach := 11.0 * (1.0 + 0.25 * sin(time * 12.0 + step))
			flame.append(Vector2(tx, ty) + Vector2(sin(t) * reach * 0.7, -cos(t) * reach - (reach * 0.9 if cos(t) > 0.0 else 0.0)))
		draw_colored_polygon(flame, Color(1.0, 0.55, 0.15, 0.9))
		draw_circle(Vector2(tx, ty), 5.0, Color(1.0, 0.9, 0.55))
	# Heavy vignette: sides, the cave roof and the near floor sink into darkness. It is
	# drawn under the fighters, so they stand out against it.
	for step in 16:
		var alpha := 0.07 * (16 - step) / 16.0
		draw_rect(Rect2(Vector2(step * 10.0, 0), Vector2(10, h)), Color(0, 0, 0, alpha * 2.4))
		draw_rect(Rect2(Vector2(w - (step + 1) * 10.0, 0), Vector2(10, h)), Color(0, 0, 0, alpha * 2.4))
		draw_rect(Rect2(Vector2(0, step * 10.0), Vector2(w, 10)), Color(0, 0, 0, alpha * 2.2))
		draw_rect(Rect2(Vector2(0, h - (step + 1) * 6.0), Vector2(w, 6)), Color(0, 0, 0, alpha * 1.6))


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
