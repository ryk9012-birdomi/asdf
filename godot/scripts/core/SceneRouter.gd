class_name SceneRouter
extends RefCounted
## Every screen change goes through here: switch immediately, then lift a dark veil.

const MAIN_MENU := "res://scenes/main/MainMenu.tscn"
const BATTLE := "res://scenes/battle/BattleScene.tscn"
const CAMP := "res://scenes/run/CampScreen.tscn"
const MAP := "res://scenes/run/MapScreen.tscn"
const NODE := "res://scenes/run/NodeScreen.tscn"
const RUN_END := "res://scenes/run/RunEndScreen.tscn"


static func go(tree: SceneTree, path: String) -> void:
	tree.change_scene_to_file(path)
	var veil := CanvasLayer.new()
	veil.layer = 100
	var shade := ColorRect.new()
	shade.color = Color("0a0705")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.add_child(shade)
	tree.root.add_child(veil)
	var fade := veil.create_tween()
	fade.tween_property(shade, "color:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade.tween_callback(veil.queue_free)
