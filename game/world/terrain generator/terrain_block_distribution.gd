class_name TerrainBlockDistribution
extends Resource

@export var blocks: Array[Block]
@export var noise: FastNoiseLite
@export var noise_threshold: float
## Per-block spawn weights (must match blocks array order).
## Higher weight = more common relative to other ores.
## Example: [40, 30, 15, 5] → iron 44%, coal 33%, diamond 17%, gold 6%.
@export var spawn_weights: PackedFloat32Array = PackedFloat32Array()

var _ore_noise: FastNoiseLite


func initialize():
	var current_seed: int
	if GameManager.world_seed:
		current_seed = hash(GameManager.world_seed)
	else:
		current_seed = Global.game.settings.world_seed

	if noise:
		_ore_noise = noise.duplicate(true)
		_ore_noise.seed = current_seed


func get_block(pos: Vector2i) -> Block:
	if not noise:
		return blocks[0]

	# Single noise check: does an ore spawn here at all?
	# Only apply gold bonus to ore distributions (those with spawn_weights)
	var bonus: float = 0.0
	if not spawn_weights.is_empty() and GameManager:
		bonus = GameManager.ore_spawn_bonus
	var threshold: float = noise_threshold - bonus
	var noise_val: float = _ore_noise.get_noise_2d(float(pos.x), float(pos.y))
	if noise_val <= threshold:
		return null

	# Ore spawns here — pick WHICH ore using weighted random from position hash
	if spawn_weights.is_empty() or spawn_weights.size() != blocks.size():
		# Fallback: uniform pick
		var pick: int = (hash(pos) & 0x7FFFFFFF) % blocks.size()
		return blocks[pick]

	# Build cumulative weights (excluding gold from bonus boost)
	var total_weight: float = 0.0
	var cumulative: PackedFloat32Array = PackedFloat32Array()
	for i in spawn_weights.size():
		var w: float = spawn_weights[i]
		# Gold does not get boosted by gold ore_spawn_bonus
		var block: Block = blocks[i]
		if block and block.name != "" and block.name != "gold":
			w += bonus * 100.0  # Scale bonus into weight space
		total_weight += w
		cumulative.append(total_weight)

	# Deterministic pick from a hash-derived float in [0, total_weight)
	var h: float = float(hash(pos) & 0x7FFFFFFF) / float(0x7FFFFFFF) * total_weight
	for i in cumulative.size():
		if h < cumulative[i]:
			return blocks[i]

	return blocks[blocks.size() - 1]
