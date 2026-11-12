class_name EffectData
extends Resource
## One step of an action. Subclasses override apply() and talk to the battle
## through BattleContext, which handles the math, the text and the visuals.
##
## To add a new kind of effect: extend this class, override apply(), and add it
## to a skill's effects list in the Inspector.


func apply(_ctx: BattleContext, _user: Battler, _target: Battler) -> void:
	pass
