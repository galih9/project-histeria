extends Control
## Title menu: Play, a couple of options, Quit.
## Play starts a new game and loads the main scene behind the loading screen.
## Play also reloads game_text.json, so edited lines show up right away.

const GAME_SCENE := "res://main.tscn"
const BACKGROUND := preload("res://data/backgrounds/title_screen.tres")

enum Choice { PLAY, TEXT_SPEED, DAMAGE_NUMBERS, QUIT }

@onready var _menu: MenuList = %Menu
@onready var _background: ColorRect = %Background
@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _controls: Label = %Controls

var _index := 0


func _ready() -> void:
	BACKGROUND.apply_to(_background.material as ShaderMaterial)
	_title.text = GameText.text("boot_and_title.title.game_title", _title.text)
	_subtitle.text = GameText.text("boot_and_title.title.subtitle", _subtitle.text)
	_controls.text = GameText.text("boot_and_title.title.controls_hint", _controls.text)
	_menu.add_cancel_entry = false
	_menu.allow_cancel = false
	_run_menu()


func _run_menu() -> void:
	while is_inside_tree():
		_index = await _menu.choose(_entries(), _index)
		match _index:
			Choice.PLAY:
				GameText.reload()
				GameState.new_game()
				SceneRouter.change_scene(GAME_SCENE, true)
				return
			Choice.TEXT_SPEED:
				UserSettings.cycle_text_speed()
			Choice.DAMAGE_NUMBERS:
				UserSettings.toggle_damage_numbers()
			Choice.QUIT:
				get_tree().quit()
				return


func _entries() -> Array[MenuEntry]:
	var menu := "boot_and_title.title_menu"
	var damage := GameText.list_item("boot_and_title.damage_number_options", 0 if UserSettings.show_damage_numbers else 1,
		"On" if UserSettings.show_damage_numbers else "Off")
	return [
		MenuEntry.new(GameText.list_item(menu, 0, "Play")),
		MenuEntry.new(GameText.list_item(menu, 1, "Text speed"), null, UserSettings.text_speed_name()),
		MenuEntry.new(GameText.list_item(menu, 2, "Damage numbers"), null, damage),
		MenuEntry.new(GameText.list_item(menu, 3, "Quit")),
	]
