class_name TrapBlock
extends Block

enum TrapType { EXPLOSION, HEAT_BURST, SHARPENER_DRAIN }

@export_category("Trap Settings")
@export var trap_type: TrapType = TrapType.EXPLOSION
@export var damage_value: float = 20.0
@export var trigger_delay: float = 0.5

func on_mined(world: World, tile_pos: Vector2i, player: BasePlayer):
	match trap_type:
		TrapType.EXPLOSION:
			var callable = func(): 
				if is_instance_valid(world): 
					world.explosion(tile_pos, damage_value, 2.0, 1.0)
			
			if trigger_delay > 0:
				world.get_tree().create_timer(trigger_delay).timeout.connect(callable)
			else:
				callable.call()
		
		TrapType.HEAT_BURST:
			if is_instance_valid(player):
				player.hull_temp = max(0.0, player.hull_temp - damage_value)
				
		TrapType.SHARPENER_DRAIN:
			if is_instance_valid(player):
				player.drill_sharpness = max(0.0, player.drill_sharpness - damage_value)
