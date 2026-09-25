extends Control
## Reads battle state, emits commands. Never applies damage or advances turns.

signal skill_requested(skill: SkillData, target: CharacterUnit)
signal pass_requested
signal restart_requested
signal lab_requested
signal menu_requested

const CARD_SCRIPT = preload("res://scripts/ui/CombatantView.gd")
const STAGGER := 40
const TRIM := Color("d8b25a")
const GOLD := Color("ffc15a")
const RED := Color("d9533f")
const TEXT := Color("eadcc0")
const MUTED := Color("a8977a")
const WARD := Color("9fc6ff")
const SERIF := ["Batang", "Noto Serif CJK KR", "Noto Serif KR", "Nanum Myeongjo", "serif"]

var battle: BattleManager
var selected_skill: SkillData
var cards: Dictionary = {}
var party_column: VBoxContainer
var enemy_column: VBoxContainer
var skill_row: HBoxContainer
var turn_row: HBoxContainer
var turn_label: Label
var prompt: Label
var result_banner: PanelContainer
var result_label: Label
var log_box: RichTextLabel
var pass_button: Button
var log_lines: PackedStringArray = []
var scroll: ScrollContainer
var fx_layer: Control
var popup_stacks: Dictionary = {}
var dice_stacks: Dictionary = {}


class DicePair extends Control:
	## Two drawn six-sided dice; faces are set by the caller while tumbling and on landing.
	const PIPS := {
		1: [Vector2(0, 0)],
		2: [Vector2(-1, -1), Vector2(1, 1)],
		3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
		4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
		5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
		6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)],
	}
	const SIDE := 34.0
	var faces: Array[int] = [1, 1]
	var rim: Color = Color("c9a24a")

	func set_faces(first: int, second: int) -> void:
		faces = [first, second]
		queue_redraw()

	func _draw() -> void:
		for index in 2:
			var rect := Rect2(Vector2(index * (SIDE + 8.0), 0), Vector2(SIDE, SIDE))
			var box := StyleBoxFlat.new()
			box.bg_color = Color("f1e3c2")
			box.border_color = rim
			box.set_border_width_all(2)
			box.set_corner_radius_all(7)
			box.shadow_color = Color(0, 0, 0, 0.55)
			box.shadow_size = 5
			draw_style_box(box, rect)
			for pip in PIPS[faces[index]]:
				draw_circle(rect.get_center() + pip * SIDE * 0.26, 3.4, Color("5a1d14"))
var screen_tween: Tween


func _ready() -> void:
	theme = build_theme()
	add_child(EmberBackdrop.new())
	scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	fx_layer = Control.new()
	fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_layer)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	scroll.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	label(content, "OATH OF EMBERS   ·   CHAPTER I   ·   잿빛 고갯길", 12, TRIM)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	content.add_child(header)
	var title := label(header, "잿불 서약  ·  고갯길 매복", 34, Color("f4e2b8"))
	title.theme_type_variation = "HeadingLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	glow_text(title, Color("ff9a3c"), 10)
	button(header, "메인 메뉴", func(): menu_requested.emit())
	button(header, "야영지", func(): lab_requested.emit())
	button(header, "전투 재시작", func(): restart_requested.emit())
	var turn_strip := HBoxContainer.new()
	turn_strip.add_theme_constant_override("separation", 12)
	content.add_child(turn_strip)
	turn_label = label(turn_strip, "", 16, GOLD)
	turn_label.theme_type_variation = "HeadingLabel"
	glow_text(turn_label, GOLD, 6)
	turn_row = HBoxContainer.new()
	turn_row.add_theme_constant_override("separation", 6)
	turn_strip.add_child(turn_row)
	content.add_child(build_battlefield())
	result_banner = PanelContainer.new()
	result_banner.add_theme_stylebox_override("panel", panel_style(GOLD, 0.92, 18))
	result_banner.visible = false
	content.add_child(result_banner)
	result_label = label(result_banner, "", 30, GOLD)
	result_label.theme_type_variation = "HeadingLabel"
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glow_text(result_label, GOLD, 14)
	result_label.visible = false
	var command := PanelContainer.new()
	command.add_theme_stylebox_override("panel", panel_style(Color("7a5c2e"), 0.86))
	content.add_child(command)
	var command_body := VBoxContainer.new()
	command_body.add_theme_constant_override("separation", 10)
	command.add_child(command_body)
	prompt = label(command_body, "", 16)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_row = row(command_body)
	skill_row.custom_minimum_size.y = 56
	var log_panel := PanelContainer.new()
	log_panel.add_theme_stylebox_override("panel", panel_style(Color("5e4526"), 0.8))
	content.add_child(log_panel)
	var log_body := VBoxContainer.new()
	log_panel.add_child(log_body)
	label(log_body, "모험 일지  ·  ADVENTURE LOG", 12, TRIM)
	log_box = RichTextLabel.new()
	log_box.custom_minimum_size.y = 92
	log_box.add_theme_font_size_override("normal_font_size", 13)
	log_box.add_theme_color_override("default_color", Color("d6c7a8"))
	log_box.scroll_following = true
	log_body.add_child(log_box)
	label(content, "판정: 2d6 + 명중 − 방어  →  7~9 스침(피해 절반) · 10+ 명중 · 주사위 눈이 치명 기준 이상이면 치명타(2배)  |  보호막이 피해를 먼저 흡수  |  자기 차례 기력 +1", 12, MUTED)


