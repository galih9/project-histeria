extends Control
## Title menu: Play, a couple of options, Quit.
## Play starts a new game and loads the main scene behind the loading screen.

const GAME_SCENE := "res://main.tscn"
const BACKGROUND := preload("res://data/backgrounds/title_screen.tres")

enum Choice { PLAY, TEXT_SPEED, DAMAGE_NUMBERS, QUIT }

@onready var _menu: MenuList = %Menu
@onready var _background: ColorRect = %Background

var _index := 0


func _ready() -> void:
	BACKGROUND.apply_to(_background.material as ShaderMaterial)
	_menu.add_cancel_entry = false
	_menu.allow_cancel = false
	_run_menu()


func _run_menu() -> void:
	while is_inside_tree():
		_index = await _menu.choose(_entries(), _index)
		match _index:
			Choice.PLAY:
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
	return [
		MenuEntry.new("Play"),
		MenuEntry.new("Text speed", null, UserSettings.text_speed_name()),
		MenuEntry.new("Damage numbers", null, "On" if UserSettings.show_damage_numbers else "Off"),
		MenuEntry.new("Quit"),
	]
