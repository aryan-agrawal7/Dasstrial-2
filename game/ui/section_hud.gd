extends CanvasLayer

## HUD overlay showing:
##   • Full-screen section title card on layer transitions
##   • Section name with animated fade-in on section change
##   • Depth meter (top-right)
##   • Depth bar (left edge) — custom-drawn with section ticks, player pip, checkpoint markers

@onready var section_label: Label = $SectionPanel/SectionLabel
@onready var depth_label: Label = $DepthPanel/DepthLabel
@onready var section_panel: PanelContainer = $SectionPanel
@onready var depth_bar: ProgressBar = $ProgressContainer/BarArea/DepthBar
@onready var depth_percent: Label = $ProgressContainer/DepthPercent
@onready var bar_area: Control = $ProgressContainer/BarArea

const BOTTOM_LIMIT: float = 1050.0

## Section boundary fractions along the bar (0=top, 1=bottom)
const SECTION_BOUNDARIES: Array = [
	{"name": "C",  "fraction": 0.0,   "color": Color(0.55, 0.35, 0.17)},  # Crust start
	{"name": "M",  "fraction": 300.0/1050.0,  "color": Color(1.0, 0.45, 0.15)},  # Mantle
	{"name": "Core",  "fraction": 450.0/1050.0,  "color": Color(0.9, 0.15, 0.1)},   # Core
	{"name": "M2", "fraction": 600.0/1050.0,  "color": Color(1.0, 0.45, 0.15)},  # Mantle-2
	{"name": "C2", "fraction": 750.0/1050.0,  "color": Color(0.55, 0.35, 0.17)}, # Crust-2
]

var display_tween: Tween

## Full-screen title overlay nodes (built dynamically)
var _title_overlay: ColorRect
var _title_label: Label
var _subtitle_label: Label
var _title_tween: Tween

## Current player depth fraction for the bar overlay
var _player_fraction: float = 0.0
## Activated checkpoint fractions
var _checkpoint_fractions: Array = []
## Pip glow pulse
var _pip_pulse: float = 0.0
## Bar fill color for overlay
var _bar_color: Color = Color(0.15, 0.85, 0.45)


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	section_panel.modulate = Color.TRANSPARENT
	hide()
	_build_title_overlay()
	call_deferred("_connect_signals")
	# Connect bar_area draw call
	bar_area.draw.connect(_draw_bar_overlay)


func _connect_signals():
	SectionManager.section_changed.connect(_on_section_changed)
	get_tree().root.child_entered_tree.connect(_on_scene_changed)


func _on_scene_changed(_node: Node):
	await get_tree().process_frame
	if GameManager.is_ingame():
		show()
	else:
		hide()


func _process(delta: float):
	if not visible:
		return
	if not GameManager.is_ingame():
		return
	var game: Game = Global.game
	if game == null or game.player == null:
		return

	var player_y: int = max(game.player.get_tile_pos().y, 0)
	depth_label.text = "Depth: %d m" % player_y

	# Update depth progress bar
	var fraction: float = clamp(float(player_y) / BOTTOM_LIMIT, 0.0, 1.0)
	_player_fraction = fraction
	depth_bar.value = fraction * 100.0
	depth_percent.text = "%d%%" % int(fraction * 100)

	# Pip glow pulse (~2 Hz)
	_pip_pulse = (sin(Time.get_ticks_msec() / 250.0) + 1.0) / 2.0

	# Dynamically color the bar: green → orange → red → purple
	var bar_color: Color
	if fraction < 0.4:
		bar_color = Color(0.15, 0.85, 0.45).lerp(Color(1.0, 0.65, 0.1), fraction / 0.4)
	elif fraction < 0.75:
		bar_color = Color(1.0, 0.65, 0.1).lerp(Color(0.95, 0.2, 0.1), (fraction - 0.4) / 0.35)
	else:
		bar_color = Color(0.95, 0.2, 0.1).lerp(Color(0.6, 0.0, 0.6), (fraction - 0.75) / 0.25)
	_bar_color = bar_color

	var fill_style: StyleBoxFlat = depth_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style:
		fill_style.bg_color = bar_color

	# Sync checkpoint fractions from SectionManager
	_checkpoint_fractions.clear()
	for cp_y in SectionManager.checkpoints_activated:
		_checkpoint_fractions.append(clamp(float(cp_y) / BOTTOM_LIMIT, 0.0, 1.0))

	# Trigger bar overlay redraw
	bar_area.queue_redraw()


