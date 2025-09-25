class_name scik_utils


## Find and return all nodes of type [target_type] in children of [parent] as array
static func get_children_of_type(parent, target_type) -> Array:
	var child_array : Array = []
	get_children_of_type_helper(parent, target_type, child_array)
	return child_array


## Recursive helper for get_children_of_type()
static func get_children_of_type_helper(c_child, target_type, arr : Array) -> void:
	if is_instance_of(c_child, target_type):
		arr.append(c_child)
	else:
		for child in c_child.get_children():
			get_children_of_type_helper(child, target_type, arr)


## Rotates Vector3i [v] around [axis] by euler [angle]
static func Vector3i_rotated(v:Vector3i, axis:Vector3i, angle:float) -> Vector3i:
	var vP = Vector3(v)
	var vP_r = vP.rotated(Vector3(axis),deg_to_rad(angle))
	var vN = Vector3i()
	for i in 3:
		vN[i] = round(vP_r[i])
	return vN


## Returns a curve defined by points [(0,[min_vol]), (0.5,0), (0,[max_vol)]
## Intended for creating a curve to sample volume settings from
static func get_volume_curve(min_vol : float, max_vol: float) -> Curve:
	var volume_curve = Curve.new()
	volume_curve.max_value = max_vol
	volume_curve.min_value = min_vol
	volume_curve.add_point(Vector2(0,min_vol))
	volume_curve.add_point(Vector2(0.5,0))
	volume_curve.add_point(Vector2(1.0,max_vol))
	return volume_curve
