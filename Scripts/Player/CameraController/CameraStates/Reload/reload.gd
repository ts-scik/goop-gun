## State for camera+gun management when fully in the Reload state
extends CameraState


## Called by the state machine when receiving unhandled input events.
func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("reload"):
		finished.emit("ReloadOut")
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Handle mouse movement
		if event is InputEventMouseMotion:
			cmk.mouse_input.x += -event.screen_relative.x * cmk.mouse_sensitivity
			cmk.mouse_input.y += -event.screen_relative.y * cmk.mouse_sensitivity
			cmk.gun_input_rotation.y += cmk.mouse_input.x * cmk.camera_sensitivity
			cmk.gun_input_rotation.x += cmk.mouse_input.y * cmk.camera_sensitivity


## Called by the state machine on the engine's main loop tick.
func update(delta: float) -> void:
	# Handle mouse input
	var cam_target_fov : float = self._determine_zoom_fov()
	var cam_target_tf : Transform3D = self._get_camera_target_transform()
	
	# Handle camera effects
	var cam_offset_tf : Transform3D = cmk._get_cam_effects_transform()
	
	# Update camera
	cmk.player_camera.fov = cam_target_fov
	cmk.position = cam_target_tf.origin + cam_offset_tf.origin
	cmk.rotation = cam_target_tf.basis.get_euler() + cam_offset_tf.basis.get_euler()
	
	# --- GUNCONTROLLER --- #
	# Update the gun's position + rotation - MUST BE AFTER MOUSE/CAMERA UPDATES!!
	# ... at least it did at some point!!
	_get_gun_target_transform(delta)
	
	# --- CLEANUP --- #
	# Reset mouse input for next frame
	cmk.mouse_input = Vector2.ZERO


## Returns desired FOV value at current frame
func _determine_zoom_fov() -> float:
	return cmk.desired_fov * cmk.reload_fov_percent
	#return cmk.desired_fov


## Returns target transform for camera
func _get_camera_target_transform() -> Transform3D:
	# Create temp output transform
	var out_tf : Transform3D
	# get position of player body
	var player_interp : Transform3D = (
		cmk.pmk.get_global_transform_interpolated()
	)
	# get position of gun on global coordinate
	var gun_target_pos_glob : Vector3 = (
		player_interp.origin + # player origin
		(player_interp.basis * cmk.gck.gun_reload_position)# holstered position (relative to player
	)
	# get position of player head
	var player_head_interp : Transform3D = (
		cmk.pmk.camera_controller_anchor.get_global_transform_interpolated()
	)
	# determine angle from head to gun target position
	var head_to_gun_vec : Vector3 = (
		gun_target_pos_glob - player_head_interp.origin
	)
	# set camera anchor angle to the calculated head-to-gun angle
	out_tf.basis = Basis.looking_at(head_to_gun_vec, Vector3.UP, false)
	# set camera position to head position
	out_tf.origin = player_head_interp.origin
	# return new camera target transform
	return out_tf


## Gets target transform for gun
func _get_gun_target_transform(delta) -> Transform3D:
	# Create temp output transform
	var out_tf : Transform3D	
	# get target pos/rot
	var player_interp := cmk.pmk.get_global_transform_interpolated()
	var gun_target_pos : Vector3 = cmk.to_local(
		player_interp.origin + # player origin
		(player_interp.basis * cmk.gck.gun_reload_position) + # holstered position (relative to player
		-cmk.gck.gun_model_holder_basepos +
		cmk.bob_vec # camera viewbob # TODO kinda hate that we have to do this
	)
	var gun_target_rot : Vector3 = cmk.gck.gun_reload_rotation - Vector3(cmk.rotation.x,0,0)
	
	gun_target_rot += Vector3(cmk.gun_input_rotation.x, cmk.gun_input_rotation.y, 0)
	
	# Determine unaimed TF
	out_tf = Transform3D(
		Basis.from_euler(gun_target_rot),
		gun_target_pos
	)
	
	# snap to target tf
	cmk.gck.rotation = Vector3.ZERO
	cmk.gck.gun_model_holder.rotation = out_tf.basis.get_euler() # rotation, not basis -- preserve scale
	cmk.gck.position = out_tf.origin
	
	return out_tf


## Called by the state machine on the engine's physics update tick.
func physics_update(_delta: float) -> void:
	pass


## Called by the state machine upon changing the active state. The `data` parameter
## is a dictionary with arbitrary data the state can use to initialize itself.
func enter(previous_state_path: String, data := {}) -> void:
	cmk.gun_input_rotation = Vector3.ZERO


## Called by the state machine before changing the active state.
## Use this function to clean up the state.
func exit() -> void:
	cmk.gun_input_rotation = Vector3.ZERO
