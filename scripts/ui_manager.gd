extends Control

signal StartGame

func _ready() -> void:
	$Control/GameOverPanel.hide()
	var game_manager = get_parent()
	if game_manager:
		if game_manager.has_signal("ScoreUpdated"):
			if not game_manager.is_connected("ScoreUpdated", Callable(self, "_on_game_manager_score_updated")):
				game_manager.connect("ScoreUpdated", Callable(self, "_on_game_manager_score_updated"))
		if game_manager.has_signal("GameOver"):
			if not game_manager.is_connected("GameOver", Callable(self, "_on_game_manager_game_over")):
				game_manager.connect("GameOver", Callable(self, "_on_game_manager_game_over"))

func _on_game_manager_score_updated(score: int) -> void:
	$RichTextScore.text = str(score)

func _on_game_manager_game_over(score: int) -> void:
	$Control/GameOverPanel.show()
	$Control/GameOverPanel/score.text = "Score: " + str(score)

func _on_retry_button_button_down() -> void:
	$Control/GameOverPanel.hide()
	StartGame.emit()

func _on_menu_button_button_down() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
