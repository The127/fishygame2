extends GutTest
## The fish restyle is visual only: species vary by marble id and the effect hooks still work.


func _make_marble() -> Marble:
	return (load("res://scenes/marble.tscn") as PackedScene).instantiate() as Marble


func test_species_wrap_around_and_all_have_the_same_keys() -> void:
	for sp: Dictionary in FishVisual.SPECIES:
		assert_eq(sp.keys(), FishVisual.SPECIES[0].keys())
	var fish: FishVisual = FishVisual.new()
	add_child_autofree(fish)
	fish.species = FishVisual.SPECIES.size() + 1
	await wait_frames(2)
	assert_true(is_instance_valid(fish))


func test_marbles_pick_species_from_id_and_keep_their_hooks() -> void:
	var marble: Marble = _make_marble()
	marble.id = 2
	add_child_autofree(marble)
	var fish: FishVisual = marble.find_children("*", "FishVisual", false, false)[0]
	assert_eq(fish.species, 2)
	marble.curse(Vector2.RIGHT)
	assert_true(marble.is_cursed())
	marble.celebrate()
	assert_true(fish.celebrating)
	await wait_frames(2)


func test_every_pattern_draws_and_wraps() -> void:
	var fish: FishVisual = FishVisual.new()
	add_child_autofree(fish)
	for pattern: int in FishVisual.Pattern.size() + 2:
		fish.pattern = pattern
		fish.species = pattern
		await wait_frames(1)
	assert_true(is_instance_valid(fish))


func test_marbles_pass_the_pattern_to_their_fish() -> void:
	var marble: Marble = _make_marble()
	marble.pattern = FishVisual.Pattern.SPOTS
	add_child_autofree(marble)
	var fish: FishVisual = marble.find_children("*", "FishVisual", false, false)[0]
	assert_eq(fish.pattern, FishVisual.Pattern.SPOTS)
	marble.pattern = FishVisual.Pattern.LINES
	assert_eq(fish.pattern, FishVisual.Pattern.LINES)


func test_every_accessory_draws_at_every_species() -> void:
	var fish: FishVisual = FishVisual.new()
	add_child_autofree(fish)
	for species: int in FishVisual.SPECIES.size():
		fish.species = species
		for kind: int in FishAccessory.Kind.size():
			fish.accessory = kind
			await wait_frames(1)
	assert_true(is_instance_valid(fish))
