extends Node
## Everything that persists between battles: the party, the bag, drives found,
## and which holograms have been beaten.

const MAX_PARTY_SIZE := 4

const STARTING_PARTY: Array[CombatantData] = [
	preload("res://data/characters/tata.tres"),
	preload("res://data/characters/ale.tres"),
]

const STARTING_ITEMS: Dictionary = {
	preload("res://data/items/cookie.tres"): 3,
	preload("res://data/items/fizzy_pop.tres"): 2,
	preload("res://data/items/mystery_sandwich.tres"): 1,
}

var party: Array[PartyMember] = []
var inventory := Inventory.new()
var drives: Array[DriveData] = []
## Hologram ids (see Hologram.hologram_id) that stay gone for this run.
var cleared_holograms: Dictionary = {}


func _ready() -> void:
	# Lets you press F6 on any scene and still have a party to fight with.
	new_game()


func new_game() -> void:
	party.clear()
	for data in STARTING_PARTY:
		party.append(PartyMember.new(data))
	inventory = Inventory.new()
	for item: ItemData in STARTING_ITEMS:
		inventory.add(item, STARTING_ITEMS[item])
	drives.clear()
	cleared_holograms.clear()


func has_room_in_party() -> bool:
	return party.size() < MAX_PARTY_SIZE


func add_party_member(data: CombatantData) -> PartyMember:
	var member := PartyMember.new(data)
	party.append(member)
	return member


## Full HP and MP for everyone, KO included.
func restore_party() -> void:
	for member in party:
		member.restore()


func mark_hologram_cleared(hologram_id: StringName) -> void:
	cleared_holograms[hologram_id] = true


func is_hologram_cleared(hologram_id: StringName) -> bool:
	return cleared_holograms.has(hologram_id)


## Sum of the party's Luck, used to nudge drive drops (GDD 04, "Luck and drops").
func party_luck() -> float:
	var total := 0.0
	for member in party:
		total += member.data.stats.luck
	return total
