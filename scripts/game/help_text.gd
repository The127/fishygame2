class_name HelpText
extends RefCounted
## What viewers are told about the chat commands: one chat line and the lobby cheat sheet.

## Chat reply to "#help". Kept well under Twitch's 500 character limit.
const CHAT_REPLY: String = (
	"Commands: #join | #lurk | #bet <fish> <amount> | #boost <fish> | #curse <fish> | "
	+ "#points | #stats | #top | #rival <name> | #shop | #fish <species> | #color <name> | #hat <name> | #trail <name> | #dance <name> | "
	+ "#left / #right (Pinball Reef 1 and 2 flippers, Claw Machine, Gravity Flip) | "
	+ "#grab (Claw Machine) | #up / #down (Gravity Flip) | "
	+ "#shake (Earthquake Fault) | #roll (Board Game) | "
	+ "#chop (Sushi Bar) | "
	+ "#eddy (flushed-out fish)"
)

const TITLE: String = "CHAT COMMANDS"

## Lobby cheat sheet rows that apply on every map: [command, what it does].
const GENERAL: Array[Array] = [
	["#join", "enter the race"],
	["#lurk", "watch from the shadows until you #join again"],
	["#bet <fish> <amount>", "bet points, winners share the pool"],
	["#boost / #curse <fish>", "help or hinder"],
	["#points", "your balance"],
	["#stats", "your record"],
	["#top", "leaderboard"],
	["#rival <name>", "beat them for bonus points"],
	["#shop", "fish, colors, hats, trails and dances"],
	["#help", "all commands in chat"],
]

## Rows only shown while their map is loaded, keyed by map id.
const MAP_ROWS: Dictionary[String, Array] = {
	"pinball": [["#left / #right", "fire the flippers"]],
	"pinball2": [["#left / #right", "fire the flippers"]],
	"claw": [["#left / #right / #grab", "work the claw"]],
	"gravity": [["#up / #down / #left / #right", "pick the side that is the floor"]],
	"fault": [["#shake", "spam it to quake the seafloor"]],
	"board": [["#roll", "spam it to roll the dice"]],
	"sushi": [["#chop", "swing the chefs' knives"]],
	"riptide": [["#eddy", "cut from the race? haunt it"]],
}


## The rows shown on every map.
static func general_rows() -> Array[PackedStringArray]:
	return _as_rows(GENERAL)


## Rows for the map [param map_id] only; empty for a map without its own commands.
static func map_rows(map_id: String) -> Array[PackedStringArray]:
	return _as_rows(MAP_ROWS.get(map_id, []))


## The whole cheat sheet for [param map_id] as plain text, one row per line.
static func sheet_text(map_id: String) -> String:
	var lines: PackedStringArray = []
	for row: PackedStringArray in general_rows() + map_rows(map_id):
		lines.append("%s  %s" % [row[0], row[1]])
	return "\n".join(lines)


static func _as_rows(raw: Array) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	for row: Array in raw:
		rows.append(PackedStringArray(row))
	return rows
