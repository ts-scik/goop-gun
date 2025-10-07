## Manages all player camera input / aiming
class_name CameraController
extends Node3D

# Written using the following godot documentation:
# https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/advanced_physics_interpolation.html

var pmk : PlayerController # Node that the camera will follow - grabbed in ready()

@export_category("Effects")
@export_group("Run Tilt")
@export var enable_tilt : bool = false
@export var run_pitch : float = 0.1 # Euler degrees
@export var run_roll : float = 0.25 # Euler degrees
@export var max_pitch : float = 1.0 # Euler degrees
@export var max_roll : float = 2.5 # Euler degrees
@export_group("Gun Kick")
@export var kick_amount = Vector2(0.025,0.05) # Cursor's x/y screen kick amount
@export_group("Camera Shake")
@export var camera_shake_enabled = true
@export var camera_roll_enabled = true
var _camera_shake_tween : Tween
var _camera_shake_angle : Vector2 = Vector2.ZERO
@export_group("Aim FOV")
@export var enable_aim_zoom : bool = true
@export var aimed_fov_percent : float = 0.875
@export_group("Viewbob")
@export var enable_viewbob : bool = true
@export var viewbob_curve : Curve
@export var max_bob_height : float = 0.06
var bob_vec : Vector3 = Vector3.ZERO

var desired_fov : float = 75.0 # TODO - this should be player-configurable
# Child nodes
var player_camera : Camera3D # Player camera
var gck : GunController # Gun's container
# Mouse sensitivity variables
var mouse_sensitivity : float = 0.005 # Mouse overall sensitivitiy
var camera_sensitivity : float = 0.5 # Mouse camera sensitivity
var aim_sensitivity : float = 0.01 # Mouse aim sensitivity
# Mouse input variables
var mouse_input : Vector2 # Stores mouse input each frame
var input_rotation : Vector3 # Stores mouse_input converted to rotation
# Gun deadzone variables
var mouse_position : Vector2 = Vector2.ZERO # Mouse cursor's position onscreen
@export_group("Mouse Deadzone")
@export var mouse_deadzone : Vector3 = Vector3(0.1, 0.65, 0.35) # Mouse deadzone (in screen %) (x, yTop, yBottom)
var screen_size : Vector2 # Size of screen (in pixels)
var gun_deadzone : Vector3 # Gun's deadzone size (in pixels)
# Debug stuff
var guncanvas : GunCanvas # Node for mouse_position debug display
var debug_dot : bool = false # Flag for if we want to show the red_dot
var debug_box : bool = false # Flag for if we want to show the boundary_rect


## Get our camera
func _ready() -> void:
	# Find our PlayerController owner
	await owner.ready
	pmk = owner as PlayerController
	assert(pmk != null, "The CameraController node requires a PlayerController node as owner.")
	# Turn off automatic physics interpolation for the Camera3D
	set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_OFF)
	# Disable transform inheritance from parent
	top_level = true
	# Capture the mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Find the target nodes
	gck = get_node("GunController")
	player_camera = get_node("PlayerCamera")
	guncanvas = get_node("GunCanvas")
	# Start using camera
	player_camera.current = true
	# Update all our screen-size-related variables
	_viewport_update()


## Handles input [event]s for mouse whenever they arrive
func _input(event: InputEvent) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Handle mouse movement
		if event is InputEventMouseMotion:
			mouse_input.x += -event.screen_relative.x * mouse_sensitivity
			mouse_input.y += -event.screen_relative.y * mouse_sensitivity


## Handles gamepad aiming
func _input_aim_gamepad() -> void:
	var y_aim : float = Input.get_axis("look_down","look_up")
	var x_aim : float = Input.get_axis("look_right","look_left")
	
	var gamepad_sense_scale = 15 # TODO - this should be an export, probably
	mouse_input.y += y_aim * mouse_sensitivity * gamepad_sense_scale
	mouse_input.x += x_aim * mouse_sensitivity * gamepad_sense_scale


## Handles camera rotation / gun positioning
func _process(_delta: float) -> void:
	# Handle gamepad aiming
	_input_aim_gamepad()


## Returns offset angle based on camera effects
func _calculate_effects() -> Transform3D:
	var velocity = pmk.velocity
	var pos = Vector3.ZERO
	var angles = Vector3.ZERO
	
	# Camera Tilt
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


## Shoots
func camera_shoot():
	# Handle mouse kick
	# TODO - make it so that this doesn't cause horizontal rotation, and minimize vertical camera rotation
	# TODO - make this a lerp rather than an instantaneous snap
	var kick_store = kick_amount
	kick_store.x *= ((randi() & 2) - 1)
	if(gck.is_aiming):
		start_camera_shake(1, gck.gun_shoot_time)
		mouse_input += kick_store # TODO scale with screen size


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


## Handles camera shake
func _update_camera_shake(alpha : float, _amount : float) -> void:
	if(camera_shake_enabled):
		var shake_frequency : float = 2 # TODO export this 4? make it amount-dependent?
		var amt = sin(alpha * shake_frequency * TAU) * (1 - alpha)
	
		var v_offset = amt * _camera_shake_angle.y
		var h_offset = amt * _camera_shake_angle.x
	
		player_camera.v_offset = v_offset
		player_camera.h_offset = h_offset
	
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
