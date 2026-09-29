extends GutTest

const PATH: String = "user://test_points_store.json"


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


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
