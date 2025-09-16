extends MultiplayerSynchronizer

func _enter_tree() -> void:
	self.add_visibility_filter(_check_is_in_network)
	

func _check_is_in_network(client_pid : int):
	return true
	#return NetworkManager.players_dict.keys().has(client_pid)
	#return NetworkManager.players_ready.has(client_pid)
