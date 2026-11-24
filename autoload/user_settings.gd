extends Node
## Player-facing options (GDD 03: text speed, fast battle mode, damage numbers).
## Saved to user://settings.cfg so they survive between sessions.

signal changed

enum TextSpeed { SLOW, NORMAL, FAST, INSTANT }

const SAVE_PATH := "user://settings.cfg"
const TEXT_SPEED_NAMES: Array[String] = ["Slow", "Normal", "Fast", "Instant"]
## Characters typed per second for each TextSpeed. INSTANT shows the whole line at once.
const CHARS_PER_SECOND: Array[float] = [30.0, 60.0, 120.0, INF]
## How long a finished line stays before the battle moves on (a confirm press skips it).
const HOLD_SECONDS: Array[float] = [0.9, 0.6, 0.35, 0.15]

var text_speed := TextSpeed.NORMAL
var show_damage_numbers := true


func _ready() -> void:
	_load()


func chars_per_second() -> float:
	return CHARS_PER_SECOND[text_speed]


func hold_seconds() -> float:
	return HOLD_SECONDS[text_speed]


func text_speed_name() -> String:
	return GameText.list_item("boot_and_title.text_speed_options", text_speed, TEXT_SPEED_NAMES[text_speed])


func cycle_text_speed() -> void:
	text_speed = ((text_speed + 1) % TextSpeed.size()) as TextSpeed
	_save()
	changed.emit()


func toggle_damage_numbers() -> void:
	show_damage_numbers = not show_damage_numbers
	_save()
	changed.emit()


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	text_speed = clampi(config.get_value("text", "speed", text_speed), 0, TextSpeed.size() - 1) as TextSpeed
	show_damage_numbers = config.get_value("battle", "damage_numbers", show_damage_numbers)


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("text", "speed", text_speed)
	config.set_value("battle", "damage_numbers", show_damage_numbers)
	config.save(SAVE_PATH)
