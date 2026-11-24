class_name ItemData
extends ActionData
## A consumable from the bag. Uses the same effect list as skills.
## Name, description and battle text come from game_text.json (text_id = the item "id").


func _init() -> void:
	use_text = "{user} uses the {action}!"
	target = Target.SINGLE_ALLY
