extends GutTest

const PATH: String = "user://test_shop_mirror.json"


## Stands in for localStorage: the copies are shared through a dictionary the test owns.
class MirroredStore:
	extends ShopStore
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
		if name_text.begins_with("test_shop_mirror.json"):
			dir.remove(name_text)


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_mirror_wins_when_file_is_older() -> void:
	var mirror: Dictionary = {}
	var store := MirroredStore.new(PATH)
	store.mirror = mirror
	store.grant("1", ShopStore.KIND_COLOR, "red")
	store.save_to_disk()
	var stale: String = FileAccess.get_file_as_string(PATH)
	await get_tree().create_timer(0.05).timeout
	store.grant("1", ShopStore.KIND_COLOR, "blue")
	store.save_to_disk()
	_write(PATH, stale)
	var reloaded := MirroredStore.new(PATH)
	reloaded.mirror = mirror
	assert_true(reloaded.load_from_disk())
	assert_true(reloaded.owns("1", ShopStore.KIND_COLOR, "blue"))


func test_mirror_restores_purchases_when_the_file_is_corrupt() -> void:
	var mirror: Dictionary = {}
	var store := MirroredStore.new(PATH)
	store.mirror = mirror
	store.grant("1", ShopStore.KIND_SPECIES, "pike")
	store.equip("1", ShopStore.KIND_SPECIES, "pike")
	store.save_to_disk()
	DirAccess.remove_absolute(PATH + ".bak")
	_write(PATH, "not json {")
	var reloaded := MirroredStore.new(PATH)
	reloaded.mirror = mirror
	assert_true(reloaded.load_from_disk())
	assert_eq(reloaded.equipped("1", ShopStore.KIND_SPECIES), "pike")
	assert_false(FileAccess.file_exists(PATH), "the corrupt file was moved aside")


func test_file_wins_when_mirror_is_older() -> void:
	var mirror: Dictionary = {}
	var store := MirroredStore.new(PATH)
	store.mirror = mirror
	store.grant("1", ShopStore.KIND_COLOR, "red")
	store.save_to_disk()
	var old_mirror: String = mirror["text"]
	await get_tree().create_timer(0.05).timeout
	store.grant("1", ShopStore.KIND_COLOR, "blue")
	store.save_to_disk()
	mirror["text"] = old_mirror
	var reloaded := MirroredStore.new(PATH)
	reloaded.mirror = mirror
	assert_true(reloaded.load_from_disk())
	assert_true(reloaded.owns("1", ShopStore.KIND_COLOR, "blue"))


func test_garbage_mirror_is_ignored() -> void:
	var store := MirroredStore.new(PATH)
	store.grant("1", ShopStore.KIND_COLOR, "red")
	store.save_to_disk()
	var reloaded := MirroredStore.new(PATH)
	reloaded.mirror = {"text": "{ nope"}
	assert_true(reloaded.load_from_disk())
	assert_true(reloaded.owns("1", ShopStore.KIND_COLOR, "red"))
