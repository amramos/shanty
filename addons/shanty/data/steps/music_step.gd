class_name MusicStep
extends CutsceneStep

## Changes what the music is doing for the rest of the scene. **Whatever it
## changes is put back when the scene ends** -- finished, skipped or abandoned
## -- because Shanty owns no state of the host's and must not leave its mixer
## altered. Which bus and which player are the host's, injected through
## ShantyViewSettings (`music_bus`, `music_player`); Shanty knows neither.

enum Mode {
	## Lowers the host's music bus by `duck_db` over `duration`.
	DUCK,
	## Plays `stream` on the host's music player in place of what was playing.
	SWAP,
}

@export var mode: Mode = Mode.DUCK
## Decibels to lower the bus by.
@export_range(0.0, 60.0, 0.5) var duck_db: float = 12.0
## Seconds the duck takes to settle. Zero cuts.
@export_range(0.0, 10.0, 0.05) var duration: float = 0.5
## The stream a SWAP plays. Null silences the music for the scene.
@export var stream: AudioStream = null


## The step does not wait for its own ramp: the scene goes on while the music
## settles under it.
func begin(player: CutscenePlayer) -> void:
	_apply(player, duration)
	completed.emit()


func skip_to_end(player: CutscenePlayer) -> void:
	_apply(player, 0.0)
	completed.emit()


func _apply(player: CutscenePlayer, seconds: float) -> void:
	if mode == Mode.DUCK:
		player.music().duck(duck_db, seconds)
	else:
		player.music().swap(stream)
