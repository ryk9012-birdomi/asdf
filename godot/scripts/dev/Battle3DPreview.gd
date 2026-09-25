extends Node3D
## Test scene for a 3D battlefield seen from the side: free CC0 KayKit models in a dark,
## torch-lit cave, with overhead name/HP plates in 2D. Nothing in the game uses it yet.
## Open scenes/dev/Battle3DPreview.tscn and press F6; the figures act out a short loop.

const ADVENTURERS := "res://assets/models/kaykit/%s.glb"
const SKELETONS := "res://assets/models/kaykit_skeletons/%s"
## model · attached meshes to keep · tint · scale · idle and attack animations
const CAST := [
	{"name": "베윈란", "model": ADVENTURERS % "Knight", "keep": ["1H_Sword", "Badge_Shield", "Knight_Helmet", "Knight_Cape"],
		"spot": Vector3(-2.0, 0, 0.0), "attack": "1H_Melee_Attack_Chop", "hp": [10, 10]},
	{"name": "엘리키", "model": ADVENTURERS % "Rogue_Hooded", "keep": ["Knife", "Knife_Offhand", "Rogue_Cape"],
		"spot": Vector3(-3.7, 0, -0.9), "attack": "Dualwield_Melee_Attack_Stab", "hp": [8, 8]},
	{"name": "나레네", "model": ADVENTURERS % "Mage", "keep": ["2H_Staff", "Mage_Hat", "Mage_Cape"],
		"spot": Vector3(-5.4, 0, -1.8), "attack": "Spellcast_Shoot", "idle": "2H_Melee_Idle", "hp": [6, 6]},
	{"name": "고블린 약탈자", "model": ADVENTURERS % "Barbarian", "keep": ["1H_Axe", "Barbarian_Round_Shield"],
		"tint": Color(0.55, 0.78, 0.4), "scale": 0.78, "spot": Vector3(2.0, 0, 0.0), "attack": "1H_Melee_Attack_Slice_Horizontal", "hp": [6, 6]},
	{"name": "해골 병사", "model": SKELETONS % "Skeleton_Warrior.glb", "keep": ["Skeleton_Warrior_Helmet"], "blade": true, "shield": true,
		"spot": Vector3(3.7, 0, -0.9), "attack": "1H_Melee_Attack_Chop", "hp": [8, 8]},
	{"name": "해골 졸개", "model": SKELETONS % "Skeleton_Minion.glb", "keep": [], "blade": true,
		"spot": Vector3(5.4, 0, -1.8), "attack": "1H_Melee_Attack_Stab", "hp": [5, 5]},
]

var camera: Camera3D
var figures: Array[Dictionary] = []
var plates: Array[Dictionary] = []
var torches: Array[OmniLight3D] = []
var time: float = 0.0
var hud: CanvasLayer
## Off for scripted captures that trigger the moves themselves.
var autoplay := true


func _ready() -> void:
	build_set()
	for entry in CAST:
		figures.append(add_figure(entry))
	build_hud()
	if autoplay:
		run_demo()


func _process(delta: float) -> void:
	time += delta
	for index in torches.size():
		torches[index].light_energy = 2.4 + 0.35 * sin(time * 9.0 + index * 2.0) * sin(time * 4.1 + index)
	for index in plates.size():
		var plate: Dictionary = plates[index]
		var head: Vector3 = figures[index].node.global_position + Vector3(0, 2.9 * figures[index].scale, 0)
		plate.box.position = camera.unproject_position(head) - Vector2(plate.box.size.x / 2.0, plate.box.size.y)


func matte(color: Color, rough: float = 0.95) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = rough
	return material


