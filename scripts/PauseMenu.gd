extends CanvasLayer

@onready var continue_button = $ColorRect/VBoxContainer/Continue
@onready var exit_button = $ColorRect/VBoxContainer/Exit

func _ready() -> void:
	continue_button.grab_focus()

func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event.is_action_pressed("escape"):
		get_tree().call_group("game_manager", "toggle_pause")
