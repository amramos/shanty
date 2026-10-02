@tool
extends VBoxContainer

## The left pane: Speakers, Conversations, Scenes and Triggers, as the config's
## folders hold them, and the field that makes a new speaker or conversation.
## Scenes and triggers are listed, not yet edited.

signal resource_selected(resource: Resource)
signal speaker_requested(id: String)
signal conversation_requested(id: String)

const Palette := preload("res://addons/shanty/editor/shanty_editor_palette.gd")
const LATER: String = "Editing arrives in 0.3.0"

var _tree: Tree = Tree.new()
var _new_id: LineEdit = LineEdit.new()
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
	var buttons := HBoxContainer.new()
	add_child(buttons)
	for entry: Array in [
		["+ Speaker", speaker_requested], ["+ Conversation", conversation_requested]
	]:
		var button := Button.new()
		button.text = entry[0]
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		var request: Signal = entry[1]
		button.pressed.connect(func() -> void: _request(request))
		buttons.add_child(button)


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
		_listed_only(scenes, String(scene.scene_id))
	_listed_only(scenes, LATER)
	var triggers: TreeItem = _section(root, "Triggers")
	for trigger: StoryTriggerDefinition in model.triggers:
		_listed_only(triggers, String(trigger.trigger_id))
	_listed_only(triggers, LATER)
	_filling = false


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


func _listed_only(section: TreeItem, title: String) -> void:
	var item: TreeItem = _tree.create_item(section)
	item.set_text(0, title)
	item.set_selectable(0, false)
	item.set_custom_color(0, Palette.muted())


func _on_item_selected() -> void:
	var item: TreeItem = _tree.get_selected()
	if not _filling and item != null and item.get_metadata(0) is Resource:
		resource_selected.emit(item.get_metadata(0))


func _request(request: Signal) -> void:
	var id: String = _new_id.text.strip_edges()
	if not id.is_empty():
		request.emit(id)
		_new_id.clear()
