extends Control
## Reads battle state, emits commands. Never applies damage or advances turns.

signal skill_requested(skill: SkillData, target: CharacterUnit)
signal pass_requested
signal restart_requested
signal lab_requested

const CARD_SCRIPT = preload("res://scripts/ui/CombatantView.gd")
var battle: BattleManager
var selected_skill: SkillData
var cards: Dictionary = {}
var enemy_row: HBoxContainer
var party_row: HBoxContainer
var skill_row: HBoxContainer
var turn_label: Label
var prompt: Label
var result_label: Label
var log_box: RichTextLabel
var pass_button: Button
var log_lines: PackedStringArray = []


func _ready() -> void:
	var ui_theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "sans-serif"])
	ui_theme.default_font = font
	ui_theme.default_font_size = 14
	ui_theme.set_color("font_color", "Label", Color("e0e9f8"))
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color("21334c")
	button_style.set_corner_radius_all(6)
	button_style.content_margin_left = 16
	button_style.content_margin_right = 16
	button_style.content_margin_top = 10
	button_style.content_margin_bottom = 10
	ui_theme.set_stylebox("normal", "Button", button_style)
	theme = ui_theme
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	scroll.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 13)
	margin.add_child(content)
	label(content, "AFTERLIGHT TRAVERSE   /   COMBAT PROTOTYPE   /   002", 12, Color("69e6c3"))
	var header := HBoxContainer.new()
	content.add_child(header)
	label(header, "잔광 항로  /  봉쇄선 돌파", 30).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(header, "준비실", func(): lab_requested.emit())
	button(header, "전투 재시작", func(): restart_requested.emit())
	turn_label = label(content, "", 14, Color("efbb6e"))
	label(content, "HOSTILES  /  적 행동 예고 · 수치는 방어 적용 전", 12, Color("f08489"))
	enemy_row = row(content)
	label(content, "CREW  /  잔광 인양단", 12, Color("69e6c3"))
	party_row = row(content)
	result_label = label(content, "", 24, Color("efbb6e"))
	result_label.visible = false
	prompt = label(content, "", 16)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_row = row(content)
	label(content, "COMBAT LOG  /  전투 기록", 12, Color("69e6c3"))
	log_box = RichTextLabel.new()
	log_box.custom_minimum_size.y = 100
	log_box.add_theme_font_size_override("normal_font_size", 13)
	log_box.scroll_following = true
	content.add_child(log_box)
	label(content, "스킬 선택 → 초록색 대상 클릭  |  실드는 피해를 먼저 흡수  |  자기 차례 EN +1  |  재사용 대기는 자신의 턴 기준", 12, Color("93a5bd"))


func bind(manager: BattleManager) -> void:
	battle = manager
	for unit in battle.enemies + battle.party:
		var card := Button.new()
		card.set_script(CARD_SCRIPT)
		(enemy_row if unit in battle.enemies else party_row).add_child(card)
		card.setup(unit)
		card.pressed.connect(func(): choose_target(unit))
		cards[unit] = card
	refresh()


func refresh() -> void:
	selected_skill = null
	var names := PackedStringArray()
	for unit in battle.turns.upcoming():
		names.append(unit.display_name)
	turn_label.text = "ROUND %02d   /   %s" % [battle.turns.round_number, " → ".join(names)]
	result_label.visible = battle.phase == BattleManager.Phase.FINISHED
	result_label.text = "작전 성공 · 봉쇄선을 돌파했습니다" if battle.victory else "작전 실패 · 파티가 전멸했습니다"
	for child in skill_row.get_children():
		skill_row.remove_child(child)
		child.queue_free()
	if battle.phase == BattleManager.Phase.PLAYER_INPUT:
		prompt.text = "%s의 차례 · 사용할 스킬을 선택하세요." % battle.actor.display_name
		for skill in battle.actor.character_data.skills:
			var reason := battle.skill_block_reason(skill)
			var caption := "%s  /  EN %d" % [skill.skill_name, skill.energy_cost]
			if not reason.is_empty():
				caption += "\n" + reason
			var skill_button := button(skill_row, caption, func(): select_skill(skill))
			skill_button.disabled = not reason.is_empty()
			skill_button.tooltip_text = skill.description + "\n재사용 대기: %d턴" % skill.cooldown
		pass_button = button(skill_row, "대기", func(): pass_requested.emit())
	elif battle.phase == BattleManager.Phase.FINISHED:
		prompt.text = "전투 재시작으로 다시 도전할 수 있습니다."
	elif battle.phase == BattleManager.Phase.ENEMY_TURN:
		prompt.text = "%s · 행동 준비 중…" % battle.actor.display_name
	else:
		prompt.text = "행동 처리 중…"
	refresh_cards()


func select_skill(skill: SkillData) -> void:
	if battle.phase != BattleManager.Phase.PLAYER_INPUT or not battle.skill_block_reason(skill).is_empty():
		return
	selected_skill = skill
	prompt.text = "%s · %s  /  초록색 대상을 클릭하세요." % [skill.skill_name, skill.description]
	refresh_cards()


func choose_target(unit: CharacterUnit) -> void:
	if selected_skill != null and battle.phase == BattleManager.Phase.PLAYER_INPUT:
		skill_requested.emit(selected_skill, unit)


func refresh_cards() -> void:
	var legal: Array[CharacterUnit] = []
	if selected_skill != null and battle.phase == BattleManager.Phase.PLAYER_INPUT:
		legal = battle.available_targets(selected_skill)
	for unit in cards:
		var detail := "ATK %d  /  DEF %d  /  SPD %d" % [unit.attack, unit.defense, unit.speed]
		if unit is EnemyUnit and unit.is_alive():
			var before_turn: bool = unit != battle.actor or battle.phase != BattleManager.Phase.ENEMY_TURN
			var intent: SkillData = unit.intended_skill(before_turn)
			if intent != null:
				var amount := roundi(unit.attack * intent.attack_multiplier) + intent.flat_value
				detail = "예고: %s · %s %d" % [intent.skill_name, "실드" if intent.effect_type == SkillData.EffectType.SHIELD else "공격", amount]
			else:
				detail = "예고: 대기"
		cards[unit].refresh(unit == battle.actor and battle.phase != BattleManager.Phase.FINISHED, unit in legal, detail)


func animate_action(_actor: CharacterUnit, targets: Array[CharacterUnit], skill: SkillData) -> void:
	for target in targets:
		if cards.has(target):
			cards[target].flash(Color("7eddeb") if skill.effect_type == SkillData.EffectType.SHIELD else Color("ffaaa4"))


func append_log(message: String) -> void:
	log_lines.append(message)
	while log_lines.size() > 60:
		log_lines.remove_at(0)
	log_box.text = "\n".join(log_lines)


func label(parent: Node, text_value: String, size: int, color: Color = Color("e0e9f8")) -> Label:
	var item := Label.new()
	item.text = text_value
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", color)
	parent.add_child(item)
	return item


func row(parent: Node) -> HBoxContainer:
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", 12)
	parent.add_child(container)
	return container


func button(parent: Node, text_value: String, callback: Callable) -> Button:
	var item := Button.new()
	item.text = text_value
	item.pressed.connect(callback)
	parent.add_child(item)
	return item
