extends Node
## Every player-facing line comes from res://data/game_text.json (GDD 11).
##
## On start, this node reads the JSON and writes its text into the data
## resources (characters, critters, skills, statuses, items, sub actions), so
## the rest of the code keeps reading `display_name`, `use_text`,
## `battle_lines`... as before. It holds a reference to every patched
## resource, so later load() and preload() calls get the same patched copy.
##
## Matching: a resource's `text_id` (or `id` for statuses) matches the JSON
## entry's "id". Skills, moves and traits match by "id" first, then by name.
##
## Editing a line in game_text.json changes it in the game on the next run,
## or right away when you go back to the title screen and press Play.

signal reloaded

const PATH := "res://data/game_text.json"
const DATA_DIRS: Array[String] = [
	"res://data/characters",
	"res://data/monsters",
	"res://data/statuses",
	"res://data/items",
	"res://data/sub_actions",
]

## Plain stand-ins for fields that are still empty in game_text.json (Q35).
## They live here in the code only, outside the JSON, until Kiki writes them.
const STAND_INS: Dictionary = {
	"status.taunt.apply": "{target} is taunted.",
	"status.taunt.expire": "{target} is calm again.",
	"status.charmed.apply": "{target} is charmed.",
	"status.charmed.expire": "{target} is back to normal.",
	"status.stun.apply": "{target} is stunned.",
	"status.stun.tick": "{target} is stunned and skips the turn.",
	"status.stun.expire": "{target} can move again.",
	"status.stun.resisted": "{target} resists the stun.",
	"status.paralyze.apply": "{target} is paralyzed.",
	"status.paralyze.tick": "{target} is paralyzed and skips the turn.",
	"status.paralyze.expire": "{target} can move freely again.",
	"status.shield.apply": "{target} gains a shield of {amount}.",
	"status.shield.tick": "{target}'s shield absorbs {amount} damage.",
	"status.shield.expire": "{target}'s shield breaks.",
	"narration.RECRUIT_TO_RESERVE": "{target} goes to the reserve.",
	"narration.CALL_IN": "{user} calls in {target}.",
	"narration.KIKI_RESCUE": "Kiki joins the battle.",
	# Recruit talk (GDD 18). Kiki can write her own in battle_narration.
	"narration.RECRUIT_CRITTER_SAYS": "{target}: \"{line}\"",
	"narration.RECRUIT_LANGUAGE_LOCKED": "{target} speaks a language the party can't understand yet.",
	"narration.RECRUIT_NO_WORDS": "{target} has nothing to say yet.",
	"narration.RECRUIT_SOFTENED": "LUCKY! {target} keeps talking.",
	"narration.RECRUIT_LEAVE": "{target} leaves the battle.",
	"narration.RECRUIT_GIVE_MONEY": "{target} gives the party {amount} coins.",
	"narration.RECRUIT_GIVE_ITEM": "{target} gives the party a {item}.",
	"narration.RECRUIT_HEAL_PARTY": "{target} heals the party.",
}

var data: Dictionary = {}
var _patched: Array[Resource] = []
var _version := 0


func _ready() -> void:
	reload()


