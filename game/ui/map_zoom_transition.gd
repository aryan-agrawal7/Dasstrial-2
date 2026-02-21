extends CanvasLayer
## Fetches satellite map tiles at increasing zoom levels and plays a
## smooth zoom-in animation before loading the actual game scene.

@onready var map_a: TextureRect = $MapA
@onready var map_b: TextureRect = $MapB
@onready var fade_rect: ColorRect = $Fade
@onready var loading_label: Label = $"Loading Label"

## Satellite zoom levels to fetch (earth → street)
const ZOOM_LEVELS: Array[int] = [2, 5, 8, 11, 14, 17]

var _images: Dictionary = {}  # zoom_level -> ImageTexture
var _pending_requests: int = 0
var _animation_started: bool = false


func _ready():
	map_a.pivot_offset = map_a.size / 2
	map_b.pivot_offset = map_b.size / 2
	map_a.modulate.a = 0
	map_b.modulate.a = 0

	if GameManager.GOOGLE_API_KEY.is_empty():
		loading_label.text = "No API key — loading game..."
		_load_game_scene()
		return

	loading_label.text = "Loading map..."
	_fetch_all_tiles()


func _fetch_all_tiles():
	_pending_requests = ZOOM_LEVELS.size()

	for zoom in ZOOM_LEVELS:
		var http = HTTPRequest.new()
		http.name = "MapRequest_%d" % zoom
		add_child(http)
		http.request_completed.connect(_on_tile_received.bind(zoom, http))

		var url = "https://maps.googleapis.com/maps/api/staticmap?center=%f,%f&zoom=%d&size=640x640&maptype=satellite&key=%s" % [
			GameManager.location_lat, GameManager.location_lng, zoom, GameManager.GOOGLE_API_KEY
		]
		http.request(url)


func _on_tile_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, zoom: int, http: HTTPRequest):
	http.queue_free()

	if response_code == 200 and body.size() > 0:
		var image = Image.new()
		var error = image.load_png_from_buffer(body)
		if error == OK:
			_images[zoom] = ImageTexture.create_from_image(image)

	_pending_requests -= 1
	loading_label.text = "Loading map... (%d/%d)" % [
		ZOOM_LEVELS.size() - _pending_requests, ZOOM_LEVELS.size()
	]

	if _pending_requests <= 0 and not _animation_started:
		_animation_started = true
		_play_zoom_animation()


func _play_zoom_animation():
	loading_label.hide()

	# Collect available images in order
	var ordered_images: Array[ImageTexture] = []
	for zoom in ZOOM_LEVELS:
		if _images.has(zoom):
			ordered_images.append(_images[zoom])

	if ordered_images.is_empty():
		_load_game_scene()
		return

	# Recalculate pivots now that layout is settled
	map_a.pivot_offset = map_a.size / 2
	map_b.pivot_offset = map_b.size / 2

	# Show first image
	map_a.texture = ordered_images[0]
	map_a.modulate.a = 1.0
	map_a.scale = Vector2.ONE
	map_b.modulate.a = 0.0

	# Short pause before starting zoom
	await get_tree().create_timer(0.4).timeout

	# Animate through each consecutive pair
	for i in range(ordered_images.size() - 1):
		map_b.texture = ordered_images[i + 1]
		map_b.scale = Vector2.ONE
		map_b.modulate.a = 0.0

		# Zoom current image in while cross-fading to the next
		var tween = create_tween().set_parallel()
		tween.tween_property(map_a, "scale", Vector2(3.0, 3.0), 0.85) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(map_a, "modulate:a", 0.0, 0.6).set_delay(0.25)
		tween.tween_property(map_b, "modulate:a", 1.0, 0.5).set_delay(0.35)
		await tween.finished

		# Swap: put the new image on map_a for the next iteration
		map_a.texture = ordered_images[i + 1]
		map_a.scale = Vector2.ONE
		map_a.modulate.a = 1.0
		map_b.modulate.a = 0.0

	# Hold on last image, then fade to black
	await get_tree().create_timer(0.5).timeout

	var fade_tween = create_tween()
	fade_tween.tween_property(fade_rect, "color:a", 1.0, 0.8)
	await fade_tween.finished

	_load_game_scene()


func _load_game_scene():
	await get_tree().create_timer(0.3).timeout
	if GameManager.game_scene_to_load:
		GameManager.run_game(GameManager.game_scene_to_load)
	else:
		push_warning("MapZoomTransition: No game scene to load, returning to menu.")
		GameManager.load_main_menu()
