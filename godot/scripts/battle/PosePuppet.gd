class_name PosePuppet
extends Puppet
## A character animated from painted key poses (tools/pose_sheet.py) instead of jointed
## parts: ready, wind-up, strike, follow-through, recovery and so on, each a whole painting.
## The fighter's motion values choose the pose; poses cross-fade, the figure breathes,
## tips into a lunge and rocks back when struck. At rest an idle loop plays round and round
## when the sheet has one (poses.json "idle"), and a plan entry may name a clip: a run of
## frames played at its own rate from the moment it starts (a frame-by-frame swing). A
## committed clip plays to its end even as the arm settles. Gear is remembered but not drawn.

## Which painted pose plays each moment, per rig style.
##   wind: winding up · dash: closing in · hit: the blow · through: the blow's far end
##   back: recovering · raise: holding a prayer or spell · guard: bracing · cheer: victory
const PLANS := {
	&"knight": {"wind": "anticipation", "dash": "lunge", "hit": "strike", "through": "follow", "back": "recovery",
		"raise": "anticipation", "guard": "recovery", "cheer": "anticipation", "through_at": 1.1},
	&"wizard": {"wind": "anticipation", "dash": "anticipation", "hit": "cast", "through": "release", "back": "recovery",
		"raise": "channel", "guard": "channel", "cheer": "channel", "through_at": 0.3},
}
const FADE := 0.08
## Arm speed (per second) that counts as a blow rather than lowering a guard.
const SWING_SPEED := 8.0

## name -> [texture, anchor, pixels per rig unit]
var frames: Dictionary = {}
## Idle loop frame names in order, and how many play per second.
var idle: Array = []
var idle_fps: float = 5.0
## name -> {"frames": [...], "fps": n, "commit": bool}
var clips: Dictionary = {}
var clip := ""
var clip_start := 0.0
## How long the pose being faded out takes to disappear.
var fade: float = FADE
var plan: Dictionary
var density: float = 3.0
var current: Sprite2D
var previous: Sprite2D
var pose := ""
var last_arm := 0.0
var swinging := 0.0
## slot -> item id, kept so screens can read what the figure has on.
var worn: Dictionary = {}


func _init(art: String, style_id: StringName) -> void:
	art = art.trim_suffix("/") + "/"
	var data: Dictionary = (load(art + "poses.json") as JSON).data
	density = data.density
	painted = not data.get("paint", false)
	plan = PLANS.get(style_id, PLANS[&"knight"]).duplicate()
	plan.merge(data.get("plan", {}), true)
	clips = data.get("clips", {})
	for name in data.frames:
		var entry: Dictionary = data.frames[name]
		frames[name] = [load(art + "pose_%s.png" % name), Vector2(entry.anchor[0], entry.anchor[1]), entry.get("density", density)]
	idle = data.get("idle", [])
	idle_fps = data.get("idle_fps", 5.0)
	previous = Sprite2D.new()
	previous.centered = false
	add_child(previous)
	current = Sprite2D.new()
	current.centered = false
	add_child(current)
	show_pose(rest(0.0))


func wear(equipment: Dictionary) -> void:
	worn = equipment.duplicate()


func show_pose(name: String) -> void:
	if name == pose or not frames.has(name):
		return
	# Idle frames melt into each other; clip frames follow each other almost at once;
	# action poses snap over quickly.
	if idle.has(name) and idle.has(pose):
		fade = 0.9 / idle_fps
	elif clip != "" and clips[clip].frames.has(name):
		fade = 0.03
	else:
		fade = FADE
	if pose != "":
		previous.texture = current.texture
		previous.offset = current.offset
		previous.set_meta("density", current.get_meta("density", density))
		previous.modulate.a = 1.0
	pose = name
	current.texture = frames[name][0]
	current.offset = -frames[name][1]
	current.set_meta("density", frames[name][2])


## The resting pose: the idle loop's frame for this moment, or the single ready pose.
func rest(t: float) -> String:
	if idle.is_empty():
		return "ready"
	return idle[int(t * idle_fps) % idle.size()]


## The pose for this moment of the fighter's motion.
func choose(arm: float, glow: float, lean: float, fallen: float, t: float = 0.0) -> String:
	if fallen > 0.3:
		return plan.back
	if arm <= -1.9:
		return plan.raise if glow > 0.3 else plan.cheer
	if swinging > 0.0:
		return plan.through if arm >= plan.through_at else plan.hit
	if arm <= -0.9:
		return plan.dash if lean > 0.5 else plan.wind
	if arm <= -0.5:
		return plan.guard if glow > 0.3 else plan.back
	if arm >= plan.through_at:
		return plan.through
	if arm > 0.05 or absf(lean) > 0.3:
		return plan.back
	if glow > 0.3:
		return plan.guard
	return rest(t)


## Shows `name`: a single pose, or the current frame of a clip (started now if new).
func play(name: String, t: float) -> void:
	if not clips.has(name):
		clip = ""
		show_pose(name)
		return
	if name != clip:
		clip = name
		clip_start = t
	show_pose(clip_frame(t))


func clip_frame(t: float) -> String:
	var run: Array = clips[clip].frames
	return run[mini(int((t - clip_start) * float(clips[clip].fps)), run.size() - 1)]


## True while a committed clip still has frames left to show.
func clip_running(t: float) -> bool:
	return clip != "" and clips[clip].get("commit", false) and clip_frame(t) != clips[clip].frames[-1]


func drive(figure: Control, delta: float) -> void:
	var arm: float = figure.arm
	var t: float = figure.time + phase
	if delta > 0.0 and (arm - last_arm) / delta > SWING_SPEED:
		swinging = 0.14
	swinging = maxf(0.0, swinging - delta)
	last_arm = arm
	var wanted := choose(arm, figure.glow, figure.lean, figure.fallen, t)
	if clip_running(t) and figure.fallen < 0.3 and figure.hurt < 0.3:
		wanted = clip
	play(wanted, t)
	previous.modulate.a = maxf(0.0, previous.modulate.a - delta / fade)
	previous.visible = previous.modulate.a > 0.0
	# Breathing, a tip into the lunge, and a rock back when struck; the frames are
	# drawn at `density` sheet pixels per rig unit.
	# The idle loop breathes on its own; single poses get a slight rise and fall.
	var breathe: float = 1.0 + (0.0 if idle.has(pose) else 0.008 * sin(t * 2.2)) * (1.0 - figure.fallen)
	var tilt: float = figure.lean * 0.05 - figure.hurt * 0.14
	for sprite in [current, previous]:
		sprite.scale = Vector2(1.0, breathe) / float(sprite.get_meta("density", density))
		sprite.rotation = tilt
