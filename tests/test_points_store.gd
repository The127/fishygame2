extends GutTest

const PATH: String = "user://test_points_store.json"


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
	_cleanup_extras()


func test_new_viewer_gets_starting_balance() -> void:
	var store := PointsStore.new("", 250)
	assert_eq(store.get_balance("1"), 250)


func test_add_and_debit() -> void:
	var store := PointsStore.new("", 100)
	assert_eq(store.add("1", 50), 150)
	assert_true(store.try_debit("1", 120))
	assert_eq(store.get_balance("1"), 30)


func test_debit_refused_when_too_poor() -> void:
	var store := PointsStore.new("", 100)
	assert_false(store.try_debit("1", 101))
	assert_eq(store.get_balance("1"), 100)


func test_balance_never_negative() -> void:
	var store := PointsStore.new("", 10)
	assert_eq(store.add("1", -50), 0)


func test_persists_and_reloads() -> void:
	var store := PointsStore.new(PATH, 100)
	store.add("1", 40)
	store.add("2", -30)
	assert_true(store.save_to_disk())
	var reloaded := PointsStore.new(PATH, 100)
	assert_true(reloaded.load_from_disk())
	assert_eq(reloaded.get_balance("1"), 140)
	assert_eq(reloaded.get_balance("2"), 70)
	assert_eq(reloaded.get_balance("unknown"), 100)


func test_missing_file_is_fine() -> void:
	var store := PointsStore.new(PATH, 100)
	assert_true(store.load_from_disk())
	assert_eq(store.get_balance("1"), 100)


func test_corrupt_file_is_ignored() -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("not json {")
	file.close()
	var store := PointsStore.new(PATH, 100)
	assert_false(store.load_from_disk())
	assert_eq(store.get_balance("1"), 100)


func test_no_path_means_no_persistence() -> void:
	var store := PointsStore.new("", 100)
	assert_true(store.save_to_disk())
	assert_true(store.load_from_disk())


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _cleanup_extras() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	for name_text: String in dir.get_files():
		if name_text.begins_with("test_points_store.json"):
			dir.remove(name_text)


func test_save_keeps_previous_as_backup() -> void:
	var store := PointsStore.new(PATH, 100)
	store.add("1", 1)
	store.save_to_disk()
	store.add("1", 1)
	store.save_to_disk()
	assert_true(FileAccess.file_exists(PATH + ".bak"))
	assert_false(FileAccess.file_exists(PATH + ".tmp"))
	var from_backup := PointsStore.new(PATH + ".bak", 100)
	from_backup.load_from_disk()
	assert_eq(from_backup.get_balance("1"), 101)
	_cleanup_extras()


func test_corrupt_main_file_recovers_from_backup() -> void:
	var store := PointsStore.new(PATH, 100)
	store.add("1", 400)
	store.save_to_disk()
	store.add("1", 1)
	store.save_to_disk()
	_write(PATH, "{ truncated")
	var reloaded := PointsStore.new(PATH, 100)
	assert_true(reloaded.load_from_disk())
	assert_eq(reloaded.get_balance("1"), 500)
	_cleanup_extras()


func test_corrupt_main_without_backup_is_kept_aside_and_not_overwritten() -> void:
	_write(PATH, "garbage")
	var store := PointsStore.new(PATH, 100)
	assert_false(store.load_from_disk())
	assert_false(FileAccess.file_exists(PATH))
	var found: bool = false
	for name_text: String in DirAccess.open("user://").get_files():
		if name_text.begins_with("test_points_store.json.corrupt-"):
			found = true
	assert_true(found, "corrupt file should be preserved")
	_cleanup_extras()


func test_both_files_corrupt_does_not_wipe_a_later_good_backup() -> void:
	_write(PATH, "garbage")
	_write(PATH + ".bak", "also garbage")
	var store := PointsStore.new(PATH, 100)
	assert_false(store.load_from_disk())
	store.add("1", 5)
	assert_true(store.save_to_disk())
	var reloaded := PointsStore.new(PATH, 100)
	assert_true(reloaded.load_from_disk())
	assert_eq(reloaded.get_balance("1"), 105)
	_cleanup_extras()


func test_wrong_shape_is_corrupt() -> void:
	_write(PATH, '{"balances": [1, 2]}')
	var store := PointsStore.new(PATH, 100)
	assert_false(store.load_from_disk())
	_cleanup_extras()


