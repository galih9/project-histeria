extends Node
## Dev check: runs auto battles (AI on both sides) for every encounter and
## prints the outcome. Run headless:
##   godot --headless --fixed-fps 60 res://tests/battle_sim.tscn

const BATTLE := preload("res://battle/battle_scene.tscn")
const ENCOUNTERS := [
	"res://data/encounters/mannequin.tres",
	"res://data/encounters/mannequin_pair.tres",
	"res://data/encounters/orb_and_mannequin.tres",
	"res://data/encounters/stone_thing.tres",
	"res://data/encounters/machinist_crew.tres",
	"res://data/encounters/big_frog_boss.tres",
]
@export var runs_per_encounter := 20
@export var verbose_first := false

var _log: Array[String] = []

func _ready() -> void:
	UserSettings.text_speed = UserSettings.TextSpeed.INSTANT
	var first := true
	for path in ENCOUNTERS:
		var wins := 0
		var turns_total := 0
		for i in runs_per_encounter:
			GameState.new_game()
			var battle: BattleController = BATTLE.instantiate()
			battle.auto_battle = true
			add_child(battle)
			var lines: Array[String] = []
			lines.append("=== " + path.get_file())
			battle.view.narrated.connect(func(t: String) -> void: lines.append(t))
			battle.start(load(path), GameState.party, GameState.inventory, i % 3, 4)
			var result: BattleResult = await battle.finished
			if verbose_first and first:
				print("---- transcript ", path)
				for l in lines: print("   ", l)
				first = false
			if result.outcome == BattleResult.Outcome.VICTORY: wins += 1
			var hp := []
			for b in result.party: hp.append("%s %d/%d" % [b.display_name(), b.hp, b.max_hp()])
			lines.append("END " + str(result.outcome) + " " + ", ".join(hp))
			_log.append_array(lines)
			turns_total += lines.size()
			battle.queue_free()
			await get_tree().process_frame
		print("%-45s wins %d/%d  avg lines %d" % [path.get_file(), wins, runs_per_encounter, turns_total / runs_per_encounter])
	var f := FileAccess.open("user://battle_sim_log.txt", FileAccess.WRITE)
	f.store_string("\n".join(_log))
	print("SIM DONE ", ProjectSettings.globalize_path("user://battle_sim_log.txt"))
	get_tree().quit()
