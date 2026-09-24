extends SceneTree
## Run with --headless --path godot --script res://tests/test_character_system.gd.

var checks: int = 0
var failures: int = 0
var deaths: int = 0
var health_events: int = 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)


func run_tests() -> void:
	var definition: CharacterData = load("res://data/classes/sword_master.tres")
	var unit_scene: PackedScene = load("res://scenes/battle/CharacterUnit.tscn")
	var first: CharacterUnit = unit_scene.instantiate()
	var second: CharacterUnit = unit_scene.instantiate()
	root.add_child(first)
	root.add_child(second)
	check(not first.is_alive(), "Uninitialized unit cannot act")
	check(not first.initialize(null), "Null definition is rejected")
	check(first.initialize(definition) and second.initialize(definition), "Shared definition initializes two units")
	first.unit_died.connect(func(_unit: CharacterUnit): deaths += 1)
	first.health_changed.connect(func(_hp: int, _max_hp: int): health_events += 1)
	check(first.receive_damage(30) == 20, "Shield absorbs the first ten damage")
	check(first.current_hp == 80 and first.current_shield == 0, "Damage crosses shield into health")
	check(second.current_hp == 100 and second.current_shield == 10, "Second instance remains independent")
	check(definition.max_hp == 100 and definition.starting_shield == 10, "Shared resource remains unchanged")
	check(health_events == 1, "HP signal emitted for actual health damage")
	check(first.receive_damage(-5) == 0 and first.heal(-5) == 0, "Negative health inputs are ignored")
	check(first.add_shield(-5) == 0 and first.restore_energy(-5) == 0, "Negative resource gains are ignored")
	check(not first.spend_energy(-1), "Negative costs cannot create energy")
	check(first.spend_energy(5) and first.current_energy == 0, "Exact energy cost succeeds")
	check(not first.spend_energy(1) and first.current_energy == 0, "Insufficient energy has no side effect")
	check(first.spend_energy(0), "Free costs work at zero energy")
	check(first.restore_energy(999) == 5, "Energy is capped at maximum")
	check(first.heal(999) == 20 and first.current_hp == 100, "Healing is capped at maximum")
	first.add_shield(20)
	check(first.receive_damage(5) == 0 and first.current_shield == 15, "Shield-only damage preserves HP")
	check(first.receive_damage(10, true) == 10 and first.current_shield == 15, "Explicit shield bypass preserves shield")
	first.receive_damage(9999)
	check(first.current_hp == 0 and first.current_shield == 0, "Overkill never makes HP or shield negative")
	first.receive_damage(9999)
	check(deaths == 1, "Death signal fires once per life")
	check(first.heal(10) == 0 and first.current_hp == 0, "Healing does not implicitly resurrect")
	check(first.add_shield(10) == 0 and not first.spend_energy(0), "Dead unit cannot gain shield or pay costs")
	check(first.restore_energy(10) == 0, "Dead unit cannot restore energy")
	var invalid := definition.duplicate() as CharacterData
	invalid.max_hp = 0
	check(not first.initialize(invalid) and first.current_hp == 0, "Invalid initialization is atomic")
	check(first.reset_to_starting_state() and first.is_alive(), "Explicit reset restores life")
	check(first.current_shield == 10 and first.current_energy == 5, "Reset restores original resources")
	first.receive_damage(9999)
	check(deaths == 2, "New life can emit a new death event")
	for role in ["sword_master", "vanguard", "sharpshooter"]:
		var sample: CharacterData = load("res://data/classes/%s.tres" % role)
		check(sample != null and sample.get_validation_errors().is_empty(), "Valid serialized class: " + role)
		check(sample.skills.size() == 2, "Two serialized skills: " + role)
		check(second.initialize(sample), "All class definitions can initialize a unit: " + role)
	first.free()
	second.free()
	await test_ui()
	print("Character system: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func test_ui() -> void:
	var lab: Control = load("res://scenes/main/CharacterLab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	var cards: HBoxContainer = lab.get_node("%Party")
	check(cards.get_child_count() == 3, "Main scene creates exactly three cards")
	var card = cards.get_child(0)
	check(card.unit.is_alive() and card.health_label.text == "HP   140 / 140", "Scene renders initial Vanguard HP")
	card.action_buttons[0].pressed.emit()
	check(card.unit.current_hp == 135 and card.health_label.text == "HP   135 / 140", "Damage button updates model and UI")
	card.action_buttons[1].pressed.emit()
	check(card.unit.current_hp == 140, "Heal button routes the correct action")
	card.action_buttons[2].pressed.emit()
	check(card.unit.current_shield == 20, "Shield button routes the correct action")
	card.action_buttons[3].pressed.emit()
	check(card.unit.current_energy == 3, "Energy button routes the correct action")
	card.action_buttons[4].pressed.emit()
	check(card.unit.current_energy == 5, "Recharge button routes the correct action")
	card.action_buttons[5].pressed.emit()
	check(not card.unit.is_alive() and card.action_buttons[0].disabled, "Death disables lab actions")
	lab.get_node("%ResetButton").pressed.emit()
	check(card.unit.is_alive() and not card.action_buttons[0].disabled, "Reset restores UI interaction")
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://test-output")
		var capture_result := root.get_texture().get_image().save_png("res://test-output/character-lab.png")
		check(capture_result == OK, "Rendered screenshot saved")
	lab.free()
