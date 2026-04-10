class_name Game
extends Node

signal game_is_over

const RESPAWN_DEATH_SFX: AudioStream = preload("res://game/audio/sounds/death_respawn.ogg")
const RESPAWN_DEATH_SFX_BOOST_DB: float = 6.0206
const FINAL_DEATH_SFX: AudioStream = preload("res://game/audio/sounds/death_over.ogg")
const FINAL_DEATH_SFX_BOOST_DB: float = 6.0206

@export var world: World
@export var settings: GameSettings
@export var cheats: Cheats
@export var can_toggle_cheats: bool = true
@export var player_scene: PackedScene

@onready var camera = $Camera2D

var player: BasePlayer

## -1 = infinite (Easy), otherwise counts down each death
var lives_remaining: int = -1

## Ore snapshot for Easy mode — saved before death, restored after respawn
var _saved_ore_counts: Dictionary = {}
var _final_death_audio_played: bool = false
var _death_audio_emitted_for_player: bool = false


func _init():
	Global.game = self


func _ready():
	get_tree().paused = false
	SectionManager.reset()

	game_is_over.connect(GameManager.game_over)
	_final_death_audio_played = false

	if not settings:
		settings = GameSettings.new()

	if not cheats:
		cheats = Cheats.new()

	if not world:
		world = get_node_or_null("World")
		assert(world)

	if GameManager.character:
		player_scene = GameManager.character

	if not player_scene:
		player_scene = DataManager.characters.front()

	# Apply selected difficulty from GameManager
	settings.difficulty = GameManager.selected_difficulty as GameSettings.Difficulty

	# Set starting lives
	match settings.difficulty:
		GameSettings.Difficulty.EASY:
			lives_remaining = -1   # infinite
		GameSettings.Difficulty.HARD:
			lives_remaining = 3
		GameSettings.Difficulty.HELL:
			lives_remaining = 1

	set_process(false)
	await world.initialization_finished

	if not player:
		spawn_player.call_deferred()

	post_init()
	set_process(true)


func post_init():
	pass


func pre_start():
	return true


func _process(_delta):
	pass


func spawn_player():
	assert(player_scene)
	assert(player == null)
	_death_audio_emitted_for_player = false
	player = player_scene.instantiate()

	# Use checkpoint position if one has been activated, otherwise default spawn
	var respawn_pos: Vector2i = SectionManager.get_respawn_position()
	if respawn_pos != Vector2i.ZERO:
		player.position = Vector2(respawn_pos) * World.TILE_SIZE
	else:
		player.position = settings.player_spawn

	add_child.call_deferred(player)
	player.ready.connect(on_player_spawned)

	camera.follow_node = player

	# Route all deaths to the unified handler
	player.tree_exited.connect(_on_player_died)
	# Snapshot ores just before the player node leaves the tree (Easy mode)
	player.tree_exiting.connect(_snapshot_ores)


## Called every time the player dies (tree_exited fires after player node is freed).
func _on_player_died():
	match settings.difficulty:
		GameSettings.Difficulty.EASY:
			if is_inside_tree():
				spawn_player.call_deferred()

		GameSettings.Difficulty.HARD:
			lives_remaining -= 1
			if lives_remaining > 0:
				if is_inside_tree():
					spawn_player.call_deferred()
			else:
				_handle_final_death_game_over()

		GameSettings.Difficulty.HELL:
			_handle_final_death_game_over()


## Called just before the player node is freed (connect in on_player_spawned).
## Snapshots ore counts for Easy mode so we can restore them after respawn.
func _snapshot_ores():
	if settings.difficulty == GameSettings.Difficulty.EASY and player:
		_saved_ore_counts = player.ore_counter.counts.duplicate()


func on_player_spawned():
	# Restore ore counts in Easy mode (new player node starts empty)
	if settings.difficulty == GameSettings.Difficulty.EASY and not _saved_ore_counts.is_empty():
		for ore_name in _saved_ore_counts:
			if ore_name in player.ore_counter.counts:
				player.ore_counter.counts[ore_name] = _saved_ore_counts[ore_name]
		player.ore_counter.updated.emit()
		_saved_ore_counts.clear()

	# Capture an initial screenshot the first time the player spawns
	# (guarantees at least one image in the stash even if the player dies immediately)
	if GameManager.game_screenshots.is_empty():
		# Defer by one frame so the world has rendered at least once
		get_tree().process_frame.connect(
			func(): GameManager.capture_screenshot(),
			CONNECT_ONE_SHOT
		)


func respawn():
	if is_inside_tree():
		spawn_player.call_deferred()


func on_player_death_for_respawn():
	# Intentionally for deaths that will respawn.
	# Keep separate so future game-over death can use a different sound.
	if settings and is_instance_valid(SoundPlayer) and SoundPlayer.has_method("play_stream"):
		SoundPlayer.play_stream(RESPAWN_DEATH_SFX, RESPAWN_DEATH_SFX_BOOST_DB)


func on_player_death_started():
	# Called at the start of death animation (from BasePlayer.die()).
	# This makes SFX feel immediate and avoids late playback after queue_free.
	if _death_audio_emitted_for_player:
		return
	_death_audio_emitted_for_player = true

	var is_final_death: bool = false
	match settings.difficulty:
		GameSettings.Difficulty.EASY:
			is_final_death = false
		GameSettings.Difficulty.HARD:
			# If this death consumes the last life, it's a final death.
			is_final_death = lives_remaining <= 1
		GameSettings.Difficulty.HELL:
			is_final_death = true

	if is_final_death:
		_play_final_death_sfx_if_needed()
	else:
		on_player_death_for_respawn()


func _handle_final_death_game_over():
	_play_final_death_sfx_if_needed()
	game_over(false)


func _play_final_death_sfx_if_needed():
	# Only finite-lives modes (Hard/Hell) should play final-death SFX.
	if not settings or settings.difficulty == GameSettings.Difficulty.EASY:
		return
	if _final_death_audio_played:
		return
	_final_death_audio_played = true

	if is_instance_valid(SoundPlayer) and SoundPlayer.has_method("play_stream"):
		SoundPlayer.play_stream(FINAL_DEATH_SFX, FINAL_DEATH_SFX_BOOST_DB)


func game_over(win: bool):
	game_is_over.emit(win)
