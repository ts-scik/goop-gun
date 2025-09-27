class_name GunController
extends Node3D
## Manages a player's gun animations/sounds/shooting

signal is_aiming_update(bool)

@export_category("References")
@export var cmk : CameraController

@onready var pmk : PlayerController = cmk.pmk # TODO - bad!!! bad!!!

@onready var gun_sound : AudioStreamPlayer3D = get_node("GunSound")
@onready var gun_model_holder : Node3D = get_node("GunModelHolder")
@onready var ray : RayCast3D = get_node("GunModelHolder/GunRaycast")
@onready var last_cmk_rot : Vector3 = cmk.rotation

@export_category("Animating")
@export_group("Sway")
@export var gun_sway_max : Vector3 = Vector3(deg_to_rad(3.5), deg_to_rad(5), deg_to_rad(5))
var camera_sway : Vector3 = Vector3.ZERO
@export_group("Shaking")
@export var gun_shake_angle_max : Vector3 = Vector3(deg_to_rad(4),deg_to_rad(1),deg_to_rad(1))
@export var gun_shake_time_percent : float = 0.8
var shake_angle := Vector3.ZERO
var _gun_shake_tween : Tween
@export_group("Shooting")
@export var shoot_angle_max : Vector3 = Vector3(deg_to_rad(20), deg_to_rad(1.7), deg_to_rad(2))
@export var shoot_offset_max = Vector3(0, 0.04, 0.16)
@export var gun_shoot_time : float = 0.25
@export var kick_peak_pct : float = 0.1
var _gun_shoot_tween : Tween
var current_shoot_angle : Vector3 = Vector3.ZERO
var current_shoot_offset : Vector3 = Vector3.ZERO
@export_group("Aiming")
@export var gun_hold_distance : float = 0.7 # How far gun is held out from player
@export var ads_time : float = 0.25 # ADS time (in seconds)
var ads_timer : float = 0.0 # Timer for ADS lerp
var is_aiming : bool = false # Flag for ADS completed
var last_aimed_target_pos : Vector3 = Vector3.ZERO # stores last position when aimed
var last_aimed_target_rot : Vector3 = Vector3.ZERO # stores last rotation when aimed
@export_group("Holstering")
@export var holstered_pos = Vector3(0, 1.0, -0.4) # configurable variable for where gun should go when holstered
@export var holstered_rot = Vector3(deg_to_rad(-45.0), 0.0, 0.0) # configurable variable for gun's rotation when holstered


## Updates the gun
@onready var gun_model_holder_basepos = gun_model_holder.position
func manage_positioning(delta) -> void:
	var target_transform : Transform3D
	
	# Do our standard gun position/rotation
	if(pmk.aim_held and is_aiming and !pmk.is_running):
		# Fully aimed
		target_transform = _manage_gun_aimed()
	else:
		# Fully unaimed OR in aim transition
		target_transform = _manage_gun_unaimed(delta)
	
	# snap to target tf
	if(is_aiming):
		var snapspeed = 10 # TODO - make this an export if we're keeping it
		self.rotation = lerp(self.rotation, target_transform.basis.get_euler(), delta * snapspeed)
		#self.position = lerp(self.position, target_transform.origin, delta * snapspeed)
	else:
		self.rotation = target_transform.basis.get_euler() # rotation rather than basis, so we maintain scale
	self.position = target_transform.origin
	
	# apply sway
	var sway_amount : Vector3 = _determine_sway(delta)
	
	# apply gun model effects
	gun_model_holder.rotation = Vector3.ZERO + sway_amount + shake_angle + current_shoot_angle
	gun_model_holder.position = gun_model_holder_basepos + current_shoot_offset


## Returns how far into ads we are, from (0.0, 1.0)
func ads_ratio() -> float:
	return ads_timer/ads_time


