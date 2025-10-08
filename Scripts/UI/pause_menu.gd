extends CanvasLayer
class_name PauseMenu

var value_sliders : Array # Sliders within the pause menu dislpay
var pmk : PlayerController # Player who owns this pause menu


## Find our ValueSlider nodes, and connect their signals
func _ready() -> void:
	# Find our PlayerController owner
	await owner.ready
	pmk = owner as PlayerController
	assert(pmk != null, "The PauseMenu node requires PlayerController as owner.")
	# Find all our ValueSlider nodes and connect their signals
	value_sliders = scik_utils.get_children_of_type(self, ValueSlider)
	for slider in value_sliders: slider.value_update.connect(_on_slider_update)


## Handles value_update signal from ValueSliders
func _on_slider_update(value, parameter : String):
	match(parameter):
		"master_vol":
			if(value == 0.0):
				AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
			else:
				AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)
				var new_vol = GameManager.volume_curve.sample_baked(value/100)
				#print(new_vol)
				AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"),(new_vol))
		"mouse_sense":
			pmk.camera_controller.mouse_sensitivity = value / 1000
		"cam_sense":
			pmk.camera_controller.camera_sensitivity = value / 10
		"aim_sense":
			pmk.camera_controller.aim_sensitivity = value / 25


## Handles quit/leave button
func _on_quit_button_pressed() -> void:
	get_tree().quit()


## Handles debug checkbox
func _on_gun_box_debug_toggled(toggled_on: bool) -> void:
	pmk.camera_controller.toggle_debug(toggled_on, "box")
func _on_gun_dot_debug_toggled(toggled_on: bool) -> void:
	pmk.camera_controller.toggle_debug(toggled_on, "dot")


## Handles ADS toggle
func _on_aim_toggle_button_toggled(toggled_on: bool) -> void:
	pmk.camera_controller.aim_toggle = toggled_on


## Handles crouch toggle
func _on_crouch_toggle_button_toggled(toggled_on: bool) -> void:
	pmk.crouch_toggle = toggled_on
