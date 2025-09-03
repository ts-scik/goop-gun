extends CanvasLayer

@export var debug_spawner : MultiplayerSpawner

func _on_server_pressed() -> void:
	NetworkHandler.start_server()
	debug_spawner.spawn_player(multiplayer.get_unique_id())
	self.hide()


func _on_client_pressed() -> void:
	NetworkHandler.start_client()
	self.hide()
