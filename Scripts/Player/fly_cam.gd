extends Camera3D

# Mouse input variables
var mouse_input : Vector2 # Stores mouse input each frame
var input_rotation : Vector3 # Stores mouse_input converted to rotation


## Handle player movement
func _physics_process(delta: float) -> void:
	var input_dir = Input.get_vector("left", "right", "forward", "back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y).normalized())
	if direction:
		self.global_position += direction*delta*10

	if(Input.is_action_pressed("jump")):
		self.global_position += Vector3.UP*delta*10
	if(Input.is_action_pressed("crouch")):
		self.global_position -= Vector3.UP*delta*10

	var camera_sensitivity = 0.0005
	input_rotation.y += mouse_input.x * camera_sensitivity
	#input_rotation.x += mouse_input.y * camera_sensitivity
	input_rotation.x = clampf(input_rotation.x + (mouse_input.y * camera_sensitivity), deg_to_rad(-90), deg_to_rad(85))
	self.basis = Basis.from_euler(Vector3(input_rotation.x, input_rotation.y, 0.0)) # rotate camera controller (up/down)input_rotation
	mouse_input = Vector2.ZERO


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_input.x += -event.screen_relative.x
		mouse_input.y += -event.screen_relative.y
		
	if event.is_action_pressed("shoot"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
