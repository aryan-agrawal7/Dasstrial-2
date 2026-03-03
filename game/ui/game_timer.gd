extends CanvasLayer

var elapsed_time: float = 0.0
var is_running: bool = false

@onready var timer_label: Label = $TimerPanel/HBoxContainer/TimerLabel


func _ready():
	# Don't auto-start — wait until a Game scene is actually running
	hide()
	get_tree().root.child_entered_tree.connect(_on_scene_changed)


func _on_scene_changed(node: Node):
	# Wait a frame so the scene is fully initialized
	await get_tree().process_frame
	if GameManager.is_ingame():
		# Connect to game_is_over signal to stop timer when game ends
		var game = Global.game
		if game and not game.game_is_over.is_connected(_on_game_over):
			game.game_is_over.connect(_on_game_over)
		reset_timer()
		show()
		start_timer()
	else:
		# We're in main menu or any non-game scene
		stop_timer()
		hide()


func _on_game_over(_win: bool):
	stop_timer()


func _process(delta):
	if is_running:
		elapsed_time += delta
		update_display()


func start_timer():
	is_running = true


func stop_timer():
	is_running = false


func reset_timer():
	elapsed_time = 0.0
	update_display()


func update_display():
	var minutes = int(elapsed_time) / 60
	var seconds = int(elapsed_time) % 60
	var milliseconds = int((elapsed_time - int(elapsed_time)) * 100)
	timer_label.text = "%02d:%02d:%02d" % [minutes, seconds, milliseconds]
