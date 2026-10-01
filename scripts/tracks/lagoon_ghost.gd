class_name LagoonGhost
extends RefCounted
## One cut fish in the lagoon of Riptide Rounds: where it waits, and what it is doing now. The
## [EddyRing] moves it; this is only its state.

enum Mode { DRAIN, IDLE, FLIGHT, SPIN, HOME }

var marble: Marble = null
## A fish that finished the race, not one that was cut: it has no eddy to send.
var victor: bool = false
## The fish's resting place in the lagoon.
var home: Vector2 = Vector2.ZERO
var mode: Mode = Mode.DRAIN
## Seconds spent in the current mode.
var time: float = 0.0
## Where the current move started and where it ends.
var from: Vector2 = Vector2.ZERO
var to: Vector2 = Vector2.ZERO
## Index of the eddy the fish is sending out, or -1.
var eddy: int = -1
## Offset of the fish's bobbing, so the ghosts do not move in step.
var phase: float = 0.0
