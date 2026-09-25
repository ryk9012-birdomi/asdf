extends Control
## Journey summary after the boss falls or the party is wiped out.

var new_run_button: Button
var menu_button: Button


func _ready() -> void:
	var run := RunState.active
	theme = FantasyTheme.build()
	add_child(EmberBackdrop.new())
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	var won := run != null and run.victory
	AudioDirector.music("victory" if won else "defeat")
	var title := centered(column, "여정 완수" if won else "여정의 끝", 64, Color("f4e2b8") if won else Color("e0503f"), true)
	FantasyTheme.glow(title, Color("ff8a2a") if won else Color("8e1c12"), 16)
	var line := "잿불 사제가 쓰러지고, 고갯길 성소의 불꽃이 꺼졌다." if won else "잿빛 고갯길에 또 하나의 맹세가 묻혔다."
	centered(column, line, 17, FantasyTheme.TEXT)
	if run != null:
		var reached := run.current_floor() + 1
		var where := "보스" if run.current_floor() == RunMap.BOSS_FLOOR else "%d층" % reached
		centered(column, "도달: %s   ·   승리한 전투 %d   ·   골드 %d" % [where, run.battles_won, run.gold], 16, FantasyTheme.GOLD, true)
		var roster := PackedStringArray()
		for hero in run.party:
			roster.append("%s %d/%d" % [hero.definition.character_name, hero.current_hp, hero.max_hp()])
		centered(column, "   ·   ".join(roster), 14, FantasyTheme.MUTED)
	var gap := Control.new()
	gap.custom_minimum_size.y = 30
	column.add_child(gap)
	new_run_button = FantasyTheme.button(column, "새 여정", start_new_run, true)
	menu_button = FantasyTheme.button(column, "메인 메뉴", func(): leave(SceneRouter.MAIN_MENU), true)
	FantasyTheme.focus_later(new_run_button)


func centered(parent: Node, text_value: String, font_size: int, color: Color, heading: bool = false) -> Label:
	var item := FantasyTheme.label(parent, text_value, font_size, color, heading)
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return item


func start_new_run() -> void:
	RunState.begin_default(randi())
	SceneRouter.go(get_tree(), SceneRouter.MAP)


func leave(path: String) -> void:
	RunState.active = null
	SceneRouter.go(get_tree(), path)
