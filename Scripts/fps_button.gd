extends Button
class_name FPSButton

@export var framerate : int

func _pressed() -> void:
	if(framerate is int):
		Engine.max_fps = framerate
		print(Engine.max_fps)
	else:
		print("Invalid framerate!!")