func build_battlefield() -> Control:
	var field := HBoxContainer.new()
	field.add_theme_constant_override("separation", 10)
	party_column = side_column(field, "일행  ·  잿불 서약단", TRIM, HORIZONTAL_ALIGNMENT_LEFT)
	var divider := VBoxContainer.new()
	divider.custom_minimum_size.x = 64
	divider.alignment = BoxContainer.ALIGNMENT_CENTER
	field.add_child(divider)
	divider.add_child(beam_rule())
	var versus := label(divider, "VS", 28, Color("f4e2b8"))
	versus.theme_type_variation = "HeadingLabel"
	versus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glow_text(versus, Color("ff8a2a"), 14)
	divider.add_child(beam_rule())
	enemy_column = side_column(field, "적대  ·  예고 적중률은 2d6 판정 기준", RED, HORIZONTAL_ALIGNMENT_RIGHT)
	return field


func side_column(parent: Node, heading: String, color: Color, align: HorizontalAlignment) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	parent.add_child(column)
	var caption := label(column, heading, 12, color)
	caption.horizontal_alignment = align
	return column


func beam_rule() -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.85, 0.7, 0.35, 0.0))
	gradient.set_color(1, Color(1.0, 0.55, 0.2, 0.9))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 2
	texture.height = 64
	var rule := TextureRect.new()
	rule.texture = texture
	rule.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rule.stretch_mode = TextureRect.STRETCH_SCALE
	rule.custom_minimum_size = Vector2(2, 150)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return rule


func bind(manager: BattleManager) -> void:
	battle = manager
	for unit in battle.party + battle.enemies:
		var hostile := unit in battle.enemies
		var card := Button.new()
		card.set_script(CARD_SCRIPT)
		# Front line sits closest to the centre divider on both sides.
		var lane := MarginContainer.new()
		var inset := (2 - int(unit.formation_slot)) * STAGGER
		lane.add_theme_constant_override("margin_right" if hostile else "margin_left", inset)
		lane.add_theme_constant_override("margin_left" if hostile else "margin_right", 2 * STAGGER - inset)
		(enemy_column if hostile else party_column).add_child(lane)
		lane.add_child(card)
		card.setup(unit, hostile)
		card.pressed.connect(func(): choose_target(unit))
		unit.unit_died.connect(func(_unit: CharacterUnit): on_unit_down(unit))
		cards[unit] = card
	refresh()


