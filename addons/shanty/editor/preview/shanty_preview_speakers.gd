@tool
class_name ShantyPreviewSpeakers
extends ShantySpeakerProvider

## A speaker provider built from authored `SpeakerDefinition`s -- the config's
## speakers folder -- for the Shanty tab's line preview, and for Play when the
## host names no preview host of its own.
##
## **Where a name comes from.** Given the tab's CSV, a speaker's name is that
## CSV's cell in `locale` (the source locale's when that cell is empty, the key
## when both are), so the preview shows the words being typed before they are
## saved or imported. Without one it is the `TranslationServer`'s, as
## `ShantySpeaker.from_definition()` reads it in a game.
##
## **Over the host's own provider.** Given `host` -- the provider the config's
## preview host makes, the one Play draws with -- every speaker is the host's:
## its face (a portrait the host generates, say), plate variation and whether
## it is known. Only the name of a speaker the folder defines is then read from
## the CSV, as above. The host provider is the preview's own instance, so the
## rename reaches nothing else.

## Speaker id -> its definition.
var definitions: Dictionary[StringName, SpeakerDefinition] = {}
## The CSV names are read from, or null for the TranslationServer.
var document: ShantyCsvDocument = null
var locale: String = ""
var fallback_locale: String = ""
## The preview host's provider, or null to draw from the definitions alone.
var host: ShantySpeakerProvider = null


## The model's speakers, named from its CSV in `shown_locale`, and drawn by
## `over` when it is given.
static func from_model(
	model: ShantyEditorModel, shown_locale: String, over: ShantySpeakerProvider = null
) -> ShantyPreviewSpeakers:
	var made := ShantyPreviewSpeakers.new()
	made.add_all(model.speakers)
	made.document = model.document
	made.locale = shown_locale
	made.fallback_locale = model.source_locale
	made.host = over
	return made


## Every speaker definition under `folder`, named through the TranslationServer.
static func from_folder(folder: String) -> ShantyPreviewSpeakers:
	var made := ShantyPreviewSpeakers.new()
	var found: Array[SpeakerDefinition] = []
	for path: String in ShantyFiles.list_resources(folder):
		var definition: SpeakerDefinition = ShantyFiles.load_resource(path) as SpeakerDefinition
		if definition != null:
			found.append(definition)
	made.add_all(found)
	return made


## Adds `speakers`; the first of two with one id wins, as the lint expects.
func add_all(speakers: Array[SpeakerDefinition]) -> void:
	for definition: SpeakerDefinition in speakers:
		if definition != null and not definitions.has(definition.speaker_id):
			definitions[definition.speaker_id] = definition


func resolve(speaker_id: StringName) -> ShantySpeaker:
	var definition: SpeakerDefinition = definitions.get(speaker_id, null)
	if host != null:
		var drawn: ShantySpeaker = host.resolve(speaker_id)
		if drawn.known and definition != null and document != null:
			drawn.display_name = cell(definition.name_key)
		return drawn
	if definition == null:
		return super.resolve(speaker_id)
	if document == null:
		return ShantySpeaker.from_definition(definition)
	var speaker := ShantySpeaker.new()
	speaker.display_name = cell(definition.name_key)
	speaker.colour_variation = definition.colour_variation
	for face: SpeakerFace in definition.faces:
		if face != null:
			speaker.add_face(face.tag, face.texture)
	return speaker


## `key`'s text in `locale`, else in the fallback locale, else the key itself
## -- the raw key a game shows for a key its catalogue lacks. Escapes are read
## as Godot's CSV importer reads them: a typed backslash-n is a line break.
func cell(key: String) -> String:
	for column: String in [locale, fallback_locale]:
		var found: String = document.text(key, column) if not column.is_empty() else ""
		if not found.is_empty():
			return found.c_unescape()
	return key
