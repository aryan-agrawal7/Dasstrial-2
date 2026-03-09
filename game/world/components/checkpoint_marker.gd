extends Area2D

## Checkpoint marker placed at section boundaries.
## When the player touches it, it activates with an animation and
## records the position as the new respawn point.

@onready var sprite: Sprite2D = $Sprite2D
@onready var particles: CPUParticles2D = $CPUParticles2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var line: Line2D = $Line2D

var boundary_y: int = 0
var activated: bool = false

## Colors
const INACTIVE_COLOR := Color(0.5, 0.5, 0.5, 0.6)
const ACTIVE_COLOR := Color(1.0, 0.85, 0.2, 1.0)
const GLOW_COLOR := Color(1.0, 0.95, 0.5, 1.0)

const TILE_SIZE := 32  ## Matches World.TILE_SIZE — defined locally to avoid circular dependency


func _ready():
	body_entered.connect(_on_body_entered)
	set_inactive_visual()


func setup(y_pos: int, map_width_tiles: int = 50):
	boundary_y = y_pos
	# Position at the center of the boundary row
	position = Vector2(0, y_pos * TILE_SIZE + TILE_SIZE / 2)
	
	# Set collision shape to span the full map width
	var shape := RectangleShape2D.new()
	shape.size = Vector2(map_width_tiles * TILE_SIZE, TILE_SIZE * 2)
	collision_shape.shape = shape
	
	# Set the visual line to span the full width
	var half_width: float = (map_width_tiles * TILE_SIZE) / 2.0
	line.clear_points()
	line.add_point(Vector2(-half_width, 0))
	line.add_point(Vector2(half_width, 0))
	line.width = 3.0
	line.default_color = INACTIVE_COLOR


func set_inactive_visual():
	if line:
		line.default_color = INACTIVE_COLOR
	if particles:
		particles.emitting = false


func activate():
	if activated:
		return
	activated = true
	
	# Visual activation — glow line
	if line:
		line.default_color = ACTIVE_COLOR
		line.width = 5.0
	
	# Burst particles
	if particles:
		particles.emitting = true
	
	# Tween glow effect
	var tween := create_tween()
	tween.tween_property(line, "default_color", GLOW_COLOR, 0.3)
	tween.tween_property(line, "default_color", ACTIVE_COLOR, 0.5)
	
	# Record checkpoint
	var player_x: int = 0
	if Global.game and Global.game.player:
		player_x = Global.game.player.get_tile_pos().x
	SectionManager.activate_checkpoint(boundary_y, player_x)


func _on_body_entered(body: Node2D):
	if body is BasePlayer:
		activate()
