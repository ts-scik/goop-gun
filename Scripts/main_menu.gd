extends CanvasLayer

# TODO: this is a MESS oh golly

var slider_prestring = "MenuContainer/SliderMargins/SlidersContainer/"

@onready var cam_sense_container = get_node(slider_prestring+"Cam_Sense_Con")
@onready var cam_sense_slider : HSlider = get_node(slider_prestring+"Cam_Sense_Con/Sense_Slider")
@onready var cam_sense_value = get_node(slider_prestring+"Cam_Sense_Con/Slider_Value")

@onready var aim_sense_container = get_node(slider_prestring+"Aim_Sense_Con")
@onready var aim_sense_slider : HSlider = get_node(slider_prestring+"Aim_Sense_Con/Sense_Slider")
@onready var aim_sense_value = get_node(slider_prestring+"Aim_Sense_Con/Slider_Value")

@onready var volume_container = get_node(slider_prestring+"Volume_Con")
@onready var vol_slider : HSlider = get_node(slider_prestring+"Volume_Con/Volume_Slider")
@onready var vol_value = get_node(slider_prestring+"Volume_Con/Slider_Value")

@onready var debug_box : CheckBox = get_node("DebugBox")

signal value_update(value, parameter : String)

func _ready() -> void:
	cam_sense_slider.drag_ended.connect(_on_slider_update.bind(cam_sense_slider, "cam_sense"))
	aim_sense_slider.drag_ended.connect(_on_slider_update.bind(aim_sense_slider, "aim_sense"))
	vol_slider.drag_ended.connect(_on_slider_update.bind(vol_slider, "vol_master"))
	debug_box.toggled.connect(_on_checkbox_update.bind("debug"))

func _on_slider_update(value_changed: bool, slider : HSlider, parameter : String):
	if(value_changed == false): return
	var value = slider.value
	match(parameter):
		"cam_sense":
			cam_sense_value.text = str(value)
			value_update.emit(value, parameter)
		"aim_sense":
			aim_sense_value.text = str(value)
			value_update.emit(value, parameter)
		"vol_master":
			vol_value.text = str(value)
			value_update.emit(value, parameter)

func _on_checkbox_update(is_toggled : bool, parameter : String):
	value_update.emit(is_toggled, parameter)
