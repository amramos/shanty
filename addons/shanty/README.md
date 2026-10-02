# Shanty

Dialogue and short cutscenes for Godot 4, authored as typed data. Text lives in your translation
catalogue under stable keys; structure lives in `.tres` resources; a pure runner walks a
conversation and hands back what your game should do, and a `CanvasLayer` player presents it.

Shanty owns no state and no theme. It never applies an effect, never saves anything, and never
decides when a scene should play: your game does all three, through four small interfaces.

**Version 0.2.0.** Requires Godot 4.4 or later (typed dictionaries); developed and tested on 4.7.1.
MIT licensed. Enable the plugin for [the Shanty tab](#the-shanty-tab), where a writer edits speakers
and conversations against your translation CSV; scenes, triggers and a live preview join it in
0.3.0. The runtime never needs the plugin: every class registers through `class_name`, so a game
plays its scenes whether it is enabled or not.

## Install

Copy `addons/shanty/` into your project — it is the only folder you need. A release's source archive
contains exactly that folder. Then declare what the [host contract](#the-host-contract) asks for:
three translation keys, and optionally a theme.

Every release carries `MANIFEST.sha256`: the SHA-256 of every file in the addon (`.uid` and
`.import` files aside, which Godot writes), so you can check that your copy is the release,
unmodified.

## Run the example (about two minutes)

`example/` is a whole host — a lighthouse keeper, a visitor, and one question — with its own
strings in English and Brazilian Portuguese (and a deliberately unfinished French column) and no
other code.

1. Open the project. In this repository the example is the main scene: press **F5**. In your own
   project, open `addons/shanty/example/example_host.tscn` and press **F6** (Run Current Scene).
2. Press **Play the scene**. The frame goes to the ground colour (black, unless your theme says
   otherwise), letterbox bars close in, and the dialogue bar docks at the top.
3. The Keeper's line types out, with *lamp* in the highlight colour. Click, or press `ui_accept`
   (Enter or Space by default), to finish a line and again to go on. Hold for 0.8 seconds instead
   to skip the scene: a skip still stops at the question.
4. The Visitor answers by name — the line spells the Keeper's name with a token, not a word — and
   the Keeper asks. The bar hands over to the Visitor, whose two replies wait as buttons. Pick one.
5. The scene fades out and the Output panel prints the record it left, as JSON: the scene id, the
   ordinal, the reply you took, and the title it played under. The host has applied that reply's
   one effect, a story flag.
6. Press **Read it again**. The same scene replays read-only under a *Reading again* caption: your
   recorded reply is spoken as the Visitor's line, never offered, and nothing is applied again.

## Make it yours (about thirty minutes the first time)

This builds the example again in your own project, from nothing but the addon: two short scripts
that give your data meaning, five resources made in the Inspector, and one host script. It reuses
the example's strings and keys, so nothing needs translating yet; every resource you make has a
finished twin in `example/` to compare against. Most of the time goes on clicking through the
Inspector.

Throughout, the Inspector shows each property capitalized — `speaker_id` appears as *Speaker ID*.
To add to an array property (*Faces*, *Lines*, *Choices*, *Steps*…), expand it, press **Add
Element**, click the new `<empty>` slot and pick **New** and the type named. Click the new resource
to open its fields.

### 1. Register the words

Every word a reader sees is a translation key. Godot imports `example/example_strings.csv` into one
`.translation` file per locale the first time the project opens. In **Project > Project Settings >
Localization > Translations**, press **Add…** and pick these two:
`addons/shanty/example/example_strings.en.translation` and
`addons/shanty/example/example_strings.pt_BR.translation`. They also hold the three keys every host
declares (see [the host contract](#the-host-contract)).

### 2. A condition and an effect

Shanty never reads your state and never changes it. A condition asks your context a question; an
effect is data your code gives meaning to. Make a folder `res://story/`, and in it two scripts
(right-click > **Create New > Script…**):

`res://story/story_flag_condition.gd`:

```gdscript
class_name StoryFlagCondition
extends ShantyCondition

## Holds while the host's context has `flag` set.

@export var flag: StringName = &""


func evaluate(context: ShantyContext) -> bool:
	return context.has_key(flag)
```

`res://story/story_flag_effect.gd`:

```gdscript
class_name StoryFlagEffect
extends ShantyEffect

## Asks the host to set `flag` to `value`. Pure data: Shanty hands it back in
## `CutscenePlayer.finished`, and the host decides what it means.

@export var flag: StringName = &""
@export var value: bool = true
```

Save both. Their `class_name` is what puts them in the Inspector's **New** menus below.

### 3. Two speakers

Right-click `res://story/` > **Create New > Resource…**, search **SpeakerDefinition**, press
**Create**, and save it as `keeper.tres`. In the Inspector:

- `speaker_id`: `keeper`
- `name_key`: `SHANTY_EXAMPLE_SPEAKER_KEEPER`
- `faces`: one element, **New SpeakerFace**, with `tag` `neutral`. Leave `texture` empty.

Make `visitor.tres` the same way, with `speaker_id` `visitor` and `name_key`
`SHANTY_EXAMPLE_SPEAKER_VISITOR`. **A missing face texture is never an error:** the bar draws a flat
plate with the speaker's name instead, so words may arrive before art. (Twins:
`example/speaker_keeper.tres`, `example/speaker_visitor.tres`.)

### 4. The conversation

Create a **ConversationDefinition** resource and save it as `lamp_conversation.tres`. Set
`conversation_id` to `my_lamp`, then give `lines` three elements, each **New DialogueLine**:

1. `speaker_id` `keeper`, `face` `neutral`, `text_key` `SHANTY_EXAMPLE_LINE_1`. In `conditions`, add
   one **New StoryFlagCondition** with `flag` `example_lamp_dark` — the line is said only while that
   flag is set.
2. `speaker_id` `visitor`, `face` `neutral`, `text_key` `SHANTY_EXAMPLE_LINE_2`.
3. `speaker_id` `keeper`, `face` `neutral`, `text_key` `SHANTY_EXAMPLE_LINE_3`, `reply_speaker_id`
   `visitor`. In `choices`, add two elements, each **New DialogueChoice**:
   - `text_key` `SHANTY_EXAMPLE_LINE_3_A`; in its `effects`, one **New StoryFlagEffect** with `flag`
     `example_visitor_lit_lamp`.
   - `text_key` `SHANTY_EXAMPLE_LINE_3_B`; in its `effects`, one **New StoryFlagEffect** with `flag`
     `example_keeper_lit_lamp`.

(Twin: `example/example_conversation.tres`.)

### 5. The scene

Create a **CutsceneDefinition** resource, `lamp_scene.tres`:

- `scene_id`: `my_lamp`
- `title_key`: `SHANTY_EXAMPLE_TITLE`; `synopsis_key`: `SHANTY_EXAMPLE_SYNOPSIS`; `remembered` on.
- `steps`: four elements, in this order:
  1. **New BackdropStep**, `letterbox` on. No texture draws the plain ground colour.
  2. **New FadeStep**, `to_black` off — a fade in.
  3. **New SayStep**: drag `lamp_conversation.tres` from the FileSystem dock onto `conversation`.
  4. **New FadeStep**, left as it is — a fade out.

(Twin: `example/example_scene.tres`.)

### 6. The trigger

Create a **StoryTriggerDefinition** resource, `lamp_trigger.tres`. Set `trigger_id` to `lamp`, and
give `candidates` one **New StoryCandidate** with `lamp_scene.tres` dragged onto `cutscene`. Leave
`priority` at 0 and `once` on.

### 7. The host

**Scene > New Scene**, then pick **User Interface** in the Scene dock for a `Control` root.
Right-click it > **Attach Script…**, set the path to `res://story/story_host.gd`, and replace the
template with this text:

```gdscript
extends Control

## Plays `trigger`'s scene when this node is ready, applies what the scene hands
## back, and keeps the record. Everything here is the host's; Shanty decides
## nothing about when to play, what an effect means, or what to save.

const PLAYER_SCENE: PackedScene = preload("res://addons/shanty/ui/cutscene_player.tscn")
const HIGHLIGHT_COLOUR: Color = Color8(237, 161, 43)

## The moment this host plays: res://story/lamp_trigger.tres.
@export var trigger: StoryTriggerDefinition = null
## Every speaker a line names: res://story/keeper.tres and res://story/visitor.tres.
@export var speaker_definitions: Array[SpeakerDefinition] = []

var _context: StoryContext = StoryContext.new()
var _speakers: StorySpeakers = StorySpeakers.new()
var _settings: ShantyViewSettings = ShantyViewSettings.new()
## What has played, for `once` candidates. A real game saves `to_dictionary()`.
var _played: Array[PlayedSceneRecord] = []


## The host's world, as Shanty asks about it: a dictionary of flags.
class StoryContext:
	extends ShantyContext

	var flags: Dictionary[StringName, bool] = {}

	func has_key(id: StringName) -> bool:
		return flags.get(id, false)

	func playthrough_ordinal() -> int:
		return 1


## Turns a line's `speaker_id` into the name and faces the bar draws.
class StorySpeakers:
	extends ShantySpeakerProvider

	var definitions: Dictionary[StringName, SpeakerDefinition] = {}

	func resolve(speaker_id: StringName) -> ShantySpeaker:
		if definitions.has(speaker_id):
			return ShantySpeaker.from_definition(definitions[speaker_id])
		return super.resolve(speaker_id)


func _ready() -> void:
	for definition: SpeakerDefinition in speaker_definitions:
		_speakers.definitions[definition.speaker_id] = definition
	ShantyText.set_highlight_colour(HIGHLIGHT_COLOUR)
	# The first line is gated on this flag (StoryFlagCondition).
	_context.flags[&"example_lamp_dark"] = true
	play_moment(trigger)


## Asks the selector what `moment` plays, and plays it on a fresh player.
func play_moment(moment: StoryTriggerDefinition) -> void:
	var candidate: StoryCandidate = ShantySelector.select(moment, _context, _played)
	if candidate == null:
		return  # Nothing to say here.
	var player: CutscenePlayer = PLAYER_SCENE.instantiate()
	add_child(player)
	player.finished.connect(_on_finished.bind(player), CONNECT_ONE_SHOT)
	player.play(candidate.cutscene, _context, _speakers, _settings)


func _on_finished(
	record: PlayedSceneRecord, effects: Array[ShantyEffect], player: CutscenePlayer
) -> void:
	for effect: ShantyEffect in effects:
		var flag_effect: StoryFlagEffect = effect as StoryFlagEffect
		if flag_effect != null:
			_context.flags[flag_effect.flag] = flag_effect.value
	# A refused scene finishes with an empty record: nothing played.
	if not record.scene_id.is_empty():
		_played.append(record)
	print("Played '", record.scene_id, "'. Flags: ", _context.flags)
	player.queue_free()
```

Select the root node. In the Inspector, drag `lamp_trigger.tres` onto `trigger`, and give
`speaker_definitions` two elements with `keeper.tres` and `visitor.tres` dragged onto them. Save the
scene as `res://story/story_host.tscn`.

### 8. Play it

Press **F6**. The scene plays as the example's did, without the buttons, and the Output panel ends
with `Played 'my_lamp'.` and the flags your reply set. Because the candidate is `once`, a second
`play_moment(trigger)` would now play nothing.

From here:

- **Your own words:** copy `example_strings.csv` into your project, change the keys and the text,
  register its translations as in step 1, and put the new keys on your resources.
- **A replay:** keep the record, then call `play_replay(scene, record, context, provider, settings)`
  on a fresh player and wait for `replay_finished` instead of `finished`. `example/example_host.gd`
  does both.
- **A save:** store `record.to_dictionary()`, and read it back with
  `PlayedSceneRecord.from_dictionary()`.

## Authoring reference

**The CSV's own columns.** Two `_` columns mean something to the Shanty tab; any other is kept
exactly as it is:

- **`_notes`** — free text for whoever writes or translates the line.
- **`_flags`** — tokens separated by `|`, such as `NEUTRAL` or `NEUTRAL|SHORT`. Shanty knows no flag
  by name: your `ShantyProjectConfig` lists the flags your writers may set and, per locale, the
  whole words a flagged line may not contain. A locale with no list has no rule. The example
  defines one flag, `NEUTRAL`, with English pronouns, and sets it on the two rows that name a
  speaker by token.

**Markup.** Two pieces are the whole authoring contract:

- **`[hl]…[/hl]`** draws its words in your highlight colour (`ShantyText.set_highlight_colour()`).
  Every other `[` a translator types is drawn as typed — a translation can never inject BBCode.
- **`{name:<speaker_id>}`** is replaced by whatever your speaker provider calls that speaker *now*.
  Rename a character, or hide their name until the reader learns it, and every line, reply, title
  and synopsis that names them follows — without touching a translation.

**A speaker's faces.** A line names a face tag; an unknown tag falls back to the first face.

**A line** (`DialogueLine`) has a `speaker_id`, a `face`, a `text_key`, and optionally:

- **`label`** — a name a reply's `jump_label` can jump to.
- **`conditions`** — every one must hold or the line is skipped, and so are its effects.
- **`effects`** — handed back to you when the line is shown (or skipped past while holding).
- **`choices`** — up to three `DialogueChoice` replies, each with a `text_key`, `effects` returned if
  chosen, and an optional `jump_label` naming another line's `label`. Replies are one level deep,
  and no path through them may come back to a line already passed: a conversation that can loop is
  refused.
- **`reply_speaker_id`** — who answers this line's replies. Once the question has been read, the bar
  hands over to that speaker: their face and name, a short placeholder where the line was, and the
  replies as buttons. Empty uses the host's default (`ShantyViewSettings.reply_speaker_id`); empty
  there too keeps the asker on the bar with the buttons beneath.
- **`voice`** — an optional recorded line.

**A scene** (`CutsceneDefinition`) is a `scene_id` and a list of steps: `BackdropStep` (a still,
optional letterbox), `FadeStep` (in or out), `SayStep` (a conversation), `PanStep`, `WaitStep` and
`MusicStep`. Then:

- **`skippable`** (default on) — holding the advance press skips to the end. A skip returns every
  effect playing would have, and still stops to ask any question it reaches.
- **`title_key`** — the scene's name in a replay list.
- **`remembered`** — whether your replay list keeps this scene once played (off by default, so a
  small or repeating beat never crowds it).
- **`synopsis_key`** — an optional one-sentence summary for that list; it may use `{name:<id>}`.

**A trigger** (`StoryTriggerDefinition`) names one moment your game recognises (`chapter_start`,
`door_opened`…) and lists `StoryCandidate`s, each a scene with a `priority`, `conditions`, and
**`once`** (default on): a `once` candidate is passed over when your played records already hold its
scene. Shanty never decides when a moment happens — your code does, then asks the selector.

**Playing.** `finished` fires once, at the end — never at the start — so a scene abandoned halfway
plays again.

## The Shanty tab

Enable the plugin (**Project > Project Settings > Plugins**) and a **Shanty** tab appears beside 2D,
3D and Script. It edits the same CSV rows and `.tres` files you would write by hand, so a writer and
anyone editing those files as text can work on one project.

**Point it at your project.** The tab reads one `ShantyProjectConfig` resource, named by the project
setting `shanty/config_path` (**Project Settings > General > Shanty**, shown once the plugin is
enabled). Make one with **Create New > Resource… > ShantyProjectConfig** and set:

- `csv_path` — your translation CSV.
- `speakers_folder`, `conversations_folder`, `scenes_folder`, `triggers_folder` — where those
  resources live; one folder may serve several, and each `.tres` is listed under its own kind.
- `source_locale` — the locale a session opens on.
- `flags` — one `ShantyFlagRule` per flag your writers may set: the flag's name and, per locale, the
  whole words a flagged line may not contain in that locale.
- `key_scheme` — how new keys are named (below); empty uses the defaults.
- `length_cap` — characters a line may run to before the lint warns; 0 is no cap.
- `required_locales`, `trigger_ids`, `theme_path`, `preview_host_path` — yours to read in your own
  tests, or used by the preview in 0.3.0; Shanty enforces none of them.

This repository's own setting points at `example/shanty_config.tres`, so opening it shows the
lighthouse conversation in the tab.

**The panes.** The left pane lists your speakers and conversations (scenes and triggers are listed;
editing them arrives in 0.3.0); type an id and press **+ Speaker** or **+ Conversation** to make one.
The centre edits what you picked:

- **A speaker**: its id, its name key (named for you, editable), the name in the source and target
  locales, notes, and its faces — an emotion tag each, with a texture chosen through the editor's
  own resource picker. A face may have no texture yet.
- **A conversation**: a table with one row per line — number, speaker, face (the speaker's tags),
  the source text with its key under it, the target text, the flag toggles and notes. Under each
  line: its label (a jump target), **+ Condition** and **+ Effect** (every subclass of
  `ShantyCondition` or `ShantyEffect` your project declares, or any script file that extends one;
  the new entry opens in the Inspector, where you edit its exports), **+ Choice** (up to three
  replies, each with its own key, a jump and effects), and who answers the replies.

The right pane is where the line preview arrives in 0.3.0.

**Two locales at a time.** The toolbar's **Source** and **Target** dropdowns list every locale column
your CSV has — the header is the only list of locales there is — and the table shows those two side
by side. An empty target cell is drawn as an empty dashed box. **+ Locale** adds a column for a new
language; nothing else needs to change.

**Coverage is a report.** The strip reads like `en 14/14 · pt_BR 14/14 · fr 10/14`, an incomplete
locale in the editor's warning colour. An empty cell never blocks Save: whether a missing
translation fails anything is your rule, in your own tests.

**Keys.** A new line is keyed `DLG_<CONVERSATION>_<nn>` by default, its replies `<line key>A`, `B`
and `C`, and a speaker's name `SPEAKER_<ID>`; a conversation's prefix is editable, and a
`ShantyKeyScheme` changes any pattern. **A key is never renumbered**: a line inserted
mid-conversation takes the next free number. New rows go into the CSV as one block after the
conversation's last row, so two people adding to different conversations touch different parts of
the file, and every row you did not edit is written back byte for byte.

**Lint.** Lint runs as you type, on demand, and before every Save. Errors refuse Save: a key missing
from the CSV or on two rows, a row of the wrong width (Godot's importer drops it), a flagged line
containing one of its flag's forbidden words, `{name:<id>}` tokens that differ between locales, a
reply jumping to a label no line carries, a conversation that can loop, an unknown speaker or face,
two replies that could not be told apart in a played record. Warnings never do: an over-length line,
a flag your config does not name, a token naming a speaker the speakers folder lacks. A host's own
tests can run the same checks: `ShantyLint.check()` takes the CSV and the resources and touches
neither the editor nor the disk.

**Save, and stale files.** Save writes the CSV (then reimports it) and every speaker and
conversation you changed, through `ResourceSaver`. Each file's content is fingerprinted when the
tab reads it; if any file Save would write has changed on disk since — someone else edited it —
Save refuses and writes nothing, and **Reload** reads the files again, dropping your unsaved edits.
It never overwrites rows it has not seen.

## The host contract

Everything a host provides. The names are published as constants in `ShantyHostContract`
(`core/shanty_host_contract.gd`), and a test in this repository holds that list equal to what the
scenes and scripts really use, so a release that adds, renames or drops one says so there and in
this changelog.

- **A context** — a `ShantyContext` subclass answering `has_key(id)` and `playthrough_ordinal()`
  (your count of the run, chapter or save; recorded on every played scene) over your own state.
- **Conditions and effects** — `ShantyCondition` subclasses that override `evaluate(context)`, and
  `ShantyEffect` subclasses that are pure data your code gives meaning to.
- **A speaker provider** — a `ShantySpeakerProvider` subclass whose `resolve(speaker_id)` returns a
  `ShantySpeaker` (`ShantySpeaker.from_definition()` builds one from a definition). It is also how
  `{name:<id>}` is spelled, so it is where a renamed or hidden character is decided.
- **Settings** — a `ShantyViewSettings` per playing: `text_speed_chars_per_second` (0 is instant),
  `auto_advance` (never past a question), `speaker_names`, `reply_speaker_id`, `reduced_motion` (no
  typing, no pan, no fade), `text_blips` with `text_blip` on `blip_bus` (a null sample is silence),
  `voice_bus`, and `music_bus`/`music_player` for `MusicStep` (null makes a swap do nothing). Set the
  highlight colour once with `ShantyText.set_highlight_colour()`.
- **Three translation keys**, in every locale you offer: `SHANTY_HOLD_TO_SKIP` (the skip control's
  caption), `SHANTY_REPLY_PLACEHOLDER` (what stands in the line while replies wait) and
  `SHANTY_READING_AGAIN` (the caption a replay wears in the frame's top-right corner).
- **A theme, optionally.** Declare none and everything draws with the engine's defaults on a black
  ground.

### Theme

Put Shanty's items in your **project theme** (Project Settings > GUI > Theme > Custom). The cutscene
player is a `CanvasLayer`, and Godot does not carry a parent Control's theme through a
`CanvasLayer`, so a theme set on your own scene's root does not reach it.

| Type variation | Styles a | What it is |
|---|---|---|
| `ShantyBar` | `PanelContainer` | The dialogue bar |
| `ShantyPortrait` | `PanelContainer` | The portrait frame, which becomes a flat plate when a face is missing |
| `ShantyName` | `Label` | The speaker's name plate; a `SpeakerDefinition.colour_variation` replaces it per speaker |
| `ShantyLine` | `RichTextLabel` | The line itself |
| `ShantyChoice` | `Button` | A reply — give it a visible `normal` box and a lit `focus`/`hover` one; its `font_focus_color` also colours the drawn ▸ mark |
| `ShantyHint` | `Label` | The name on a flat plate, the skip caption and the replay caption |
| `ShantySkipBar` | `ProgressBar` | The hold-to-skip bar |
| `ShantyFrame` | `ColorRect` | Its `ground_color` is the frame's ground (below) |

**Theme items read by name.** Beyond what each control draws for itself, Shanty's code reads four
items, listed in `ShantyHostContract.THEME_ITEMS` in a theme `.tres`'s own spelling:
`ShantyChoice/styles/normal` (its left margin places the reply mark),
`ShantyChoice/colors/font_focus_color` (the mark itself), `ShantyName/colors/font_color` (the
continue marker) and `ShantyFrame/colors/ground_color` (below). With a variation declared on its
base class, an item your theme leaves out is the base class's; the ground falls back to black.

**The ground colour.** The ground behind a still, the letterbox bars, the fade and the dim over your
screen all draw in one colour: `ground_color` on the `ShantyFrame` type. The player reads it when it
is ready and again whenever its theme changes; the ground, bars and fade use it opaque, and the dim
lays 0.6 of it over your frame. Without one it is black. In a theme `.tres`:

```ini
ShantyFrame/base_type = &"ColorRect"
ShantyFrame/colors/ground_color = Color(0.05, 0.1, 0.2, 1)
```

## Localization

Shanty reads every word through Godot's `TranslationServer`, so localization is Godot's own CSV
translations: a `keys` column, then one column per locale — as many as you like — and any column
whose header starts with `_` for the writers, which the importer skips. No locale is special to
Shanty, and it never names one; the example carries English and Brazilian Portuguese, and a
deliberately unfinished French column so the Shanty tab has a gap to report. Which locales your game
requires is your rule, not Shanty's.

## Rules the code keeps

- A line's effects are collected when it becomes current, a reply's when it is chosen; skipping walks
  the same path, so a skipped scene returns the same effects as a played one.
- A skip never answers a choice: it stops on the line and asks.
- The question is always read in full before the replies appear; the chosen reply is not shown again
  as a line.
- `finished` is emitted at the end of a scene, never at its start.
- The selector picks the highest `priority` among candidates whose conditions all hold and that have
  not played when `once`; the first authored wins a tie; nothing qualifying is null.
- A scene holding a step this version does not build (`AnimateStep`, `VideoStep`) is refused before
  it starts: an error, then `finished` at once with an empty record and no effects.
- A conversation that can loop — a reply jumping back to an earlier line, or a gated line that,
  once it fails, falls through to one that does — is refused: `ShantyRunner.start()` returns
  `false` with an error naming it, and a scene holding one is refused like an unbuilt step (in a
  replay, `replay_finished` at once).
- A pan moves in whole art pixels; a still narrower than the frame is centred on the ground colour.
- Whatever a `MusicStep` changed is put back when the scene ends — finished, skipped or freed.
- A replay is read-only and ends on `replay_finished`, never `finished`; `stop_replay()` closes one
  early (a first playing has no such exit). A line the record holds no answer for ends the replay's
  dialogue there, with a warning, while the scene's other steps still play: no reply is invented.

## Layout

| Path | What lives there |
|---|---|
| `data/` | The authored shapes: `SpeakerDefinition`/`SpeakerFace`, `ConversationDefinition`, `DialogueLine`, `DialogueChoice`, `CutsceneDefinition`, `CutsceneStep` and `steps/` (`BackdropStep`, `PanStep`, `FadeStep`, `SayStep`, `WaitStep`, `MusicStep`; `AnimateStep` and `VideoStep` declared and unbuilt), `StoryTriggerDefinition`/`StoryCandidate`, and the `PlayedSceneRecord` a host persists (scene, ordinal, an optional `place_id` in the host's own naming, replies taken, and the title, synopsis key and `remembered` flag as they were at that playing) |
| `core/` | Pure code, the four host interfaces and the contract: `ShantyRunner`, `ShantySelector`, `ShantyText`, `ShantyViewSettings`, `ShantySpeaker`; `ShantyContext`, `ShantyCondition`, `ShantyEffect`, `ShantySpeakerProvider`; `ShantyHostContract` |
| `ui/` | `CutscenePlayer` (layer, shield, backdrop, letterbox, fade, hold-to-skip, replay) and `DialogueView` (the top-docked bar), with the pieces they are built from: `ShantyBackdrop` (integer-scale still and pan), `ShantyPressInput` (tap versus hold, and the waits a tap may cut short), `ShantySay` (a scene's conversations), `ShantyMusic` (duck/swap and their undo), `ShantyTypewriter` (a line typing out), `ShantyReplyTurn` (the reply speaker's turn and its buttons), `ShantyLineAudio` (a line's voice and its blips), `ShantyChoiceButton`, `ShantyContinueMarker`, `SkipHold` |
| `lint/` | Pure checks the tab and a host's tests share, with no editor and no file access: `ShantyCsvDocument` (with `ShantyCsvCodec` and `ShantyCsvRow`) reads and writes the translation CSV, `ShantyLocaleCoverage` reports one locale, `ShantyKeyScheme` names keys, `ShantyLint` (with `ShantyLintText`) returns `ShantyLintIssue`s, and `ShantyProjectConfig` with its `ShantyFlagRule`s is a host's configuration |
| `editor/` | The Shanty tab. `model/` holds everything it knows and does, testable without the editor: `ShantyEditorModel`, `ShantySpeakerEdits`, `ShantyConversationEdits`, `ShantyClassCatalog` (the pickers' classes), `ShantySaveResult`, and `ShantyFiles`, the one script that opens a file your config names. The scenes and scripts beside it are thin panes over that model |
| `example/` | A whole host with no other code: context, condition, effect, speaker provider, host scene, a three-line conversation with one choice, its scene, two speakers, its own strings, and `shanty_config.tres`, its configuration for the Shanty tab. Its scripts declare no `class_name`, so installing Shanty spends no global names on it. It reads `example_strings.csv` at runtime, which an export does not include, so it runs from the editor; a real host adds its catalogue through Project Settings and needs no loader |
| `plugin.cfg`, `plugin.gd` | The editor plugin: the Shanty tab and the `shanty/config_path` setting |
| `CHANGELOG.md`, `LICENSE`, `MANIFEST.sha256` | What each version changed; MIT; the release's file hashes |

## Developing Shanty

The repository is a Godot project that opens straight into the example. Its tests use
[GUT](https://github.com/bitwes/Gut) 9.7.1, bundled under `addons/gut/` for local runs only:

```sh
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gexit -gconfig=.gutconfig.json
python tools/manifest.py          # rewrite MANIFEST.sha256 after changing the addon
python tools/manifest.py --check  # what CI runs
python -m unittest discover -s tools -p "*_test.py"  # the tools' own tests
```

Scripts are fully typed and kept `gdformat`/`gdlint` clean. A release bumps `plugin.cfg`'s
`version`, opens the matching topmost section of `CHANGELOG.md` (a test holds the two equal), and is
tagged `vX.Y.Z`; CI refuses a tag that disagrees with either.
