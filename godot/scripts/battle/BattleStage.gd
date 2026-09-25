class_name BattleStage
extends SubViewportContainer
## Side-view 3D diorama of the fight. Presentation only: it mirrors CharacterUnits and
## plays animations for actions the rules have already resolved.

signal unit_clicked(unit: CharacterUnit)

const MODELS := "res://assets/models/kaykit/%s.glb"
## Look and moves per character id (enemies) or class id (heroes).
const LOOKS := {
	&"paladin": {"model": "Knight", "keep": ["1H_Sword", "Badge_Shield", "Knight_Helmet", "Knight_Cape"], "melee": "1H_Melee_Attack_Chop", "guard": "Block"},
	&"rogue": {"model": "Rogue", "keep": ["Knife", "Knife_Offhand", "Rogue_Cape"], "melee": "Dualwield_Melee_Attack_Chop", "idle": "Idle"},
	&"wizard": {"model": "Mage", "keep": ["2H_Staff", "Mage_Hat", "Mage_Cape"], "ranged": true, "cast": "Spellcast_Shoot", "idle": "2H_Melee_Idle"},
	&"goblin_raider": {"model": "Barbarian", "keep": ["1H_Axe", "Barbarian_Round_Shield"], "tint": Color(0.62, 0.84, 0.46), "scale": 0.8, "melee": "1H_Melee_Attack_Slice_Horizontal", "guard": "Block"},
	&"goblin_archer": {"model": "Rogue_Hooded", "keep": ["1H_Crossbow", "Rogue_Cape"], "tint": Color(0.6, 0.8, 0.45), "scale": 0.78, "ranged": true, "cast": "1H_Ranged_Shoot", "missile": "arrow"},
	&"hobgoblin_captain": {"model": "Barbarian", "keep": ["2H_Axe", "Barbarian_Hat", "Barbarian_Cape"], "tint": Color(0.95, 0.62, 0.5), "scale": 1.12, "melee": "2H_Melee_Attack_Chop", "guard": "Cheer", "idle": "2H_Melee_Idle"},
	&"ember_priest": {"model": "Mage", "keep": ["2H_Staff", "Spellbook_open", "Mage_Hat", "Mage_Cape"], "tint": Color(0.95, 0.5, 0.55), "scale": 1.15, "ranged": true, "cast": "Spellcast_Shoot", "idle": "2H_Melee_Idle"},
}
const MISSILE_COLORS := {
	SkillData.DamageType.PHYSICAL: Color("e8dcc0"),
	SkillData.DamageType.ARCANE: Color("b48cff"),
	SkillData.DamageType.FIRE: Color("ff7a1f"),
	SkillData.DamageType.RADIANT: Color("ffe08a"),
	SkillData.DamageType.TRUE_DAMAGE: Color("ffffff"),
}

var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var figures: Dictionary = {}
var torches: Array[OmniLight3D] = []
var busy_until: float = 0.0
var time: float = 0.0


class Figure extends Node3D:
	## One combatant on stage: the imported model, its animations and its floor ring.
	var unit: CharacterUnit
	var look: Dictionary
	var player: AnimationPlayer
	var ring: MeshInstance3D
	var ring_material: StandardMaterial3D
	var home: Vector3
	var facing: float = 1.0
	var down: bool = false

	func idle_name() -> String:
		return look.get("idle", "Idle")

	func play(animation: String, blend: float = 0.12) -> void:
		if player != null and player.has_animation(animation):
			player.play(animation, blend)

	func settle() -> void:
		if not down:
			play(idle_name(), 0.2)


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	build_set()


func _process(delta: float) -> void:
	time += delta
	for index in torches.size():
		torches[index].light_energy = 2.4 + 0.5 * sin(time * 9.0 + index * 2.1) * sin(time * 4.3 + index)
	for figure in figures.values():
		if figure.ring.visible:
			figure.ring.scale = Vector3.ONE * (1.0 + 0.06 * sin(time * 5.0))


