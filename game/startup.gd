extends Node

func _ready():
	var video_player = VideoStreamPlayer.new()
	video_player.stream = load("res://game/ui/Starting animation.ogv")
	video_player.autoplay = true
	video_player.expand = true # just in case older version or property still exists
	video_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var canvas = CanvasLayer.new()
	var bg = ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	canvas.add_child(bg)
	canvas.add_child(video_player)
	add_child(canvas)
	
	video_player.finished.connect(_on_video_finished.bind(canvas))

func _on_video_finished(canvas: CanvasLayer):
	canvas.queue_free()
	GameManager.init()
