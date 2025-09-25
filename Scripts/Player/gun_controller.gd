class_name GunController
extends Node3D
## Manages a player's gun animations/sounds/shooting

signal is_aiming_update(bool)

@export_category("References")
@export var cmk : CameraController

@onready var pmk : PlayerController = cmk.pmk # TODO - bad!!! bad!!!

@onready var gun_sound : AudioStreamPlayer3D = get_node("GunSound")
@onready var gun_model : Node3D = get_node("GunModelHolder")
@onready var ray : RayCast3D = get_node("GunModelHolder/GunRaycast")
@onready var last_cc_rot : Vector3 = cmk.rotation

@export_category("Animating")
@export_group("Sway")
@export var gun_sway_max : Vector3 = Vector3(deg_to_rad(3.5), deg_to_rad(5), deg_to_rad(5))
@export_group("Shaking")
@export var gun_shake_angle_max : Vector3 = Vector3(deg_to_rad(5),deg_to_rad(5),deg_to_rad(5))
@export var gun_shake_time_percent : float = 0.8
var gun_shake_stored : Vector3 = Vector3.ZERO
var _gun_shake_tween : Tween
@export_group("Shooting")
@export var shoot_angle_max : Vector3 = Vector3(deg_to_rad(10), 0, 0)
@export var gun_shoot_time : float = 0.25
var _gun_shoot_tween : Tween

@export_category("Aiming")
@export var gun_hold_distance : float = 0.7 # How far gun is held out from player
@export var ads_time : float = 0.25 # ADS time (in seconds)
var ads_timer : float = 0.0 # Timer for ADS lerp
var is_aiming : bool = false # Flag for ADS completed
# Aiming position variables
var last_aimed_target_pos : Vector3 = Vector3.ZERO # stores last position when aimed
var last_aimed_target_rot : Vector3 = Vector3.ZERO # stores last rotation when aimed
@export_category("Holstering")
@export var holstered_pos = Vector3(0, 1.0, -0.4) # configurable variable for where gun should go when holstered
@export var holstered_rot = Vector3(deg_to_rad(-45.0), 0.0, 0.0) # configurable variable for gun's rotation when holstered


## Updates the gun
func manage_positioning(delta) -> void:
	var target_transform : Transform3D
	
	# Do our standard gun position/rotation
	if(pmk.aim_held and is_aiming):
		# Fully aimed
		target_transform = _manage_gun_aimed()
	else:
		# Fully unaimed OR in aim transition
		target_transform = _manage_gun_unaimed(delta)
		
	self.position = target_transform.origin
	self.rotation = target_transform.basis.get_euler() # rotation rather than basis, so we maintain scale
	
	# apply sway
	var sway_amount : Vector3 = _determine_sway(delta)
	# do shake
	var shake_amount : Vector3 = _determine_shake()
	# do shoot anim
	var shoot_amount : Vector3 = _determine_shooting()
	
	# apply gun model effects
	gun_model.rotation = Vector3.ZERO + sway_amount + shake_amount + shoot_amount


## Returns how far into ads we are, from (0.0, 1.0)
func ads_ratio() -> float:
	return ads_timer/ads_time


## Animates gun in/out of aiming position
func _manage_gun_unaimed(delta) -> Transform3D:
	# get target pos/rot
	var player_interp := pmk.get_global_transform_interpolated()
	#var player_interp = pmk.global_transform # TODO -- why does this get weird??
	var unaimed_target_pos : Vector3 = cmk.to_local(player_interp.origin + (player_interp.basis * holstered_pos))
	var unaimed_target_rot : Vector3 = holstered_rot - Vector3(cmk.rotation.x,0,0)
	var aim_held : bool = pmk.aim_held
	
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
	var fw_dir = cmk.to_local(global_position) - cmk.to_local(cmk.player_camera.global_position) 
	# Update the gun's position
	out_tf.origin = cmk.to_local(cmk.player_camera.project_position(cmk.mouse_position,gun_hold_distance))
	# Update the gun's rotation (relative to camera)
	out_tf.basis = Basis.looking_at(fw_dir, Vector3.UP, false)
	return out_tf


## Returns Vector3 angle for how much gun should sway, given camera velocity
var camera_sway : Vector3 = Vector3.ZERO
func _determine_sway(delta) -> Vector3:
	# store post-update, pre-sway basis
	var cc_rot := cmk.rotation
	var rot_change : Vector3 = Vector3.ZERO
	
	# Rotation change -- only calculated if not holstered
	if(is_aiming or pmk.aim_held or ads_timer > 0.0):
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


## Handles gun shake animation
func _determine_shake() -> Vector3:
	if(v_offset == 0 and h_offset == 0): return Vector3.ZERO
	return Vector3(v_offset, h_offset, 0)


func _determine_shooting() -> Vector3:
	return current_shoot_angle


## Shoots
@rpc("authority","call_local","unreliable")
func shoot() -> void:
	# handle raycast
	ray.shoot()
	# handle sound
	gun_sound.play()
	# handle anim
	start_gun_shoot_tilt()


## Starts gun shoot animation
func start_gun_shoot_tilt() -> void:
	if _gun_shoot_tween:
		_gun_shoot_tween.kill()
		
	_gun_shoot_tween = create_tween()
	_gun_shoot_tween.tween_method(update_gun_shoot, 0.0, 1.0, gun_shoot_time).set_ease(Tween.EASE_OUT)


## Handles gun shoot animation
var current_shoot_angle : Vector3 = Vector3.ZERO
func update_gun_shoot(alpha : float) -> void:
	current_shoot_angle = lerp(shoot_angle_max, Vector3.ZERO, alpha)


## Starts end-of-footstep gun shake
func start_gun_shake(footstep_time_length : float) -> void:
	var gun_shake_time_length = footstep_time_length * gun_shake_time_percent
	
	if _gun_shake_tween:
		_gun_shake_tween.kill()
	
	var amount = 0.5
	_gun_shake_tween = create_tween()
	_gun_shake_tween.tween_method(update_gun_shake.bind(amount), 0.0, 1.0, gun_shake_time_length).set_ease(Tween.EASE_OUT)


## Handles end-of-footstep gun shake
var h_offset : float = 0.0
var v_offset : float = 0.0
func update_gun_shake(alpha: float, amount: float) -> void:
	var MIN_GUN_SHAKE = 0.01
	var MAX_GUN_SHAKE = 0.05
	
	amount = remap(amount, 0.0, 1.0 , MIN_GUN_SHAKE, MAX_GUN_SHAKE)
	
	var current_shake_amount = amount * (1.0 - alpha)
	h_offset = randf_range(-current_shake_amount, current_shake_amount)
	v_offset = randf_range(-current_shake_amount, current_shake_amount)
