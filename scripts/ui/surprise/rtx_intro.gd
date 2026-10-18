class_name RtxIntro
extends CanvasLayer
## The one-time, completely overdone introduction of the RTX switch, right after the fake 3D
## sequel unlocked it: the classic "RTX OFF / RTX ON" comparison. The screen goes pixelated
## and grey, a glowing divider sweeps in and reveals the real RTX look on the right, then whips
## away for a full-screen "RTX UNLOCKED" that flies into the switch's corner.
## Owns its own [RtxFilter]; frees itself when done.

signal finished

const LAYER: int = 20
const GREEN: Color = Color(0.46, 0.73, 0.0)
const OFF_GREY: Color = Color(0.62, 0.62, 0.6)
## Seconds from the start to each beat.
const SWEEP_AT: float = 0.9
const ON_AT: float = 1.6
const WHIP_AT: float = 3.4
const UNLOCKED_AT: float = 3.75
const FLY_AT: float = 5.4
const END_AT: float = 5.9

## Where "RTX UNLOCKED" flies to at the end, in screen pixels (the switch).
var target: Vector2 = Vector2.ZERO

var _filter: RtxFilter = RtxFilter.new()
var _root: Control
var _off: Label
var _on: Label
var _unlocked: Label
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	layer = LAYER
	_filter.set_badge_visible(false)
	_filter.set_split(1.01)
	_filter.set_enabled(true)
	add_child(_filter)
	_root = Control.new()
	_root.name = "Captions"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_off = _caption("RTX OFF", _plain_look())
	_off.anchor_right = 0.5
	_on = _caption("RTX ON", _green_look(130))
	_on.anchor_left = 0.5
	_unlocked = _caption("RTX UNLOCKED", _green_look(170))


## Runs the whole show. Emits [signal finished] at the end, then frees itself.
func play() -> void:
	_rng.randomize()
	_slam(_off, 3.0)
	await _wait(SWEEP_AT)
	Sound.play(Sound.Sfx.KRAKEN_SWOOSH)
	var sweep: Tween = create_tween()
	sweep.tween_method(_filter.set_split, 1.01, 0.5, ON_AT - SWEEP_AT).set_trans(Tween.TRANS_EXPO)
	await _wait(ON_AT - SWEEP_AT)
	_slam(_on, 3.0)
	_flash(0.6, 0.3)
	await _wait(WHIP_AT - ON_AT)
	Sound.play(Sound.Sfx.KRAKEN_SWOOSH)
	var whip: Tween = create_tween()
	(
		whip
		. tween_method(_filter.set_split, 0.5, -0.02, UNLOCKED_AT - WHIP_AT)
		. set_trans(Tween.TRANS_EXPO)
		. set_ease(Tween.EASE_IN)
	)
	var fall: Tween = create_tween().set_parallel()
	fall.tween_property(_off, "position:y", _off.position.y + 900.0, 0.7).set_ease(Tween.EASE_IN)
	fall.tween_property(_off, "rotation", -0.8, 0.7)
	fall.tween_property(_on, "modulate:a", 0.0, 0.3)
	await _wait(UNLOCKED_AT - WHIP_AT)
	_filter.set_split(-1.0)
	_flash(1.0, 0.5)
	_slam(_unlocked, 4.0, 40.0)
	await _wait(FLY_AT - UNLOCKED_AT)
	_unlocked.pivot_offset = _unlocked.size / 2.0
	var fly: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK)
	fly.tween_property(_unlocked, "scale", Vector2.ONE * 0.12, END_AT - FLY_AT).set_ease(
		Tween.EASE_IN
	)
	(
		fly
		. tween_property(_unlocked, "position", target - _unlocked.size / 2.0, END_AT - FLY_AT)
		. set_ease(Tween.EASE_IN)
	)
	await _wait(END_AT - FLY_AT)
	finished.emit()
	queue_free()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _caption(text: String, look: LabelSettings) -> Label:
	var label := Label.new()
	label.text = text
	label.label_settings = look
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.modulate.a = 0.0
	_root.add_child(label)
	return label


func _plain_look() -> LabelSettings:
	var look := LabelSettings.new()
	look.font = UiStyle.font(400)
	look.font_size = 130
	look.font_color = OFF_GREY
	look.outline_color = Color(0.2, 0.2, 0.2)
	look.outline_size = 6
	return look


func _green_look(size: int) -> LabelSettings:
	var look := LabelSettings.new()
	look.font = UiStyle.font(900, 4)
	look.font_size = size
	look.font_color = Color.WHITE
	look.outline_color = GREEN
	look.outline_size = 30
	look.shadow_color = Color(GREEN, 0.9)
	look.shadow_size = 60
	look.shadow_offset = Vector2.ZERO
	return look


## Drops [param label] in from [param from_scale] times its size, with a hit and a shake.
func _slam(label: Label, from_scale: float, shake: float = 24.0) -> void:
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2.ONE * from_scale
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	tween.tween_property(label, "modulate:a", 1.0, 0.12)
	tween.chain().tween_callback(Sound.play.bind(Sound.Sfx.BLAST_HIT))
	tween.tween_method(_shake, shake, 0.0, 0.45)


func _shake(strength: float) -> void:
	offset = Vector2(_rng.randf_range(-strength, strength), _rng.randf_range(-strength, strength))


func _flash(amount: float, seconds: float) -> void:
	create_tween().tween_method(_filter.set_flash, amount, 0.0, seconds)
