class_name BattleAction
extends RefCounted
## A chosen command, ready to run: who does it and to whom.
## The menu and the AI build these; the controller runs them with execute().
## To add a new command (Guard Ally, Swap...), extend this class.

var user: Battler
var targets: Array[Battler] = []


func _init(acting: Battler, aimed_at: Array[Battler] = []) -> void:
	user = acting
	targets = aimed_at


## Sub actions return false and keep the turn going (GDD 06).
func costs_turn() -> bool:
	return true


func execute(_ctx: BattleContext) -> void:
	pass
