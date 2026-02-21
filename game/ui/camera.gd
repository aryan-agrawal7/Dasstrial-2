class_name Camera
extends Camera2D

@export var follow_node: Node2D
@export var free_cam: bool= false
@export var speed: float= 200


func _ready():
	# Hardcode the internal Godot camera limits so it refuses to render past the edges
	limit_left = -800
	limit_right = 800
	
	# Bottom limit: 150 tiles * 32 pixels per tile = 4800 pixels
	limit_bottom = 4800


func _process(delta):
	if free_cam:
		position+= Input.get_vector("left", "right", "up", "down") * speed * delta
	elif follow_node and is_instance_valid(follow_node):
		# We want the camera to stop following the player once they get too close to the edge.
		# If the player limit is 640, we stop the camera earlier so half the screen isn't blue void.
		# Assuming a typical screen width of ~1920 (960 half width), 
		# we clamp the camera's center to never pass -640 or +640.
		# You can adjust these numbers to perfectly hug the edge of your screen!
		var target_x = clamp(follow_node.global_position.x, -640, 640)
		# We also clamp the Y coordinate to stop the camera from showing the void below
		# 150 tiles * 32 pixels = 4800. We stop the camera center slightly above that.
		var target_y = min(follow_node.global_position.y, 4500)
		position= Vector2(target_x, target_y)