func glow(color: Color, strength: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = strength
	return material


func build_set() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("050403")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.32, 0.36, 0.5)
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.1
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.08, 0.06, 0.05)
	environment.fog_density = 0.045
	environment.glow_enabled = true
	environment.glow_intensity = 0.9
	environment.glow_bloom = 0.15
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	# Cold, faint light from a crack in the cave roof: gives the figures a blue rim.
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-35, 150, 0)
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.light_energy = 0.5
	add_child(moon)
	# Warm fill from the viewer's side, as if a campfire burned behind the camera.
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 3.2, 6.5)
	fill.light_color = Color(1.0, 0.62, 0.36)
	fill.light_energy = 1.6
	fill.omni_range = 16.0
	fill.omni_attenuation = 1.2
	add_child(fill)
	for x in [-7.5, 0.0, 7.5]:
		var torch := OmniLight3D.new()
		torch.position = Vector3(x, 2.6, -2.0 if x != 0.0 else -4.2)
		torch.light_color = Color(1.0, 0.52, 0.2)
		torch.omni_range = 11.0
		torch.omni_attenuation = 1.4
		torch.shadow_enabled = true
		add_child(torch)
		torches.append(torch)
		var flame := MeshInstance3D.new()
		var flame_mesh := SphereMesh.new()
		flame_mesh.radius = 0.16
		flame_mesh.height = 0.46
		flame.mesh = flame_mesh
		flame.material_override = glow(Color(1.0, 0.55, 0.18), 5.0)
		flame.position = torch.position
		add_child(flame)
		var post := MeshInstance3D.new()
		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.06
		post_mesh.bottom_radius = 0.09
		post_mesh.height = 2.4
		post.mesh = post_mesh
		post.material_override = matte(Color("1a110b"))
		post.position = torch.position - Vector3(0, 1.35, 0)
		add_child(post)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 30)
	ground.mesh = plane
	var noise := FastNoiseLite.new()
	noise.frequency = 0.03
	var ramp := Gradient.new()
	ramp.set_color(0, Color("140e0a"))
	ramp.set_color(1, Color("3a2c20"))
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.color_ramp = ramp
	texture.seamless = true
	var ground_material := matte(Color.WHITE)
	ground_material.albedo_texture = texture
	ground_material.uv1_scale = Vector3(6, 6, 1)
	ground.material_override = ground_material
	add_child(ground)
	# Back wall of stacked boulders, then rubble and broken pillars.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for index in 40:
		var rock := MeshInstance3D.new()
		var rock_mesh := SphereMesh.new()
		rock_mesh.radius = rng.randf_range(1.0, 2.6)
		rock_mesh.height = rock_mesh.radius * rng.randf_range(1.2, 2.0)
		rock_mesh.radial_segments = 7
		rock_mesh.rings = 4
		rock.mesh = rock_mesh
		rock.material_override = matte(Color("1e1712").lerp(Color("3a2e24"), rng.randf()))
		rock.position = Vector3(rng.randf_range(-16, 16), rng.randf_range(0.0, 5.5), rng.randf_range(-9.5, -6.5))
		rock.rotation = Vector3(rng.randf() * 0.6, rng.randf() * TAU, rng.randf() * 0.6)
		add_child(rock)
	for index in 12:
		var pebble := MeshInstance3D.new()
		var pebble_mesh := SphereMesh.new()
		pebble_mesh.radius = rng.randf_range(0.15, 0.45)
		pebble_mesh.height = pebble_mesh.radius * 1.2
		pebble_mesh.radial_segments = 6
		pebble_mesh.rings = 3
		pebble.mesh = pebble_mesh
		pebble.material_override = matte(Color("2a2019"))
		pebble.position = Vector3(rng.randf_range(-8, 8), 0.05, rng.randf_range(-3.5, 1.8))
		add_child(pebble)
	for spec in [[-1.2, 3.8, -5.0], [4.6, 2.1, -5.4], [-6.4, 2.8, -5.6]]:
		var pillar := MeshInstance3D.new()
		var pillar_mesh := CylinderMesh.new()
		pillar_mesh.top_radius = 0.42
		pillar_mesh.bottom_radius = 0.52
		pillar_mesh.height = spec[1]
		pillar_mesh.radial_segments = 10
		pillar.mesh = pillar_mesh
		pillar.material_override = matte(Color("4a3e32"))
		pillar.position = Vector3(spec[0], spec[1] / 2.0, spec[2])
		add_child(pillar)
	var embers := CPUParticles3D.new()
	embers.amount = 70
	embers.lifetime = 5.0
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	embers.emission_box_extents = Vector3(10, 0.2, 3)
	embers.direction = Vector3.UP
	embers.spread = 25.0
	embers.gravity = Vector3(0.25, 0.3, 0)
	embers.initial_velocity_min = 0.2
	embers.initial_velocity_max = 0.5
	var ember_mesh := QuadMesh.new()
	ember_mesh.size = Vector2(0.04, 0.04)
	var ember_material := glow(Color(1.0, 0.55, 0.2), 4.0)
	ember_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	ember_mesh.material = ember_material
	embers.mesh = ember_mesh
	embers.position = Vector3(0, 0.2, -1)
	add_child(embers)
	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 41.0
	camera.position = Vector3(0, 2.3, 16.5)
	add_child(camera)
	camera.look_at(Vector3(0, 1.3, -0.8))


