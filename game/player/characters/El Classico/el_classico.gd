extends BasePlayer


@onready var animation_player_hand = $"AnimationPlayer Hand"
@onready var animation_player_feet = $"AnimationPlayer Feet"

## Nodes that form the polygon body (hidden when a skin is applied)
var _polygon_body_nodes: Array[String] = ["Torso", "Pants", "Head", "Hip", "Look Pivot"]

## The skin sprite added at runtime
var skin_sprite: Sprite2D


func _ready():
	super._ready()
	_apply_skin()


func _apply_skin():
	var skin_path: String = GameManager.skin_path
	if skin_path.is_empty():
		return

	var tex: Texture2D = load(skin_path)
	if not tex:
		return

	# Hide all polygon body parts
	for node_name in _polygon_body_nodes:
		var node: Node = body.get_node_or_null(node_name)
		if node and node is CanvasItem:
			(node as CanvasItem).hide()
		elif node:
			# For Node2D without visibility, hide all CanvasItem children
			for child in node.get_children():
				if child is CanvasItem:
					(child as CanvasItem).hide()

	# Create a Sprite2D for the skin, centered on the body.
	# The character body spans roughly 30x76 pixels.
	# Images are 500x500, so scale to fit the character height.
	skin_sprite = Sprite2D.new()
	skin_sprite.texture = tex
	skin_sprite.name = "SkinSprite"

	# Scale 500px image to ~76px tall (character height).
	# Since images are square, this gives ~76px wide too — close enough to the ~30px body width.
	# Use 0.15 scale: 500 * 0.15 = 75px
	var target_scale: float = 76.0 / tex.get_height()
	skin_sprite.scale = Vector2(target_scale, target_scale)

	# Position: Body node is at (0,0), character center is roughly at (0, -3)
	# CollisionShape2D is at (0, -2)
	skin_sprite.position = Vector2(0, -3)

	body.add_child(skin_sprite)
	# Move to front so it draws on top of any remaining nodes
	body.move_child(skin_sprite, -1)


func on_movement_walk():
	animation_player_feet.play("walk")


func on_movement_stop():
	animation_player_feet.play("RESET")


func on_swim():
	animation_player_feet.play("RESET")


func on_hand_action(action_name: String):
	animation_player_hand.play(action_name)


func subscribe_hand_action_finished(action_name: String, method: Callable):
	assert(animation_player_hand.has_animation(action_name))
	animation_player_hand.animation_finished.connect(method, CONNECT_ONE_SHOT)


func on_hand_action_finished():
	animation_player_hand.play("RESET")


func on_start_mining(action_name: String):
	animation_player_hand.play(action_name)


func on_stop_mining():
	animation_player_hand.play("RESET")


func _on_health_component_report_damage(_damage: Damage, _hitpoints: float):
	pass


func _on_vehicle_state_entered():
	animation_player_feet.play("enter_vehicle")


func _on_vehicle_state_exited():
	animation_player_feet.play("exit_vehicle")


func on_death():
	animation_player_hand.play("RESET")
	animation_player_feet.play("RESET")


