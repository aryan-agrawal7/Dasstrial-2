extends CanvasLayer

const SELECTION_MENU_SCENE := "res://game/ui/main_menu.tscn"

var _is_transitioning: bool = false


func _ready() -> void:
	# Ensure menu input works even if opened from a paused game.
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_open_selection_menu()


func _on_play_button_pressed() -> void:
	_open_selection_menu()


func _open_selection_menu() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	get_tree().change_scene_to_file(SELECTION_MENU_SCENE)
