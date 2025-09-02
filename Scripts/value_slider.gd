extends Container
class_name ValueSlider

@onready var tooltip : Label = get_node("Tooltip")
@onready var slider : HSlider = get_node("Slider")
@onready var value : Label = get_node("Value")

@export var parameter : String = "default"
@export var tip_text : String = "Tooltip:"
@export var slider_range : Vector2 = Vector2(0.0, 10.0) # min, value, max
@export var slider_default : float = 5.0

signal value_update(value, parameter : String)

func _ready() -> void:
	slider.drag_ended.connect(_on_slider_update)
	update_config()


## Set up configured variables
func update_config() -> void:
	tooltip.text = str(tip_text)
	slider.min_value = slider_range.x
	slider.max_value = slider_range.y
	slider.value = slider_default
	value.text = str(slider.value)


## Manage slider updates
func _on_slider_update(value_changed: bool):
	# Early return if no change
	if(value_changed == false): return
	# Update text
	value.text = str(slider.value)
	# Emit the value
	value_update.emit(slider.value, parameter)
