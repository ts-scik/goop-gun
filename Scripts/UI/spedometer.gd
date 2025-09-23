extends Label

var tracked_node : Node3D = null


## Update our text to match tracked_node xz_velocity each physics tick
func _physics_process(_delta: float) -> void:
	if tracked_node != null:
		var xz_vel = Vector3(tracked_node.velocity.x, 0, tracked_node.velocity.z)
		self.text = str(snapped(xz_vel.length(),0.1)) + "u/s"


## Sets our tracked_node to passed [node]
func set_tracked_node(node : Node3D) -> void:
	tracked_node = node
