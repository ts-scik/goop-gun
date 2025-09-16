extends CanvasLayer


func _ready():
	# Called every time the node is added to the scene.
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.connection_succeeded.connect(_on_connection_success)
	NetworkManager.game_error.connect(_on_game_error)
	NetworkManager.game_ended.connect(_on_game_ended)
	NetworkManager.player_list_changed.connect(_refresh_lobby)
	NetworkManager.log_update.connect(_refresh_chatlog)
	NetworkManager.server_lost.connect(_on_server_lost)
	$Connect/IPAddress.text = NetworkManager.DEFAULT_IP_ADDRESS
	if OS.has_environment("USERNAME"):
		$Connect/Name.text = OS.get_environment("USERNAME")


## Handles hosting a lobby
func _on_server_pressed() -> void:
	# Verify username is valid
	if $Connect/Name.text == "":
		$Connect/ErrorLabel.text = "Invalid name!"
		return
	# Hide the Connect box
	$Connect.hide()
	$Connect/ErrorLabel.text = ""
	# Start the Server
	var player_name = $Connect/Name.text
	NetworkManager.start_server(player_name) 
	# Show and refresh the lobby
	$Lobby/Start.show()
	$Lobby.show()
	_refresh_lobby()


## Handles joining a lobby
func _on_client_pressed() -> void:
	# Verify username is valid
	if $Connect/Name.text == "":
		$Connect/ErrorLabel.text = "Invalid name!"
		return
	# Verify the IP is valid
	var ip = $Connect/IPAddress.text
	if not ip.is_valid_ip_address():
		ip = IP.resolve_hostname(ip, IP.TYPE_IPV4)
		print(ip)
	if not ip.is_valid_ip_address():
		$Connect/ErrorLabel.text = "Invalid IP address!"
		return
	# Hide the Connect box
	$Connect/ErrorLabel.text = ""
	$Connect/Server.disabled = true
	$Connect/Client.disabled = true
	# Start the Client
	var player_name = $Connect/Name.text
	NetworkManager.start_client(ip, player_name)
	# Set "Connecting" state
	$Connect/ErrorLabel.set_text("Connecting...")


## Handles successful lobby connection
func _on_connection_success():
	$Connect.hide()


## Handles lobby connection failure
func _on_connection_failed():
	$Connect/Server.disabled = false
	$Connect/Client.disabled = false
	$Connect/ErrorLabel.set_text("Connection failed!")


## Handles game errors
func _on_game_error(errtxt):
	$ErrorDialog.dialog_text = errtxt
	$ErrorDialog.popup_centered()
	$Connect/Server.disabled = false
	$Connect/Client.disabled = false


## Handles losing connection to server
func _on_server_lost():
	$Lobby.hide()
	$Connect.show()


## Handles end-of-game
func _on_game_ended():
	$Connect.show()
	$Connect/Server.disabled = false
	$Connect/Client.disabled = false
	$Connect/ErrorLabel.set_text("")


## Signal for server to signal to clients that the lobby should be hidden
@rpc("authority","call_local")
func _hide_lobby():
	$Lobby.hide()


## Refreshes player list
func _refresh_lobby():
	if(!GameManager.is_playing):
		$Lobby.show()
	var player_names = NetworkManager.get_player_list()
	player_names.sort()
	$Lobby/Players/List.clear()
	for p in player_names:
		$Lobby/Players/List.add_item(p)


## Handle starting the game
func _on_start_pressed():
	assert(multiplayer.is_server())
	$Lobby/Start.hide()
	_hide_lobby.rpc()
	NetworkManager.start_game()


## Handle the "leave lobby" button
func _on_leave_lobby_pressed() -> void:
	NetworkManager.peer.close()
	NetworkManager.players_dict.clear()
	$Lobby/Start.hide()
	$Lobby.hide()
	$Connect.show()
	$Connect/Server.disabled = false
	$Connect/Client.disabled = false
	$Connect/ErrorLabel.set_text("")


## Handles incoming log messages from server
func _refresh_chatlog(text : String) -> void:
	$Lobby/ChatLog.add_text(text+"\n")
