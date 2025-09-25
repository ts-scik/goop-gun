class_name CameraController
extends Node3D
## Manages all player camera input / aiming

# Written using the following godot documentation:
# https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/advanced_physics_interpolation.html

@export_category("References")
@export var pmk : PlayerController # Node that the camera will follow

@export_category("Effects")
@export var enable_tilt : bool = false
@export var enable_aim_zoom : bool = true
@export var enable_viewbob : bool = true
@export_group("Run Tilt")
@export var run_pitch : float = 0.1 # Euler degrees
@export var run_roll : float = 0.25 # Euler degrees
@export var max_pitch : float = 1.0 # Euler degrees
@export var max_roll : float = 2.5 # Euler degrees
@export_group("Gun Kick")
@export var kick_amount = Vector2(0.1,0.1) # Cursor's x/y screen kick amount
@export_group("Aim FOV")
@export var aimed_fov_percent : float = 0.9

var desired_fov : float = 75.0 # TODO - this should be player-configurable
# Child nodes
var player_camera : Camera3D # Player camera
var qck : GunController # Gun's container
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
	# Turn off automatic physics interpolation for the Camera3D
	set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_OFF)
	# Early return if not multiplayer authority - clients own their cameras
	if NetworkManager.early_return(self): return
	# Disable transform inheritance from parent
	top_level = true
	# Capture the mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Find the target nodes
	qck = get_node("GunController")
	player_camera = get_node("PlayerCamera")
	guncanvas = get_node("GunCanvas")
	# Set up signals, start using camera
	qck.is_aiming_update.connect(_on_is_aiming_update)
	player_camera.current = true
	# Update all our screen-size-related variables
	_viewport_update()


## Handles input [event]s for mouse whenever they arrive
func _input(event: InputEvent) -> void:
	# If we're using Network -- early return if not authority
	if NetworkManager.early_return(self): return
	
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Handle mouse movement
		if event is InputEventMouseMotion:
			mouse_input.x += -event.screen_relative.x * mouse_sensitivity
			mouse_input.y += -event.screen_relative.y * mouse_sensitivity


## Handles camera rotation / gun positioning
func _process(delta: float) -> void:
	# If we're using Network -- early return if not authority
	if NetworkManager.early_return(self): return
	
	# If the window has been resized, do some viewport updates
	if(screen_size != Vector2(get_viewport().size)):
		_viewport_update()

	# Handle mouse input
	var target_transform : Transform3D = _mouse_camera_update()
	
	# Handle camera effects
	var target_fov : float = _determine_zoom_fov()
	var offset_transform : Transform3D = _calculate_effects(delta)
	
	var target_position = target_transform.origin
	var target_rotation = target_transform.basis.get_euler()
	var offset_position = offset_transform.origin
	var offset_rotation = offset_transform.basis.get_euler()
	
	# Update camera
	player_camera.fov = target_fov
	self.position = target_position + offset_position
	self.rotation = target_rotation + offset_rotation
	
	# Update the gun's position + rotation - THIS MUST BE AFTER MOUSE/CAMERA UPDATES!!
	# TODO: add some kind of sway to gun as mouse moves slower/faster
	qck.manage_positioning(delta)
	
	# Zero out our mouse input for next frame
	mouse_input = Vector2.ZERO


## Handle mouse input event on camera
func _mouse_camera_update() -> Transform3D:
	var mouse_y_locked : bool = false
	var mouse_x_locked : bool = false
	
	# AIMED state
	if(qck.is_aiming):
		# Update mouse position
		var mouse_newpos : Vector2 = mouse_position - (mouse_input * aim_sensitivity * (screen_size.y) * 20)
		var midpoint : Vector2 = screen_size/2
		mouse_position.x = clampf(mouse_newpos.x, midpoint.x - gun_deadzone.x, midpoint.x + gun_deadzone.x)
		mouse_position.y = clampf(mouse_newpos.y, midpoint.y - gun_deadzone.y, midpoint.y + gun_deadzone.z)

		# If the mouse is still within the bounding box on an axis, lock that axis' camera rotation
		if(mouse_position.x == mouse_newpos.x):
			mouse_x_locked = true
		if(mouse_position.y == mouse_newpos.y):
			mouse_y_locked = true
		
		# Debug - Move our debug red-dot
		if(debug_dot): guncanvas.update_dot_pos(mouse_position)
	# UNAIMED state
	else:
		# Reset mouse position to screen center
		mouse_position = screen_size/2
	
	# Rotate the camera (unless it's locked by the bounding boxes)
	if(!mouse_x_locked):
		input_rotation.y += mouse_input.x * camera_sensitivity
	if(!mouse_y_locked):
		input_rotation.x = clampf(input_rotation.x + (mouse_input.y * camera_sensitivity), deg_to_rad(-90), deg_to_rad(85))
	
	# Update the pmk rotation
	# TODO -- look this over and think about it -- globals/interpolation
	# Rotate camera controller (up/down)
	pmk.camera_controller_anchor.transform.basis = Basis.from_euler(Vector3(input_rotation.x, 0.0, 0.0))
	# Rotate player controller (left/right)
	pmk.global_transform.basis = Basis.from_euler(Vector3(0.0, input_rotation.y, 0.0))
	# Move transform to player head anchor
	return pmk.camera_controller_anchor.get_global_transform_interpolated()


## Determines how zoom-in the fov should be, given the current qck ads_ratio
func _determine_zoom_fov() -> float:
	if not enable_aim_zoom or qck.ads_ratio() <= 0.0:
		return desired_fov
	return lerpf(desired_fov, desired_fov * aimed_fov_percent, qck.ads_ratio())


## Returns offset angle based on camera effects
func _calculate_effects(delta) -> Transform3D:
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
		# TODO - develop some kind of viewbob curve
		# temp solution -- symmetrical arc peaking at 0.5
		var max_bob_height : float = 0.3 # TODO make this an export var
		var bob_amount : float
		if(foot_time_ratio <= 0.5):
			bob_amount = foot_time_ratio
		else:
			bob_amount = 1.0 - foot_time_ratio
		pos.y += max_bob_height * bob_amount
	
	var out_tf : Transform3D
	out_tf.origin = pos # TODO
	out_tf.basis = Basis.from_euler(angles)
	return out_tf


## Shoots
func camera_shoot():
	# Handle mouse kick
	# TODO - make it so that this doesn't cause horizontal rotation, and minimize vertical camera rotation
	# TODO - make this a lerp rather than an instantaneous snap
	var kick_store = kick_amount
	kick_store.x *= ((randi() & 2) - 1)
	if(qck.is_aiming):
		mouse_input += (kick_store * screen_size/1000)


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
	guncanvas.viewport_update(screen_size, gun_deadzone) # TODO - not our job


## Handle update to is_aiming state
func _on_is_aiming_update(n_is_aiming : bool):
	# Debug - update our debug red-dot color
	if(debug_dot and n_is_aiming):
		guncanvas.update_dot_color(Color.RED)
	if(debug_dot and !n_is_aiming):
		guncanvas.update_dot_pos(screen_size/2)
		guncanvas.update_dot_color(Color.BLUE)


## Toggles debug UI
func toggle_debug(is_debug : bool, parameter : String):
	match(parameter):
		"box": debug_box = is_debug
		"dot": debug_dot = is_debug
	guncanvas.display_toggle(debug_box, debug_dot) # TODO - not our job