## Reads the JSON again and re-applies it to every known resource.
func reload() -> void:
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("GameText: could not open %s" % PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("GameText: %s is not valid JSON (check commas and quotes)" % PATH)
		return
	data = parsed
	_version += 1
	if _patched.is_empty():
		for dir in DATA_DIRS:
			_collect(dir)
	for resource in _patched:
		patch(resource)
	reloaded.emit()


# --- Lookups -----------------------------------------------------------------

## Text at a dotted path ("battle_narration.MISS", "ui_text.popups.miss").
## Empty or missing text returns `fallback`.
func text(path: String, fallback := "") -> String:
	var value: Variant = _at(path)
	if value is String and not (value as String).is_empty():
		return value
	return fallback


## Any value at a dotted path (dictionaries and lists included), or null.
func value(path: String) -> Variant:
	return _at(path)


## A list of lines at a dotted path.
func lines(path: String) -> PackedStringArray:
	return _to_lines(_at(path))


## One line of a list (menus): list_item("ui_text.battle_menu", 2, "Action").
func list_item(path: String, index: int, fallback := "") -> String:
	var list := lines(path)
	if index >= 0 and index < list.size() and not list[index].is_empty():
		return list[index]
	return fallback


func narration(key: String, fallback := "") -> String:
	return text("battle_narration." + key, STAND_INS.get("narration." + key, fallback))


func character(id: StringName) -> Dictionary:
	if id == &"":
		return {}
	var characters: Dictionary = data.get("characters", {})
	for group in ["raiders", "guardians", "story_characters", "sentinels"]:
		var found := _find_by_id(characters.get(group, []), id)
		if not found.is_empty():
			return found
	return _find_by_id(data.get("critters", []), id)


func status(id: StringName) -> Dictionary:
	return _find_by_id(data.get("statuses", []), id)


func sign_pages(id: StringName) -> PackedStringArray:
	return _to_lines(_find_by_id(_at("overworld.signs"), id).get("pages", []))


func race_description(race: StringName) -> String:
	var races: Dictionary = data.get("races", {})
	for group in ["story_races", "critter_races"]:
		for entry: Dictionary in races.get(group, []):
			if StringName(entry.get("name", "")) == race or StringName(entry.get("id", "")) == race:
				return entry.get("description", "")
	return ""


func conversations() -> Array:
	return _at("conversations.entries") if _at("conversations.entries") is Array else []


func expression_tags() -> Array[StringName]:
	var result: Array[StringName] = []
	for tag in lines("meta.expression_tags"):
		result.append(StringName(tag))
	if result.is_empty():
		result = [&"neutral", &"happy", &"worried", &"smug", &"surprised"]
	return result


# --- Patching resources ------------------------------------------------------

## Writes the JSON text into one resource. Safe to call many times.
func patch(resource: Resource) -> void:
	if resource is CombatantData:
		_patch_combatant(resource)
	elif resource is StatusData:
		_patch_status(resource)
	elif resource is ItemData:
		_patch_item(resource)
	elif resource is SubActionData:
		_patch_sub_action(resource)


func _patch_combatant(c: CombatantData) -> void:
	var entry := character(c.text_id)
	if entry.is_empty():
		return
	var full_name: String = entry.get("name", "")
	if full_name.begins_with("the "):
		c.article = "the "
		c.display_name = full_name.substr(4)
	elif not full_name.is_empty():
		c.article = ""
		c.display_name = full_name
	c.signature_weapon = entry.get("weapon", "")
	c.battle_intro = entry.get("battle_intro", "")
	if entry.get("battle_lines") is Dictionary:
		var by_event := {}
		var source: Dictionary = entry.battle_lines
		for event: String in source:
			by_event[event] = _to_lines(source[event])
		c.battle_lines = by_event
	if entry.has("humiliate_lines"):
		c.humiliate_lines = _to_lines(entry.humiliate_lines)
	if entry.get("defend") is Dictionary:
		c.defend_text = (entry.defend as Dictionary).get("battle_text", "")

	var moves: Array = entry.get("skills", entry.get("moves", []))
	for action in c.weapons + c.skills:
		_patch_action(action, _find_named(moves, action.text_id, action.display_name))
	var traits: Array = entry.get("traits", [])
	for battle_trait in c.traits:
		var trait_entry := _find_named(traits, battle_trait.text_id, battle_trait.display_name)
		if not trait_entry.is_empty():
			battle_trait.display_name = trait_entry.get("name", battle_trait.display_name)
			battle_trait.description = trait_entry.get("description", battle_trait.description)
			battle_trait.set_battle_text(trait_entry.get("battle_text", ""))


func _patch_action(action: ActionData, entry: Dictionary) -> void:
	if entry.is_empty():
		return
	action.display_name = entry.get("name", action.display_name)
	action.description = entry.get("description", action.description)
	var battle_text: String = entry.get("battle_text", "")
	action.use_text = battle_text if not battle_text.is_empty() else narration("DEFAULT_SKILL_USE", "{user} uses {action}!")
	var menu: String = entry.get("menu", "")
	if menu.contains(">"):
		action.menu_label = menu.get_slice(">", 1).strip_edges()
	action.outcome_success_lines = _to_lines(entry.get("battle_text_chances_success", []))
	action.outcome_fail_lines = _to_lines(entry.get("battle_text_chances_failed", []))


func _patch_status(s: StatusData) -> void:
	var entry := status(s.id)
	var key := "status.%s." % s.id
	s.display_name = entry.get("name", s.display_name)
	s.apply_text = _field(entry, "apply", key + "apply")
	s.trigger_text = _field(entry, "tick", key + "tick")
	s.expire_text = _field(entry, "expire", key + "expire")
	s.resisted_text = _field(entry, "resisted", key + "resisted")


func _patch_item(item: ItemData) -> void:
	var entry := _find_by_id(data.get("items", []), item.text_id)
	if entry.is_empty():
		return
	item.display_name = entry.get("name", item.display_name)
	item.description = entry.get("description", item.description)
	var battle_text: String = entry.get("battle_text", "")
	if not battle_text.is_empty():
		item.use_text = battle_text


func _patch_sub_action(sub: SubActionData) -> void:
	var entry := _find_by_id(data.get("sub_actions", []), sub.text_id)
	if entry.is_empty():
		return
	sub.display_name = entry.get("name", sub.display_name)
	sub.open_text = entry.get("opening", sub.open_text)
	sub.fallback_text = entry.get("taunt_fallback", sub.fallback_text)
	sub.react_text = entry.get("enemy_reaction", sub.react_text)


# --- Helpers -----------------------------------------------------------------

func _collect(dir: String) -> void:
	for file in DirAccess.get_files_at(dir):
		file = file.trim_suffix(".remap") # exported builds
		if file.ends_with(".tres") or file.ends_with(".res"):
			var resource := load(dir.path_join(file))
			if resource:
				_patched.append(resource)


func _at(path: String) -> Variant:
	var node: Variant = data
	for part in path.split("."):
		if node is Dictionary and (node as Dictionary).has(part):
			node = node[part]
		else:
			return null
	return node


## Text of a JSON field, or the code stand-in when the field is empty.
func _field(entry: Dictionary, field: String, stand_in_key: String) -> String:
	var value: String = entry.get(field, "")
	return value if not value.is_empty() else STAND_INS.get(stand_in_key, "")


static func _to_lines(value: Variant) -> PackedStringArray:
	var result := PackedStringArray()
	if value is Array:
		for line in value:
			if line is String and not (line as String).is_empty():
				result.append(line)
	return result


static func _find_by_id(list: Variant, id: StringName) -> Dictionary:
	if list is Array:
		for entry in list:
			if entry is Dictionary and StringName(entry.get("id", "")) == id:
				return entry
	return {}


## Finds a skill, move or trait by its "id", then by its name.
static func _find_named(list: Array, id: StringName, name: String) -> Dictionary:
	for entry in list:
		if entry is Dictionary and id != &"" and StringName(entry.get("id", "")) == id:
			return entry
	for entry in list:
		if not entry is Dictionary:
			continue
		var entry_name: String = entry.get("name", "")
		if entry_name == name or (id != &"" and StringName(entry_name.to_snake_case().replace("-", "_")) == id):
			return entry
	return {}
