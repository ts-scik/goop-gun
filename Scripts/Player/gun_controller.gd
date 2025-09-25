class_name GunController
extends Node3D
## Manages a player's gun animations/sounds/shooting

signal is_aiming_update(bool)

@export_category("References")
@export var camera_controller : CameraController

@onready var player_controller : PlayerController = camera_controller.player_controller # bad??
@onready var anim_tree : AnimationTree = get_node("GunAnimationTree")
@onready var anim_player : AnimationPlayer = get_node("GunAnimator")
@onready var gun_sound : AudioStreamPlayer3D = get_node("GunSound")
@onready var ray : RayCast3D = get_node("GunRaycast")
@onready var last_cc_rot : Vector3 = self.global_rotation

@export_category("Animating")
@export var gun_sway_max : Vector3 = Vector3(deg_to_rad(3.5), deg_to_rad(5), deg_to_rad(5))
@export_category("Aiming")
@export var gun_hold_distance : float = 0.75 # How far gun is held out from player
@export var ads_time : float = 0.25 # ADS time (in seconds)
var ads_timer : float = 0.0 # Timer for ADS lerp
var is_aiming : bool = false # Flag for ADS completed
# Aiming position variables
var last_aimed_target_pos : Vector3 = Vector3.ZERO # stores last position when aimed
var last_aimed_target_rot : Vector3 = Vector3.ZERO # stores last rotation when aimed
@export_category("Holstering")
@export var holstered_pos = Vector3(0, 1.0, -0.5) # configurable variable for where gun should go when holstered
@export var holstered_rot = Vector3(deg_to_rad(-45.0), 0.0, 0.0) # configurable variable for gun's rotation when holstered


## Updates the gun
func manage_positioning(delta) -> void:
	var target_transform : Transform3D
	
	# Do our standard gun position/rotation
	if(player_controller.aim_held and is_aiming):
		# Fully aimed
		target_transform = _manage_gun_aimed()
	else:
		# Fully unaimed OR in aim transition
		target_transform = _manage_gun_unaimed(delta)
	var target_position := target_transform.origin
	var target_rotation := target_transform.basis.get_euler()
	
	self.position = target_position
	self.rotation = target_rotation
	
	# apply sway -- needs to be AFTER we do everything else
	var sway_amount : Vector3 = _determine_sway(delta)
	self.rotation += sway_amount


## Returns how far into ads we are, from (0.0, 1.0)
func ads_ratio() -> float:
	return ads_timer/ads_time


## Animates gun in/out of aiming position
func _manage_gun_unaimed(delta) -> Transform3D:
	# get target pos/rot
	var player_interp := player_controller.get_global_transform_interpolated()
	#var player_interp = player_controller.global_transform # TODO -- why does this get weird??
	var unaimed_target_pos : Vector3 = camera_controller.to_local(player_interp.origin + (player_interp.basis * holstered_pos))
	var unaimed_target_rot : Vector3 = holstered_rot - Vector3(camera_controller.rotation.x,0,0)
	var aim_held : bool = player_controller.aim_held
	
	# Starting an aim
	if(aim_held):
		ads_timer = min(ads_timer + delta, 1.0) # update the aim timer
		if(ads_ratio() >= 1.0): # if we're there, update the aim variable
			ads_timer = ads_time
			is_aiming = true
			is_aiming_update.emit(is_aiming)
		last_aimed_target_pos = Vector3(0,0,-gun_hold_distance)
		last_aimed_target_rot = Vector3.ZERO
	# Ending an aim
	elif(ads_timer > 0.0):
		ads_timer = max(ads_timer - delta, 0.0) # update the aim timer
		if(is_aiming): # update is_aiming, last_aimed stuff
			is_aiming = false
			is_aiming_update.emit(is_aiming)
			last_aimed_target_pos = position
			last_aimed_target_rot = rotation
	
	# Aim transition lerp
	var out_tf : Transform3D
	if(ads_timer > 0.0):
		out_tf.origin = lerp(unaimed_target_pos, last_aimed_target_pos, ads_ratio())
		out_tf.basis = Basis.from_euler(lerp(unaimed_target_rot, last_aimed_target_rot, ads_ratio()))
	# Not aiming
	else:
		out_tf.origin = unaimed_target_pos
		out_tf.basis = Basis.from_euler(unaimed_target_rot)
	return out_tf


## Updates the gun's position+rotation (for if gun exists in local space)
func _manage_gun_aimed() -> Transform3D:
	var out_tf : Transform3D
	# Get vector from player camera to gun_controller
	var fw_dir = camera_controller.to_local(global_position) - camera_controller.to_local(camera_controller.player_camera.global_position) 
	# Update the gun's position
	out_tf.origin = camera_controller.to_local(camera_controller.player_camera.project_position(camera_controller.mouse_position,gun_hold_distance))
	# Update the gun's rotation (relative to camera)
	out_tf.basis = Basis.looking_at(fw_dir, Vector3.UP, false)
	return out_tf


## Returns Vector3 angle for how much gun should sway, given camera velocity
var camera_sway : Vector3 = Vector3.ZERO
func _determine_sway(delta) -> Vector3:
	
	# store post-update, pre-sway basis
	var cc_rot := camera_controller.rotation
	var rot_change : Vector3 = Vector3.ZERO
	
	# Rotation change -- only calculated if not holstered
	if(is_aiming or player_controller.aim_held or ads_timer > 0.0):
		rot_change = cc_rot - last_cc_rot
	
		# Keep rot_change inbounds
		for idx in 3:
			if(abs(rot_change[idx]) > PI):
				rot_change[idx] -= TAU * sign(rot_change[idx])
	
		rot_change.z = rot_change.y # TODO - are you sure?
	
	# Apply rot_change to camera_sway
	var CHANGESCALE = 1
	camera_sway += (rot_change * CHANGESCALE)
	camera_sway.clampf(-1.0, 1.0)
	
	# Recenter
	var RECENTER = 7
	camera_sway = lerp(camera_sway, Vector3.ZERO, delta*RECENTER)

	# Store this frame's pre-sway basis for next frame
	last_cc_rot = cc_rot

	return camera_sway * gun_sway_max


## Shoots
@rpc("authority","call_local","unreliable")
func shoot() -> void:
	# handle raycast
	ray.shoot()
	# handle sound
	gun_sound.play()
	# handle animation
	anim_player.stop()
	anim_player.play("shoot")


## Handles animations
#TODO: i hate this
func handle_movement_anim(direction : Vector3) -> void:
	return # TODO - temp early return
