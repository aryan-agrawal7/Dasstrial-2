## Simplified player UI: shows ore counters (top-right) and health bar.
## Replaces the full hotbar/inventory/crafting/build menu system.
class_name UI
extends CanvasLayer


@export var health: HealthComponent

@onready var player: BasePlayer = get_parent()
@onready var health_bar: ProgressBar = %"ProgressBar Health"
@onready var ore_container: VBoxContainer = %"Ore Container"
@onready var interaction_hint: Label = %"Interaction Hint"

## References to ore count labels, keyed by ore item name
var ore_labels: Dictionary = {}

var hurt_effect_tween: Tween


func _ready():
	assert(player)
	assert(health)

	health.report_damage.connect(hurt_effect)

	# Defer building the ore display — the player's _ready() hasn't run yet
	# (children are ready before parents in Godot), so ore_counter.ore_items
	# is still empty at this point. call_deferred ensures it runs next frame.
	call_deferred("_build_ore_display")
	call_deferred("_connect_ore_counter")


func _process(_delta):
	update_health()


func _connect_ore_counter():
	player.ore_counter.updated.connect(_update_ore_display)


func _build_ore_display():
	## Create a row for each registered ore: [icon] [count]
	for item in player.ore_counter.ore_items:
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)

		var icon := TextureRect.new()
		icon.texture = item.texture
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(32, 32)
		hbox.add_child(icon)

		var label := Label.new()
		label.text = "0"
		var settings := LabelSettings.new()
		settings.font_size = 22
		settings.font_color = Color.WHITE
		settings.outline_size = 3
		settings.outline_color = Color.BLACK
		label.label_settings = settings
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(label)

		ore_container.add_child(hbox)
		ore_labels[item.name] = label


func _update_ore_display():
	for item in player.ore_counter.ore_items:
		if item.name in ore_labels:
			ore_labels[item.name].text = str(player.ore_counter.get_count(item))


func update_health():
	var ratio: float = health.hitpoints / health.max_hitpoints
	if is_equal_approx(ratio, 1.0):
		health_bar.hide()
	else:
		health_bar.value = ratio * 100
		health_bar.show()


func hurt_effect(_damage, _hitpoints):
	if hurt_effect_tween and hurt_effect_tween.is_running():
		hurt_effect_tween.kill()
	hurt_effect_tween = create_tween()
	hurt_effect_tween.tween_property(health_bar, "modulate", Color.TRANSPARENT, 0.1)
	hurt_effect_tween.tween_property(health_bar, "modulate", Color.WHITE, 0.1)
	hurt_effect_tween.set_loops(3)


## Stub methods kept so other code doesn't crash if it still references them
func update_hotbar():
	pass


func update_inventory():
	_update_ore_display()


func set_interaction_hint(text: String = "", pos: Vector2 = Vector2.ZERO):
	interaction_hint.text = text
	interaction_hint.visible = not text.is_empty()
	if not text.is_empty():
		await get_tree().process_frame
		interaction_hint.position = get_viewport().canvas_transform * pos - Vector2(interaction_hint.size.x / 2, 0)
