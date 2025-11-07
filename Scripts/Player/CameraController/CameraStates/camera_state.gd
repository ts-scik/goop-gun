@abstract
class_name CameraState extends State

enum cameraStates{
	STD_UNAIMED,
	STD_AIMED,
	STD_AIMIN,
	STD_AIMOUT,
	RELOAD,
	HANDLING_IN,
	HANDLING_OUT,
	HANDLING,
}

var cmk: CameraController

func _ready() -> void:
	await owner.ready
	cmk = owner as CameraController
	assert(cmk != null, "The CameraState state-type requires CameraController owner.")
