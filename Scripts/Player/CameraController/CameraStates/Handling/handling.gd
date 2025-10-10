## State for camera+gun management when fully in the Handling state
extends CameraState


## Called by the state machine when receiving unhandled input events.
func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("reload"):
		cmk.want_handling = !cmk.want_handling
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Handle mouse movement
		if event is InputEventMouseMotion:
			cmk.mouse_input.x += -event.screen_relative.x * cmk.mouse_sensitivity
			cmk.mouse_input.y += -event.screen_relative.y * cmk.mouse_sensitivity
			cmk.gun_input_rotation.y = clampf(
					cmk.gun_input_rotation.y + (cmk.mouse_input.x * cmk.camera_sensitivity),
					deg_to_rad(-190),
					deg_to_rad(170)
				)
			cmk.gun_input_rotation.x = clampf(
					cmk.gun_input_rotation.x + (cmk.mouse_input.y * cmk.camera_sensitivity),
					deg_to_rad(-40),
					deg_to_rad(70)
				)


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
	
	# --- PLAYER HANDS --- #
	_cam_hand_update()
	
	# --- CLEANUP --- #
	# Reset mouse input for next frame
	cmk.mouse_input = Vector2.ZERO
	
	if(cmk.want_handling == false):
		finished.emit("HandlingOut")


## Returns desired FOV value at current frame
func _determine_zoom_fov() -> float:
	return cmk.desired_fov * cmk.handling_fov_percent


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
		(player_interp.basis * cmk.gck.gun_handling_origin_position)# holstered position (relative to player
	)
	# get position of player head on global coordinate
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
	# --- GUNMODEL--- #
	# Create temp output transform
	var out_tf : Transform3D	
	# get base gun target position
	var player_interp := cmk.pmk.get_global_transform_interpolated()
	var gun_target_pos : Vector3 = cmk.to_local(
		player_interp.origin # player origin
		+ (player_interp.basis * (cmk.gck.gun_handling_origin_position + cmk.gck.gun_handling_offset_position)) # target position (relative to player)
		- cmk.gck.gun_model_holder_basepos
		+ cmk.bob_vec # camera viewbob # TODO kinda hate that we have to do this
	)
	# get base gun target rotation
	var gun_target_rot : Vector3 = Vector3.ZERO
	# add reload target rotation
	gun_target_rot += cmk.gck.gun_reload_rotation
	# add input rotation
	gun_target_rot += Vector3(cmk.gun_input_rotation.x, cmk.gun_input_rotation.y, 0)
	
	# Determine unaimed TF
	out_tf.basis = Basis.from_euler(gun_target_rot)
	out_tf.origin = gun_target_pos
	
	# snap to target tf
	cmk.gck.gun_model_holder.rotation = out_tf.basis.get_euler() # rotation, not basis -- preserve scale
	cmk.gck.position = out_tf.origin
	
	# --- GUNCONTROLLER --- #
	# get angle from camera to gun target position
	var cam_to_gun_vec : Vector3 = (
		gun_target_pos
		- cmk.to_local(cmk.player_camera.global_position)
		- (cmk.gck.gun_handling_offset_position * 0.5)
	)
	var cam_to_gun_angle = Basis.looking_at(cam_to_gun_vec, Vector3.UP, false).get_euler()
	cmk.gck.rotation = cam_to_gun_angle
	
	return out_tf


## Called by the state machine on the engine's physics update tick.
func physics_update(_delta: float) -> void:
	pass


## Called by the state machine upon changing the active state. The `data` parameter
## is a dictionary with arbitrary data the state can use to initialize itself.
func enter(previous_state_path: String, data := {}) -> void:
	cmk.gun_input_rotation = Vector3.ZERO
	pass


## Called by the state machine before changing the active state.
## Use this function to clean up the state.
func exit() -> void:
	cmk.gun_input_rotation = Vector3.ZERO
	pass


## Snap the player's right camera hand model to the gun's marked position
## Move the player's left hand offscreen
func _cam_hand_update() -> void:
	cmk.l_hand.global_position = cmk.gck.r_hand_grip_marker.global_position
	cmk.r_hand.position = Vector3.ZERO
