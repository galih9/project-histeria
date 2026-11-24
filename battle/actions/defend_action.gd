class_name DefendAction
extends BattleAction
## Basic Defend for everyone, Raiders included (GDD 03, Q15): lasts until the
## character's next turn, reduces damage based on Defense and Resistance, and
## blocks critical hits. A Raider's unique Defend text (game_text.json
## "defend.battle_text") replaces the plain line once Kiki writes it.


func execute(ctx: BattleContext) -> void:
	user.is_defending = true
	ctx.view.refresh_battler(user)
	var line := user.data.defend_text if not user.data.defend_text.is_empty() else BattleText.line("DEFEND")
	await ctx.say(BattleText.fill(line, {"user": user.label()}))
