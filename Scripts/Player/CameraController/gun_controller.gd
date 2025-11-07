class_name GunController
extends Node3D
## Manages a player's gun animations/sounds/shooting

@export_category("Animating")
@export_group("Sway")
@export var gun_sway_max := Vector3(deg_to_rad(3.5), deg_to_rad(5), deg_to_rad(5))	# max angle of gun sway
var camera_sway := Vector3.ZERO	# stores current camera sway vector

@export_group("Shaking")
@export var gun_shake_angle_max := Vector3(deg_to_rad(4),deg_to_rad(1),deg_to_rad(1)) # max angle of gun shake
@export var footstep_gun_shake_time_pct : float = 0.8	# what % of foostep time gun should shake for
@export var min_shake_angle_pct : float = 0.3	# minimum % of gun_shake_angle_max
var shake_angle := Vector3.ZERO	# stores current camera shake angle
var _gun_shake_tween : Tween

@export_group("Shooting")
@export var shoot_angle_max := Vector3(deg_to_rad(20), deg_to_rad(1.7), deg_to_rad(2))	# max angle offset when shooting
@export var shoot_offset_max := Vector3(0, 0.04, 0.16)	# max position offset when shooting
@export var gun_shoot_time : float = 0.25	# time gun shoot animation plays
@export var reshoot_cutoff : float = 0.75	# min seconds between shots
@export var kick_peak_pct : float = 0.1		# at what % of gun_shoot_time we hit peak kick
var _gun_shoot_tween : Tween
var current_shoot_angle := Vector3.ZERO
var current_shoot_offset := Vector3.ZERO

@export_group("Aiming")
@export var gun_hold_distance : float = 0.7	# How far gun is held out from player
var last_aimed_target_pos := Vector3.ZERO	# stores last position when aimed
var last_aimed_target_rot := Vector3.ZERO	# stores last rotation when aimed

@export_group("Holstering")
@export var holstered_pos = Vector3(0, 1.0, -0.4) # configurable variable for where gun should go when holstered
@export var holstered_rot = Vector3(deg_to_rad(-45.0), 0.0, 0.0) # configurable variable for gun's rotation when holstered

@export_group("Handling")
@export var gun_handling_origin_position := Vector3(0.0, 1.2, -0.4)	# position camera targets when handling
@export var gun_handling_offset_position := Vector3(0.17, 0.038, 0)	# gun offset rel to handling_origin when handling

@export_group("Reloading")
@export var gun_reload_rotation := Vector3(deg_to_rad(0), deg_to_rad(0), deg_to_rad(0))	# target rotation in reloading state

@onready var gun_sound : AudioStreamPlayer3D = get_node("GunSound")
@onready var click_sound : AudioStreamPlayer3D = get_node("ClickSound")
@onready var gun_model_holder : Node3D = get_node("GunModelHolder")
@onready var ray : RayCast3D = get_node("GunModelHolder/GunRaycast")
@onready var gun_magazine : MagazineController = get_node("GunModelHolder/MagazineController")
@onready var l_hand_grip_marker : Marker3D = get_node("GunModelHolder/GripMarkers/LHandMarker")
@onready var r_hand_grip_marker : Marker3D = get_node("GunModelHolder/GripMarkers/RHandMarker")

# Parent nodes
var cmk : CameraController # Node for camera that this gun inherits from
var pmk : PlayerController # Node that the camera will follow - grabbed in _ready()

# Holders for animation transforms
var gun_model_holder_basepos : Vector3


## Find our owners
func _ready() -> void:
	# Find our PlayerController owner
	await owner.ready
	cmk = owner as CameraController
	assert(cmk != null, "The GunController node requires CameraControllernode as owner.")
	pmk = cmk.pmk # is this bad?
	assert(pmk != null, "The GunController node requires CameraController owner w/ PlayerController owner.")
	
	# Store transform variables
	gun_model_holder_basepos = gun_model_holder.position


## Updates the gun's model_holder child
## All the effects are processed elsewhere in Tweens, but we apply them here
func _process(_delta) -> void:
	# apply sway
	var sway_amount : Vector3 = camera_sway * gun_sway_max
	
	# apply gun model effects -- rotation
	gun_model_holder.rotation = (
			Vector3.ZERO + sway_amount + shake_angle + current_shoot_angle)
	# apply gun model effects -- position
	gun_model_holder.position = (
			gun_model_holder_basepos + current_shoot_offset)