func add_figure(entry: Dictionary) -> Dictionary:
	var holder := Node3D.new()
	holder.position = entry.spot
	var facing := 1.0 if entry.spot.x < 0 else -1.0
	holder.rotation.y = PI / 2.0 * facing
	add_child(holder)
	var model: Node3D = load(entry.model).instantiate()
	var scale_by: float = entry.get("scale", 1.0)
	model.scale = Vector3.ONE * scale_by
	holder.add_child(model)
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.get_parent() is BoneAttachment3D and mesh.name not in entry.keep:
			mesh.visible = false
		for surface in mesh.get_surface_override_material_count():
			var base: Material = mesh.mesh.surface_get_material(surface)
			if base is StandardMaterial3D:
				# Less toy-like: rougher, a touch of sheen, darker tint where asked.
				var look: StandardMaterial3D = base.duplicate()
				look.roughness = 0.7
				look.metallic_specular = 0.6
				if entry.has("tint"):
					look.albedo_color = entry.tint
				mesh.set_surface_override_material(surface, look)
	var skeleton: Skeleton3D = null
	for node in model.find_children("*", "Skeleton3D", true, false):
		skeleton = node
	if entry.get("blade", false) and skeleton != null:
		attach(skeleton, "handslot.r", SKELETONS % "Skeleton_Blade.gltf")
	if entry.get("shield", false) and skeleton != null:
		attach(skeleton, "handslot.l", SKELETONS % "Skeleton_Shield_Small_A.gltf")
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	var idle: String = entry.get("idle", "Idle")
	for looping in [idle, "Running_A"]:
		if player.has_animation(looping):
			player.get_animation(looping).loop_mode = Animation.LOOP_LINEAR
	player.play(idle)
	player.seek(randf() * 1.5, true)
	return {"node": holder, "player": player, "idle": idle, "attack": entry.attack, "home": entry.spot, "scale": scale_by, "facing": facing, "down": false}


func attach(skeleton: Skeleton3D, bone: String, path: String) -> void:
	var slot := BoneAttachment3D.new()
	slot.bone_name = bone
	skeleton.add_child(slot)
	slot.add_child(load(path).instantiate())


