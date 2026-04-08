class_name Game
extends Node

signal game_is_over

const RESPAWN_DEATH_SFX: AudioStream = preload("res://game/audio/sounds/death_respawn.ogg")
const RESPAWN_DEATH_SFX_BOOST_DB: float = 6.0206

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


func _init():
	Global.game = self


func _ready():
	get_tree().paused = false
	SectionManager.reset()

	game_is_over.connect(GameManager.game_over)

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
			on_player_death_for_respawn()
			if is_inside_tree():
				spawn_player.call_deferred()

		GameSettings.Difficulty.HARD:
			lives_remaining -= 1
			if lives_remaining > 0:
				on_player_death_for_respawn()
				if is_inside_tree():
					spawn_player.call_deferred()
			else:
				game_over(false)

		GameSettings.Difficulty.HELL:
			game_over(false)


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


func respawn():
	if is_inside_tree():
		spawn_player.call_deferred()


func on_player_death_for_respawn():
	# Intentionally for deaths that will respawn.
	# Keep separate so future game-over death can use a different sound.
	if settings and is_instance_valid(SoundPlayer) and SoundPlayer.has_method("play_stream"):
		SoundPlayer.play_stream(RESPAWN_DEATH_SFX, RESPAWN_DEATH_SFX_BOOST_DB)


func game_over(win: bool):
	game_is_over.emit(win)
