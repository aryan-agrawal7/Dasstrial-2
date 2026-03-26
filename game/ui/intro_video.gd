extends CanvasLayer

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
var skipped:= false

func _ready():
	var stream = load("res://game/ui/Starting animation.mp4")
	if stream and stream is VideoStream:
		video_player.stream = stream
		video_player.volume_db = -80.0 # Mute video
		video_player.play()
	else:
		push_warning("Video stream not loaded or unsupported. Skipping intro.")
		_on_video_finished()

func _on_video_finished():
	if skipped: return
	skipped = true
	if GameManager.location_lat != 0.0 and not GameManager.GOOGLE_API_KEY.is_empty():
		get_tree().change_scene_to_file("res://game/ui/map_zoom_transition.tscn")
	else:
		GameManager.run_game(GameManager.game_scene_to_load)

func _process(_delta):
	# Allow skipping with Space, Esc, or Left Click
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_cancel") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_on_video_finished()
