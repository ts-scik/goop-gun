extends Node3D
class_name CameraController

# Written using the following godot documentation:
# https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/advanced_physics_interpolation.html
# And with help from the following video:
# https://www.youtube.com/watch?v=zfIuaRzNti4

# //VARIABLE ZONE// #

# Child nodes
var player_controller : PlayerController # Node that the camera will follow
var player_camera : Camera3D # Player camera
var gun_controller : Node3D # Gun's container
# Mouse sensitivity variables
var mouse_sensitivity : float = 0.005 # Mouse overall sensitivitiy
var camera_sensitivity : float = 0.5 # Mouse camera sensitivity
var aim_sensitivity : float = 0.005 # Mouse aim sensitivity
# Mouse input variables
var mouse_input : Vector2 # Stores mouse input each frame
var input_rotation : Vector3 # Stores mouse_input converted to rotation
# Gun deadzone variables
var mouse_position : Vector2 = Vector2.ZERO # Mouse cursor's position onscreen
var mouse_deadzone : Vector3 = Vector3(0.15, 0.65, 0.35) # Mouse deadzone (in screen %) (x, yTop, yBottom)
var screen_size : Vector2 # Size of screen (in pixels)
var gun_deadzone : Vector3 # Gun's deadzone size (in pixels)
var gun_hold_distance : float = 0.75 # How far gun is held out from player
# Gun aiming variables
var ads_time : float = 0.5 # ADS time (in seconds)
var ads_timer : float = 0.0 # Timer for ADS lerp
var aim_held : bool = false # Flag for ADS input
var is_aiming : bool = false # Flag for ADS completed
var aim_toggle : bool = false # Whether or not we're using toggle-aim
var kick_amount = Vector2(0.1,0.5) # Cursor's x/y screen kick amount
# Debug stuff
var red_dot : ColorRect # Node for mouse_position debug display
var boundary_rect : ReferenceRect # Node for gun_deadzone debug display
var debug_dot : bool = false # Flag for if we want to show the red_dot
var debug_box : bool = false # Flag for if we want to show the boundary_rect


# //PRIMARY FUNCTION ZONE// #


## Get our camera + gun set up
func _ready() -> void:
	# Early return if not multiplayer authority - clients own their cameras
	if not is_multiplayer_authority(): return

	# Turn off automatic physics interpolation for the Camera3D
	set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_OFF)
	# Disable transform inheritance from parent
	top_level = true
	# Find the target nodes
	player_controller = get_parent() # TODO: bad!
	# Capture the mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Get the player camera, and start using it
	player_camera = get_node("PlayerCamera")
	player_camera.current = true
	# Get the gun controller and its debug UI
	gun_controller = get_node("GunController")
	boundary_rect = get_node("GunCanvas/BoundaryRect")
	red_dot = get_node("GunCanvas/RedDot")
	# Update all our screen-size-related variables
	viewport_update()


## Handles input [event]s for mouse whenever they arrive
func _input(event: InputEvent) -> void:
	# Early return if not multiplayer authority - clients own their cameras
	if not is_multiplayer_authority(): return
	
	# If the mouse is captured -> handle mouse movement
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		mouse_input.x += -event.screen_relative.x * mouse_sensitivity
		mouse_input.y += -event.screen_relative.y * mouse_sensitivity
	# Elif mouse is captured, and we clicked -> shoot
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and aim_held and event.is_action_pressed("shoot"):
		shoot()
	# Elif mouse is captured, and aim button was pressed down this frame,
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event.is_action_pressed("aim"):
		# If aim is a hold, enable aiming
		if(!aim_toggle):
			aim_held = true
		# If aim is a toggle, toggle aiming
		else:
			aim_held = !aim_held
	# Elif mouse is captured, aim button was released this frame, and we're using hold-to-aim,
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and !aim_toggle and event.is_action_released("aim"):
		# Disable aiming
		aim_held = false
		is_aiming = false


## Handles camera rotation / gun positioning
func _process(delta: float) -> void:
	# Early return if not multiplayer authority - clients own their cameras
	if not is_multiplayer_authority(): return
	
	# If the window has been resized, do some viewport updates
	if(screen_size != Vector2(get_viewport().size)): viewport_update()

	# Choose a camera update function depending on whether we're fully aimed or not
	mouse_input_management()
	
	# Handle ADS inputs -- THIS NEEDS TO BE AFTER MOUSE INPUT HANDLING
	#TODO: add third state for once we've finished de-aiming
	if(aim_held and !is_aiming):
		start_aim(delta)
	elif(!aim_held):
		end_aim(delta)
	
	# Zero out our mouse input for next frame
	mouse_input = Vector2.ZERO


## On the physics tick, snap our transform to the player head marker (helps with multiplayer sync)
func _physics_process(_delta: float) -> void:
	# Early return if not multiplayer authority - clients own their cameras
	if not is_multiplayer_authority(): return
	
	# Snap our global_transform to the player's head marker
	global_transform = player_controller.camera_controller_anchor.global_transform


# //SUB-FUNCTION ZONE// #