func test_balance_is_capped() -> void:
	var store := PointsStore.new("", 100)
	assert_eq(store.add("1", PointsStore.MAX_BALANCE * 5), PointsStore.MAX_BALANCE)
	assert_eq(store.add("1", 9223372036854775807), PointsStore.MAX_BALANCE)
	store.set_balance("2", 9223372036854775807)
	assert_eq(store.get_balance("2"), PointsStore.MAX_BALANCE)
	assert_eq(store.add("1", -9223372036854775807), 0)


func test_load_clamps_huge_and_ignores_non_finite_values() -> void:
	_write(PATH, '{"balances": {"a": 1e30, "b": -5, "c": "x", "d": 42}}')
	var store := PointsStore.new(PATH, 100)
	assert_true(store.load_from_disk())
	assert_eq(store.get_balance("a"), PointsStore.MAX_BALANCE)
	assert_eq(store.get_balance("b"), 0)
	assert_eq(store.get_balance("c"), 100)
	assert_eq(store.get_balance("d"), 42)
	_cleanup_extras()


func test_stakes_persist_and_refund() -> void:
	var store := PointsStore.new(PATH, 100)
	assert_true(store.try_debit("1", 60))
	store.add_stake("1", 60)
	store.save_to_disk()
	var reloaded := PointsStore.new(PATH, 100)
	reloaded.load_from_disk()
	assert_eq(reloaded.get_balance("1"), 40)
	assert_eq(reloaded.stake_of("1"), 60)
	assert_eq(reloaded.refund_stakes(), 1)
	assert_eq(reloaded.get_balance("1"), 100)
	assert_eq(reloaded.stake_of("1"), 0)
	_cleanup_extras()


func test_release_stake_keeps_other_holds() -> void:
	var store := PointsStore.new("", 100)
	store.add_stake("1", 60)
	store.add_stake("1", 30)
	store.release_stake("1", 60)
	assert_eq(store.stake_of("1"), 30)
	store.release_stake("1", 30)
	assert_eq(store.stake_of("1"), 0)


func test_interrupted_save_recovers_from_finished_temp_file() -> void:
	var store := PointsStore.new(PATH, 100)
	store.add("1", 1)
	store.save_to_disk()
	store.add("1", 1)
	store.save_to_disk()
	# Crash between the renames: no main file, complete temp file, older backup.
	DirAccess.rename_absolute(PATH, PATH + ".tmp")
	var reloaded := PointsStore.new(PATH, 100)
	assert_true(reloaded.load_from_disk())
	assert_eq(reloaded.get_balance("1"), 102)


func test_corrupt_main_is_kept_aside_when_backup_is_used() -> void:
	var store := PointsStore.new(PATH, 100)
	store.add("1", 1)
	store.save_to_disk()
	store.save_to_disk()
	_write(PATH, "garbage")
	var reloaded := PointsStore.new(PATH, 100)
	assert_true(reloaded.load_from_disk())
	var found: bool = false
	for name_text: String in DirAccess.open("user://").get_files():
		if name_text.begins_with("test_points_store.json.corrupt-"):
			found = true
	assert_true(found)
	assert_false(FileAccess.file_exists(PATH))


func test_mirror_wins_when_file_is_older() -> void:
	var mirror: Dictionary = {}
	var store := MirroredStore.new(PATH, 100)
	store.mirror = mirror
	store.add("1", 50)
	assert_true(store.save_to_disk())
	# The file is left at this state, as if IndexedDB had not been flushed for the next save.
	var stale: String = FileAccess.get_file_as_string(PATH)
	store.add("1", 400)
	assert_true(store.save_to_disk())
	_write(PATH, stale)
	var reloaded := MirroredStore.new(PATH, 100)
	reloaded.mirror = mirror
	assert_true(reloaded.load_from_disk())
	assert_eq(reloaded.get_balance("1"), 550)
	_cleanup_extras()


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
	_cleanup_extras()


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
	_cleanup_extras()


func test_garbage_mirror_is_ignored() -> void:
	var store := MirroredStore.new(PATH, 100)
	store.mirror = {"text": "{ nope"}
	store.add("1", 5)
	store.mirror = {"text": "{ nope"}
	store.save_to_disk()
	store.mirror = {"text": "{ nope"}
	var reloaded := MirroredStore.new(PATH, 100)
	reloaded.mirror = {"text": "{ nope"}
	assert_true(reloaded.load_from_disk())
	assert_eq(reloaded.get_balance("1"), 105)
	_cleanup_extras()
