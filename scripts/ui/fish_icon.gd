class_name FishIcon
extends Control
## A small still picture of a fish for lists. Wraps a [FishVisual] so it always matches
## the fish that races; the visual is frozen, so it costs nothing per frame.

const ICON_SIZE: Vector2 = Vector2(56.0, 32.0)
const FISH_SCALE: float = 0.75

var _fish: FishVisual


## [param look] holds "color", "species", "pattern" and "accessory", as on a [Contestant].
func _init(look: Dictionary = {}) -> void:
	custom_minimum_size = ICON_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fish = FishVisual.new()
	_fish.frozen = true
	_fish.color = look.get("color", Color.WHITE)
	_fish.species = int(look.get("species", 0))
	_fish.pattern = int(look.get("pattern", 0))
	_fish.accessory = int(look.get("accessory", 0))
	add_child(_fish)
	# FishVisual detaches itself in _ready to follow a marble; here it stays in the row.
	_fish.top_level = false
	_fish.scale = Vector2.ONE * FISH_SCALE
	_fish.position = ICON_SIZE * 0.5


func fish() -> FishVisual:
	return _fish
