## Simplified player UI: shows ore counters (top-right) and health bar.
## Replaces the full hotbar/inventory/crafting/build menu system.
class_name UI
extends CanvasLayer

const PLAYER_HURT_SFX: AudioStream = preload("res://game/audio/sounds/player_hurt.ogg")
const HURT_SFX_BOOST_DB: float = 6.0206

## Touch control button texture paths (pixel art)
const LEFT_BTN_PATH: String = "res://game/ui/btn_left.png"
const RIGHT_BTN_PATH: String = "res://game/ui/btn_right.png"


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


## Lives display pip nodes
var _lives_pips: Array = []
var _lives_container: HBoxContainer

## Red screen-edge vignette overlay
var danger_vignette: ColorRect
var vignette_material: ShaderMaterial

## Touch control button node references
var _left_btn: TextureButton
var _right_btn: TextureButton
var _upgrade_btn: Button

## Hurt sound sync state (tracks pulse + recent health loss)
var _last_health: float = 0.0
var _recent_damage_timer: float = 0.0
var _hurt_sound_cooldown: float = 0.0
var _pulse_peak_armed: bool = true


func _ready():
	assert(player)
	assert(health)
	_last_health = health.hitpoints

	# Build the lives display
	_build_lives_display()

	# Build the red vignette overlay (full-screen, above everything)
	_build_danger_vignette()

	# Build touch control buttons for mobile
	_build_touch_controls()

	# Defer building the ore display — the player's _ready() hasn't run yet
	# (children are ready before parents in Godot), so ore_counter.ore_items
	# is still empty at this point. call_deferred ensures it runs next frame.
	call_deferred("_build_ore_display")
	call_deferred("_connect_ore_counter")


func _process(delta):
	update_health()
	update_subsystems()
	_track_recent_health_loss(delta)
	_update_danger_vignette(delta)
	_update_lives_display()


func _track_recent_health_loss(delta: float) -> void:
	_hurt_sound_cooldown = max(0.0, _hurt_sound_cooldown - delta)

	if health.hitpoints < _last_health - 0.001:
		_recent_damage_timer = 0.45
	else:
		_recent_damage_timer = max(0.0, _recent_damage_timer - delta)

	_last_health = health.hitpoints



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






func _build_lives_display() -> void:
	## Build a small lives indicator widget in the top-center, just below the gauges.
	_lives_container = HBoxContainer.new()
	_lives_container.anchor_left = 0.5
	_lives_container.anchor_top = 0.0
	_lives_container.anchor_right = 0.5
	_lives_container.anchor_bottom = 0.0
	# Sit below the gauge row (gauges are 90px + margin ~10 = ~100px from top)
	_lives_container.offset_top = 108
	_lives_container.offset_left = -60
	_lives_container.offset_right = 60
	_lives_container.offset_bottom = 130
	_lives_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lives_container.add_theme_constant_override("separation", 6)
	add_child(_lives_container)

	var difficulty: int = GameManager.selected_difficulty

	if difficulty == 0:  # EASY
		var lbl := Label.new()
		lbl.text = "EASY  ∞"
		var ls := LabelSettings.new()
		ls.font_size = 14
		ls.font_color = Color(0.4, 1.0, 0.55, 0.85)
		ls.outline_size = 2
		ls.outline_color = Color(0, 0, 0, 0.7)
		lbl.label_settings = ls
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lives_container.add_child(lbl)
	elif difficulty == 1:  # HARD — 3 heart pips
		var prefix := Label.new()
		prefix.text = "HARD"
		var pls := LabelSettings.new()
		pls.font_size = 14
		pls.font_color = Color(0.95, 0.65, 0.1, 0.85)
		pls.outline_size = 2
		pls.outline_color = Color(0, 0, 0, 0.7)
		prefix.label_settings = pls
		_lives_container.add_child(prefix)
		for i in range(3):
			var pip := Label.new()
			pip.text = "♥"
			var ls := LabelSettings.new()
			ls.font_size = 16
			ls.font_color = Color(0.95, 0.2, 0.2, 1.0)
			ls.outline_size = 2
			ls.outline_color = Color(0, 0, 0, 0.8)
			pip.label_settings = ls
			_lives_container.add_child(pip)
			_lives_pips.append(pip)
	else:  # HELL
		var lbl := Label.new()
		lbl.text = "HELL  💀"
		var ls := LabelSettings.new()
		ls.font_size = 14
		ls.font_color = Color(0.85, 0.1, 0.1, 0.9)
		ls.outline_size = 2
		ls.outline_color = Color(0, 0, 0, 0.7)
		lbl.label_settings = ls
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lives_container.add_child(lbl)


func _update_lives_display() -> void:
	## Dim Hard-mode pips as lives are spent.
	if GameManager.selected_difficulty != 1:
		return
	if not Global.game:
		return
	var lives: int = Global.game.lives_remaining
	for i in range(_lives_pips.size()):
		var pip: Label = _lives_pips[i]
		if i < lives:
			pip.label_settings.font_color = Color(0.95, 0.2, 0.2, 1.0)
		else:
			pip.label_settings.font_color = Color(0.35, 0.35, 0.35, 0.45)


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


