extends Node3D
class_name CameraController

# Written using the following godot documentation:
# https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/advanced_physics_interpolation.html
# And with help from the following video:
# https://www.youtube.com/watch?v=zfIuaRzNti4

# Child nodes
var player_controller : PlayerController # Node that the camera will follow
var player_camera : Camera3D # Player camera
var gun_controller : Node3D # Gun's container
# Mouse input variables
var mouse_input : Vector2 # Stores mouse input each frame
var input_rotation : Vector3 # Stores mouse_input converted to rotation
var camera_sensitivity : float = 0.5 # Mouse camera sensitivity
var mouse_sensitivity : float = 0.005 # Mouse overall sensitivitiy
var mouse_target : Vector2 = Vector2.ZERO
# Gun deadzone variables
var aim_sensitivity : float = 0.005 # Mouse aim sensitivity
var mouse_position : Vector2 = Vector2.ZERO
var mouse_deadzone : Vector3 = Vector3(0.15, 0.65, 0.35) # mouse deadzone by percentage of screen (x, yTop, yBottom)
var screen_size : Vector2 # size of screen (in pixels)
var gun_deadzone : Vector3 # gun's deadzone size (in pixels)
var gun_hold_distance : float = 0.75 # how far gun is held out from player
# Gun aiming variables
var ads_time : float = 0.5 # ADS time (in seconds)
var ads_timer : float = 0.0 # timer for ADS lerp
var aim_held : bool = false # for ADS input
var is_aiming : bool = false # for ADS completed
var aim_toggle : bool = false
var kick_amount = Vector2(0.1,0.5) # x/y screen kick amount
# Debug stuff
var red_dot : ColorRect # debug red-dot for aim
var boundary_rect : ReferenceRect # debug rectangle for gun deadzone
var debug_dot : bool = false
var debug_box : bool = false


## Get our camera + gun set up
func _ready() -> void:
	if not is_multiplayer_authority(): return
# START CAMERA MNGMT
	# Turn off automatic physics interpolation for the Camera3D
	set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_OFF)
	# Disable transform inheritance from parent
	top_level = true
	# Find the target nodes
	player_controller = get_parent() # TODO: bad!
	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
# END CAMERA MNGMT
# START GUN MGMT
	gun_controller = get_node("GunController")
	boundary_rect = get_node("GunCanvas/BoundaryRect")
	red_dot = get_node("GunCanvas/RedDot")
	player_camera = get_node("PlayerCamera")
	player_camera.current = true
	viewport_update()
# END GUN MGMT


## Handles input [event]s for mouse
func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	# If the mouse is captured -> handle mouse movement
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		mouse_input.x += -event.screen_relative.x * mouse_sensitivity
		mouse_input.y += -event.screen_relative.y * mouse_sensitivity
	# If mouse is captured, and we clicked -> shoot
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and aim_held and event.is_action_pressed("shoot"):
		shoot()
	
	# If aim button is pressed down this frame,
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event.is_action_pressed("aim"):
		# If aim is a hold, enable aiming
		if(!aim_toggle):
			aim_held = true
		# If aim is a toggle, toggle aiming
		else:
			aim_held = !aim_held
	# If aim button was released this frame, and we're using hold-to-aim,
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and !aim_toggle and event.is_action_released("aim"):
		aim_held = false
		is_aiming = false


## Handles camera rotation / gun positioning
func _process(delta: float) -> void:
	# Early return if not multiplayer authority
	if not is_multiplayer_authority(): return
	
	# If the window has been resized, do some viewport updates
	if(screen_size != Vector2(get_viewport().size)): viewport_update()

	# Choose a camera update function depending on whether we're fully aimed or not
	if(is_aiming):
		aimed_input_management()
	else:
		unaimed_input_management()
	
	# Handle ADS inputs -- THIS NEEDS TO BE AFTER MOUSE INPUT HANDLING
	if(aim_held and !is_aiming):
		start_aim(delta)
	elif(!aim_held):
		end_aim(delta)


## On the physics tick, snap our transform to the player head (helps with multiplayer sync)
func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority(): return
	global_transform = player_controller.camera_controller_anchor.global_transform