## Handle mouse input event on camera + gun
func mouse_input_management() -> void:
	# Handle AIMED state
	if(is_aiming):
		# Update mouse position
		var mouse_newpos = mouse_position - (mouse_input * aim_sensitivity * (screen_size.y) * 20)
		var midpoint = screen_size/2
		mouse_position.x = clampf(mouse_newpos.x, midpoint.x - gun_deadzone.x, midpoint.x + gun_deadzone.x)
		mouse_position.y = clampf(mouse_newpos.y, midpoint.y - gun_deadzone.y, midpoint.y + gun_deadzone.z)

		# If the gun is trying to move beyond its deadzone, rotate the camera
		# TODO : a lot of this has duplicate code below
		if(mouse_position.x != mouse_newpos.x):
			input_rotation.y += mouse_input.x * camera_sensitivity
		elif(mouse_position.y != mouse_newpos.y):
			input_rotation.x = clampf(input_rotation.x + (mouse_input.y * camera_sensitivity), deg_to_rad(-90), deg_to_rad(85))
		
		# Debug - update our debug red-dot color
		if(debug_dot): red_dot.color = Color.RED # TODO: - move this to start/end aim
	
	# Handle UNAIMED state
	else:
		# Reset mouse position to screen center
		mouse_position = screen_size/2
		
		# Update camera rotation
		# TODO : this code is duplicated above
		input_rotation.y += mouse_input.x * camera_sensitivity
		input_rotation.x = clampf(input_rotation.x + (mouse_input.y * camera_sensitivity), deg_to_rad(-90), deg_to_rad(85))
		
		# Debug - update our debug red-dot color
		if(debug_dot): red_dot.color = Color.BLUE # TODO: - move this to start/end aim
	
	# Update the player_controller rotation
	player_controller.camera_controller_anchor.transform.basis = Basis.from_euler(Vector3(input_rotation.x, 0.0, 0.0)) # rotate camera controller (up/down)
	player_controller.global_transform.basis = Basis.from_euler(Vector3(0.0, input_rotation.y, 0.0)) # rotate player (left/right) # rotate camera controller (up/down)
	global_transform = player_controller.camera_controller_anchor.get_global_transform_interpolated() # move transform to player head anchor
	
	# Update the gun's position + rotation if we're aiming (has to be after player controller rotation)
	# TODO: add some kind of sway to gun as mouse moves slower/faster
	if(is_aiming): update_gun_local_space()
	
	# Debug - Move our debug red-dot
	# TODO - should only do this if we're aiming, or if we just stopped aiming
	if(debug_dot): red_dot.position = mouse_position - (red_dot.size/2)


## Animates gun into aiming position
func start_aim(delta) -> void:
	# update the aim timer
	ads_timer += delta
	# if we're there, update the aim variable
	if(ads_timer/ads_time >= 1.0):
		ads_timer = ads_time
		is_aiming = true
	# get target pos/rot
	var target_pos = Vector3(0,0,-gun_hold_distance)
	var target_rot = Vector3.ZERO
	# lerp towards aim position
	#TODO: This lerp is BAD!!
	gun_controller.position = lerp(gun_controller.position, target_pos, ads_timer/ads_time)
	gun_controller.rotation = lerp(gun_controller.rotation, target_rot, ads_timer/ads_time)


## Animates gun when not aimed
var holstered_pos = Vector3(0, 1.0, -0.3)
var holstered_rot = Vector3(deg_to_rad(-45.0), 0.0, 0.0)
func end_aim(delta) -> void:
	# update is_aiming to be safe
	if(is_aiming): is_aiming = false
	# update the aim timer
	ads_timer -= delta
	if(ads_timer < 0.0): ads_timer = 0.0
	# get target pos/rot
	var player_interp = player_controller.get_global_transform_interpolated()
	var target_pos = to_local(
		player_interp.origin + (player_interp.basis.y * holstered_pos.y) + (player_interp.basis.z * holstered_pos.z)
	)
	var target_rot = player_controller.global_rotation + holstered_rot
	# lerp towards not-aimed position
	#TODO: This lerp is BAD!!
	gun_controller.position = lerp(gun_controller.position, target_pos, (1-ads_timer/ads_time))
	gun_controller.global_rotation = lerp(gun_controller.global_rotation, target_rot, (1-ads_timer/ads_time))


## Shoots
func shoot():
	# Handle kick
	kick_amount.x *= ((randi() & 2) - 1)
	if(is_aiming): mouse_input += (kick_amount * screen_size/1000)
	# TODO: play a kick animation on camera
	# Ask the gun container to take over
	# TODO: should this be the player's responsibility or the camera's or the gun's?
	gun_controller.shoot.rpc()


## Updates the gun's position+rotation (for if gun exists in local space)
func update_gun_local_space():
	# Update whether gun is global/local
	gun_controller.top_level = false
	# Update the gun's position
	gun_controller.position = to_local(player_camera.project_position(mouse_position,gun_hold_distance))
	# Update the gun's rotation (relative to camera)
	var player_camera_interp = to_local(player_camera.get_global_transform_interpolated().origin) # get interpolated player_camera position in local space
	var gun_controller_interp = to_local(gun_controller.get_global_transform_interpolated().origin) # get interpolated gun_controller position in local space
	var fw_dir = gun_controller_interp - player_camera_interp # find vector from player camera to gun_controller (interpolated)
	gun_controller.basis = Basis.looking_at(fw_dir, Vector3.UP, false)


## Centers the gun camera, and updates the gun deadzone to match
func viewport_update():
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
	boundary_rect.size = Vector2(gun_deadzone.x*2, gun_deadzone.y + gun_deadzone.z)
	boundary_rect.position = (screen_size / 2) - Vector2(gun_deadzone.x, gun_deadzone.y)


## Toggles debug UI
func toggle_debug(is_debug : bool, parameter : String):
	match(parameter):
		"box": debug_box = is_debug
		"dot": debug_dot = is_debug
	if(debug_box or debug_dot):
		get_node("GunCanvas").show()
	else:
		get_node("GunCanvas").hide()
	if(debug_box):
		boundary_rect.show()
	else:
		boundary_rect.hide()
	if(debug_dot):
		red_dot.show()
	else:
		red_dot.hide()
