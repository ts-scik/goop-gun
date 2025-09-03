extends CanvasLayer
class_name PauseMenu

var value_sliders : Array
@onready var debug_box : CheckBox = get_node("DebugBox")
signal value_update(value, parameter : String)


func _ready() -> void:
	# Handle ValueSlider nodes
	value_sliders = scik.find_children_of_type(self, ValueSlider)
	for slider in value_sliders: slider.value_update.connect(_on_slider_update)
	# Handle debug checkbox
	debug_box.toggled.connect(_on_checkbox_update.bind("debug"))


## Handles value_update signal from ValueSliders
func _on_slider_update(value, parameter : String):
	value_update.emit(value,parameter)


## Handles value checkboxes toggling
func _on_checkbox_update(is_toggled : bool, parameter : String):
	value_update.emit(is_toggled, parameter)
