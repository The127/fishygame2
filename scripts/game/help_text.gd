class_name HelpText
extends RefCounted
## What viewers are told about the chat commands: one chat line and the lobby cheat sheet.

## Chat reply to "#help". Kept well under Twitch's 500 character limit.
const CHAT_REPLY: String = (
	"Commands: #join | #bet <fish> <amount> | #boost <fish> | #curse <fish> | "
	+ "#points | #stats | #top | #rival <name> | #shop | #fish <species> | #color <name> | #hat <name> | #trail <name> | #dance <name> | "
	+ "#left / #right (Pinball Reef 1 and 2 flippers, Claw Machine, Gravity Flip) | "
	+ "#grab (Claw Machine) | #up / #down (Gravity Flip) | "
	+ "#shake (Earthquake Fault) | #roll (Board Game) | "
	+ "#chop (Sushi Bar) | "
	+ "#eddy (flushed-out fish)"
)

const TITLE: String = "CHAT COMMANDS"

## One line per command on the lobby cheat sheet.
const LINES: PackedStringArray = [
	"#join  enter the race",
	"#bet <fish> <amount>  bet points, winners share the pool",
	"#boost / #curse <fish>  help or hinder",
	"#eddy  flushed out of Riptide Rounds? haunt the race",
	"#points  your balance",
	"#stats  your record",
	"#top  leaderboard",
	"#rival <name>  beat them for bonus points",
	"#shop  fish, colors, hats, trails and dances",
	"#left / #right  fire the flippers (both Pinball Reefs)",
	"#left / #right / #grab  work the claw (Claw Machine)",
	"#up / #down / #left / #right  steer gravity (Gravity Flip)",
	"#shake  spam it to quake the seafloor (Earthquake Fault)",
	"#roll  spam it to roll the dice (Board Game)",
	"#chop  swing the chefs' knives (Sushi Bar)",
	"#help  this list",
]
