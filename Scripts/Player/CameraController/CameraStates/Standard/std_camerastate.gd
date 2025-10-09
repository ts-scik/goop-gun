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
		cmk.ads_timer = 0.0
		cmk.aim_held = false
		finished.emit("HandlingIn")
	# do regular mouse input capture
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Handle mouse movement
		if event is InputEventMouseMotion:
			cmk.mouse_input.x += -event.screen_relative.x * cmk.mouse_sensitivity
			cmk.mouse_input.y += -event.screen_relative.y * cmk.mouse_sensitivity
		# Handle mouse buttons
		if event.is_action_pressed("shoot_btn"):
			cmk.pmk.input_buffer.buffer_input(cmk.pmk.SHOOT_INPUT)
		elif event.is_action_pressed("aim_btn"):
			# Toggle-aim / Hold to aim
			cmk.aim_held = !cmk.aim_held if cmk.aim_toggle else true
		elif event.is_action_released("aim_btn") and !cmk.aim_toggle:
			# Hold-to-aim (release)
			cmk.aim_held = false


## Handle gamepad aiming/shooting inputs
func _handle_gamepad_gun_input() -> void:
	# Early return if we're not in a captured-mouse state
	if !Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	
	# --- Handle gamepad aiming --- #
	var y_aim : float = Input.get_axis("look_down","look_up")
	var x_aim : float = Input.get_axis("look_right","look_left")
	cmk.mouse_input.y += y_aim * cmk.mouse_sensitivity * cmk.gamepad_sense_scale
	cmk.mouse_input.x += x_aim * cmk.mouse_sensitivity * cmk.gamepad_sense_scale
	
	# --- Handle gamepad aiming/shooting --- #
	# Effectively converts LT/RT into buttons
	var shoot_amount = Input.get_action_strength("shoot_axis")
	var aim_amount = Input.get_action_strength("aim_axis")
	
	var shoot_threshold = 0.25 # TODO - export
	var aim_threshold = 0.1 # TODO - export
	
	# --- Release Triggers --- #
	# If we recently pulled RT, and just released it, reset shoot flag
	if(cmk.recent_gamepad_shoot and shoot_amount < shoot_threshold):
		cmk.recent_gamepad_shoot = false
	# If we recently pulled LT, and just released it, reset aim flag
	# Also - if we're not using toggle aim, we should de-aim
	if(cmk.recent_gamepad_aim and aim_amount < aim_threshold):
		if(!cmk.aim_toggle):
			cmk.aim_held = false
		cmk.recent_gamepad_aim = false
	
	# --- Press Triggers --- #
	# If we haven't recently pulled RT, and just pulled it, shoot!! (and set flag)
	if(!cmk.recent_gamepad_shoot and shoot_amount > shoot_threshold):
		cmk.pmk.input_buffer.buffer_input(cmk.pmk.SHOOT_INPUT)
		cmk.recent_gamepad_shoot = true
	# If we haven't recently pulled LT, and just pulled it, update aim (and set flag)
	if(!cmk.recent_gamepad_aim and aim_amount > aim_threshold):
		# Toggle-aim / Hold to aim
		cmk.aim_held = !cmk.aim_held if cmk.aim_toggle else true
		cmk.recent_gamepad_aim = true


