class_name ChatBatcher
extends Node
## Collects short confirmations and sends them as one chat line per kind, so a burst of
## joins or bets costs a single Twitch message instead of one each.

## Emitted once per kind with everything queued for it, e.g. "Joined: @a, @b".
signal line_ready(text: String)

## Twitch allows 500 characters; stay well under it.
const MAX_LENGTH: int = 400

## Seconds between the first queued item and the send.
var interval: float = 4.0

var _prefixes: Dictionary[String, String] = {}
var _items: Dictionary[String, PackedStringArray] = {}
var _timer: float = -1.0


func _process(delta: float) -> void:
	if _timer < 0.0:
		return
	_timer -= delta
	if _timer <= 0.0:
		flush()


## Queues one item under a kind. The prefix of the first item of a kind is used.
func add(kind: String, prefix: String, item: String) -> void:
	if not _items.has(kind):
		_items[kind] = PackedStringArray()
		_prefixes[kind] = prefix
	_items[kind].append(item)
	if _timer < 0.0:
		_timer = interval


func is_empty() -> bool:
	return _items.is_empty()


## Drops everything queued without sending it.
func clear() -> void:
	_items.clear()
	_prefixes.clear()
	_timer = -1.0


## Sends every queued kind now, in the order first queued.
func flush() -> void:
	var kinds: Array[String] = _items.keys()
	var lines: Array[String] = []
	for kind: String in kinds:
		lines.append(_line(_prefixes[kind], _items[kind]))
	clear()
	for line: String in lines:
		line_ready.emit(line)


static func _line(prefix: String, items: PackedStringArray) -> String:
	var text: String = prefix
	for i: int in items.size():
		var next: String = text + (", " if i > 0 else " ") + items[i]
		var more: String = ", +%d more" % (items.size() - i)
		# Leave room for the "+N more" tail unless this is the last item and it fits.
		var limit: int = MAX_LENGTH if i == items.size() - 1 else MAX_LENGTH - more.length()
		if next.length() > limit:
			return text + more if i > 0 else text + " +%d more" % items.size()
		text = next
	return text
