class_name FishSkin
extends RefCounted
## Premium fish looks: animated shader effects that replace a fish's flat palette color.
## They are sold through "#color <name>" at a higher price than the palette colors, see
## [ShopCatalog]. The drawing is [code]assets/shaders/fish_skin.gdshader[/code], selected per
## [enum Kind]; [member GLOW] is the tint of the fish's halo.

## The shader's `mode` uniform is the value of the kind. NONE is the plain palette color.
enum Kind {
	NONE,
	NEON,
	ATOMIC,
	RAINBOW,
	GHOST,
	MISSING_TEXTURE,
	MATRIX,
	GOLD,
	LAVA,
	GALAXY,
	GLITCH,
}

## Chat names, in the order of [enum Kind] after NONE.
const NAMES: Array[String] = [
	"neon",
	"atomic",
	"rainbow",
	"ghost",
	"missing",
	"matrix",
	"gold",
	"lava",
	"galaxy",
	"glitch",
]
## Other spellings a viewer may type, mapped to [constant NAMES].
const ALIASES: Dictionary = {
	"missing texture": "missing",
	"missingtexture": "missing",
	"missing_texture": "missing",
}
## The fish's base color and accent (eye, glow, fin edge) per kind. The shader paints the body.
const ACCENTS: Array[Color] = [
	Color("ff2bd6"),
	Color("9dff2b"),
	Color("ffd23f"),
	Color("cfe6ff"),
	Color("ff00ff"),
	Color("33ff66"),
	Color("ffc83d"),
	Color("ff6a1a"),
	Color("9b6bff"),
	Color("19f0e0"),
]
## Kinds whose halo changes color over time.
const ANIMATED_GLOW: Array[int] = [Kind.NEON, Kind.RAINBOW, Kind.GLITCH]
const SHADER: Shader = preload("res://assets/shaders/fish_skin.gdshader")

static var _materials: Dictionary = {}


## The canonical chat name of [param item] (case and aliases resolved), or "" if it is none.
static func canonical(item: String) -> String:
	var wanted: String = item.strip_edges().to_lower()
	wanted = String(ALIASES.get(wanted, wanted))
	return wanted if NAMES.has(wanted) else ""


## The [enum Kind] for a chat name, NONE if unknown.
static func kind_of(item: String) -> int:
	return NAMES.find(canonical(item)) + 1


## Chat name of a [enum Kind], "" for NONE.
static func name_of(kind: int) -> String:
	return NAMES[kind - 1] if kind > 0 and kind <= NAMES.size() else ""


## Accent color of a kind, white for NONE.
static func accent_of(kind: int) -> Color:
	return ACCENTS[kind - 1] if kind > 0 and kind <= ACCENTS.size() else Color.WHITE


## The shared shader material of a kind, or null for NONE. Fish share it, so the effect runs
## in step across the school and compiles once.
static func material_of(kind: int) -> ShaderMaterial:
	if kind <= 0 or kind > NAMES.size():
		return null
	if not _materials.has(kind):
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("mode", kind)
		_materials[kind] = material
	return _materials[kind]