## Animates gun in/out of aiming position
func _manage_gun_unaimed(delta) -> Transform3D:
	# get target pos/rot
	var player_interp := pmk.get_global_transform_interpolated()
	var unaimed_target_pos : Vector3 = cmk.to_local(
		player_interp.origin + # player origin
		(player_interp.basis * holstered_pos) + # holstered position (relative to player
		cmk.bob_vec # camera viewbob # TODO kinda hate that we have to do this
	)
	var unaimed_target_rot : Vector3 = holstered_rot - Vector3(cmk.rotation.x,0,0)
	var aim_held : bool = pmk.aim_held
	
	# cap our max aim amount if the player is running
	var max_aim_amt : float = ads_time
	if(pmk.is_running):
		max_aim_amt = ads_time * 0.4 # TODO pct export
	
	# Starting an aim
	if(aim_held and ads_timer <= max_aim_amt):
		# update the aim timer
		ads_timer = min(ads_timer + delta, max_aim_amt)
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
func _determine_sway(delta) -> Vector3:
	# store post-update, pre-sway basis
	var cmk_rot := cmk.rotation
	var rot_change : Vector3 = Vector3.ZERO
	
	# Rotation change -- only calculated if not holstered
	if(is_aiming or pmk.aim_held or ads_timer > 0.0):
		rot_change = cmk_rot - last_cmk_rot
	
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
	last_cmk_rot = cmk_rot

	return camera_sway * gun_sway_max


## Shoots
@rpc("authority","call_local","unreliable")
func shoot() -> void:
	# handle raycast
	ray.shoot()
	# handle sound
	gun_sound.play()
	# handle anim
	start_gun_shoot_anim()


## Returns 0.0 -> 1.0 value for how long is left in our shooting animation
## Value of [1.0] means that we're not currently in a shooting animation
func shoot_time_remaining() -> float:
	if(!_gun_shoot_tween or !_gun_shoot_tween.is_running()):
		return 1.0
	return clampf(_gun_shoot_tween.get_total_elapsed_time() / gun_shoot_time, 0.0, 1.0)


## Starts gun shoot animation
func start_gun_shoot_anim() -> void:
	if _gun_shoot_tween:
		_gun_shoot_tween.kill()
		
	_gun_shoot_tween = create_tween()
	_gun_shoot_tween.tween_method(_update_gun_shoot, 0.0, 1.0, gun_shoot_time).set_ease(Tween.EASE_OUT)


## Handles gun shoot animation
func _update_gun_shoot(alpha : float) -> void:
	var wght : float
	if(alpha < kick_peak_pct):
		wght = alpha / kick_peak_pct
	else:
		wght = 1 - ((alpha - kick_peak_pct) / (1 - kick_peak_pct))
	
	# variables that peak at kick_peak_pct, then linearly taper
	current_shoot_offset.z = wght * shoot_offset_max.z
	current_shoot_offset.y = wght * shoot_offset_max.y
	current_shoot_angle.x = lerpf(0, shoot_angle_max.x, wght)
	# variables that follow a sin wave of frequency 2
	var amt = (sin(alpha * TAU * 2))
	current_shoot_angle.y = amt * shoot_angle_max.y * (1-alpha)
	current_shoot_angle.z = amt * shoot_angle_max.z * (1-alpha)


## Starts end-of-footstep gun shake
func start_gun_shake(footstep_time_length : float) -> void:
	if _gun_shake_tween:
		_gun_shake_tween.kill()
	
	var gun_shake_time_length = footstep_time_length * gun_shake_time_percent
	
	var random_shake := Vector3.ZERO
	for idx in 3:
		# TODO make the 0.25 exportable
		random_shake[idx] = randf_range(gun_shake_angle_max[idx] * 0.25, gun_shake_angle_max[idx])
		
	_gun_shake_tween = create_tween()
	_gun_shake_tween.tween_method(_update_gun_shake.bind(random_shake), 0.0, 1.0, gun_shake_time_length).set_ease(Tween.EASE_OUT)


## Handles end-of-footstep gun shake
func _update_gun_shake(alpha: float, random_shake: Vector3) -> void:
	var shake_frequency = 5 * (1-alpha) # TODO make this export effected
	var amt = sin(alpha * shake_frequency * TAU) * (1 - alpha)
	
	shake_angle = random_shake * amt
