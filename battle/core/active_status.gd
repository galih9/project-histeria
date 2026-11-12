class_name ActiveStatus
extends RefCounted
## A status currently on a battler. stacks = turns left (GDD 05).

var data: StatusData
var stacks: int
## Global counter value at the moment it was applied; breaks ties in trigger order.
var applied_order: int
## The battler who applied it (used for credit in text and future rules).
var source: Battler


func _init(status: StatusData, stack_count: int, order: int, from: Battler) -> void:
	data = status
	stacks = stack_count
	applied_order = order
	source = from
