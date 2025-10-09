## Class for magazines
class_name MagazineController extends Node3D

@export var mag_grip_point : Marker3D	# used to store point hand should grab at
@export var max_bullets : int = 6
var curr_bullets : int


## Sets curr_bullets to start value
func _ready() -> void:
	curr_bullets = max_bullets


## Attempts to remove a bullet
## Returns [false] if mag is already empty
## Returns [true] if sucessful
func remove_bullet() -> bool:
	if (curr_bullets <= 0):
		return false
	else:
		# TODO - animate bullet removal
		curr_bullets -= 1
		return true


## Attempts to add a bullet
## Returns [false] if mag is already full
## Returns [true] if sucessful
func add_bullet() -> bool:
	if (curr_bullets >= max_bullets):
		# TODO - play a little "can't add ammo!!" animation
		return false
	else:
		# TODO - play an animation of bullet entering mag
		curr_bullets += 1
		return true


## Check if there is any ammo left in the gun
## Returns [true] if yes, [false] if no
func has_ammo() -> bool:
	return (curr_bullets > 0)
