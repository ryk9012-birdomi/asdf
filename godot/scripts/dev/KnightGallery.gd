extends Control
## Example sheet of every knight made by tools/generate_knight_art.py, all on the battle
## rig. Open scenes/dev/KnightGallery.tscn and press F6. The buttons play one motion on
## everyone; "자동" cycles through them with each knight a little out of step.

const INDEX := "res://art/knights/index.json"
const COLUMNS := 6
const CELL := Vector2(208, 400)
const ACTIONS := ["대기", "베기", "기도", "방패", "피격", "승리", "쓰러짐"]

var figures: Array[FighterView.Figure] = []
var auto := true
var clock: float = 0.0
var status: Label


func _ready() -> void:
	theme = FantasyTheme.build()
	add_child(EmberBackdrop.new())
	var title := FantasyTheme.label(self, "기사 견본", 32, Color("f4e2b8"), true)
	title.position = Vector2(28, 16)
	var bar := HBoxContainer.new()
	bar.position = Vector2(28, 64)
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	for action in ACTIONS:
		var button := FantasyTheme.button(bar, action, func(): play_all(action))
		button.name = "Play_" + action
	FantasyTheme.button(bar, "자동", func(): auto = true).name = "Auto"
	status = FantasyTheme.label(self, "", 15, FantasyTheme.MUTED)
	status.position = Vector2(28, 108)
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
	for index in entries.size():
		add_knight(entries[index], index)
	status.text = "%d종 · tools/generate_knight_art.py의 VARIANTS에서 투구·얼굴·갑옷·문장·망토·무기·방패를 골라 만든 예시입니다." % figures.size()


func add_knight(entry: Dictionary, index: int) -> void:
	var cell := Vector2(18 + (index % COLUMNS) * CELL.x, 140 + (index / COLUMNS) * CELL.y)
	var figure := FighterView.Figure.new()
	figure.name = "Knight_" + entry.id
	figure.size = Vector2(CELL.x, 300)
	figure.position = cell
	figure.phase = index * 0.9
	figure.puppet = Puppet.knight("res://art/knights/%s/" % entry.id)
	figure.puppet.phase = figure.phase
	figure.add_child(figure.puppet)
	figure.set_meta("home", cell)
	add_child(figure)
	figures.append(figure)
	var caption := VBoxContainer.new()
	caption.position = cell + Vector2(4, 300)
	caption.size = Vector2(CELL.x - 8, 90)
	caption.add_theme_constant_override("separation", 2)
	add_child(caption)
	var name_label := FantasyTheme.label(caption, entry.name, 18, Color("f4e6c4"), true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var note := FantasyTheme.label(caption, entry.note, 13, FantasyTheme.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _process(delta: float) -> void:
	if not auto:
		return
	clock += delta
	if clock < 1.6:
		return
	clock = 0.0
	for index in figures.size():
		play(figures[index], ACTIONS[(int(Time.get_ticks_msec() / 1600.0) + index) % ACTIONS.size()])


func play_all(action: String) -> void:
	auto = false
	for figure in figures:
		play(figure, action)


## The same motion values FighterView tweens in battle, played in place.
func play(figure: FighterView.Figure, action: String) -> void:
	var home: Vector2 = figure.get_meta("home")
	var tween := create_tween()
	tween.tween_property(figure, "fallen", 0.0, 0.2)
	tween.parallel().tween_property(figure, "glow", 0.0, 0.2)
	tween.parallel().tween_property(figure, "hurt", 0.0, 0.2)
	tween.parallel().tween_property(figure, "position", home, 0.2)
	match action:
		"대기":
			tween.parallel().tween_property(figure, "arm", 0.0, 0.2)
		"베기":
			tween.tween_property(figure, "arm", -1.3, 0.14)
			tween.parallel().tween_property(figure, "position", home + Vector2(40, 0), 0.24)
			tween.parallel().tween_property(figure, "lean", 1.0, 0.24)
			tween.tween_property(figure, "arm", 1.5, 0.09).set_trans(Tween.TRANS_BACK)
			tween.tween_interval(0.25)
			tween.tween_property(figure, "position", home, 0.3)
			tween.parallel().tween_property(figure, "lean", 0.0, 0.3)
			tween.parallel().tween_property(figure, "arm", 0.0, 0.3)
		"기도":
			tween.tween_property(figure, "arm", -2.1, 0.16)
			tween.parallel().tween_property(figure, "glow", 1.0, 0.16)
			tween.tween_interval(0.6)
			tween.tween_property(figure, "glow", 0.0, 0.4)
			tween.parallel().tween_property(figure, "arm", 0.0, 0.3)
		"방패":
			tween.tween_property(figure, "arm", -0.8, 0.15)
			tween.parallel().tween_property(figure, "glow", 1.0, 0.15)
			tween.tween_interval(0.6)
			tween.tween_property(figure, "glow", 0.0, 0.4)
			tween.parallel().tween_property(figure, "arm", 0.0, 0.3)
		"피격":
			tween.tween_property(figure, "hurt", 1.0, 0.06)
			tween.parallel().tween_property(figure, "position", home - Vector2(14, 0), 0.06)
			tween.tween_property(figure, "hurt", 0.0, 0.5)
			tween.parallel().tween_property(figure, "position", home, 0.25)
		"승리":
			for _hop in 2:
				tween.tween_property(figure, "bob", 18.0, 0.16).set_ease(Tween.EASE_OUT)
				tween.parallel().tween_property(figure, "arm", -2.3, 0.16)
				tween.tween_property(figure, "bob", 0.0, 0.16).set_ease(Tween.EASE_IN)
		"쓰러짐":
			tween.parallel().tween_property(figure, "arm", 0.0, 0.2)
			tween.tween_property(figure, "fallen", 1.0, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
