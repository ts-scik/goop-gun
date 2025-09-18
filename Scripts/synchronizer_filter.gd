extends MultiplayerSynchronizer


## Set up visibility filter
func _enter_tree() -> void:
	#self.add_visibility_filter(_check_is_in_network)
	pass


## Custom visibility filter
func _check_is_in_network(client_pid : int):
	#TODO: whyyyyyy why doesn't this workkkkk whyyyyyyy
	if(GameManager.is_playing) and (NetworkManager.players_loaded.has(client_pid)):
		return true
	else:
		return false
	# and why does the below sometimes work instead??
	#return NetworkManager.players_loaded.has(client_pid)
