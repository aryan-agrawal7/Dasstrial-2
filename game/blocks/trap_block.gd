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
				# Screen flash + camera shake for explosion
				if is_instance_valid(player):
					_flash_screen(player, Color(1.0, 0.6, 0.0, 0.6))
					_shake_camera(player, 12.0, 0.4)
					_spawn_damage_label(player, "EXPLOSION!", Color(1.0, 0.4, 0.0))
			
			if trigger_delay > 0:
				world.get_tree().create_timer(trigger_delay).timeout.connect(callable)
			else:
				callable.call()
		
		TrapType.HEAT_BURST:
			if is_instance_valid(player):
				player.hull_temp = max(0.0, player.hull_temp - damage_value)
				# Also deal direct HP damage so it's noticeable
				if player.health and player.health.is_inside_tree():
					var hp_dmg := damage_value * 0.4
					player.health.receive_damage(Damage.new(hp_dmg, Damage.Type.ENVIRONMENT))
				_flash_screen(player, Color(1.0, 0.15, 0.0, 0.55))
				_shake_camera(player, 8.0, 0.3)
				_spawn_damage_label(player, "HEAT BURST!", Color(1.0, 0.2, 0.05))
				
		TrapType.SHARPENER_DRAIN:
			if is_instance_valid(player):
				player.drill_sharpness = max(0.0, player.drill_sharpness - damage_value)
				# Also deal some HP damage
				if player.health and player.health.is_inside_tree():
					var hp_dmg := damage_value * 0.25
					player.health.receive_damage(Damage.new(hp_dmg, Damage.Type.ENVIRONMENT))
				_flash_screen(player, Color(0.5, 0.1, 0.8, 0.5))
				_shake_camera(player, 6.0, 0.25)
				_spawn_damage_label(player, "DRILL DAMAGED!", Color(0.6, 0.2, 1.0))


## Flash the screen with a colored overlay that fades out quickly.
func _flash_screen(player: BasePlayer, color: Color) -> void:
	if not player.ui or not player.ui.is_inside_tree():
		return

	var flash := ColorRect.new()
	flash.color = color
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	player.ui.add_child(flash)

	var tween := flash.create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_callback(flash.queue_free)


## Shake the camera by briefly offsetting it and tweening back.
func _shake_camera(player: BasePlayer, intensity: float, duration: float) -> void:
	var cam := player.get_viewport().get_camera_2d()
	if not cam:
		return

	var original_offset := cam.offset
	var shake_tween := cam.create_tween()
	var steps := 6
	var step_dur := duration / float(steps)
	for i in range(steps):
		var rand_offset := Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		# Decay intensity each step
		rand_offset *= (1.0 - float(i) / float(steps))
		shake_tween.tween_property(cam, "offset", original_offset + rand_offset, step_dur)
	shake_tween.tween_property(cam, "offset", original_offset, step_dur)


## Spawn a floating damage label above the player that rises and fades out.
func _spawn_damage_label(player: BasePlayer, text: String, color: Color) -> void:
	if not player.ui or not player.ui.is_inside_tree():
		return

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var settings := LabelSettings.new()
	settings.font_size = 28
	settings.font_color = color
	settings.outline_size = 4
	settings.outline_color = Color(0, 0, 0, 0.9)
	label.label_settings = settings

	# Position at center of the screen, slightly above middle
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.offset_top = -60
	label.offset_bottom = -30
	label.offset_left = -120
	label.offset_right = 120
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.ui.add_child(label)

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "offset_top", label.offset_top - 80, 1.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "offset_bottom", label.offset_bottom - 80, 1.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.2).set_ease(Tween.EASE_IN).set_delay(0.3)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)
