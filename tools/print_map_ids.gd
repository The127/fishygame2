extends SceneTree
## Prints the ids of every map in TrackCatalog: space separated by default, or a JSON array
## with "--json". Used by tests/run_race_seeds.sh and the CI race-seeds matrix.
## Usage: godot --headless -s tools/print_map_ids.gd [-- --json]


func _init() -> void:
	var ids: PackedStringArray = TrackCatalog.ids()
	if OS.get_cmdline_user_args().has("--json"):
		print(JSON.stringify(Array(ids)))
	else:
		print(" ".join(ids))
	quit()
