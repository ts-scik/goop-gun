## Manages a player's gun animations/sounds/shooting
class_name GunController
extends Node3D

# Parent nodes
var cmk : CameraController # Node for camera that this gun inherits from
var pmk : PlayerController # Node that the camera will follow - grabbed in _ready()

# Holders for animation transforms
var gun_model_holder_basepos
var last_cmk_rot : Vector3 # grab this in _ready()

@onready var gun_sound : AudioStreamPlayer3D = get_node("GunSound")
@onready var gun_model_holder : Node3D = get_node("GunModelHolder")
@onready var ray : RayCast3D = get_node("GunModelHolder/GunRaycast")

@export_category("Animating")
@export_group("Sway")
@export var gun_sway_max : Vector3 = Vector3(deg_to_rad(3.5), deg_to_rad(5), deg_to_rad(5))
var camera_sway : Vector3 = Vector3.ZERO
@export_group("Shaking")
@export var gun_shake_angle_max : Vector3 = Vector3(deg_to_rad(4),deg_to_rad(1),deg_to_rad(1))
@export var gun_shake_time_percent : float = 0.8 # what % of foostep time gun should shake for
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
var last_aimed_target_pos : Vector3 = Vector3.ZERO # stores last position when aimed
var last_aimed_target_rot : Vector3 = Vector3.ZERO # stores last rotation when aimed
@export_group("Holstering")
@export var holstered_pos = Vector3(0, 1.0, -0.4) # configurable variable for where gun should go when holstered
@export var holstered_rot = Vector3(deg_to_rad(-45.0), 0.0, 0.0) # configurable variable for gun's rotation when holstered


## Find our owners
func _ready() -> void:
	# Find our PlayerController owner
	await owner.ready
	cmk = owner as CameraController
	assert(cmk != null, "The GunController node requires a CameraController node as owner.")
	pmk = cmk.pmk # is this bad?
	assert(pmk != null, "The GunController node must be child of a CameraController with PlayerController as owner.")
	
	# Store transform variables
	last_cmk_rot = cmk.rotation
	gun_model_holder_basepos = gun_model_holder.position


## Updates the gun's model_holder child
func _process(_delta) -> void:
	# apply sway
	var sway_amount : Vector3 = camera_sway * gun_sway_max
	
	# apply gun model effects
	gun_model_holder.rotation = Vector3.ZERO + sway_amount + shake_angle + current_shoot_angle
	gun_model_holder.position = gun_model_holder_basepos + current_shoot_offset


## Shoots
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


## [Tween method] - Handles gun shoot animation
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
# TODO - should make this just take a time, so it's not specifically for footsteps
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


## [Tween method] - Handles end-of-footstep gun shake
func _update_gun_shake(alpha: float, random_shake: Vector3) -> void:
	var shake_frequency = 5 * (1-alpha) # TODO make this export effected
	var amt = sin(alpha * shake_frequency * TAU) * (1 - alpha)
	
	shake_angle = random_shake * amt
