class_name SubActionOffer
extends RefCounted
## An open sub action: which one, and who it points at (Humiliate -> the enemy who missed).

var data: SubActionData
var target: Battler


func _init(sub_action: SubActionData, aimed_at: Battler) -> void:
	data = sub_action
	target = aimed_at
