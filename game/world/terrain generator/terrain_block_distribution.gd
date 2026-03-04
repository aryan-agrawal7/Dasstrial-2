class_name TerrainBlockDistribution
extends Resource

@export var blocks: Array[Block]
@export var noise: FastNoiseLite
@export var noise_threshold: float
## Per-block thresholds (optional). If set, overrides noise_threshold per block.
## Higher threshold = rarer ore. Order must match blocks array.
@export var noise_thresholds: PackedFloat32Array = PackedFloat32Array()

var processed_noises: Array[FastNoiseLite]


func initialize():
	var current_seed: int
	if GameManager.world_seed:
		current_seed= hash(GameManager.world_seed)
	else:
		current_seed= Global.game.settings.world_seed
	
	if noise:
		for i in blocks.size():
			var new_noise: FastNoiseLite= noise.duplicate(true)
			new_noise.seed= current_seed
			processed_noises.append(new_noise)
			current_seed= wrapi(current_seed + 100, 0, 1_000_000)
		

func get_block(pos: Vector2i)-> Block:
	if not noise:
		return blocks[0]
	# Collect all blocks whose noise qualifies, then pick one at random
	# This ensures equal spawn chance when multiple ores share the same threshold
	var candidates: Array[Block] = []
	var bonus: float = GameManager.ore_spawn_bonus if GameManager else 0.0
	for i in len(blocks):
		var threshold: float = noise_thresholds[i] if i < noise_thresholds.size() else noise_threshold
		threshold -= bonus
		if processed_noises[i].get_noise_2dv(pos) > threshold:
			candidates.append(blocks[i])
	if candidates.is_empty():
		return null
	# Use a position-based hash for deterministic but uniform selection
	var pick: int = (hash(pos) & 0x7FFFFFFF) % candidates.size()
	return candidates[pick]
