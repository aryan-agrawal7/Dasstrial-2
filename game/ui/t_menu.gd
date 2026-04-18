class_name TMenu
extends CanvasLayer

const UPGRADE_SFX: AudioStream = preload("res://game/audio/sounds/upgrade.ogg")
const UPGRADE_SFX_BOOST_DB: float = 4.0

## Pixel-art ship maintenance menu with 5 upgrade slots.
## Layout: T-menu.png background (512px) with 5 columns of
## [upgrade arrow] → [icon] → [cost label].

# --- Preloaded textures ---
var _tex_bg := preload("res://game/ui/T-menu.png")
var _tex_close := preload("res://game/ui/X.png")
var _tex_upgrade := preload("res://game/ui/upgrade.png")
var _tex_health := preload("res://game/ui/HEALTH.png")
var _tex_vision := preload("res://game/ui/VISION.png")
var _tex_temp := preload("res://game/ui/temperature.png")
var _tex_sharp := preload("res://game/ui/sharpness.png")
var _tex_integ := preload("res://game/ui/SHIP-HEALTH.png")

const ICON_SIZE := 96
const BG_WIDTH := 768

var player: BasePlayer
var _root: Control          # full-screen root for centering
var _bg: TextureRect        # T-menu.png background
var _close_btn: TextureButton
var _upgrade_btns: Array[TextureButton] = []
var _upgrade_icons: Array[TextureRect] = []
var _cost_labels: Array[Label] = []

# Upgrade config: [icon_tex, cost_text, check_callable, action_callable]
var _upgrades: Array = []


func _init(p_player: BasePlayer):
	player = p_player
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	_build_upgrade_config()
	_build_ui()


func _build_upgrade_config():
	_upgrades = [
		{
			"icon": _tex_health,
			"cost_text": "2x Oxy\n1x Water",
			"can_use": func() -> bool:
				return player.ore_counter.get_count_by_name("Oxygen Pod") >= 2 \
					and player.ore_counter.get_count_by_name("Water Pod") >= 1,
			"action": func():
				player.ore_counter.consume_raw("Oxygen Pod", 2)
				player.ore_counter.consume_raw("Water Pod", 1)
				player.health.hitpoints = min(player.health.max_hitpoints, player.health.hitpoints + 40),
		},
		{
			"icon": _tex_vision,
			"cost_text": "2x Coal",
			"can_use": func() -> bool:
				return player.ore_counter.get_count_by_name("coal_ore") >= 2 \
					and player.visibility_level < 3,
			"action": func():
				player.ore_counter.consume_raw("coal_ore", 2)
				player.increase_visibility(),
		},
		{
			"icon": _tex_temp,
			"cost_text": "2x Water",
			"can_use": func() -> bool:
				return player.ore_counter.get_count_by_name("Water Pod") >= 2,
			"action": func():
				player.ore_counter.consume_raw("Water Pod", 2)
				player.hull_temp = min(player.max_hull_temp, player.hull_temp + 20),
		},
		{
			"icon": _tex_sharp,
			"cost_text": "2x Dia",
			"can_use": func() -> bool:
				return player.ore_counter.get_count_by_name("diamond_ore") >= 2 \
					and player.drill_sharpness < player.max_sharpness,
			"action": func():
				player.ore_counter.consume_raw("diamond_ore", 2)
				player.drill_sharpness = min(player.max_sharpness, player.drill_sharpness + 25),
		},
		{
			"icon": _tex_integ,
			"cost_text": "2x Iron",
			"can_use": func() -> bool:
				return player.ore_counter.get_count_by_name("iron_ore") >= 2,
			"action": func():
				player.ore_counter.consume_raw("iron_ore", 2)
				player.hull_integrity = min(player.max_integrity, player.hull_integrity + 25),
		},
	]