func refresh() -> void:
	selected_skill = null
	refresh_turn_order()
	var finished := battle.phase == BattleManager.Phase.FINISHED
	if finished and not result_banner.visible:
		reveal_result()
	result_banner.visible = finished
	result_label.visible = finished
	for child in skill_row.get_children():
		skill_row.remove_child(child)
		child.queue_free()
	if battle.phase == BattleManager.Phase.PLAYER_INPUT:
		prompt.text = "%s의 차례 · 사용할 스킬을 선택하세요." % battle.actor.display_name
		for skill in battle.actor.character_data.skills:
			var reason := battle.skill_block_reason(skill)
			var caption := "%s\n기력 %d  ·  대기 %d턴" % [skill.skill_name, skill.energy_cost, skill.cooldown]
			if not reason.is_empty():
				caption = "%s\n%s" % [skill.skill_name, reason]
			var skill_button := button(skill_row, caption, func(): select_skill(skill), battle.actor.character_data.display_color)
			skill_button.disabled = not reason.is_empty()
			skill_button.custom_minimum_size = Vector2(170, 56)
			skill_button.tooltip_text = skill.description + "\n재사용 대기: %d턴" % skill.cooldown
		pass_button = button(skill_row, "대기\n턴 넘기기", func(): pass_requested.emit())
		pass_button.custom_minimum_size = Vector2(110, 56)
	elif finished:
		prompt.text = "전투 재시작으로 다시 도전하거나 메인 메뉴로 돌아갈 수 있습니다."
	elif battle.phase == BattleManager.Phase.ENEMY_TURN:
		prompt.text = "%s · 행동 준비 중…" % battle.actor.display_name
	else:
		prompt.text = "행동 처리 중…"
	refresh_cards()


func refresh_turn_order() -> void:
	turn_label.text = "제 %d 라운드  ·  주도권" % battle.turns.round_number
	for child in turn_row.get_children():
		turn_row.remove_child(child)
		child.queue_free()
	var first := true
	for unit in battle.turns.upcoming():
		var color: Color = unit.character_data.display_color
		var chip := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = color.darkened(0.78 if not first else 0.55)
		style.border_color = color if first else color.darkened(0.4)
		style.set_border_width_all(2 if first else 1)
		style.set_corner_radius_all(12)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		if first:
			style.shadow_color = Color(color, 0.45)
			style.shadow_size = 8
		chip.add_theme_stylebox_override("panel", style)
		turn_row.add_child(chip)
		label(chip, unit.display_name, 13, TEXT if first else color.lightened(0.2))
		first = false


func select_skill(skill: SkillData) -> void:
	if battle.phase != BattleManager.Phase.PLAYER_INPUT or not battle.skill_block_reason(skill).is_empty():
		return
	selected_skill = skill
	prompt.text = "%s · %s  /  초록빛 대상을 클릭하세요." % [skill.skill_name, skill.description]
	refresh_cards()


func choose_target(unit: CharacterUnit) -> void:
	if selected_skill != null and battle.phase == BattleManager.Phase.PLAYER_INPUT:
		skill_requested.emit(selected_skill, unit)


func refresh_cards() -> void:
	var legal: Array[CharacterUnit] = []
	if selected_skill != null and battle.phase == BattleManager.Phase.PLAYER_INPUT:
		legal = battle.available_targets(selected_skill)
	for unit in cards:
		var detail := "ATK %d  ·  방어 %d  ·  명중 %+d  ·  SPD %d" % [unit.attack, unit.defense, unit.hit_bonus, unit.speed]
		if unit in legal:
			detail = forecast(battle.actor, unit, selected_skill)
		elif unit is EnemyUnit and unit.is_alive():
			detail = intent_text(unit)
		cards[unit].refresh(unit == battle.actor and battle.phase != BattleManager.Phase.FINISHED, unit in legal, detail)


## Exact outcome chances of `skill` from `attacker` against `defender`, as card text.
func forecast(attacker: CharacterUnit, defender: CharacterUnit, skill: SkillData) -> String:
	var base := DamageCalculator.base_damage(attacker, skill)
	if skill.effect_type == SkillData.EffectType.SHIELD:
		return "보호막 +%d" % base
	var odds := DamageCalculator.odds(attacker, defender, skill)
	var hits := " × %d회" % skill.hit_count if skill.hit_count > 1 else ""
	if skill.auto_hit:
		return "적중 100%%  ·  자동 명중\n피해 %d%s" % [base, hits]
	return "적중 %d%%  —  명중 %d%% · 스침 %d%% · 치명 %d%%\n피해 %d (스침 %d · 치명 %d)%s  ·  2d6 %+d" % [
		percent(odds.land), percent(odds.hit), percent(odds.glance), percent(odds.critical),
		base, DamageCalculator.damage_for(DamageCalculator.Outcome.GLANCE, base), base * 2, hits,
		DamageCalculator.modifier(attacker, defender, skill)]


