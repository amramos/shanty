class_name ConversationDefinition
extends Resource

## An ordered list of lines between speakers. Read by ShantyRunner, which walks
## it; nothing in the resource changes while it is played.

@export var conversation_id: StringName = &""
@export var lines: Array[DialogueLine] = []
