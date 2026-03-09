extends Node

## Autoload singleton that tracks which section of the descent the player is in.
## Sections: Crust → Mantle → Core → Mantle-2 → Crust-2

signal section_changed(old_section: String, new_section: String)

## Section definitions — order matters (checked sequentially)
var sections: Array[Dictionary] = [
	{"name": "Crust",    "start_y": 0,   "end_y": 299,  "color": Color(0.55, 0.35, 0.17)},
	{"name": "Mantle",   "start_y": 300,  "end_y": 449,  "color": Color(1.0, 0.35, 0.1)},
	{"name": "Core",     "start_y": 450,  "end_y": 599,  "color": Color(0.9, 0.1, 0.1)},
	{"name": "Mantle-2", "start_y": 600,  "end_y": 749, "color": Color(1.0, 0.35, 0.1)},
	{"name": "Crust-2",  "start_y": 750, "end_y": 1050, "color": Color(0.55, 0.35, 0.17)},
]

## The section boundary y-values (where checkpoints go)
var section_boundaries: Array[int] = [300, 450, 600, 750]

var current_section: String = ""

## Checkpoint tracking
var last_checkpoint_y: int = -1
var last_checkpoint_pos: Vector2i = Vector2i.ZERO
var checkpoints_activated: Array[int] = []


func _process(_delta: float):
	if not GameManager.is_ingame():
		return
	var game: Game = Global.game
	if game == null or game.player == null:
		return

	var player_y: int = game.player.get_tile_pos().y
	var section: Dictionary = get_section(player_y)
	if section.is_empty():
		return

	if section.name != current_section:
		var old := current_section
		current_section = section.name
		section_changed.emit(old, current_section)


func get_section(y: int) -> Dictionary:
	for s in sections:
		if y >= s.start_y and y <= s.end_y:
			return s
	return {}


func get_section_color(section_name: String) -> Color:
	for s in sections:
		if s.name == section_name:
			return s.color
	return Color.WHITE


func activate_checkpoint(y_boundary: int, player_x: int):
	if y_boundary not in checkpoints_activated:
		checkpoints_activated.append(y_boundary)
		last_checkpoint_y = y_boundary
		last_checkpoint_pos = Vector2i(player_x, y_boundary - 2)


func get_respawn_position() -> Vector2i:
	if last_checkpoint_y >= 0:
		return last_checkpoint_pos
	# Fallback to default spawn
	if Global.game:
		return Global.game.settings.player_spawn
	return Vector2i.ZERO


func reset():
	current_section = ""
	last_checkpoint_y = -1
	last_checkpoint_pos = Vector2i.ZERO
	checkpoints_activated.clear()
