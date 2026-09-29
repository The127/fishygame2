class_name Contestant
extends RefCounted
## A viewer who joined the lobby. Keyed by the stable Twitch user id.

var user_id: String = ""
var display_name: String = ""
var color: Color = Color.WHITE


static func create(p_user_id: String, p_display_name: String) -> Contestant:
	var contestant := Contestant.new()
	contestant.user_id = p_user_id
	contestant.display_name = p_display_name
	contestant.color = color_for(p_user_id)
	return contestant


## Stable color for a user id: same id, same color, on every run.
static func color_for(user_id: String) -> Color:
	var hue: float = float(posmod(user_id.hash(), 360)) / 360.0
	return Color.from_hsv(hue, 0.7, 0.95)
