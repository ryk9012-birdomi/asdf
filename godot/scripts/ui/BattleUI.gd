extends Control
## Reads battle state, emits commands. Never applies damage or advances turns.

signal skill_requested(skill: SkillData, target: CharacterUnit)
signal pass_requested
signal restart_requested
signal lab_requested

const CARD_SCRIPT = preload("res://scripts/ui/CombatantView.gd")
const STAGGER := 40
const CYAN := Color("69e6c3")
const GOLD := Color("ffc76b")
const RED := Color("ff6b73")
const TEXT := Color("e0e9f8")
const MUTED := Color("93a5bd")

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
var screen_tween: Tween


func _ready() -> void:
	theme = build_theme()
	add_child(SpaceBackdrop.new())
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
	label(content, "AFTERLIGHT TRAVERSE   /   COMBAT PROTOTYPE   /   002", 12, CYAN)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	content.add_child(header)
	var title := label(header, "잔광 항로  /  봉쇄선 돌파", 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	glow_text(title, CYAN, 10)
	button(header, "준비실", func(): lab_requested.emit())
	button(header, "전투 재시작", func(): restart_requested.emit())
	var turn_strip := HBoxContainer.new()
	turn_strip.add_theme_constant_override("separation", 12)
	content.add_child(turn_strip)
	turn_label = label(turn_strip, "", 15, GOLD)
	glow_text(turn_label, GOLD, 6)
	turn_row = HBoxContainer.new()
	turn_row.add_theme_constant_override("separation", 6)
	turn_strip.add_child(turn_row)
	content.add_child(build_battlefield())
	result_banner = PanelContainer.new()
	result_banner.add_theme_stylebox_override("panel", panel_style(GOLD, 0.92, 18))
	result_banner.visible = false
	content.add_child(result_banner)
	result_label = label(result_banner, "", 28, GOLD)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glow_text(result_label, GOLD, 14)
	result_label.visible = false
	var command := PanelContainer.new()
	command.add_theme_stylebox_override("panel", panel_style(Color("34506f"), 0.78))
	content.add_child(command)
	var command_body := VBoxContainer.new()
	command_body.add_theme_constant_override("separation", 10)
	command.add_child(command_body)
	prompt = label(command_body, "", 16)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_row = row(command_body)
	skill_row.custom_minimum_size.y = 56
	var log_panel := PanelContainer.new()
	log_panel.add_theme_stylebox_override("panel", panel_style(Color("25384f"), 0.7))
	content.add_child(log_panel)
	var log_body := VBoxContainer.new()
	log_panel.add_child(log_body)
	label(log_body, "COMBAT LOG  /  전투 기록", 12, CYAN)
	log_box = RichTextLabel.new()
	log_box.custom_minimum_size.y = 92
	log_box.add_theme_font_size_override("normal_font_size", 13)
	log_box.add_theme_color_override("default_color", Color("c3d0e3"))
	log_box.scroll_following = true
	log_body.add_child(log_box)
	label(content, "스킬 선택 → 빛나는 대상 클릭  |  실드는 피해를 먼저 흡수  |  자기 차례 EN +1  |  재사용 대기는 자신의 턴 기준", 12, MUTED)


func build_battlefield() -> Control:
	var field := HBoxContainer.new()
	field.add_theme_constant_override("separation", 10)
	party_column = side_column(field, "CREW  /  잔광 인양단", CYAN, HORIZONTAL_ALIGNMENT_LEFT)
	var divider := VBoxContainer.new()
	divider.custom_minimum_size.x = 64
	divider.alignment = BoxContainer.ALIGNMENT_CENTER
	field.add_child(divider)
	divider.add_child(beam_rule())
	var versus := label(divider, "VS", 26, Color("f4f7ff"))
	versus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glow_text(versus, Color("b58cff"), 14)
	divider.add_child(beam_rule())
	enemy_column = side_column(field, "HOSTILES  /  적 행동 예고 · 방어 적용 전", RED, HORIZONTAL_ALIGNMENT_RIGHT)
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
	gradient.set_color(0, Color(0.41, 0.9, 0.76, 0.0))
	gradient.set_color(1, Color(0.71, 0.55, 1.0, 0.9))
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
			var caption := "%s\nEN %d  ·  CD %d" % [skill.skill_name, skill.energy_cost, skill.cooldown]
			if not reason.is_empty():
				caption = "%s\n%s" % [skill.skill_name, reason]
			var skill_button := button(skill_row, caption, func(): select_skill(skill), battle.actor.character_data.display_color)
			skill_button.disabled = not reason.is_empty()
			skill_button.custom_minimum_size = Vector2(170, 56)
			skill_button.tooltip_text = skill.description + "\n재사용 대기: %d턴" % skill.cooldown
		pass_button = button(skill_row, "대기\n턴 넘기기", func(): pass_requested.emit())
		pass_button.custom_minimum_size = Vector2(110, 56)
	elif finished:
		prompt.text = "전투 재시작으로 다시 도전할 수 있습니다."
	elif battle.phase == BattleManager.Phase.ENEMY_TURN:
		prompt.text = "%s · 행동 준비 중…" % battle.actor.display_name
	else:
		prompt.text = "행동 처리 중…"
	refresh_cards()


func refresh_turn_order() -> void:
	turn_label.text = "ROUND %02d" % battle.turns.round_number
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
	prompt.text = "%s · %s  /  빛나는 대상을 클릭하세요." % [skill.skill_name, skill.description]
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
				detail = "예고 ▸ %s · %s %d" % [intent.skill_name, "실드" if intent.effect_type == SkillData.EffectType.SHIELD else "공격", amount]
			else:
				detail = "예고 ▸ 대기"
		cards[unit].refresh(unit == battle.actor and battle.phase != BattleManager.Phase.FINISHED, unit in legal, detail)


func animate_action(actor: CharacterUnit, targets: Array[CharacterUnit], skill: SkillData) -> void:
	var shielding := skill.effect_type == SkillData.EffectType.SHIELD
	if cards.has(actor):
		cards[actor].flash(actor.character_data.display_color)
	for target in targets:
		if not cards.has(target):
			continue
		if shielding:
			spawn_ring(card_center(target), Color("7eeaff"))
			cards[target].flash(Color("7eddeb"))
		elif cards.has(actor):
			spawn_beam(card_center(actor), card_center(target), actor.character_data.display_color)


func show_hit(target: CharacterUnit, health_damage: int, shield_damage: int, critical: bool) -> void:
	if not cards.has(target):
		return
	var center := card_center(target)
	cards[target].flash(Color("ffaaa4"), 9.0 if critical else 5.0)
	spawn_burst(center, Color("ffb46b") if critical else Color("ff8a7a"), 34 if critical else 18)
	if shield_damage > 0:
		spawn_popup(target, "−%d" % shield_damage, Color("7eeaff"), 18)
	if critical:
		spawn_popup(target, "CRITICAL  −%d" % health_damage, GOLD, 30)
		shake_screen(7.0)
	elif health_damage > 0 or shield_damage == 0:
		spawn_popup(target, "−%d" % health_damage, Color("ff8f8f"), 24)


func show_miss(target: CharacterUnit) -> void:
	spawn_popup(target, "MISS", Color("b8c4d6"), 20)


func show_shield(target: CharacterUnit, amount: int) -> void:
	if amount > 0:
		spawn_popup(target, "+%d 실드" % amount, Color("7eeaff"), 22)


func on_unit_down(unit: CharacterUnit) -> void:
	if not cards.has(unit):
		return
	spawn_burst(card_center(unit), unit.character_data.display_color, 60)
	spawn_ring(card_center(unit), RED)
	shake_screen(10.0)


func reveal_result() -> void:
	result_label.text = "작전 성공  ·  봉쇄선을 돌파했습니다" if battle.victory else "작전 실패  ·  파티가 전멸했습니다"
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
	popup.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.07, 0.9))
	popup.add_theme_constant_override("outline_size", 7)
	popup.add_theme_color_override("font_shadow_color", Color(color, 0.6))
	popup.add_theme_constant_override("shadow_outline_size", 12)
	popup.add_theme_constant_override("shadow_offset_x", 0)
	popup.add_theme_constant_override("shadow_offset_y", 0)
	fx_layer.add_child(popup)
	popup.reset_size()
	var origin := card_center(unit) - popup.size / 2.0 + Vector2(randf_range(-20, 20), 6 - order * 30)
	popup.position = origin
	popup.pivot_offset = popup.size / 2.0
	popup.scale = Vector2.ONE * 0.3
	popup.modulate.a = 0.0
	var motion := popup.create_tween()
	motion.tween_interval(order * 0.12)
	motion.tween_property(popup, "modulate:a", 1.0, 0.08)
	motion.parallel().tween_property(popup, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	motion.parallel().tween_property(popup, "position:y", origin.y - 60, 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	motion.tween_property(popup, "modulate:a", 0.0, 0.3)
	motion.tween_callback(popup.queue_free)


func spawn_beam(from: Vector2, to: Vector2, color: Color) -> void:
	var lift := Vector2(0, -minf(90.0, from.distance_to(to) * 0.18))
	var control := (from + to) / 2.0 + lift
	var points := PackedVector2Array()
	for index in 17:
		var t := index / 16.0
		points.append(from.lerp(control, t).lerp(control.lerp(to, t), t))
	for layer in [[14.0, Color(color, 0.35)], [5.0, color.lightened(0.3)], [2.0, Color.WHITE]]:
		var line := Line2D.new()
		line.points = points
		line.width = layer[0]
		line.default_color = layer[1]
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		fx_layer.add_child(line)
		var fade := line.create_tween()
		fade.tween_property(line, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fade.parallel().tween_property(line, "width", 0.0, 0.45)
		fade.tween_callback(line.queue_free)
	spawn_burst(to, color, 14)


func spawn_ring(center: Vector2, color: Color) -> void:
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
	ui_theme.set_color("font_color", "Label", TEXT)
	ui_theme.set_color("font_color", "Button", TEXT)
	ui_theme.set_color("font_hover_color", "Button", Color.WHITE)
	ui_theme.set_color("font_disabled_color", "Button", Color("66758c"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		ui_theme.set_stylebox(state, "Button", button_style(CYAN, state))
	return ui_theme


func button_style(accent: Color, state: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("16253b")
	style.border_color = accent.darkened(0.35)
	style.set_border_width_all(1)
	style.border_width_bottom = 3
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	match state:
		"hover":
			style.bg_color = Color("1f3551").lerp(accent, 0.15)
			style.border_color = accent
			style.shadow_color = Color(accent, 0.45)
			style.shadow_size = 10
		"pressed":
			style.bg_color = accent.darkened(0.55)
			style.border_color = accent.lightened(0.2)
		"disabled":
			style.bg_color = Color("0f1828")
			style.border_color = Color("2a3649")
		"focus":
			style.draw_center = false
			style.border_color = Color(accent, 0.0)
	return style


func panel_style(border: Color, alpha: float, padding: int = 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.07, 0.12, alpha)
	style.border_color = Color(border, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
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


func button(parent: Node, text_value: String, callback: Callable, accent: Color = CYAN) -> Button:
	var item := Button.new()
	item.text = text_value
	item.pressed.connect(callback)
	if accent != CYAN:
		for state in ["normal", "hover", "pressed", "disabled"]:
			item.add_theme_stylebox_override(state, button_style(accent, state))
	parent.add_child(item)
	return item
