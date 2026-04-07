extends BaseSoundPlayer


var stream_players: Array[AudioStreamPlayer]
var sfx_volume_db: float = 0.0



func _ready():
	stream_players.assign(get_children())
	_apply_saved_sfx_volume()


func play(sound_key: String):
	if not DataManager.sound_library.library.has(sound_key):
		push_error("No %s in sound library" % [sound_key])
		return

	var sound: AudioStream= DataManager.sound_library.library[sound_key]
	play_stream(sound)


func play_stream(sound: AudioStream, extra_volume_db: float = 0.0):
	if sound == null:
		return

	var player: AudioStreamPlayer= get_free_player()
	if player:
		player.stream= sound
		player.volume_db = sfx_volume_db + extra_volume_db
		player.play()


func set_sfx_volume_percent(percent: float):
	var linear: float = clamp(percent / 100.0, 0.0001, 2.0)
	sfx_volume_db = linear_to_db(linear)


func _apply_saved_sfx_volume():
	var user_config = get_node_or_null("/root/UserConfig")
	if user_config and user_config.has_method("get_setting"):
		if user_config.config_file.has_section_key("Settings", "sfx_volume"):
			set_sfx_volume_percent(float(user_config.get_setting("sfx_volume")))


func get_free_player()-> AudioStreamPlayer:
	for player: AudioStreamPlayer in stream_players:
		if not player.playing:
			return player
	return null
