extends RefCounted
## Unit acknowledgements ("Moving out", "Target acquired") and alerts ("Units
## under attack"), the way C&C, Red Alert and StarCraft units answer every
## click. Until recorded voice lines exist this speaks them with the system's
## text-to-speech voices (macOS and Windows both ship good ones). Recorded Ogg
## lines in res://audio/voice/<key>.ogg will replace it later.
##
## Rules from the classics: one line per click (never one per unit), a short
## cooldown so rapid clicks do not stack, a different voice per faction, and
## alerts interrupt acknowledgements.

const LINES := {
	"select": {
		"tank": ["Armor ready.", "Tank crew standing by.", "Abrams here."],
		"soldier": ["Rangers ready.", "Yes sir?", "Reporting."],
		"robodog": ["K9 online.", "Unit active."],
		"laser_truck": ["Air defence online.", "Laser charged."],
		"patrol_boat": ["Patrol boat ready.", "Helm here."],
	},
	"move": {
		"tank": ["Rolling out.", "Moving.", "On our way."],
		"soldier": ["Moving out.", "On it.", "Copy that."],
		"robodog": ["Relocating.", "Path set."],
		"laser_truck": ["Repositioning.", "Moving."],
		"patrol_boat": ["Coming about.", "Underway."],
	},
	"attack": {
		"tank": ["Target acquired.", "Engaging.", "Fire for effect."],
		"soldier": ["Weapons free.", "Engaging.", "Contact."],
		"robodog": ["Target locked.", "Engaging."],
		"laser_truck": ["Tracking.", "Locked on."],
		"patrol_boat": ["Guns hot.", "Engaging."],
	},
}

const ALERTS := {
	"under_attack": "Units under attack.",
	"unit_lost": "Unit lost.",
	"wave": "Enemy forces approaching.",
	"strike": "Strike inbound.",
	"objective": "Objective complete.",
	"objective_new": "New objective.",
	"objective_failed": "Objective failed.",
	"mission_won": "Mission accomplished.",
	"mission_lost": "Mission failed.",
	"reinforcements": "Reinforcements have arrived.",
	"building": "Building.",
	"insufficient": "Insufficient funds.",
	"derrick": "Oil derrick captured.",
	"derrick_lost": "Oil derrick lost.",
	"counter_attack": "Enemy counter-attack detected.",
}

static var enabled := true
static var _voice := ""
static var _alert_voice := ""
static var _inited := false
static var _available := false
static var _next_time := 0.0
static var _last_alert := {}


static func _init_voices() -> void:
	_inited = true
	if not ProjectSettings.get_setting("audio/general/text_to_speech", false):
		enabled = false
		return
	var voices := DisplayServer.tts_get_voices_for_language("en")
	if voices.is_empty():
		enabled = false
		return
	_available = true
	_voice = voices[0]
	_alert_voice = voices[mini(1, voices.size() - 1)]
	# Prefer a US voice for the troops and a different one for the base AI.
	for v: Dictionary in DisplayServer.tts_get_voices():
		var lang := String(v.get("language", ""))
		if lang.begins_with("en_US") or lang.begins_with("en-US"):
			if _voice == voices[0]:
				_voice = v["id"]
			elif v["id"] != _voice:
				_alert_voice = v["id"]
				break


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## kind: "select", "move" or "attack"; model: the unit's model key.
static func ack(kind: String, model: String) -> void:
	if not _inited:
		_init_voices()
	if not enabled or not _available or _now() < _next_time:
		return
	var by_model: Dictionary = LINES.get(kind, {})
	var lines: Array = by_model.get(model, by_model.get("soldier", []))
	if lines.is_empty():
		return
	_next_time = _now() + 1.4
	DisplayServer.tts_speak(lines.pick_random(), _voice, 55, 1.0, 1.1)


## Base-AI alert, rate limited per kind (classic EVA spacing).
static func alert(kind: String, min_gap := 12.0) -> void:
	if not _inited:
		_init_voices()
	if not enabled or not _available or _now() < float(_last_alert.get(kind, -100.0)) + min_gap:
		return
	_last_alert[kind] = _now()
	_next_time = _now() + 1.6
	DisplayServer.tts_speak(ALERTS.get(kind, kind), _alert_voice, 65, 0.9, 1.0, 0, true)


static func toggle() -> bool:
	if not _inited:
		_init_voices()
	enabled = _available and not enabled
	if _available and not enabled:
		DisplayServer.tts_stop()
	return enabled
