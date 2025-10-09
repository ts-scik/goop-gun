## State for camera+gun management when fully in the Reload state
extends CameraState


## Called by the state machine when receiving unhandled input events.
func handle_input(_event: InputEvent) -> void:
	if _event.is_action_pressed("reload"):
		finished.emit("ReloadIn")


## Called by the state machine on the engine's main loop tick.
func update(delta: float) -> void:
	cmk.reload_timer = max(cmk.reload_timer-delta, 0.0)
	
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
	_get_gun_target_transform(delta) # [ABSTRACT]
	
	if(cmk.reload_timer <= 0.0):
		finished.emit("Unaimed")
		return


## Returns desired FOV value at current frame
func _determine_zoom_fov() -> float:
	if cmk.reload_timer <= 0.0:
		return cmk.desired_fov
	return lerpf(
		cmk.desired_fov,
		cmk.desired_fov * cmk.reload_fov_percent,
		cmk.reload_timer / cmk.reload_entry_time
	)


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
	var target_basis = Basis.looking_at(head_to_gun_vec, Vector3.UP, false)
	var start_basis = Basis.from_euler(
		Vector3(cmk.input_rotation.x, cmk.input_rotation.y, 0.0)
	)
	out_tf.basis = lerp(start_basis, target_basis, cmk.reload_timer/cmk.reload_entry_time)
	# set camera position to head position
	out_tf.origin = player_head_interp.origin
	# return new camera target transform
	return out_tf


func _get_gun_target_transform(delta) -> Transform3D:
	# Create temp output transform
	var out_tf : Transform3D	
	# get target pos/rot
	var player_interp := cmk.pmk.get_global_transform_interpolated()
	var gun_target_pos : Vector3 = cmk.to_local(
		player_interp.origin + # player origin
		(player_interp.basis * cmk.gck.gun_reload_position) + # holstered position (relative to player
		cmk.bob_vec # camera viewbob # TODO kinda hate that we have to do this
	)
	var gun_start_pos : Vector3 = cmk.to_local(
		player_interp.origin + # player origin
		(player_interp.basis * cmk.gck.holstered_pos) + # holstered position (relative to player
		cmk.bob_vec # camera viewbob # TODO kinda hate that we have to do this
	)
	var gun_target_rot : Vector3 = cmk.gck.gun_reload_rotation - Vector3(cmk.rotation.x,0,0)
	
	# Determine unaimed TF
	out_tf.basis = Basis.from_euler(gun_target_rot)
	out_tf.origin = lerp(gun_start_pos, gun_target_pos, cmk.reload_timer/cmk.reload_entry_time)
	
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
	pass


## Called by the state machine before changing the active state.
## Use this function to clean up the state.
func exit() -> void:
	# --- CLEANUP --- #
	# Reset mouse input for next frame
	cmk.mouse_input = Vector2.ZERO
