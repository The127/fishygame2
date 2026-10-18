class_name ReleaseSurprise
extends RefCounted
## The fake "Fishy Marble Run 3" release joke: the first Open Lobby press after an update
## drops a red 3 onto the title, and the game pretends to be a 3D sequel for a while.
## The stage lives in a static variable so it survives scene changes until the page reloads.

enum Stage { OFF, THREE }

static var stage: Stage = Stage.OFF


## Whether pressing Open Lobby should start the surprise instead of opening the lobby.
static func should_start(enabled: bool, store: ReleaseSurpriseStore) -> bool:
	return enabled and stage == Stage.OFF and not store.is_seen()


## Marks the surprise as played on this browser source and switches the game to the fake 3.
static func begin(store: ReleaseSurpriseStore) -> void:
	store.set_seen(true)
	stage = Stage.THREE


## Arms the surprise again: it plays on the next Open Lobby press.
static func rearm(store: ReleaseSurpriseStore) -> bool:
	stage = Stage.OFF
	return store.set_seen(false)
