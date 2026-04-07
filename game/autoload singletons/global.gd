extends Node

const TERRAIN_COLLISION_LAYER= 1
const PLAYER_COLLISION_LAYER= 2
const PROJECTILE_COLLISION_LAYER= 6
const HURTBOX_COLLISION_LAYER= 7
const SOLID_ENTITY_COLLISION_LAYER= 8
const BGM_MAX_LINEAR_AT_100: float = 0.5

const HEALT_COMPONENT_NODE= "Health Component"

var game: Game

var bg_music_player: AudioStreamPlayer
var _pending_bgm_volume_db: float = linear_to_db(BGM_MAX_LINEAR_AT_100)

func _ready():
	bg_music_player = AudioStreamPlayer.new()
	bg_music_player.name = "BackgroundMusic"
	bg_music_player.stream = preload("res://game/audio/BgMusic.ogg")
	bg_music_player.bus = "Master"
	bg_music_player.volume_db = _pending_bgm_volume_db
	
	# Add directly to the global autoload node so it survives scene changes
	add_child(bg_music_player)
	_apply_saved_bgm_volume()
	
	bg_music_player.play()


func set_bgm_volume_percent(percent: float):
	var scaled_linear: float = clamp(percent / 100.0, 0.0, 1.0) * BGM_MAX_LINEAR_AT_100
	var db: float = -80.0 if scaled_linear <= 0.0 else linear_to_db(scaled_linear)
	_pending_bgm_volume_db = db
	if bg_music_player:
		bg_music_player.volume_db = db


func _apply_saved_bgm_volume():
	var user_config = get_node_or_null("/root/UserConfig")
	if user_config and user_config.has_method("get_setting"):
		if user_config.config_file.has_section_key("Settings", "bgm_volume"):
			set_bgm_volume_percent(float(user_config.get_setting("bgm_volume")))
