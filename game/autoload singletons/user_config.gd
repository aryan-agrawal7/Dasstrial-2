extends Node

const FILE_PATH: String= "user://user_config.cfg" 


var config_file:= ConfigFile.new()


var default_settings: String="""
	[Settings]
	master_volume=80
	bgm_volume=100
	sfx_volume=100
	fullscreen=false
	world_seed=""
"""


func _init():
	if not FileAccess.file_exists(FILE_PATH):
		config_file.parse(default_settings)
		save_data()
	
	load_data()


func save_data():
	config_file.save(FILE_PATH)


func load_data():
	config_file.load(FILE_PATH)
	_ensure_default_settings()
	_migrate_legacy_volume_setting()

	for section in config_file.get_sections():
		for key in config_file.get_section_keys(section):
			on_update_setting(config_file.get_value(section, key), key, section)


func _ensure_default_settings():
	var defaults:= ConfigFile.new()
	defaults.parse(default_settings)

	var changed: bool = false
	for section in defaults.get_sections():
		for key in defaults.get_section_keys(section):
			if not config_file.has_section_key(section, key):
				config_file.set_value(section, key, defaults.get_value(section, key))
				changed = true

	if changed:
		save_data()


func _migrate_legacy_volume_setting():
	if not config_file.has_section_key("Settings", "volume"):
		return

	# Preserve old overall volume preference as new master volume if present.
	config_file.set_value("Settings", "master_volume", config_file.get_value("Settings", "volume"))
	config_file.erase_section_key("Settings", "volume")
	save_data()


func get_setting(key: String, section: String= "Settings"):
	assert(config_file.has_section(section))
	assert(config_file.has_section_key(section, key))
	return config_file.get_value(section, key)


func update_setting(value: Variant, key: String, section: String= "Settings"):
	assert(config_file.has_section(section))
	assert(config_file.has_section_key(section, key))
	config_file.set_value(section, key, value)
	save_data()
	on_update_setting(value, key, section)
	

func on_update_setting(value: Variant, key: String, section: String):
	if section == "Settings":
		match key:
			"master_volume":
				AudioServer.set_bus_volume_db(0, linear_to_db(value / 100.0))
			"bgm_volume":
				if is_instance_valid(Global) and Global.has_method("set_bgm_volume_percent"):
					Global.set_bgm_volume_percent(float(value))
			"sfx_volume":
				if is_instance_valid(SoundPlayer) and SoundPlayer.has_method("set_sfx_volume_percent"):
					SoundPlayer.set_sfx_volume_percent(float(value))
				if is_instance_valid(PositionalSoundPlayer) and PositionalSoundPlayer.has_method("set_sfx_volume_percent"):
					PositionalSoundPlayer.set_sfx_volume_percent(float(value))
			"fullscreen":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
