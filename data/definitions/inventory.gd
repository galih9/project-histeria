class_name Inventory
extends RefCounted
## The party's bag: items with counts, kept in the order they were first added.

var _counts: Dictionary = {} # ItemData -> int


func add(item: ItemData, amount := 1) -> void:
	_counts[item] = count_of(item) + amount


## Takes one item out of the bag. Returns false when there is none left.
func consume(item: ItemData) -> bool:
	var current := count_of(item)
	if current <= 0:
		return false
	if current == 1:
		_counts.erase(item)
	else:
		_counts[item] = current - 1
	return true


func count_of(item: ItemData) -> int:
	return _counts.get(item, 0)


func items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item: ItemData in _counts:
		result.append(item)
	return result


func is_empty() -> bool:
	return _counts.is_empty()