func _update_danger_vignette(_delta: float) -> void:
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

		# Sync hurt sound to pulse peaks, but only while health is currently draining.
		if pulse > 0.96 and _pulse_peak_armed:
			_pulse_peak_armed = false
			if _recent_damage_timer > 0.0:
				_play_hurt_sound()
		elif pulse < 0.55:
			_pulse_peak_armed = true
	else:
		vignette_material.set_shader_parameter("intensity", 0.0)
		_pulse_peak_armed = true


func _play_hurt_sound() -> void:
	if _hurt_sound_cooldown > 0.0:
		return

	if is_instance_valid(SoundPlayer) and SoundPlayer.has_method("play_stream"):
		SoundPlayer.play_stream(PLAYER_HURT_SFX, HURT_SFX_BOOST_DB)
		_hurt_sound_cooldown = 0.18


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
	var btn_size := Vector2(140, 140)
	var margin := 24

	# Load pixel art textures directly from PNG files, bypassing Godot's
	# import system (which may mark them as valid=false if never imported).
	var left_tex: Texture2D = _load_png_texture(LEFT_BTN_PATH)
	var right_tex: Texture2D = _load_png_texture(RIGHT_BTN_PATH)

	# — Left button (bottom-left) —
	_left_btn = TextureButton.new()
	if left_tex:
		_left_btn.texture_normal = left_tex
		_left_btn.texture_pressed = left_tex
		_left_btn.texture_hover = left_tex
		# STRETCH_SCALE fills the full btn_size area; ignore_texture_size
		# prevents the button from auto-resizing to the raw PNG dimensions.
		_left_btn.stretch_mode = TextureButton.STRETCH_SCALE
		_left_btn.ignore_texture_size = true
	else:
		# Fallback: show unicode arrow so button is still usable before import
		var lbl := Label.new()
		lbl.text = "◀"
		lbl.set_anchors_preset(Control.PRESET_CENTER)
		lbl.add_theme_font_size_override("font_size", 48)
		_left_btn.add_child(lbl)
	_left_btn.custom_minimum_size = btn_size
	_left_btn.anchor_left = 0.0
	_left_btn.anchor_top = 1.0
	_left_btn.anchor_right = 0.0
	_left_btn.anchor_bottom = 1.0
	_left_btn.offset_left = margin
	_left_btn.offset_top = -(btn_size.y + margin)
	_left_btn.offset_right = margin + btn_size.x
	_left_btn.offset_bottom = -margin
	_left_btn.button_down.connect(_on_left_pressed)
	_left_btn.button_up.connect(_on_left_released)
	_left_btn.button_down.connect(func(): _left_btn.modulate = Color(0.6, 0.6, 0.6, 1.0))
	_left_btn.button_up.connect(func(): _left_btn.modulate = Color.WHITE)
	add_child(_left_btn)

	# — Right button (bottom-right) —
	_right_btn = TextureButton.new()
	if right_tex:
		_right_btn.texture_normal = right_tex
		_right_btn.texture_pressed = right_tex
		_right_btn.texture_hover = right_tex
		_right_btn.stretch_mode = TextureButton.STRETCH_SCALE
		_right_btn.ignore_texture_size = true
	else:
		var lbl := Label.new()
		lbl.text = "▶"
		lbl.set_anchors_preset(Control.PRESET_CENTER)
		lbl.add_theme_font_size_override("font_size", 48)
		_right_btn.add_child(lbl)
	_right_btn.custom_minimum_size = btn_size
	_right_btn.anchor_left = 1.0
	_right_btn.anchor_top = 1.0
	_right_btn.anchor_right = 1.0
	_right_btn.anchor_bottom = 1.0
	_right_btn.offset_left = -(btn_size.x + margin)
	_right_btn.offset_top = -(btn_size.y + margin)
	_right_btn.offset_right = -margin
	_right_btn.offset_bottom = -margin
	_right_btn.button_down.connect(_on_right_pressed)
	_right_btn.button_up.connect(_on_right_released)
	_right_btn.button_down.connect(func(): _right_btn.modulate = Color(0.6, 0.6, 0.6, 1.0))
	_right_btn.button_up.connect(func(): _right_btn.modulate = Color.WHITE)
	add_child(_right_btn)

	# — Upgrade button (top-right, below ore panel) —
	_upgrade_btn = Button.new()
	_upgrade_btn.text = "⬆ Upgrade"
	_upgrade_btn.custom_minimum_size = Vector2(120, 50)
	_upgrade_btn.anchor_left = 1.0
	_upgrade_btn.anchor_top = 0.0
	_upgrade_btn.anchor_right = 1.0
	_upgrade_btn.anchor_bottom = 0.0
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


## Load an image file directly from disk, bypassing Godot's import system.
## Handles files with incorrect extensions (e.g. JPEGs named .png).
func _load_png_texture(res_path: String) -> Texture2D:
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	var img := Image.new()
	var err := img.load(abs_path)
	
	if err != OK:
		# Fallback: the files are named .png but might actually be JPEGs
		# Read raw bytes and try both formats manually
		var file := FileAccess.open(abs_path, FileAccess.READ)
		if file:
			var buffer := file.get_buffer(file.get_length())
			# Try PNG first
			err = img.load_png_from_buffer(buffer)
			# If it fails, try JPEG
			if err != OK:
				err = img.load_jpg_from_buffer(buffer)
	
	if err != OK:
		push_warning("Failed to load image texture: %s (error %d)" % [abs_path, err])
		return null
		
	return ImageTexture.create_from_image(img)
