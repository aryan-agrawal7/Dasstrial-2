extends CanvasLayer

## HUD overlay showing:
##   • Section name with animated fade-in on section change
##   • Depth meter (top-right)
##   • Antipode progress bar (left edge) — also drives bar color by temperature/pressure stress

@onready var section_label: Label = $SectionPanel/SectionLabel
@onready var depth_label: Label = $DepthPanel/DepthLabel
@onready var section_panel: PanelContainer = $SectionPanel
@onready var depth_bar: ProgressBar = $ProgressContainer/DepthBar
@onready var depth_percent: Label = $ProgressContainer/DepthPercent

const BOTTOM_LIMIT: float = 150.0

var display_tween: Tween


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	section_panel.modulate = Color.TRANSPARENT
	hide()
	call_deferred("_connect_signals")


func _connect_signals():
	SectionManager.section_changed.connect(_on_section_changed)
	get_tree().root.child_entered_tree.connect(_on_scene_changed)


func _on_scene_changed(_node: Node):
	await get_tree().process_frame
	if GameManager.is_ingame():
		show()
	else:
		hide()


func _process(_delta: float):
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
	depth_bar.value = fraction * 100.0
	depth_percent.text = "%d%%" % int(fraction * 100)

	# Dynamically color the bar: green → orange → red as depth increases
	var bar_color: Color
	if fraction < 0.4:
		bar_color = Color(0.15, 0.85, 0.45).lerp(Color(1.0, 0.65, 0.1), fraction / 0.4)
	elif fraction < 0.75:
		bar_color = Color(1.0, 0.65, 0.1).lerp(Color(0.95, 0.2, 0.1), (fraction - 0.4) / 0.35)
	else:
		bar_color = Color(0.95, 0.2, 0.1).lerp(Color(0.6, 0.0, 0.6), (fraction - 0.75) / 0.25)

	var fill_style: StyleBoxFlat = depth_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style:
		fill_style.bg_color = bar_color


func _on_section_changed(_old_section: String, new_section: String):
	var color: Color = SectionManager.get_section_color(new_section)

	section_label.text = _get_section_icon(new_section) + "  " + new_section.to_upper()
	section_label.add_theme_color_override("font_color", color)

	# Dramatic fade-in → hold → fade-out
	if display_tween and display_tween.is_running():
		display_tween.kill()

	section_panel.modulate = Color.TRANSPARENT
	display_tween = create_tween()
	display_tween.tween_property(section_panel, "modulate", Color.WHITE, 0.4).set_ease(Tween.EASE_OUT)
	display_tween.tween_interval(2.5)
	display_tween.tween_property(section_panel, "modulate", Color.TRANSPARENT, 1.0).set_ease(Tween.EASE_IN)


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
