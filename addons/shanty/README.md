# Shanty

Dialogue and short cutscenes for Godot 4, authored as typed data. Text lives in your translation
catalogue under stable keys; structure lives in `.tres` resources; a pure runner walks a
conversation and hands back what your game should do, and a `CanvasLayer` player presents it.

Shanty owns no state and no theme. It never applies an effect, never saves anything, and never
decides when a scene should play: your game does all three, through four small interfaces.

**Version 0.1.0.** Requires Godot 4.4 or later (typed dictionaries); developed and tested on 4.7.1.
MIT licensed. Everything is authored as resources and CSV rows today; an editor surface for writers
arrives in 0.2.0. Until then `plugin.cfg` is editor-inert: the classes register through `class_name`
alone, so there is nothing to enable.

## Install

Copy `addons/shanty/` into your project — it is the only folder you need. A release's source archive
contains exactly that folder. Then declare what the [host contract](#the-host-contract) asks for:
three translation keys, and optionally a theme.

Every release carries `MANIFEST.sha256`: the SHA-256 of every file in the addon (`.uid` and
`.import` files aside, which Godot writes), so you can check that your copy is the release,
unmodified.

## Author your first scene in ten minutes

`example/` holds every file this walkthrough names, finished and playing: open
`example/example_host.tscn` and run it (F6). What follows builds the same thing from nothing — a
lighthouse keeper, a visitor, and one question.

### 1. Write the words

Every word a reader sees is a translation key. Add yours to a CSV in Godot's own shape and add the
CSV to **Project Settings > Localization > Translations**:

```csv
keys,en,pt_BR,_notes
LAMP_SPEAKER_KEEPER,The Keeper,O Faroleiro,A column whose header starts with _ is ignored
LAMP_LINE_1,You came back. The [hl]lamp[/hl] has been dark since you left.,…,
LAMP_LINE_2,"I said I would, {name:keeper}.",…,
LAMP_LINE_3,"Will you light it tonight, or shall I?",…,
LAMP_REPLY_A,I will light it.,…,
LAMP_REPLY_B,You light it. I will watch.,…,
```

Two pieces of markup are the whole authoring contract:

- **`[hl]…[/hl]`** draws its words in your highlight colour (`ShantyText.set_highlight_colour()`).
  Every other `[` a translator types is drawn as typed — a translation can never inject BBCode.
- **`{name:<speaker_id>}`** is replaced by whatever your speaker provider calls that speaker *now*.
  Rename a character, or hide their name until the reader learns it, and every line, reply, title
  and synopsis that names them follows — without touching a translation.

### 2. Make a speaker

A `SpeakerDefinition` (`example/speaker_keeper.tres`): a `speaker_id` lines refer to, a `name_key`,
and `faces` — one `SpeakerFace` per emotion tag (`neutral`, `wary`…), each with a texture. A line
names a tag; an unknown tag falls back to the first face. **A missing texture is never an error:**
the bar draws a flat plate with the speaker's name instead, so words may arrive before art.

Your speaker provider (step 5) turns a `speaker_id` into what the bar draws. The example's provider
reads its two definitions and paints a placeholder face in code.

### 3. Write the conversation

A `ConversationDefinition` (`example/example_conversation.tres`) is an ordered list of
`DialogueLine`s. Each line has a `speaker_id`, a `face`, a `text_key`, and optionally:

- **`conditions`** — every one must hold or the line is skipped, and so are its effects.
- **`effects`** — handed back to you when the line is shown (or skipped past while holding).
- **`choices`** — up to three `DialogueChoice` replies, each with a `text_key`, `effects` returned if
  chosen, and an optional `jump_label` naming another line's `label`. Replies are one level deep.
- **`reply_speaker_id`** — who answers this line's replies. Once the question has been read, the bar
  hands over to that speaker: their face and name, a short placeholder where the line was, and the
  replies as buttons. Empty uses the host's default (`ShantyViewSettings.reply_speaker_id`); empty
  there too keeps the asker on the bar with the buttons beneath.
- **`voice`** — an optional recorded line.

### 4. Make the scene

A `CutsceneDefinition` (`example/example_scene.tres`) is a `scene_id` and a list of steps:
`BackdropStep` (a still, optional letterbox), `FadeStep` (in or out), `SayStep` (a conversation),
`PanStep`, `WaitStep` and `MusicStep`. The example's is backdrop → fade in → say → fade out. Then:

- **`skippable`** (default on) — holding the advance press skips to the end. A skip returns every
  effect playing would have, and still stops to ask any question it reaches.
- **`title_key`** — the scene's name in a replay list.
- **`remembered`** — whether your replay list keeps this scene once played (off by default, so a
  small or repeating beat never crowds it).
- **`synopsis_key`** — an optional one-sentence summary for that list; it may use `{name:<id>}`.

### 5. Give your game a trigger

A `StoryTriggerDefinition` names one moment your game recognises (`chapter_start`, `door_opened`…)
and lists `StoryCandidate`s, each a scene with a `priority`, `conditions`, and **`once`** (default
on): a `once` candidate is passed over when your played records already hold its scene. Shanty never
decides when a moment happens — your code does, then asks the selector:

```gdscript
const PLAYER_SCENE: PackedScene = preload("res://addons/shanty/ui/cutscene_player.tscn")


func on_moment(trigger: StoryTriggerDefinition) -> void:
	var candidate: StoryCandidate = ShantySelector.select(trigger, context, played_records)
	if candidate == null:
		return  # Nothing to say here.
	var player: CutscenePlayer = PLAYER_SCENE.instantiate()
	add_child(player)
	player.finished.connect(_on_finished.bind(player), CONNECT_ONE_SHOT)
	player.play(candidate.cutscene, context, speakers, settings)


func _on_finished(
	record: PlayedSceneRecord, effects: Array[ShantyEffect], player: CutscenePlayer
) -> void:
	for effect: ShantyEffect in effects:
		apply(effect)  # Yours: Shanty never applies an effect.
	played_records.append(record)  # Persist record.to_dictionary() in your save.
	player.queue_free()
```

### 6. Play it, and play it again

`finished` fires once, at the end — never at the start — so a scene abandoned halfway plays again.
To replay a record read-only, `play_replay(scene, record, context, speakers, settings)` on a fresh
player and wait for `replay_finished`: each reply is spoken from the record rather than offered,
and nothing is returned. `example/example_host.gd` does both, and applies its one effect type.

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
whose header starts with `_` for notes. No locale is special to Shanty, and it never names one; the
example carries English and Brazilian Portuguese only because it needs two to show the mechanism.
Which locales your game requires is your rule, not Shanty's.

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
| `example/` | A whole host with no other code: context, condition, effect, speaker provider, host scene, a three-line conversation with one choice, its scene, two speakers, and its own strings. Its scripts declare no `class_name`, so installing Shanty spends no global names on it. It reads `example_strings.csv` at runtime, which an export does not include, so it runs from the editor; a real host adds its catalogue through Project Settings and needs no loader |
| `plugin.cfg`, `plugin.gd` | Editor-inert in this version |
| `CHANGELOG.md`, `LICENSE`, `MANIFEST.sha256` | What each version changed; MIT; the release's file hashes |

## Developing Shanty

The repository is a Godot project that opens straight into the example. Its tests use
[GUT](https://github.com/bitwes/Gut) 9.7.1, bundled under `addons/gut/` for local runs only:

```sh
godot --headless --import
godot --headless -s addons/gut/gut_cmdln.gd -gexit -gconfig=.gutconfig.json
python tools/manifest.py          # rewrite MANIFEST.sha256 after changing the addon
python tools/manifest.py --check  # what CI runs
```

Scripts are fully typed and kept `gdformat`/`gdlint` clean. A release bumps `plugin.cfg`'s
`version`, opens the matching topmost section of `CHANGELOG.md` (a test holds the two equal), and is
tagged `vX.Y.Z`; CI refuses a tag that disagrees with either.
