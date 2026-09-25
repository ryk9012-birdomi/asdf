extends SceneTree
## Run with --headless --path godot --script res://tests/test_flow.gd.

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("run_tests")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)


func settle() -> void:
	for _frame in 3:
		await process_frame


func run_tests() -> void:
	check(ProjectSettings.get_setting("application/run/main_scene") == SceneRouter.MAIN_MENU, "Project starts on the main menu")
	change_scene_to_file(SceneRouter.MAIN_MENU)
	await settle()
	var menu := current_scene
	check(menu.name == "MainMenu", "Main menu loads")
	check(menu.new_run_button.text == "새 여정" and not menu.new_run_button.disabled, "New journey is available")
	check(menu.continue_button.disabled, "Continue is disabled without a save")
	check(menu.camp_button.text == "야영지" and menu.quit_button.text == "종료", "Camp and quit entries exist")
	menu.new_run_button.pressed.emit()
	await settle()
	check(current_scene.name == "BattleScene", "New journey opens the battle")
	current_scene.view.menu_requested.emit()
	await settle()
	check(current_scene.name == "MainMenu", "Battle returns to the main menu")
	current_scene.camp_button.pressed.emit()
	await settle()
	check(current_scene.name == "CharacterLab", "Menu opens the camp")
	current_scene.get_node("%ResetButton").get_parent().get_node("MenuButton").pressed.emit()
	await settle()
	check(current_scene.name == "MainMenu", "Camp returns to the main menu")
	await create_timer(0.6).timeout
	var veils := root.get_children().filter(func(node): return node is CanvasLayer)
	check(veils.is_empty(), "Transition veils clean themselves up")
	print("Game flow: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
