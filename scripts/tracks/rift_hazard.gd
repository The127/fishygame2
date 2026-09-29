class_name RiftHazard
extends Hazard
## A portal turns unstable: it flickers red while telegraphing, then for the event fish that
## enter it are thrown back to its divert point instead of ahead. The portals are PortalPair
## children.

## Seconds the red glow takes to fade at the end of the event.
const FADE: float = 0.5

var _pairs: Array[PortalPair] = []
var _pair: PortalPair = null


func _ready() -> void:
	for child: Node in get_children():
		if child is PortalPair:
			_pairs.append(child as PortalPair)


## The portal currently unstable, or null.
func get_active_pair() -> PortalPair:
	return _pair


func _begin_telegraph(rng: RandomNumberGenerator) -> void:
	if _pairs.is_empty():
		return
	_pair = _pairs[rng.randi_range(0, _pairs.size() - 1)]


func _process_telegraph(_delta: float) -> void:
	if _pair != null:
		_pair.unstable = phase_progress()


func _begin_active() -> void:
	if _pair != null:
		_pair.diverted = true
		_pair.unstable = 1.0


func _process_active(_delta: float) -> void:
	if _pair != null:
		_pair.unstable = clampf((active_seconds - phase_time) / FADE, 0.0, 1.0)


func _end_event() -> void:
	if _pair != null:
		_pair.diverted = false
		_pair.unstable = 0.0
	_pair = null


func _reset() -> void:
	for pair: PortalPair in _pairs:
		pair.reset()
	_pair = null
