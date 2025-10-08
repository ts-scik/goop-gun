## State for camera+gun management when transitioning from Aimed -> Unaimed
extends StandardCameraState
# TODO - implement HSM to move a lot of this elsewhere


## Called by the state machine when receiving unhandled input events.
func handle_input(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Handle mouse movement
		if event is InputEventMouseMotion:
			cmk.mouse_input.x += -event.screen_relative.x * cmk.mouse_sensitivity
			cmk.mouse_input.y += -event.screen_relative.y * cmk.mouse_sensitivity


## Called by the state machine on the engine's main loop tick.
func update(delta: float) -> void:
	# If the window has been resized, do some viewport updates
	if(cmk.screen_size != Vector2(get_viewport().size)):
		cmk._viewport_update()
	
	# Handle mouse input
	var target_transform : Transform3D = _unaimed_mouse_camera_update()
	
	# Handle camera effects
	var target_fov : float = _aim_trans_determine_zoom_fov()
	var offset_transform : Transform3D = cmk._calculate_effects()
	
	# Update camera
	cmk.player_camera.fov = target_fov
	cmk.position = target_transform.origin + offset_transform.origin
	cmk.rotation = target_transform.basis.get_euler() + offset_transform.basis.get_euler()
	
	# Update the gun's position + rotation - THIS MUST BE AFTER MOUSE/CAMERA UPDATES!!
	# TODO - is that true??
	_aimout_gun_target_transform(delta)
	_determine_gun_sway(delta)
	
	# Zero out our mouse input for next frame
	cmk.mouse_input = Vector2.ZERO
	
	# If we're no longer trying to aim out, aim in
	# ... unless we're trying to aim while sprinting, and still above the sprint aim cap
	var max_aim_amt = cmk.ads_time * 0.4 if cmk.pmk.is_running else cmk.ads_time 
	if cmk.pmk.aim_held and cmk.ads_timer < max_aim_amt:
		finished.emit("AimIn")
	# If we've fully aimed out, transition to Unaimed
	if cmk.ads_ratio() <= 0.0:
		finished.emit("Unaimed")


## Handle mouse input event on camera
func _unaimed_mouse_camera_update() -> Transform3D:
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


## Determines how zoom-in the fov should be, given the current gck ads_ratio
func _aim_trans_determine_zoom_fov() -> float:
	if not cmk.enable_aim_zoom or cmk.ads_ratio() <= 0.0:
		return cmk.desired_fov
	return lerpf(cmk.desired_fov, cmk.desired_fov * cmk.aimed_fov_percent, cmk.ads_ratio())


## Animates gun in/out of aiming position
func _aimout_gun_target_transform(delta) -> Transform3D:
	# get target pos/rot
	var player_interp := cmk.pmk.get_global_transform_interpolated()
	var unaimed_target_pos : Vector3 = cmk.to_local(
		player_interp.origin + # player origin
		(player_interp.basis * cmk.gck.holstered_pos) + # holstered position (relative to player
		cmk.bob_vec # camera viewbob # TODO kinda hate that we have to do this
	)
	var unaimed_target_rot : Vector3 = cmk.gck.holstered_rot - Vector3(cmk.rotation.x,0,0)
	
	# Ending an aim
	cmk.ads_timer = max(cmk.ads_timer - delta, 0.0) # update the aim timer
	
	# Aim transition lerp
	var out_tf : Transform3D
	out_tf.origin = lerp(unaimed_target_pos, cmk.gck.last_aimed_target_pos, cmk.ads_ratio())
	out_tf.basis = Basis.from_euler(lerp(unaimed_target_rot, cmk.gck.last_aimed_target_rot, cmk.ads_ratio()))
	
	# snap to target tf
	cmk.gck.rotation = out_tf.basis.get_euler() # rotation rather than basis, so we maintain scale
	cmk.gck.position = out_tf.origin
	
	return out_tf


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


## Called by the state machine on the engine's physics update tick.
func physics_update(_delta: float) -> void:
	pass


## Called by the state machine upon changing the active state. The `data` parameter
## is a dictionary with arbitrary data the state can use to initialize itself.
func enter(_previous_state_path: String, _data := {}) -> void:
	pass


## Called by the state machine before changing the active state. Use this function
## to clean up the state.
func exit() -> void:
	pass
