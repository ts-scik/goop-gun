class_name GunCanvas
extends CanvasLayer

@export var boundary_rect : ReferenceRect
@export var red_dot : ColorRect

var debug_box : bool = false
var debug_dot : bool = false


## Updates rectangle size + dot position given new screen_size/gun_deadzone
func viewport_update(screen_size : Vector2, gun_deadzone : Vector3) -> void:
	var screen_midpoint := screen_size/2
	boundary_rect.size = Vector2(gun_deadzone.x*2, gun_deadzone.y + gun_deadzone.z)
	boundary_rect.position = screen_midpoint - Vector2(gun_deadzone.x, gun_deadzone.y)
	update_dot_pos(screen_midpoint)


## Takes [pos], updates red_dot to that spot on the screen
func update_dot_pos(pos : Vector2):
	red_dot.position = pos - (red_dot.size/2)


## Takes [clr], updates red_dot color to match
func update_dot_color(clr : Color):
	red_dot.color = clr


## Toggles debug UI + element display
func display_toggle(n_debug_box : bool, n_debug_dot : bool) -> void:
	debug_box = n_debug_box
	debug_dot = n_debug_dot
	if(debug_box or debug_dot):
		self.show()
	else:
		self.hide()
	if(debug_box):
		boundary_rect.show()
	else:
		boundary_rect.hide()
	if(debug_dot):
		red_dot.show()
	else:
		red_dot.hide()
