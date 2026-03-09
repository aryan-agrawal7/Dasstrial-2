extends Node

const RESOURCE_PATH= "res://local/game_start.res"

@export_group("Functionality moved to")
@export_placeholder(RESOURCE_PATH) var _look_here: String

@export_category("Scenes")
@export var main_menu: PackedScene


@onready var game_over_container = $"Game Over CenterContainer"
@onready var game_over_label = %"Game Over Label"


var game: Game
var character: PackedScene
var world_seed: String
var skin_path: String
var location_name: String = ""
var location_lat: float = 0.0
var location_lng: float = 0.0
var game_scene_to_load: PackedScene

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
	assert(get_tree().change_scene_to_packed(scene) == OK)


func game_over(win: bool):
	# Guard: only execute once per game session
	if _game_over_triggered:
		return
	_game_over_triggered = true

	# Save the final run time before stopping the timer
	final_run_time = GameTimer.elapsed_time
	GameTimer.stop_timer()

	# Pause the world FIRST to stop background chunk generator threads from crashing.
	get_tree().paused = true

	# If the player won and a location was selected, show the antipode animation.
	# The antipode scene will unpause immediately in its own _ready().
	if win and location_lat != 0.0 and not GOOGLE_API_KEY.is_empty():
		get_tree().change_scene_to_file.call_deferred("res://game/ui/antipode_zoom_transition.tscn")
		return

	game_over_label.text = "You won!!!" if win else "You lost :("
	game_over_container.show()
	
	# Auto-exit cleanly after 2 seconds (timer runs while paused via process_always=true)
	await get_tree().create_timer(2.0, true, false, true).timeout
	load_main_menu()


func _on_try_again_button_pressed():
	game_over_container.hide()
	get_tree().reload_current_scene.call_deferred()


func _on_exit_button_pressed():
	load_main_menu()


func load_main_menu():
	game_over_container.hide()
	get_tree().paused = false
	get_tree().change_scene_to_packed.call_deferred(main_menu)


func is_ingame()-> bool:
	return get_tree().current_scene is Game
