extends GutTest
## Moving a volume slider reaches the matching audio bus.

var _panel: ControlPanel


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/ui/control_panel.tscn")
	_panel = scene.instantiate()
	add_child_autofree(_panel)
	_panel.volume_changed.connect(Sound.set_volume)


func after_each() -> void:
	Sound.settings = AudioSettings.new()
	for bus: String in AudioSettings.BUSES:
		Sound.set_volume(bus, AudioSettings.DEFAULT_VOLUMES[bus])
	Sound.settings.save_path = ""


func _slider(row: String) -> HSlider:
	return _panel.get_node("Panel/Box/%s/Slider" % row) as HSlider


func test_each_slider_emits_its_bus_then_the_value() -> void:
	var rows: Dictionary = {
		"MasterRow": AudioSettings.BUS_MASTER,
		"MusicRow": AudioSettings.BUS_MUSIC,
		"AmbienceRow": AudioSettings.BUS_AMBIENCE,
		"SfxRow": AudioSettings.BUS_SFX,
	}
	for row: String in rows:
		watch_signals(_panel)
		_slider(row).value = 0.25
		assert_signal_emitted_with_parameters(_panel, "volume_changed", [rows[row], 0.25])


func test_each_slider_changes_its_bus_volume() -> void:
	var rows: Dictionary = {
		"MasterRow": AudioSettings.BUS_MASTER,
		"MusicRow": AudioSettings.BUS_MUSIC,
		"AmbienceRow": AudioSettings.BUS_AMBIENCE,
		"SfxRow": AudioSettings.BUS_SFX,
	}
	for row: String in rows:
		var bus: String = rows[row]
		_slider(row).value = 0.25
		var index: int = AudioServer.get_bus_index(bus)
		assert_almost_eq(AudioServer.get_bus_volume_db(index), linear_to_db(0.25), 0.01, bus)
		assert_almost_eq(Sound.settings.get_volume(bus), 0.25, 0.001, bus)
		_slider(row).value = 0.0
		assert_eq(AudioServer.get_bus_volume_db(index), Sound.SILENT_DB, bus)
