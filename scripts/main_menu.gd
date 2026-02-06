extends Node2D

func _ready() -> void:
	$CenterContainer/SettingsButton.visible = false
	$CenterContainer/Credits.visible = false
	$CenterContainer/SettingsButton/Fullscreen.button_pressed = true if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN else false
	$CenterContainer/SettingsButton/Volume.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_settings_pressed() -> void:
	$CenterContainer/MenuButton.visible = false
	$CenterContainer/SettingsButton.visible = true



func _on_credits_pressed() -> void:
	$CenterContainer/MenuButton.visible = false
	$CenterContainer/Credits.visible = true


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_back_pressed() -> void:
	$CenterContainer/MenuButton.visible = true
	$CenterContainer/SettingsButton.visible = false
	$CenterContainer/Credits.visible = false


func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)


func _on_volume_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Master"), value)
