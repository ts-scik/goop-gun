extends Node3D
class_name CameraController

# Written using the following godot documentation:
# https://docs.godotengine.org/en/stable/tutorials/physics/interpolation/advanced_physics_interpolation.html
# And with help from the following video:
# https://www.youtube.com/watch?v=zfIuaRzNti4

# Player variables
var player_controller : Player # Node that the camera will follow
var player_camera : Camera3D # Player camera
# Gun camera nodes
var gun_vpc : SubViewportContainer # Gun's ViewPortContainer
var gun_model : Node3D # Gun's model
# Mouse input variables
var mouse_input : Vector2 # Stores mouse input each frame
var input_rotation : Vector3 # Stores mouse_input converted to rotation
var camera_sensitivity : float = 0.005 # Mouse camera sensitivity
var aim_sensitivity : float = 100 # Mouse aim sensitivity
# Gun deadzone variables
var mouse_deadzone : Vector2 = Vector2(0.25, 0.25) # mouse deadzone by percentage of screen
var square_mouse_deadzone : bool = true # whether mouse deadzone should be square (y component only)
var screen_size : Vector2 # size of screen (in pixels)
var gun_deadzone : Vector2 # gun's deadzone size (in pixels)
var boundary_rect : ReferenceRect # debug rectangle for gun deadzone


## Get our cameras set up
func _ready() -> void:
# START CAMERA MNGMT
	# Find the target nodes
	player_controller = get_parent() # TODO: bad!
	# Turn off automatic physics interpolation for the Camera3D
	set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_OFF)
	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Disable transform inheritance from parent
	top_level = true
# END CAMERA MNGMT
# START GUN CAMERA MGMT
	gun_vpc = get_node("GunCanvas/GunVPC")
	gun_model = get_node("GunCanvas/GunVPC/GunVP/GunCamera/GunModel")
	boundary_rect = get_node("GunCanvas/BoundaryRect")
	player_camera = get_node("PlayerCamera")
	gun_vpc.get_node("GunVP/GunCamera").environment = player_camera.environment
	camera_center()
# END GUN CAMERA MGMT


## Handles input [event]s for mouse
func _input(event: InputEvent) -> void:
	# If the mouse is captured -> handle mouse movement
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		mouse_input.x += -event.screen_relative.x * camera_sensitivity
		mouse_input.y += -event.screen_relative.y * camera_sensitivity
	# If mouse is uncaptured, and we just clicked -> capture the mouse
	elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and event is InputEventMouseButton:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Centers the gun camera, and updates the gun deadzone to match
func camera_center():
	# Zero out the mouse variables
	mouse_input = Vector2.ZERO
	input_rotation = Vector3.ZERO
	# Save our screensize, and set the gun viewport to match
	screen_size = get_viewport().size
	gun_vpc.get_node("GunVP").size = screen_size
	# Update the GunVPC
	#gun_vpc.set_anchors_preset(Control.PRESET_FULL_RECT)
	gun_vpc.position = Vector2.ZERO
	# Update the gun deadzone
	gun_deadzone = Vector2(screen_size.x/2 * mouse_deadzone.x, screen_size.y/2 * mouse_deadzone.y)
	if(square_mouse_deadzone):
		gun_deadzone.x = gun_deadzone.y
	# Update our deadzone debug rectangle
	boundary_rect.size = gun_deadzone * 2
	boundary_rect.position = (screen_size / 2) - (boundary_rect.size / 2)


## Spawns a debug cube at [location]
func spawn_cube(location : Vector3):
	var cube : RigidBody3D = load("res://Prefabs/cube.tscn").instantiate(5)
	add_child(cube)
	cube.global_position = location
	cube.top_level = true
	cube.set_linear_velocity(-self.transform.basis.z * 15)


## Handles camera rotation / gun positioning
func _process(_delta: float) -> void:
	# Debug
	if Input.is_action_just_pressed("debug"):
		#camera_center()
		var gun_vpc_screenpos = gun_vpc.position + screen_size/2
		var gun_pos = player_camera.project_position(gun_vpc_screenpos, 0.75)
		print("actual g_vpc_p: ", gun_vpc.position, "\tg_vpc_sp: ", gun_vpc_screenpos)
		print(gun_pos)
		spawn_cube(gun_pos)
		pass
	
	# Update gun position
	var gun_vpc_newpos = gun_vpc.position - mouse_input * aim_sensitivity
	gun_vpc.position.x = clampf(gun_vpc_newpos.x, -gun_deadzone.x, gun_deadzone.x)
	gun_vpc.position.y = clampf(gun_vpc_newpos.y, -gun_deadzone.y, gun_deadzone.y)

	# If the gun is trying to move beyond its deadzone, rotate the camera
	if(gun_vpc.position != gun_vpc_newpos):
		input_rotation.x = clampf(input_rotation.x + mouse_input.y, deg_to_rad(-90), deg_to_rad(85))
		input_rotation.y += mouse_input.x
	
	# rotate camera controller (up/down)
	player_controller.camera_controller_anchor.transform.basis = Basis.from_euler(Vector3(input_rotation.x, 0.0, 0.0))
	# rotate player (left/right)
	player_controller.global_transform.basis = Basis.from_euler(Vector3(0.0, input_rotation.y, 0.0))
	
	# move transform to player head anchor
	global_transform = player_controller.camera_controller_anchor.get_global_transform_interpolated()
	
	# Zero out our mouse input for next frame
	mouse_input = Vector2.ZERO
