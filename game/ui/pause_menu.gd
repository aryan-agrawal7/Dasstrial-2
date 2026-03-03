extends CanvasLayer

## Pause menu overlay. Autoloaded so it works from any game scene.
## Intercepts ESC to pause instead of quitting.

@onready var panel: CenterContainer = $CenterContainer


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide_menu()


func _unhandled_key_input(event: InputEvent):
	var key_event: InputEventKey = event
	if key_event.is_pressed() and key_event.keycode == KEY_ESCAPE:
		if GameManager.is_ingame():
			toggle_pause()
		else:
			get_tree().quit()
		get_viewport().set_input_as_handled()


func toggle_pause():
	if panel.visible:
		resume()
	else:
		pause()


func pause():
	get_tree().paused = true
	GameTimer.stop_timer()
	panel.show()


func resume():
	panel.hide()
	GameTimer.start_timer()
	get_tree().paused = false


func hide_menu():
	panel.hide()


func _on_resume_button_pressed():
	resume()


func _on_main_menu_button_pressed():
	panel.hide()
	get_tree().paused = false
	GameManager.load_main_menu()


func _on_quit_button_pressed():
	get_tree().quit()
