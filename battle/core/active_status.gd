class_name ActiveStatus
extends RefCounted
## A status currently on a battler. stacks = turns left (GDD 05).

var data: StatusData
var stacks: int
## Global counter value at the moment it was applied; breaks ties in trigger order.
var applied_order: int
## The battler who applied it (the taunter for Taunt).
var source: Battler
## Scales a stat modifier: 1.0 = as written, 1.5 = 50% stronger (Yawn +).
var strength := 1.0


func _init(status: StatusData, stack_count: int, order: int, from: Battler) -> void:
	data = status
	stacks = stack_count
	applied_order = order
	source = from
