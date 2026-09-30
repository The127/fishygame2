class_name UiStyle
extends RefCounted
## Shared look for the in-race UI, matching the home screen: dark ocean panels,
## cyan outlines and the green-to-cyan title gradient, all in Exo 2.

const FONT_PATH: String = "res://assets/fonts/Exo2.ttf"
const GRADIENT_SHADER_PATH: String = "res://assets/shaders/title_gradient.gdshader"
const WEIGHT_TAG: int = 2003265652  # OpenType "wght"

const CYAN: Color = Color(0.0, 0.8, 1.0)
const CYAN_LIGHT: Color = Color(0.5, 0.92, 1.0)
const TEXT: Color = Color(0.93, 0.98, 1.0)
const MUTED: Color = Color(0.416, 0.624, 0.769)
const PANEL_BG: Color = Color(0.012, 0.047, 0.102, 0.86)
const GOOD: Color = Color(0.0, 0.91, 0.533)
const BAD: Color = Color(1.0, 0.45, 0.5)


static func font(weight: int = 600, spacing: int = 0) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = load(FONT_PATH)
	variation.variation_opentype = {WEIGHT_TAG: float(weight)}
	variation.spacing_glyph = spacing
	return variation


static func panel_box(border_alpha: float = 0.6) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_BG
	box.set_border_width_all(2)
	box.border_color = Color(CYAN, border_alpha)
	box.set_corner_radius_all(12)
	box.shadow_color = Color(CYAN, 0.2)
	box.shadow_size = 16
	box.content_margin_left = 28.0
	box.content_margin_right = 28.0
	box.content_margin_top = 16.0
	box.content_margin_bottom = 16.0
	return box


static func button_box(hover: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(CYAN, 0.14 if hover else 0.0)
	box.set_border_width_all(2)
	box.border_color = CYAN_LIGHT if hover else CYAN
	box.set_corner_radius_all(6)
	box.shadow_color = Color(CYAN, 0.4 if hover else 0.2)
	box.shadow_size = 12 if hover else 8
	box.content_margin_left = 16.0
	box.content_margin_right = 16.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	return box


## Grayed-out look for a button that cannot be pressed right now.
static func disabled_button_box() -> StyleBoxFlat:
	var box: StyleBoxFlat = button_box(false)
	box.bg_color = Color(MUTED, 0.12)
	box.border_color = Color(MUTED, 0.5)
	box.shadow_size = 0
	return box


static func gradient_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(GRADIENT_SHADER_PATH)
	return material


## Outlined text that stays readable over any track or 3D scene.
static func style_label(
	label: Label, size: int, weight: int = 600, color: Color = TEXT, spacing: int = 0
) -> void:
	label.add_theme_font_override("font", font(weight, spacing))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.03, 0.08, 0.95))
	label.add_theme_constant_override("outline_size", 6)


static func style_button(button: BaseButton, size: int = 24) -> void:
	button.add_theme_font_override("font", font(700, 3))
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_color", CYAN)
	for state: String in ["font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color.WHITE)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("normal", button_box(false))
	button.add_theme_stylebox_override("hover", button_box(true))
	button.add_theme_stylebox_override("pressed", button_box(true))
	button.add_theme_stylebox_override("focus", button_box(true))
	button.add_theme_stylebox_override("disabled", button_box(false))
