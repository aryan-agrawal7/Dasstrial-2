extends CanvasLayer

## Pixel-art pause menu overlay. Autoloaded so it works from any game scene.
## Buttons drop in from the top like a rope ladder falling.
## Two side ropes run from the top of the screen down through the buttons.

@onready var panel: CenterContainer = $CenterContainer
@onready var button_container: VBoxContainer = $CenterContainer/VBoxContainer
@onready var settings_overlay: CenterContainer = $CenterContainer/SettingsOverlay

# --- Layout constants (must match .tscn values) ---
const BUTTON_WIDTH := 352.0
const BUTTON_HEIGHT := 70.0
const BUTTON_GAP := 16.0
const BUTTON_COUNT := 4
const ROPE_WIDTH := 10.0
const ROPE_INSET := 40.0  # distance from button edge to rope center

var _drop_tween: Tween
var _left_rope: Panel
var _right_rope: Panel
var _rope_style: StyleBoxFlat


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_rope_style()
	_create_side_ropes()
	hide_menu()


func _create_rope_style() -> void:
	_rope_style = StyleBoxFlat.new()
	_rope_style.bg_color = Color(0.243, 0.129, 0.063, 1.0)
	_rope_style.corner_radius_top_left = 4
	_rope_style.corner_radius_top_right = 4
	_rope_style.corner_radius_bottom_left = 4
	_rope_style.corner_radius_bottom_right = 4


func _create_side_ropes() -> void:
	_left_rope = Panel.new()
	_left_rope.add_theme_stylebox_override("panel", _rope_style)
	_left_rope.z_index = -1
	add_child(_left_rope)

	_right_rope = Panel.new()
	_right_rope.add_theme_stylebox_override("panel", _rope_style)
	_right_rope.z_index = -1
	add_child(_right_rope)

	_left_rope.visible = false
	_right_rope.visible = false


func _calc_layout() -> Dictionary:
	## Returns pre-calculated layout positions based on known constants.
	var vp_size := get_viewport().get_visible_rect().size
	var total_h := BUTTON_COUNT * BUTTON_HEIGHT + (BUTTON_COUNT - 1) * BUTTON_GAP
	var center_x := vp_size.x / 2.0
	var center_y := vp_size.y / 2.0
	var first_button_top := center_y - total_h / 2.0
	var last_button_bottom := center_y + total_h / 2.0

	# Button positions within VBoxContainer (relative to the VBox origin)
	var button_positions: Array[float] = []
	for i in BUTTON_COUNT:
		button_positions.append(float(i) * (BUTTON_HEIGHT + BUTTON_GAP))

	return {
		"vp_size": vp_size,
		"center_x": center_x,
		"first_button_top": first_button_top,
		"last_button_bottom": last_button_bottom,
		"button_positions": button_positions,
	}


func _position_ropes(layout: Dictionary) -> void:
	var center_x: float = layout.center_x
	var first_top: float = layout.first_button_top
	var last_bottom: float = layout.last_button_bottom

	var rope_left_x := center_x - BUTTON_WIDTH / 2.0 + ROPE_INSET - ROPE_WIDTH / 2.0
	var rope_right_x := center_x + BUTTON_WIDTH / 2.0 - ROPE_INSET - ROPE_WIDTH / 2.0
	var rope_height := last_bottom  # from top of screen (y=0) to bottom of last button

	_left_rope.position = Vector2(rope_left_x, 0)
	_left_rope.size = Vector2(ROPE_WIDTH, rope_height)
	_right_rope.position = Vector2(rope_right_x, 0)
	_right_rope.size = Vector2(ROPE_WIDTH, rope_height)


# --- Input ---

func _unhandled_key_input(event: InputEvent):
	var key_event: InputEventKey = event
	if key_event.is_pressed() and key_event.keycode == KEY_ESCAPE:
		if settings_overlay.visible:
			_on_settings_back_pressed()
		elif GameManager.is_ingame():
			toggle_pause()
		else:
			get_tree().quit()
		get_viewport().set_input_as_handled()


# --- Pause / Resume ---

func toggle_pause():
	if panel.visible:
		resume()
	else:
		pause()


func pause():
	get_tree().paused = true
	GameTimer.stop_timer()
	settings_overlay.hide()
	button_container.show()
	panel.show()
	_play_drop_animation()


func resume():
	if _drop_tween:
		_drop_tween.kill()
	_left_rope.visible = false
	_right_rope.visible = false
	panel.hide()
	settings_overlay.hide()
	GameTimer.start_timer()
	get_tree().paused = false


func hide_menu():
	panel.hide()
	if _left_rope:
		_left_rope.visible = false
	if _right_rope:
		_right_rope.visible = false


# --- Drop Animation (pre-calculated positions, no await) ---

func _play_drop_animation():
	if _drop_tween:
		_drop_tween.kill()

	var layout := _calc_layout()
	var button_positions: Array = layout.button_positions
	var buttons := button_container.get_children()

	# Position ropes and hide them for animation
	_position_ropes(layout)
	_left_rope.visible = true
	_right_rope.visible = true
	_left_rope.modulate.a = 0.0
	_right_rope.modulate.a = 0.0

	# Offset all buttons above screen
	for i in buttons.size():
		var btn = buttons[i]
		btn.position.y = button_positions[i] - 600.0
		btn.modulate.a = 0.0

	# Create tween that runs while paused
	_drop_tween = create_tween()
	_drop_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_drop_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	# Fade in ropes first
	_drop_tween.tween_property(_left_rope, "modulate:a", 1.0, 0.15)
	_drop_tween.parallel().tween_property(_right_rope, "modulate:a", 1.0, 0.15)

	# Drop each button sequentially
	var delay := 0.15  # after rope fade-in
	for i in buttons.size():
		var btn = buttons[i]
		var target_y: float = button_positions[i]

		_drop_tween.parallel().tween_property(
			btn, "modulate:a", 1.0, 0.18
		).set_delay(delay)

		_drop_tween.parallel().tween_property(
			btn, "position:y", target_y, 0.22
		).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		delay += 0.10


# --- Button Handlers ---

func _on_resume_button_pressed():
	resume()


func _on_home_button_pressed():
	if _drop_tween:
		_drop_tween.kill()
	_left_rope.visible = false
	_right_rope.visible = false
	panel.hide()
	settings_overlay.hide()
	get_tree().paused = false
	GameManager.load_main_menu()


func _on_menu_button_pressed():
	button_container.hide()
	_left_rope.visible = false
	_right_rope.visible = false
	settings_overlay.show()


func _on_exit_button_pressed():
	get_tree().quit()


func _on_settings_back_pressed():
	settings_overlay.hide()
	button_container.show()
	_left_rope.visible = true
	_right_rope.visible = true
	_play_drop_animation()
