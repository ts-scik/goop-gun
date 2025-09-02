extends Node3D

@onready var player : PlayerController = get_node("Player")
@onready var player_camera : CameraController = get_node("Player/CameraController")
@onready var menu : CanvasLayer = get_node("MainMenu")

func _ready() -> void:
	player.menu.connect(_on_menu_key)
	menu.value_update.connect(_on_menu_value_update)
	
func _on_menu_key(is_paused: bool) -> void:
	if(is_paused):
		menu.show()
	else:
		menu.hide()

func _on_menu_value_update(value, parameter : String) -> void:
	print(value, parameter)
	match(parameter):
		"cam_sense":
			player_camera.camera_sensitivity = value / 1000
		"aim_sense":
			player_camera.aim_sensitivity = value / 1000
		"debug":
			player_camera.toggle_debug(value)
