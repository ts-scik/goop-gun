extends CameraState


## Called by the state machine when receiving unhandled input events.
func handle_input(_event: InputEvent) -> void:
	pass


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
	cmk.gck.target_transform = _get_aimout_gun_transform(delta)
	cmk.gck.manage_positioning(delta)
	
	# Zero out our mouse input for next frame
	cmk.mouse_input = Vector2.ZERO
	
	# If we're no longer trying to aim out, aim in
	# ... unless we're trying to aim while sprinting, and still above the sprint aim cap
	var max_aim_amt = cmk.gck.ads_time * 0.4 if cmk.pmk.is_running else cmk.gck.ads_time 
	if cmk.pmk.aim_held and cmk.gck.ads_timer < max_aim_amt:
		finished.emit("AimIn")
	# If we've fully aimed out, transition to Unaimed
	if cmk.gck.ads_ratio() <= 0.0:
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
	if not cmk.enable_aim_zoom or cmk.gck.ads_ratio() <= 0.0:
		return cmk.desired_fov
	return lerpf(cmk.desired_fov, cmk.desired_fov * cmk.aimed_fov_percent, cmk.gck.ads_ratio())


## Animates gun in/out of aiming position
func _get_aimout_gun_transform(delta) -> Transform3D:
	# get target pos/rot
	var player_interp := cmk.pmk.get_global_transform_interpolated()
	var unaimed_target_pos : Vector3 = cmk.to_local(
		player_interp.origin + # player origin
		(player_interp.basis * cmk.gck.holstered_pos) + # holstered position (relative to player
		cmk.bob_vec # camera viewbob # TODO kinda hate that we have to do this
	)
	var unaimed_target_rot : Vector3 = cmk.gck.holstered_rot - Vector3(cmk.rotation.x,0,0)
	
	# Ending an aim
	cmk.gck.ads_timer = max(cmk.gck.ads_timer - delta, 0.0) # update the aim timer
	if(cmk.gck.is_aiming): # update is_aiming, last_aimed stuff
		cmk.gck.is_aiming = false
		cmk.gck.last_aimed_target_pos = cmk.gck.position
		cmk.gck.last_aimed_target_rot = cmk.gck.rotation
	
	# Aim transition lerp
	var out_tf : Transform3D
	out_tf.origin = lerp(unaimed_target_pos, cmk.gck.last_aimed_target_pos, cmk.gck.ads_ratio())
	out_tf.basis = Basis.from_euler(lerp(unaimed_target_rot, cmk.gck.last_aimed_target_rot, cmk.gck.ads_ratio()))
	return out_tf


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
