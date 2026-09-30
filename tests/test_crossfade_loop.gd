extends GutTest
## CrossfadeLoop keeps working through repeated crossfades and fade-outs, and a resume
## request never starts a bed that was faded out.


func test_fade_sequence_leaves_no_playing_stream_behind() -> void:
	var loop := CrossfadeLoop.new(AudioSettings.BUS_AMBIENCE)
	add_child_autofree(loop)
	var stream: AudioStreamWAV = Sound.make_loop(load(Sound.AMBIENCE_PATHS["wreck"]))
	loop.fade_to(stream, 0.05)
	loop.fade_to(stream, 0.05)
	loop.fade_out(0.05)
	await wait_seconds(0.2)
	for child: Node in loop.get_children():
		assert_false((child as AudioStreamPlayer).playing)
	loop.resume_if_stopped()
	for child: Node in loop.get_children():
		assert_false((child as AudioStreamPlayer).playing, "faded-out bed must stay off")
