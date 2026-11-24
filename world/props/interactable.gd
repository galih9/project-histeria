class_name Interactable
extends Area2D
## Something the player can check with the confirm button: signs, NPCs,
## the snack stand. Shows its pages from game_text.json (overworld.signs, by
## text_id) in the world text box; can also heal the party.

## The sign "id" in game_text.json.
@export var text_id: StringName
## Used only when text_id is empty.
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
	var pages := GameText.sign_pages(text_id) if text_id != &"" else lines
	EventBus.world_message_requested.emit(pages)
