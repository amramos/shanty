extends ShantyEffect

## SetFlagEffect: asks the host to set `flag` to `value`. Pure data, as every
## effect is -- Shanty hands it back in `CutscenePlayer.finished`, and the
## example host decides what it means (`example_host.gd`, `_apply()`).

@export var flag: StringName = &""
@export var value: bool = true