## Called by the state machine on the engine's main loop tick.
func update(delta: float) -> void:
	# --- GAMEPAD --- #
	_handle_gamepad_gun_input()
	
	# --- CAMERACONTROLLER --- #
	# If the window has been resized, do some viewport updates
	if(cmk.screen_size != Vector2(get_viewport().size)):
		cmk._viewport_update()
	
	# Handle mouse input
	var cam_target_fov : float = _determine_zoom_fov() # [ABSTRACT]
	var cam_target_tf : Transform3D = _get_camera_target_transform()
	
	# Handle camera effects
	var cam_offset_tf : Transform3D = cmk._get_cam_effects_transform()
	
	# Update camera
	cmk.player_camera.fov = cam_target_fov
	cmk.position = cam_target_tf.origin + cam_offset_tf.origin
	cmk.rotation = cam_target_tf.basis.get_euler() + cam_offset_tf.basis.get_euler()
	
	# --- GUNCONTROLLER --- #
	# Update the gun's position + rotation - MUST BE AFTER MOUSE/CAMERA UPDATES!!
	# ... at least it did at some point!!
	_get_gun_target_transform(delta) # [ABSTRACT]
	_determine_gun_sway(delta)
	
	# --- CLEANUP --- #
	# Reset mouse input for next frame
	cmk.mouse_input = Vector2.ZERO
	# Determines possible state transitions
	_check_state_transitions() # [ABSTRACT]


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
## Called by the state machine before changing the active state.
## Use this function to clean up the state.
func exit() -> void:
	pass


## Returns target transform for CameraController -- unaimed default
## Handle mouse input event on camera when unaimed
func _get_camera_target_transform() -> Transform3D:
	# UNAIMED state
	_camera_mouse_update() # update mouse position
	return _camera_player_transform_update() # update player transform


## Performs standard updates for UNAIMED camera, given mouse input
## Updates are stored in [cmk.mouse_position] and [cmk.input_rotation]
func _camera_mouse_update() -> void:
	# Reset mouse position to screen center
	cmk.mouse_position = cmk.screen_size/2
	# Rotate the camera (unless it's locked by the bounding boxes)
	cmk.input_rotation.y += cmk.mouse_input.x * cmk.camera_sensitivity
	cmk.input_rotation.x = clampf(
		cmk.input_rotation.x + (cmk.mouse_input.y * cmk.camera_sensitivity),
		deg_to_rad(-90),
		deg_to_rad(85)
	)


## Returns new interpolated player camera anchor transform
## Directly updates rotation of player model + player camera anchor
## Performs said update given current [cmk.input_rotation] value
func _camera_player_transform_update() -> Transform3D:
	# Rotate camera anchor (up/down -- pitch)
	cmk.pmk.camera_controller_anchor.transform.basis = Basis.from_euler(
		Vector3(cmk.input_rotation.x, 0.0, 0.0))
	# Rotate player controller (left/right -- yaw)
	cmk.pmk.global_transform.basis = Basis.from_euler(
		Vector3(0.0, cmk.input_rotation.y, 0.0))
	# Return the interpolated position of player camera anchor
	return cmk.pmk.camera_controller_anchor.get_global_transform_interpolated()


## Returns the current unaimed target Transform3D for the GunController
func _get_gun_unaimed_tf() -> Transform3D:
	# get target pos/rot
	var player_interp := cmk.pmk.get_global_transform_interpolated()
	var unaimed_target_pos : Vector3 = cmk.to_local(
		player_interp.origin + # player origin
		(player_interp.basis * cmk.gck.holstered_pos) + # holstered position (relative to player
		cmk.bob_vec # camera viewbob # TODO kinda hate that we have to do this
	)
	var unaimed_target_rot : Vector3 = cmk.gck.holstered_rot - Vector3(cmk.rotation.x,0,0)
	
	# Determine unaimed TF
	return Transform3D(
		Basis.from_euler(unaimed_target_rot),
		unaimed_target_pos
	)


## Returns Vector3 angle for how much gun should sway, given camera velocity
func _determine_gun_sway(delta) -> Vector3:
	# store post-update, pre-sway basis
	var cmk_rot := cmk.rotation
	var rot_change : Vector3 = Vector3.ZERO
	
	# Rotation change -- only calculated if not holstered
	if(cmk.is_aiming or cmk.aim_held or cmk.ads_timer > 0.0):
		rot_change = cmk_rot - cmk.last_cmk_rot
	
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
	cmk.last_cmk_rot = cmk_rot

	return cmk.gck.camera_sway * cmk.gck.gun_sway_max
