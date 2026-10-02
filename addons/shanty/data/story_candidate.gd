class_name StoryCandidate
extends Resource

## One scene a trigger may play, with what must hold for it to be chosen.

## Higher is preferred when several candidates qualify.
@export var priority: int = 0
@export var conditions: Array[ShantyCondition] = []
@export var cutscene: CutsceneDefinition = null
## Played at most once per save: skipped once its scene has a played record.
@export var once: bool = true
