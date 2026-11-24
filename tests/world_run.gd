extends Node
## Walks the playtest section the Game way: every hologram, Big Frog last,
## each through the real encounter flow (swirl, battle, back to the world).
## Checks the player comes back to the same spot and every hologram is cleared.
##   godot --headless --fixed-fps 60 res://tests/world_run.tscn
## With a display (xvfb-run, no --headless) it also saves screenshots to user://.

const MAIN := preload("res://main.tscn")

var _shots := 0


func _ready() -> void:
	UserSettings.text_speed = UserSettings.TextSpeed.INSTANT
	GameState.new_game()
	var main: Game = MAIN.instantiate()
	add_child(main)
	await _frames(30)
	var map: WorldMap = main._map
	var player := map.player
	await _shot("world")

	var holograms: Array[Hologram] = []
	for node in map.get_node("Entities").get_children():
		if node is Hologram:
			holograms.append(node)
	holograms.sort_custom(func(a: Hologram, b: Hologram) -> bool: return not a.encounter.is_boss and b.encounter.is_boss)

	var failures := 0
	var advantages := [EncounterData.Advantage.PARTY, EncounterData.Advantage.ENEMY, EncounterData.Advantage.NEUTRAL]
	for i in holograms.size():
		var holo := holograms[i]
		var id := holo.hologram_id
		GameState.restore_party()
		player.global_position = holo.global_position + Vector2(0, 30)
		await _frames(2)
		var spot := player.global_position
		var cleared := false
		var same_spot := false
		for attempt in 4: # a lost fight respawns the party; walk back and try again
			GameState.restore_party()
			player.global_position = holo.global_position + Vector2(0, 30)
			await _frames(2)
			spot = player.global_position
			BattleController.force_auto = i > 0 or attempt > 0
			EventBus.encounter_requested.emit(holo, advantages[i % 3])
			if i == 0 and attempt == 0:
				await _first_battle_by_hand(main)
			while main._in_battle:
				await _frames(1)
			await _frames(5)
			cleared = GameState.is_hologram_cleared(id)
			same_spot = player.global_position.distance_to(spot) < 1.0
			if cleared:
				break
			print("     %s: party lost, respawned at the start (attempt %d)" % [id, attempt + 1])
			for press in 3: # close the wake-up message
				await _press("confirm")
				await _frames(20)
			await _frames(160) # wait out the invulnerability after the respawn
		print("%s %-14s cleared=%s same_spot=%s" % ["PASS" if cleared and same_spot else "FAIL", id, cleared, same_spot])
		if not (cleared and same_spot):
			failures += 1
	await _shot("world_after")
	print("WORLD RUN DONE, %d failures" % failures)
	get_tree().quit(failures)


## The first fight plays through the menus with key presses, for the screenshots.
func _first_battle_by_hand(main: Game) -> void:
	await _frames(150)
	await _shot("battle_menu")
	await _press("move_down") # Skill
	await _press("confirm")
	await _frames(10)
	await _shot("battle_skills")
	await _press("cancel")
	await _press("move_up") # back to Attack
	await _press("confirm")
	await _frames(10)
	await _shot("battle_attack")
	await _press("confirm") # Melee
	await _frames(10)
	await _shot("battle_target")
	await _press("confirm") # target
	BattleController.force_auto = true
	await _frames(90)
	await _shot("battle_action")


func _press(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await _frames(2)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(4)


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	_shots += 1
	image.save_png("user://shot_%02d_%s.png" % [_shots, name])


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
