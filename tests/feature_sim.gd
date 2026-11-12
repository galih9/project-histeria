extends Node
## Dev check: recruiting, Humiliate and recruited monsters fighting for the party.

const BATTLE := preload("res://battle/battle_scene.tscn")

func _ready() -> void:
	UserSettings.text_speed = UserSettings.TextSpeed.INSTANT
	var all: Array[String] = []
	var recruits := 0
	for i in 25:
		GameState.new_game()
		var battle: BattleController = BATTLE.instantiate()
		battle.set_script(load("res://tests/scripted_battle.gd"))
		add_child(battle)
		battle.view.narrated.connect(func(t: String) -> void: all.append(t))
		var enc := load(["res://data/encounters/mannequin_pair.tres", "res://data/encounters/machinist_crew.tres", "res://data/encounters/orb_and_mannequin.tres"][i % 3])
		battle.start(enc, GameState.party, GameState.inventory, 0, 4)
		var result: BattleResult = await battle.finished
		recruits += result.recruited.size()
		all.append("END outcome=%d recruited=%s party=%d" % [result.outcome, str(result.recruited.map(func(b): return b.display_name())), result.party.size()])
		battle.queue_free()
		await get_tree().process_frame
	var f := FileAccess.open("user://feature_log.txt", FileAccess.WRITE)
	f.store_string("\n".join(all))
	print("recruits total: ", recruits)
	for key in ["insulted", "joins the party", "refuses", "sees an opening", "wobbles", "printer", "HA!"]:
		print(key, ": ", all.filter(func(l: String) -> bool: return l.contains(key)).size())
	print("FEATURE DONE")
	get_tree().quit()
