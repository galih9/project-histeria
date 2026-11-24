class_name Game
extends Node
## The main scene: holds the current world section and swaps to the battle
## scene when a hologram asks for a fight, then applies the result.

const BATTLE_SCENE := preload("res://battle/battle_scene.tscn")
const ESCAPE_INVULNERABLE_SECONDS := 2.0
const ESCAPE_STUN_SECONDS := 2.5

@onready var _world_root: Node2D = %WorldRoot
@onready var _battle_layer: CanvasLayer = %BattleLayer
@onready var _transition: EncounterTransition = %Transition
@onready var _hud: WorldHud = %WorldHud

var _map: WorldMap
var _in_battle := false


func _ready() -> void:
	_map = _world_root.get_child(0) as WorldMap
	EventBus.encounter_requested.connect(_on_encounter_requested)
	_hud.opened.connect(_set_world_active.bind(false))
	_hud.closed.connect(_set_world_active.bind(true))


func _on_encounter_requested(hologram: Node, advantage: int) -> void:
	if _in_battle or _hud.is_busy() or not hologram is Hologram:
		return
	var source := hologram as Hologram
	if source.encounter == null:
		return
	_in_battle = true
	_hud.set_enabled(false)
	# Contact arrives inside a physics callback, so pause the world one step later.
	_set_world_active.call_deferred(false)

	await _transition.cover_with_swirl(advantage as EncounterData.Advantage)
	var battle: BattleController = BATTLE_SCENE.instantiate()
	_battle_layer.add_child(battle)
	_world_root.hide()
	battle.start(source.encounter, GameState.party, GameState.inventory,
		advantage as EncounterData.Advantage, GameState.MAX_PARTY_SIZE)
	await _transition.reveal()

	var result: BattleResult = await battle.finished

	await _transition.cover_with_fade()
	battle.queue_free()
	_world_root.show()
	_apply_result(result, source)
	await _transition.reveal()

	_in_battle = false
	_hud.set_enabled(true)
	_set_world_active(true)
	if result.outcome == BattleResult.Outcome.DEFEAT:
		_hud.show_message(GameText.lines("overworld.after_defeat"))


func _apply_result(result: BattleResult, hologram: Hologram) -> void:
	for battler in result.recruited:
		var member := GameState.add_party_member(battler.data)
		member.hp = battler.hp
		member.mp = battler.mp
	GameState.drives.append_array(result.drives)
	GameState.coins += result.coins

	match result.outcome:
		BattleResult.Outcome.VICTORY:
			GameState.mark_hologram_cleared(hologram.hologram_id)
			hologram.defeat()
		BattleResult.Outcome.ESCAPED:
			_map.player.make_invulnerable(ESCAPE_INVULNERABLE_SECONDS)
			hologram.stun(ESCAPE_STUN_SECONDS)
		BattleResult.Outcome.DEFEAT:
			GameState.restore_party()
			_map.respawn_player()
			_map.player.make_invulnerable(ESCAPE_INVULNERABLE_SECONDS)
			hologram.stun(ESCAPE_STUN_SECONDS)


func _set_world_active(active: bool) -> void:
	if _in_battle and active:
		return
	_world_root.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
