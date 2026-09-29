class_name HelpText
extends RefCounted
## What viewers are told about the chat commands: one chat line and the lobby cheat sheet.

## Chat reply to "#help". Kept well under Twitch's 500 character limit.
const CHAT_REPLY: String = (
	"Commands: #join | #bet <fish> <amount> | #boost <fish> | #curse <fish> | "
	+ "#points | #top | #shop | #fish <species> | #color <name>"
)

const TITLE: String = "CHAT COMMANDS"

## One line per command on the lobby cheat sheet.
const LINES: PackedStringArray = [
	"#join  enter the race",
	"#bet <fish> <amount>  bet points",
	"#boost / #curse <fish>  help or hinder",
	"#points  your balance",
	"#top  leaderboard",
	"#shop  fish and colors",
	"#help  this list",
]
