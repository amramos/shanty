class_name DialogueLine
extends Resource

## One line of a conversation. Text is never stored here -- only the key the
## host's translation server resolves -- so a line reads in every language the
## host provides and a rewrite never touches the resource.

## Optional jump target for a `DialogueChoice.jump_label`.
@export var label: StringName = &""
@export var speaker_id: StringName = &""
## The `SpeakerFace.tag` to show; the speaker's first face when absent.
@export var face: StringName = &""
@export var text_key: String = ""
## Optional per-line voice; null is the normal case.
@export var voice: AudioStream = null
## Every condition must hold for the line to be shown; otherwise it is skipped
## and its effects are not returned.
@export var conditions: Array[ShantyCondition] = []
## Returned to the host when the line is shown (or skipped past while holding).
@export var effects: Array[ShantyEffect] = []
## At most three, shown below the line once it has finished typing.
@export var choices: Array[DialogueChoice] = []
## Who answers this line's replies, overriding the host's
## `ShantyViewSettings.reply_speaker_id`. Empty uses the host's.
@export var reply_speaker_id: StringName = &""
