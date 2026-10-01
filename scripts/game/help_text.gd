class_name HelpText
extends RefCounted
## What viewers are told about the chat commands: one chat line and the lobby cheat sheet.

## Chat reply to "#help". Kept well under Twitch's 500 character limit.
const CHAT_REPLY: String = (
	"Commands: #join | #bet <fish> <amount> | #boost <fish> | #curse <fish> | "
	+ "#points | #stats | #top | #shop | #fish <species> | #color <name> | #hat <name> | #trail <name> | "
	+ "#left / #right (Pinball Reef flippers) | #shake (Earthquake Fault) | "
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
	"#shop  fish, colors, hats and trails",
	"#left / #right  fire the flippers (Pinball Reef)",
	"#shake  spam it to quake the seafloor (Earthquake Fault)",
	"#help  this list",
]
