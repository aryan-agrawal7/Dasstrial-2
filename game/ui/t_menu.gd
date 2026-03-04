class_name TMenu
extends CanvasLayer

var panel: PanelContainer
var heal_btn: Button
var vis_btn: Button
var pod_btn: Button
var drill_btn: Button
var gold_btn: Button
var player: BasePlayer

func _init(p_player: BasePlayer):
	player = p_player
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100 # Above other UI
	
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	
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
	vbox.add_theme_constant_override("separation", 14)
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
	
	# 1. Iron → Heal Ship (hull integrity + hull temp)
	heal_btn = Button.new()
	heal_btn.text = "Heal Ship (5 Iron Ore)"
	heal_btn.custom_minimum_size = Vector2(0, 50)
	heal_btn.pressed.connect(_on_heal_pressed)
	_style_button(heal_btn, Color(0.2, 0.6, 0.3))
	vbox.add_child(heal_btn)
	
	# 2. Coal → Improve Visibility (reduce fog)
	vis_btn = Button.new()
	vis_btn.text = "Improve Visibility (5 Coal Ore)"
	vis_btn.custom_minimum_size = Vector2(0, 50)
	vis_btn.pressed.connect(_on_vis_pressed)
	_style_button(vis_btn, Color(0.6, 0.4, 0.2))
	vbox.add_child(vis_btn)
	
	# 3. Resource Pods → Heal Player (restore HP)
	pod_btn = Button.new()
	pod_btn.text = "Heal Player (2 Resource Pods)"
	pod_btn.custom_minimum_size = Vector2(0, 50)
	pod_btn.pressed.connect(_on_pod_pressed)
	_style_button(pod_btn, Color(0.2, 0.4, 0.8))
	vbox.add_child(pod_btn)
	
	# 4. Diamond → Sharpen Drill (increase drill efficiency)
	drill_btn = Button.new()
	drill_btn.text = "Sharpen Drill (2 Diamond Ore)"
	drill_btn.custom_minimum_size = Vector2(0, 50)
	drill_btn.pressed.connect(_on_drill_pressed)
	_style_button(drill_btn, Color(0.5, 0.8, 0.9))
	vbox.add_child(drill_btn)
	
	# 5. Gold → Boost Ore Spawns (increase all ore rates proportionally)
	gold_btn = Button.new()
	gold_btn.text = "Boost Ore Spawns (5 Gold Ore)"
	gold_btn.custom_minimum_size = Vector2(0, 50)
	gold_btn.pressed.connect(_on_gold_pressed)
	_style_button(gold_btn, Color(0.8, 0.7, 0.2))
	vbox.add_child(gold_btn)
	
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
	
	var pressed_style = normal.duplicate()
	pressed_style.bg_color = base_color.darkened(0.2)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
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

func _get_total_pods() -> int:
	return player.ore_counter.get_count_by_name("Water Pod") + player.ore_counter.get_count_by_name("Oxygen Pod")

func _update_buttons():
	heal_btn.disabled = player.ore_counter.get_count_by_name("iron_ore") < 5
	vis_btn.disabled = player.ore_counter.get_count_by_name("coal_ore") < 5 or player.visibility_level >= 3
	pod_btn.disabled = _get_total_pods() < 2
	drill_btn.disabled = player.ore_counter.get_count_by_name("diamond_ore") < 2 or player.drill_sharpness >= player.max_sharpness
	gold_btn.disabled = player.ore_counter.get_count_by_name("gold_ore") < 5

## Iron: Repair ship hull (+25 integrity, +25 hull temp)
func _on_heal_pressed():
	if player.ore_counter.get_count_by_name("iron_ore") >= 5:
		player.ore_counter.consume_raw("iron_ore", 5)
		player.hull_integrity = min(player.max_integrity, player.hull_integrity + 25)
		player.hull_temp = min(player.max_hull_temp, player.hull_temp + 25)
		_update_buttons()

## Coal: Improve visibility by 1 level (reduce fog)
func _on_vis_pressed():
	if player.ore_counter.get_count_by_name("coal_ore") >= 5 and player.visibility_level < 3:
		player.ore_counter.consume_raw("coal_ore", 5)
		player.increase_visibility()
		_update_buttons()

## Resource Pods: Heal the player (+30 HP)
func _on_pod_pressed():
	if _get_total_pods() >= 2:
		_consume_pods(2)
		player.health.hitpoints = min(player.health.max_hitpoints, player.health.hitpoints + 30)
		_update_buttons()

## Diamond: Sharpen drill (+25 sharpness)
func _on_drill_pressed():
	if player.ore_counter.get_count_by_name("diamond_ore") >= 2:
		player.ore_counter.consume_raw("diamond_ore", 2)
		player.drill_sharpness = min(player.max_sharpness, player.drill_sharpness + 25)
		_update_buttons()

## Gold: Boost all ore spawn rates proportionally
func _on_gold_pressed():
	if player.ore_counter.get_count_by_name("gold_ore") >= 5:
		player.ore_counter.consume_raw("gold_ore", 5)
		GameManager.ore_spawn_bonus = min(GameManager.ore_spawn_bonus + 0.03, 0.15)
		_update_buttons()

## Consume a number of pods, taking from whichever type is available
func _consume_pods(count: int):
	var remaining := count
	var water := player.ore_counter.get_count_by_name("Water Pod")
	var consume_water := mini(water, remaining)
	if consume_water > 0:
		player.ore_counter.consume_raw("Water Pod", consume_water)
		remaining -= consume_water
	if remaining > 0:
		player.ore_counter.consume_raw("Oxygen Pod", remaining)
