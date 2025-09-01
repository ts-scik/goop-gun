extends Node3D

# Node that the camera will follow
var player_controller: Player
var input_rotation: Vector3
var mouse_input: Vector2
var mouse_sensitivity: float = 0.005

func _ready() -> void:
	# Find the target node
	player_controller = get_parent()

	# Turn off automatic physics interpolation for the Camera3D,
	# we will be doing this manually
	set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_OFF)
	
	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Disable transform inheritance from parent
	top_level = true
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_input.x += -event.screen_relative.x * mouse_sensitivity
		mouse_input.y += -event.screen_relative.y * mouse_sensitivity
	elif event is InputEventMouseButton:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func _process(_delta: float) -> void:
	input_rotation.x = clampf(input_rotation.x + mouse_input.y, deg_to_rad(-90), deg_to_rad(85))
	input_rotation.y += mouse_input.x
	
	# rotate camera controller (up/down)
	player_controller.camera_controller_anchor.transform.basis = Basis.from_euler(Vector3(input_rotation.x, 0.0, 0.0))
	
	# rotate player (left/right)
	player_controller.global_transform.basis = Basis.from_euler(Vector3(0.0, input_rotation.y, 0.0))
	
	# move transform to player head anchor
	global_transform = player_controller.camera_controller_anchor.get_global_transform_interpolated()
	
	mouse_input = Vector2.ZERO
