class_name StoryBackdrop
extends Control
## Full-screen storybook painting behind menus and screens: the shared landscape from
## Storybook, drifting petals and a watercolor paper grain on top. Purely decorative.

## Where the meadow starts, as a fraction of the height.
@export var ground: float = 0.66
## Blurs the painting back a little so panels in front of it read clearly.
@export var hush: float = 0.18

var time: float = 0.0
var petals: Array[Vector3] = []
var sheet: ColorRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for index in 26:
		petals.append(Vector3(rng.randf(), rng.randf(), rng.randf()))
	sheet = Storybook.paper(size)
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(sheet)
	resized.connect(func(): (sheet.material as ShaderMaterial).set_shader_parameter("resolution", size))


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func _draw() -> void:
	Storybook.paint(self, Rect2(Vector2.ZERO, size), ground, false, time)
	# Petals and seeds drifting on a light breeze.
	for index in petals.size():
		var seed: Vector3 = petals[index]
		var x := fposmod(seed.x * size.x + time * (18.0 + seed.z * 22.0), size.x + 40.0) - 20.0
		var y := fposmod(seed.y * size.y + time * (10.0 + seed.z * 8.0) + sin(time * 1.3 + index) * 14.0, size.y)
		var tint := Color("f6b8c4") if index % 3 == 0 else (Color("fff6e0") if index % 3 == 1 else Color("ffd66e"))
		draw_set_transform(Vector2(x, y), time * (1.0 + seed.z) + index, Vector2.ONE)
		draw_colored_polygon(PackedVector2Array([Vector2(-4, 0), Vector2(0, -2.4), Vector2(4, 0), Vector2(0, 2.4)]), Color(tint, 0.85))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if hush > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.97, 0.9, hush))
