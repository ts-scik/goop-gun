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
var gun_container : Node3D # Gun's container
# Mouse input variables
var mouse_input : Vector2 # Stores mouse input each frame
var input_rotation : Vector3 # Stores mouse_input converted to rotation
var camera_sensitivity : float = 0.005 # Mouse camera sensitivity
# Gun deadzone variables
var mouse_position : Vector2 = Vector2.ZERO
var aim_sensitivity : float = 0.005 # Mouse aim sensitivity
var mouse_deadzone : Vector3 = Vector3(0.15, 0.75, 0.4) # mouse deadzone by percentage of screen (x, yTop, yBottom)
var screen_size : Vector2 # size of screen (in pixels)
var gun_deadzone : Vector3 # gun's deadzone size (in pixels)
var gun_hold_distance : float = 0.75 # how far gun is held out from player
# Debug stuff
var red_dot : ColorRect # debug red-dot for aim
var boundary_rect : ReferenceRect # debug rectangle for gun deadzone

## Get our cameras set up
func _ready() -> void:
# START CAMERA MNGMT
	# Find the target nodes
	player_controller = get_parent() # TODO: bad!
	# Turn off automatic physics interpolation for the Camera3D
	set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_OFF)
	$PlayerCamera.set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_OFF) # TODO -- why??
	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Disable transform inheritance from parent
	top_level = true
# END CAMERA MNGMT
# START GUN MGMT
	gun_container = get_node("GunContainer")
	boundary_rect = get_node("GunCanvas/BoundaryRect")
	red_dot = get_node("GunCanvas/RedDot")
	player_camera = get_node("PlayerCamera")
	viewport_update()
# END GUN MGMT


## Handles input [event]s for mouse
func _input(event: InputEvent) -> void:
	# If the mouse is captured -> handle mouse movement
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		mouse_input.x += -event.screen_relative.x * camera_sensitivity
		mouse_input.y += -event.screen_relative.y * camera_sensitivity
	# If mouse is uncaptured, and we just clicked -> capture the mouse
	elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and event is InputEventMouseButton:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event.is_action_pressed("shoot"):
		shoot()


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


## Handles camera rotation / gun positioning
func _process(_delta: float) -> void:
	# If the window has been resized, do some viewport updates
	if(screen_size != Vector2(get_viewport().size)): viewport_update()
	
	# Get the gun's position onscreen
	var gun_pos = player_camera.project_position(mouse_position, gun_hold_distance)
	
	# Update mouse position
	var mouse_newpos = mouse_position - mouse_input * aim_sensitivity * (screen_size.y) * 20
	var midpoint = screen_size/2
	mouse_position.x = clampf(mouse_newpos.x, midpoint.x - gun_deadzone.x, midpoint.x + gun_deadzone.x)
	mouse_position.y = clampf(mouse_newpos.y, midpoint.y - gun_deadzone.y, midpoint.y + gun_deadzone.z)

	# If the gun is trying to move beyond its deadzone, rotate the camera
	if(mouse_position.x != mouse_newpos.x):
		input_rotation.y += mouse_input.x
	elif(mouse_position.y != mouse_newpos.y):
		input_rotation.x = clampf(input_rotation.x + mouse_input.y, deg_to_rad(-90), deg_to_rad(85))
	
	# Update the player_controller rotation
	player_controller.camera_controller_anchor.transform.basis = Basis.from_euler(Vector3(input_rotation.x, 0.0, 0.0)) # rotate camera controller (up/down)
	player_controller.global_transform.basis = Basis.from_euler(Vector3(0.0, input_rotation.y, 0.0)) # rotate player (left/right) # rotate camera controller (up/down)
	global_transform = player_controller.camera_controller_anchor.get_global_transform_interpolated() # move transform to player head anchor
	
	# Update the gun's position + rotation
	update_gun_local_space()
	
	# Debug
	red_dot.position = mouse_position - (red_dot.size/2) # move our debug red-dot
	
	# Zero out our mouse input for next frame
	mouse_input = Vector2.ZERO


## Shoots : TODO - put this elsewhere
const BULLET_DECAL = preload("res://Prefabs/bullet_decal.tscn")
func shoot():
	var raycast : RayCast3D = get_node("GunContainer/GunRaycast")
	raycast.force_raycast_update()
	if raycast.is_colliding():
		if raycast.get_collider() is RigidBody3D:
			var rb : RigidBody3D = raycast.get_collider()
			var hit_pos_offset = raycast.get_collision_point() - rb.global_position
			rb.apply_force(-global_basis.z*300, hit_pos_offset)
		if raycast.get_collider() is StaticBody3D or raycast.get_collider() is CSGShape3D:
			_bullet_decal(raycast.get_collision_point(), raycast.get_collision_normal())


## Applies bullet decal : TODO - put this elsewhere
func _bullet_decal(pos:Vector3, normal:Vector3) -> void:
	var decal : Node3D = BULLET_DECAL.instantiate()
	get_tree().current_scene.add_child(decal)
	decal.position = pos
	
	if abs(normal) != abs(Vector3.UP):
		decal.look_at(decal.position+normal, Vector3.UP)
		decal.transform = decal.transform.rotated_local(Vector3.LEFT, TAU/4)
	decal.rotate(normal, randf_range(0, TAU))
	
	await get_tree().create_timer(1.5).timeout
	decal.queue_free()

## Updates the gun's position+rotation (for if gun exists in local space)
func update_gun_local_space():
	# Update whether gun is global/local
	gun_container.top_level = false
	# Update the gun's position
	gun_container.position = to_local(player_camera.project_position(mouse_position,0.5))
	# Update the gun's rotation (relative to camera)
	var player_camera_interp = to_local(player_camera.get_global_transform_interpolated().origin) # get interpolated player_camera position in local space
	var gun_container_interp = to_local(gun_container.get_global_transform_interpolated().origin) # get interpolated gun_container position in local space
	var fw_dir = gun_container_interp - player_camera_interp # find vector from player camera to gun_container (interpolated)
	gun_container.basis = Basis.looking_at(fw_dir, Vector3.UP, false)


## Updates the gun's position+rotation (for if gun exists in global space)
func update_gun_global_space():
	# Update whether gun is global/local
	gun_container.top_level = true
	# Update the gun's position
	gun_container.global_position = (player_camera.project_position(mouse_position,0.5))
	# Update the gun's rotation (relative to camera)
	var player_camera_interp = player_camera.get_global_transform_interpolated().origin # get interpolated player_camera position in local space
	var gun_container_interp = gun_container.get_global_transform_interpolated().origin # get interpolated gun_container position in local space
	var fw_dir = gun_container_interp - player_camera_interp # find vector from player camera to gun_container (interpolated)
	var up_dir = self.basis.y
	gun_container.basis = Basis.looking_at(fw_dir, up_dir, false)
