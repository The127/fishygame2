extends GutTest
## The fish restyle is visual only: species vary by marble id and the effect hooks still work.


func test_species_wrap_around_and_all_have_the_same_keys() -> void:
	for sp: Dictionary in FishVisual.SPECIES:
		assert_eq(sp.keys(), FishVisual.SPECIES[0].keys())
	var fish: FishVisual = FishVisual.new()
	add_child_autofree(fish)
	fish.species = FishVisual.SPECIES.size() + 1
	await wait_frames(2)
	assert_true(is_instance_valid(fish))


func test_marbles_pick_species_from_id_and_keep_their_hooks() -> void:
	var scene: PackedScene = load("res://scenes/marble.tscn")
	var marble: Marble = scene.instantiate()
	marble.id = 2
	add_child_autofree(marble)
	var fish: FishVisual = marble.find_children("*", "FishVisual", false, false)[0]
	assert_eq(fish.species, 2)
	marble.curse(Vector2.RIGHT)
	assert_true(marble.is_cursed())
	marble.celebrate()
	assert_true(fish.celebrating)
	await wait_frames(2)
