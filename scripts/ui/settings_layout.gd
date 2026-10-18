class_name SettingsLayout
## What the [SettingsScreen] shows: its pages, the caption and explanation of each row, and
## which settings are toggles, text boxes or named steps.

const PREVIEW_KEY: String = "preview"
## Control key of the button that arms the release surprise again.
const REPLAY_SURPRISE_KEY: String = "replay_surprise"
## Hidden until the fake 3D sequel has played once (see [method ReleaseSurpriseStore.has_played]).
const RTX_KEY: String = "rtx"
## The RTX unlock show, hidden together with [constant RTX_KEY].
const RTX_INTRO_KEY: String = "rtx_intro"
## Page layout: each page has titled sections; each item is a setting key, or
## [constant PREVIEW_KEY] / [constant REPLAY_SURPRISE_KEY]. A section "hint" explains it.
const PAGES: Array[Dictionary] = [
	{
		"title": "Race",
		"sections":
		[
			{
				"title": "Players",
				"items": ["min_players", "max_players", "cardboard_fish", "cardboard_fill"],
			},
			{
				"title": "Timing",
				"items": ["countdown_seconds", "race_time_limit", "finish_replay"],
			},
			{
				"title": "Maps",
				"items":
				[
					"default_map",
					"hazards_enabled",
					"hazard_frequency",
					"treasures_enabled",
					"random_events",
				],
			},
			{"title": "Auto mode", "items": ["auto_mode", "auto_join_seconds"]},
			{
				"title": "Auto-join",
				"hint": "Lurkers (#lurk) never auto-join, and the maximum players still applies.",
				"items": ["auto_join_chatters", "auto_join_recent", "auto_join_ignore"],
			},
		],
	},
	{
		"title": "Points & betting",
		"sections":
		[
			{"title": "New viewers", "items": ["starting_balance"]},
			{"title": "Betting", "items": ["min_bet", "max_bet"]},
			{
				"title": "Prizes",
				"hint": "Points paid to the owners of the fastest fish.",
				"items": ["win_reward", "second_reward", "third_reward", "rival_reward"],
			},
		],
	},
	{
		"title": "Chaos & powers",
		"sections":
		[
			{
				"title": "Boost and curse",
				"items": ["boost_cost", "curse_cost", "viewer_cooldown", "fish_lockout"],
			},
			{
				"title": "Cheering",
				"hint": "A chat message that names a fish and has emotes nudges it forward.",
				"items":
				[
					"cheer_strength",
					"cheer_viewer_cooldown",
					"cheer_fish_cooldown",
					"cheer_max_emotes",
				],
			},
			{
				"title": "Streamer powers",
				"items": ["powers_enabled", "power_cooldown", "powers_per_race"],
			},
			{"title": "Sushi chef", "items": ["chop_limit"]},
		],
	},
	{
		"title": "Shop",
		"sections":
		[
			{
				"title": "Prices",
				"items":
				[
					"species_price",
					"color_price",
					"premium_color_price",
					"hat_price",
					"trail_price",
					"dance_price",
				],
			},
			{"title": "Gifts", "items": ["welcome_hat"]},
		],
	},
	{
		"title": "Chat",
		"sections":
		[
			{"title": "Replies", "items": ["chat_replies"]},
			{
				"title": "Confirmations",
				"hint": "What the game posts in chat. The overlay shows everything either way.",
				"items":
				[
					"reply_joins",
					"reply_bets",
					"reply_chaos",
					"reply_shop",
					"reply_rivals",
					"reply_catalog",
					"reply_results",
					"reply_powers",
				],
			},
		],
	},
	{
		"title": "Display",
		"sections":
		[
			{
				"title": "Blocked edges",
				"hint": "Keeps screen edges free for your own overlays (webcam, alerts).",
				"items": ["pad_left", "pad_right", "pad_top", "pad_bottom", PREVIEW_KEY],
			},
			{"title": "Accessibility", "items": ["colorblind"]},
			{"title": "Graphics", "items": ["rtx", RTX_INTRO_KEY]},
		],
	},
	SoundSettingsControls.PAGE,
	{
		"title": "Extras",
		"sections":
		[
			{"title": "Release surprise", "items": ["release_surprise", REPLAY_SURPRISE_KEY]},
			{
				"title": "Impostor duck",
				"hint": "It earns no points and counts for no bets, rivals or tournaments.",
				"items": ["impostor_duck", "impostor_chance"],
			},
		],
	},
]

