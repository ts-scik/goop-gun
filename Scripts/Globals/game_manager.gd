#class_name GameManager
extends Node

var is_playing = false
var world_data : Array

var volume_curve : Curve = Curve.new()
var max_vol = 6.0
var min_vol = -40.0
var max_room_depth = 5

func _ready() -> void:
	volume_curve.max_value = max_vol
	volume_curve.min_value = min_vol
	volume_curve.add_point(Vector2(0,min_vol))
	volume_curve.add_point(Vector2(0.5,0))
	volume_curve.add_point(Vector2(1.0,max_vol))
