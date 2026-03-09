extends Node

const TERRAIN_COLLISION_LAYER= 1
const PLAYER_COLLISION_LAYER= 2
const MOB_COLLISION_LAYER= 3
const PROJECTILE_COLLISION_LAYER= 6
const HURTBOX_COLLISION_LAYER= 7
const SOLID_ENTITY_COLLISION_LAYER= 8

const HEALT_COMPONENT_NODE= "Health Component"

var game: Game

var bg_music_player: AudioStreamPlayer

func _ready():
	bg_music_player = AudioStreamPlayer.new()
	bg_music_player.name = "BackgroundMusic"
	bg_music_player.stream = preload("res://game/audio/BgMusic.ogg")
	# Optional: you can set bus or volume here if needed:
	# bg_music_player.bus = "Master"
	# bg_music_player.volume_db = -5.0
	
	# Add directly to the global autoload node so it survives scene changes
	add_child(bg_music_player)
	
	bg_music_player.play()

