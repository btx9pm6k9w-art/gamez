extends Node
## Audio manager: bus mix, 3D sound effects with variation, looping vehicle
## and drone engines, ambience and adaptive music driven by combat intensity.
##
## Recorded assets override the procedural placeholders automatically: drop
## res://audio/sfx/<name>.ogg (or <name>_1.ogg, <name>_2.ogg ... for random
## variations), res://audio/music/<stem>.ogg (calm, tension, combat) and
## res://audio/ambience/coast.ogg into the project.

const SFX_NAMES := ["explosion_small", "explosion_big", "cannon", "rifle", "laser", "launch",
	"drone_engine", "engine", "missile_incoming", "jet", "bomb_whistle", "fire", "ui_select", "ui_confirm", "ui_error", "alert"]
const STEMS := ["calm", "tension", "combat"]

var intensity := 0.0
var is_ready := false

var _sfx := {} # name -> Array[AudioStream]
var _active := {}
var _music: Array[AudioStreamPlayer] = []
var _ambience: AudioStreamPlayer
var _ui: AudioStreamPlayer


func _ready() -> void:
	_setup_buses()
	_ui = AudioStreamPlayer.new()
	_ui.bus = "UI"
	_ui.max_polyphony = 4
	add_child(_ui)
	WorkerThreadPool.add_task(_render)


func _setup_buses() -> void:
	for bus_name in ["Music", "SFX", "Ambience", "UI", "Voice"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -0.5
	AudioServer.add_bus_effect(0, limiter)

	var sfx := AudioServer.get_bus_index("SFX")
	var reverb := AudioEffectReverb.new() # open desert: short, airy tail
	reverb.room_size = 0.55
	reverb.damping = 0.6
	reverb.spread = 1.0
	reverb.hipass = 0.25
	reverb.wet = 0.12
	reverb.dry = 1.0
	AudioServer.add_bus_effect(sfx, reverb)
	var glue := AudioEffectCompressor.new()
	glue.threshold = -14.0
	glue.ratio = 3.0
	glue.attack_us = 2000.0
	glue.release_ms = 180.0
	AudioServer.add_bus_effect(sfx, glue)

	# Music ducks under big explosions (sidechain from the SFX bus).
	var music := AudioServer.get_bus_index("Music")
	var duck := AudioEffectCompressor.new()
	duck.sidechain = "SFX"
	duck.threshold = -20.0
	duck.ratio = 4.0
	duck.release_ms = 400.0
	AudioServer.add_bus_effect(music, duck)
	AudioServer.set_bus_volume_db(music, -4.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), -10.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("UI"), -8.0)


## Background render of the procedural placeholders (a few seconds of CPU).
func _render() -> void:
	var d := {}
	d["explosion_small"] = [SoundSynth.explosion(1, 0.7), SoundSynth.explosion(2, 0.8), SoundSynth.explosion(3, 0.9)]
	d["explosion_big"] = [SoundSynth.explosion(4, 2.2), SoundSynth.explosion(5, 2.6)]
	d["cannon"] = [SoundSynth.cannon(6), SoundSynth.cannon(7)]
	d["rifle"] = [SoundSynth.rifle(8), SoundSynth.rifle(9), SoundSynth.rifle(10), SoundSynth.rifle(11)]
	d["laser"] = [SoundSynth.laser()]
	d["launch"] = [SoundSynth.missile_whoosh()]
	d["missile_incoming"] = [SoundSynth.missile_whoosh()]
	d["drone_engine"] = [SoundSynth.drone_engine()]
	d["engine"] = [SoundSynth.engine_rumble()]
	d["jet"] = [SoundSynth.jet()]
	d["bomb_whistle"] = [SoundSynth.bomb_whistle()]
	d["fire"] = [SoundSynth.fire()]
	d["ui_select"] = [SoundSynth.blip([1320.0], 0.06)]
	d["ui_confirm"] = [SoundSynth.blip([990.0, 1480.0], 0.05)]
	d["ui_error"] = [SoundSynth.blip([300.0, 220.0], 0.08)]
	d["alert"] = [SoundSynth.radio()]
	d["music_calm"] = [SoundSynth.music_pad()]
	d["music_tension"] = [SoundSynth.music_ostinato()]
	d["music_combat"] = [SoundSynth.music_drums()]
	d["ambience"] = [SoundSynth.ambience()]
	_on_rendered.call_deferred(d)


