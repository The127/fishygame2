extends GutTest
## ChatBatcher: one chat line per kind, short enough for Twitch.

var _batcher: ChatBatcher
var _lines: Array[String] = []


func before_each() -> void:
	_lines = []
	_batcher = ChatBatcher.new()
	add_child_autofree(_batcher)
	_batcher.line_ready.connect(func(text: String) -> void: _lines.append(text))


func test_items_of_one_kind_become_one_line() -> void:
	_batcher.add("joins", "Joined:", "@a")
	_batcher.add("joins", "Joined:", "@b")
	_batcher.add("joins", "Joined:", "@c")
	_batcher.flush()
	assert_eq(_lines, ["Joined: @a, @b, @c"] as Array[String])


func test_each_kind_gets_its_own_line_in_first_seen_order() -> void:
	_batcher.add("bets", "Bets:", "@a 10 on X")
	_batcher.add("joins", "Joined:", "@b")
	_batcher.add("bets", "Bets:", "@c 20 on Y")
	_batcher.flush()
	assert_eq(_lines, ["Bets: @a 10 on X, @c 20 on Y", "Joined: @b"] as Array[String])


func test_nothing_is_sent_before_the_interval() -> void:
	_batcher.interval = 2.0
	_batcher.add("joins", "Joined:", "@a")
	_batcher._process(1.9)
	assert_eq(_lines.size(), 0)
	_batcher._process(0.2)
	assert_eq(_lines.size(), 1)


func test_flush_empties_the_queue_and_stops_the_timer() -> void:
	_batcher.add("joins", "Joined:", "@a")
	_batcher.flush()
	assert_true(_batcher.is_empty())
	_batcher._process(100.0)
	assert_eq(_lines.size(), 1)


func test_flush_with_nothing_queued_sends_nothing() -> void:
	_batcher.flush()
	assert_eq(_lines.size(), 0)


func test_a_new_batch_starts_after_a_flush() -> void:
	_batcher.add("joins", "Joined:", "@a")
	_batcher.flush()
	_batcher.add("joins", "Joined:", "@b")
	_batcher.flush()
	assert_eq(_lines, ["Joined: @a", "Joined: @b"] as Array[String])


func test_clear_drops_the_queue() -> void:
	_batcher.add("joins", "Joined:", "@a")
	_batcher.clear()
	_batcher.flush()
	assert_eq(_lines.size(), 0)


func test_long_batches_are_capped_with_a_count() -> void:
	for i: int in 200:
		_batcher.add("joins", "Joined:", "@viewer%d" % i)
	_batcher.flush()
	assert_eq(_lines.size(), 1)
	assert_lte(_lines[0].length(), ChatBatcher.MAX_LENGTH)
	assert_true(_lines[0].begins_with("Joined: @viewer0, @viewer1"))
	assert_true(_lines[0].ends_with(" more"))
