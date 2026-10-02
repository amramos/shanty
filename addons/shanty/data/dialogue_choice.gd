class_name DialogueChoice
extends Resource

## One reply under a line. Choices are one level deep by design: a reply may
## jump to a labelled line of the same conversation, never open a nested tree.

## Translation key for the reply's text.
@export var text_key: String = ""
## The `DialogueLine.label` to continue from. Empty continues with the line
## after the one that asked.
@export var jump_label: StringName = &""
## Returned to the host when this reply is chosen; Shanty never applies them.
@export var effects: Array[ShantyEffect] = []
