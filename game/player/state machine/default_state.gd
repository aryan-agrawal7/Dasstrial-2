extends PlayerState



func on_physics_process(_delta: float):
	if player.is_frozen(): return

	# Auto-mine game: no mouse mining, no build menu
	# Mining is handled in base_player.auto_mine()
	# Just handle interaction with nearby entities (e.g. furnaces, chests)
	interaction_logic()


func interaction_logic():
	var areas: Array[Area2D]= player.interaction_area.get_overlapping_areas()

	if areas.is_empty(): 
		player.ui.set_interaction_hint()
		return
	
	var interaction_target: InteractionTarget= areas[0]

	player.ui.set_interaction_hint(interaction_target.get_interaction_hint(player), interaction_target.label_offset.global_position)

	if Input.is_action_just_pressed("interact"):
		interaction_target.interact(player)
