class_name Backdrop
extends Control
## Full-screen painting behind menus and screens: the ruined village from Painting, mist
## and a few ash flakes on the wind, the brush overlay, and a dusk wash so the panels in
## front read clearly. Purely decorative.

## Where the land starts, as a fraction of the height.
@export var ground: float = 0.64
## Darkens the painting so panels in front of it read clearly.
@export var hush: float = 0.22

var time: float = 0.0
var flakes: Array[Vector3] = []
var wash: ColorRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for index in 22:
		flakes.append(Vector3(rng.randf(), rng.randf(), rng.randf()))
	var strokes := Painting.brush(0.55)
	strokes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(strokes)
	wash = ColorRect.new()
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.color = Color(0.1, 0.1, 0.09, hush)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(wash)


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func _draw() -> void:
	Painting.paint(self, Rect2(Vector2.ZERO, size), ground, false, time)
	# Ash and dust carried on a cold wind.
	for index in flakes.size():
		var seed: Vector3 = flakes[index]
		var x := fposmod(seed.x * size.x + time * (14.0 + seed.z * 18.0), size.x + 40.0) - 20.0
		var y := fposmod(seed.y * size.y + time * (6.0 + seed.z * 6.0) + sin(time * 0.9 + index) * 10.0, size.y)
		draw_circle(Vector2(x, y), 1.2 + seed.z * 1.4, Color(0.78, 0.78, 0.74, 0.45))
