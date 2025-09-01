extends Camera3D

# Node that the camera will follow
@export var _target : Node3D

# We will smoothly lerp to follow the target
# rather than follow exactly
var _target_pos : Vector3 = Vector3()
var _move_curve : Curve3D
var _timer : float = 0.0
const MOVE_SPEED = 0.1

func _ready() -> void:
	# Find the target node

	# Turn off automatic physics interpolation for the Camera3D,
	# we will be doing this manually
	set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_OFF)
	
	# Disable transform inheritance from parent
	top_level = true
	
	_move_curve = Curve3D.new()
	_move_curve.add_point(Vector3(0,1.5,3.0))
	_move_curve.add_point(Vector3(3.0,1.5,0))
	_move_curve.add_point(Vector3(0,1.5,-3.0))
	_move_curve.add_point(Vector3(-3.0,1.5,0))
	_move_curve.add_point(Vector3(0,1.5,3.0))

func _process(delta: float) -> void:
	# Find the current interpolated transform of the target
	var tr : Transform3D = _target.get_global_transform_interpolated()

	# Provide some delayed smoothed lerping towards the target position
	_target_pos = lerp(_target_pos, tr.origin, min(delta, 1.0))

	# Fixed camera position, but it will follow the target
	look_at(_target_pos, Vector3(0, 1, 0))

func _physics_process(delta: float) -> void:
	position = _move_curve.sample_baked(_timer * _move_curve.get_baked_length(), true)
	_timer += delta * MOVE_SPEED
	if(_timer > 1.0):
		_timer = 0.0
