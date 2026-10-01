class_name ChatReplies
extends Node
## Words the chat confirmations, rejection replies and overlay notices for Game, and holds the
## reply settings checks and the per-viewer rejection cooldown. Game feeds it the round
## signals; it answers with [signal chat_line] and [signal notice].

## A line to say in chat. Only emitted when the chat replies setting is on.
signal chat_line(text: String)
## A short message for the overlay.
signal notice(text: String)

## Milliseconds before the same viewer gets another rejection reply.
const REPLY_COOLDOWN_MSEC: int = 15000

const BET_REJECTIONS: Dictionary = {
	"closed": "betting is closed",
	"usage": "use #bet <name> <amount>",
	"already_bet": "you already bet this round",
	"unknown_fish": "no such racer",
	"invalid_amount": "invalid amount",
	"below_min": "bet is below the minimum",
	"above_max": "bet is above the maximum",
	"insufficient": "not enough points",
}

const SHOP_REJECTIONS: Dictionary = {
	"usage": "use #fish <species>, #color <name>, #hat <name> or #trail <name>, see #shop",
	"unknown_species": "no such species, see #shop",
	"unknown_color": "no such color, see #shop",
	"unknown_hat": "no such accessory, see #shop",
	"unknown_trail": "no such trail, see #shop",
	"insufficient": "not enough points",
}

const CHAOS_REJECTIONS: Dictionary = {
	"closed": "chaos only works during a race",
	"usage": "use #boost <name> or #curse <name>",
	"unknown_fish": "no such racer",
	"finished": "that fish already finished",
	"self_boost": "you can't boost your own fish",
	"self_curse": "you can't curse your own fish",
	"cooldown": "you have to wait before another one",
	"fish_busy": "that fish was just hit, try again shortly",
	"insufficient": "not enough points",
}

## Names listed in the line about a cut, before "and N more".
const CUT_NAMES_SHOWN: int = 6

const HAUNT_REJECTIONS: Dictionary = {
	"closed": "eddies only work during a race",
	"no_fish": "you have no fish in this race",
	"no_rounds": "this map does not flush anyone out",
	"swimming": "your fish is still in the race",
	"no_ghost": "only a flushed-out fish can send an eddy",
	"busy": "your ghost is already out there",
	"full": "enough eddies are spinning already",
	"cooldown": "your ghost needs a moment",
}

const POWER_REJECTIONS: Dictionary = {
	"off": "streamer powers are off in the settings",
	"closed": "powers only work during a race",
	"cooldown": "power is recharging",
	"cap": "no powers left this race",
}

var settings: GameSettings = null
var batcher: ChatBatcher = ChatBatcher.new()

var _last_reply_msec: Dictionary[String, int] = {}


func _ready() -> void:
	add_child(batcher)
	batcher.line_ready.connect(_on_batched_line)


## The name to show for a viewer: the display name, or the login when there is none.
static func viewer_name(msg: ChatMessage) -> String:
	return msg.display_name if msg.display_name != "" else msg.login


static func power_rejection(reason: String) -> String:
	return POWER_REJECTIONS.get(reason, "power not available")


## Queues a chat confirmation when replies and the kind's own toggle are on.
func confirm(toggle: String, kind: String, prefix: String, item: String) -> void:
	if settings.replies_enabled(toggle):
		batcher.add(kind, prefix, item)


## Says a line in chat right away when replies are on.
func say(text: String) -> void:
	if settings.chat_replies:
		chat_line.emit(text)


func player_joined(contestant: Contestant) -> void:
	confirm("reply_joins", "joins", "Joined:", "@" + contestant.display_name)


## Replies to a rejected join, at most once per viewer per cooldown, and only when the
## rejection has a reply text.
func join_rejected(msg: ChatMessage, reason: String) -> void:
	var text: String = GameFlow.rejection_text(reason, msg)
	if text == "" or not settings.chat_replies:
		return
	var now: int = Time.get_ticks_msec()
	if (
		_last_reply_msec.has(msg.user_id)
		and now - _last_reply_msec[msg.user_id] < REPLY_COOLDOWN_MSEC
	):
		return
	_last_reply_msec[msg.user_id] = now
	chat_line.emit(text)


func bet_placed(msg: ChatMessage, target: Contestant, amount: int) -> void:
	var who: String = viewer_name(msg)
	confirm("reply_bets", "bets", "Bets:", "@%s %d on %s" % [who, amount, target.display_name])
	notice.emit("%s bet %d on %s" % [who, amount, target.display_name])


func bet_rejected(msg: ChatMessage, reason: String) -> void:
	var text: String = BET_REJECTIONS.get(reason, "bet not accepted")
	notice.emit("%s: %s" % [viewer_name(msg), text])


func effect_applied(msg: ChatMessage, target: Contestant, kind: Chaos.Kind) -> void:
	var boost: bool = kind == Chaos.Kind.BOOST
	var who: String = viewer_name(msg)
	confirm(
		"reply_chaos",
		"boost" if boost else "curse",
		"Boosted:" if boost else "Cursed:",
		"@%s on %s" % [who, target.display_name]
	)
	notice.emit("%s %s %s!" % [who, "boosted" if boost else "cursed", target.display_name])


func effect_rejected(msg: ChatMessage, reason: String) -> void:
	var text: String = CHAOS_REJECTIONS.get(reason, "not accepted")
	notice.emit("%s: %s" % [viewer_name(msg), text])


func eddy_sent(msg: ChatMessage, target: Contestant) -> void:
	var who: String = viewer_name(msg)
	confirm("reply_chaos", "eddy", "Eddy:", "@%s" % who)
	notice.emit("%s's ghost spun up an eddy!" % target.display_name)


func eddy_rejected(msg: ChatMessage, reason: String) -> void:
	var text: String = HAUNT_REJECTIONS.get(reason, "not accepted")
	notice.emit("%s: %s" % [viewer_name(msg), text])


## Says who a round race just cut, in chat and on the overlay. `names` are display names.
func round_cut(round_number: int, names: PackedStringArray) -> void:
	var shown: PackedStringArray = names.slice(0, CUT_NAMES_SHOWN)
	var list: String = ", ".join(shown)
	if names.size() > CUT_NAMES_SHOWN:
		list += " and %d more" % (names.size() - CUT_NAMES_SHOWN)
	notice.emit("Flushed out: %s" % list)
	say(
		(
			"Flushed out after lap %d: %s. Flushed-out fish can send eddies with #eddy"
			% [round_number, list]
		)
	)


func shop_equipped(msg: ChatMessage, kind: String, item: String, price: int) -> void:
	var who: String = viewer_name(msg)
	confirm("reply_shop", "shop", "Shop:", "@%s %s %s" % [who, kind, item])
	if price > 0:
		notice.emit("%s bought %s for %d" % [who, item, price])
	else:
		notice.emit("%s switched to %s" % [who, item])


func shop_rejected(msg: ChatMessage, reason: String) -> void:
	var text: String = SHOP_REJECTIONS.get(reason, "not accepted")
	notice.emit("%s: %s" % [viewer_name(msg), text])


func balance_reported(msg: ChatMessage, balance: int) -> void:
	notice.emit("%s has %d points" % [viewer_name(msg), balance])


func welcome(racer_name: String, hat: String) -> void:
	confirm("reply_shop", "welcome", "Welcome!", "@%s (free %s)" % [racer_name, hat])
	notice.emit("Welcome %s! Here's a free %s" % [racer_name, hat])


func _on_batched_line(text: String) -> void:
	say(text)
