extends CanvasLayer

@export var debug_spawner : MultiplayerSpawner

func _ready():
	# Called every time the node is added to the scene.
	NetworkHandler.connection_failed.connect(_on_connection_failed)
	NetworkHandler.connection_succeeded.connect(_on_connection_success)
	NetworkHandler.game_error.connect(_on_game_error)
	NetworkHandler.game_ended.connect(_on_game_ended)
	NetworkHandler.player_list_changed.connect(_refresh_lobby)
	$Connect/IPAddress.text = NetworkHandler.DEFAULT_IP_ADDRESS
	if OS.has_environment("USERNAME"):
		$Connect/Name.text = OS.get_environment("USERNAME")


## Handles hosting a lobby
func _on_server_pressed() -> void:
	if $Connect/Name.text == "":
		$Connect/ErrorLabel.text = "Invalid name!"
		return

	$Connect.hide()
	$Connect/ErrorLabel.text = ""

	var player_name = $Connect/Name.text
	NetworkHandler.start_server(player_name)
	$Lobby/Start.show()
	$Lobby.show()
	_refresh_lobby()


## Handles joining a lobby
func _on_client_pressed() -> void:
	if $Connect/Name.text == "":
		$Connect/ErrorLabel.text = "Invalid name!"
		return

	var ip = $Connect/IPAddress.text
	if not ip.is_valid_ip_address():
		ip = IP.resolve_hostname(ip, IP.TYPE_IPV4)
		print(ip)
	if not ip.is_valid_ip_address():
		$Connect/ErrorLabel.text = "Invalid IP address!"
		return

	$Connect/ErrorLabel.text = ""
	$Connect/Server.disabled = true
	$Connect/Client.disabled = true
	
	var player_name = $Connect/Name.text
	NetworkHandler.start_client(ip, player_name)
	
	$Connect/ErrorLabel.set_text("Connecting...")


## Handles successful lobby connection
func _on_connection_success():
	$Connect.hide()
	if(!GameManager.is_playing):
		$Lobby.show()


## Handles lobby connection failure
func _on_connection_failed():
	$Connect/Server.disabled = false
	$Connect/Client.disabled = false
	$Connect/ErrorLabel.set_text("Connection failed!")


func _on_game_error(errtxt):
	$ErrorDialog.dialog_text = errtxt
	$ErrorDialog.popup_centered()
	$Connect/Server.disabled = false
	$Connect/Client.disabled = false
	#$Connect.show()


## Handles end-of-game
func _on_game_ended():
	$Connect.show()
	$Connect/Server.disabled = false
	$Connect/Client.disabled = false
	$Connect/ErrorLabel.set_text("")


## Signal for server to signal to clients that the lobby should be hidden
@rpc("authority","call_local")
func _hide_lobby(passed_scores):
	$Lobby.hide()
	GameManager.is_playing = true
	GameManager.player_scores = passed_scores


## Refreshes player list
func _refresh_lobby():
	if(multiplayer.is_server() and GameManager.is_playing):
		_hide_lobby.rpc(GameManager.player_scores)
	
	var player_names = NetworkHandler.get_player_list()
	player_names.sort()
	$Lobby/Players/List.clear()
	for p in player_names:
		$Lobby/Players/List.add_item(p)


## Handle starting the game
func _on_start_pressed():
	$Lobby/Start.hide()
	_hide_lobby.rpc(GameManager.player_scores)
	assert(multiplayer.is_server())
	GameManager.is_playing = true
	for player in NetworkHandler.players:
		debug_spawner.spawn_player(player)


## Handle the "leave lobby" button
func _on_leave_lobby_pressed() -> void:
	multiplayer.set_multiplayer_peer(null)
	NetworkHandler.players.clear()
	$Lobby/Start.hide()
	$Lobby.hide()
	$Connect.show()
	$Connect/Server.disabled = false
	$Connect/Client.disabled = false
	$Connect/ErrorLabel.set_text("")