## Centers the gun camera, and updates the gun deadzone to match
func viewport_update():
	# Zero out the mouse variables
	mouse_input = Vector2.ZERO
	input_rotation = Vector3.ZERO
	# Save our screensize, and set the gun viewport to match
	screen_size = get_viewport().size
	# Update the gun deadzone
	gun_deadzone = Vector3(screen_size.x/2 * mouse_deadzone.x, screen_size.y/2 * mouse_deadzone.y, screen_size.y/2 * mouse_deadzone.z)
	# Update our deadzone debug rectangle
	boundary_rect.size = Vector2(gun_deadzone.x*2, gun_deadzone.y + gun_deadzone.z)
	boundary_rect.position = (screen_size / 2) - Vector2(gun_deadzone.x, gun_deadzone.y)
	# Reset our cursor position
	mouse_position = screen_size/2


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
	# lerp towards aim position
	gun_controller.position = lerp(gun_controller.position, target_pos, (1-ads_timer/ads_time))
	gun_controller.global_rotation = lerp(gun_controller.global_rotation, target_rot, (1-ads_timer/ads_time))


## Manages mouse effect on camera when unaimed
func unaimed_input_management():
	# Reset mouse position to screen center
	mouse_position = screen_size/2
	
	# Update mouse position
	input_rotation.y += mouse_input.x * camera_sensitivity
	input_rotation.x = clampf(input_rotation.x + (mouse_input.y * camera_sensitivity), deg_to_rad(-90), deg_to_rad(85))
	
	# Update the player_controller rotation
	player_controller.camera_controller_anchor.transform.basis = Basis.from_euler(Vector3(input_rotation.x, 0.0, 0.0)) # rotate camera controller (up/down)
	player_controller.global_transform.basis = Basis.from_euler(Vector3(0.0, input_rotation.y, 0.0)) # rotate player (left/right) # rotate camera controller (up/down)
	global_transform = player_controller.camera_controller_anchor.get_global_transform_interpolated() # move transform to player head anchor
	
	# Debug
	# Move our debug red-dot
	if(debug_box or debug_dot):
		red_dot.position = mouse_position - (red_dot.size/2)
		red_dot.color = Color.BLUE
	
	# Zero out our mouse input for next frame
	mouse_input = Vector2.ZERO


## Move the mouse, move the camera, rotate the player to match, etc
func aimed_input_management():
	# Update mouse position
	var mouse_newpos = mouse_position - (mouse_input * aim_sensitivity * (screen_size.y) * 20)
	var midpoint = screen_size/2
	mouse_position.x = clampf(mouse_newpos.x, midpoint.x - gun_deadzone.x, midpoint.x + gun_deadzone.x)
	mouse_position.y = clampf(mouse_newpos.y, midpoint.y - gun_deadzone.y, midpoint.y + gun_deadzone.z)

	# If the gun is trying to move beyond its deadzone, rotate the camera
	if(mouse_position.x != mouse_newpos.x):
		input_rotation.y += mouse_input.x * camera_sensitivity
	elif(mouse_position.y != mouse_newpos.y):
		input_rotation.x = clampf(input_rotation.x + (mouse_input.y * camera_sensitivity), deg_to_rad(-90), deg_to_rad(85))
	
	# Update the player_controller rotation
	player_controller.camera_controller_anchor.transform.basis = Basis.from_euler(Vector3(input_rotation.x, 0.0, 0.0)) # rotate camera controller (up/down)
	player_controller.global_transform.basis = Basis.from_euler(Vector3(0.0, input_rotation.y, 0.0)) # rotate player (left/right) # rotate camera controller (up/down)
	global_transform = player_controller.camera_controller_anchor.get_global_transform_interpolated() # move transform to player head anchor
	
	# Update the gun's position + rotation
	update_gun_local_space()
	
	# Debug
	# Move our debug red-dot
	if(debug_box or debug_dot):
		red_dot.position = mouse_position - (red_dot.size/2)
		red_dot.color = Color.RED
	
	# Zero out our mouse input for next frame
	mouse_input = Vector2.ZERO
	

## Shoots
func shoot():
	# handle kick
	kick_amount.x *= ((randi() & 2) - 1)
	if(is_aiming):
		mouse_input += (kick_amount * screen_size/1000)
	# get container to take over
	#gun_controller.shoot()
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


## Toggles debug
func toggle_debug(is_debug : bool, parameter : String):
	match(parameter):
		"box": debug_box = is_debug
		"dot": debug_dot = is_debug
	if(debug_box or debug_dot):
		get_node("GunCanvas").show()
	else:
		get_node("GunCanvas").hide()
	if(debug_box):
		get_node("GunCanvas/BoundaryRect").show()
	else:
		get_node("GunCanvas/BoundaryRect").hide()
	if(debug_dot):
		get_node("GunCanvas/RedDot").show()
	else:
		get_node("GunCanvas/RedDot").hide()
