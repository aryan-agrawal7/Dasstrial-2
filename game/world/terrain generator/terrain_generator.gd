class_name TerrainGenerator
extends Resource

@export var instructions: Array[TerrainGeneratorInstruction]
@export var height_noise: FastNoiseLite
@export var height_scale: float= 10.0


var cave_cache: Array[Vector2i]

var black_finish_block: Block = preload("res://game/blocks/finish_blocks/black_finish_block.tres")
var white_finish_block: Block = preload("res://game/blocks/finish_blocks/white_finish_block.tres")
var bottom_limit: int = 1050

## Section boundary y-values (used by world.gd for checkpoint placement)
var section_boundaries: Array[int] = [300, 450, 600, 750]



## Depth-specific block variants
var mantle_blocks: Dictionary = {
	"stone": preload("res://game/blocks/stone block/stone_mantle_block.tres"),
	"coal": preload("res://game/blocks/coal block/coal_mantle_block.tres"),
	"iron": preload("res://game/blocks/iron block/iron_mantle_block.tres"),
	"gold": preload("res://game/blocks/gold block/gold_mantle_block.tres"),
	"diamond": preload("res://game/blocks/diamond block/diamond_mantle_block.tres")
}

var core_blocks: Dictionary = {
	"stone": preload("res://game/blocks/stone block/stone_core_block.tres"),
	"coal": preload("res://game/blocks/coal block/coal_core_block.tres"),
	"iron": preload("res://game/blocks/iron block/iron_core_block.tres"),
	"gold": preload("res://game/blocks/gold block/gold_core_block.tres"),
	"diamond": preload("res://game/blocks/diamond block/diamond_core_block.tres")
}



func initialize():
	for instruction in instructions:
		instruction.initialize(self)


func get_block_id(pos: Vector2i)-> int:
	if pos.x < -25 or pos.x > 25:
		return -1

	if pos.y == bottom_limit or pos.y == bottom_limit - 1:
		if (pos.x + pos.y) % 2 == 0:
			return DataManager.get_block_id(black_finish_block)
		else:
			return DataManager.get_block_id(white_finish_block)
	elif pos.y > bottom_limit:
		return -1

	var block: Block
	var cave:= false

	for instruction in instructions:
		var new_block: Block= instruction.get_block(pos)
		if new_block:
			cave= new_block.is_air and instruction.is_cave
		block= new_block if new_block else block

	if cave:
		cave_cache.append(pos)

	if not block or block.is_air: return -1

	## Swap block visuals based on depth
	var section: String = get_section_name(pos.y)
	if section == "Mantle" or section == "Mantle-2":
		if mantle_blocks.has(block.name):
			block = mantle_blocks[block.name]
	elif section == "Core":
		if core_blocks.has(block.name):
			block = core_blocks[block.name]

	return DataManager.get_block_id(block)





func start_caching_caves():
	cave_cache= []


func is_cave(pos: Vector2i)-> bool:
	return pos in cave_cache


func get_height(x: int)-> int:
	if not height_noise: return 999999
	return int(height_noise.get_noise_1d(x) * height_scale)


## Returns a section name for the given y-position
func get_section_name(y: int) -> String:
	if y < 300:
		return "Crust"
	elif y < 450:
		return "Mantle"
	elif y < 600:
		return "Core"
	elif y < 750:
		return "Mantle-2"
	else:
		return "Crust-2"
