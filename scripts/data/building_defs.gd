class_name BuildingDefs
## Base structures (C&C style). A structure is a Unit that never moves, so it
## shares health bars, targeting, fog and damage with everything else. The
## keys a Unit reads (speed, range, weapon and so on) are filled in by
## get_def() so each entry only lists what makes it different.
##
## power: positive supplies, negative drains. Below zero the base is on low
## power: production runs at half speed and defences stop firing.
## produces: the production line this structure opens (infantry, vehicle).
## requires: structures that must be standing before this one can be built.
## income: credits per second (refinery).

const BASE := {
	"faction": "coalition", "speed": 0.0, "range": 0.0, "vision": 22.0,
	"weapon": "none", "damage": 0.0, "cooldown": 1.0, "splash": 0.0, "crater": 0.0,
	"targets": "ground", "armor": "structure", "power": 0, "requires": [],
}

const DEFS := {
	"fob": {
		"display": "Forward Operating Base", "model": "fob",
		"hp": 3000.0, "radius": 6.0, "vision": 34.0, "power": 20,
		"build_time": 30.0, "cost": 3000,
		"blurb": "Builds every other structure. Lose it and you cannot rebuild.",
	},
	"power_plant": {
		"display": "Power Plant", "model": "power_plant",
		"hp": 900.0, "radius": 4.0, "power": 100,
		"build_time": 10.0, "cost": 600, "requires": ["fob"],
		"blurb": "+100 power. Everything else draws on it.",
	},
	"refinery": {
		"display": "Oil Refinery", "model": "refinery",
		"hp": 1400.0, "radius": 5.5, "power": -30, "income": 5.0,
		"build_time": 16.0, "cost": 1400, "requires": ["power_plant"],
		"blurb": "+5 credits/s, and +25% from every derrick you hold.",
	},
	"barracks": {
		"display": "Barracks", "model": "barracks",
		"hp": 1000.0, "radius": 4.5, "power": -20, "produces": "infantry",
		"build_time": 10.0, "cost": 500, "requires": ["power_plant"],
		"blurb": "Trains Rangers, Javelin teams and K9 dogs.",
	},
	"vehicle_depot": {
		"display": "Vehicle Depot", "model": "vehicle_depot",
		"hp": 1600.0, "radius": 6.0, "power": -40, "produces": "vehicle",
		"build_time": 18.0, "cost": 1800, "requires": ["refinery"],
		"blurb": "Builds tanks and laser trucks.",
	},
	"guard_post": {
		"display": "Guard Post", "model": "guard_post",
		"hp": 800.0, "radius": 2.0, "power": -10, "vision": 30.0,
		"range": 22.0, "weapon": "autocannon", "damage": 14.0, "cooldown": 1.0, "splash": 1.2,
		"targets": "ground", "turret_speed": 3.0,
		"build_time": 8.0, "cost": 450, "requires": ["barracks"],
		"blurb": "Autocannon bunker. Shreds infantry and light vehicles.",
	},
	"interceptor": {
		"display": "Interceptor Battery", "model": "interceptor",
		"hp": 700.0, "radius": 2.5, "power": -30, "vision": 40.0,
		"range": 42.0, "weapon": "laser", "damage": 34.0, "cooldown": 0.7,
		"targets": "air", "turret_speed": 4.0,
		"build_time": 12.0, "cost": 900, "requires": ["power_plant"],
		"blurb": "Shoots down drones and missiles. Needs power.",
	},
}

## Sidebar order for structures the player can build.
const BUILD_ORDER := ["power_plant", "refinery", "barracks", "vehicle_depot", "guard_post", "interceptor"]

static var _cache := {}


static func has(id: String) -> bool:
	return DEFS.has(id)


## The full definition: BASE merged under the entry, "structure": true added.
static func get_def(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var d := BASE.duplicate(true)
	d.merge(DEFS[id], true)
	d["structure"] = true
	d["category"] = "structure"
	_cache[id] = d
	return d
