extends Control
## Camp, reachable from the map at any time: wear gear (weapon, armor, trinket) and
## spend gold on skill upgrades. Changes apply from the next battle on.

const HERO_TINTS := [Color("e9b949"), Color("a98bdb"), Color("6fa8ff")]

var run: RunState
var body: HBoxContainer
var stash_box: VBoxContainer
var gold_label: Label
var note: Label


func _ready() -> void:
	run = RunState.active
	if run == null:
		leave.call_deferred(SceneRouter.MAIN_MENU)
		return
	theme = FantasyTheme.build()
	AudioDirector.music("menu")
	add_child(EmberBackdrop.new())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	page.add_child(header)
	var title := FantasyTheme.label(header, "야영지  ·  정비", 32, Color("f4e2b8"), true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	FantasyTheme.glow(title, Color("ff8a2a"), 10)
	gold_label = FantasyTheme.label(header, "", 22, FantasyTheme.GOLD, true)
	var back := FantasyTheme.button(header, "지도로 돌아가기", func(): leave(SceneRouter.MAP))
	back.name = "BackButton"
	note = FantasyTheme.label(page, "장비는 영웅마다 무기·방어구·장신구 한 칸씩. 바뀐 능력치와 강화한 기술은 다음 전투부터 적용됩니다.", 15, FantasyTheme.MUTED)
	body = HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	var stash_panel := PanelContainer.new()
	stash_panel.add_theme_stylebox_override("panel", FantasyTheme.panel(Color("7a5c2e"), 0.86, 12))
	page.add_child(stash_panel)
	stash_box = VBoxContainer.new()
	stash_box.add_theme_constant_override("separation", 6)
	stash_panel.add_child(stash_box)
	rebuild()


func leave(path: String) -> void:
	SceneRouter.go(get_tree(), path)


func rebuild() -> void:
	gold_label.text = "골드 %d" % run.gold
	for child in body.get_children() + stash_box.get_children():
		child.get_parent().remove_child(child)
		child.queue_free()
	for index in run.party.size():
		body.add_child(hero_panel(index))
	FantasyTheme.label(stash_box, "보관함", 18, FantasyTheme.TRIM, true)
	if run.stash.is_empty():
		FantasyTheme.label(stash_box, "보관 중인 장비가 없습니다. 전투 보상과 보물 상자에서 얻을 수 있습니다.", 15, FantasyTheme.MUTED)
	for item_id in run.stash:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		stash_box.add_child(row)
		var info: Dictionary = Items.item(item_id)
		var caption := FantasyTheme.label(row, "[%s]  %s  —  %s" % [Items.SLOT_NAMES[info.slot], info.name, Items.describe(item_id)], 16, FantasyTheme.TEXT)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.tooltip_text = info.flavor
		caption.mouse_filter = Control.MOUSE_FILTER_PASS
		for index in run.party.size():
			var hero := run.party[index]
			var give := FantasyTheme.button(row, "%s 착용" % hero.definition.character_name, func(): wear(index, item_id))
			give.name = "Equip_%s_%d" % [item_id, index]
			give.add_theme_color_override("font_color", HERO_TINTS[index])


func hero_panel(index: int) -> PanelContainer:
	var hero := run.party[index]
	var fighter := hero.battle_definition()
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", FantasyTheme.panel(HERO_TINTS[index].darkened(0.3), 0.9, 14))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	FantasyTheme.hero_row(column, hero)
	var stats := "공격 %d%s · 방어 %d%s · 명중 %+d%s\n최대 MP %d%s · 치명 %d+" % [
		fighter.attack, extra(hero, "attack"), fighter.defense, extra(hero, "defense"),
		fighter.hit_bonus, extra(hero, "hit_bonus"), fighter.max_energy, extra(hero, "max_energy"), fighter.crit_threshold]
	FantasyTheme.label(column, stats, 15, FantasyTheme.TEXT)
	column.add_child(HSeparator.new())
	FantasyTheme.label(column, "장비", 16, FantasyTheme.TRIM, true)
	for slot in Items.SLOTS:
		var row := HBoxContainer.new()
		column.add_child(row)
		var worn: String = hero.equipment.get(slot, "")
		var text := "%s:  %s" % [Items.SLOT_NAMES[slot], "비어 있음" if worn.is_empty() else "%s (%s)" % [Items.item(worn).name, Items.describe(worn)]]
		var line := FantasyTheme.label(row, text, 15, FantasyTheme.TEXT if not worn.is_empty() else FantasyTheme.MUTED)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if not worn.is_empty():
			var off := FantasyTheme.button(row, "해제", func(): take_off(index, slot))
			off.name = "Unequip_%d_%s" % [index, slot]
	column.add_child(HSeparator.new())
	FantasyTheme.label(column, "기술 강화", 16, FantasyTheme.TRIM, true)
	for skill in hero.definition.skills:
		var level := hero.skill_level(skill)
		var current := hero.upgraded(skill)
		var effect := "보호막 %d" % DamageCalculator.base_damage_for(fighter.attack, current) if current.effect_type == SkillData.EffectType.SHIELD else "피해 %d" % DamageCalculator.base_damage_for(fighter.attack, current)
		var row := VBoxContainer.new()
		column.add_child(row)
		FantasyTheme.label(row, "%s  Lv%d   ·   %s · MP %d" % [skill.skill_name, level, effect, current.energy_cost], 15, FantasyTheme.TEXT)
		var upgrade := FantasyTheme.button(row, "최대 레벨" if level >= RunState.MAX_SKILL_LEVEL else "강화 → Lv%d  (%d 골드)  %s" % [level + 1, run.upgrade_cost(index, skill), "피해·보호막 +1" + (", MP −1" if level + 1 >= 3 and current.energy_cost > 0 else "")], func(): improve(index, skill))
		upgrade.name = "Upgrade_%d_%s" % [index, skill.id]
		upgrade.disabled = not run.can_upgrade(index, skill)
	return panel


func extra(hero: RunState.HeroState, stat: String) -> String:
	var amount := hero.bonus(stat)
	return " (%+d)" % amount if amount != 0 else ""


func wear(index: int, item_id: String) -> void:
	if run.equip(index, item_id):
		AudioDirector.sfx("shield", 0.05, -4.0)
		rebuild.call_deferred()


func take_off(index: int, slot: String) -> void:
	if run.unequip(index, slot):
		rebuild.call_deferred()


func improve(index: int, skill: SkillData) -> void:
	if run.upgrade_skill(index, skill):
		AudioDirector.sfx("radiant", 0.0, -4.0)
		rebuild.call_deferred()
