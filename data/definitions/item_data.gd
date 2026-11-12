class_name ItemData
extends ActionData
## A consumable from the bag. Uses the same effect list as skills.


func _init() -> void:
	use_text = "{user} uses the {action}!"
	target = Target.SINGLE_ALLY
