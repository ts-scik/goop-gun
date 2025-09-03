extends Node
class_name scik_utils


## Find and return all nodes of type [target_type] in children of [parent] as array
func find_children_of_type(parent, target_type) -> Array:
	var child_array : Array = []
	find_children_of_type_helper(parent, target_type, child_array)
	return child_array


## Recursive helper for find_children_of_type()
func find_children_of_type_helper(c_child, target_type, arr : Array) -> void:
	if is_instance_of(c_child, target_type):
		arr.append(c_child)
	else:
		for child in c_child.get_children():
			find_children_of_type_helper(child, target_type, arr)
