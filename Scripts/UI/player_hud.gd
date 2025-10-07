class_name PlayerHUD
extends CanvasLayer

@onready var healthbar = get_node("Base/Health")


## Sets up variables for HUD, given player owner
func _ready():
	await owner.ready
	var player = owner as PlayerController
	self.show()
	self.update_health(player.health)
	self.get_node("SpeedContainer/Speed").set_tracked_node(player)


## Update the healthbar value
func update_health(value : int):
	healthbar.value = value
