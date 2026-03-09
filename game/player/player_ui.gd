## Simplified player UI: shows ore counters (top-right) and health bar.
## Replaces the full hotbar/inventory/crafting/build menu system.
class_name UI
extends CanvasLayer


@export var health: HealthComponent


@onready var player: BasePlayer = get_parent()
@onready var health_bar: GaugeDial = %"Player Health"
@onready var hull_temp: GaugeDial = %"Hull Temperature"
@onready var hull_integrity: GaugeDial = %"Hull Integrity"
@onready var drill_sharpness: GaugeDial = %"Drill Sharpness"
@onready var ore_container: VBoxContainer = %"Ore Container"
@onready var interaction_hint: Label = %"Interaction Hint"


## References to ore count labels, keyed by ore item name
var ore_labels: Dictionary = {}



## Red screen-edge vignette overlay
var danger_vignette: ColorRect
var vignette_material: ShaderMaterial

## Touch control buttons
var _left_btn: Button
var _right_btn: Button
var _upgrade_btn: Button


func _ready():
	assert(player)
	assert(health)

	# Build the red vignette overlay (full-screen, above everything)
	_build_danger_vignette()

	# Build touch control buttons for mobile
	_build_touch_controls()

	# Defer building the ore display — the player's _ready() hasn't run yet
	# (children are ready before parents in Godot), so ore_counter.ore_items
	# is still empty at this point. call_deferred ensures it runs next frame.
	call_deferred("_build_ore_display")
	call_deferred("_connect_ore_counter")


func _process(_delta):
	update_health()
	update_subsystems()
	_update_danger_vignette()


func _connect_ore_counter():
	player.ore_counter.updated.connect(_update_ore_display)


func _build_ore_display():
	## Create a row for each registered ore: [icon] [count]
	for item in player.ore_counter.ore_items:
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)

		var icon := TextureRect.new()
		icon.texture = item.texture
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(32, 32)
		hbox.add_child(icon)

		var label := Label.new()
		label.text = "0"
		var settings := LabelSettings.new()
		settings.font_size = 22
		settings.font_color = Color.WHITE
		settings.outline_size = 3
		settings.outline_color = Color.BLACK
		label.label_settings = settings
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(label)

		ore_container.add_child(hbox)
		ore_labels[item.name] = label


func _update_ore_display():
	for item in player.ore_counter.ore_items:
		if item.name in ore_labels:
			ore_labels[item.name].text = str(player.ore_counter.get_count(item))


func update_health():
	var ratio: float = health.hitpoints / health.max_hitpoints
	health_bar.gauge_value = ratio * 100.0





func _build_danger_vignette() -> void:
	var shader := Shader.new()
	shader.code = "
	shader_type canvas_item;
	uniform float intensity : hint_range(0.0, 1.0) = 0.0;
	void fragment() {
		vec2 uv = UV;
		float dx = max(0.0, 0.3 - uv.x) / 0.3;
		float dy = max(0.0, 0.3 - uv.y) / 0.3;
		float dx2 = max(0.0, uv.x - 0.7) / 0.3;
		float dy2 = max(0.0, uv.y - 0.7) / 0.3;
		float edge = max(max(dx, dx2), max(dy, dy2));
		edge = pow(edge, 1.5);
		COLOR = vec4(1.0, 0.05, 0.0, edge * intensity);
	}
	"
	vignette_material = ShaderMaterial.new()
	vignette_material.shader = shader
	vignette_material.set_shader_parameter("intensity", 0.0)

	danger_vignette = ColorRect.new()
	danger_vignette.material = vignette_material
	danger_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	danger_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(danger_vignette)


func _update_danger_vignette() -> void:
	# Check all 4 metrics — flash if ANY is below 10%
	var health_pct: float = (health.hitpoints / health.max_hitpoints) * 100.0
	var temp_pct: float = (player.hull_temp / player.max_hull_temp) * 100.0 if player.max_hull_temp > 0 else 100.0
	var integrity_pct: float = (player.hull_integrity / player.max_integrity) * 100.0 if player.max_integrity > 0 else 100.0
	var sharpness_pct: float = (player.drill_sharpness / player.max_sharpness) * 100.0 if player.max_sharpness > 0 else 100.0

	var lowest: float = min(health_pct, min(temp_pct, min(integrity_pct, sharpness_pct)))

	if lowest <= 10.0:
		# Pulse intensity scales with how low the worst metric is
		var severity := 1.0 - (lowest / 10.0)  # 0 at 10%, 1 at 0%
		var pulse := (sin(Time.get_ticks_msec() / 300.0) + 1.0) / 2.0
		var target_intensity := lerpf(0.3, 0.7, pulse) * (0.5 + 0.5 * severity)
		vignette_material.set_shader_parameter("intensity", target_intensity)
	else:
		vignette_material.set_shader_parameter("intensity", 0.0)


