class_name UnitDefs
## Unit stats. Display names live here so a store build can rename them.
## Weapons: cannon (shell + splash + small crater), rifle (hitscan tracer),
## laser (anti-air beam), drone_launch (spawns a loitering munition),
## autocannon (fast bursts of small explosive rounds, used by boats).
## "naval": true units move on water only.

const FACTION_NAMES := {
	"coalition": "Coalition (US / UAE)",
	"iran": "Iran (IRGC)",
	"oracle": "ORACLE",
}

const DEFS := {
	"abrams": {
		"display": "Abrams-class Tank", "faction": "coalition", "model": "tank",
		"hp": 650.0, "speed": 6.5, "radius": 1.7, "range": 24.0, "vision": 32.0,
		"weapon": "cannon", "damage": 95.0, "cooldown": 2.4, "splash": 2.5, "crater": 1.2,
		"targets": "ground", "turret_speed": 2.2,
	},
	"ranger": {
		"display": "Ranger", "faction": "coalition", "model": "soldier",
		"hp": 90.0, "speed": 3.6, "radius": 0.5, "range": 17.0, "vision": 26.0,
		"weapon": "rifle", "damage": 9.0, "cooldown": 0.55, "splash": 0.0, "crater": 0.0,
		"targets": "both",
	},
	"k9": {
		"display": "K9 Robot Dog", "faction": "coalition", "model": "robodog",
		"hp": 140.0, "speed": 8.0, "radius": 0.7, "range": 14.0, "vision": 36.0,
		"weapon": "rifle", "damage": 7.0, "cooldown": 0.25, "splash": 0.0, "crater": 0.0,
		"targets": "ground",
	},
	"laser_ad": {
		"display": "Laser Air Defence", "faction": "coalition", "model": "laser_truck",
		"hp": 320.0, "speed": 5.5, "radius": 1.6, "range": 38.0, "vision": 40.0,
		"weapon": "laser", "damage": 45.0, "cooldown": 0.6, "splash": 0.0, "crater": 0.0,
		"targets": "air", "turret_speed": 5.0,
	},
	"patrol_boat": {
		"display": "Mk VI-class Patrol Boat", "faction": "coalition", "model": "patrol_boat",
		"hp": 420.0, "speed": 11.0, "radius": 2.6, "range": 30.0, "vision": 42.0,
		"weapon": "autocannon", "damage": 16.0, "cooldown": 0.9, "splash": 1.2, "crater": 0.0,
		"targets": "both", "turret_speed": 3.5, "naval": true,
	},
	"karrar": {
		"display": "Karrar-style Tank", "faction": "iran", "model": "tank",
		"hp": 540.0, "speed": 5.8, "radius": 1.7, "range": 22.0, "vision": 28.0,
		"weapon": "cannon", "damage": 85.0, "cooldown": 2.7, "splash": 2.5, "crater": 1.2,
		"targets": "ground", "turret_speed": 1.8,
	},
	"irgc": {
		"display": "IRGC Rifleman", "faction": "iran", "model": "soldier",
		"hp": 80.0, "speed": 3.6, "radius": 0.5, "range": 16.0, "vision": 24.0,
		"weapon": "rifle", "damage": 8.0, "cooldown": 0.65, "splash": 0.0, "crater": 0.0,
		"targets": "both",
	},
	"fast_boat": {
		"display": "IRGC Fast Attack Craft", "faction": "iran", "model": "fast_boat",
		"hp": 160.0, "speed": 14.0, "radius": 1.6, "range": 22.0, "vision": 30.0,
		"weapon": "autocannon", "damage": 9.0, "cooldown": 0.7, "splash": 0.8, "crater": 0.0,
		"targets": "ground", "turret_speed": 4.0, "naval": true,
	},
	"shahed_launcher": {
		"display": "Shahed-style Drone Launcher", "faction": "iran", "model": "launcher_truck",
		"hp": 300.0, "speed": 4.8, "radius": 1.6, "range": 85.0, "vision": 30.0,
		"weapon": "drone_launch", "damage": 170.0, "cooldown": 9.0, "splash": 4.0, "crater": 2.4,
		"targets": "ground", "turret_speed": 1.0,
	},
	"shahed": {
		"display": "Shahed-style Drone", "faction": "iran", "model": "drone",
		"hp": 45.0, "speed": 15.0, "radius": 0.8, "range": 2.0, "vision": 12.0,
		"weapon": "none", "damage": 170.0, "cooldown": 1.0, "splash": 4.0, "crater": 2.4,
		"targets": "ground", "air": true,
	},
}


static func get_def(id: String) -> Dictionary:
	return DEFS[id]
