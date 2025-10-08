## State for camera+gun management when fully in the Reload state
extends CameraState


## Called by the state machine when receiving unhandled input events.
func handle_input(_event: InputEvent) -> void:
	if _event.is_action_pressed("reload"):
		finished.emit("Unaimed")
	pass


## Called by the state machine on the engine's main loop tick.
func update(_delta: float) -> void:
	# TODO - allofit!!
	
	# Handle mouse input
	var cam_target_fov : float = cmk.desired_fov * cmk.aimed_fov_percent
	var cam_target_transform : Transform3D = cmk.pmk.camera_controller_anchor.get_global_transform_interpolated()
	
	# Handle camera effects
	var cam_offset_transform : Transform3D = cmk._get_cam_effects_transform()
	
	# Update camera
	cmk.player_camera.fov = cam_target_fov
	cmk.position = cam_target_transform.origin + cam_offset_transform.origin
	cmk.rotation = (
		cam_offset_transform.basis.get_euler() +
		cam_offset_transform.basis.get_euler()
	)


## Called by the state machine on the engine's physics update tick.
func physics_update(_delta: float) -> void:
	pass


## Called by the state machine upon changing the active state. The `data` parameter
## is a dictionary with arbitrary data the state can use to initialize itself.
func enter(previous_state_path: String, data := {}) -> void:
	pass


## Called by the state machine before changing the active state.
## Use this function to clean up the state.
func exit() -> void:
	pass
