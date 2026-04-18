extends CanvasLayer

const SELECTION_MENU_SCENE := "res://game/ui/main_menu.tscn"

var _is_transitioning: bool = false
@onready var _play_button: Button = %"Play Button"


func _ready() -> void:
	# Ensure menu input works even if opened from a paused game.
	get_tree().paused = false
	_setup_play_button_fx()


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


func _setup_play_button_fx() -> void:
	if not _play_button:
		return

	_play_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var normal := _play_button.get_theme_stylebox("normal")
	if normal is StyleBoxFlat:
		var hover: StyleBoxFlat = normal.duplicate()
		hover.bg_color = hover.bg_color.lightened(0.18)
		hover.border_color = hover.border_color.lightened(0.2)
		_play_button.add_theme_stylebox_override("hover", hover)
		_play_button.add_theme_stylebox_override("focus", hover)

		var pressed: StyleBoxFlat = normal.duplicate()
		pressed.bg_color = pressed.bg_color.darkened(0.12)
		_play_button.add_theme_stylebox_override("pressed", pressed)

	_play_button.mouse_entered.connect(func(): _tween_play_button(Vector2(1.04, 1.04), 0.08))
	_play_button.mouse_exited.connect(func(): _tween_play_button(Vector2.ONE, 0.08))
	_play_button.button_down.connect(func(): _tween_play_button(Vector2(0.96, 0.96), 0.06))
	_play_button.button_up.connect(func():
		var target := Vector2.ONE
		if _play_button.is_hovered():
			target = Vector2(1.04, 1.04)
		_tween_play_button(target, 0.07)
	)


func _tween_play_button(target: Vector2, duration: float) -> void:
	if not _play_button:
		return
	_play_button.pivot_offset = _play_button.size / 2.0
	var existing: Tween = _play_button.get_meta("fx_tween") if _play_button.has_meta("fx_tween") else null
	if existing:
		existing.kill()
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(_play_button, "scale", target, duration)
	_play_button.set_meta("fx_tween", tw)