func _on_rendered(d: Dictionary) -> void:
	for key: String in d:
		_sfx[key] = _overrides(key, d[key])
	is_ready = true
	_start_beds()


func _overrides(key: String, fallback: Array) -> Array:
	var path_base := "res://audio/sfx/%s" % key
	if key.begins_with("music_"):
		path_base = "res://audio/music/%s" % key.trim_prefix("music_")
	elif key == "ambience":
		path_base = "res://audio/ambience/coast"
	var found: Array = []
	if ResourceLoader.exists(path_base + ".ogg"):
		found.append(load(path_base + ".ogg"))
	for i in range(1, 9):
		var p := "%s_%d.ogg" % [path_base, i]
		if ResourceLoader.exists(p):
			found.append(load(p))
	if found.is_empty():
		return fallback
	for s in found:
		if s is AudioStreamOggVorbis and (key.begins_with("music_") or key == "ambience" or key.ends_with("engine") or key in ["jet", "fire"]):
			(s as AudioStreamOggVorbis).loop = true
	return found


func _start_beds() -> void:
	for stem in STEMS:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.stream = _pick("music_" + stem)
		p.volume_db = -6.0 if stem == "calm" else -60.0
		add_child(p)
		_music.append(p)
	for p in _music:
		p.play() # started together so the stems stay in sync
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Ambience"
	_ambience.stream = _pick("ambience")
	add_child(_ambience)
	_ambience.play()


func _pick(key: String) -> AudioStream:
	var list: Array = _sfx.get(key, [])
	return null if list.is_empty() else list[randi() % list.size()]


## One-shot positional sound with random pitch for natural variation.
func play_3d(key: String, pos: Vector3, volume_db := 0.0, pitch := 1.0, max_concurrent := 8) -> void:
	if not is_ready or _active.get(key, 0) >= max_concurrent:
		return
	var stream := _pick(key)
	if stream == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = "SFX"
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.93, 1.07)
	p.unit_size = 30.0
	p.max_distance = 450.0
	p.attenuation_filter_cutoff_hz = 7000.0
	p.attenuation_filter_db = -14.0
	add_child(p)
	p.global_position = pos
	_active[key] = _active.get(key, 0) + 1
	p.finished.connect(func() -> void:
		_active[key] = maxi(_active.get(key, 1) - 1, 0)
		p.queue_free())
	p.play()


func play_ui(key: String) -> void:
	if not is_ready:
		return
	_ui.stream = _pick(key)
	_ui.play()


## Looping positional sound that follows a node (engines, drones).
## Also used for one-shots that must travel with a moving node (bomb whistle);
## doppler adds the pitch drop of fast passes (jets).
func attach_loop(node: Node3D, key: String, volume_db := 0.0, unit_size := 22.0, doppler := false) -> AudioStreamPlayer3D:
	if not is_ready:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = _pick(key)
	p.bus = "SFX"
	p.volume_db = volume_db
	p.unit_size = unit_size
	p.max_distance = maxf(300.0, unit_size * 12.0)
	if doppler:
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_IDLE_STEP
	p.pitch_scale = randf_range(0.92, 1.08)
	node.add_child(p)
	p.play()
	return p


## Combat feeds intensity; music layers follow it.
func bump_intensity(amount: float) -> void:
	intensity = minf(intensity + amount, 1.0)


func _process(delta: float) -> void:
	intensity = maxf(intensity - delta * 0.04, 0.0)
	if _music.size() == 3:
		var tension := smoothstep(0.1, 0.45, intensity)
		var combat := smoothstep(0.45, 0.85, intensity)
		_music[0].volume_db = lerpf(_music[0].volume_db, lerpf(-6.0, -12.0, combat), delta * 1.5)
		_music[1].volume_db = lerpf(_music[1].volume_db, lerpf(-60.0, -9.0, tension), delta * 1.5)
		_music[2].volume_db = lerpf(_music[2].volume_db, lerpf(-60.0, -5.0, combat), delta * 1.5)
