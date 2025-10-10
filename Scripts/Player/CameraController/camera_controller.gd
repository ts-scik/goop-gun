## Manages all player camera input / aiming
class_name CameraController
extends Node3D

# Written using the following godot documentation:
# https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/advanced_physics_interpolation.html

# Parent node
var pmk : PlayerController # Node that the camera will follow - grabbed in ready()

# Child nodes
var player_camera : Camera3D # Player camera
var gck : GunController # Gun's container

@export_category("Effects")
@export_group("Run Tilt")
@export var enable_tilt : bool = false	# Whether camera tilt angle is enabled
@export var run_pitch : float = 0.1	# Euler degrees
@export var run_roll : float = 0.25	# Euler degrees
@export var max_pitch : float = 1.0	# Euler degrees
@export var max_roll : float = 2.5	# Euler degrees
@export_group("Gun Kick")
@export var kick_amount := Vector2(0.025,0.05) # Cursor's x/y screen kick amount
@export_group("Camera Shake")
@export var camera_shake_enabled = true	# Whether camera x/y shake is enabled
@export var camera_roll_enabled = true	# Whether camera roll shake is enabled
var _camera_shake_tween : Tween			# Tween for camera shake
var _camera_shake_angle := Vector2.ZERO	# Holder for camera shake
@export_group("Aim FOV")
@export var enable_aim_zoom : bool = true		# Whether camera FOV changes while aiming
@export var aimed_fov_percent : float = 0.875	# % of fov when fully aimed in
@export_group("Handling / Reloading FOV")
@export var handling_fov_percent : float = 0.8	# % of fov when fully in reload state
@export var reload_fov_percent : float = 0.6	# % of fov when fully in handling state
@export_group("Viewbob")
@export var enable_viewbob : bool = true	# Whether viewbob is enabled
@export var viewbob_curve : Curve			# Configurable curve for viewbob
@export var max_bob_height : float = 0.06	# Point where viewbob curve peaks
var bob_vec : Vector3 = Vector3.ZERO		# Holder for viewbob offset vector

@export_category("Interactions")
@export_group("Shooting")
var recent_gamepad_shoot : bool = false		# flag for if we've recently pulled RT
@export_group("Aiming")
@export var ads_time : float = 0.25	# ADS time (in seconds)
var ads_timer : float = 0.0		# Timer for ADS lerp
var is_aiming : bool = false	# Flag for ADS completed
var aim_held : bool = false		# Flag for ADS input
var aim_toggle : bool = false	# Whether or not we're using toggle-aim
var recent_gamepad_aim : bool = false	# flag for if we've recently pulled LT
@export_group("Reloading")
@export var reload_entry_time : float = 0.5	# Time to enter reload state (in seconds)
var reload_timer : float = 0.0	# Timer for reload lerp
var want_handling : bool = false # Whether we want to be handling the gun
@export_group("Mouse Deadzone")
@export var mouse_deadzone : Vector3 = Vector3(0.1, 0.65, 0.35) # Mouse deadzone (in screen %) (x, yTop, yBottom)

@export_category("Player Configurables")
@export var desired_fov : float = 75.0 		# Player default FOV (TODO - add player setting)
@export var mouse_sensitivity : float = 0.005 	# Mouse overall sensitivitiy
@export var camera_sensitivity : float = 0.5 	# Mouse camera sensitivity
@export var aim_sensitivity : float = 0.1 		# Mouse aim sensitivity
@export var gamepad_sense_scale : float = 15 	# Gamepad sensitivity multiplier

@onready var l_hand : MeshInstance3D = get_node("Hands/LHand")
@onready var r_hand : MeshInstance3D = get_node("Hands/RHand")

# Mouse input variables
var mouse_input : Vector2		# Stores mouse input (1gets reset each frame!)
var input_rotation : Vector3 	# Stores mouse_input converted to rotation - for cam
var gun_input_rotation : Vector3 # Stores mouse_input converted to rotation - for gun
# Gun deadzone variables
var mouse_position := Vector2.ZERO	# Mouse cursor's position onscreen
var screen_size : Vector2	# Size of screen (in pixels)
var gun_deadzone : Vector3	# Gun's deadzone size (in pixels)
var last_cmk_rot : Vector3	# Camera's rotation last frame
# Debug stuff
var guncanvas : GunCanvas 	# Node for mouse_position debug display
var debug_dot :bool = false	# Flag for if we want to show the red_dot
var debug_box :bool = false	# Flag for if we want to show the boundary_rect


## Get our camera
func _ready() -> void:
	# Find our PlayerController owner
	#await owner.ready
	pmk = owner as PlayerController
	assert(pmk != null, "The CameraController node requires PlayerController as owner.")
	
	# Handle independent camera setup
	set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_OFF)
	top_level = true
	
	# Find target child nodes
	gck = get_node("GunController")
	player_camera = get_node("PlayerCamera")
	guncanvas = get_node("GunCanvas")
	
	# Set camera up
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player_camera.current = true
	
	# Store transform variables
	last_cmk_rot = self.rotation
	
	# Update all our screen-size-related variables
	_viewport_update()


