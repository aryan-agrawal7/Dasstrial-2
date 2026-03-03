extends CanvasLayer


@onready var game_mode_item_list = %"Game Mode ItemList"
@onready var skin_water: TextureButton = %"Skin Water"
@onready var skin_fire: TextureButton = %"Skin Fire"
@onready var location_line_edit: LineEdit = %"Location LineEdit"
@onready var location_suggestions: ItemList = %"Location Suggestions"
@onready var selected_location_label: Label = %"Selected Location Label"

## Path to the currently selected skin texture
var selected_skin_path: String = "res://game/Water-air.png"

## Selected location data
var selected_location_name: String = ""
var selected_location_lat: float = 0.0
var selected_location_lng: float = 0.0

## Internal autocomplete state
var _autocomplete_predictions: Array = []
var _debounce_timer: Timer
var _autocomplete_http: HTTPRequest
var _place_details_http: HTTPRequest


func _ready():
	get_tree().paused= false
	
	
	populate_lists()
	
	# Set up skin selection buttons
	skin_water.pressed.connect(_on_skin_selected.bind("res://game/Water-air.png", skin_water, skin_fire))
	skin_fire.pressed.connect(_on_skin_selected.bind("res://game/Fire-strcuture.png", skin_fire, skin_water))
	
	# Default select Water-air
	_highlight_skin(skin_water, true)
	_highlight_skin(skin_fire, false)
	
	# Location autocomplete setup
	_setup_location_autocomplete()


func _setup_location_autocomplete():
	_debounce_timer = Timer.new()
	_debounce_timer.one_shot = true
	_debounce_timer.wait_time = 0.4
	_debounce_timer.timeout.connect(_send_autocomplete_request)
	add_child(_debounce_timer)
	
	_autocomplete_http = HTTPRequest.new()
	_autocomplete_http.request_completed.connect(_on_autocomplete_response)
	add_child(_autocomplete_http)
	
	_place_details_http = HTTPRequest.new()
	_place_details_http.request_completed.connect(_on_place_details_response)
	add_child(_place_details_http)
	
	location_line_edit.text_changed.connect(_on_location_text_changed)
	location_suggestions.item_selected.connect(_on_suggestion_selected)
	
	if GameManager.GOOGLE_API_KEY.is_empty():
		location_line_edit.placeholder_text = "Set GOOGLE_API_KEY in game_manager.gd"
		location_line_edit.editable = false


func populate_lists():
	for scenario in DataManager.builtin_scenarios + DataManager.scenarios:
		game_mode_item_list.add_item(get_scene_name(scenario))

	game_mode_item_list.select(0)


func get_scene_name(scene: PackedScene)-> String:
	return scene.resource_path.rsplit("/")[-1].trim_suffix(".tscn").capitalize()


func _on_skin_selected(path: String, selected_btn: TextureButton, other_btn: TextureButton):
	selected_skin_path = path
	_highlight_skin(selected_btn, true)
	_highlight_skin(other_btn, false)


func _highlight_skin(btn: TextureButton, selected: bool):
	if selected:
		btn.modulate = Color.WHITE
		btn.self_modulate = Color.WHITE
	else:
		btn.modulate = Color(0.5, 0.5, 0.5, 0.7)
		btn.self_modulate = Color(0.5, 0.5, 0.5, 0.7)


# --- Location Autocomplete ---

func _on_location_text_changed(new_text: String):
	if new_text.length() < 2:
		location_suggestions.hide()
		return
	_debounce_timer.start()


func _send_autocomplete_request():
	var text = location_line_edit.text.strip_edges()
	if text.is_empty():
		return
	_autocomplete_http.cancel_request()
	var url = "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=%s&key=%s" % [
		text.uri_encode(), GameManager.GOOGLE_API_KEY
	]
	_autocomplete_http.request(url)


func _on_autocomplete_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if response_code != 200:
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if not json or json.get("status") != "OK":
		location_suggestions.hide()
		return
	_autocomplete_predictions = json.get("predictions", [])
	location_suggestions.clear()
	for pred in _autocomplete_predictions:
		location_suggestions.add_item(pred.get("description", ""))
	if _autocomplete_predictions.size() > 0:
		location_suggestions.show()
	else:
		location_suggestions.hide()


func _on_suggestion_selected(index: int):
	if index < 0 or index >= _autocomplete_predictions.size():
		return
	var prediction = _autocomplete_predictions[index]
	var place_id = prediction.get("place_id", "")
	var description = prediction.get("description", "")
	location_line_edit.text = description
	selected_location_name = description
	location_suggestions.hide()
	if place_id.is_empty():
		return
	var url = "https://maps.googleapis.com/maps/api/place/details/json?place_id=%s&fields=geometry&key=%s" % [
		place_id.uri_encode(), GameManager.GOOGLE_API_KEY
	]
	_place_details_http.request(url)


func _on_place_details_response(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if response_code != 200:
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if not json or json.get("status") != "OK":
		return
	var result = json.get("result", {})
	var geometry = result.get("geometry", {})
	var location = geometry.get("location", {})
	selected_location_lat = location.get("lat", 0.0)
	selected_location_lng = location.get("lng", 0.0)
	selected_location_label.text = "Location set: %s" % selected_location_name
	selected_location_label.add_theme_color_override("font_color", Color.GREEN_YELLOW)


# --- Navigation ---

func _on_close_button_pressed():
	get_tree().quit()


func _on_play_button_pressed():
	GameManager.world_seed = str(randi())
	GameManager.character = DataManager.characters[0]
	GameManager.skin_path = selected_skin_path
	GameManager.location_name = selected_location_name
	GameManager.location_lat = selected_location_lat
	GameManager.location_lng = selected_location_lng
	var scenarios: Array[PackedScene] = DataManager.builtin_scenarios + DataManager.scenarios
	GameManager.game_scene_to_load = scenarios[game_mode_item_list.get_selected_items()[0]]
	# Show zoom transition if location is selected and API key exists
	if selected_location_lat != 0.0 and not GameManager.GOOGLE_API_KEY.is_empty():
		get_tree().change_scene_to_file("res://game/ui/map_zoom_transition.tscn")
	else:
		GameManager.run_game(GameManager.game_scene_to_load)
