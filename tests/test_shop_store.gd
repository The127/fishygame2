extends GutTest

const PATH: String = "user://test_shop_store.json"


func before_each() -> void:
	_cleanup()


func after_each() -> void:
	_cleanup()


func test_nothing_owned_by_default() -> void:
	var store := ShopStore.new()
	assert_false(store.owns("1", ShopStore.KIND_COLOR, "red"))
	assert_eq(store.equipped("1", ShopStore.KIND_COLOR), "")


func test_grant_and_equip() -> void:
	var store := ShopStore.new()
	store.grant("1", ShopStore.KIND_COLOR, "red")
	store.grant("1", ShopStore.KIND_COLOR, "red")
	assert_true(store.owns("1", ShopStore.KIND_COLOR, "red"))
	assert_true(store.equip("1", ShopStore.KIND_COLOR, "red"))
	assert_eq(store.equipped("1", ShopStore.KIND_COLOR), "red")
	assert_false(store.owns("2", ShopStore.KIND_COLOR, "red"), "owned per viewer")
	assert_false(store.owns("1", ShopStore.KIND_SPECIES, "red"), "owned per kind")


func test_cannot_equip_what_is_not_owned() -> void:
	var store := ShopStore.new()
	assert_false(store.equip("1", ShopStore.KIND_SPECIES, "pike"))
	assert_eq(store.equipped("1", ShopStore.KIND_SPECIES), "")


func test_unknown_kind_is_ignored() -> void:
	var store := ShopStore.new()
	store.grant("1", "scarf", "top")
	assert_false(store.owns("1", "scarf", "top"))


func test_persists_and_reloads() -> void:
	var store := ShopStore.new(PATH)
	store.grant("1", ShopStore.KIND_COLOR, "red")
	store.grant("1", ShopStore.KIND_COLOR, "blue")
	store.grant("1", ShopStore.KIND_SPECIES, "pike")
	store.equip("1", ShopStore.KIND_COLOR, "blue")
	store.equip("1", ShopStore.KIND_SPECIES, "pike")
	assert_true(store.save_to_disk())
	var reloaded := ShopStore.new(PATH)
	assert_true(reloaded.load_from_disk())
	assert_true(reloaded.owns("1", ShopStore.KIND_COLOR, "red"))
	assert_true(reloaded.owns("1", ShopStore.KIND_COLOR, "blue"))
	assert_eq(reloaded.equipped("1", ShopStore.KIND_COLOR), "blue")
	assert_eq(reloaded.equipped("1", ShopStore.KIND_SPECIES), "pike")
	assert_true(store.save_to_disk(), "saving over an existing file works")


func test_missing_file_is_fine() -> void:
	var store := ShopStore.new(PATH)
	assert_true(store.load_from_disk())


func test_corrupt_file_leaves_store_empty() -> void:
	_write(PATH, "not json {")
	var store := ShopStore.new(PATH)
	assert_false(store.load_from_disk())
	assert_false(store.owns("1", ShopStore.KIND_COLOR, "red"))


func test_corrupt_file_is_moved_aside_not_overwritten() -> void:
	_write(PATH, "not json {")
	var store := ShopStore.new(PATH)
	assert_false(store.load_from_disk())
	assert_false(FileAccess.file_exists(PATH), "the bad file is out of the way")
	assert_eq(_corrupt_files().size(), 1)
	store.grant("1", ShopStore.KIND_COLOR, "red")
	assert_true(store.save_to_disk())
	var kept: String = FileAccess.get_file_as_string("user://" + _corrupt_files()[0])
	assert_eq(kept, "not json {", "the next purchase does not destroy the old data")


func test_corrupt_file_recovers_from_backup() -> void:
	var store := ShopStore.new(PATH)
	store.grant("1", ShopStore.KIND_COLOR, "red")
	store.save_to_disk()
	store.grant("1", ShopStore.KIND_COLOR, "blue")
	store.save_to_disk()
	assert_true(FileAccess.file_exists(PATH + ".bak"), "the previous save is kept")
	_write(PATH, "garbage")
	var reloaded := ShopStore.new(PATH)
	assert_true(reloaded.load_from_disk())
	assert_true(reloaded.owns("1", ShopStore.KIND_COLOR, "red"))
	assert_eq(_corrupt_files().size(), 1)


func test_interrupted_save_uses_the_finished_temp_file() -> void:
	var store := ShopStore.new(PATH)
	store.grant("1", ShopStore.KIND_SPECIES, "pike")
	store.save_to_disk()
	var text: String = FileAccess.get_file_as_string(PATH)
	DirAccess.remove_absolute(PATH)
	_write(PATH + ".tmp", text)
	_write(PATH, "{")
	var reloaded := ShopStore.new(PATH)
	assert_true(reloaded.load_from_disk())
	assert_true(reloaded.owns("1", ShopStore.KIND_SPECIES, "pike"))


func test_wrongly_shaped_entries_are_dropped() -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	(
		file
		. store_string(
			'{"owned": {"1": {"color": ["red", 5, null], "species": "pike"}, "2": 7}, "equipped": {"1": {"color": "red"}}}'
		)
	)
	file.close()
	var store := ShopStore.new(PATH)
	assert_true(store.load_from_disk())
	assert_true(store.owns("1", ShopStore.KIND_COLOR, "red"))
	assert_eq(store.equipped("1", ShopStore.KIND_COLOR), "red")
	assert_false(store.owns("1", ShopStore.KIND_SPECIES, "pike"))
	assert_false(store.owns("2", ShopStore.KIND_COLOR, "red"))


func test_no_path_means_no_persistence() -> void:
	var store := ShopStore.new()
	store.grant("1", ShopStore.KIND_COLOR, "red")
	assert_true(store.save_to_disk())
	assert_true(store.load_from_disk())
	assert_false(store.owns("1", ShopStore.KIND_COLOR, "red"))


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _corrupt_files() -> PackedStringArray:
	var found: PackedStringArray = []
	for name_text: String in DirAccess.open("user://").get_files():
		if name_text.begins_with("test_shop_store.json.corrupt-"):
			found.append(name_text)
	return found


func _cleanup() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	for name_text: String in dir.get_files():
		if name_text.begins_with("test_shop_store.json"):
			dir.remove(name_text)


func test_unequip_keeps_ownership() -> void:
	var store := ShopStore.new()
	store.grant("1", ShopStore.KIND_HAT, "crown")
	store.equip("1", ShopStore.KIND_HAT, "crown")
	store.unequip("1", ShopStore.KIND_HAT)
	assert_eq(store.equipped("1", ShopStore.KIND_HAT), "")
	assert_true(store.owns("1", ShopStore.KIND_HAT, "crown"))


func test_welcomed_viewers_are_saved() -> void:
	var path: String = "user://test_shop_welcomed.json"
	var store := ShopStore.new(path)
	store.mark_welcomed("7")
	assert_true(store.save_to_disk())
	var loaded := ShopStore.new(path)
	assert_true(loaded.load_from_disk())
	assert_true(loaded.was_welcomed("7"))
	assert_false(loaded.was_welcomed("8"))
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