## Caption, explanation and unit of each row. A setting missing here falls back to its
## [constant GameSettings.FIELDS] or [constant GameSettings.CHAT_TOGGLES] label.
const ROWS: Dictionary[String, Dictionary] = {
	"min_players": {"label": "Minimum players", "hint": "Fish needed before a race can start."},
	"max_players": {"label": "Maximum players", "hint": "The lobby is full at this many fish."},
	"cardboard_fish":
	{
		"label": "Cardboard fish",
		"hint": "Under 3 viewers, cutouts fill the empty slots. They win no points."
	},
	"cardboard_fill": {"label": "Fill up to", "hint": "Fish on the track with the cutouts."},
	"countdown_seconds": {"label": "Countdown", "hint": "Before the start.", "unit": "s"},
	"race_time_limit":
	{"label": "Time limit", "hint": "Fish still racing then are DNF. 0 means none.", "unit": "s"},
	"finish_replay": {"label": "Finish replay", "hint": "Replays the finish before the podium."},
	"default_map": {"label": "Map", "hint": "The map every race uses, or a random one."},
	"hazards_enabled": {"label": "Map hazards", "hint": "Currents, eels and collapsing planks."},
	"hazard_frequency": {"label": "Hazard frequency", "hint": "How often hazards strike."},
	"treasures_enabled": {"label": "Treasures", "hint": "Fish pick them up for points."},
	"random_events":
	{"label": "Random events", "hint": "A wheel before each race, now and then a twist."},
	"auto_mode": {"label": "Auto mode", "hint": "Lobby, race and podium cycle on their own."},
	"auto_join_seconds":
	{"label": "Join window", "hint": "How long the lobby stays open.", "unit": "s"},
	"auto_join_chatters":
	{"label": "Auto-join chatters", "hint": "Anyone who chats joins the lobby, no #join needed."},
	"auto_join_recent":
	{
		"label": "Recent chatters",
		"hint": "Who chatted this long before a lobby opens joins it. 0 means none.",
		"unit": "s"
	},
	"auto_join_ignore": {"label": "Never auto-join", "hint": "Bot accounts, separated by commas."},
	"starting_balance":
	{"label": "Starting points", "hint": "What a viewer has on their first visit.", "unit": "pts"},
	"min_bet": {"label": "Minimum bet", "unit": "pts"},
	"max_bet": {"label": "Maximum bet", "hint": "0 means no limit.", "unit": "pts"},
	"win_reward": {"label": "1st place", "unit": "pts"},
	"second_reward": {"label": "2nd place", "unit": "pts"},
	"third_reward": {"label": "3rd place", "unit": "pts"},
	"rival_reward":
	{
		"label": "Beating your rival",
		"hint": "Bonus for finishing ahead of a #rival.",
		"unit": "pts"
	},
	"boost_cost": {"label": "Boost cost", "hint": "#boost kicks a fish forward.", "unit": "pts"},
	"curse_cost": {"label": "Curse cost", "hint": "#curse knocks a fish back.", "unit": "pts"},
	"viewer_cooldown":
	{"label": "Viewer cooldown", "hint": "Wait between one viewer's effects.", "unit": "s"},
	"fish_lockout":
	{"label": "Fish lockout", "hint": "Wait before a fish can be hit again.", "unit": "s"},
	"cheer_strength": {"label": "Cheer strength", "hint": "0 turns cheering off.", "unit": "%"},
	"cheer_viewer_cooldown":
	{"label": "Viewer cooldown", "hint": "Wait between one viewer's cheers.", "unit": "s"},
	"cheer_fish_cooldown":
	{"label": "Fish cooldown", "hint": "Wait before a fish can be cheered again.", "unit": "s"},
	"cheer_max_emotes":
	{"label": "Emotes counted", "hint": "More emotes in one message add nothing."},
	"powers_enabled":
	{"label": "Streamer powers", "hint": "Your rod, net and bubble blast during a race."},
	"power_cooldown": {"label": "Cooldown", "hint": "Wait between two powers.", "unit": "s"},
	"powers_per_race": {"label": "Uses per race"},
	"chop_limit":
	{"label": "Chop limit", "hint": "Fish #chop may take per race on Sushi Bar. Never the last."},
	"species_price": {"label": "Fish species", "unit": "pts"},
	"color_price": {"label": "Fish color", "unit": "pts"},
	"premium_color_price": {"label": "Premium color", "unit": "pts"},
	"hat_price": {"label": "Accessory", "hint": "Hats and other accessories.", "unit": "pts"},
	"trail_price": {"label": "Trail", "unit": "pts"},
	"dance_price":
	{"label": "Victory dance", "hint": "Done on the podium after a win.", "unit": "pts"},
	"welcome_hat": {"label": "Welcome hat", "hint": "A free random hat for a first race."},
	"chat_replies":
	{"label": "Reply in chat", "hint": "Off silences everything: errors, #help, #top and below."},
	"pad_left": {"label": "Left", "unit": "%"},
	"pad_right": {"label": "Right", "unit": "%"},
	"pad_top": {"label": "Top", "unit": "%"},
	"pad_bottom": {"label": "Bottom", "unit": "%"},
	PREVIEW_KEY: {"label": "Preview", "hint": "Black is blocked, the outline is the game."},
	"colorblind":
	{"label": "Colorblind mode", "hint": "Alternate fish colors and a marking on each fish."},
	"rtx": {"label": "RTX", "hint": "Ray tracing, allegedly. Bloom, lens flares, light shafts."},
	RTX_INTRO_KEY:
	{
		"label": "RTX unlock show",
		"hint": "Plays once after the fake sequel. REPLAY RTX plays it again."
	},
	"release_surprise":
	{"label": "Release surprise", "hint": "A fake sequel announcement, once, on Open Lobby."},
	REPLAY_SURPRISE_KEY: {"label": "Play it again", "hint": "On the next Open Lobby press."},
	"impostor_duck":
	{"label": "Impostor duck", "hint": "Now and then a rubber duck races. It is a fish."},
	"impostor_chance": {"label": "Chance", "hint": "Share of races it lines up in.", "unit": "%"},
}

