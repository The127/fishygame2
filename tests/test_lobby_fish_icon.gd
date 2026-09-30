extends GameTestBase
## The lobby list shows each joined player's fish next to their name.


func _icons() -> Array[Node]:
	return _game.find_children("*", "FishIcon", true, false)


func test_each_joined_player_gets_a_fish_icon_with_their_look() -> void:
	_join(3)
	await wait_frames(2)
	var icons: Array[Node] = _icons()
	assert_eq(icons.size(), 3)
	var contestants: Array[Contestant] = _flow.get_contestants()
	for i: int in 3:
		var fish: FishVisual = (icons[i] as FishIcon).fish()
		assert_eq(fish.color, contestants[i].color)
		assert_eq(fish.species, contestants[i].species)
		assert_true(fish.frozen)
		assert_false(fish.top_level, "the fish stays inside its row")
		assert_true(icons[i].get_global_rect().has_point(fish.global_position))
		assert_false(fish.is_processing(), "icons do no per-frame work")


func test_icons_are_reused_while_nothing_changes() -> void:
	_join(2)
	await wait_frames(2)
	var first: Array[Node] = _icons()
	await wait_frames(3)
	assert_eq(_icons(), first)