## Returns how far into ads we are, from (0.0, 1.0)
func ads_ratio() -> float:
	return ads_timer/ads_time


## Returns offset transform based on camera effects
func _get_cam_effects_transform() -> Transform3D:
	var velocity = pmk.velocity
	var pos = Vector3.ZERO
	var angles = Vector3.ZERO
	
	# Camera Tilt
	# TODO - can we get rid of this??
	if enable_tilt:
		var forward = -global_transform.basis.z
		var right = global_transform.basis.x
		
		var forward_dot = velocity.dot(forward)
		var forward_tilt = clampf(forward_dot * deg_to_rad(run_pitch), deg_to_rad(-max_pitch), deg_to_rad(max_pitch))
		
		var right_dot = velocity.dot(right)
		var side_tilt = clampf(right_dot * deg_to_rad(run_roll), deg_to_rad(-max_roll), deg_to_rad(max_roll))
		
		angles.x -= forward_tilt
		angles.z -= side_tilt
	
	# Viewbob
	if enable_viewbob:
		# get 0.0 - 1.0 float for how far into footstep we are
		var foot_time_ratio : float = pmk.footstep_timer/pmk.footstep_time_length
		var bob_amount : float
		bob_amount = viewbob_curve.sample_baked(foot_time_ratio)
		bob_vec = Vector3(0, max_bob_height * bob_amount, 0)
		pos.y += bob_vec.y
	
	var out_tf : Transform3D
	out_tf.origin = pos
	out_tf.basis = Basis.from_euler(angles)
	return out_tf


## Handles camera shake + kickback after gunshot
func camera_gun_kick():
	# Early return if we're not aiming (how would we even shoot?)
	if !is_aiming:
		return
	
	# Handle mouse kick
	# TODO - make it so that this doesn't cause horizontal rotation
	# TODO - minimize vertical camera rotation
	# TODO - make this a lerp rather than an instantaneous snap
	var kick_store : Vector2 = kick_amount
	kick_store.x *= ((randi() & 2) - 1)
	mouse_input += kick_store # TODO scale with screen size ?
	
	start_camera_shake(1, gck.gun_shoot_time)


## Centers the gun camera, and updates the gun deadzone to match
func _viewport_update():
	# Save our new screensize
	screen_size = get_viewport().size
	# Reset the mouse input variables
	mouse_input = Vector2.ZERO
	mouse_position = screen_size/2
	input_rotation = Vector3.ZERO
	# Update the gun deadzone based on screen_size and mouse_deadzone
	gun_deadzone = Vector3(
		screen_size.x/2 * mouse_deadzone.x,
		screen_size.y/2 * mouse_deadzone.y,
		screen_size.y/2 * mouse_deadzone.z
	)
	# Update our deadzone debug rectangle
	guncanvas.viewport_update(screen_size, gun_deadzone) # TODO - not our job?


## Starts a camera shake, with aggressiveness [amount] and duration [duration]
func start_camera_shake(amount : float, duration : float) -> void:
	# Early return if we've fully disabled camera shake
	if(!camera_shake_enabled and !camera_roll_enabled):
		return
	
	if _camera_shake_tween:
		_camera_shake_tween.kill()
	
	var MAX_SHAKE_AMT = 0.025 # TODO export, amount-dependent
	var MIN_SHAKE_AMT = MAX_SHAKE_AMT * 0.5 # TODO export
	_camera_shake_angle.x = randf_range(MIN_SHAKE_AMT, MAX_SHAKE_AMT)
	_camera_shake_angle.y = randf_range(MIN_SHAKE_AMT, MAX_SHAKE_AMT)
	
	_camera_shake_tween = create_tween()
	_camera_shake_tween.tween_method(_update_camera_shake.bind(amount), 0.0, 1.0, duration).set_ease(Tween.EASE_OUT)


## [Tween method] - Handles camera shake 
func _update_camera_shake(alpha : float, _amount : float) -> void:
	# Camera x/y shake
	if(camera_shake_enabled):
		var shake_frequency : float = 2 # TODO export this? make it amount-dependent?
		var amt = sin(alpha * shake_frequency * TAU) * (1 - alpha)
	
		var v_offset = amt * _camera_shake_angle.y
		var h_offset = amt * _camera_shake_angle.x
	
		player_camera.v_offset = v_offset
		player_camera.h_offset = h_offset
	
	# Camera roll shake
	if(camera_roll_enabled):
		var roll_frequency : float = 3 # TODO export this and below multipliers, make effected by amount
		var roll_offset = -sin(alpha * roll_frequency * TAU) * (1 - alpha) * 0.002
		var pitch_offset = sin(alpha * 2 * TAU) * (1 - alpha) * 0.002
		var yaw_offset = sin(alpha * roll_frequency * TAU) * (1 - alpha) * 0.002
	
		player_camera.rotation.z = roll_offset
		player_camera.rotation.x = pitch_offset
		player_camera.rotation.y = yaw_offset


## Toggles debug UI
func toggle_debug(is_debug : bool, parameter : String) -> void:
	match(parameter):
		"box": debug_box = is_debug
		"dot": debug_dot = is_debug
	guncanvas.display_toggle(debug_box, debug_dot) # TODO - not our job ?
