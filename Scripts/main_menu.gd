extends CanvasLayer

var value_sliders : Array
@onready var debug_box : CheckBox = get_node("DebugBox")
signal value_update(value, parameter : String)


func _ready() -> void:
	# Handle ValueSlider nodes
	value_sliders = find_children_of_type(self, ValueSlider)
	for slider in value_sliders: slider.value_update.connect(_on_slider_update)
	# Handle debug checkbox
	debug_box.toggled.connect(_on_checkbox_update.bind("debug"))


#TODO: move this elsewhere
## Find and return all nodes of type [target_type] in children of [parent] as array
func find_children_of_type(parent, target_type) -> Array:
	var child_array : Array = []
	find_children_of_type_helper(parent, target_type, child_array)
	return child_array
#TODO: move this elsewhere
## Recursive helper for find_children_of_type()
func find_children_of_type_helper(c_child, target_type, arr : Array) -> void:
	if is_instance_of(c_child, target_type):
		arr.append(c_child)
	else:
		for child in c_child.get_children():
			find_children_of_type_helper(child, target_type, arr)


## Handles value_update signal from ValueSliders
func _on_slider_update(value, parameter : String):
	value_update.emit(value,parameter)


## Handles value checkboxes toggling
func _on_checkbox_update(is_toggled : bool, parameter : String):
	value_update.emit(is_toggled, parameter)
