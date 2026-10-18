class_name Lurkers
extends Node
## "#lurk": instead of racing, the viewer watches from the scenery as a shadow of their fish with
## a pair of eyes ([LurkerDen] draws them). The first "#lurk" hands out a random eye style for
## good ([LurkerEyes]). A viewer keeps lurking, race after race and across restarts, until they
## "#join" a race again.
##
## Every race a lurker sits out silently earns them [constant POINTS_PER_RACE].
## The node emits [signal lurkers_changed] for the den and never talks to the chat itself.

## The current lurkers, see [method watchers].
signal lurkers_changed(watchers: Array[Dictionary])
## A viewer just started lurking.
signal lurk_started(display_name: String)

const COMMAND: String = "lurk"
const POINTS_PER_RACE: int = 1

## The scores to pay into, shared with betting. Set by the owner.
var points: PointsStore = null
## Where the lurking and the eye styles are kept, shared with the shop. Set by the owner.
var store: ShopStore = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## User ids racing in the current lobby or race; they do not lurk in it.
var _racing: Dictionary = {}


func _init() -> void:
	rng.randomize()


## Feed it Chat.command_received.
func handle_command(msg: ChatMessage, command: String, _args: PackedStringArray) -> void:
	if command == COMMAND:
		lurk(msg.user_id, ChatReplies.viewer_name(msg))


## Starts lurking. Returns false when the viewer already lurks.
func lurk(user_id: String, display_name: String) -> bool:
	if store.is_lurking(user_id):
		return false
	store.set_lurking(user_id, true)
	if store.equipped(user_id, ShopStore.KIND_EYES).is_empty():
		var style: String = LurkerEyes.random_style(rng)
		store.grant(user_id, ShopStore.KIND_EYES, style)
		store.equip(user_id, ShopStore.KIND_EYES, style)
	store.save_to_disk()
	lurk_started.emit(display_name)
	lurkers_changed.emit(watchers())
	return true


## Feed it GameFlow.player_joined: joining a race ends lurking.
func add_contestant(contestant: Contestant) -> void:
	_racing[contestant.user_id] = true
	if store.is_lurking(contestant.user_id):
		store.set_lurking(contestant.user_id, false)
		store.save_to_disk()
		lurkers_changed.emit(watchers())


## Feed it GameFlow.state_changed.
func on_state_changed(new_state: GameFlow.State, _old_state: GameFlow.State) -> void:
	if new_state == GameFlow.State.LOBBY or new_state == GameFlow.State.IDLE:
		_racing.clear()
		lurkers_changed.emit(watchers())


## Feed it Race.race_finished: pays every lurker who sat this race out, without a word in chat.
func on_race_finished(_results: Array[Dictionary]) -> void:
	var paid: bool = false
	for user_id: String in store.lurkers():
		if not _racing.has(user_id):
			points.add(user_id, POINTS_PER_RACE)
			paid = true
	if paid:
		points.save_to_disk()


## The lurkers watching right now (not racing), each {"user_id", "eyes", "species"}, in the
## order they started lurking.
func watchers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for user_id: String in store.lurkers():
		if _racing.has(user_id):
			continue
		var eyes: String = store.equipped(user_id, ShopStore.KIND_EYES)
		var species: int = ShopCatalog.index_of(
			ShopStore.KIND_SPECIES, store.equipped(user_id, ShopStore.KIND_SPECIES)
		)
		if species < 0:
			species = posmod(hash(user_id), FishVisual.SPECIES.size())
		(
			result
			. append(
				{
					"user_id": user_id,
					"eyes": eyes if not eyes.is_empty() else LurkerEyes.PLAIN,
					"species": species,
				}
			)
		)
	return result
