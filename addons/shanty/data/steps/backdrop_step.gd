class_name BackdropStep
extends CutsceneStep

## Puts a still behind the dialogue bar. A null texture draws the player's
## plain ground colour, which is a deliberate register rather than missing art.
## While a backdrop is up the game is not dimmed: the backdrop is the scene.

@export var texture: Texture2D = null
## Cinematic bars over the top and bottom of the frame.
@export var letterbox: bool = false


func begin(player: CutscenePlayer) -> void:
	player.show_backdrop(texture, letterbox)
	completed.emit()


func skip_to_end(player: CutscenePlayer) -> void:
	begin(player)
