extends CanvasLayer

@export var debug_spawner : MultiplayerSpawner

func _ready():
	# Called every time the node is added to the scene.
	NetworkHandler.connection_failed.connect(_on_connection_failed)
	NetworkHandler.connection_succeeded.connect(_on_connection_success)
	NetworkHandler.game_error.connect(_on_game_error)
	$Connect/IPAddress.text = NetworkHandler.DEFAULT_IP_ADDRESS
	if OS.has_environment("USERNAME"):
		$Connect/Name.text = OS.get_environment("USERNAME")


func _on_server_pressed() -> void:
	if $Connect/Name.text == "":
		$Connect/ErrorLabel.text = "Invalid name!"
		return

	$Connect.hide()
	$Connect/ErrorLabel.text = ""

	var player_name = $Connect/Name.text
	NetworkHandler.start_server(player_name)
	debug_spawner.spawn_player(multiplayer.get_unique_id())
	#refresh_lobby()

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


func _on_connection_success():
	$Connect.hide()


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
