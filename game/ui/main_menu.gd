extends CanvasLayer


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

## Difficulty selector nodes (built dynamically)
var _difficulty_option: OptionButton
var _difficulty_desc: Label


func _ready():
	get_tree().paused= false
	
	# Set up skin selection buttons
	skin_water.pressed.connect(_on_skin_selected.bind("res://game/Water-air.png", skin_water, skin_fire))
	skin_fire.pressed.connect(_on_skin_selected.bind("res://game/Fire-strcuture.png", skin_fire, skin_water))
	
	# Default select Water-air
	_highlight_skin(skin_water, true)
	_highlight_skin(skin_fire, false)
	
	# Location autocomplete setup
	_setup_location_autocomplete()

	# Difficulty selector (injected before the Play button)
	call_deferred("_build_difficulty_selector")


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


func _build_difficulty_selector() -> void:
	## Find the VBoxContainer that holds the skin/location/play UI
	## and inject the difficulty selector just before the Play button.
	var play_btn: Button = get_node_or_null(
		"PanelContainer/MarginContainer/VBoxContainer/Main Content MarginContainer/HBoxContainer/VBoxContainer/Play Button")
	if not play_btn:
		return
	var vbox: VBoxContainer = play_btn.get_parent()
	var play_idx: int = play_btn.get_index()

	# Separator label
	var diff_hdr := Label.new()
	diff_hdr.text = "Difficulty"
	diff_hdr.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.9))
	vbox.add_child(diff_hdr)
	vbox.move_child(diff_hdr, play_idx)

	# OptionButton
	_difficulty_option = OptionButton.new()
	_difficulty_option.add_item("Easy")
	_difficulty_option.add_item("Hard")
	_difficulty_option.add_item("Hell")
	_difficulty_option.selected = 0
	_difficulty_option.custom_minimum_size = Vector2(0, 36)
	_difficulty_option.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_difficulty_option)
	vbox.move_child(_difficulty_option, play_idx + 1)

	# Descriptor label
	_difficulty_desc = Label.new()
	_difficulty_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_difficulty_desc.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_difficulty_desc)
	vbox.move_child(_difficulty_desc, play_idx + 2)

	_difficulty_option.item_selected.connect(_on_difficulty_selected)
	_on_difficulty_selected(0)  # Set default text


## Difficulty descriptions shown below the dropdown
const DIFF_DESCRIPTIONS: Array = [
	"∞ lives  •  keep resources on respawn",
	"3 lives  •  lose resources on respawn",
	"1 life  •  no respawn",
]
const DIFF_COLORS: Array = [
	Color(0.35, 0.95, 0.5, 1.0),
	Color(1.0, 0.65, 0.1, 1.0),
	Color(0.95, 0.2, 0.15, 1.0),
]

func _on_difficulty_selected(idx: int) -> void:
	if not _difficulty_desc:
		return
	_difficulty_desc.text = DIFF_DESCRIPTIONS[idx]
	_difficulty_desc.add_theme_color_override("font_color", DIFF_COLORS[idx])


func _on_play_button_pressed():
	GameManager.world_seed = str(randi())
	GameManager.character = DataManager.characters[0]
	GameManager.skin_path = selected_skin_path
	GameManager.location_name = selected_location_name
	GameManager.location_lat = selected_location_lat
	GameManager.location_lng = selected_location_lng
	# Store selected difficulty for the game session
	if _difficulty_option:
		GameManager.selected_difficulty = _difficulty_option.selected
	# Always use Freeplay (first built-in scenario)
	GameManager.game_scene_to_load = DataManager.builtin_scenarios[0]
	# Show zoom transition if location is selected and API key exists
	if selected_location_lat != 0.0 and not GameManager.GOOGLE_API_KEY.is_empty():
		get_tree().change_scene_to_file("res://game/ui/map_zoom_transition.tscn")
	else:
		GameManager.run_game(GameManager.game_scene_to_load)
