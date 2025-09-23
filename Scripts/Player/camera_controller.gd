class_name CameraController
extends Node3D
## Manages all player camera input / aiming

# Written using the following godot documentation:
# https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/advanced_physics_interpolation.html

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
var ads_time : float = 0.25 # ADS time (in seconds)
var ads_timer : float = 0.0 # Timer for ADS lerp
var aim_held : bool = false # Flag for ADS input
var is_aiming : bool = false # Flag for ADS completed
var aim_toggle : bool = false # Whether or not we're using toggle-aim
var kick_amount = Vector2(0.1,0.5) # Cursor's x/y screen kick amount
var last_aimed_target_pos : Vector3 = Vector3.ZERO # stores last position when aimed
var last_aimed_target_rot : Vector3 = Vector3.ZERO # stores last rotation when aimed
var holstered_pos = Vector3(0, 1.0, -0.5) # configurable variable for where gun should go when holstered
var holstered_rot = Vector3(deg_to_rad(-45.0), 0.0, 0.0) # configurable variable for gun's rotation when holstered
# Debug stuff
var red_dot : ColorRect # Node for mouse_position debug display
var boundary_rect : ReferenceRect # Node for gun_deadzone debug display
var debug_dot : bool = false # Flag for if we want to show the red_dot
var debug_box : bool = false # Flag for if we want to show the boundary_rect


## Get our camera + gun set up
func _ready() -> void:
	# Turn off automatic physics interpolation for the Camera3D
	set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_OFF)
	# Early return if not multiplayer authority - clients own their cameras
	if NetworkManager.peer != null and not is_multiplayer_authority(): return
	# Disable transform inheritance from parent
	top_level = true
	# Find the target nodes
	player_controller = get_parent() # TODO: bad!?
	# Capture the mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Get the player camera, and start using it
	gun_controller = get_node("GunController")
	player_camera = get_node("PlayerCamera")
	player_camera.current = true
	# Get the gun controller and its debug UI
	boundary_rect = get_node("GunCanvas/BoundaryRect")
	red_dot = get_node("GunCanvas/RedDot")
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
		# Handle shooting
		elif aim_held and event.is_action_pressed("shoot"):
			shoot()
		# Handle aim press
		elif event.is_action_pressed("aim"):
			# Hold-to-aim -> enable aiming
			if(!aim_toggle): aim_held = true
			# Toggle-aim -> toggle aiming
			else: aim_held = !aim_held
		# Handle aim release (only for hold-to-aim)
		elif !aim_toggle and event.is_action_released("aim"):
			# Hold-to-aim -> disable aiming
			aim_held = false


## Handles camera rotation / gun positioning
func _process(delta: float) -> void:
	# If we're using Network -- early return if not authority
	if NetworkManager.early_return(self): return
	
	# If the window has been resized, do some viewport updates
	if(screen_size != Vector2(get_viewport().size)):
		_viewport_update()

	# Handle mouse input
	_mouse_camera_update()
	
	# Update the gun's position + rotation if we're aiming (has to be after player controller rotation)
	# THIS MUST BE AFTER MOUSE/CAMERA UPDATES!!
	# TODO: add some kind of sway to gun as mouse moves slower/faster
	if(aim_held and is_aiming): #if we're aiming, move+rotate the gun
		_update_gun_local_space() 
	else: # manage aim/de-aim/unaimed states
		manage_aiming(delta)
	
	# Zero out our mouse input for next frame
	mouse_input = Vector2.ZERO
	
	# At the end of the tick, snap our transform to the player head marker (helps with multiplayer sync)
	# TODO : this fixed multiplayer sync, but makes the lighting go crazy
	#global_transform = player_controller.camera_controller_anchor.global_transform