func build_set() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("140d08")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.5, 0.4)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.22, 0.13, 0.08)
	environment.fog_density = 0.035
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 28, 0)
	sun.light_color = Color(1.0, 0.86, 0.7)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	world.add_child(sun)
	for side in [-1.0, 1.0]:
		var torch := OmniLight3D.new()
		torch.position = Vector3(side * 7.2, 2.4, -2.2)
		torch.light_color = Color(1.0, 0.55, 0.22)
		torch.omni_range = 10.0
		world.add_child(torch)
		torches.append(torch)
		var flame := MeshInstance3D.new()
		var flame_mesh := SphereMesh.new()
		flame_mesh.radius = 0.18
		flame_mesh.height = 0.5
		flame.mesh = flame_mesh
		flame.material_override = glow_material(Color(1.0, 0.6, 0.2), 3.0)
		flame.position = torch.position
		world.add_child(flame)
		var post := MeshInstance3D.new()
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.07
		post_mesh.bottom_radius = 0.1
		post_mesh.height = 2.3
		post.mesh = post_mesh
		post.material_override = matte(Color("2a1a10"))
		post.position = torch.position - Vector3(0, 1.3, 0)
		world.add_child(post)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(44, 20)
	ground.mesh = plane
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	var ramp := Gradient.new()
	ramp.set_color(0, Color("2a1d13"))
	ramp.set_color(1, Color("4d3a28"))
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.color_ramp = ramp
	texture.seamless = true
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_texture = texture
	ground_material.uv1_scale = Vector3(5, 5, 1)
	ground_material.roughness = 1.0
	ground.material_override = ground_material
	world.add_child(ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for index in 14:
		var rock := MeshInstance3D.new()
		var rock_mesh := SphereMesh.new()
		rock_mesh.radius = rng.randf_range(0.6, 1.8)
		rock_mesh.height = rock_mesh.radius * rng.randf_range(1.0, 1.8)
		rock_mesh.radial_segments = 7
		rock_mesh.rings = 4
		rock.mesh = rock_mesh
		rock.material_override = matte(Color("3a2c21").lerp(Color("5a4636"), rng.randf()))
		rock.position = Vector3(rng.randf_range(-13, 13), rock_mesh.height * 0.25, rng.randf_range(-9.5, -5.0))
		rock.rotation = Vector3(rng.randf() * 0.4, rng.randf() * TAU, rng.randf() * 0.4)
		world.add_child(rock)
	for x in [-3.6, 3.9]:
		var pillar := MeshInstance3D.new()
		var pillar_mesh := CylinderMesh.new()
		pillar_mesh.top_radius = 0.42
		pillar_mesh.bottom_radius = 0.5
		pillar_mesh.height = 3.4 if x < 0 else 1.9
		pillar_mesh.radial_segments = 8
		pillar.mesh = pillar_mesh
		pillar.material_override = matte(Color("6b5a48"))
		pillar.position = Vector3(x, pillar_mesh.height / 2.0, -4.2)
		world.add_child(pillar)
	var embers := CPUParticles3D.new()
	embers.amount = 60
	embers.lifetime = 4.0
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	embers.emission_box_extents = Vector3(10, 0.2, 3)
	embers.direction = Vector3.UP
	embers.spread = 25.0
	embers.gravity = Vector3(0.3, 0.35, 0)
	embers.initial_velocity_min = 0.2
	embers.initial_velocity_max = 0.6
	var ember_mesh := QuadMesh.new()
	ember_mesh.size = Vector2(0.05, 0.05)
	var ember_material := glow_material(Color(1.0, 0.6, 0.25), 2.5)
	ember_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	ember_mesh.material = ember_material
	embers.mesh = ember_mesh
	embers.position = Vector3(0, 0.2, -1)
	world.add_child(embers)
	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 50.0
	camera.position = Vector3(0, 3.1, 12.8)
	world.add_child(camera)
	camera.look_at(Vector3(0, 1.1, -0.8))


func matte(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material


func glow_material(color: Color, strength: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = strength
	return material


func setup(party: Array[CharacterUnit], enemies: Array[CharacterUnit]) -> void:
	for side in [party, enemies]:
		var sign := -1.0 if side == party else 1.0
		for index in side.size():
			var unit: CharacterUnit = side[index]
			var slot: int = mini(index, 2)
			var extra: int = index - slot
			var spot := Vector3(sign * (1.7 + slot * 1.6 + extra * 0.95), 0, -slot * 0.7 + extra * 0.95)
			add_figure(unit, spot, -sign)


func add_figure(unit: CharacterUnit, spot: Vector3, facing: float) -> void:
	var look: Dictionary = LOOKS.get(unit.character_data.id, LOOKS.get(unit.character_data.class_id, LOOKS[&"goblin_raider"]))
	var figure := Figure.new()
	figure.unit = unit
	figure.look = look
	figure.home = spot
	figure.facing = facing
	figure.position = spot
	figure.rotation.y = PI / 2.0 * facing
	world.add_child(figure)
	var model: Node3D = load(MODELS % look.model).instantiate()
	model.scale = Vector3.ONE * float(look.get("scale", 1.0))
	figure.add_child(model)
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.get_parent() is BoneAttachment3D and mesh.name not in look.keep:
			mesh.visible = false
		if look.has("tint"):
			for surface in mesh.get_surface_override_material_count():
				var base: Material = mesh.mesh.surface_get_material(surface)
				if base is StandardMaterial3D:
					var tinted: StandardMaterial3D = base.duplicate()
					tinted.albedo_color = look.tint
					mesh.set_surface_override_material(surface, tinted)
	figure.player = model.find_child("AnimationPlayer", true, false)
	for looping in ["Idle", "2H_Melee_Idle", "Running_A", "Cheer"]:
		if figure.player.has_animation(looping):
			figure.player.get_animation(looping).loop_mode = Animation.LOOP_LINEAR
	figure.player.animation_finished.connect(func(_name: StringName): figure.settle())
	figure.player.speed_scale = 1.0 + (hash(unit.get_instance_id()) % 7) * 0.02
	figure.settle()
	figure.player.seek(float(hash(unit.get_instance_id()) % 100) / 100.0, true)
	figure.ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.68
	figure.ring.mesh = torus
	figure.ring.scale = Vector3.ONE
	figure.ring_material = glow_material(Color.WHITE, 2.0)
	figure.ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	figure.ring.material_override = figure.ring_material
	figure.ring.position = Vector3(0, 0.04, 0)
	figure.ring.visible = false
	figure.add_child(figure.ring)
	figures[unit] = figure


## Gold ring under the actor, pulsing green rings under legal targets.
func set_marks(active: CharacterUnit, legal: Array[CharacterUnit]) -> void:
	for unit in figures:
		var figure: Figure = figures[unit]
		var color := Color(0.43, 0.88, 0.55, 0.85) if unit in legal else Color(1.0, 0.76, 0.35, 0.8)
		figure.ring.visible = (unit in legal or unit == active) and unit.is_alive()
		figure.ring_material.albedo_color = color
		figure.ring_material.emission = color


## Where a unit's head sits in this control's local coordinates.
func screen_point(unit: CharacterUnit, height: float = 2.2) -> Vector2:
	if not figures.has(unit) or camera == null:
		return size / 2.0
	var figure: Figure = figures[unit]
	var point := camera.unproject_position(figure.global_position + Vector3(0, height * float(figure.look.get("scale", 1.0)), 0))
	return point * (size / Vector2(viewport.size)) if viewport.size.x > 0 else point


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var best: CharacterUnit = null
		var best_distance := 70.0
		for unit in figures:
			var distance: float = screen_point(unit, 1.1).distance_to(event.position)
			if distance < best_distance and unit.is_alive():
				best = unit
				best_distance = distance
		if best != null:
			unit_clicked.emit(best)
			accept_event()


func animation_time_left() -> float:
	return maxf(0.0, busy_until - time)


## Plays one resolved action. Returns seconds until the blow lands, so the UI can time
## numbers and sparks to the impact. `missed` lists targets whose roll failed.
func perform(actor: CharacterUnit, targets: Array[CharacterUnit], skill: SkillData, missed: Array[CharacterUnit]) -> float:
	if not figures.has(actor):
		return 0.0
	var figure: Figure = figures[actor]
	var impact := 0.35
	if skill.effect_type == SkillData.EffectType.SHIELD:
		figure.play(figure.look.get("guard", "Spellcast_Raise"))
		busy_until = time + 1.0
	elif not figure.look.get("ranged", false) and skill.target_type == SkillData.TargetType.FRONT_ENEMY and figures.has(targets[0]):
		impact = charge(figure, figures[targets[0]])
	else:
		impact = 0.55
		var long_cast := skill.target_type == SkillData.TargetType.ALL_ENEMIES
		figure.play("Spellcast_Long" if long_cast else figure.look.get("cast", "Spellcast_Shoot"))
		if long_cast:
			impact = 0.95
		for target in targets:
			if figures.has(target):
				launch(figure, figures[target], skill, impact - 0.28, 0.28)
		busy_until = time + impact + 0.7
	for target in targets:
		if figures.has(target) and target != actor:
			react(figures[target], target in missed, impact, skill)
	return impact


func charge(figure: Figure, target: Figure) -> float:
	# Stop just short of the target, on the attacker's side.
	var reach := Vector3(target.home.x - signf(target.home.x - figure.home.x) * 1.25, 0, target.home.z + 0.15)
	var attack_name: String = figure.look.get("melee", "1H_Melee_Attack_Chop")
	var dash := 0.28
	var swing := 0.4
	var move := figure.create_tween()
	figure.play("Running_A", 0.08)
	move.tween_property(figure, "position", reach, dash).set_trans(Tween.TRANS_SINE)
	move.tween_callback(func(): figure.play(attack_name, 0.05))
	move.tween_interval(swing + 0.45)
	move.tween_callback(func(): figure.play("Walking_Backwards", 0.1))
	move.tween_property(figure, "position", figure.home, 0.34).set_trans(Tween.TRANS_SINE)
	move.tween_callback(figure.settle)
	busy_until = time + dash + swing + 0.45 + 0.4
	return dash + swing


func launch(from: Figure, to: Figure, skill: SkillData, delay: float, travel: float) -> void:
	var color: Color = MISSILE_COLORS.get(skill.damage_type, Color.WHITE)
	var bolt := MeshInstance3D.new()
	if from.look.get("missile", "") == "arrow":
		var shaft := BoxMesh.new()
		shaft.size = Vector3(0.55, 0.04, 0.04)
		bolt.mesh = shaft
		bolt.material_override = matte(Color("8a6a40"))
	else:
		var orb := SphereMesh.new()
		orb.radius = 0.16 if skill.damage_type != SkillData.DamageType.FIRE else 0.24
		orb.height = orb.radius * 2.0
		bolt.mesh = orb
		bolt.material_override = glow_material(color, 4.0)
		var light := OmniLight3D.new()
		light.light_color = color
		light.omni_range = 2.5
		light.light_energy = 2.0
		bolt.add_child(light)
	var scale_from := float(from.look.get("scale", 1.0))
	var scale_to := float(to.look.get("scale", 1.0))
	var start := from.home + Vector3(signf(to.home.x - from.home.x) * 0.5, 1.35 * scale_from, 0)
	var finish := to.home + Vector3(0, 1.2 * scale_to, 0)
	bolt.position = start
	bolt.visible = false
	world.add_child(bolt)
	var flight := bolt.create_tween()
	flight.tween_interval(maxf(delay, 0.0))
	flight.tween_callback(bolt.show)
	flight.tween_method(func(t: float):
		bolt.position = start.lerp(finish, t) + Vector3(0, sin(t * PI) * 0.6, 0), 0.0, 1.0, travel)
	flight.tween_callback(bolt.queue_free)


func react(figure: Figure, missed: bool, delay: float, skill: SkillData) -> void:
	var beat := figure.create_tween()
	beat.tween_interval(delay)
	if missed:
		var away := figure.home + Vector3(signf(figure.home.x) * 0.6, 0, 0)
		beat.tween_callback(func(): figure.play("Dodge_Backward", 0.05))
		beat.tween_property(figure, "position", away, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		beat.tween_property(figure, "position", figure.home, 0.3).set_trans(Tween.TRANS_SINE)
		return
	if skill.effect_type == SkillData.EffectType.SHIELD:
		return
	beat.tween_callback(func():
		if not figure.unit.is_alive():
			figure.down = true
			figure.ring.visible = false
			figure.play("Death_A", 0.08)
		else:
			figure.play("Hit_A" if randf() < 0.5 else "Hit_B", 0.05))
	var knock := figure.home + Vector3(signf(figure.home.x) * 0.25, 0, 0)
	beat.tween_property(figure, "position", knock, 0.08)
	beat.tween_property(figure, "position", figure.home, 0.25)


## Winners cheer once the fight is over.
func celebrate(victory: bool) -> void:
	for unit in figures:
		var figure: Figure = figures[unit]
		var winner := (figure.home.x < 0.0) == victory
		if winner and not figure.down:
			var cheer := figure.create_tween()
			cheer.tween_interval(maxf(animation_time_left(), 0.3))
			cheer.tween_callback(func(): figure.play("Cheer", 0.2))