func intent_text(enemy: EnemyUnit) -> String:
	var before_turn: bool = enemy != battle.actor or battle.phase != BattleManager.Phase.ENEMY_TURN
	var intent: SkillData = enemy.intended_skill(before_turn)
	if intent == null:
		return "예고 ▸ 대기"
	var targets := TargetRules.legal_targets(enemy, intent, battle.enemies, battle.party)
	if intent.effect_type == SkillData.EffectType.SHIELD or targets.is_empty():
		return "예고 ▸ %s · 보호막 %d" % [intent.skill_name, DamageCalculator.base_damage(enemy, intent)]
	var odds := DamageCalculator.odds(enemy, targets[0], intent)
	return "예고 ▸ %s → %s\n적중 %d%% · 피해 %d" % [intent.skill_name, targets[0].display_name, percent(odds.land), DamageCalculator.base_damage(enemy, intent)]


func percent(chance: float) -> int:
	return roundi(chance * 100.0)


func animate_action(actor: CharacterUnit, targets: Array[CharacterUnit], skill: SkillData) -> void:
	if cards.has(actor):
		cards[actor].flash(actor.character_data.display_color)
	for target in targets:
		if not cards.has(target):
			continue
		var to := card_center(target)
		if skill.effect_type == SkillData.EffectType.SHIELD:
			spawn_ring(to, WARD)
			spawn_ring(to, TRIM, 0.12)
			cards[target].flash(WARD)
			continue
		var from := card_center(actor) if cards.has(actor) else to
		match skill.damage_type:
			SkillData.DamageType.FIRE:
				spawn_beam(from, to, Color("ff7a1f"), 18.0, 0.18)
				spawn_burst(to, Color("ffb347"), 40)
			SkillData.DamageType.ARCANE:
				for bolt in 3:
					spawn_beam(from, to, Color("b48cff"), 6.0, 0.08 + bolt * 0.16, bolt * 0.09)
				spawn_burst(to, Color("c9a8ff"), 24)
			SkillData.DamageType.RADIANT:
				spawn_pillar(to, Color("ffe08a"))
			_:
				if skill.target_type == SkillData.TargetType.FRONT_ENEMY:
					spawn_slash(to, Color("f2efe6"), skill.hit_count)
				else:
					spawn_beam(from, to, Color("e8dcc0"), 4.0, 0.02)


func show_hit(target: CharacterUnit, health_damage: int, shield_damage: int, critical: bool) -> void:
	if not cards.has(target):
		return
	var center := card_center(target)
	cards[target].flash(Color("ffb09a"), 9.0 if critical else 5.0)
	spawn_burst(center, Color("ffcf6b") if critical else Color("e0503f"), 34 if critical else 18)
	if shield_damage > 0:
		spawn_popup(target, "−%d" % shield_damage, WARD, 18)
	if critical:
		spawn_popup(target, "치명타!  −%d" % health_damage, GOLD, 30)
		shake_screen(7.0)
	elif health_damage > 0 or shield_damage == 0:
		spawn_popup(target, "−%d" % health_damage, Color("ff7a66"), 24)