## Checks whether or not gun has ammo
## Returns [true] if yes, [false] if no
func has_ammo() -> bool:
	# no mag/empty mag
	if (gun_magazine == null or gun_magazine.has_ammo() == false):
		return false
	else:
		return true


## Checks whether or not gun can shoot again
## Returns [true] if yes, [false] if no
func can_shoot_again() -> bool:
	return (shoot_time_remaining() >= reshoot_cutoff)


## Shoots
func shoot() -> void:
	# handle ammo
	gun_magazine.remove_bullet()
	# handle raycast
	ray.shoot()
	# handle sound
	gun_sound.play()
	# handle anim
	start_gun_shoot_anim()


## For when you try to shoot on an empty mag
func shoot_fail() -> void:
	# handle sound
	click_sound.play()
	# handle anim
	start_gun_shoot_anim(0.05)


## Returns 0.0 -> 1.0 value for how long is left in our shooting animation
## Value of [1.0] means that we're not currently in a shooting animation
func shoot_time_remaining() -> float:
	if(!_gun_shoot_tween or !_gun_shoot_tween.is_running()):
		return 1.0
	return clampf(_gun_shoot_tween.get_total_elapsed_time() / gun_shoot_time, 0.0, 1.0)


## Starts gun shoot animation
func start_gun_shoot_anim(amount : float = 1.0) -> void:
	# if shoot tween running, kill it
	if _gun_shoot_tween:
		_gun_shoot_tween.kill()
	
	# start new shoot tween
	_gun_shoot_tween = create_tween()
	_gun_shoot_tween.tween_method(
		_update_gun_shoot.bind(amount),
		0.0, 1.0,
		gun_shoot_time
	).set_ease(Tween.EASE_OUT)


## [Tween method] - Handles gun shoot animation
func _update_gun_shoot(alpha : float, amount : float = 1.0) -> void:
	# wght is used for variables that peak at kick_peak_pct
	# before peak - wght maps (0.0, kick_peak_pct) -> (0.0, 1.0)
	# after peak  - wght maps (kick_peak_pct, 1.0) -> (1.0, 0.0)
	var wght : float
	if(alpha < kick_peak_pct):
		wght = alpha / kick_peak_pct
	else:
		wght = 1 - ((alpha - kick_peak_pct) / (1 - kick_peak_pct))
	
	# variables that peak at kick_peak_pct, then linearly taper
	current_shoot_offset.z = wght * shoot_offset_max.z * amount	# kick-back
	current_shoot_offset.y = wght * shoot_offset_max.y * amount	# kick-up
	current_shoot_angle.x = lerpf(0, shoot_angle_max.x * amount, wght)	# kick pitch
	# variables that follow a sin wave of frequency 2
	var wav = (sin(alpha * TAU * 2))
	current_shoot_angle.y = wav * shoot_angle_max.y * amount  * (1-alpha)	# kick yaw
	current_shoot_angle.z = wav * shoot_angle_max.z * amount  * (1-alpha)	# kick roll


## Starts end-of-footstep gun shake
## [shake_len] -> how long shake should occur
## [shake_amt] -> how aggressive the shakes should be
## [shak_freq] -> how many full shakes should complete within [shake_time_len]
func start_gun_shake(shake_len: float, shake_amt: float = 1.0, shake_freq: float = 4.0) -> void:
	# kill the shake tween, if running
	if _gun_shake_tween:
		_gun_shake_tween.kill()
	
	# get our randomized shake vector
	var random_shake := Vector3.ZERO
	for idx in 3:
		var rand_sign = scik_utils.rand_sign()
		random_shake[idx] = randf_range(
				gun_shake_angle_max[idx] * min_shake_angle_pct,
				gun_shake_angle_max[idx]
			) * rand_sign
	
	# start the new shake tween
	_gun_shake_tween = create_tween()
	_gun_shake_tween.tween_method(
		_update_gun_shake.bind(random_shake, shake_amt, shake_freq),
		0.0, 1.0,
		shake_len
	).set_ease(Tween.EASE_OUT)


## [Tween method] - Handles end-of-footstep gun shake
func _update_gun_shake(alpha: float, r_shake_angle: Vector3, shake_amt: float, shake_freq: float) -> void:
	var c_amt = sin(alpha * shake_freq * TAU) * (1 - alpha) * shake_amt
	shake_angle = r_shake_angle * c_amt
