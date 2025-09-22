extends Label

var player : PlayerController = null

func _physics_process(_delta: float) -> void:
	if player != null:
		var xz_vel = Vector3(player.velocity.x, 0, player.velocity.z)
		self.text = str(snapped(xz_vel.length(),0.1)) + "u/s"
