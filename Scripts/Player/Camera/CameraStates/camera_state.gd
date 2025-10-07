@abstract
class_name CameraState extends State

enum cameraStates{
	STD_UNAIMED,
	STD_AIMED,
	STD_AIMIN,
	STD_AIMOUT,
	RELOAD,
	RELOAD_IN,
	RELOAD_OUT,
}

var cmk: CameraController

func _ready() -> void:
	await owner.ready
	cmk = owner as CameraController
	assert(cmk != null, "The CameraState state type must be used only in the camera scene. It needs the owner to be a CameraController node.")
