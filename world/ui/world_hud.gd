class_name WorldHud
extends CanvasLayer
## Overworld UI: the message box for signs and NPCs, and the pause menu
## (Resume / Party / Title). Emits `opened` and `closed` so the Game can pause
## the world while it's up. No HUD while walking, like EarthBound.

signal opened
signal closed

const TITLE_SCENE := "res://scenes/menu/main_menu.tscn"

enum PauseChoice { RESUME, PARTY, TITLE }

@onready var _text_box: TextBox = %MessageBox
@onready var _pause_menu: MenuList = %PauseMenu
@onready var _status_panel: PanelContainer = %StatusPanel
@onready var _status_label: Label = %StatusLabel

var _busy := false
var _enabled := true


func _ready() -> void:
	_text_box.hide()
	_status_panel.hide()
	_pause_menu.add_cancel_entry = false
	_pause_menu.keep_visible_on_select = true
	EventBus.world_message_requested.connect(show_message)


func is_busy() -> bool:
	return _busy


## Turns the pause button off during battles and transitions.
func set_enabled(enabled: bool) -> void:
	_enabled = enabled


func show_message(lines: PackedStringArray) -> void:
	if _busy or lines.is_empty():
		return
	_begin()
	_text_box.clear()
	for line in lines:
		await _text_box.say(line)
	_text_box.hide()
	_end()


func _unhandled_input(event: InputEvent) -> void:
	if _enabled and not _busy and event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		_open_pause_menu()


func _open_pause_menu() -> void:
	_begin()
	var index := 0
	while true:
		index = await _pause_menu.choose(_pause_entries(), index)
		if index == PauseChoice.PARTY:
			await _show_party_status()
		elif index == PauseChoice.TITLE:
			_pause_menu.close()
			SceneRouter.change_scene(TITLE_SCENE)
			return
		else:
			break # Resume or Cancel
	_pause_menu.close()
	_end()


func _pause_entries() -> Array[MenuEntry]:
	var path := "ui_text.pause_menu"
	return [
		MenuEntry.new(GameText.list_item(path, 0, "Resume")),
		MenuEntry.new(GameText.list_item(path, 1, "Party")),
		MenuEntry.new(GameText.list_item(path, 2, "Title")),
	]


func _show_party_status() -> void:
	var lines: PackedStringArray = []
	var row := GameText.text("ui_text.party_screen_row", "{name}   HP x/y   MP x/y")
	for member in GameState.party:
		lines.append(_party_row(row, member))
	lines.append(GameText.text("ui_text.party_screen_coins", "Coins: {count}").format({"count": GameState.coins}))
	lines.append(GameText.text("ui_text.party_screen_drives", "Drives: {count}").format({"count": GameState.drives.size()}))
	for drive in GameState.drives.slice(-3):
		lines.append("  " + drive.display_name())
	_status_label.text = "\n".join(lines)
	_status_panel.reset_size()
	_status_panel.show()
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("cancel") or Input.is_action_just_pressed("menu"):
			break
	_status_panel.hide()


## Fills the party row template: {name}, plus {hp} {max_hp} {mp} {max_mp}, or
## the two "x/y" spots in the order HP, MP.
static func _party_row(template: String, member: PartyMember) -> String:
	var values := {"name": member.data.display_name, "hp": member.hp, "max_hp": member.data.stats.max_hp,
		"mp": member.mp, "max_mp": member.data.stats.max_mp}
	var row := template.format(values)
	for pair in ["%d/%d" % [member.hp, member.data.stats.max_hp], "%d/%d" % [member.mp, member.data.stats.max_mp]]:
		var at := row.find("x/y")
		if at >= 0:
			row = row.substr(0, at) + pair + row.substr(at + 3)
	return row


func _begin() -> void:
	_busy = true
	opened.emit()


func _end() -> void:
	# Wait a frame so the closing key press doesn't also reach the player.
	await get_tree().process_frame
	_busy = false
	closed.emit()