func show_dice(target: CharacterUnit, roll: Dictionary) -> void:
	if not cards.has(target) or roll.auto:
		return
	var frame := Engine.get_process_frames()
	var stack: Array = dice_stacks.get(target, [frame, 0])
	if stack[0] != frame:
		stack = [frame, 0]
	var order: int = mini(stack[1], 2)
	dice_stacks[target] = [frame, stack[1] + 1]
	var colors := [Color("b3a78f"), Color("f0b44c"), Color("ff7a4d"), GOLD]
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(holder)
	var dice := DicePair.new()
	dice.size = Vector2(DicePair.SIDE * 2 + 8, DicePair.SIDE)
	dice.pivot_offset = dice.size / 2.0
	dice.rim = colors[roll.outcome].darkened(0.1)
	holder.add_child(dice)
	var verdict := Label.new()
	verdict.text = "%+d = %d  %s" % [roll.modifier, roll.total, DamageCalculator.OUTCOME_NAMES[roll.outcome]]
	verdict.theme_type_variation = "HeadingLabel"
	verdict.add_theme_font_size_override("font_size", 17)
	verdict.add_theme_color_override("font_color", colors[roll.outcome])
	verdict.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.02, 0.95))
	verdict.add_theme_constant_override("outline_size", 6)
	verdict.position = Vector2(dice.size.x + 10, 4)
	verdict.modulate.a = 0.0
	holder.add_child(verdict)
	var card: Control = cards[target]
	var rect := card.get_global_rect()
	holder.position = Vector2(rect.position.x + 16 + order * 190, rect.position.y - 24) - fx_layer.get_global_rect().position
	var final_faces: Array = roll.dice
	var spin := func(progress: float) -> void:
		dice.rotation = sin(progress * 18.0) * 0.35 * (1.0 - progress)
		dice.set_faces(randi_range(1, 6), randi_range(1, 6))
	var land := func() -> void:
		dice.set_faces(final_faces[0], final_faces[1])
		dice.rotation = 0.0
		dice.scale = Vector2.ONE * 1.25
	var tumble := holder.create_tween()
	tumble.tween_interval(order * 0.16)
	tumble.tween_method(spin, 0.0, 1.0, 0.38)
	tumble.tween_callback(land)
	tumble.tween_property(dice, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tumble.parallel().tween_property(verdict, "modulate:a", 1.0, 0.15)
	tumble.tween_interval(1.0)
	tumble.tween_property(holder, "modulate:a", 0.0, 0.35)
	tumble.tween_callback(holder.queue_free)


func show_miss(target: CharacterUnit) -> void:
	spawn_popup(target, "빗나감", Color("c9bda5"), 20)


func show_shield(target: CharacterUnit, amount: int) -> void:
	if amount > 0:
		spawn_popup(target, "+%d 보호막" % amount, WARD, 22)


func on_unit_down(unit: CharacterUnit) -> void:
	if not cards.has(unit):
		return
	spawn_burst(card_center(unit), unit.character_data.display_color, 60)
	spawn_ring(card_center(unit), RED)
	shake_screen(10.0)


func reveal_result() -> void:
	result_label.text = "승리  ·  고갯길을 되찾았습니다" if battle.victory else "패배  ·  일행이 모두 쓰러졌습니다"
	var color := GOLD if battle.victory else RED
	result_label.add_theme_color_override("font_color", color)
	glow_text(result_label, color, 14)
	result_banner.add_theme_stylebox_override("panel", panel_style(color, 0.92, 18))
	result_banner.modulate.a = 0.0
	result_banner.pivot_offset = Vector2(size.x / 2.0, 30)
	result_banner.scale = Vector2(1.2, 1.2)
	var reveal := create_tween()
	reveal.tween_property(result_banner, "modulate:a", 1.0, 0.35)
	reveal.parallel().tween_property(result_banner, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func card_center(unit: CharacterUnit) -> Vector2:
	var card: Control = cards[unit]
	return card.get_global_rect().get_center() - fx_layer.get_global_rect().position


func spawn_popup(unit: CharacterUnit, text_value: String, color: Color, font_size: int) -> void:
	if not cards.has(unit):
		return
	var frame := Engine.get_process_frames()
	var stack: Array = popup_stacks.get(unit, [frame, 0])
	if stack[0] != frame:
		stack = [frame, 0]
	var order: int = mini(stack[1], 3)
	popup_stacks[unit] = [frame, stack[1] + 1]
	var popup := Label.new()
	popup.text = text_value
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_theme_font_size_override("font_size", font_size)
	popup.add_theme_color_override("font_color", color)
	popup.theme_type_variation = "HeadingLabel"
	popup.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.02, 0.9))
	popup.add_theme_constant_override("outline_size", 7)
	popup.add_theme_color_override("font_shadow_color", Color(color, 0.6))
	popup.add_theme_constant_override("shadow_outline_size", 12)
	popup.add_theme_constant_override("shadow_offset_x", 0)
	popup.add_theme_constant_override("shadow_offset_y", 0)
	fx_layer.add_child(popup)
	popup.reset_size()
	var origin := card_center(unit) - popup.size / 2.0 + Vector2(randf_range(-20, 20), 24 - order * 28)
	popup.position = origin
	popup.pivot_offset = popup.size / 2.0
	popup.scale = Vector2.ONE * 0.3
	popup.modulate.a = 0.0
	var motion := popup.create_tween()
	motion.tween_interval(order * 0.12)
	motion.tween_property(popup, "modulate:a", 1.0, 0.08)
	motion.parallel().tween_property(popup, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	motion.parallel().tween_property(popup, "position:y", origin.y - 44, 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	motion.tween_property(popup, "modulate:a", 0.0, 0.3)
	motion.tween_callback(popup.queue_free)


func spawn_beam(from: Vector2, to: Vector2, color: Color, width: float = 5.0, arc: float = 0.18, delay: float = 0.0) -> void:
	var lift := Vector2(0, -minf(140.0, from.distance_to(to) * arc))
	var control := (from + to) / 2.0 + lift
	var points := PackedVector2Array()
	for index in 17:
		var t := index / 16.0
		points.append(from.lerp(control, t).lerp(control.lerp(to, t), t))
	for layer in [[width * 2.8, Color(color, 0.35)], [width, color.lightened(0.3)], [maxf(1.5, width * 0.35), Color("fff6e0")]]:
		var line := Line2D.new()
		line.points = points
		line.width = layer[0]
		line.default_color = layer[1]
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		fx_layer.add_child(line)
		var fade := line.create_tween()
		if delay > 0.0:
			line.visible = false
			fade.tween_interval(delay)
			fade.tween_callback(line.show)
		fade.tween_property(line, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fade.parallel().tween_property(line, "width", 0.0, 0.45)
		fade.tween_callback(line.queue_free)


func spawn_slash(center: Vector2, color: Color, strokes: int) -> void:
	for index in maxi(1, strokes):
		var direction := 1.0 if index % 2 == 0 else -1.0
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2(-70 * direction, -44), Vector2(-10 * direction, -6), Vector2(70 * direction, 44)])
		line.width = 7.0
		line.width_curve = Curve.new()
		line.width_curve.add_point(Vector2(0, 0))
		line.width_curve.add_point(Vector2(0.5, 1))
		line.width_curve.add_point(Vector2(1, 0))
		line.default_color = color
		line.position = center
		line.scale = Vector2(0.1, 0.1)
		line.visible = false
		fx_layer.add_child(line)
		var cut := line.create_tween()
		cut.tween_interval(index * 0.14)
		cut.tween_callback(line.show)
		cut.tween_property(line, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		cut.tween_property(line, "modulate:a", 0.0, 0.3)
		cut.tween_callback(line.queue_free)


func spawn_pillar(center: Vector2, color: Color) -> void:
	for layer in [[64.0, Color(color, 0.25)], [26.0, Color(color, 0.7)], [8.0, Color("fffbe8")]]:
		var beam := Line2D.new()
		beam.points = PackedVector2Array([Vector2(0, -260), Vector2(0, 30)])
		beam.width = layer[0]
		beam.default_color = layer[1]
		beam.position = center
		beam.scale = Vector2(0.2, 1)
		fx_layer.add_child(beam)
		var shine := beam.create_tween()
		shine.tween_property(beam, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		shine.tween_property(beam, "modulate:a", 0.0, 0.5)
		shine.tween_callback(beam.queue_free)
	spawn_ring(center, color)
	spawn_burst(center, color, 30)


func spawn_ring(center: Vector2, color: Color, delay: float = 0.0) -> void:
	var ring := Line2D.new()
	var points := PackedVector2Array()
	for index in 49:
		points.append(Vector2.from_angle(TAU * index / 48.0) * 60.0)
	ring.points = points
	ring.width = 4.0
	ring.default_color = color
	ring.position = center
	ring.scale = Vector2.ONE * 0.3
	fx_layer.add_child(ring)
	var expand := ring.create_tween()
	if delay > 0.0:
		ring.visible = false
		expand.tween_interval(delay)
		expand.tween_callback(ring.show)
	expand.tween_property(ring, "scale", Vector2.ONE * 1.6, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	expand.parallel().tween_property(ring, "modulate:a", 0.0, 0.55)
	expand.tween_callback(ring.queue_free)


func spawn_burst(center: Vector2, color: Color, amount: int) -> void:
	var sparks := CPUParticles2D.new()
	sparks.position = center
	sparks.amount = amount
	sparks.one_shot = true
	sparks.explosiveness = 0.95
	sparks.lifetime = 0.7
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 12.0
	sparks.direction = Vector2.UP
	sparks.spread = 180.0
	sparks.gravity = Vector2(0, 160)
	sparks.initial_velocity_min = 110.0
	sparks.initial_velocity_max = 280.0
	sparks.damping_min = 120.0
	sparks.damping_max = 200.0
	sparks.scale_amount_min = 2.0
	sparks.scale_amount_max = 4.5
	var ramp := Gradient.new()
	ramp.set_color(0, Color.WHITE)
	ramp.set_color(1, Color(color, 0.0))
	ramp.add_point(0.25, color.lightened(0.2))
	sparks.color_ramp = ramp
	sparks.finished.connect(sparks.queue_free)
	fx_layer.add_child(sparks)
	sparks.emitting = true


func shake_screen(strength: float) -> void:
	if screen_tween != null:
		screen_tween.kill()
	screen_tween = create_tween()
	for step in 6:
		var falloff := 1.0 - step / 6.0
		screen_tween.tween_property(scroll, "position", Vector2(randf_range(-strength, strength), randf_range(-strength, strength)) * falloff, 0.035)
	screen_tween.tween_property(scroll, "position", Vector2.ZERO, 0.05)


func append_log(message: String) -> void:
	log_lines.append(message)
	while log_lines.size() > 60:
		log_lines.remove_at(0)
	log_box.text = "\n".join(log_lines)


func build_theme() -> Theme:
	var ui_theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "sans-serif"])
	ui_theme.default_font = font
	ui_theme.default_font_size = 14
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(SERIF)
	serif.font_weight = 600
	ui_theme.set_type_variation("HeadingLabel", "Label")
	ui_theme.set_font("font", "HeadingLabel", serif)
	ui_theme.set_color("font_color", "Label", TEXT)
	ui_theme.set_color("font_color", "Button", TEXT)
	ui_theme.set_color("font_hover_color", "Button", Color.WHITE)
	ui_theme.set_color("font_disabled_color", "Button", Color("6f6352"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		ui_theme.set_stylebox(state, "Button", button_style(TRIM, state))
	return ui_theme


func button_style(accent: Color, state: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2a1d12")
	style.border_color = accent.darkened(0.3)
	style.set_border_width_all(1)
	style.border_width_bottom = 3
	style.set_corner_radius_all(4)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	match state:
		"hover":
			style.bg_color = Color("3a2716").lerp(accent, 0.15)
			style.border_color = accent
			style.shadow_color = Color(accent, 0.45)
			style.shadow_size = 10
		"pressed":
			style.bg_color = accent.darkened(0.55)
			style.border_color = accent.lightened(0.2)
		"disabled":
			style.bg_color = Color("17110b")
			style.border_color = Color("3b2f22")
		"focus":
			style.draw_center = false
			style.border_color = Color(accent, 0.0)
	return style


func panel_style(border: Color, alpha: float, padding: int = 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.06, 0.04, alpha)
	style.border_color = Color(border, 0.9)
	style.set_border_width_all(1)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.set_corner_radius_all(4)
	style.shadow_color = Color(border, 0.18)
	style.shadow_size = 12
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, padding)
	return style


func glow_text(item: Label, color: Color, strength: int) -> void:
	item.add_theme_color_override("font_shadow_color", Color(color, 0.4))
	item.add_theme_constant_override("shadow_outline_size", strength)
	item.add_theme_constant_override("shadow_offset_x", 0)
	item.add_theme_constant_override("shadow_offset_y", 0)


func label(parent: Node, text_value: String, font_size: int, color: Color = TEXT) -> Label:
	var item := Label.new()
	item.text = text_value
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	parent.add_child(item)
	return item


func row(parent: Node) -> HBoxContainer:
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", 12)
	parent.add_child(container)
	return container


func button(parent: Node, text_value: String, callback: Callable, accent: Color = TRIM) -> Button:
	var item := Button.new()
	item.text = text_value
	item.pressed.connect(callback)
	if accent != TRIM:
		for state in ["normal", "hover", "pressed", "disabled"]:
			item.add_theme_stylebox_override(state, button_style(accent, state))
	parent.add_child(item)
	return item
