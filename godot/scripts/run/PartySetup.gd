extends Control
## Before a journey: pick a class for each of the three places (repeats allowed). Names
## are drawn at random and can be redrawn. The preview is the battle puppet itself.

const PLACES := [
	["전열", "적의 근접 공격을 가장 먼저 받는 자리"],
	["중열", "근접 공격이 닿기 어려운 자리 (적 명중 −2)"],
	["후열", "가장 안전한 자리 (적 근접 명중 −4)"],
]
const ROLES := ["paladin", "rogue", "wizard"]
const TINTS := [Color("9fb8e8"), Color("a98bdb"), Color("6fa8ff")]

var classes: Array[String] = ["paladin", "rogue", "wizard"]
var names: Array[String] = ["", "", ""]
var rng := RandomNumberGenerator.new()
var slots: Array[Dictionary] = []
var start_button: Button


func _ready() -> void:
	theme = FantasyTheme.build()
	AudioDirector.music("menu")
	add_child(EmberBackdrop.new())
	rng.randomize()
	for index in classes.size():
		names[index] = Names.random(classes[index], rng, names)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	margin.add_child(page)
	var title := FantasyTheme.label(page, "일행 꾸리기", 34, Color("f4e2b8"), true)
	FantasyTheme.glow(title, Color("ff8a2a"), 10)
	FantasyTheme.label(page, "세 자리마다 직업을 고르세요. 같은 직업을 여러 명 둘 수도 있습니다. 이름은 무작위로 정해지며 다시 뽑을 수 있습니다.", 16, FantasyTheme.MUTED)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(row)
	for index in PLACES.size():
		slots.append(build_slot(row, index))
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	footer.alignment = BoxContainer.ALIGNMENT_END
	page.add_child(footer)
	FantasyTheme.button(footer, "메인 메뉴", func(): SceneRouter.go(get_tree(), SceneRouter.MAIN_MENU)).name = "BackButton"
	start_button = FantasyTheme.button(footer, "이 일행으로 출발", start_journey, true)
	start_button.name = "StartButton"
	for index in slots.size():
		refresh(index)
	FantasyTheme.focus_later(start_button)


func build_slot(row: HBoxContainer, index: int) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = "Slot_%d" % index
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", FantasyTheme.panel(TINTS[index].darkened(0.45), 0.9, 14))
	row.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	FantasyTheme.label(column, PLACES[index][0], 22, FantasyTheme.TRIM, true)
	FantasyTheme.label(column, PLACES[index][1], 13, FantasyTheme.MUTED)
	var picks := HBoxContainer.new()
	picks.add_theme_constant_override("separation", 6)
	column.add_child(picks)
	var group := ButtonGroup.new()
	var buttons := {}
	for role in ROLES:
		var definition: CharacterData = load(RunState.CLASSES[role])
		var pick := FantasyTheme.button(picks, definition.class_name_label, func(): choose(index, role))
		pick.name = "Class_%d_%s" % [index, role]
		pick.toggle_mode = true
		pick.button_group = group
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons[role] = pick
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 290)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(stage)
	var naming := HBoxContainer.new()
	naming.add_theme_constant_override("separation", 8)
	column.add_child(naming)
	var name_label := FantasyTheme.label(naming, "", 26, Color("f4e6c4"), true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var reroll := FantasyTheme.button(naming, "다른 이름", func(): rename(index))
	reroll.name = "Reroll_%d" % index
	var stats := FantasyTheme.label(column, "", 15, FantasyTheme.TEXT)
	var about := FantasyTheme.label(column, "", 14, FantasyTheme.MUTED)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var skills := FantasyTheme.label(column, "", 14, FantasyTheme.TEXT)
	skills.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return {"buttons": buttons, "stage": stage, "figure": null, "name": name_label, "stats": stats, "about": about, "skills": skills}


func choose(index: int, role: String) -> void:
	if classes[index] == role:
		return
	classes[index] = role
	var others: Array = names.duplicate()
	others.remove_at(index)
	names[index] = Names.random(role, rng, others)
	refresh(index)


func rename(index: int) -> void:
	names[index] = Names.random(classes[index], rng, names)
	slots[index].name.text = names[index]


func refresh(index: int) -> void:
	var slot: Dictionary = slots[index]
	var role := classes[index]
	var definition: CharacterData = load(RunState.CLASSES[role])
	slot.buttons[role].set_pressed_no_signal(true)
	slot.name.text = names[index]
	slot.stats.text = "HP %d · MP %d · 공격 %d · 방어 %d\n속도 %d · 명중 %+d · 치명 %d+" % [
		definition.max_hp, definition.max_energy, definition.attack, definition.defense,
		definition.speed, definition.hit_bonus, definition.crit_threshold]
	slot.about.text = definition.description
	var lines := PackedStringArray()
	for skill in definition.skills:
		lines.append("• %s (MP %d) — %s" % [skill.skill_name, skill.energy_cost, skill.description])
	slot.skills.text = "\n".join(lines)
	# Swap the preview puppet for the new class.
	var stage: Control = slot.stage
	if slot.figure != null:
		stage.remove_child(slot.figure)
		slot.figure.queue_free()
	var figure := FighterView.Figure.new()
	figure.name = "Preview"
	figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	figure.size = Vector2(300, 290)
	figure.position = Vector2(40, 0)
	figure.phase = index * 1.3
	figure.puppet = Puppet.create(StringName(role))
	figure.puppet.phase = figure.phase
	figure.add_child(figure.puppet)
	stage.add_child(figure)
	slot.figure = figure
	# A little flourish so the change reads: the new hero raises their weapon.
	var flourish := create_tween()
	figure.arm = -2.1
	figure.glow = 0.8
	flourish.tween_property(figure, "arm", 0.0, 0.5).set_delay(0.2)
	flourish.parallel().tween_property(figure, "glow", 0.0, 0.6).set_delay(0.2)


func start_journey() -> void:
	RunState.begin_party(rng.randi(), classes, names)
	SceneRouter.go(get_tree(), SceneRouter.MAP)