## Draw section tick marks, player pip, and checkpoint markers on top of the ProgressBar.
## Called via bar_area.draw signal.
func _draw_bar_overlay():
	var w: float = bar_area.size.x
	var h: float = bar_area.size.y
	var bar_x: float = w * 0.5

	# ── Section boundary tick marks ────────────────────────────────────────
	for i in range(1, SECTION_BOUNDARIES.size()):  # skip 0 (top edge)
		var bd = SECTION_BOUNDARIES[i]
		var y: float = bd.fraction * h
		var col: Color = bd.color

		# Tick line across full width
		bar_area.draw_line(Vector2(0, y), Vector2(w, y), Color(col.r, col.g, col.b, 0.6), 1.5, true)

		# Small label to the right (abbreviation)
		var font := ThemeDB.fallback_font
		bar_area.draw_string(font, Vector2(w + 3, y + 4), bd.name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(col.r, col.g, col.b, 0.75))

	# ── Checkpoint diamond markers ─────────────────────────────────────────
	for cp_f in _checkpoint_fractions:
		var y: float = cp_f * h
		var diamond_size: float = 5.0
		var pts := PackedVector2Array([
			Vector2(bar_x, y - diamond_size),
			Vector2(bar_x + diamond_size, y),
			Vector2(bar_x, y + diamond_size),
			Vector2(bar_x - diamond_size, y),
		])
		bar_area.draw_colored_polygon(pts, Color(0.3, 0.9, 1.0, 0.85))
		bar_area.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]),
			Color(1.0, 1.0, 1.0, 0.5), 1.0, true)

	# ── Player position pip (glowing dot) ─────────────────────────────────
	var pip_y: float = _player_fraction * h
	var pip_r: float = 5.0
	var glow_r: float = lerp(8.0, 11.0, _pip_pulse)
	var pip_col: Color = _bar_color

	# Outer glow ring
	bar_area.draw_circle(Vector2(bar_x, pip_y), glow_r,
		Color(pip_col.r, pip_col.g, pip_col.b, 0.18 * _pip_pulse))
	# Mid glow
	bar_area.draw_circle(Vector2(bar_x, pip_y), pip_r + 2,
		Color(pip_col.r, pip_col.g, pip_col.b, 0.35))
	# Core pip
	bar_area.draw_circle(Vector2(bar_x, pip_y), pip_r,
		Color(1.0, 1.0, 1.0, 0.95))
	# Center dot
	bar_area.draw_circle(Vector2(bar_x, pip_y), 2.5,
		Color(pip_col.r * 0.6, pip_col.g * 0.6, pip_col.b * 0.6, 1.0))


func _on_section_changed(_old_section: String, new_section: String):
	var color: Color = SectionManager.get_section_color(new_section)

	section_label.text = _get_section_icon(new_section) + "  " + new_section.to_upper()
	section_label.add_theme_color_override("font_color", color)

	# Snap a screenshot at every section crossing (used for the win screen stash).
	# Defer by one frame so the section-title card is visible in the image.
	get_tree().process_frame.connect(
		func(): GameManager.capture_screenshot(),
		CONNECT_ONE_SHOT
	)

	# Dramatic fade-in → hold → fade-out for the small panel
	if display_tween and display_tween.is_running():
		display_tween.kill()

	section_panel.modulate = Color.TRANSPARENT
	display_tween = create_tween()
	display_tween.tween_property(section_panel, "modulate", Color.WHITE, 0.4).set_ease(Tween.EASE_OUT)
	display_tween.tween_interval(2.5)
	display_tween.tween_property(section_panel, "modulate", Color.TRANSPARENT, 1.0).set_ease(Tween.EASE_IN)

	# Full-screen title card
	_show_title_card(new_section, color)


