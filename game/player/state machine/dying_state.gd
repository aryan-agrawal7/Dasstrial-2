extends PlayerState


func on_enter():
	player.init_death()

	var tween= create_tween()
	tween.tween_property(player, "rotation", deg_to_rad(-90 * player.body.scale.x), 0.45).set_ease(Tween.EASE_OUT)
	await tween.finished

	player.queue_free()
