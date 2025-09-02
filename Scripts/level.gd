extends Node3D

@onready var player : PlayerController = get_node("Player")
@onready var player_camera : CameraController = get_node("Player/CameraController")
@onready var menu : CanvasLayer = get_node("MainMenu")


## Connect relevant signals
func _ready() -> void:
	player.menu.connect(_on_menu_key)
	menu.value_update.connect(_on_menu_value_update)
	

## Handle showing/hiding the menu
func _on_menu_key(is_paused: bool) -> void:
	if(is_paused):
		menu.show()
	else:
		menu.hide()


## Handle main menu value updates
func _on_menu_value_update(value, parameter : String) -> void:
	match(parameter):
		"cam_sense":
			player_camera.camera_sensitivity = value / 1000
		"aim_sense":
			player_camera.aim_sensitivity = value / 1000
		"debug":
			player_camera.toggle_debug(value)
