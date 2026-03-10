extends Node

const TILE_SET_PATH= "res://resources/tile_set.tres"

@export var orig_tile_set: TileSet
@export_dir var blocks_path: String
@export var blocks_suffix: String
@export_dir var items_path: String
@export_dir var block_entities_path: String
@export_dir var furnace_recipe_path: String
@export var fluid_library: FluidLibrary

@export_dir var scenarios_path
@export_dir var builtin_scenarios_path
@export_dir var characters_path

@export var sound_library: SoundLibrary
@export var material_sound_library: MaterialSoundLibrary

var tile_set: TileSet

var blocks: Array[Block]
var blocks_lookup: Dictionary

var block_entities: Array[BlockEntityDefinition]

var items: Array[Item]

var furnace_recipes: Dictionary

var builtin_scenarios: Array[PackedScene]
var scenarios: Array[PackedScene]
var characters: Array[PackedScene]


# ── Static resource paths for web export compatibility ──────────────────────
# DirAccess directory scanning does not work in HTML5/web builds.
# When you add or remove a resource, update the matching array below.

const STATIC_BLOCK_PATHS: Array[String] = [
	"res://game/blocks/air block/air_block.tres",
	"res://game/blocks/clay block/clay_block.tres",
	"res://game/blocks/coal block/coal_block.tres",
	"res://game/blocks/coal block/coal_core_block.tres",
	"res://game/blocks/coal block/coal_mantle_block.tres",
	"res://game/blocks/diamond block/diamond_block.tres",
	"res://game/blocks/diamond block/diamond_core_block.tres",
	"res://game/blocks/diamond block/diamond_mantle_block.tres",
	"res://game/blocks/dirt block/dirt_block.tres",
	"res://game/blocks/finish_blocks/black_finish_block.tres",
	"res://game/blocks/finish_blocks/white_finish_block.tres",
	"res://game/blocks/gold block/gold_block.tres",
	"res://game/blocks/gold block/gold_core_block.tres",
	"res://game/blocks/gold block/gold_mantle_block.tres",
	"res://game/blocks/grass block/grass_block.tres",
	"res://game/blocks/iron block/iron_block.tres",
	"res://game/blocks/iron block/iron_core_block.tres",
	"res://game/blocks/iron block/iron_mantle_block.tres",
	"res://game/blocks/oxygen_pod_block/oxygen_pod_block.tres",
	"res://game/blocks/smooth stone block/smooth_stone_block.tres",
	"res://game/blocks/stone block/stone_block.tres",
	"res://game/blocks/stone block/stone_core_block.tres",
	"res://game/blocks/stone block/stone_mantle_block.tres",
	"res://game/blocks/stone ramp/stone_ramp_block.tres",
	"res://game/blocks/water blocks/water_block.tres",
	"res://game/blocks/water blocks/water_half_block.tres",
	"res://game/blocks/water blocks/water_half_flowing_block.tres",
	"res://game/blocks/water blocks/water_quarter_block.tres",
	"res://game/blocks/water blocks/water_quarter_flowing_block.tres",
	"res://game/blocks/water blocks/water_source_block.tres",
	"res://game/blocks/water blocks/water_three_quarter_block.tres",
	"res://game/blocks/water blocks/water_three_quarter_flowing_block.tres",
	"res://game/blocks/water_pod_block/water_pod_block.tres",
]

const STATIC_ITEM_PATHS: Array[String] = [
	"res://game/items/clay/clay.tres",
	"res://game/items/coal ore/coal_ore.tres",
	"res://game/items/diamond ore/diamond_ore.tres",
	"res://game/items/fish/fish.tres",
	"res://game/items/fishing rod/fishing_rod.tres",
	"res://game/items/gold ore/gold_ore.tres",
	"res://game/items/grenade/grenade.tres",
	"res://game/items/iron ingot/iron_ingot.tres",
	"res://game/items/iron ore/iron_ore.tres",
	"res://game/items/iron rod/iron_rod.tres",
	"res://game/items/oxygen_pod/oxygen_pod.tres",
	"res://game/items/pickaxe/pickaxe.tres",
	"res://game/items/stone/stone.tres",
	"res://game/items/stone slab/stone_slab.tres",
	"res://game/items/sword/sword.tres",
	"res://game/items/water_pod/water_pod.tres",
]

const STATIC_BLOCK_ENTITY_PATHS: Array[String] = [
	"res://game/block entities/furnace/furnace.tres",
]

const STATIC_FURNACE_RECIPE_PATHS: Array[String] = [
	"res://game/recipes/furnace/iron.tres",
]

const STATIC_CHARACTER_PATHS: Array[String] = [
	"res://game/player/characters/El Classico/el_classico.tscn",
]

const STATIC_BUILTIN_SCENARIO_PATHS: Array[String] = [
	"res://game/scenarios/built in/freeplay/freeplay.tscn",
	"res://game/scenarios/built in/sandbox/sandbox.tscn",
]

const STATIC_SCENARIO_PATHS: Array[String] = [
	"res://game/scenarios/iron ingot challenge/iron_ingot_challenge.tscn",
]


func _ready():
	if Engine.is_editor_hint():
		return

	sound_library.build()
	material_sound_library.build()

	# Load blocks from static list (web-safe)
	for path in STATIC_BLOCK_PATHS:
		blocks.append(load(path))

	for i in len(blocks):
		blocks_lookup[blocks[i]]= i

	# Load items from static list
	for path in STATIC_ITEM_PATHS:
		items.append(load(path))

	# Load block entities from static list
	for path in STATIC_BLOCK_ENTITY_PATHS:
		block_entities.append(load(path))

	# Load furnace recipes from static list
	for path in STATIC_FURNACE_RECIPE_PATHS:
		var item = load(path)
		furnace_recipes[item.ingredient] = item

	# Load characters from static list
	for path in STATIC_CHARACTER_PATHS:
		characters.append(load(path))

	# Load scenarios from static lists
	for path in STATIC_BUILTIN_SCENARIO_PATHS:
		builtin_scenarios.append(load(path))

	for path in STATIC_SCENARIO_PATHS:
		scenarios.append(load(path))

	late_ready.call_deferred()


func late_ready():
	WorldChunk.create_tileset()
	fluid_library.build()


func find_furnace_recipe_for(ore: Item)-> FurnaceRecipe:
	if not furnace_recipes.has(ore):
		return null
	return furnace_recipes[ore]


func get_block(id: int)-> Block:
	assert(id < len(blocks))
	if id == -1:
		return null
	return blocks[id]


func get_block_id(block: Block)-> int:
	if not blocks_lookup.has(block):
		return -1
	return blocks_lookup[block]


func get_block_from_name(_name: String)-> Block:
	for block in blocks:
		if block.name == _name:
			return block
	push_warning("get_block_from_name(%s): cant find block" % [_name])
	return null
