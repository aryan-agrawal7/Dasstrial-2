class_name TMenu
extends CanvasLayer

var panel: PanelContainer
var heal_btn: Button
var vis_btn: Button
var player: BasePlayer

func _init(p_player: BasePlayer):
	player = p_player
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100 # Above other UI
	
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	
	# Create a dark, slightly transparent background for the panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.hide()
	add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "- SHIP MAINTENANCE -"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_settings = LabelSettings.new()
	title_settings.font_size = 28
	title_settings.font_color = Color(0.9, 0.9, 1.0)
	title_settings.outline_size = 4
	title_settings.outline_color = Color.BLACK
	title_settings.shadow_size = 4
	title_settings.shadow_color = Color(0, 0, 0, 0.5)
	title.label_settings = title_settings
	vbox.add_child(title)
	
	# Add a tasteful separator
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	heal_btn = Button.new()
	heal_btn.text = "Heal Ship (5 Iron Ore)"
	heal_btn.custom_minimum_size = Vector2(0, 50)
	heal_btn.pressed.connect(_on_heal_pressed)
	_style_button(heal_btn, Color(0.2, 0.6, 0.3))
	vbox.add_child(heal_btn)
	
	vis_btn = Button.new()
	vis_btn.text = "Improve Visibility (5 Coal Ore)"
	vis_btn.custom_minimum_size = Vector2(0, 50)
	vis_btn.pressed.connect(_on_vis_pressed)
	_style_button(vis_btn, Color(0.6, 0.4, 0.2))
	vbox.add_child(vis_btn)
	
	# Add spacing before close button
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)
	
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 40)
	close_btn.pressed.connect(close)
	_style_button(close_btn, Color(0.3, 0.3, 0.3))
	vbox.add_child(close_btn)

func _style_button(btn: Button, base_color: Color):
	var normal = StyleBoxFlat.new()
	normal.bg_color = base_color
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", normal)
	
	var hover = normal.duplicate()
	hover.bg_color = base_color.lightened(0.2)
	btn.add_theme_stylebox_override("hover", hover)
	
	var pressed = normal.duplicate()
	pressed.bg_color = base_color.darkened(0.2)
	btn.add_theme_stylebox_override("pressed", pressed)
	
	var disabled = normal.duplicate()
	disabled.bg_color = Color(0.2, 0.2, 0.2, 0.5)
	btn.add_theme_stylebox_override("disabled", disabled)

func open():
	get_tree().paused = true
	panel.show()
	_update_buttons()

func close():
	panel.hide()
	get_tree().paused = false

func _update_buttons():
	heal_btn.disabled = player.ore_counter.get_count_by_name("iron_ore") < 5
	vis_btn.disabled = player.ore_counter.get_count_by_name("coal_ore") < 5 or player.visibility_level >= 3

func _on_heal_pressed():
	if player.ore_counter.get_count_by_name("iron_ore") >= 5:
		player.ore_counter.consume_raw("iron_ore", 5)
		# fully heal
		player.health.hitpoints = player.health.max_hitpoints
		player.hull_temp = player.max_hull_temp
		player.hull_integrity = player.max_integrity
		player.drill_sharpness = player.max_sharpness
		_update_buttons()

func _on_vis_pressed():
	if player.ore_counter.get_count_by_name("coal_ore") >= 5 and player.visibility_level < 3:
		player.ore_counter.consume_raw("coal_ore", 5)
		player.increase_visibility()
		_update_buttons()