## Handle mouse input event on camera + gun
func _mouse_camera_update() -> void:
	var mouse_y_locked : bool = false
	var mouse_x_locked : bool = false
	
	# AIMED state
	if(is_aiming):
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
		if(debug_dot): red_dot.position = mouse_position - (red_dot.size/2)
	# UNAIMED state
	else:
		# Reset mouse position to screen center
		mouse_position = screen_size/2
	
	# Rotate the camera (unless it's locked by the bounding boxes)
	if(!mouse_x_locked):
		input_rotation.y += mouse_input.x * camera_sensitivity
	if(!mouse_y_locked):
		input_rotation.x = clampf(input_rotation.x + (mouse_input.y * camera_sensitivity), deg_to_rad(-90), deg_to_rad(85))
	
	# Update the player_controller rotation
	# TODO -- look this over and think about it -- globals/interpolation
	# Rotate camera controller (up/down)
	player_controller.camera_controller_anchor.transform.basis = Basis.from_euler(Vector3(input_rotation.x, 0.0, 0.0))
	# Rotate player controller (left/right)
	player_controller.global_transform.basis = Basis.from_euler(Vector3(0.0, input_rotation.y, 0.0))
	# Move transform to player head anchor
	global_transform = player_controller.camera_controller_anchor.get_global_transform_interpolated()


## Animates gun in/out of aiming position
func manage_aiming(delta) -> void:
	# get target pos/rot
	var player_interp := player_controller.get_global_transform_interpolated()
	#var player_interp = player_controller.global_transform # TODO -- why does this get weird??
	var unaimed_target_pos : Vector3 = to_local(player_interp.origin + (player_interp.basis * holstered_pos))
	var unaimed_target_rot : Vector3 = holstered_rot - Vector3(self.rotation.x,0,0)
	
	# If we're in an aim transition,
	if(aim_held or ads_timer > 0.0):
		# If we're trying to aim
		if(aim_held):
			ads_timer += delta # update the aim timer
			if(ads_timer/ads_time >= 1.0): # if we're there, update the aim variable
				ads_timer = ads_time
				is_aiming = true
				# Debug - update our debug red-dot color
				if(debug_dot): red_dot.color = Color.RED
			last_aimed_target_pos = Vector3(0,0,-gun_hold_distance)
			last_aimed_target_rot = Vector3.ZERO
		# If we're trying to de-aim
		elif(!aim_held):
			ads_timer = clampf(ads_timer, 0.0, ads_timer-delta) # update the aim timer
			if(is_aiming): # update is_aiming, last_aimed stuff
				is_aiming = false
				last_aimed_target_pos = gun_controller.position
				last_aimed_target_rot = gun_controller.rotation
				# Debug - update our debug red-dot color
				if(debug_dot):
					red_dot.color = Color.BLUE
					red_dot.position = screen_size/2
		gun_controller.position = lerp(unaimed_target_pos, last_aimed_target_pos, ads_timer/ads_time)
		gun_controller.rotation = lerp(unaimed_target_rot, last_aimed_target_rot, ads_timer/ads_time)
	else:
		gun_controller.position = unaimed_target_pos
		gun_controller.rotation = unaimed_target_rot


## Updates the gun's position+rotation (for if gun exists in local space)
func _update_gun_local_space():
	# Update the gun's position
	gun_controller.position = to_local(player_camera.project_position(mouse_position,gun_hold_distance))
	# Update the gun's rotation (relative to camera)
	var fw_dir = to_local(gun_controller.global_position) - to_local(player_camera.global_position) # vector from player camera to gun_controller
	gun_controller.basis = Basis.looking_at(fw_dir, Vector3.UP, false)


## Shoots
func shoot():
	# Handle mouse kick
	kick_amount.x *= ((randi() & 2) - 1)
	if(is_aiming): mouse_input += (kick_amount * screen_size/1000)
	# TODO: play a kick animation on camera
	# Ask the gun container to take over
	# TODO: should this be the player's responsibility or the camera's or the gun's?
	gun_controller.shoot.rpc()


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
