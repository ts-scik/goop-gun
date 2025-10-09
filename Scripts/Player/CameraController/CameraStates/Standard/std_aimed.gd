## State for camera+gun management when completely Aimed
extends StandardCameraState

## [OVERRIDE]
## Called by the state machine on the engine's main loop tick.
## We override this so we can handle shooting!!
func update(delta) -> void:
	# --- !TRY SHOOTING! --- #
	# check if we're allowed to shoot again
	if(cmk.gck.shoot_time_remaining() >= cmk.reshoot_cutoff):
		# try retrieving a SHOOT_INPUT from the input buffer
		# if there's one in there, let's shoot!!w
		if(cmk.pmk.input_buffer.buffer_retrieve(cmk.pmk.SHOOT_INPUT)):
			cmk.camera_gun_kick()
			cmk.gck.shoot()
	super(delta)


## [OVERRIDE]
## Called by the state machine upon changing the active state. The `data` parameter
## is a dictionary with arbitrary data the state can use to initialize itself.
func enter(_previous_state_path: String, _data := {}) -> void:
	cmk.is_aiming = true
	# Debug - update our debug red-dot color
	if(cmk.debug_dot):
		cmk.guncanvas.update_dot_color(Color.RED)


## [OVERRIDE]
## Called by the state machine before changing the active state.
## Use this function to clean up the state.
func exit() -> void:
	cmk.is_aiming = false
	cmk.gck.last_aimed_target_pos = cmk.gck.position
	cmk.gck.last_aimed_target_rot = cmk.gck.rotation
	# Debug - update our debug red-dot color
	if(cmk.debug_dot):
		cmk.guncanvas.update_dot_pos(cmk.screen_size/2)
		cmk.guncanvas.update_dot_color(Color.BLUE)


## [OVERRIDE]
## Performs standard updates for AIMED camera, given mouse input
## Updates are stored in [cmk.mouse_position] and [cmk.input_rotation]
func _camera_mouse_update() -> void:
	# Update mouse position
	var midpoint : Vector2 = cmk.screen_size/2
		# we scale below by screen_size.y to make it scale with resolution
		# but we only scale by screen_size.y OR screen_size.x --
		# otherwise you get weird behavior on diagonal mouse inputs
	var mouse_newpos : Vector2 = cmk.mouse_position - (
		cmk.mouse_input * cmk.aim_sensitivity * cmk.screen_size.y
	)
	cmk.mouse_position.x = clampf(
		mouse_newpos.x,
		midpoint.x - cmk.gun_deadzone.x,	# left deadzone
		midpoint.x + cmk.gun_deadzone.x		# right deadzone
	)
	cmk.mouse_position.y = clampf(
		mouse_newpos.y,
		midpoint.y - cmk.gun_deadzone.y,	# top deadzone
		midpoint.y + cmk.gun_deadzone.z		# bottom deadzone
	)

	# Holder booleans for checking if an axis is locked
	# If the mouse is still within the bounding box on an axis, lock that axis.
	var mouse_x_locked : bool = (cmk.mouse_position.x == mouse_newpos.x)
	var mouse_y_locked : bool =  (cmk.mouse_position.y == mouse_newpos.y)
	
	# Debug - Move our debug red-dot
	#TODO - move this elsewhere?
	if(cmk.debug_dot):
		cmk.guncanvas.update_dot_pos(cmk.mouse_position)
	
	# If both axes are rotation-locked, early return
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


## [ABSTRACT IMPL]
## Determines current zoom fov -- returns fully-zoomed FOV, since we're aimed
func _determine_zoom_fov() -> float:
	return (cmk.desired_fov * cmk.aimed_fov_percent)


## [ABSTRACT IMPL]
## Updates the gun's position+rotation (for if gun exists in local space)
func _get_gun_target_transform(delta) -> Transform3D:
	# Create temp output transform
	var out_tf : Transform3D
	# Get vector from player camera to gun_controller
	var fw_dir : Vector3 = (
		cmk.to_local(cmk.gck.global_position) - 
		cmk.to_local(cmk.player_camera.global_position) 
	)
	# Update the gun's rotation (relative to camera)
	out_tf.basis = Basis.looking_at(fw_dir, Vector3.UP, false)
	
	# Determine point where gun should be held
	out_tf.origin = cmk.to_local( 
		cmk.player_camera.project_position(
			cmk.mouse_position, cmk.gck.gun_hold_distance
		)
	)
	
	# snap (lerp, actually!) to target tf
	var snapspeed = 10 # TODO - make this an export if we're keeping it
	cmk.gck.rotation = lerp(
		cmk.gck.rotation,
		out_tf.basis.get_euler(),
		delta * snapspeed
	)
	cmk.gck.position = out_tf.origin
	
	return out_tf


## [ABSTRACT IMPL]
## Determines whether we should change state
func _check_state_transitions() -> void:
	# If we're no longer in an aiming state, transition out
	# If we aren't holding aim, or we aren't is_aiming, or we started running
	if (!cmk.aim_held or !cmk.is_aiming or cmk.pmk.is_running):
		finished.emit("AimOut")
