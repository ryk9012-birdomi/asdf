class_name AudioDirector
extends Node
## Music with crossfades and a small pool of sound-effect players. It lives on the scene
## tree root, so a track keeps playing across screen changes. Every sound is synthesised
## by tools/generate_audio.py.

const MUSIC := "res://assets/audio/music/%s.ogg"
const SFX := "res://assets/audio/sfx/%s.wav"
const JINGLES := ["victory", "defeat"]
const SETTINGS := "user://settings.cfg"
const FADE := 1.2
const VOICES := 10

static var instance: AudioDirector
## Set by shutdown(); late sound requests during exit must not revive the player.
static var closed: bool = false

var decks: Array[AudioStreamPlayer] = []
var live_deck: int = 0
var current_track: String = ""
var voices: Array[AudioStreamPlayer] = []
var next_voice: int = 0
var cache: Dictionary = {}
var pending_track: String = ""
## Names of effects played, newest last; tests read it.
var played: PackedStringArray = []


static func director() -> AudioDirector:
	if closed:
		return null
	if instance == null or not is_instance_valid(instance):
		instance = AudioDirector.new()
		instance.name = "AudioDirector"
		var tree := Engine.get_main_loop() as SceneTree
		# Screens call this from _ready, while the root is still adding children.
		tree.root.add_child.call_deferred(instance)
	return instance


static func music(track: String) -> void:
	if director() != null:
		instance.play_music(track)


## Stops every player so the audio thread can release its playbacks; the node itself is
## freed with the tree. Call before quitting and give it a moment (see MainMenu.quit_game).
static func shutdown() -> void:
	closed = true
	if instance != null and is_instance_valid(instance):
		for tween in instance.get_tree().get_processed_tweens():
			tween.kill()
		for player in instance.decks + instance.voices:
			player.stop()


static func sfx(effect: String, pitch_spread: float = 0.06, volume_db: float = 0.0) -> void:
	if director() != null:
		instance.play_sfx(effect, pitch_spread, volume_db)


static func volume(bus: String) -> float:
	ensure_buses()
	var config := ConfigFile.new()
	if config.load(SETTINGS) == OK and config.has_section_key("audio", bus):
		return config.get_value("audio", bus)
	var index := AudioServer.get_bus_index(bus)
	return db_to_linear(AudioServer.get_bus_volume_db(index)) if index >= 0 else 1.0


static func set_volume(bus: String, level: float) -> void:
	director()
	ensure_buses()
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.0001)))
	AudioServer.set_bus_mute(index, level <= 0.001)
	var config := ConfigFile.new()
	config.load(SETTINGS)
	config.set_value("audio", bus, level)
	config.save(SETTINGS)


static func ensure_buses() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_buses()
	var config := ConfigFile.new()
	if config.load(SETTINGS) == OK:
		for bus in ["Music", "SFX"]:
			var level: float = config.get_value("audio", bus, 0.8 if bus == "Music" else 1.0)
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(maxf(level, 0.0001)))
			AudioServer.set_bus_mute(AudioServer.get_bus_index(bus), level <= 0.001)
	else:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(0.8))
	for index in 2:
		var deck := AudioStreamPlayer.new()
		deck.bus = "Music"
		deck.volume_db = -80.0
		add_child(deck)
		decks.append(deck)
	for index in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = "SFX"
		add_child(voice)
		voices.append(voice)
	if not pending_track.is_empty():
		var track := pending_track
		pending_track = ""
		current_track = ""
		play_music(track)


func _exit_tree() -> void:
	# Release streams before shutdown so nothing is reported as leaked.
	for player in decks + voices:
		player.stop()
		player.stream = null
	cache.clear()
	if instance == self:
		instance = null


func load_stream(path: String) -> AudioStream:
	if not cache.has(path):
		cache[path] = load(path) if ResourceLoader.exists(path) else null
	return cache[path]


func play_music(track: String) -> void:
	if track == current_track:
		return
	current_track = track
	if decks.is_empty():
		pending_track = track
		return
	var stream := load_stream(MUSIC % track)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = track not in JINGLES
	var outgoing := decks[live_deck]
	live_deck = 1 - live_deck
	var incoming := decks[live_deck]
	incoming.stream = stream
	incoming.volume_db = -30.0 if track not in JINGLES else 0.0
	incoming.play()
	var blend := create_tween().set_parallel(true)
	blend.tween_property(incoming, "volume_db", 0.0, FADE * 0.6)
	blend.tween_property(outgoing, "volume_db", -80.0, FADE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	blend.chain().tween_callback(outgoing.stop)


func stop_music() -> void:
	current_track = ""
	for deck in decks:
		create_tween().tween_property(deck, "volume_db", -80.0, FADE)


func play_sfx(effect: String, pitch_spread: float, volume_db: float) -> void:
	played.append(effect)
	if played.size() > 64:
		played.remove_at(0)
	if voices.is_empty():
		return
	var stream := load_stream(SFX % effect)
	if stream == null:
		return
	var voice := voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	voice.stream = stream
	voice.pitch_scale = 1.0 + randf_range(-pitch_spread, pitch_spread)
	voice.volume_db = volume_db
	voice.play()
