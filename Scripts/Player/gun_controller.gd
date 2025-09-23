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

# Aiming timer/flag
var is_aiming : bool = false # Flag for ADS completed
var ads_time : float = 0.25 # ADS time (in seconds)
var ads_timer : float = 0.0 # Timer for ADS lerp
# Aiming position variables
var last_aimed_target_pos : Vector3 = Vector3.ZERO # stores last position when aimed
var last_aimed_target_rot : Vector3 = Vector3.ZERO # stores last rotation when aimed
var holstered_pos = Vector3(0, 1.0, -0.5) # configurable variable for where gun should go when holstered
var holstered_rot = Vector3(deg_to_rad(-45.0), 0.0, 0.0) # configurable variable for gun's rotation when holstered
var gun_hold_distance : float = 0.75 # How far gun is held out from player


## Updates the gun
func manage_positioning(delta) -> void:
	if(player_controller.aim_held and is_aiming): #if we're aiming, move+rotate the gun
		_update_gun_local_space()
	else: # manage aim/de-aim/unaimed states
		_manage_aiming(delta)


## Animates gun in/out of aiming position
func _manage_aiming(delta) -> void:
	# get target pos/rot
	var player_interp := player_controller.get_global_transform_interpolated()
	#var player_interp = player_controller.global_transform # TODO -- why does this get weird??
	var unaimed_target_pos : Vector3 = camera_controller.to_local(player_interp.origin + (player_interp.basis * holstered_pos))
	var unaimed_target_rot : Vector3 = holstered_rot - Vector3(camera_controller.rotation.x,0,0)
	var aim_held : bool = player_controller.aim_held
	
	# If we're in an aim transition,
	if(aim_held or ads_timer > 0.0):
		# If we're trying to aim
		if(aim_held):
			ads_timer += delta # update the aim timer
			if(ads_timer/ads_time >= 1.0): # if we're there, update the aim variable
				ads_timer = ads_time
				is_aiming = true
				is_aiming_update.emit(is_aiming)
			last_aimed_target_pos = Vector3(0,0,-gun_hold_distance)
			last_aimed_target_rot = Vector3.ZERO
		# If we're trying to de-aim
		elif(!aim_held):
			ads_timer = clampf(ads_timer, 0.0, ads_timer-delta) # update the aim timer
			if(is_aiming): # update is_aiming, last_aimed stuff
				is_aiming = false
				is_aiming_update.emit(is_aiming)
				last_aimed_target_pos = position
				last_aimed_target_rot = rotation
				
		position = lerp(unaimed_target_pos, last_aimed_target_pos, ads_timer/ads_time)
		rotation = lerp(unaimed_target_rot, last_aimed_target_rot, ads_timer/ads_time)
	else:
		position = unaimed_target_pos
		rotation = unaimed_target_rot


## Updates the gun's position+rotation (for if gun exists in local space)
func _update_gun_local_space():
	# Update the gun's position
	position = camera_controller.to_local(camera_controller.player_camera.project_position(camera_controller.mouse_position,gun_hold_distance))
	# Update the gun's rotation (relative to camera)
	var fw_dir = camera_controller.to_local(global_position) - camera_controller.to_local(camera_controller.player_camera.global_position) # vector from player camera to gun_controller
	basis = Basis.looking_at(fw_dir, Vector3.UP, false)


## Shoots
@rpc("authority","call_local","unreliable")
func shoot():
	# handle raycast
	ray.shoot()
	# handle sound
	gun_sound.play()
	# handle animation
	anim_player.stop()
	anim_player.play("shoot")


## Handles animations
#TODO: i hate this
func handle_movement_anim(direction : Vector3):
	if(direction.x != 0 or direction.z != 0):
		anim_tree.set("parameters/conditions/stopped", false)
		anim_tree.set("parameters/conditions/walking", true)
	else:
		anim_tree.set("parameters/conditions/walking", false)
		anim_tree.set("parameters/conditions/stopped", true)