## Build the full-screen title overlay (hidden by default)
func _build_title_overlay():
	_title_overlay = ColorRect.new()
	_title_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_overlay.color = Color(0, 0, 0, 0)
	_title_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_overlay)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	_title_overlay.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var title_settings := LabelSettings.new()
	title_settings.font_size = 72
	title_settings.font_color = Color.WHITE
	title_settings.outline_size = 6
	title_settings.outline_color = Color(0, 0, 0, 0.9)
	title_settings.shadow_size = 8
	title_settings.shadow_color = Color(0, 0, 0, 0.7)
	title_settings.shadow_offset = Vector2(3, 3)
	_title_label.label_settings = title_settings
	vbox.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var sub_settings := LabelSettings.new()
	sub_settings.font_size = 24
	sub_settings.font_color = Color(0.8, 0.8, 0.8, 1.0)
	sub_settings.outline_size = 3
	sub_settings.outline_color = Color(0, 0, 0, 0.8)
	_subtitle_label.label_settings = sub_settings
	vbox.add_child(_subtitle_label)

	# Decorative separator lines
	var line_top := ColorRect.new()
	line_top.custom_minimum_size = Vector2(400, 2)
	line_top.color = Color(1, 1, 1, 0.4)
	line_top.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(line_top)
	vbox.move_child(line_top, 1)  # Between title and subtitle

	_title_overlay.modulate = Color.TRANSPARENT


## Show the dramatic full-screen title card
func _show_title_card(section_name: String, section_color: Color):
	if _title_tween and _title_tween.is_running():
		_title_tween.kill()

	var icon: String = _get_section_icon(section_name)
	_title_label.text = icon + "  " + section_name.to_upper() + "  " + icon
	_title_label.label_settings.font_color = section_color
	_subtitle_label.text = _get_section_subtitle(section_name)

	# Start fully transparent, with the title shifted left for a sweep effect
	_title_overlay.modulate = Color.TRANSPARENT
	_title_label.position.x = -60

	_title_tween = create_tween()
	_title_tween.set_parallel(true)

	# Background dims slightly
	_title_tween.tween_property(_title_overlay, "color", Color(0, 0, 0, 0.55), 0.5)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Fade in overlay
	_title_tween.tween_property(_title_overlay, "modulate", Color.WHITE, 0.5)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Sweep title from left to center
	_title_tween.tween_property(_title_label, "position:x", 0.0, 0.6)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Hold
	_title_tween.set_parallel(false)
	_title_tween.tween_interval(2.0)

	# Fade out
	_title_tween.set_parallel(true)
	_title_tween.tween_property(_title_overlay, "modulate", Color.TRANSPARENT, 0.8)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_title_tween.tween_property(_title_overlay, "color", Color(0, 0, 0, 0), 0.8)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func _get_section_subtitle(section_name: String) -> String:
	match section_name:
		"Crust":
			return "The surface layer"
		"Mantle":
			return "Heat rises"
		"Core":
			return "Extreme conditions — Beware!"
		"Mantle-2":
			return "Coming back up!"
		"Crust-2":
			return "Almost there"
		_:
			return "Unknown territory"


func _get_section_icon(section_name: String) -> String:
	match section_name:
		"Crust":
			return "🌍"
		"Mantle":
			return "🔥"
		"Core":
			return "💎"
		"Mantle-2":
			return "🔥"
		"Crust-2":
			return "🌍"
		_:
			return "📍"
