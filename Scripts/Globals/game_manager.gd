#class_name GameManager
extends Node

# Game state variables
var is_playing = false
var world_data : Array
var max_room_depth = 3
var local_player : PlayerController = null

# Volume variables
var volume_curve : Curve
var max_vol = 6.0
var min_vol = -40.0


func _ready() -> void:
	volume_curve = scik_utils.get_volume_curve(min_vol, max_vol)
