@abstract
class_name PlayerState extends State

enum playerStates{
	STAND,
	CROUCH,
	WALK,
	WALK_CROUCH,
	SPRINT,
	SLIDE,
	AIR,
	AIR_CROUCH,
}

var player: PlayerController

func _ready() -> void:
	await owner.ready
	player = owner as PlayerController
	assert(player != null, "The PlayerState state type must be used only in the player scene. It needs the owner to be a Player node.")
