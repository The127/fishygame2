class_name RaceEvent
extends RefCounted
## Random map events: the wheel that is spun before a race and the modifiers it can land on.
## An event is an id from [constant EVENTS], or [constant NOTHING]. Applying one draws nothing
## from a race's rng, so a seed still replays the same race under the same event.

## Id of the plain result: the race runs as usual.
const NOTHING: String = ""

const LOW_GRAVITY: String = "low_gravity"
const DOUBLE_HAZARDS: String = "double_hazards"
const LIGHTS_OUT: String = "lights_out"
const BOUNCY: String = "bouncy"

## Every modifier: display name, one line of what it does, the short wheel label and its color.
const EVENTS: Dictionary = {
	LOW_GRAVITY:
	{
		"name": "Low gravity",
		"blurb": "Fish sink slowly",
		"short": "LOW G",
		"color": Color(0.45, 0.6, 1.0),
	},
	DOUBLE_HAZARDS:
	{
		"name": "Double hazards",
		"blurb": "Hazards strike twice as often",
		"short": "x2",
		"color": Color(1.0, 0.5, 0.35),
	},
	LIGHTS_OUT:
	{
		"name": "Lights out",
		"blurb": "The map goes dark, the fish glow",
		"short": "DARK",
		"color": Color(0.6, 0.4, 0.9),
	},
	BOUNCY:
	{
		"name": "Bouncy",
		"blurb": "Everything bounces",
		"short": "BOUNCE",
		"color": Color(0.35, 0.9, 0.5),
	},
}

## Wheel layout, clockwise from the top. Mostly nothing, so an event stays a surprise.
const WHEEL: Array[String] = [
	NOTHING,
	LOW_GRAVITY,
	NOTHING,
	NOTHING,
	DOUBLE_HAZARDS,
	NOTHING,
	NOTHING,
	LIGHTS_OUT,
	NOTHING,
	NOTHING,
	BOUNCY,
	NOTHING,
]

## Shortest countdown, in seconds, that leaves the wheel time to spin and show its result.
const MIN_COUNTDOWN: int = 6
const LOW_GRAVITY_SCALE: float = 0.85
const BOUNCY_BOUNCE: float = 0.6
const DARK_TRACK: Color = Color(0.3, 0.34, 0.45)
const LIGHTS_OUT_GLOW: float = 2.0
## Longest a hazard frequency can get.
const MAX_HAZARD_LEVEL: int = 5


## The wheel's slices. Double hazards needs hazards to double, so a game with hazards off
## gets [constant NOTHING] in its place.
static func wheel(hazards_enabled: bool) -> Array[String]:
	var slices: Array[String] = []
	for id: String in WHEEL:
		slices.append(id if hazards_enabled or id != DOUBLE_HAZARDS else NOTHING)
	return slices


## Picks the slice the wheel lands on. Returns its index in [param slices].
static func spin(slices: Array[String], rng: RandomNumberGenerator) -> int:
	return rng.randi_range(0, slices.size() - 1)


static func is_event(id: String) -> bool:
	return EVENTS.has(id)


static func name_of(id: String) -> String:
	return String((EVENTS.get(id, {}) as Dictionary).get("name", "Nothing"))


static func blurb_of(id: String) -> String:
	return String((EVENTS.get(id, {}) as Dictionary).get("blurb", ""))


static func short_of(id: String) -> String:
	return String((EVENTS.get(id, {}) as Dictionary).get("short", "-"))


static func color_of(id: String) -> Color:
	return (EVENTS.get(id, {}) as Dictionary).get("color", Color(0.2, 0.3, 0.4))


## The hazard frequency a race runs at under [param id], given the setting's `base` (0 = off).
static func hazard_level(id: String, base: int) -> int:
	if id == DOUBLE_HAZARDS and base > 0:
		return mini(base * 2, MAX_HAZARD_LEVEL)
	return base


static func gravity_scale(id: String) -> float:
	return LOW_GRAVITY_SCALE if id == LOW_GRAVITY else 1.0


## Bounce of the fish, or a negative number to keep their own.
static func bounce(id: String) -> float:
	return BOUNCY_BOUNCE if id == BOUNCY else -1.0


static func track_tint(id: String) -> Color:
	return DARK_TRACK if id == LIGHTS_OUT else Color.WHITE


static func glow_scale(id: String) -> float:
	return LIGHTS_OUT_GLOW if id == LIGHTS_OUT else 1.0
