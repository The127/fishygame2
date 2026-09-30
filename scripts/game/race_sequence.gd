class_name RaceSequence
extends Node
## What happens between the finish and the podium: the photo finish slow-mo, and when the
## settings ask for one the replay intro, the finish replay and the fade around it.
##
## It holds the results back while the replay plays and hands them on through
## [signal results_ready] or [signal replay_ended]. It never touches the overlay, panel or
## camera: the game reacts to its signals and supplies [member fade_out].

## Asks the game to bring the picture back from dark over [param seconds].
signal fade_in_requested(seconds: float)
## The race ended with no replay to show (or it could not start): report these results.
signal results_ready(results: Array[Dictionary])
## The replay cut in: show the badge and the skip button.
signal replay_started
## The replay is over. [param results] are the ones held back, empty when the round was left.
signal replay_ended(results: Array[Dictionary])
## The photo finish moment is over.
signal photo_ended

## Seconds the finish plays on live before the replay cuts in.
const REPLAY_BEAT: float = 0.8
## Seconds of each fade to dark around the replay.
const REPLAY_FADE: float = 0.25

## The streamer's rules. Set by the owner.
var settings: GameSettings = null
## Dips the picture to dark over the given seconds and returns the Tween to await. Set by the
## owner. The intro awaits its [signal Tween.finished], which never comes when the round is
## left and the fade is killed, so a stopped round gets no stale fade back in.
var fade_out: Callable = Callable()

var _photo: PhotoFinish = PhotoFinish.new()
var _replay: FinishReplay = FinishReplay.new()
## Bumped whenever a pending replay intro must stop (round left, new race).
var _intro_id: int = 0
## Results held back while the finish replay plays; empty when none is waiting.
var _pending_results: Array[Dictionary] = []
var _recorder: ReplayRecorder = null
var _marbles: Array[Marble] = []


func _ready() -> void:
	add_child(_photo)
	add_child(_replay)
	_replay.ended.connect(_on_replay_ended)
	_replay.ending.connect(_on_replay_ending)
	_photo.ended.connect(photo_ended.emit)


## True while the finish replay plays.
func is_replaying() -> bool:
	return _replay.active


## Where the winner is in the replay.
func winner_position() -> Vector2:
	return _replay.winner_position()


## Stops the replay (reporting the held results) when one plays. Nothing otherwise.
func skip_replay() -> void:
	_replay.stop()


func start_photo_finish() -> void:
	_photo.start()


## The round left the race (stop, home) or a new state began: drops the held results and any
## pending intro instead of reporting them.
func cancel() -> void:
	_photo.stop()
	_pending_results = []
	_intro_id += 1
	_replay.stop()


## Feed it the race's results with its recorder, marbles and whether it had a photo finish.
## Reports them at once, or after a replay when the settings ask for one.
func finish(
	results: Array[Dictionary], recorder: ReplayRecorder, marbles: Array[Marble], photo: bool
) -> void:
	if _wants_replay(results, photo) and recorder != null and recorder.has_clip():
		# Held until the replay ends. The finish signal comes from the physics callback, where
		# bodies must not be moved, so the replay itself starts later, after a short beat.
		_pending_results = results
		_recorder = recorder
		_marbles = marbles
		_intro_id += 1
		_intro(_intro_id)
		return
	results_ready.emit(results)


## The lead-in: a beat on the live finish, a dip to dark, the replay starts under it and the
## picture fades back in with the REPLAY badge sliding in.
func _intro(id: int) -> void:
	await get_tree().create_timer(REPLAY_BEAT).timeout
	if id != _intro_id:
		return
	var dip: Tween = fade_out.call(REPLAY_FADE)
	await dip.finished
	if id != _intro_id:
		fade_in_requested.emit(REPLAY_FADE)
		return
	_begin_replay()


func _begin_replay() -> void:
	if _pending_results.is_empty():
		fade_in_requested.emit(REPLAY_FADE)
		return
	if not _replay.start(_recorder, _marbles):
		fade_in_requested.emit(REPLAY_FADE)
		var results: Array[Dictionary] = _pending_results
		_pending_results = []
		results_ready.emit(results)
		return
	_photo.stop()
	replay_started.emit()
	fade_in_requested.emit(REPLAY_FADE)


## The crossing has been shown: dip to dark so the podium does not cut in.
func _on_replay_ending() -> void:
	fade_out.call(REPLAY_FADE)


func _on_replay_ended() -> void:
	var results: Array[Dictionary] = _pending_results
	_pending_results = []
	replay_ended.emit(results)


func _wants_replay(results: Array[Dictionary], had_photo_finish: bool) -> bool:
	if settings.finish_replay == GameSettings.REPLAY_OFF or results.is_empty():
		return false
	if not bool(results[0]["finished"]):
		return false
	if settings.finish_replay == GameSettings.REPLAY_ALWAYS:
		return true
	return FinishReplay.is_close(results, had_photo_finish)
