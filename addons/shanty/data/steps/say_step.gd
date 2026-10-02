class_name SayStep
extends CutsceneStep

## Plays a conversation in the dialogue bar. Skipping walks the conversation's
## remaining lines at once but stops on a line that offers choices: a skip
## never answers for the player, so the reply is still asked for.

@export var conversation: ConversationDefinition = null


## A conversation that can loop is refused before the scene starts: skipping
## walks it in one synchronous loop, which a cycle would never leave.
func is_well_formed() -> bool:
	return not ShantyRunner.has_cycle(conversation)


func begin(player: CutscenePlayer) -> void:
	player.say(conversation, completed.emit)


func skip_to_end(player: CutscenePlayer) -> void:
	player.skip_say(conversation, completed.emit)
