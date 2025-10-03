class_name PlayerHUD
extends CanvasLayer

@onready var healthbar = get_node("Base/Health")

## Update the healthbar value
func update_health(value : int):
	healthbar.value = value
