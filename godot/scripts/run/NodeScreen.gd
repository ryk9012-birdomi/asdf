extends Control
## Non-combat map nodes: rest at a campfire, open a chest, or face a story event.

var run: RunState
var map_node: RunMap.MapNode
var story: Label
var outcome: Label
var actions: VBoxContainer
var party_box: VBoxContainer


func _ready() -> void:
	run = RunState.active
	if run == null or run.current_node() == null or run.node_resolved:
		back_to_map.call_deferred()
		return
	map_node = run.current_node()
	theme = FantasyTheme.build()
	AudioDirector.music("map")
	add_child(EmberBackdrop.new())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	panel.add_theme_stylebox_override("panel", FantasyTheme.panel(FantasyTheme.TRIM, 0.9, 30))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	FantasyTheme.label(column, "%d층   ·   %s" % [map_node.floor + 1, RunMap.TYPE_NAMES[map_node.type]], 13, FantasyTheme.TRIM)
	var title := FantasyTheme.label(column, "", 34, Color("f4e2b8"), true)
	FantasyTheme.glow(title, Color("ff8a2a"), 10)
	story = FantasyTheme.label(column, "", 16, FantasyTheme.TEXT)
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	party_box = VBoxContainer.new()
	party_box.add_theme_constant_override("separation", 10)
	column.add_child(party_box)
	outcome = FantasyTheme.label(column, "", 18, FantasyTheme.GOLD, true)
	outcome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	actions = VBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	column.add_child(actions)
	match map_node.type:
		RunMap.NodeType.REST:
			title.text = "모닥불"
			story.text = "바람을 막아 주는 바위 틈에서 일행이 모닥불을 피웠다. 잠시 몸을 누일 수 있을 것 같다."
			option("모닥불 곁에서 쉰다   (살아 있는 동료 HP %d%% 회복)" % roundi(RunState.REST_HEAL_FRACTION * 100), take_rest)
			option("쉬지 않고 길을 재촉한다", func(): finish("일행은 불씨를 밟아 끄고 다시 길을 나섰다."))
		RunMap.NodeType.TREASURE:
			title.text = "버려진 보물 상자"
			story.text = "무너진 순례자 초소 안쪽, 녹슨 자물쇠가 달린 상자가 먼지를 뒤집어쓰고 있다."
			option("상자를 연다", open_chest)
		_:
			var event := Events.for_node(run, map_node)
			title.text = event.title
			story.text = event.text
			for choice in event.choices:
				var caption: String = choice.label
				var odds := Events.describe_check(run, choice)
				if not odds.is_empty():
					caption += "\n      " + odds
				var item := option(caption, func(): choose(choice))
				item.disabled = not Events.affordable(run, choice)
				if item.disabled:
					item.tooltip_text = "골드가 부족합니다 (보유 %d)" % run.gold
	show_party()


func choose(choice: Dictionary) -> void:
	var result := Events.resolve(run, map_node, choice)
	var lines := PackedStringArray()
	if not result.roll.is_empty():
		AudioDirector.sfx("dice", 0.08)
		var roll: Dictionary = result.roll
		lines.append("2d6 [%d+%d]%s = %d  (목표 %d)  →  %s" % [roll.dice[0], roll.dice[1], (" %+d" % roll.bonus) if roll.bonus != 0 else "", roll.total, roll.target, "성공" if roll.passed else "실패"])
	var effects: Dictionary = result.effects
	if int(effects.get("gold", 0)) > 0:
		AudioDirector.sfx("coin", 0.02)
	if int(effects.get("heal", 0)) > 0 or int(effects.get("ward", 0)) > 0:
		AudioDirector.sfx("heal" if int(effects.get("heal", 0)) > 0 else "shield", 0.0)
	if effects.has("hurt"):
		AudioDirector.sfx("hit")
	lines.append(result.text)
	show_party()
	finish("\n".join(lines))


func option(caption: String, callback: Callable) -> Button:
	var item := FantasyTheme.button(actions, caption, callback)
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return item


func show_party() -> void:
	for child in party_box.get_children():
		child.queue_free()
	if map_node.type in [RunMap.NodeType.REST, RunMap.NodeType.EVENT]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		party_box.add_child(row)
		for hero in run.party:
			var slot := VBoxContainer.new()
			slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(slot)
			FantasyTheme.hero_row(slot, hero)
		if run.ward > 0:
			FantasyTheme.label(party_box, "축복: 다음 전투 시작 시 모두 보호막 +%d" % run.ward, 13, Color("9fc6ff"))
		FantasyTheme.label(party_box, "골드 %d" % run.gold, 13, FantasyTheme.GOLD)


func take_rest() -> void:
	var healed := run.rest()
	AudioDirector.sfx("heal", 0.0)
	show_party()
	finish("따뜻한 불 곁에서 상처를 돌봤다. 일행 HP %d 회복." % healed)


func open_chest() -> void:
	var gold := Encounters.gold_for(run, map_node)
	AudioDirector.sfx("coin", 0.02)
	run.gold += gold
	finish("상자 안에는 교단이 빼돌린 금화가 들어 있었다. 골드 +%d (보유 %d)" % [gold, run.gold])


func finish(message: String) -> void:
	run.resolve_current()
	outcome.text = message
	for child in actions.get_children():
		child.queue_free()
	var onward := FantasyTheme.button(actions, "지도로 돌아간다", func(): SceneRouter.go(get_tree(), SceneRouter.MAP))
	onward.name = "ContinueButton"
	onward.grab_focus.call_deferred()


func back_to_map() -> void:
	SceneRouter.go(get_tree(), SceneRouter.MAP)
