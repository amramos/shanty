@tool
class_name ShantyPreviewModel
extends RefCounted

## What the line preview draws for one line, worked out with no node: the
## speaker's name, plate variation and face, the line as the bar's BBCode, and
## -- in the reply turn -- the replies as their buttons read. The preview pane
## only binds this to the real `DialogueView` scene.
##
## **It says what `DialogueView` would, from the tab's CSV.** The text is the
## cell in the shown locale run through `ShantyText` exactly as
## `ShantyText.render()` runs a translation -- `{name:}` named by a
## `ShantyPreviewSpeakers` over the speakers folder, `[hl]` in the config's
## `highlight_colour` -- and the reply turn is chosen by
## `ShantyReplyTurn.reply_speaker()`, the view's own rule. Words appear as they
## are typed, before Save.
##
## **Its speakers are Play's.** Given the provider and settings the config's
## `ShantyPreviewHost` makes, each speaker's face, plate variation and
## knownness are that provider's -- a portrait it generates shows here as in
## Play -- and the reply speaker and `speaker_names` are those settings'; only
## the folder's speakers' names come from the CSV.

var speaker_name: String = ""
## The speaker's own name plate variation; empty uses `DialogueView`'s.
var colour_variation: StringName = &""
## Null draws the flat plate with the name on it.
var face: Texture2D = null
## The line as BBCode, or the reply placeholder in the reply turn.
var text: String = ""
## Each reply as its button reads: names resolved, highlight tags removed.
var replies: PackedStringArray = []
## True when the reply speaker has taken the bar.
var replying: bool = false
## False when the settings show no names: the name plate is hidden and the
## flat plate stays blank, as in the view.
var speaker_names: bool = true
## The locale shown, and whether its cell for the line is empty.
var locale: String = ""
var empty_cell: bool = false


## What to draw for `line` in `shown_locale`. `reply_turn` draws the turn that
## follows an asking line: the reply speaker (when the line names one the
## speakers folder knows) with the placeholder and the replies, or the asker
## with the replies under the question. `host_speakers` and `settings` are what
## the config's preview host makes (`ShantyPreviewHost.make_speaker_provider()`
## and `make_settings()`); without them the speakers folder alone draws, under
## default settings.
static func for_line(
	model: ShantyEditorModel,
	line: DialogueLine,
	shown_locale: String,
	reply_turn: bool = false,
	host_speakers: ShantySpeakerProvider = null,
	settings: ShantyViewSettings = null
) -> ShantyPreviewModel:
	var made := ShantyPreviewModel.new()
	made.locale = shown_locale
	if line == null or model.config == null:
		return made
	if settings == null:
		settings = ShantyViewSettings.new()
	made.speaker_names = settings.speaker_names
	var speakers: ShantyPreviewSpeakers = ShantyPreviewSpeakers.from_model(
		model, shown_locale, host_speakers
	)
	made._show_speaker(speakers.resolve(line.speaker_id), line.face)
	var written: String = model.document.text(line.text_key, shown_locale).c_unescape()
	made.empty_cell = written.is_empty()
	made.text = render(written, speakers, model.config.highlight_colour)
	if not reply_turn or line.choices.is_empty():
		return made
	for choice: DialogueChoice in line.choices:
		var key: String = choice.text_key if choice != null else ""
		made.replies.append(
			ShantyText.strip_tags(ShantyText.resolve_names(speakers.cell(key), speakers))
		)
	var answering: ShantySpeaker = ShantyReplyTurn.reply_speaker(line, settings, speakers)
	if answering != null:
		made.replying = true
		made._show_speaker(answering, &"")
		made.text = render(
			speakers.cell(DialogueView.REPLY_PLACEHOLDER_KEY),
			speakers,
			model.config.highlight_colour
		)
	return made


## The line to show when `selected` is picked: a conversation's first line, a
## scene's first said line; null for anything else.
static func line_for(selected: Resource) -> DialogueLine:
	var conversation: ConversationDefinition = selected as ConversationDefinition
	if selected is CutsceneDefinition:
		for step: CutsceneStep in (selected as CutsceneDefinition).steps:
			conversation = ShantySceneEdits.conversation_of(step)
			if conversation != null:
				break
	if conversation == null:
		return null
	for line: DialogueLine in conversation.lines:
		if line != null:
			return line
	return null


## `written` as the bar's BBCode: what `ShantyText.render()` makes of a
## translation, with `[hl]` in `colour`. The shared highlight colour is put
## back afterwards, so the preview never recolours anything else.
static func render(written: String, provider: ShantySpeakerProvider, colour: Color) -> String:
	var previous: Color = ShantyText.highlight_colour()
	ShantyText.set_highlight_colour(colour)
	var rendered: String = ShantyText.highlight(ShantyText.resolve_names(written, provider))
	ShantyText.set_highlight_colour(previous)
	return rendered


## The theme the preview draws under: the engine's default, then the project's
## own theme, then the config's `theme_path` on top -- the order a game looks
## items up in. Merged into one, so nothing falls through to the editor's own
## theme around the pane.
static func stage_theme(config: ShantyProjectConfig) -> Theme:
	var merged: Theme = ThemeDB.get_default_theme().duplicate() as Theme
	var paths: PackedStringArray = [String(ProjectSettings.get_setting("gui/theme/custom", ""))]
	if config != null:
		paths.append(config.theme_path)
	for path: String in paths:
		var host: Theme = ShantyFiles.load_resource(path) as Theme if not path.is_empty() else null
		if host != null:
			merged.merge_with(host)
	return merged


func _show_speaker(speaker: ShantySpeaker, tag: StringName) -> void:
	speaker_name = speaker.display_name
	colour_variation = speaker.colour_variation
	face = speaker.face_texture(tag)
