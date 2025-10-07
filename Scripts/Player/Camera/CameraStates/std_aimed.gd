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
	var target_fov : float = (cmk.desired_fov * cmk.aimed_fov_percent)
	var cam_target_transform : Transform3D = _aimed_mouse_camera_update()
	
	# Handle camera effects
	var cam_offset_transform : Transform3D = cmk._calculate_effects()
	
	# Update camera
	cmk.player_camera.fov = target_fov
	cmk.position = cam_target_transform.origin + cam_offset_transform.origin
	cmk.rotation = cam_target_transform.basis.get_euler() + cam_offset_transform.basis.get_euler()
	
	# Update the gun's position + rotation - THIS MUST BE AFTER MOUSE/CAMERA UPDATES!!
	# TODO - is that true??
	cmk.gck.target_transform = _get_aimed_gun_transform()
	cmk.gck.manage_positioning(delta)
	
	# Zero out our mouse input for next frame
	cmk.mouse_input = Vector2.ZERO
	
	# If we're no longer in an aiming state, transition out
	if !(cmk.pmk.aim_held and cmk.gck.is_aiming and !cmk.pmk.is_running):
		finished.emit("AimOut")


## Handle mouse input event on camera
func _aimed_mouse_camera_update() -> Transform3D:
	var mouse_y_locked : bool = false
	var mouse_x_locked : bool = false
	
	# AIMED state
	if(cmk.gck.is_aiming):
		# Update mouse position
		# TODO -- why only screen_size.y? why * 20?
		var midpoint : Vector2 = cmk.screen_size/2
		var mouse_newpos : Vector2 = cmk.mouse_position - (
			cmk.mouse_input * cmk.aim_sensitivity * cmk.screen_size.y * 20
		)
		cmk.mouse_position.x = clampf(
			mouse_newpos.x,
			midpoint.x - cmk.gun_deadzone.x,
			midpoint.x + cmk.gun_deadzone.x
		)
		cmk.mouse_position.y = clampf(
			mouse_newpos.y,
			midpoint.y - cmk.gun_deadzone.y,
			midpoint.y + cmk.gun_deadzone.z
		)

		# If the mouse is still within the bounding box on an axis, lock that axis' camera rotation
		if(cmk.mouse_position.x == mouse_newpos.x):
			mouse_x_locked = true
		if(cmk.mouse_position.y == mouse_newpos.y):
			mouse_y_locked = true
		
		# Debug - Move our debug red-dot
		#TODO - move this elsewhere
		if(cmk.debug_dot): cmk.guncanvas.update_dot_pos(cmk.mouse_position)
	
	# If both axes are locked, early return
	if mouse_x_locked and mouse_y_locked:
		return cmk.pmk.camera_controller_anchor.get_global_transform_interpolated()
	
	# Rotate the camera (unless it's locked by the bounding boxes)
	if !mouse_x_locked:
		cmk.input_rotation.y += cmk.mouse_input.x * cmk.camera_sensitivity
	if !mouse_y_locked:
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


## Updates the gun's position+rotation (for if gun exists in local space)
func _get_aimed_gun_transform() -> Transform3D:
	# Create temp output transform
	var out_tf : Transform3D
	# Get vector from player camera to gun_controller
	var fw_dir : Vector3 = (
		cmk.to_local(cmk.gck.global_position) - 
		cmk.to_local(cmk.player_camera.global_position) 
	)
	# Determine point where gun should be held
	out_tf.origin = cmk.to_local( 
		cmk.player_camera.project_position(
			cmk.mouse_position, cmk.gck.gun_hold_distance
		)
	)
	# Update the gun's rotation (relative to camera)
	out_tf.basis = Basis.looking_at(fw_dir, Vector3.UP, false)
	return out_tf


## Called by the state machine on the engine's physics update tick.
func physics_update(_delta: float) -> void:
	pass


## Called by the state machine upon changing the active state. The `data` parameter
## is a dictionary with arbitrary data the state can use to initialize itself.
func enter(_previous_state_path: String, _data := {}) -> void:
	# Debug - update our debug red-dot color
	if(cmk.debug_dot):
		cmk.guncanvas.update_dot_color(Color.RED)


## Called by the state machine before changing the active state. Use this function
## to clean up the state.
func exit() -> void:
	# Debug - update our debug red-dot color
	if(cmk.debug_dot):
		cmk.guncanvas.update_dot_pos(cmk.screen_size/2)
		cmk.guncanvas.update_dot_color(Color.BLUE)