func _build_ui():
	# --- Full-screen root for centering ---
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP  # block clicks behind menu
	_root.hide()
	add_child(_root)

	# --- Dim background ---
	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.5)
	_root.add_child(dim)

	# --- CenterContainer to center everything ---
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	# --- Main container (holds bg + content) ---
	var main_container = Control.new()
	main_container.custom_minimum_size = Vector2(BG_WIDTH, BG_WIDTH * 0.75)
	center.add_child(main_container)

	# --- Background texture ---
	_bg = TextureRect.new()
	_bg.texture = _tex_bg
	_bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_container.add_child(_bg)

	# --- Close button (top-right) ---
	_close_btn = TextureButton.new()
	_close_btn.texture_normal = _tex_close
	_close_btn.ignore_texture_size = true
	_close_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_close_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_close_btn.custom_minimum_size = Vector2(45, 45)
	_close_btn.size = Vector2(45, 45)
	_close_btn.position = Vector2(BG_WIDTH - 55, 8)
	_close_btn.pressed.connect(close)
	main_container.add_child(_close_btn)
	_wire_tmenu_hover_fx(_close_btn, 1.08)

	# --- Upgrades row ---
	# We position 5 columns evenly across the background width.
	# Each column: arrow (64×64) on top, icon (64×64) below, cost label below icon.
	var num_slots: int = _upgrades.size()
	var slot_width: float = float(BG_WIDTH) / num_slots  # ~102px each
	var icon_y: float = main_container.custom_minimum_size.y * 0.48  # icons vertically centered-ish
	var arrow_y: float = icon_y - ICON_SIZE - 12  # arrows above icons

	for i in num_slots:
		var slot_center_x := slot_width * i + slot_width / 2.0

		# --- Upgrade arrow button ---
		var arrow_btn = TextureButton.new()
		arrow_btn.texture_normal = _tex_upgrade
		arrow_btn.ignore_texture_size = true
		arrow_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		arrow_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		arrow_btn.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		arrow_btn.size = Vector2(ICON_SIZE, ICON_SIZE)
		arrow_btn.position = Vector2(slot_center_x - ICON_SIZE / 2.0, arrow_y)
		arrow_btn.pressed.connect(_on_upgrade_pressed.bind(i))
		_wire_tmenu_hover_fx(arrow_btn, 1.04)
		main_container.add_child(arrow_btn)
		_upgrade_btns.append(arrow_btn)

		# --- Icon ---
		var icon = TextureRect.new()
		icon.texture = _upgrades[i].icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.position = Vector2(slot_center_x - ICON_SIZE / 2.0, icon_y)
		main_container.add_child(icon)
		_upgrade_icons.append(icon)

		# --- Cost label ---
		var lbl = Label.new()
		lbl.text = _upgrades[i].cost_text
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.position = Vector2(slot_center_x - slot_width / 2.0, icon_y + ICON_SIZE + 6)
		lbl.size = Vector2(slot_width, 60)
		var lbl_settings = LabelSettings.new()
		lbl_settings.font_size = 16
		lbl_settings.font_color = Color(1.0, 1.0, 1.0)
		lbl_settings.outline_size = 4
		lbl_settings.outline_color = Color.BLACK
		lbl.label_settings = lbl_settings
		main_container.add_child(lbl)
		_cost_labels.append(lbl)


# --- Open / Close ---

func open():
	get_tree().paused = true
	_root.show()
	_update_buttons()


func close():
	_root.hide()
	get_tree().paused = false


# --- Upgrade logic ---

func _on_upgrade_pressed(index: int):
	var upg = _upgrades[index]
	if upg.can_use.call():
		var btn := _upgrade_btns[index]
		_play_click_anim(btn)
		_play_upgrade_sfx()
		upg.action.call()
		_update_buttons()


func _play_upgrade_sfx():
	if is_instance_valid(SoundPlayer) and SoundPlayer.has_method("play_stream"):
		SoundPlayer.play_stream(UPGRADE_SFX, UPGRADE_SFX_BOOST_DB)


func _play_click_anim(btn: TextureButton):
	btn.pivot_offset = btn.size / 2.0
	var tw = create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(btn, "scale", Vector2(0.7, 0.7), 0.08).set_ease(Tween.EASE_IN)
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _wire_tmenu_hover_fx(btn: TextureButton, hover_scale: float) -> void:
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.mouse_entered.connect(func():
		if btn.disabled:
			return
		_tween_tmenu_hover(btn, Vector2(hover_scale, hover_scale), Color(1.1, 1.1, 1.1, 1.0), 0.08)
	)
	btn.mouse_exited.connect(func():
		if btn.disabled:
			return
		_tween_tmenu_hover(btn, Vector2.ONE, Color.WHITE, 0.08)
	)


func _tween_tmenu_hover(btn: TextureButton, target_scale: Vector2, target_modulate: Color, duration: float) -> void:
	btn.pivot_offset = btn.size / 2.0
	var existing: Tween = btn.get_meta("hover_tween") if btn.has_meta("hover_tween") else null
	if existing:
		existing.kill()
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", target_scale, duration)
	tw.parallel().tween_property(btn, "modulate", target_modulate, duration)
	btn.set_meta("hover_tween", tw)


func _update_buttons():
	for i in _upgrades.size():
		var can := _upgrades[i].can_use.call() as bool
		var btn := _upgrade_btns[i]
		if can:
			btn.disabled = false
			btn.modulate = Color.WHITE
		else:
			btn.disabled = true
			btn.modulate = Color(0.3, 0.3, 0.3, 0.5)


# --- Gold (kept for future UI integration) ---

func _on_gold_pressed():
	if player.ore_counter.get_count_by_name("gold_ore") >= 5:
		player.ore_counter.consume_raw("gold_ore", 5)
		GameManager.ore_spawn_bonus = min(GameManager.ore_spawn_bonus + 0.03, 0.15)
		_play_upgrade_sfx()
		_update_buttons()
