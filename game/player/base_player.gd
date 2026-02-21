class_name BasePlayer
extends CharacterBody2D

signal break_block(block: Block)


const FLY_SPEED_FACTOR= 4.0

@export_category("Movement")
@export var speed: float = 200.0
@export var mining_speed: float= 1.0
@export var swim_speed: float= 30.0
@export var swim_acceleration: float= 1.0
@export var swim_damping: float= 1

@export_category("Auto-Mine")
## Time in seconds between each auto-mine action
@export var auto_mine_interval: float = 0.12
## If true, player constantly digs downward and cannot stop
@export var auto_mine_enabled: bool = true

@export_category("Health")
@export var fall_damage_speed: float= 600
@export var fall_damage_scale: float= 0.5

@export_category("Misc")
@export var freeze: bool= false

@export_category("Components")
@export var body: Node2D
@export var look_pivot: Node2D
@export var main_hand: Hand
@export var interaction_area: Area2D

@export_category("Scenes")
@export var block_marker_scene: PackedScene
@export var block_breaker_scene: PackedScene
@export var mine_raycast_scene: PackedScene

## Preloaded ore item resources
var ORE_COAL: Item = preload("res://game/items/coal ore/coal_ore.tres")
var ORE_IRON: Item = preload("res://game/items/iron ore/iron_ore.tres")
var ORE_GOLD: Item = preload("res://game/items/gold ore/gold_ore.tres")
var ORE_GODOT: Item = preload("res://game/items/godot ore/godot_ore.tres")

@onready var ui: UI = $"Player UI"
@onready var low_tile_detector: TileDetector = $"Low Tile Detector"
@onready var mid_tile_detector: TileDetector = $"Mid Tile Detector"
@onready var collision_shape: CollisionShape2D  = $CollisionShape2D
@onready var health: HealthComponent = $"Health Component"
@onready var hurtbox = $"Hurt Box"
@onready var vehicle_logic: PlayerVehicleLogic = $Vehicle

@onready var state_machine: PlayerStateMachine = $"State Machine"


var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var ray_cast: RayCast2D

# rectangle to mark the block we are currently looking at
var block_marker: Sprite2D
# overlay to indicate the breaking progress of the currently mined block
var block_breaker: AnimatedSprite2D

## Simple ore counter replacing the full inventory system
var ore_counter: OreCounter = OreCounter.new()

# disable fall damage when spawned
var disable_fall_damage: bool= true

var active_effects: Array[PlayerEffect]

var in_vehicle: Vehicle

## Timer tracking auto-mine cooldown
var auto_mine_timer: float = 0.0
## Tracks last horizontal input direction for auto-mining
var auto_mine_direction: int = 0


func _ready():
	assert_export_scenes()

	var game: Game= get_parent()
	assert(game)
	game.player= self

	ray_cast= mine_raycast_scene.instantiate()
	look_pivot.add_child(ray_cast)

	motion_mode= CharacterBody2D.MOTION_MODE_GROUNDED

	# Register the 4 ore types
	ore_counter.register_ore(ORE_COAL)
	ore_counter.register_ore(ORE_IRON)
	ore_counter.register_ore(ORE_GOLD)
	ore_counter.register_ore(ORE_GODOT)

	init_block_indicators()


func _process(_delta):
	if freeze: return

	# Face the direction the player is moving
	if auto_mine_direction > 0:
		body.scale.x = 1
	elif auto_mine_direction < 0:
		body.scale.x = -1


func _physics_process(delta):
	if freeze: return

	if in_vehicle:
		vehicle_logic.on_physics_process(delta)
	else:
		if state_machine.current_state.can_move:
			sidescroll_movement(delta)
		# Auto-mine blocks below and in movement direction
		if auto_mine_enabled:
			auto_mine(delta)

	tick_effects()


func sidescroll_movement(delta):
	# In auto-mine mode: gravity always applies, no jumping, left/right only
	if is_swimming():
		swim(delta)
		return

	if Global.game.cheats.fly:
		fly(delta)
		return

	# Gravity always applies
	if not is_on_floor():
		if low_tile_detector.is_in_fluid():
			velocity.y += gravity / 20 * delta
		else:
			velocity.y += gravity * delta

	# Left/right only — no jump
	var direction = Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * get_max_speed()
		auto_mine_direction = 1 if direction > 0 else -1
	else:
		velocity.x = 0

	if is_on_floor():
		disable_fall_damage = true  # no fall damage in auto-mine game
		if abs(velocity.x) > 0:
			on_movement_walk()
		else:
			on_movement_stop()

	move_and_slide()





func tick_effects():
	for effect in active_effects.duplicate():
		if not effect.tick():
			active_effects.erase(effect)


func on_movement_walk():
	pass


func on_movement_stop():
	pass


func swim(delta: float):
	on_swim()

	var direction= Input.get_axis("left", "right")
	if direction:
		velocity.x= move_toward(velocity.x, direction * swim_speed, swim_acceleration)

	# No upward swimming — player always sinks down
	velocity.y = swim_speed

	move_and_slide()

	velocity*= 1 - delta * swim_damping


func on_swim():
	pass


