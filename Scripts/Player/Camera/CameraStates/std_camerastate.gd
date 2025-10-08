## Parent state from which Standard CameraStates inherit
## (A standard state is like... when you're walking around and living yr life)
@abstract
class_name StandardCameraState extends CameraState

## Returns desired FOV value at current frame
@abstract
func _determine_zoom_fov() -> float

## Returns target transform for GunController
@abstract
func _get_gun_target_transform(delta) -> Transform3D

## Determines whether we should change state
@abstract
func _check_state_transitions() -> void


## Called by the state machine when receiving unhandled input events.
func handle_input(event: InputEvent) -> void:
	# custom bit to handle reloading
	if event.is_action_pressed("reload"):
		finished.emit("Reload")
	# do regular mouse input capture
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Handle mouse movement
		if event is InputEventMouseMotion:
			cmk.mouse_input.x += -event.screen_relative.x * cmk.mouse_sensitivity
			cmk.mouse_input.y += -event.screen_relative.y * cmk.mouse_sensitivity
	
	# Handle gamepad aiming
	var y_aim : float = Input.get_axis("look_down","look_up")
	var x_aim : float = Input.get_axis("look_right","look_left")
	cmk.mouse_input.y += y_aim * cmk.mouse_sensitivity * cmk.gamepad_sense_scale
	cmk.mouse_input.x += x_aim * cmk.mouse_sensitivity * cmk.gamepad_sense_scale


## Called by the state machine on the engine's main loop tick.
func update(delta: float) -> void:
	# If the window has been resized, do some viewport updates
	if(cmk.screen_size != Vector2(get_viewport().size)):
		cmk._viewport_update()
	
	# Handle mouse input
	var cam_target_fov : float = _determine_zoom_fov()
	var cam_target_transform : Transform3D = _get_camera_target_transform()
	
	# Handle camera effects
	var cam_offset_transform : Transform3D = cmk._calculate_effects()
	
	# Update camera
	cmk.player_camera.fov = cam_target_fov
	cmk.position = cam_target_transform.origin + cam_offset_transform.origin
	cmk.rotation = cam_target_transform.basis.get_euler() + cam_offset_transform.basis.get_euler()
	
	# Update the gun's position + rotation - THIS MUST BE AFTER MOUSE/CAMERA UPDATES!!
	# ... at least it did at some point!!
	_get_gun_target_transform(delta)
	_determine_gun_sway(delta)
	
	# Zero out our mouse input for next frame
	cmk.mouse_input = Vector2.ZERO
	
	# Determines possible state transitions
	_check_state_transitions()


## [ABSTRACT IMPL]
## Called by the state machine on the engine's physics update tick.
func physics_update(_delta: float) -> void:
	pass


## [ABSTRACT IMPL]
## Called by the state machine upon changing the active state. The `data` parameter
## is a dictionary with arbitrary data the state can use to initialize itself.
func enter(_previous_state_path: String, _data := {}) -> void:
	pass


## [ABSTRACT IMPL]
## Called by the state machine before changing the active state. Use this function
## to clean up the state.
func exit() -> void:
	pass


## Returns target transform for CameraController -- unaimed default
## Handle mouse input event on camera when unaimed
func _get_camera_target_transform() -> Transform3D:
	# UNAIMED state
	# Reset mouse position to screen center
	cmk.mouse_position = cmk.screen_size/2
	
	# Rotate the camera (unless it's locked by the bounding boxes)
	cmk.input_rotation.y += cmk.mouse_input.x * cmk.camera_sensitivity
	cmk.input_rotation.x = clampf(
		cmk.input_rotation.x + (cmk.mouse_input.y * cmk.camera_sensitivity),
		deg_to_rad(-90),
		deg_to_rad(85)
	)
	
	# Update the pmk rotation
	# Rotate camera controller (up/down)
	cmk.pmk.camera_controller_anchor.transform.basis = Basis.from_euler(Vector3(cmk.input_rotation.x, 0.0, 0.0))
	# Rotate player controller (left/right)
	cmk.pmk.global_transform.basis = Basis.from_euler(Vector3(0.0, cmk.input_rotation.y, 0.0))
	# Move transform to player head anchor
	return cmk.pmk.camera_controller_anchor.get_global_transform_interpolated()


## Returns Vector3 angle for how much gun should sway, given camera velocity
func _determine_gun_sway(delta) -> Vector3:
	# store post-update, pre-sway basis
	var cmk_rot := cmk.rotation
	var rot_change : Vector3 = Vector3.ZERO
	
	# Rotation change -- only calculated if not holstered
	if(cmk.is_aiming or cmk.pmk.aim_held or cmk.ads_timer > 0.0):
		rot_change = cmk_rot - cmk.gck.last_cmk_rot
	
		# Keep rot_change inbounds
		for idx in 3:
			if(abs(rot_change[idx]) > PI):
				rot_change[idx] -= TAU * sign(rot_change[idx])
	
		rot_change.z = rot_change.y # TODO - are you sure?
	
		# Apply rot_change to camera_sway
		var CHANGESCALE = 1
		cmk.gck.camera_sway += (rot_change * CHANGESCALE)
		cmk.gck.camera_sway.clampf(-1.0, 1.0)
	
	# Recenter
	var RECENTER = 7
	cmk.gck.camera_sway = lerp(cmk.gck.camera_sway, Vector3.ZERO, delta*RECENTER)

	# Store this frame's pre-sway basis for next frame
	cmk.gck.last_cmk_rot = cmk_rot

	return cmk.gck.camera_sway * cmk.gck.gun_sway_max