## Stub methods kept so other code doesn't crash if it still references them
func update_hotbar():
	pass


func update_inventory():
	_update_ore_display()


func set_interaction_hint(text: String = "", pos: Vector2 = Vector2.ZERO):
	interaction_hint.text = text
	interaction_hint.visible = not text.is_empty()
	if not text.is_empty():
		if not is_inside_tree(): return
		await get_tree().process_frame
		if not is_inside_tree(): return
		interaction_hint.position = get_viewport().canvas_transform * pos - Vector2(interaction_hint.size.x / 2, 0)


func update_subsystems():
	hull_temp.gauge_value = player.hull_temp
	hull_integrity.gauge_value = player.hull_integrity
	drill_sharpness.gauge_value = player.drill_sharpness


# ---- Touch Controls ----

func _build_touch_controls():
	var btn_size := Vector2(100, 100)
	var btn_font_size := 32
	var margin := 20

	# — Left button (bottom-left) —
	_left_btn = Button.new()
	_left_btn.text = "◀"
	_left_btn.custom_minimum_size = btn_size
	_left_btn.anchors_preset = Control.PRESET_BOTTOM_LEFT
	_left_btn.anchor_left = 0.0
	_left_btn.anchor_top = 1.0
	_left_btn.anchor_right = 0.0
	_left_btn.anchor_bottom = 1.0
	_left_btn.offset_left = margin
	_left_btn.offset_top = -(btn_size.y + margin)
	_left_btn.offset_right = margin + btn_size.x
	_left_btn.offset_bottom = -margin
	_left_btn.add_theme_font_size_override("font_size", btn_font_size)
	_style_touch_button(_left_btn, Color(0.2, 0.2, 0.3, 0.6))
	_left_btn.button_down.connect(_on_left_pressed)
	_left_btn.button_up.connect(_on_left_released)
	add_child(_left_btn)

	# — Right button (bottom-right) —
	_right_btn = Button.new()
	_right_btn.text = "▶"
	_right_btn.custom_minimum_size = btn_size
	_right_btn.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	_right_btn.anchor_left = 1.0
	_right_btn.anchor_top = 1.0
	_right_btn.anchor_right = 1.0
	_right_btn.anchor_bottom = 1.0
	_right_btn.offset_left = -(btn_size.x + margin)
	_right_btn.offset_top = -(btn_size.y + margin)
	_right_btn.offset_right = -margin
	_right_btn.offset_bottom = -margin
	_right_btn.add_theme_font_size_override("font_size", btn_font_size)
	_style_touch_button(_right_btn, Color(0.2, 0.2, 0.3, 0.6))
	_right_btn.button_down.connect(_on_right_pressed)
	_right_btn.button_up.connect(_on_right_released)
	add_child(_right_btn)

	# — Upgrade button (top-right, below ore panel) —
	_upgrade_btn = Button.new()
	_upgrade_btn.text = "⬆ Upgrade"
	_upgrade_btn.custom_minimum_size = Vector2(120, 50)
	_upgrade_btn.anchor_left = 1.0
	_upgrade_btn.anchor_top = 0.0
	_upgrade_btn.anchor_right = 1.0
	_upgrade_btn.anchor_bottom = 0.0
	# Positioned below the ore panel (ore panel is ~20px margin + panel height)
	# We'll use a generous top offset so it sits under the counters
	_upgrade_btn.offset_left = -140
	_upgrade_btn.offset_top = 260
	_upgrade_btn.offset_right = -20
	_upgrade_btn.offset_bottom = 310
	_upgrade_btn.add_theme_font_size_override("font_size", 18)
	_style_touch_button(_upgrade_btn, Color(0.5, 0.35, 0.1, 0.75))
	_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	add_child(_upgrade_btn)


func _style_touch_button(btn: Button, bg_color: Color):
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_left = 12
	normal.corner_radius_bottom_right = 12
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(1, 1, 1, 0.3)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = bg_color.lightened(0.3)
	btn.add_theme_stylebox_override("pressed", pressed)


func _on_left_pressed():
	Input.action_press("left")

func _on_left_released():
	Input.action_release("left")

func _on_right_pressed():
	Input.action_press("right")

func _on_right_released():
	Input.action_release("right")

func _on_upgrade_pressed():
	if player and player.t_menu:
		player.t_menu.open()
