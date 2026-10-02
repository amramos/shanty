extends RefCounted

## A small authored project in a temporary folder for the editor-model tests:
## a CSV with a quoted row nobody edits, one speaker, one two-line conversation,
## empty scenes and triggers folders, and a config naming them. No
## `class_name`, as with every support script.

const ROOT: String = "user://shanty_editor_fixture"
const CSV_PATH: String = ROOT + "/strings.csv"
const SPEAKERS: String = ROOT + "/speakers"
const CONVERSATIONS: String = ROOT + "/conversations"
const SCENES: String = ROOT + "/scenes"
const TRIGGERS: String = ROOT + "/triggers"
const STEPS: String = "res://addons/shanty/data/steps/"
const CONDITION_SCRIPT: String = "res://addons/shanty/example/example_condition.gd"
const EFFECT_SCRIPT: String = "res://addons/shanty/example/example_effect.gd"
const CSV: String = (
	"keys,en,pt_BR,_notes\n"
	+ "SPEAKER_ANA,Ana,Ana,\n"
	+ 'UNRELATED,"Keep me, as I am","Fica, como estou","a ""quoted"" note"\n'
	+ "DLG_TALK_01,Hello.,Olá.,\n"
	+ "DLG_TALK_02,Bye.,,\n"
	+ "TAIL,Last,Último,\n"
)


## Writes the fixture's files and returns a config naming them.
static func build() -> ShantyProjectConfig:
	remove()
	DirAccess.make_dir_recursive_absolute(SPEAKERS)
	DirAccess.make_dir_recursive_absolute(CONVERSATIONS)
	DirAccess.make_dir_recursive_absolute(SCENES)
	DirAccess.make_dir_recursive_absolute(TRIGGERS)
	ShantyFiles.write_text(CSV_PATH, CSV)
	var speaker := SpeakerDefinition.new()
	speaker.speaker_id = &"ana"
	speaker.name_key = "SPEAKER_ANA"
	var face := SpeakerFace.new()
	face.tag = &"neutral"
	speaker.faces = [face]
	ResourceSaver.save(speaker, SPEAKERS + "/ana.tres")
	var conversation := ConversationDefinition.new()
	conversation.conversation_id = &"talk"
	conversation.lines = [_line("DLG_TALK_01"), _line("DLG_TALK_02")]
	ResourceSaver.save(conversation, CONVERSATIONS + "/talk.tres")
	return config()


static func config() -> ShantyProjectConfig:
	var made := ShantyProjectConfig.new()
	made.csv_path = CSV_PATH
	made.speakers_folder = SPEAKERS
	made.conversations_folder = CONVERSATIONS
	made.scenes_folder = SCENES
	made.triggers_folder = TRIGGERS
	var rule := ShantyFlagRule.new()
	rule.flag = "NEUTRAL"
	rule.forbidden_words = {"en": PackedStringArray(["he", "she"])}
	made.flags = [rule]
	return made


## A model opened fresh on a newly built fixture.
static func open_model() -> ShantyEditorModel:
	var model := ShantyEditorModel.new()
	model.open(build(), true)
	return model


static func csv_on_disk() -> String:
	return ShantyFiles.read_text(CSV_PATH)


static func remove() -> void:
	_remove_tree(ROOT)


static func _line(key: String) -> DialogueLine:
	var line := DialogueLine.new()
	line.speaker_id = &"ana"
	line.face = &"neutral"
	line.text_key = key
	return line


static func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	for child: String in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(child))
	DirAccess.remove_absolute(path)
