extends CanvasLayer
class_name PauseMenu

var value_sliders : Array
signal value_update(value, parameter : String)


## Find our ValueSlider nodes, and connect their signals
func _ready() -> void:
	# Handle ValueSlider nodes
	value_sliders = scik_utils.find_children_of_type(self, ValueSlider)
	for slider in value_sliders: slider.value_update.connect(_on_slider_update)


## Handles value_update signal from ValueSliders
func _on_slider_update(value, parameter : String):
	value_update.emit(value,parameter)


## Handles quit/leave button
func _on_quit_button_pressed() -> void:
	NetworkManager.leave_game()


## Handles debug checkbox
func _on_gun_box_debug_toggled(toggled_on: bool) -> void:
	value_update.emit(toggled_on, "debug_box")
func _on_gun_dot_debug_toggled(toggled_on: bool) -> void:
	value_update.emit(toggled_on, "debug_dot")


## Handles ADS toggle
func _on_aim_toggle_button_toggled(toggled_on: bool) -> void:
	value_update.emit(toggled_on, "aim_toggle")


## Handles crouch toggle
func _on_crouch_toggle_button_toggled(toggled_on: bool) -> void:
	value_update.emit(toggled_on,"crouch_toggle")
