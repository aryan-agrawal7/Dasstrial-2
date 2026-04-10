extends Node

const RESOURCE_PATH= "res://local/game_start.res"

@export_group("Functionality moved to")
@export_placeholder(RESOURCE_PATH) var _look_here: String

@export_category("Scenes")
@export var main_menu: PackedScene


@onready var game_over_container = $"Game Over CenterContainer"
@onready var game_over_label: Label = %"Game Over Label"
@onready var run_time_label: Label = %"RunTimeLabel"
@onready var screenshot_rect: TextureRect = %"ScreenshotRect"
@onready var screenshot_caption: Label = %"ScreenshotCaption"
@onready var play_again_button: Button = %"PlayAgainButton"
@onready var main_menu_button: Button = %"MainMenuButton"


var game: Game
var character: PackedScene
var world_seed: String
var skin_path: String
var location_name: String = ""
var location_lat: float = 0.0
var location_lng: float = 0.0
var game_scene_to_load: PackedScene
## 0=EASY, 1=HARD, 2=HELL — matches GameSettings.Difficulty enum
var selected_difficulty: int = 0

## Set your Google Maps API key here.
## Requires Places API and Maps Static API enabled in Google Cloud Console.
const GOOGLE_API_KEY: String = "AIzaSyCSXKeE_7gAv4lNfGBVoOupdoQ0LlCCzIQ"

var game_start_resource: GameStart

## Guards against game_over() being called multiple times in the same frame
## (e.g. from _physics_process while standing on finish blocks).
var _game_over_triggered: bool = false

## Bonus applied to ore spawn thresholds (lowered = more ores). Increased by gold use.
var ore_spawn_bonus: float = 0.0

## Stores final run time so the antipode screen can display it
var final_run_time: float = 0.0

## Screenshot stash: Images captured at spawn and each section crossing for the win screen.
## The death screenshot is always stored last when game_over(false) is called.
var game_screenshots: Array[Image] = []
var _death_screenshot: Image = null
var _is_win: bool = false


func init():
	if not ResourceLoader.exists(RESOURCE_PATH):
		game_start_resource= GameStart.new()
		ResourceSaver.save(game_start_resource, RESOURCE_PATH)
	else:
		game_start_resource= load(RESOURCE_PATH)

	assert(main_menu)
	assert(not game_start_resource.skip_main_menu or game_start_resource.skip_to_scene != null)
	
	if game_start_resource.skip_main_menu:
		GameManager.run_game(game_start_resource.skip_to_scene)
	else:
		get_tree().change_scene_to_packed.call_deferred(main_menu)


## ESC is now handled by the PauseMenu autoload (res://game/ui/pause_menu.tscn)


func run_game(scene: PackedScene):
	run_deferred.call_deferred(scene)


func run_deferred(scene: PackedScene):
	_game_over_triggered = false
	ore_spawn_bonus = 0.0
	game_screenshots.clear()
	_death_screenshot = null
	_is_win = false
	assert(get_tree().change_scene_to_packed(scene) == OK)


## Capture a screenshot and stash it in game_screenshots.
## Hides timer, ore panel, touch controls, and lives display so only gauges
## and the depth progress bar appear in the image.
func capture_screenshot() -> void:
	var vp := get_viewport()
	if vp == null:
		return

	# Collect UI nodes to hide
	var hidden_nodes: Array[CanvasItem] = []

	# Timer (autoload CanvasLayer)
	if is_instance_valid(GameTimer):
		hidden_nodes.append(GameTimer)

	# Player UI sub-elements
	var player_ui: UI = null
	if Global.game and Global.game.player:
		player_ui = Global.game.player.get_node_or_null("Player UI") as UI
	if player_ui:
		# Ore Panel (the MarginContainer holding ore counts)
		var ore_panel := player_ui.get_node_or_null("Ore Panel")
		if ore_panel:
			hidden_nodes.append(ore_panel)
		# Touch buttons
		if player_ui._left_btn:
			hidden_nodes.append(player_ui._left_btn)
		if player_ui._right_btn:
			hidden_nodes.append(player_ui._right_btn)
		if player_ui._upgrade_btn:
			hidden_nodes.append(player_ui._upgrade_btn)
		# Lives display
		if player_ui._lives_container:
			hidden_nodes.append(player_ui._lives_container)

	# Store original visibility and hide
	var was_visible: Array[bool] = []
	for node in hidden_nodes:
		was_visible.append(node.visible)
		node.visible = false

	# Wait one frame so the viewport renders without hidden elements
	await get_tree().process_frame

	# Capture
	var img: Image = vp.get_texture().get_image()
	if img and not img.is_empty():
		game_screenshots.append(img)

	# Restore visibility
	for i in range(hidden_nodes.size()):
		hidden_nodes[i].visible = was_visible[i]



func game_over(win: bool):
	# Guard: only execute once per game session
	if _game_over_triggered:
		return
	_game_over_triggered = true
	_is_win = win

	final_run_time = GameTimer.elapsed_time
	GameTimer.stop_timer()

	if win:
		# Freeze gameplay scene without pausing the entire tree so music keeps running.
		_freeze_active_game_scene()
		if location_lat != 0.0 and not GOOGLE_API_KEY.is_empty():
			get_tree().change_scene_to_file.call_deferred("res://game/ui/antipode_zoom_transition.tscn")
		else:
			# No map — show win popup straight away
			show_win_popup()
		return

	# --- Loss ---
	# Take the death screenshot on the exact frame of death, before pausing
	capture_screenshot()
	if game_screenshots.size() > 0:
		_death_screenshot = game_screenshots.back()

	# Freeze gameplay scene without pausing global systems/audio.
	_freeze_active_game_scene()

	_show_popup(false)


## Called by antipode_zoom_transition.gd after its animation finishes.
func show_win_popup() -> void:
	_show_popup(true)


## Internal: builds and reveals the popup for either win or loss.
func _show_popup(win: bool) -> void:
	# Format run time
	var t: float = final_run_time
	var mins := int(t) / 60
	var secs := int(t) % 60
	var ms := int((t - int(t)) * 100)
	run_time_label.text = "TIME   %02d:%02d:%02d" % [mins, secs, ms]

	var img: Image
	if win:
		game_over_label.text = "MISSION COMPLETE"
		game_over_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1, 1.0))
		img = _pick_random_screenshot()
	else:
		game_over_label.text = "YOU DIED"
		game_over_label.add_theme_color_override("font_color", Color(0.9, 0.15, 0.1, 1.0))
		img = _death_screenshot
		screenshot_caption.text = "moment of death"

	if img and not img.is_empty():
		screenshot_rect.texture = ImageTexture.create_from_image(img)
	else:
		screenshot_rect.texture = null

	game_over_container.show()


## Returns a random Image from the stash, or null if empty.
func _pick_random_screenshot() -> Image:
	if game_screenshots.is_empty():
		return null
	return game_screenshots[randi() % game_screenshots.size()]


func _on_play_again_button_pressed():
	game_over_container.hide()
	run_game(game_scene_to_load)


func _on_exit_button_pressed():
	load_main_menu()


func load_main_menu():
	game_over_container.hide()
	get_tree().change_scene_to_packed.call_deferred(main_menu)


func is_ingame()-> bool:
	return get_tree().current_scene is Game


func _freeze_active_game_scene():
	var scene: Node = get_tree().current_scene
	if scene:
		scene.process_mode = Node.PROCESS_MODE_DISABLED
