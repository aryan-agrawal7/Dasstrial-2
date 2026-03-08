class_name Furnace
extends BaseBlockEntity

@export var default_texture: Texture2D
@export var working_texture: Texture2D


var fuel: float
var ore_type: Item
var ore_count: int

var product_type: Item
var product_count: int

var is_burning: bool= false: set= set_burning

var ticks_to_finish: float


func _ready():
	super()
	sprite.texture= default_texture


func tick(_world: World):
	if is_burning:
		ticks_to_finish-= 1
		if ticks_to_finish == 0:
			NodeDebugger.write(self, "product finished")
			product_count+= 1
			is_burning= false
		else:
			return
			
	if ore_type and ore_count > 0:
		var recipe: FurnaceRecipe= DataManager.find_furnace_recipe_for(ore_type)
		
		if fuel < recipe.required_fuel:
			return
		if product_type and product_type != recipe.product:
			return
		
		product_type= recipe.product
		fuel-= recipe.required_fuel
		ore_count-= 1
		ticks_to_finish= recipe.duration * World.ENTITY_TICKS
		is_burning= true
	
		NodeDebugger.write(self, "start recipe " + ore_type.name)


func interact(_player: BasePlayer):
	# Inventory system removed — furnace interaction disabled
	pass


func can_player_take_product(_player: BasePlayer)-> bool:
	return false


func can_player_add_fuel(_player: BasePlayer)-> bool:
	return false


func can_player_add_ore(_player: BasePlayer)-> bool:
	return false


func custom_interaction_hint(_player: BasePlayer, default_hint: String)-> String:
	return default_hint


func set_burning(b: bool):
	if is_burning != b:
		is_burning= b
		sprite.texture= working_texture if is_burning else default_texture	
