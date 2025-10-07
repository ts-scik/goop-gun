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
	assert(pmk != null, "The PlayerState state type must be used only in the player scene. It needs the owner to be a Player node.")