func build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var title := Label.new()
	title.text = "3D 시범 장면  ·  옆에서 본 전투"
	title.position = Vector2(28, 18)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("f4e2b8"))
	hud.add_child(title)
	var note := Label.new()
	note.text = "KayKit 캐릭터 팩(CC0) 모델 · 횃불 그림자 · 안개 · 실제 애니메이션"
	note.position = Vector2(28, 58)
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color("a8977a"))
	hud.add_child(note)
	for index in CAST.size():
		var entry: Dictionary = CAST[index]
		var box := VBoxContainer.new()
		box.size = Vector2(170, 44)
		box.add_theme_constant_override("separation", 2)
		hud.add_child(box)
		var name_label := Label.new()
		name_label.text = entry.name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 17)
		name_label.add_theme_color_override("font_color", Color("f4e6c4"))
		name_label.add_theme_color_override("font_outline_color", Color("0b0806"))
		name_label.add_theme_constant_override("outline_size", 6)
		box.add_child(name_label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(150, 16)
		bar.max_value = entry.hp[1]
		bar.value = entry.hp[0]
		bar.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("4caf50") if entry.spot.x < 0 else Color("c0392b")
		var back := StyleBoxFlat.new()
		back.bg_color = Color(0.05, 0.03, 0.02, 0.9)
		back.border_color = Color(0.85, 0.7, 0.35, 0.8)
		back.set_border_width_all(1)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", back)
		box.add_child(bar)
		plates.append({"box": box, "bar": bar})


## A short loop: the knight charges the goblin, the mage blasts a skeleton, the skeleton
## warrior strikes back, the rogue finishes the minion, then everyone resets.
func run_demo() -> void:
	while is_inside_tree():
		await charge(0, 3)
		await cast(2, 4)
		await charge(4, 0)
		await charge(1, 5, true)
		await get_tree().create_timer(1.6).timeout
		reset()
		await get_tree().create_timer(0.6).timeout


func charge(from: int, to: int, lethal: bool = false) -> void:
	var attacker: Dictionary = figures[from]
	var target: Dictionary = figures[to]
	var spot: Vector3 = target.home - Vector3(1.1 * attacker.facing, 0, 0) + Vector3(0, 0, target.home.z - attacker.home.z) * 0.0
	spot.z = target.home.z
	attacker.player.play("Running_A", 0.1)
	var move := create_tween()
	move.tween_property(attacker.node, "position", spot, 0.45)
	await move.finished
	attacker.player.play(attacker.attack, 0.08)
	await get_tree().create_timer(0.35).timeout
	struck(to, 2, lethal)
	await get_tree().create_timer(0.5).timeout
	attacker.player.play("Walking_Backwards", 0.1)
	var back := create_tween()
	back.tween_property(attacker.node, "position", attacker.home, 0.6)
	await back.finished
	attacker.player.play(attacker.idle, 0.2)


func cast(from: int, to: int) -> void:
	var caster: Dictionary = figures[from]
	var target: Dictionary = figures[to]
	caster.player.play(caster.attack, 0.1)
	await get_tree().create_timer(0.45).timeout
	var bolt := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.14
	sphere.height = 0.28
	bolt.mesh = sphere
	bolt.material_override = glow(Color(0.5, 0.7, 1.0), 6.0)
	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 0.7, 1.0)
	light.light_energy = 3.0
	light.omni_range = 4.0
	bolt.add_child(light)
	add_child(bolt)
	bolt.global_position = caster.node.global_position + Vector3(0.6, 1.5, 0)
	var fly := create_tween()
	fly.tween_property(bolt, "global_position", target.node.global_position + Vector3(0, 1.2, 0), 0.4)
	await fly.finished
	bolt.queue_free()
	struck(to, 3, false)
	await get_tree().create_timer(0.4).timeout
	caster.player.play(caster.idle, 0.2)


func struck(index: int, damage: int, lethal: bool) -> void:
	var target: Dictionary = figures[index]
	var bar: ProgressBar = plates[index].bar
	bar.value = 0 if lethal else maxf(1, bar.value - damage)
	if lethal:
		target.down = true
		target.player.play("Death_A", 0.08)
	else:
		target.player.play("Hit_A", 0.05)
		await get_tree().create_timer(0.5).timeout
		if not target.down:
			target.player.play(target.idle, 0.2)


func reset() -> void:
	for index in figures.size():
		var figure: Dictionary = figures[index]
		figure.down = false
		figure.node.position = figure.home
		figure.player.play(figure.idle, 0.2)
		plates[index].bar.value = plates[index].bar.max_value
