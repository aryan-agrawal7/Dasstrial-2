extends CanvasLayer
## Fetches satellite map tiles at the antipode of the selected location
## and plays a smooth zoom-in animation showing the player character
## with a "You reached the antipode!" message.

@onready var map_a: TextureRect = $MapA
@onready var map_b: TextureRect = $MapB
@onready var fade_rect: ColorRect = $Fade
@onready var loading_label: Label = $"Loading Label"
@onready var character_sprite: TextureRect = $CharacterSprite
@onready var antipode_label: Label = $AntipodeLabel
@onready var location_label: Label = $LocationLabel
@onready var run_time_label: Label = $RunTimeLabel

## Satellite zoom levels: full set for land, reduced for water
const ZOOM_LEVELS_LAND: Array[int] = [2, 5, 8, 11, 14, 17]
const ZOOM_LEVELS_WATER: Array[int] = [2, 5, 8]

var _active_zoom_levels: Array[int] = ZOOM_LEVELS_LAND
var _images: Dictionary = {}  # zoom_level -> ImageTexture
var _pending_requests: int = 0
var _animation_started: bool = false
var _is_water: bool = false
var _geocode_done: bool = false
var _tiles_done: bool = false

var antipode_lat: float = 0.0
var antipode_lng: float = 0.0


func _ready():
	# CRITICAL: unpause immediately — we paused to stop chunk threads before this scene loaded.
	# All tweens and buttons need the tree to be running.
	get_tree().paused = false

	map_a.pivot_offset = map_a.size / 2
	map_b.pivot_offset = map_b.size / 2
	map_a.modulate.a = 0
	map_b.modulate.a = 0

	# Hide character and text overlays until the end
	character_sprite.modulate.a = 0
	antipode_label.modulate.a = 0
	location_label.modulate.a = 0
	run_time_label.modulate.a = 0

	# Show final run time
	var t: float = GameManager.final_run_time
	var mins := int(t) / 60
	var secs := int(t) % 60
	var ms := int((t - int(t)) * 100)
	run_time_label.text = "Run time: %02d:%02d:%02d" % [mins, secs, ms]

	# Calculate the antipode: negate latitude, shift longitude by 180°
	antipode_lat = -GameManager.location_lat
	antipode_lng = GameManager.location_lng + 180.0
	if antipode_lng > 180.0:
		antipode_lng -= 360.0

	if GameManager.GOOGLE_API_KEY.is_empty():
		loading_label.text = "No API key — returning to menu..."
		_return_to_menu()
		return

	loading_label.text = "Locating the antipode..."
	_load_character_skin()
	_check_if_water()
	_fetch_all_tiles()


func _load_character_skin():
	var skin_path: String = GameManager.skin_path
	if skin_path.is_empty():
		return
	var tex: Texture2D = load(skin_path)
	if tex:
		character_sprite.texture = tex


func _check_if_water():
	## Use reverse geocoding to detect if the antipode is over water.
	## If there are no meaningful results, it's likely ocean.
	var http = HTTPRequest.new()
	http.name = "GeocodeRequest"
	add_child(http)
	http.request_completed.connect(_on_geocode_response.bind(http))
	var url = "https://maps.googleapis.com/maps/api/geocode/json?latlng=%f,%f&key=%s" % [
		antipode_lat, antipode_lng, GameManager.GOOGLE_API_KEY
	]
	http.request(url)


func _on_geocode_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest):
	http.queue_free()
	_is_water = true  # assume water unless proven otherwise

	if response_code == 200 and body.size() > 0:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json and json.get("status") == "OK":
			var results: Array = json.get("results", [])
			# If there are results with types other than just "plus_code" or
			# broad political boundaries, it's likely land.
			for r in results:
				var types: Array = r.get("types", [])
				for t in types:
					# Any of these indicate a land address
					if t in ["street_address", "route", "locality", "sublocality",
							"administrative_area_level_1", "administrative_area_level_2",
							"administrative_area_level_3", "neighborhood",
							"premise", "subpremise", "postal_code", "country"]:
						_is_water = false
						break
				if not _is_water:
					break

	_geocode_done = true
	_try_start_animation()


func _fetch_all_tiles():
	# Always fetch all 6 tiles; we'll pick the right subset once we know land vs water
	var all_zooms := ZOOM_LEVELS_LAND
	_pending_requests = all_zooms.size()

	for zoom in all_zooms:
		var http = HTTPRequest.new()
		http.name = "AntipodeRequest_%d" % zoom
		add_child(http)
		http.request_completed.connect(_on_tile_received.bind(zoom, http))

		var url = "https://maps.googleapis.com/maps/api/staticmap?center=%f,%f&zoom=%d&size=640x640&maptype=satellite&key=%s" % [
			antipode_lat, antipode_lng, zoom, GameManager.GOOGLE_API_KEY
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
	var total := ZOOM_LEVELS_LAND.size()
	loading_label.text = "Locating the antipode... (%d/%d)" % [
		total - _pending_requests, total
	]

	if _pending_requests <= 0:
		_tiles_done = true
		_try_start_animation()


func _try_start_animation():
	if not _tiles_done or not _geocode_done or _animation_started:
		return
	_animation_started = true

	# Pick zoom levels based on water detection
	_active_zoom_levels = ZOOM_LEVELS_WATER if _is_water else ZOOM_LEVELS_LAND
	_play_zoom_animation()


func _play_zoom_animation():
	loading_label.hide()

	# Collect available images in order (only for the active zoom levels)
	var ordered_images: Array[ImageTexture] = []
	for zoom in _active_zoom_levels:
		if _images.has(zoom):
			ordered_images.append(_images[zoom])

	if ordered_images.is_empty():
		_show_character_overlay()
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

	# Hold on last image, then show the character overlay
	await get_tree().create_timer(0.3).timeout
	_show_character_overlay()


func _show_character_overlay():
	# Fade in the character sprite
	var char_tween = create_tween().set_parallel()
	char_tween.tween_property(character_sprite, "modulate:a", 1.0, 0.6) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await char_tween.finished

	await get_tree().create_timer(0.3).timeout
	antipode_label.scale = Vector2(0.3, 0.3)
	var text_tween = create_tween().set_parallel()
	text_tween.tween_property(antipode_label, "modulate:a", 1.0, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	text_tween.tween_property(antipode_label, "scale", Vector2.ONE, 0.6) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await text_tween.finished

	# Show location name below
	if not GameManager.location_name.is_empty():
		location_label.text = "Antipode of %s\n(%.4f°, %.4f°)" % [
			GameManager.location_name, antipode_lat, antipode_lng
		]
	else:
		location_label.text = "(%.4f°, %.4f°)" % [antipode_lat, antipode_lng]

	var loc_tween = create_tween()
	loc_tween.tween_property(location_label, "modulate:a", 1.0, 0.5) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await loc_tween.finished



func _return_to_menu():
	# Directly change to main menu — bypass load_main_menu() to avoid any state issues.
	get_tree().paused = false
	get_tree().change_scene_to_packed(GameManager.main_menu)
