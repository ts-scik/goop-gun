@abstract
class_name PlayerState extends State

enum playerStates{
	WALK,
	SLIDE,
	AIR,
}

var pmk: PlayerController

func _ready() -> void:
	await owner.ready
	pmk = owner as PlayerController
	assert(pmk != null, "The PlayerState state-type requires PlayerController as owner.")
