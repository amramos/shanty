@tool
extends VBoxContainer

## The left pane: Speakers, Conversations, Scenes and Triggers, as the config's
## folders hold them, and the field that makes a new one of each. With a closed
## set of trigger ids, + Trigger offers the ids no trigger has yet instead of
## reading the field.

signal resource_selected(resource: Resource)
## The writer asked for a new `kind` (`speaker`, `conversation`, `scene`,
## `trigger`) with `id`.
signal create_requested(kind: StringName, id: String)

const KINDS: Array[StringName] = [&"speaker", &"conversation", &"scene", &"trigger"]

var _tree: Tree = Tree.new()
var _new_id: LineEdit = LineEdit.new()
var _trigger_ids: PopupMenu = PopupMenu.new()
var _free_trigger_ids: PackedStringArray = []
var _trigger_ids_closed: bool = false
var _built: bool = false
## Set while the tree is refilled, so restoring the selection is not a pick.
var _filling: bool = false


func build() -> void:
	if _built:
		return
	_built = true
	_tree.hide_root = true
	_tree.size_flags_vertical = SIZE_EXPAND_FILL
	_tree.item_selected.connect(_on_item_selected)
	add_child(_tree)
	_new_id.placeholder_text = "new id, e.g. lamp_talk"
	add_child(_new_id)
	var buttons := GridContainer.new()
	buttons.columns = 2
	add_child(buttons)
	for kind: StringName in KINDS:
		var button := Button.new()
		button.text = "+ " + String(kind).capitalize()
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.pressed.connect(_on_add_pressed.bind(kind, button))
		buttons.add_child(button)
	_trigger_ids.id_pressed.connect(
		func(at: int) -> void: create_requested.emit(&"trigger", _free_trigger_ids[at])
	)
	add_child(_trigger_ids)


## Lists everything the model loaded, keeping `selected` selected.
func show_model(model: ShantyEditorModel, selected: Resource) -> void:
	_filling = true
	_tree.clear()
	var root: TreeItem = _tree.create_item()
	var speakers: TreeItem = _section(root, "Speakers")
	for speaker: SpeakerDefinition in model.speakers:
		_entry(speakers, String(speaker.speaker_id), speaker, selected)
	var conversations: TreeItem = _section(root, "Conversations")
	for conversation: ConversationDefinition in model.conversations:
		_entry(conversations, String(conversation.conversation_id), conversation, selected)
	var scenes: TreeItem = _section(root, "Scenes")
	for scene: CutsceneDefinition in model.scenes:
		_entry(scenes, String(scene.scene_id), scene, selected)
	var triggers: TreeItem = _section(root, "Triggers")
	for trigger: StoryTriggerDefinition in model.triggers:
		_entry(triggers, String(trigger.trigger_id), trigger, selected)
	_filling = false
	_free_trigger_ids = ShantyTriggerEdits.free_ids(model)
	_trigger_ids_closed = ShantyTriggerEdits.is_closed(model)


func _section(root: TreeItem, title: String) -> TreeItem:
	var item: TreeItem = _tree.create_item(root)
	item.set_text(0, title)
	item.set_selectable(0, false)
	return item


func _entry(section: TreeItem, title: String, resource: Resource, selected: Resource) -> void:
	var item: TreeItem = _tree.create_item(section)
	item.set_text(0, title if not title.is_empty() else "(no id)")
	item.set_metadata(0, resource)
	item.set_tooltip_text(0, resource.resource_path)
	if resource == selected:
		item.select(0)


func _on_item_selected() -> void:
	var item: TreeItem = _tree.get_selected()
	if not _filling and item != null and item.get_metadata(0) is Resource:
		resource_selected.emit(item.get_metadata(0))


func _on_add_pressed(kind: StringName, button: Button) -> void:
	if kind == &"trigger" and _trigger_ids_closed:
		_offer_trigger_ids(button)
		return
	var id: String = _new_id.text.strip_edges()
	if not id.is_empty():
		create_requested.emit(kind, id)
		_new_id.clear()


## A closed set: the ids no trigger has yet, under the button.
func _offer_trigger_ids(button: Button) -> void:
	_trigger_ids.clear()
	for id: String in _free_trigger_ids:
		_trigger_ids.add_item(id)
	if _free_trigger_ids.is_empty():
		_trigger_ids.add_item("Every trigger id in the config has a trigger")
		_trigger_ids.set_item_disabled(0, true)
	var at: Vector2 = button.get_screen_position() + Vector2(0.0, button.size.y)
	_trigger_ids.popup(Rect2i(Vector2i(at), Vector2i.ZERO))
