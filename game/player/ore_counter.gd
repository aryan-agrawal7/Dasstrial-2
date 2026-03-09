## Tracks the count of each ore type collected by the player.
## Replaces the full Inventory system with simple integer counters.
class_name OreCounter

signal updated

## Dictionary mapping ore item resource name (String) -> count (int)
var counts: Dictionary = {}

## Preloaded ore item resources for lookup
var ore_items: Array[Item] = []


func _init():
	# Will be populated by the player on ready
	pass


func register_ore(item: Item):
	if item and item.name not in counts:
		ore_items.append(item)
		counts[item.name] = 0


func add_ore(item: Item, amount: int = 1):
	if item == null:
		return
	if item.name not in counts:
		register_ore(item)
	counts[item.name] += amount
	updated.emit()


func get_count(item: Item) -> int:
	if item and item.name in counts:
		return counts[item.name]
	return 0


func get_count_by_name(ore_name: String) -> int:
	if ore_name in counts:
		return counts[ore_name]
	return 0
	
func consume_item(item_name: String, player: BasePlayer) -> bool:
	if item_name in counts and counts[item_name] > 0:
		counts[item_name] -= 1
		updated.emit() # Notify UI to update counts
		
		# Apply your specific healing/repair logic
		match item_name:
			"water":
				player.health.hitpoints = min(player.health.max_hitpoints, player.health.hitpoints + 20)
				player.hull_temp = max(0, player.hull_temp + 20)
			"oxygen":
				player.health.hitpoints = min(player.health.max_hitpoints, player.health.hitpoints + 40)
			"iron_ore":
				player.drill_sharpness = min(player.max_sharpness, player.drill_sharpness+25)
			"gold_ore":
				player.hull_integrity = min(player.max_integrity, player.hull_integrity + 20)
		return true
	return false
