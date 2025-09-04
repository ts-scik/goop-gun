extends CanvasLayer

@onready var healthbar = get_node("Base/Health")

func update_health(value : int):
	healthbar.value = value
