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