## Yes/no settings outside [constant GameSettings.CHAT_TOGGLES]. A new boolean setting needs a
## key here and a place in [constant PAGES].
const TOGGLES: Array[String] = [
	"hazards_enabled",
	"powers_enabled",
	"treasures_enabled",
	"random_events",
	"auto_mode",
	"auto_join_chatters",
	"chat_replies",
	"colorblind",
	"welcome_hat",
	"release_surprise",
	"rtx",
	"rtx_intro",
	"impostor_duck",
	"cardboard_fish",
]

## Free text settings, typed into a text box.
const TEXTS: Array[String] = ["auto_join_ignore"]

## Number settings picked from named steps instead of typed: the names, from the field's min.
const CHOICES: Dictionary[String, Array] = {
	"finish_replay": ["Off", "Close finishes", "Every race"],
	"cardboard_fill": ["5 fish", "10 fish"],
	"hazard_frequency": ["Rare", "Occasional", "Normal", "Frequent", "Constant"],
	"chop_limit":
	[
		"30% of the field",
		"1 fish",
		"2 fish",
		"3 fish",
		"4 fish",
		"5 fish",
		"6 fish",
		"7 fish",
		"8 fish",
		"9 fish",
		"10 fish",
		"11 fish",
		"12 fish",
		"13 fish",
		"14 fish",
		"15 fish",
		"16 fish",
		"17 fish",
		"18 fish",
		"19 fish",
		"Unlimited",
	],
}

## Rows that are greyed out while the yes/no setting they depend on is off. The chat
## confirmations are added in [method _ready].
const DEPENDENTS: Dictionary[String, Array] = {
	"hazards_enabled": ["hazard_frequency"],
	"powers_enabled": ["power_cooldown", "powers_per_race"],
	"auto_mode": ["auto_join_seconds"],
	"auto_join_chatters": ["auto_join_recent", "auto_join_ignore"],
	"cardboard_fish": ["cardboard_fill"],
	"release_surprise": [REPLAY_SURPRISE_KEY],
	"impostor_duck": ["impostor_chance"],
}
