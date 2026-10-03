# Shanty

Dialogue and short cutscenes for Godot 4, authored as typed data. Every word lives in your
translation CSV under a stable key; speakers, conversations, scenes and triggers live in `.tres`
resources; a pure runner walks a conversation and hands back what your game should do; and a
`CanvasLayer` player presents it. Enable the plugin and a **Shanty** tab lets a writer author all of
it, see each line in your own dialogue bar, and play a scene in a game window.

What it is not: not a scripting language — a conversation is data, and a condition or an effect is
a class of yours. Not a state owner — no autoload, and it never applies an effect, saves anything or
decides when a scene plays; your game does all three. And not an editor dependency — every runtime
class registers through `class_name`, so a game plays its scenes whether the plugin is enabled or
not.

**Version 0.3.0.** Requires Godot 4.4 or later (typed dictionaries); developed and tested on 4.7.1.
MIT licensed.

- [Install](#install)
- [Write your first scene in the Shanty tab](#write-your-first-scene-in-the-shanty-tab)
- [Hosting Shanty in your game](#hosting-shanty-in-your-game)
- [Authoring reference](#authoring-reference)
- [Lint rules](#lint-rules)
- [Rules the code keeps](#rules-the-code-keeps)
- [Layout](#layout), [Running the tests](#running-the-tests),
  [Versioning and the manifest](#versioning-and-the-manifest)

## Install

1. **Copy `addons/shanty/` into your project.** It is the only folder you need, and a release's
   source archive contains exactly that folder.
2. **Enable the plugin** in **Project > Project Settings > Plugins**. A **Shanty** tab appears
   beside 2D, 3D and Script, and Project Settings gains `shanty/config_path` (**General >
   Shanty**).
3. **Point the tab at a config.** The setting names one `ShantyProjectConfig`: where your CSV and
   your resources live, and the rules the tab checks them by. It defaults to the example's config
   inside the addon, so the tab first opens on the demo. Point it at a config of your own, or empty
   it, press **Reload** in the tab and then **Create config…**, as
   [the tutorial's first steps](#2-your-own-folder-and-config) do.

Shanty brings no look of its own. The dialogue bar, its replies and name plate, the skip control
and the ground behind a scene draw from your **project theme** through eight type variations
(`ShantyBar`, `ShantyName`, `ShantyFrame`…); declare none and everything draws with the engine's
defaults on a black ground. [The theme contract](#the-theme-contract) lists them.

## Write your first scene in the Shanty tab

This rebuilds the example's lighthouse scene — a keeper, a visitor who has come back, and one
question — in a folder of your own, the way a writer would: in the tab, with nothing typed into the
Inspector but a config, a scene's step values and one effect. It takes about half an hour the first
time. Each step names what you click and what appears. The example's finished resources are its
twins: `example/speaker_keeper.tres`, `example/example_conversation.tres`,
`example/example_scene.tres` and `example/example_trigger.tres`. Yours differ in ids and keys only,
because the example's config names its keys with its own scheme.

### 1. Open the tab

Click **Shanty** at the top of the editor. In a project that has just installed Shanty the tab opens
on the example:

- **The left pane** lists **Speakers** (`keeper`, `visitor`), **Conversations** and **Scenes**
  (`shanty_example_lamp` each) and **Triggers** (`lamp`), with a field for a new id under them and
  **+ Speaker**, **+ Conversation**, **+ Scene** and **+ Trigger**.
- **The toolbar** holds the **Source** and **Target** locale dropdowns (`en` and `pt_BR`), a *new
  locale* field with **+ Locale**, the coverage strip — `en 14/14 · pt_BR 14/14 · fr 10/14` — and
  **Reload**, **Lint**, **Save** and **Play**.
- **The centre** edits whatever you pick on the left; **the right pane** draws the line you are
  working on in the real dialogue bar; **the issues list** and **the status line** run along the
  bottom.

Pick the scene `shanty_example_lamp` and press **Play** to see, in a game window, what you are about
to build. Close it with Escape.

### 2. Your own folder and config

**The words file.** Make a folder `res://story/` (FileSystem dock: right-click `res://` >
**Create New > Folder…**). Then, with any text editor, save these four lines in it as
`dialogue_strings.csv`:

```csv
keys,en,pt_BR
SHANTY_HOLD_TO_SKIP,Hold to skip,Segure para pular
SHANTY_REPLY_PLACEHOLDER,…,…
SHANTY_READING_AGAIN,Reading again,Lendo de novo
```

The header names your locales, and the rows are the three keys every host declares
([the host contract](#the-host-contract)). The tab makes rows only for what it names — speakers,
lines, replies, titles — so these three are yours to write once by hand. Godot imports the file as
soon as the editor has focus again.

**The config.** Empty the setting (**Project Settings > General > Shanty > Config Path**), then
press **Reload** in the tab. The status line says
`No Shanty config: shanty/config_path is empty. Press Create config… to make one.`, and
**Create config…** appears at the left of the toolbar — it is offered only while no config is open.
Press it, open `res://story/`, keep the name `shanty_config.tres`, and save. The tab writes a config
whose CSV is `dialogue_strings.csv` beside it and whose four folders are `res://story`, points the
setting at it, and opens it: **Source** reads `en`, **Target** `pt_BR`, and the strip
`en 3/3 · pt_BR 3/3`. The config is also open in the Inspector. Set two things there:

- **Highlight Colour** — the colour `[hl]` words draw in for the preview and Play. Pick an amber.
- **Flags** — add one element, **New ShantyFlagRule**, and click it. Set **Flag** to `NEUTRAL` and
  give **Forbidden Words** one entry: key `en`, value the words `he`, `she`, `him`, `her`, `his`
  and `hers`. Step 7 uses it.

Save the config with the Inspector's save button, and press **Reload** so the tab reads it as
saved. [The config](#the-config) lists its other fields.

### 3. Two speakers

Type `keeper` into the field under the list (it reads *new id, e.g. lamp_talk*) and press
**+ Speaker**. `keeper` appears under **Speakers**, and the centre shows its form:

- **Id** — `keeper`.
- **Name key** — `SPEAKER_KEEPER`, named for you by the config's key scheme. You may type another
  and press Enter; a key another speaker already uses is shared, not copied.
- **Name (en)** — type `The Keeper`. **Name (pt_BR)** — type `O Faroleiro`. A target cell left
  empty is drawn as an empty dashed box: room to write, not an error.
- **Notes** — free text for whoever translates the name, kept in the CSV's `_notes` column. Leave
  it empty here.
- **Faces** — type `neutral` into the *emotion tag, e.g. neutral* field and press **+ Face**. The
  face's row has the editor's own resource picker for its texture: leave it empty. **A face with
  no texture is never an error** — the bar draws a flat plate with the speaker's name instead, so
  the words can arrive before the art.

Make `visitor` the same way: `SPEAKER_VISITOR`, `The Visitor`, `A Visita`, face `neutral`.

### 4. The conversation

Type `lamp_talk` and press **+ Conversation**. The centre shows its table: the id, a **Key prefix**
field reading `DLG_LAMP_TALK` (every new line is keyed under it; type another and press Enter
before adding lines if you want one), and the columns `#`, `Speaker`, `Face`, `Source: en`,
`Target: pt_BR`, `Flags` and `Notes`.

Press **+ Line** under the table. Line 1 appears, spoken by your first speaker, `keeper`, with the
face *(first face)*. Type into its source cell:

```text
You came back. The [hl]lamp[/hl] has been dark since you left.
```

Under the cell is the line's key: `DLG_LAMP_TALK_01 · key ok`. That caption is where the lint
speaks about a key — the success colour while all is well, otherwise the first finding in the
error or warning colour, every finding in its tooltip. Type the target cell too:
`Você voltou. A [hl]lanterna[/hl] está apagada desde que você partiu.`

Press **+ Line** again: a new line comes in the voice of the line before it. Pick `visitor` in its
**Speaker** dropdown (a face the new speaker lacks is dropped) and type
`I said I would, {name:keeper}.` and `Eu disse que voltaria, {name:keeper}.` — `{name:keeper}` is
replaced by whatever your game calls the keeper when the line is shown. Press **+ Line** a third
time, set the speaker back to `keeper`, and type `Will you light it tonight, or shall I?` Leave its
target cell empty: step 6 needs a gap.

Each line has a second row: its **label** (a name a reply can jump to), **+ Condition** and
**+ Effect**, **+ Choice**, and the line's own actions — **Insert after** (a new line straight
below, in the same voice), **↑** and **↓**, and **Remove line**. Moving a line changes the order
only: no key is renumbered and no CSV row moves ([Keys](#keys)).

### 5. A reply pair with an effect

On line 3's second row press **+ Choice** twice. Two rows appear under the line, **reply A** and
**reply B**, keyed `DLG_LAMP_TALK_03A` and `DLG_LAMP_TALK_03B`. Type `I will light it.` /
`Eu acendo.` and `You light it. I will watch.` / `Acenda você. Eu fico olhando.` Each reply's
dropdown reads *(next line)*, where the conversation goes after it. Line 3 now also has a dropdown
reading *(host's reply speaker)*: pick `visitor`. Once the question has been read, the bar will
hand over to the visitor, whose replies wait as buttons.

An effect is data your game gives meaning to, so it is a class of yours. Someone writes it once —
right-click `res://story/` > **Create New > Script…**, `story_flag_effect.gd`:

```gdscript
class_name StoryFlagEffect
extends ShantyEffect

## Asks the host to set `flag` to `value`. Pure data: Shanty hands it back in
## `CutscenePlayer.finished`, and the host decides what it means.

@export var flag: StringName = &""
@export var value: bool = true
```

On reply A press **+ Effect**. The menu lists every `ShantyEffect` subclass your project declares
with a `class_name` — `StoryFlagEffect` is there — and **Script file...** for a script without one.
Pick it: the new effect opens in the Inspector, where you set **Flag** to `visitor_lit_lamp`, and a
`StoryFlagEffect` chip appears beside the menu (click it to edit it again; its **x** removes it).
Give reply B one with `keeper_lit_lamp`. **+ Condition** on a line works the same way with your
`ShantyCondition` subclasses: every condition must hold or the line is skipped
([Hosting](#a-host-in-one-script) has one).

### 6. The target locale and coverage

The coverage strip now reads `en 10/10 · pt_BR 9/10`, the incomplete locale in the editor's warning
colour; hover it for `Empty: DLG_LAMP_TALK_03`. **Save never refuses on coverage.** An empty cell
is a report, not an error: whether a missing translation fails anything is your rule, in your own
tests ([Localization](#localization)).

Add a language: type `fr` into the *new locale* field and press **+ Locale**. The status line says
`Added the fr column. Save writes it.` and the strip gains `fr 0/10`. Pick `fr` in **Target**: the
column header reads `Target: fr` and every target cell is an empty dashed box. Pick `pt_BR` again
to go on; the French column stays unfinished, as the example's does.

### 7. Flags

Line 2 names the keeper by token, so it must never call them *he* or *she*: that is what your
`NEUTRAL` flag checks. Press the **NEUTRAL** toggle in line 2's **Flags** column; it writes the
token into the row's `_flags` column. Now add `Ask her.` to line 2's English text. Within a moment
the caption under it turns to the error colour —
`DLG_LAMP_TALK_02 · flagged NEUTRAL, but the text says 'her'` — and the issues list reads:

```text
error  flag_word  DLG_LAMP_TALK_02 en: flagged NEUTRAL, but the text says 'her'
```

Press **Save**: the status line says `Not saved: lint found 1 error.` and nothing is written. Take
the two words out again, and the caption goes back to `key ok`. A forbidden word is matched whole
and case-insensitively, in the locale whose list names it ([Lint rules](#lint-rules)).

### 8. The scene

Press **Save** first: `Saved 4 files.` — the CSV and three resources (step 10 says what Save does).
A scene names its conversation by its file, and now the file exists.

Type `lamp_scene` and press **+ Scene**. The centre shows:

- **Title** and **Synopsis** — each a source and a target cell with its key under it,
  `SCENE_TITLE_LAMP_SCENE` and `SCENE_SYNOPSIS_LAMP_SCENE`, named by the scheme's scene patterns and
  given their two rows together. Type `The Lamp` / `A Lanterna` and
  `{name:visitor} came back to the lighthouse.` / `{name:visitor} voltou ao farol.` The title names
  the scene in a replay list; the synopsis is that list's one-sentence summary. The synopsis is
  optional: its **Remove** takes it away, and **+ Synopsis** brings one back.
- **Skippable** (ticked) and **Remembered** (not): tick **Remembered**, so a replay list keeps the
  scene once it has played.
- *Steps, in order*, then **+ Step** — a menu of every step type your project declares. Pick, in
  turn:
  1. **BackdropStep**. Its row reads `Backdrop: ground colour` and the step opens in the Inspector:
     tick **Letterbox**, and the row reads `Backdrop: ground colour, letterbox`. With no texture the
     backdrop is the plain ground colour.
  2. **FadeStep**: `Fade out 0.6 s`. Untick **To Black** in the Inspector: `Fade in 0.6 s`.
  3. **SayStep**: `Say: (no conversation)`. Drag `res://story/lamp_talk.tres` from the FileSystem
     dock onto **Conversation** in the Inspector: `Say: lamp_talk`, and the row gains
     **Open conversation**, which jumps the centre to those lines.
  4. **FadeStep** again, left as it is: `Fade out 0.6 s`.

Every step row also has **Edit** (back to the Inspector), **Insert after**, **↑**, **↓** and
**Remove**, none of which touches the other steps.

### 9. The trigger

A trigger names one moment your game recognises and lists the scenes that may play there. Type
`lamp` and press **+ Trigger**. Your config lists no `trigger_ids`, so any lower-case id is allowed;
when it lists them, **+ Trigger** offers the ones that have no trigger yet instead. Every new
resource is saved as `<id>.tres` in its kind's folder, and your four folders are one, so give each
new speaker, conversation, scene and trigger an id nothing else has.

The centre shows **Moment** `lamp`, and under it what the lint finds about the trigger:
`warning  empty_trigger  lamp: no candidate: this moment always plays nothing`. Press
**+ Candidate**. Its row holds a scene dropdown reading *(no scene)* — an `unknown_scene` error
until you pick one — a priority (`0`; any whole number, the highest whose conditions hold plays),
**Once** (ticked: passed over once your records hold its scene), **+ Condition**, **↑**, **↓** and
**Remove**. Pick `lamp_scene`, and both findings clear.

### 10. Save

Press **Save**: `Saved 3 files.` Save lints first, and any error refuses it, as in step 7. Then it
checks every file it would write against the content it read; then it writes all of them or none:

- the CSV — after which the tab asks Godot to reimport it, which writes one `.translation` file per
  locale beside it;
- every speaker, conversation, scene and trigger changed since the last Save: this time
  `lamp_scene.tres` and `lamp.tres`.

**Untouched rows are written back byte for byte**, line endings included, and new rows arrive as
one block after their conversation's last row ([Your CSV's bytes](#your-csvs-bytes)). Adding a
column — a locale, or the first `_notes` or `_flags` — widens every row, once.

**A stale file refuses the whole Save.** Try it: change a cell of `dialogue_strings.csv` in a text
editor and save it there; change any cell in the tab and press **Save**. The status line says
`Not saved: res://story/dialogue_strings.csv changed on disk since it was read. Reload to see the change.`
and nothing is written. **Reload** reads every file again and drops your unsaved edits: the tab
never overwrites rows it has not seen.

### 11. The preview

The right pane has been drawing all along: the line you are working on — the first line of a
picked conversation or scene, then whichever line's cell you click into — in your real dialogue
bar, `res://addons/shanty/ui/dialogue_view.tscn`, under your project theme with the config's
`theme_path` laid over it. The words are the CSV's as you type them, before any Save.

Click into line 1's source cell. The bar shows `The Keeper` on a flat plate (no face texture yet)
and the line with *lamp* in your highlight colour; the note under it reads
`DLG_LAMP_TALK_01, en`. Turn on **Target** for the `pt_BR` text. Click into line 3: its target cell
is empty, so the bar is too, and the note says `DLG_LAMP_TALK_03, pt_BR · no pt_BR text yet`. Turn
on **Reply turn**, enabled on a line with replies: the visitor takes the bar, with the placeholder
from your `SHANTY_REPLY_PLACEHOLDER` row where the line was and the two replies as buttons.

Its limit: it is the real bar under the real theme at the pane's width, with every line whole — not
the player's layer, letterbox, backdrop or dim, not your game's resolution, and no typing. Its
speakers are Play's ([Hosting Play](#hosting-play)). Play shows everything else.

### 12. Play

Play runs a game, and a game reads your translations as Godot imported them, so register them once:
**Project > Project Settings > Localization > Translations**, press **Add…**, and pick
`res://story/dialogue_strings.en.translation` and `res://story/dialogue_strings.pt_BR.translation`.

Pick `lamp_scene` in the list — or the trigger `lamp`, to play the scene it chooses — and press
**Play**. (With unsaved edits the status line says `Save first: Play plays the files on disk.`; and
after a Save, wait for its reimport to finish.) A game window opens, as **Run Current Scene** would,
and plays your scene through the real `CutscenePlayer` in the locale the preview shows — `en`, or
`pt_BR` while its **Target** toggle is on:

1. The frame goes to the ground colour, the letterbox bars close in, the bar docks at the top, and
   the keeper's line types out, *lamp* in your highlight colour.
2. Click, or press `ui_accept` (Enter or Space by default), to finish a line and again to go on.
   Hold for 0.8 seconds instead to skip the scene: a skip still stops at the question.
3. At line 3 the bar hands over to the visitor and the replies wait as buttons. Pick one.
4. The scene fades out, and the window says `Played lamp_scene. Press Escape or close.` Escape
   closes it.

The editor's **Output** panel has the rest — every effect the scene handed back and the record it
left, as your game would have received them (the record is shortened here). Nothing is applied and
nothing is saved:

```text
Shanty Play: playing 'lamp_scene' in en.
Shanty Play: effect StoryFlagEffect {flag: visitor_lit_lamp, value: true}
Shanty Play: record {"choices":{"lamp_talk/DLG_LAMP_TALK_03":0}, …, "scene_id":"lamp_scene", …}
Shanty Play: Played lamp_scene. Press Escape or close.
```

The record names the reply taken by conversation and line key, with its index, and keeps the title
and synopsis keys and `remembered` as they were when it played. Each Play plays once: running
`res://addons/shanty/editor/preview/preview_host.tscn` again yourself says `Nothing to play`.

### 13. Where it all went

Everything you made is in `res://story/`:

| File | What it holds |
|---|---|
| `dialogue_strings.csv` | Every word, one row per key, one column per locale, then `_flags` |
| `dialogue_strings.*.translation` | Godot's import of it, one per locale — never edit these |
| `shanty_config.tres` | The config the tab reads |
| `story_flag_effect.gd` | Your effect class |
| `keeper.tres`, `visitor.tres` | The speakers: an id, a name key and faces |
| `lamp_talk.tres` | The conversation: lines as speaker ids and keys, replies and their effects |
| `lamp_scene.tres` | The scene: its keys, flags and steps, naming `lamp_talk.tres` by path |
| `lamp.tres` | The trigger: the moment `lamp` and its one candidate |

The CSV, as Save wrote it:

```csv
keys,en,pt_BR,fr,_flags
SHANTY_HOLD_TO_SKIP,Hold to skip,Segure para pular,,
SHANTY_REPLY_PLACEHOLDER,…,…,,
SHANTY_READING_AGAIN,Reading again,Lendo de novo,,
SPEAKER_KEEPER,The Keeper,O Faroleiro,,
SPEAKER_VISITOR,The Visitor,A Visita,,
DLG_LAMP_TALK_01,You came back. The [hl]lamp[/hl] has been dark since you left.,Você voltou. A [hl]lanterna[/hl] está apagada desde que você partiu.,,
DLG_LAMP_TALK_02,"I said I would, {name:keeper}.","Eu disse que voltaria, {name:keeper}.",,NEUTRAL
DLG_LAMP_TALK_03,"Will you light it tonight, or shall I?",,,
DLG_LAMP_TALK_03A,I will light it.,Eu acendo.,,
DLG_LAMP_TALK_03B,You light it. I will watch.,Acenda você. Eu fico olhando.,,
SCENE_TITLE_LAMP_SCENE,The Lamp,A Lanterna,,
SCENE_SYNOPSIS_LAMP_SCENE,{name:visitor} came back to the lighthouse.,{name:visitor} voltou ao farol.,,
```

No `.tres` holds a word of text: a translator works in the CSV alone, and a rename in the CSV
never touches a resource. Compare yours with the twins in `example/`; the next section plays them
from your own game.

## Hosting Shanty in your game

The tab authors; your game plays. Everything a host provides is published as constants in
`ShantyHostContract` (`core/shanty_host_contract.gd`), and a test in this repository holds that
list equal to what the scenes and scripts really use, so a release that adds, renames or drops one
says so there and in the changelog.

### The host contract

- **A context** — a `ShantyContext` subclass answering `has_key(id)` and `playthrough_ordinal()`
  (your count of the run, chapter or save; recorded on every played scene) over your own state.
- **Conditions and effects** — `ShantyCondition` subclasses that override `evaluate(context)`, and
  `ShantyEffect` subclasses that are pure data your code gives meaning to.
- **A speaker provider** — a `ShantySpeakerProvider` subclass whose `resolve(speaker_id)` returns a
  `ShantySpeaker` (`ShantySpeaker.from_definition()` builds one from a definition). It is also how
  `{name:<speaker_id>}` is spelled, so it is where a renamed or hidden character is decided.
- **Settings** — a `ShantyViewSettings` per playing: `text_speed_chars_per_second` (0 is instant),
  `auto_advance` (never past a question), `speaker_names`, `reply_speaker_id`, `reduced_motion` (no
  typing, no pan, no fade), `text_blips` with `text_blip` on `blip_bus` (a null sample is silence),
  `voice_bus`, and `music_bus`/`music_player` for `MusicStep` (null makes a swap do nothing). Set
  the highlight colour once with `ShantyText.set_highlight_colour()`.
- **Three translation keys**, in every locale you offer: `SHANTY_HOLD_TO_SKIP` (the skip control's
  caption), `SHANTY_REPLY_PLACEHOLDER` (what stands in the line while replies wait) and
  `SHANTY_READING_AGAIN` (the caption a replay wears in the frame's top-right corner).
- **A theme, optionally** ([below](#the-theme-contract)).

### A host in one script

A condition, beside the tutorial's effect in `res://story/`:

```gdscript
class_name StoryFlagCondition
extends ShantyCondition

## Holds while the host's context has `flag` set.

@export var flag: StringName = &""


func evaluate(context: ShantyContext) -> bool:
	return context.has_key(flag)
```

And the host: **Scene > New Scene**, pick **User Interface** for a `Control` root, attach a script
`res://story/story_host.gd` with this text, and in the Inspector drag `lamp.tres` onto `trigger` and
`keeper.tres` and `visitor.tres` into `speaker_definitions`:

```gdscript
extends Control

## Plays `trigger`'s scene when this node is ready, applies what the scene hands
## back, and keeps the record. Everything here is the host's; Shanty decides
## nothing about when to play, what an effect means, or what to save.

const PLAYER_SCENE: PackedScene = preload("res://addons/shanty/ui/cutscene_player.tscn")
const HIGHLIGHT_COLOUR: Color = Color8(237, 161, 43)

## The moment this host plays: res://story/lamp.tres.
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

Save the scene as `res://story/story_host.tscn` and press **F6**. The scene plays as it did from
the tab, and the Output panel ends with `Played 'lamp_scene'.` and the flag your reply set. Because
the candidate is `once`, a second `play_moment(trigger)` now plays nothing.

`example/example_host.gd` is the same host grown a little — its own strings loaded at runtime, a
**Play the scene** button and a **Read it again** replay. Open `example/example_host.tscn` and press
**F6** (in this repository it is the main scene: **F5**).

### Triggers at your own boundaries

Shanty never decides when a moment happens. Your code recognises it — a chapter starts, a door
opens, a level ends — and asks `ShantySelector.select(trigger, context, records)` which candidate
plays, as `play_moment()` does above ([the rule it picks by](#rules-the-code-keeps)). Call it
only where your game is ready to hand the screen to a scene.

### Records, saves and replays

`finished(record, effects)` fires once, at the end of a scene, so a scene abandoned halfway plays
again. The `PlayedSceneRecord` holds the scene id, your ordinal, the
replies taken, an optional `place_id` in your own naming, and the scene's title key, synopsis key
and `remembered` flag as they were at that playing. Store `record.to_dictionary()` in your save and
read it back with `PlayedSceneRecord.from_dictionary()`; the records you hand the selector are what
`once` reads.

A replay list is yours to draw from those records: the ones whose `remembered` is set, named by
their title and synopsis keys. To replay one, call
`play_replay(scene, record, context, provider, settings)` on a fresh player and wait for
`replay_finished` instead of `finished`: the scene plays read-only under the `SHANTY_READING_AGAIN`
caption, the recorded reply spoken rather than offered, and nothing is handed back.
`stop_replay()` closes a replay early. `example/example_host.gd` does both.

### Hosting Play

The tab's Play asks one object of yours for what a game would hand the player: a
`ShantyPreviewHost`. With none named, Shanty's own plays your scenes with no code of yours at all —
a context holding nothing (so every condition asking `has_key()` fails, and a gated line is
skipped), your speakers folder named through your translations, the default reading settings, and
nothing played before. When your conditions read real state, or your speakers are generated, extend
it in a script of your own, override what your game provides, and name the script in your config's
`preview_host_path`:

- `make_context() -> ShantyContext` — what your conditions ask.
- `make_speaker_provider() -> ShantySpeakerProvider` — who the speakers are.
- `make_settings() -> ShantyViewSettings` — text speed, names, reduced motion, buses.
- `make_records() -> Array[PlayedSceneRecord]` — what has played, for a trigger's `once`
  candidates.
- `make_translations() -> Array[Translation]` — catalogues to add while the preview plays, for
  strings your project does not register (the example's are not).

`config` holds your `ShantyProjectConfig` by the time any of them is called. The script needs no
`@tool`: Play runs it in a game window, and the line preview, which asks it for
`make_speaker_provider()` and `make_settings()` inside the editor, makes it with `GDScript.new()`,
which runs any script there. One thing differs in the editor: a resource your code loads from disk —
a `SpeakerDefinition`, say — is a placeholder there, holding its stored values but running no
method. Read a definition's values, never call its methods, in the provider and settings, and the
preview draws exactly what Play does. For the host above, with a line gated on a
`StoryFlagCondition` whose `flag` is `lamp_dark` (save it as `res://story/story_preview_host.gd`
and name it in your config):

```gdscript
extends ShantyPreviewHost

## Plays the Shanty tab's scenes with the story's own context.

const StoryHost := preload("res://story/story_host.gd")


func make_context() -> ShantyContext:
	var context := StoryHost.StoryContext.new()
	context.flags[&"lamp_dark"] = true
	return context
```

`example/example_preview_host.gd` is the example's: its own context, speakers and strings.

### The theme contract

Put Shanty's items in your **project theme** (**Project Settings > GUI > Theme > Custom**). The
cutscene player is a `CanvasLayer`, and Godot does not carry a parent Control's theme through a
`CanvasLayer`, so a theme set on your own scene's root does not reach it. The tab's preview and Play
draw with the project theme too, with the config's `theme_path` laid over it.

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

### Localization

Shanty reads every word through Godot's `TranslationServer`, so localization is Godot's own CSV
translations, registered in **Project Settings > Localization > Translations** as any game's are.
The CSV is a `keys` column, then one column per locale — as many as you like — then any `_` columns
for the writers, which the importer skips. **The header is the only list of locales there is**:
Shanty names none and treats none as special, the tab's **Source** and **Target** dropdowns list
the header's columns, and **+ Locale** adds one. Coverage is a report, never a gate: the config's
`required_locales` is yours to read in your own tests, and Shanty never enforces it.

### The config

The tab reads one `ShantyProjectConfig`, named by `shanty/config_path`. When the setting is empty,
names no file, or names something that is not a config, the tab says which in its status line,
shows an empty state, and offers **Create config…**. You can also make one with
**Create New > Resource… > ShantyProjectConfig**. Its fields:

- `csv_path` — your translation CSV. One that does not exist yet is created by the first Save.
- `speakers_folder`, `conversations_folder`, `scenes_folder`, `triggers_folder` — where those
  resources live, read recursively; one folder may serve several, each `.tres` listed under its own
  kind.
- `source_locale` — the locale a session opens on, when the CSV has that column; the target is the
  first other one.
- `flags` — one `ShantyFlagRule` per flag your writers may set: its name (`flag`) and, per locale,
  the whole words a flagged line may not contain there (`forbidden_words`). **Flags are yours**:
  Shanty knows none by name, and a locale with no list has no rule. A grammar that agrees in more
  than single words is beyond a word list, so the check is a help, never a guarantee.
- `key_scheme` — how new keys are named ([Keys](#keys)); empty uses the defaults.
- `length_cap` — characters a line or reply may run to before the lint warns; 0 is no cap.
- `trigger_ids` — the moments your game recognises. When the list is not empty it is the whole set
  a trigger may name: **+ Trigger** offers only these, the trigger's **Moment** is a dropdown of
  them, and the lint marks any other. Empty allows any lower-case id. Either way an id is also the
  new trigger's file name, so it may hold only letters, digits, `_` and `-`.
- `theme_path` — the theme the line preview and Play draw with, over your project theme; empty uses
  the project theme alone.
- `highlight_colour` — the colour `[hl]` words draw in for the preview and Play: whatever your game
  passes to `ShantyText.set_highlight_colour()`.
- `preview_host_path` — your [`ShantyPreviewHost`](#hosting-play) script; empty plays with
  Shanty's default.
- `required_locales` — the locales your own tests require ([Localization](#localization)).

This repository's own setting names `example/shanty_config.tres`, so opening it shows the lighthouse
in the tab.

## Authoring reference

**The CSV's own columns.** Two `_` columns mean something to the tab; any other is kept exactly as
it is:

- **`_notes`** — free text for whoever writes or translates the line.
- **`_flags`** — tokens separated by `|`, such as `NEUTRAL` or `NEUTRAL|SHORT`, each checked against
  its rule in [the config](#the-config). The example defines one flag, `NEUTRAL`, with English
  pronouns, and sets it on the two rows that name a speaker by token.

**Markup.** Two pieces are the whole authoring contract:

- **`[hl]…[/hl]`** draws its words in your highlight colour (`ShantyText.set_highlight_colour()`).
  Every other `[` a translator types is drawn as typed — a translation can never inject BBCode.
- **`{name:<speaker_id>}`** is replaced by whatever your speaker provider calls that speaker *now*.
  Rename a character, or hide their name until the reader learns it, and every line, reply, title
  and synopsis that names them follows — without touching a translation.

**A speaker** (`SpeakerDefinition`) is a `speaker_id`, a `name_key`, its `faces` (`SpeakerFace`: a
`tag` and an optional `texture`) and an optional `colour_variation` for its name plate. A line names
a face tag; empty uses the first face, and at runtime an unknown tag falls back to the first face
too (the lint calls it an error).

**A line** (`DialogueLine`) has a `speaker_id`, a `face`, a `text_key`, and optionally:

- **`label`** — a name a reply's `jump_label` can jump to.
- **`conditions`** — every one must hold or the line is skipped, and so are its effects.
- **`effects`** — handed back to you when the line is shown (or skipped past while holding).
- **`choices`** — up to three `DialogueChoice` replies, each with a `text_key`, `effects` returned
  if chosen, and an optional `jump_label` naming another line's `label`. Replies are one level deep,
  and no path through them may come back to a line already passed: a conversation that can loop is
  refused.
- **`reply_speaker_id`** — who answers this line's replies. Once the question has been read, the bar
  hands over to that speaker: their face and name, a short placeholder where the line was, and the
  replies as buttons. Empty uses the host's default (`ShantyViewSettings.reply_speaker_id`); empty
  there too keeps the asker on the bar with the buttons beneath.
- **`voice`** — an optional recorded line.

**A scene** (`CutsceneDefinition`) is a `scene_id` and its `steps`: `BackdropStep` (a still, or the
ground colour, with an optional letterbox), `FadeStep` (out to the ground colour, or in from it),
`SayStep` (a conversation), `PanStep` (the still, in whole art pixels), `WaitStep` and `MusicStep`
(duck or swap). `AnimateStep` and `VideoStep` are declared and unbuilt; the tab never offers them.
A step type of your own is any `CutsceneStep` subclass with a `class_name`, and **+ Step** offers
it. Then:

- **`skippable`** (default on) — holding the advance press skips to the end. A skip returns every
  effect playing would have, and still stops to ask any question it reaches.
- **`title_key`** — the scene's name in a replay list.
- **`remembered`** — whether your replay list keeps this scene once played (off by default, so a
  small or repeating beat never crowds it).
- **`synopsis_key`** — an optional one-sentence summary for that list; it may use `{name:<id>}`.

**A trigger** (`StoryTriggerDefinition`) is a `trigger_id` — one moment your game recognises — and
its `candidates`, each a `StoryCandidate`: a `cutscene`, a `priority` (any whole number), its
`conditions`, and **`once`** (default on), which passes it over when your played records already
hold its scene. A trigger's file is named for the id it was made with; changing the id later leaves
the file where it is.

### Keys

A new line is keyed `DLG_<CONVERSATION>_<nn>` by default, its replies `<line key>A`, `B` and `C`, a
speaker's name `SPEAKER_<ID>`, and a scene's title and synopsis `SCENE_TITLE_<ID>` and
`SCENE_SYNOPSIS_<ID>`. A conversation's prefix is editable in its table, and a `ShantyKeyScheme` in
the config changes any pattern (the example's names its replies `<line key>_A` through
`reply_key = "{LINE}_{LETTER}"`). **A key is never renumbered**: a line inserted mid-conversation
takes the next free number, and moving a line changes the order only — no key and no CSV row moves.
New rows go into the CSV as one block after the conversation's last row, so two people adding to
different conversations touch different parts of the file. Removing a line or a reply removes its
rows when nothing else names them.

### Your CSV's bytes

Every row you did not edit is written back byte for byte, with the line ending it had — LF or CRLF,
mixed if the file mixes them; an edited row keeps its own; a new row takes the ending most of the
file uses. A byte-order mark, and whether the file ended with a line break, are kept as found. A new
column — a locale, or the first `_notes` or `_flags` — goes before the `_` columns or at the end,
and widens every row.

### Save

Save writes the CSV (then asks Godot to reimport it) and every speaker, conversation, scene and
trigger you changed, through `ResourceSaver`; a new resource that names another new one — a new
scene saying a new conversation — names that file rather than holding a copy. Lint errors refuse
it; warnings and coverage never do. **Stale files refuse it**: each file's content is fingerprinted
when the tab reads it, and if any file Save would write has changed on disk since, Save writes
nothing and says which; **Reload** reads the files again, dropping your unsaved edits.

**All or nothing.** Every file is first written beside its target (`<file>.shanty-tmp`, or
`<name>.shanty-tmp.tres` for a resource) and read back; only when every one is ready are they moved
over their targets. If any write fails, every file is left exactly as it was — a target already
replaced is put back from the bytes read before the save — and your edits stay unsaved. A staged
resource keeps its target's `ext_resource` ids, so a one-field edit changes one line of the file:
the ids, every `ExtResource()` naming one, and the uids stay as they were. What else differs is
Godot's own form for the file, as any editor save writes it — properties in the script's order, a
default value left out, a uid added to a hand-written `ext_resource` line. If the editor is scanning
or importing when you save, the tab waits for it to finish before it asks for the reimport.

## Lint rules

Lint runs shortly after every edit, on **Lint**, and before every Save. Each finding names its rule;
it is listed in the issues list, and one about a key also marks the caption under that key's cell.
**Errors refuse Save; warnings never block anything.** A host's own tests can run the same checks:
`ShantyLint.check()` takes the CSV document, the config and the resources, and touches neither the
editor nor the disk.

| Rule | Severity | Finds |
|---|---|---|
| `missing_key` | error | A speaker, line, reply, title or synopsis naming a key the CSV has no row for |
| `empty_key` | error | A speaker, line or reply with no key (a scene's title and synopsis may have none) |
| `duplicate_key` | error | A key on two rows: Godot's importer keeps only the last |
| `row_width` | error | A row wider than the header: the importer ignores the extra cells, which usually mean an unescaped comma |
| `row_width` | warning | A row shorter than the header: its missing cells read as empty, and coverage counts them so; Save writes it back as found unless you edit it |
| `flag_word` | error | A flagged row whose cell in a locale contains a word that flag forbids there |
| `unknown_flag` | warning | A `_flags` token the config does not name, which therefore checks nothing |
| `token_mismatch` | error | Filled locales of one row naming different speakers by `{name:<id>}`, or a different number of times |
| `unknown_token` | warning | A `{name:<id>}` naming a speaker the speakers folder lacks |
| `length` | warning | A line or reply over the config's `length_cap`, markup not counted |
| `unknown_speaker` | error | A line's speaker or reply speaker naming no speaker, or a speaker with no id |
| `duplicate_speaker` | error | Two speakers with one id |
| `unknown_face` | error | A line naming a face its speaker does not have |
| `cycle` | error | A conversation that can loop: a reply jumping back, or a gated line falling through to an earlier one |
| `unknown_label` | error | A reply jumping to a label no line carries |
| `duplicate_label` | error | Two lines of a conversation with one label |
| `duplicate_reply` | error | A reply key used twice — under one line, on two lines, or in two conversations — or two asking lines sharing a key: a record names a reply by its key alone |
| `too_many_replies` | error | More than three replies on a line |
| `unplayable_scene` | error | A scene holding a step this version does not build, or a Say step whose conversation can loop: the player would refuse the whole scene |
| `unknown_trigger` | error | A trigger with no id, or one outside a closed `trigger_ids` |
| `duplicate_trigger` | error | Two triggers with one id (counted apart, so an unknown id on two triggers is both) |
| `unknown_scene` | error | A candidate with no scene, or one the scenes folder does not hold |
| `empty_trigger` | warning | A trigger with no candidate, whose moment always plays nothing |
| `duplicate_candidate` | warning | One scene on two candidates of a trigger — sometimes meant, as one scene behind two gates |
| `unsafe_trigger_id` | warning | A `trigger_ids` entry that cannot be a file name, so no trigger can be made for it |

A forbidden word is matched whole and case-insensitively, without its markup and `{name:}` tokens;
an accent or other combining mark belongs to its word, and an apostrophe is an edge, so `she` is
found in `she's` and `homme` in `l'homme` (a listed `she's` matches only itself, and `’` reads as
`'`).

## Rules the code keeps

- A line's effects are collected when it becomes current, a reply's when it is chosen; skipping
  walks the same path, so a skipped scene returns the same effects as a played one.
- A skip never answers a choice: it stops on the line and asks.
- The question is always read in full before the replies appear; the chosen reply is not shown
  again as a line.
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
- The tab's Play plays the files on disk, and a request once: it is refused while the tab holds
  unsaved edits, and the game window takes the request as it reads it. It plays only a request
  naming a scene or trigger, a locale and a config, each a `res://` path inside your project to a
  file of that kind, and says which part it refused otherwise.

## Layout

| Path | What lives there |
|---|---|
| `data/` | The authored shapes: `SpeakerDefinition`/`SpeakerFace`, `ConversationDefinition`, `DialogueLine`, `DialogueChoice`, `CutsceneDefinition`, `CutsceneStep` and `steps/` (`BackdropStep`, `PanStep`, `FadeStep`, `SayStep`, `WaitStep`, `MusicStep`; `AnimateStep` and `VideoStep` declared and unbuilt), `StoryTriggerDefinition`/`StoryCandidate`, and the `PlayedSceneRecord` a host persists |
| `core/` | Pure code, the four host interfaces and the contract: `ShantyRunner`, `ShantySelector`, `ShantyText`, `ShantyViewSettings`, `ShantySpeaker`; `ShantyContext`, `ShantyCondition`, `ShantyEffect`, `ShantySpeakerProvider`; `ShantyHostContract` |
| `ui/` | `CutscenePlayer` (layer, shield, backdrop, letterbox, fade, hold-to-skip, replay) and `DialogueView` (the top-docked bar), with the pieces they are built from: `ShantyBackdrop` (integer-scale still and pan), `ShantyPressInput` (tap versus hold, and the waits a tap may cut short), `ShantySay` (a scene's conversations), `ShantyMusic` (duck/swap and their undo), `ShantyTypewriter` (a line typing out), `ShantyReplyTurn` (the reply speaker's turn and its buttons), `ShantyLineAudio` (a line's voice and its blips), `ShantyChoiceButton`, `ShantyContinueMarker`, `SkipHold` |
| `lint/` | Pure checks the tab and a host's tests share, with no editor and no file access: `ShantyCsvDocument` (with `ShantyCsvCodec` and `ShantyCsvRow`) reads and writes the translation CSV, `ShantyLocaleCoverage` reports one locale, `ShantyKeyScheme` names keys, `ShantyLint` (with `ShantyLintText` and `ShantyLintStory`) returns `ShantyLintIssue`s, and `ShantyProjectConfig` with its `ShantyFlagRule`s is a host's configuration |
| `editor/` | The Shanty tab. `model/` holds everything it knows and does, testable without the editor: `ShantyEditorModel`, `ShantySpeakerEdits`, `ShantyConversationEdits`, `ShantySceneEdits`, `ShantyTriggerEdits`, `ShantyPreviewModel` (what the line preview draws), `ShantyPlay` (what Play asks for), `ShantyClassCatalog` (the pickers' classes), `ShantySaveResult`, `ShantySaveTransaction`, and `ShantyFiles`, the one script that opens a file your config names. `preview/` is Play's game-window side: `preview_host.tscn`, `ShantyPreviewHost` and `ShantyPreviewSpeakers`. The scenes and scripts beside them are thin panes over that model |
| `example/` | A whole host with no other code: context, condition, effect, speaker provider, host scene, a three-line conversation with one choice, its scene and trigger, two speakers, its own strings, `shanty_config.tres`, its configuration for the tab, and `example_preview_host.gd`, what Play plays it with. Its scripts declare no `class_name`, so installing Shanty spends no global names on it. It reads `example_strings.csv` at runtime, which an export does not include, so it runs from the editor; a real host registers its catalogue in Project Settings and needs no loader |
| `plugin.cfg`, `plugin.gd` | The editor plugin: the Shanty tab and the `shanty/config_path` setting |
| `CHANGELOG.md`, `LICENSE`, `MANIFEST.sha256` | What each version changed; MIT; the release's file hashes |

## Running the tests

This repository is a Godot project that opens straight into the example. Its tests use
[GUT](https://github.com/bitwes/Gut) 9.7.1, bundled under `addons/gut/` for local runs only:

```sh
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gexit -gconfig=.gutconfig.json
python -m unittest discover -s tools -p "*_test.py"  # the tools' own tests
```

Scripts are fully typed and kept `gdformat`/`gdlint` clean. Among the tests, one holds this README
to the code: every key, class, file and `res://addons/shanty/` path it names exists, and every key
the tutorial says the tab will name is the one the default key scheme makes.

## Versioning and the manifest

A release bumps `plugin.cfg`'s `version`, opens the matching topmost section of `CHANGELOG.md` (a
test holds the two equal), and is tagged `vX.Y.Z`; CI refuses a tag that disagrees with either.
Until 1.0.0 a minor version may change the authored data's shape, and the changelog marks every such
change **BREAKING** with a migration line.

Every release carries `MANIFEST.sha256`: the SHA-256 of every file in the addon, so you can check
that your copy is the release, unmodified. It leaves out what Godot writes on import — `.uid`,
`.import` and `.translation` files — and itself.

```sh
python tools/manifest.py          # rewrite MANIFEST.sha256 after changing the addon
python tools/manifest.py --check  # what CI runs
```
