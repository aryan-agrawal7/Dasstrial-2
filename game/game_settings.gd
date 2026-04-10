class_name GameSettings
extends Resource

enum Difficulty { EASY, HARD, HELL }

@export var world_seed: int
@export var player_spawn: Vector2i
@export var spawn_clearing_radius: int = 4
## Kept for backward compatibility with existing scenario .tres files.
@export var respawn_on_death: bool = true
@export var difficulty: Difficulty = Difficulty.EASY
@export var player_loadout: PlayerLoadout
