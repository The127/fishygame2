extends GutTest

const PATH: String = "user://test_points_mirror.json"


## Stands in for localStorage: the copies are shared through a dictionary the test owns.
class MirroredStore:
	extends PointsStore
	var mirror: Dictionary

	func _mirror_enabled() -> bool:
		return true

	func _mirror_write(text: String) -> void:
		mirror["text"] = text

	func _mirror_read() -> String:
		return mirror.get("text", "")


func after_each() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	for name_text: String in dir.get_files():
		if name_text.begins_with("test_points_mirror.json"):
			dir.remove(name_text)


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_mirror_wins_when_file_is_older() -> void:
	var mirror: Dictionary = {}
	var store := MirroredStore.new(PATH, 100)
	store.mirror = mirror
	store.add("1", 50)
	assert_true(store.save_to_disk())
	# The file is left at this state, as if IndexedDB had not been flushed for the next save.
	var stale: String = FileAccess.get_file_as_string(PATH)
	await get_tree().create_timer(0.05).timeout
	store.add("1", 400)
	assert_true(store.save_to_disk())
	_write(PATH, stale)
	var reloaded := MirroredStore.new(PATH, 100)
	reloaded.mirror = mirror
	assert_true(reloaded.load_from_disk())
	assert_eq(reloaded.get_balance("1"), 550)


func test_mirror_holds_the_save_when_the_file_is_missing() -> void:
	var mirror: Dictionary = {}
	var store := MirroredStore.new(PATH, 100)
	store.mirror = mirror
	store.add("1", 25)
	store.add_stake("1", 10)
	store.save_to_disk()
	DirAccess.remove_absolute(PATH)
	DirAccess.remove_absolute(PATH + ".bak")
	var reloaded := MirroredStore.new(PATH, 100)
	reloaded.mirror = mirror
	assert_true(reloaded.load_from_disk())
	assert_eq(reloaded.get_balance("1"), 125)
	assert_eq(reloaded.stake_of("1"), 10)


func test_file_wins_when_mirror_is_older() -> void:
	var mirror: Dictionary = {}
	var store := MirroredStore.new(PATH, 100)
	store.mirror = mirror
	store.add("1", 5)
	store.save_to_disk()
	var old_mirror: String = mirror["text"]
	await get_tree().create_timer(0.05).timeout
	store.add("1", 70)
	store.save_to_disk()
	mirror["text"] = old_mirror
	var reloaded := MirroredStore.new(PATH, 100)
	reloaded.mirror = mirror
	assert_true(reloaded.load_from_disk())
	assert_eq(reloaded.get_balance("1"), 175)


func test_garbage_mirror_is_ignored() -> void:
	var store := MirroredStore.new(PATH, 100)
	store.add("1", 5)
	store.save_to_disk()
	store.mirror = {"text": "{ nope"}
	var reloaded := MirroredStore.new(PATH, 100)
	reloaded.mirror = {"text": "{ nope"}
	assert_true(reloaded.load_from_disk())
	assert_eq(reloaded.get_balance("1"), 105)


func test_non_numeric_saved_at_is_treated_as_missing() -> void:
	_write(PATH, '{"version": 1, "saved_at": null, "balances": {"1": 40}, "stakes": {}}')
	var store := MirroredStore.new(PATH, 100)
	store.mirror = {"text": '{"version": 1, "saved_at": {}, "balances": {"1": 90}, "stakes": {}}'}
	assert_true(store.load_from_disk())
	assert_eq(store.get_balance("1"), 40)
