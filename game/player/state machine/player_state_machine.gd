extends FiniteStateMachine
class_name PlayerStateMachine

@onready var player: BasePlayer= get_parent()
@onready var default_state: PlayerState = $"Default"
@onready var mining_state: PlayerMiningState = $"Mining"
@onready var item_using_state: PlayerState = $"Item Using"
@onready var item_charging_state: PlayerState = $"Item Charging"
@onready var dying_state: PlayerState = $"Dying"
@onready var fishing_state: PlayerFishingState = $Fishing



func _on_charge_item():
	change_state(item_charging_state)


func _on_start_mining():
	change_state(mining_state)


func _on_use_item():
	change_state(item_using_state)


func _on_stop_mining():
	change_state(default_state)


func _on_stop_using_item():
	change_state(default_state)


func _on_exit_vehicle():
	change_state(default_state)


func release_charge(charge_primary: bool, total_charge: float):
	player.release_charge(charge_primary, total_charge)