## Auto-mine: continuously break blocks below the player and in the movement direction.
## This is the core mechanic — the player drills downward and cannot stop.
func auto_mine(delta: float):
	auto_mine_timer += delta
	if auto_mine_timer < auto_mine_interval:
		return
	auto_mine_timer = 0.0

	var world: World = get_world()
	if not world: return

	var tile_pos: Vector2i = get_tile_pos()

	# Always mine the block directly below the player (feet level)
	try_auto_mine_block(world, tile_pos + Vector2i(0, 1))
	# Also mine the block at the player's center (handles 2-tile tall collisions)
	try_auto_mine_block(world, tile_pos + Vector2i(0, 2))

	# If moving left or right, mine blocks in that direction
	if auto_mine_direction != 0:
		# Mine at body level (head and torso height)
		try_auto_mine_block(world, tile_pos + Vector2i(auto_mine_direction, 0))
		# Mine at feet level in movement direction
		try_auto_mine_block(world, tile_pos + Vector2i(auto_mine_direction, 1))


func try_auto_mine_block(world: World, pos: Vector2i):
	var block: Block = world.get_block(pos)
	if block and block.can_be_mined():
		# If the block drops an ore item, add it directly to the counter
		if block.drop:
			ore_counter.add_ore(block.drop)
		# Break the block without spawning world items (with_drops = false)
		world.break_block(pos, false)
		break_block.emit(block)


func fly(_delta: float):
	var direction: Vector2= Input.get_vector("left", "right", "up", "down")
	velocity= direction * speed * FLY_SPEED_FACTOR
	move_and_slide()


## Called when a WorldItem touches the player (legacy pickup path).
## Routes ore items to the ore counter.
func can_pickup(_item: Item)-> bool:
	return true


func pickup(item: Item):
	ore_counter.add_ore(item)


func get_look_direction()-> Vector2:
	var vec: Vector2= look_pivot.transform.x
	vec.x*= body.scale.x
	return vec


func get_world()-> World:
	return get_parent().world


func fall_damage():
	health.receive_damage(Damage.new((velocity.y - fall_damage_speed) * fall_damage_scale, Damage.Type.FALL))


func assert_export_scenes():
	assert(body)
	assert(look_pivot)
	assert(interaction_area)
	assert(block_marker_scene)
	assert(block_breaker_scene)
	assert(mine_raycast_scene)


func init_block_indicators():
	block_marker= block_marker_scene.instantiate()
	add_child(block_marker)
	block_marker.top_level= true
	block_marker.hide()

	block_breaker= block_breaker_scene.instantiate()
	add_child(block_breaker)
	block_breaker.top_level= true
	block_breaker.hide()


func on_start_mining(_action_name: String):
	pass


func on_stop_mining():
	pass


func is_swimming()-> bool:
	return low_tile_detector.is_in_fluid() and mid_tile_detector.is_in_fluid()


func get_max_speed()-> float:
	var result: float= speed

	if low_tile_detector.is_in_fluid() or mid_tile_detector.is_in_fluid():
		result/= 2

	result*= get_effect_multiplier(PlayerEffect.Type.MOVE_SPEED)

	return result


func get_tile_pos()-> Vector2i:
	return get_world().get_tile(global_position)


func get_tile_distance(tile: Vector2i)-> int:
	return int((get_tile_pos() - tile).length())


func die():
	state_machine.change_state(state_machine.dying_state)
	on_death()


func on_death():
	pass


func init_death():
	freeze= true
	collision_shape.set_deferred("disabled", true)
	health.queue_free()
	hurtbox.queue_free()
	ui.queue_free()


func add_effect(effect: PlayerEffect):
	active_effects.append(effect)


func enter_vehicle_seat(seat: VehicleSeat):
	state_machine.paused= true
	in_vehicle= seat.get_vehicle()
	vehicle_logic.on_enter(seat)
	seat.get_vehicle().on_enter()


func get_effect_multiplier(type: PlayerEffect.Type):
	var result: float= 1
	for effect in active_effects:
		if effect.type == type:
			result*= effect.multiplier
	return result


func is_in_tile(tile_pos: Vector2i)-> bool:
	var query= PhysicsShapeQueryParameters2D.new()
	var shape:= RectangleShape2D.new()
	shape.size= Vector2.ONE * World.TILE_SIZE
	query.shape= shape
	query.transform.origin= get_world().map_to_local(tile_pos)
	query.collision_mask= Utils.build_mask([Global.PLAYER_COLLISION_LAYER])
	if get_world_2d().direct_space_state.intersect_shape(query):
		return true
	return false


func is_frozen()-> bool:
	return freeze


# ---- Hand item stubs (no longer used, kept so state machine code doesn't crash) ----

func has_hand_object() -> bool:
	return false


func get_hand_object() -> HandItemObject:
	return null


func get_hand_object_type() -> HandItem.Type:
	return HandItem.Type.NONE


func on_hand_action(_action_name: String):
	pass


func hand_action_executed(_action_name: String = "", _primary: bool = true):
	pass


func hand_action_finished(_action_name: String = ""):
	if state_machine.current_state:
		state_machine.current_state.on_hand_action_finished()


func subscribe_hand_action_finished(_action_name: String, _method: Callable):
	pass


func on_hand_action_finished():
	pass


func play_hand_item_sound(_target_material: MaterialSoundLibrary.Type):
	pass
