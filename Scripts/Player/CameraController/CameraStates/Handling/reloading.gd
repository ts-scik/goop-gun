## State for camera+gun management when fully in the Reload state
extends CameraState

var l_hand_tgt: Vector3 = Vector3.ZERO # Global position of hand's starting position
var l_hand_offset: Vector3 = Vector3.ZERO # Offset from hand's starting position
var starting_hand_distance := 0.75 # Hand's starting distance from mag
var mag_left: Vector3 # Left, relative to mag, in global space
var mag_grip: Vector3 # Grip position of magazine
var hand_start_to_mag: Vector3 # Vector from hand's start pos to magazine grip point
var min_closeness_ratio := 0.96 # Minimum % of the way hand must be before grabbing
const mag_scene = preload("res://Prefabs/Player/magazine_controller.tscn")
var dummy_mag: MagazineController = null # Fake magazine controller we're carrying around

## Called by the state machine when receiving unhandled input events.
func handle_input(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Handle mouse movement
		if event is InputEventMouseMotion:
			cmk.mouse_input.x += -event.screen_relative.x * cmk.mouse_sensitivity
			cmk.mouse_input.y += -event.screen_relative.y * cmk.mouse_sensitivity
			l_hand_offset -= cmk.mouse_input.x * hand_start_to_mag
			l_hand_offset = l_hand_offset.limit_length(hand_start_to_mag.length())
	
	if event.is_action_released("reload_interact1"):
		finished.emit("Handling")
	
	if event.is_action_pressed("reload_interact2"):
		_try_grab_mag()
	if event.is_action_released("reload_interact2"):
		_try_release_mag()

## Called by the state machine on the engine's main loop tick.
func update(delta: float) -> void:
	# Handle mouse input
	var cam_target_tf : Transform3D = self._get_camera_target_transform()
	
	# Handle camera effects
	var cam_offset_tf : Transform3D = cmk._get_cam_effects_transform()
	
	# Update camera
	cmk.position = cam_target_tf.origin + cam_offset_tf.origin
	cmk.rotation = cam_target_tf.basis.get_euler() + cam_offset_tf.basis.get_euler()
	
	# --- GUNCONTROLLER --- #
	# Update the gun's position + rotation - MUST BE AFTER MOUSE/CAMERA UPDATES!!
	# ... at least it did at some point!!
	_get_gun_target_transform(delta) # [ABSTRACT]
	
	# --- PLAYER HANDS --- #
	_cam_hand_update()
	
	# --- CLEANUP --- #
	# Reset mouse input for next frame
	cmk.mouse_input = Vector2.ZERO
	
	if(cmk.want_handling == false):
		finished.emit("HandlingOut")

	mag_left = -cmk.gck.gun_magazine.global_basis.x	# Left, relative to gun's magazine
	mag_grip = cmk.gck.gun_magazine.mag_grip_point.global_position	# Magazine grip point, in global space
	mag_grip += cmk.pmk.velocity * delta # TODO - this is not smart i think. also viewbob is still a problem
	
	l_hand_tgt = mag_grip + (mag_left * starting_hand_distance)	# Get our left hand start target
	hand_start_to_mag = mag_grip - l_hand_tgt	# Get vector from hand start to mag position


## Called by the state machine on the engine's physics update tick.
func physics_update(_delta: float) -> void:
	pass

## Called by the state machine upon changing the active state. The `data` parameter
## is a dictionary with arbitrary data the state can use to initialize itself.
func enter(previous_state_path: String, data := {}) -> void:
	l_hand_offset = Vector3.ZERO	# Zero out our hand offset
	
	# Set our left-hand base target
	mag_left = -cmk.gck.gun_magazine.global_basis.x	# Left, relative to gun's magazine
	mag_grip = cmk.gck.gun_magazine.mag_grip_point.global_position	# Magazine grip point, in global space
	
	l_hand_tgt = mag_grip + (mag_left * starting_hand_distance)	# Get our left hand start target
	hand_start_to_mag = mag_grip - l_hand_tgt	# Get vector from hand start to mag position
	pass

## Called by the state machine before changing the active state. Use this function
## to clean up the state.
func exit() -> void:
	_try_release_mag()
	pass


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
func _get_gun_target_transform(_delta) -> Transform3D:
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
			- (cmk.gck.gun_handling_offset_position * 0.5))
	var cam_to_gun_angle = Basis.looking_at(cam_to_gun_vec, Vector3.UP, false).get_euler()
	cmk.gck.rotation = cam_to_gun_angle
	
	return out_tf


## Snap the player's right camera hand model to the gun's marked position
## Move the player's left hand offscreen
func _cam_hand_update() -> void:
	cmk.r_hand.global_position = cmk.gck.r_hand_grip_marker.global_position
	cmk.l_hand.global_position = (l_hand_tgt) + (l_hand_offset)


## Tries to grab the magazine
func _try_grab_mag() -> void:
	# check if the magazine is grabbable
	# if no, early return
	# TODO
	var closeness_ratio := l_hand_offset.length() / hand_start_to_mag.length()
	if closeness_ratio < min_closeness_ratio:
		return
	
	# snap our hand to the magazine
	l_hand_offset = hand_start_to_mag
	cmk.l_hand.global_position = (l_hand_tgt) + (l_hand_offset)
	
	# hide the gun's real mag
	cmk.gck.gun_magazine.hide()
	
	# create a dummy mag
	dummy_mag = mag_scene.instantiate()
	dummy_mag.curr_bullets = cmk.gck.gun_magazine.curr_bullets
	cmk.l_hand.add_child(dummy_mag)
	
	# position the dummy mag
	var grab_target := cmk.gck.gun_magazine.global_position
	grab_target += cmk.pmk.velocity * get_process_delta_time()
	dummy_mag.global_position = grab_target
	dummy_mag.global_basis = cmk.gck.gun_magazine.global_basis


## Tries to drop the magazine
func _try_release_mag() -> void:
	# check if we're even holding the mag
	# if no, early return
	if dummy_mag == null:
		return
	
	# check if the mag is still within the gun
	# if so, leave it there and early return
	# TODO
	
	# check if the magazine can be dropped into inventory
	# if so, put it there and early return
	# TODO
	
	# if the mag isn't in the gun, and it isn't in our inventory...
	# fling it!!
	# TODO
	
	# temp -- just delete the dummy mag
	dummy_mag.queue_free()
	dummy_mag = null
	cmk.gck.gun_magazine.show()
