class_name Interactable
extends Area2D
## Something the player can check with the confirm button: signs, NPCs,
## the snack stand. Shows lines in the world text box; can also heal the party.

@export_multiline var lines: PackedStringArray = []
## Restores the whole party (the prototype's way to recover outside battle).
@export var heals_party := false


func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	monitoring = false


func interact(_player: Player) -> void:
	if heals_party:
		GameState.restore_party()
	EventBus.world_message_requested.emit(lines)
