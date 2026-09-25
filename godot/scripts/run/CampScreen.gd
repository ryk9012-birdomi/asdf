extends Control
## Camp, reachable from the map at any time. Gear is handled like an old-school action RPG
## inventory: each hero stands in a paper-doll frame with weapon, armor and trinket slots,
## and the shared stash is a grid below. Drag an item onto a slot to wear it (whatever was
## there swaps back), onto another hero to hand it over, or back to the stash to take it
## off. Right-click a worn item to take it off. Gold still buys skill upgrades.

const HERO_TINTS := [Color("9fb8e8"), Color("a98bdb"), Color("6fa8ff")]
const STASH_COLUMNS := 12
const STASH_ROWS := 2
const CELL := 58.0
## Where each equipment slot sits around the figure, and its size.
const SLOT_BOXES := {
	"weapon": Rect2(6, 70, 76, 150),
	"armor": Rect2(298, 60, 84, 110),
	"trinket": Rect2(308, 190, 64, 64),
}
const INK := Color("0b0806")
const BRONZE := Color("8a6a3a")
const VALID := Color("6fe08a")
const INVALID := Color("d04a3a")

var run: RunState
var gold_label: Label
var stash_grid: GridContainer
var heroes: Array[Dictionary] = []


## One square that can hold an item: a stash cell (hero -1) or a hero's equipment slot.
class ItemCell extends Panel:
	var camp: Control
	var hero: int = -1
	var slot: String = ""
	var item_id: String = ""
	var icon: TextureRect
	var caption: Label
	var mark: Color = Color(0, 0, 0, 0)

	func _init(owner_camp: Control, hero_index: int, slot_name: String) -> void:
		camp = owner_camp
		hero = hero_index
		slot = slot_name
		mouse_filter = Control.MOUSE_FILTER_STOP
		icon = TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 4
		icon.offset_top = 4
		icon.offset_right = -4
		icon.offset_bottom = -4
		add_child(icon)
		if not slot.is_empty():
			caption = Label.new()
			caption.text = Items.SLOT_NAMES[slot]
			caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
			caption.add_theme_font_size_override("font_size", 12)
			caption.add_theme_color_override("font_color", Color("6b5a44"))
			caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
			caption.grow_vertical = Control.GROW_DIRECTION_BOTH
			add_child(caption)
		restyle()

	func show_item(id: String) -> void:
		item_id = id
		icon.texture = null if id.is_empty() else load("res://art/items/%s.svg" % id)
		if caption != null:
			caption.visible = id.is_empty()
		tooltip_text = id
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not id.is_empty() else Control.CURSOR_ARROW
		restyle()

	func restyle() -> void:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("0d0907") if item_id.is_empty() else Color("1a120c")
		box.border_color = mark if mark.a > 0.0 else (BRONZE if not slot.is_empty() else Color("3a2c1c"))
		box.set_border_width_all(2 if mark.a > 0.0 or not slot.is_empty() else 1)
		box.set_corner_radius_all(3)
		box.shadow_color = Color(0, 0, 0, 0.6)
		box.shadow_size = 3
		if mark.a > 0.0:
			box.bg_color = box.bg_color.lerp(mark, 0.18)
		add_theme_stylebox_override("panel", box)

	func _get_drag_data(_at: Vector2) -> Variant:
		if item_id.is_empty():
			return null
		var preview := Control.new()
		var picture := TextureRect.new()
		picture.texture = icon.texture
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.size = Vector2(56, 56)
		picture.position = Vector2(-28, -28)
		picture.modulate = Color(1, 1, 1, 0.85)
		preview.add_child(picture)
		set_drag_preview(preview)
		AudioDirector.sfx("ui_click", 0.05, -6.0)
		return {"item": item_id, "hero": hero}

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return camp.can_place(data, hero, slot)

	func _drop_data(_at: Vector2, data: Variant) -> void:
		camp.place(data, hero, slot)

	func _gui_input(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT and hero >= 0 and not item_id.is_empty():
			camp.place({"item": item_id, "hero": hero}, -1, "")

	func _notification(what: int) -> void:
		# While something is being dragged, every cell shows whether it would take it.
		if what == NOTIFICATION_DRAG_BEGIN:
			var data: Variant = get_viewport().gui_get_drag_data()
			if typeof(data) == TYPE_DICTIONARY and not slot.is_empty():
				mark = VALID if camp.can_place(data, hero, slot) else INVALID
				restyle()
		elif what == NOTIFICATION_DRAG_END:
			mark = Color(0, 0, 0, 0)
			restyle()

	func _make_custom_tooltip(_for_text: String) -> Object:
		return camp.item_tooltip(item_id)


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
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	margin.add_child(page)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	page.add_child(header)
	var title := FantasyTheme.label(header, "야영지  ·  정비", 30, Color("f4e2b8"), true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	FantasyTheme.glow(title, Color("ff8a2a"), 10)
	gold_label = FantasyTheme.label(header, "", 22, FantasyTheme.GOLD, true)
	var back := FantasyTheme.button(header, "지도로 돌아가기", func(): leave(SceneRouter.MAP))
	back.name = "BackButton"
	FantasyTheme.label(page, "장비를 끌어다 칸에 놓으면 착용합니다. 다른 영웅에게 끌면 넘겨주고, 보관함으로 끌거나 오른쪽 클릭하면 벗습니다. 바뀐 능력치와 강화한 기술은 다음 전투부터 적용됩니다.", 14, FantasyTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(row)
	for index in run.party.size():
		heroes.append(build_hero(row, index))
	page.add_child(build_stash())
	refresh()


func leave(path: String) -> void:
	SceneRouter.go(get_tree(), path)


func frame_style(border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.04, 0.03, 0.94)
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	box.shadow_color = Color(0, 0, 0, 0.7)
	box.shadow_size = 8
	box.set_content_margin_all(10)
	return box


func build_hero(row: HBoxContainer, index: int) -> Dictionary:
	var hero := run.party[index]
	var panel := PanelContainer.new()
	panel.name = "Hero_%d" % index
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", frame_style(HERO_TINTS[index].darkened(0.45)))
	row.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	var top := VBoxContainer.new()
	column.add_child(top)
	# Paper doll: the hero's own battle figure, with slots around it.
	var doll := Control.new()
	doll.custom_minimum_size = Vector2(384, 356)
	doll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(doll)
	var floor_glow := ColorRect.new()
	floor_glow.color = Color(0, 0, 0, 0.35)
	floor_glow.position = Vector2(88, 6)
	floor_glow.size = Vector2(204, 346)
	floor_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	doll.add_child(floor_glow)
	var figure := FighterView.Figure.new()
	figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	figure.size = Vector2(210, 356)
	figure.position = Vector2(84, 0)
	figure.phase = index * 1.4
	figure.puppet = Puppet.create(hero.definition.class_id)
	figure.puppet.phase = figure.phase
	figure.puppet.size = 1.2
	figure.add_child(figure.puppet)
	doll.add_child(figure)
	var slots := {}
	for slot in Items.SLOTS:
		var cell := ItemCell.new(self, index, slot)
		cell.name = "Slot_%d_%s" % [index, slot]
		var box: Rect2 = SLOT_BOXES[slot]
		cell.position = box.position
		cell.size = box.size
		doll.add_child(cell)
		slots[slot] = cell
	var stats := FantasyTheme.label(column, "", 14, FantasyTheme.TEXT)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var skills := VBoxContainer.new()
	skills.add_theme_constant_override("separation", 3)
	column.add_child(skills)
	return {"top": top, "figure": figure, "slots": slots, "stats": stats, "skills": skills}


func build_stash() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Stash"
	panel.add_theme_stylebox_override("panel", frame_style(BRONZE))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	FantasyTheme.label(column, "보관함", 17, FantasyTheme.TRIM, true)
	stash_grid = GridContainer.new()
	stash_grid.columns = STASH_COLUMNS
	stash_grid.add_theme_constant_override("h_separation", 4)
	stash_grid.add_theme_constant_override("v_separation", 4)
	column.add_child(stash_grid)
	return panel


## Keeps at least STASH_ROWS rows, adding a row whenever the stash outgrows the grid.
func grow_stash() -> void:
	var rows := maxi(STASH_ROWS, ceili((run.stash.size() + 1) / float(STASH_COLUMNS)))
	while stash_grid.get_child_count() < rows * STASH_COLUMNS:
		var cell := ItemCell.new(self, -1, "")
		cell.name = "Stash_%d" % stash_grid.get_child_count()
		cell.custom_minimum_size = Vector2(CELL, CELL)
		stash_grid.add_child(cell)


func refresh() -> void:
	gold_label.text = "골드 %d" % run.gold
	for index in heroes.size():
		var hero := run.party[index]
		var view: Dictionary = heroes[index]
		for child in view.top.get_children():
			view.top.remove_child(child)
			child.queue_free()
		FantasyTheme.hero_row(view.top, hero)
		for slot in Items.SLOTS:
			view.slots[slot].show_item(hero.equipment.get(slot, ""))
		view.figure.puppet.wear(hero.equipment)
		var fighter := hero.battle_definition()
		view.stats.text = "공격 %d%s · 방어 %d%s · 명중 %+d%s · 최대 MP %d%s · 치명 %d+" % [
			fighter.attack, extra(hero, "attack"), fighter.defense, extra(hero, "defense"),
			fighter.hit_bonus, extra(hero, "hit_bonus"), fighter.max_energy, extra(hero, "max_energy"), fighter.crit_threshold]
		fill_skills(view.skills, index, fighter)
	grow_stash()
	var cells := stash_grid.get_children()
	for index in cells.size():
		cells[index].show_item(run.stash[index] if index < run.stash.size() else "")


func fill_skills(box: VBoxContainer, index: int, fighter: CharacterData) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var hero := run.party[index]
	for skill in hero.definition.skills:
		var level := hero.skill_level(skill)
		var current := hero.upgraded(skill)
		var amount := DamageCalculator.base_damage_for(fighter.attack, current)
		var effect := ("보호막 %d" if current.effect_type == SkillData.EffectType.SHIELD else "피해 %d") % amount
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		box.add_child(line)
		var text := FantasyTheme.label(line, "%s Lv%d · %s · MP %d" % [skill.skill_name, level, effect, current.energy_cost], 13, FantasyTheme.TEXT)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var caption := "최대" if level >= RunState.MAX_SKILL_LEVEL else "강화 %dG" % run.upgrade_cost(index, skill)
		var upgrade := FantasyTheme.button(line, caption, func(): improve(index, skill))
		upgrade.name = "Upgrade_%d_%s" % [index, skill.id]
		upgrade.add_theme_font_size_override("font_size", 13)
		upgrade.disabled = not run.can_upgrade(index, skill)
		if level < RunState.MAX_SKILL_LEVEL:
			upgrade.tooltip_text = "Lv%d: 피해·보호막 +1%s" % [level + 1, ", MP −1" if level + 1 >= 3 and current.energy_cost > 0 else ""]


func extra(hero: RunState.HeroState, stat: String) -> String:
	var amount := hero.bonus(stat)
	return " (%+d)" % amount if amount != 0 else ""


## Whether `data` (an item picked up from a hero or the stash) may be dropped on that cell.
func can_place(data: Variant, hero: int, slot: String) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has("item") or Items.item(data.item).is_empty():
		return false
	if hero < 0:
		return data.hero >= 0
	return Items.item(data.item).slot == slot and not (data.hero == hero)


## Moves an item: to the stash (take off), onto a hero's slot (wear; whatever was there goes
## back where the item came from, so two heroes simply trade).
func place(data: Dictionary, hero: int, slot: String) -> void:
	if not can_place(data, hero, slot):
		return
	var item: String = data.item
	var from: int = data.hero
	var item_slot: String = Items.item(item).slot
	if hero < 0:
		run.unequip(from, item_slot)
	else:
		var displaced: String = run.party[hero].equipment.get(slot, "")
		if from >= 0:
			run.unequip(from, item_slot)
		run.equip(hero, item)
		if from >= 0 and not displaced.is_empty():
			run.equip(from, displaced)
	AudioDirector.sfx("shield", 0.05, -4.0)
	refresh.call_deferred()


func improve(index: int, skill: SkillData) -> void:
	if run.upgrade_skill(index, skill):
		AudioDirector.sfx("radiant", 0.0, -4.0)
		refresh.call_deferred()


## Item card in the old dungeon-crawler style: gold name, slot, blue bonuses, flavor text.
func item_tooltip(id: String) -> Control:
	if id.is_empty():
		return null
	var info := Items.item(id)
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.02, 0.015, 0.01, 0.96)
	box.border_color = BRONZE
	box.set_border_width_all(1)
	box.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	panel.add_child(column)
	FantasyTheme.label(column, info.name, 18, Color("f0c85a"), true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	FantasyTheme.label(column, Items.SLOT_NAMES[info.slot], 13, Color("9a8a70")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for part in Items.describe(id).split(" · "):
		FantasyTheme.label(column, part, 15, Color("8ab0ff")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var flavor := FantasyTheme.label(column, info.flavor, 13, Color("c8a878"))
	flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor.custom_minimum_size.x = 220
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return panel
