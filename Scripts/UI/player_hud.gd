extends CanvasLayer
class_name PlayerHUD

@onready var healthbar = get_node("Base/Health")
@onready var scoreboard = get_node("Base/ScoreContainer")


func update_health(value : int):
	healthbar.value = value


func update_scores():
	var player_ids = GameManager.player_scores.keys()
	player_ids.sort()
	$Base/ScoreContainer/Players/ScoreList.clear()
	for p in player_ids:
		$Base/ScoreContainer/Players/ScoreList.add_item(NetworkManager.players_dict[p])
		$Base/ScoreContainer/Players/ScoreList.add_item(str(GameManager.player_scores[p]))
