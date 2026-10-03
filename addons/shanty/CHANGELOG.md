# Changelog

All notable changes to Shanty are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the version numbers follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). Until 1.0.0, a minor version may
change the authored data's shape; every such change is marked **BREAKING** with a migration line.

The topmost section is always the version in `plugin.cfg`, and a release tag `vX.Y.Z` always has
its section here.

## 0.3.0

The editor surface for writers, second half: scenes and triggers edited in the Shanty tab, each
line drawn in the host's own dialogue bar as it is typed, and Play, which runs a scene in a game
window through the real player. No authored data changes shape, so nothing here is **BREAKING**;
the config gains one optional field.

### Added

- **A scene pane.** Title and synopsis cells in the source and target locales, their keys named by
  the scheme's scene patterns and their two rows written as one block after the other scenes';
  Skippable and Remembered; the steps in order, added, inserted after any step, moved and removed
  without touching the others, each new step opened in the Inspector and each row summarised from
  its values (`Say: lamp_talk`, `Fade in 0.5 s`). A Say row opens its conversation. Step types come
  from `ShantyClassCatalog`, `AnimateStep` and `VideoStep` hidden while unbuilt.
- **A trigger pane.** The moment, chosen from the config's `trigger_ids` when it lists them and
  typed when it does not; candidates with a scene picked from the scenes folder, a priority (any
  whole number a 64-bit int holds, typed, as `StoryCandidate.priority` allows: the tab sets no range
  of its own), `once` and conditions, added, moved and removed. The left pane makes scenes and
  triggers too, and offers a closed set's free ids for + Trigger; it follows every edit, so an id
  changed in a form shows in its row and in those free ids at once, the pick kept.
- **The line preview.** The picked line in the real `DialogueView` scene, instanced under a plain
  `Control` carrying the project theme with the config's `theme_path` merged over it: the speaker's
  name and face, `{name:}` tokens and `[hl]` words resolved from the tab's CSV as it is typed, in the
  source or the target locale, and an asking line's reply turn as the view draws it. A test holds it
  equal to a playing view showing the same line.
- **Play.** The toolbar's Play writes the picked scene, or the picked trigger whose choice to play,
  to `user://shanty_preview.cfg` and runs `editor/preview/preview_host.tscn` through
  `EditorInterface.play_custom_scene()`. The preview host applies the locale, the highlight colour
  and the theme in code, plays through the real `CutscenePlayer`, prints every effect and the
  record, and closes on Escape. It is refused while the tab holds unsaved edits.
- **`ShantyPreviewHost`**, the base a host extends for Play — `make_context()`,
  `make_speaker_provider()`, `make_settings()`, `make_records()`, `make_translations()` — named by
  the config's `preview_host_path`. With none named, Play uses the base: an empty context, the
  config's speakers folder (`ShantyPreviewSpeakers`), default settings.
- **Scene and trigger lint** (`ShantyLintStory`): errors `unplayable_scene` (a step this version does
  not build, or a Say step whose conversation can loop), `unknown_trigger` (no id, or one outside a
  closed `trigger_ids`), `duplicate_trigger` (counted apart from `unknown_trigger`, so an unknown id
  on two triggers reports both) and `unknown_scene` (a candidate with no scene, or one the scenes
  folder does not hold); warnings `empty_trigger`, `duplicate_candidate` and `unsafe_trigger_id` (a
  `trigger_ids` entry that is not letters, digits, `_` and `-`). A step is asked through a fresh copy
  of its script inside the editor, where the loaded one is a placeholder, and directly elsewhere.
  `ShantyLint.check()` takes the triggers as an optional last argument.
- **`ShantyProjectConfig.highlight_colour`**, the colour `[hl]` words draw in for the preview and
  Play. `trigger_ids`, `theme_path` and `preview_host_path` are now read: the first by the lint and
  the trigger pane, the others by the preview and Play.
- **Model classes** for all of it, testable without the editor: `ShantySceneEdits`,
  `ShantyTriggerEdits`, `ShantyPreviewModel` and `ShantyPlay`. Every trigger id, from a closed set
  or typed, must be a safe file name (`ShantyLintStory.is_safe_stem()`), so no id from the config
  can put a trigger's file outside the triggers folder.
- **The example plays from the tab:** `example/example_preview_host.gd` (its context, speakers and
  strings), `example/example_trigger.tres` (the moment `lamp`), and a config naming both, with a
  closed set of trigger ids and its highlight colour.

### Fixed

- A new resource saved alongside another new one that names it — a new scene saying a new
  conversation — is written as a reference to that file, not as an embedded copy:
  `ShantySaveTransaction.claim_paths()` names every new resource before anything is staged, and a
  failed save takes the names back.

## 0.2.0

The editor surface for writers, first half: a Shanty tab for speakers and conversations, and the
pure checks it shares with a host's own tests. Scenes, triggers, the line preview and Play arrive in
0.3.0. No authored data changes shape, so nothing here is **BREAKING**.

### Added

- **The Shanty tab**, a main-screen tab beside 2D, 3D and Script once the plugin is enabled. A list of
  speakers and conversations (scenes and triggers listed, editing in 0.3.0); a speaker form with the
  name key, the name in two locales, notes and faces, each face's texture chosen through the
  editor's resource picker; a line table with speaker and face dropdowns, source and target text,
  each key and its state, flag toggles, notes, labels, up to three replies with their own keys, jumps
  and effects, condition and effect pickers whose entries are edited in the Inspector, and per line
  **Insert after**, up, down and remove. A toolbar
  with the source and target locale dropdowns, **+ Locale**, the coverage strip, Reload, Lint and
  Save.
- **Locales come from the CSV header only.** Any column that is not the keys column and does not
  start with `_` is a locale, Godot's own rule; the writer sees one source and one target at a time,
  chosen from dropdowns, and **+ Locale** adds a column. An empty target cell is drawn as an empty
  dashed box.
- **Coverage is a report, never a refusal.** The strip counts filled cells per locale and colours an
  incomplete one; an empty cell never blocks Save.
- **`_flags`**, a structured CSV column of `|`-separated tokens, beside the free-text `_notes`. A host
  names its flags and, per locale, the whole words a flagged line may not contain; Shanty knows no
  flag by name.
- **Save that never overwrites unseen work, all or nothing.** Save lints first and refuses on an
  error; it fingerprints every file when it is read and refuses, writing nothing, when one it would
  write has changed on disk since. It stages every output beside its target, reads each back, and
  only then moves them over their targets (`ShantySaveTransaction`); a failure at any point leaves
  every file as it was, putting back any target already replaced. New rows go in as one block after
  their conversation's last row, changed resources are saved through `ResourceSaver`, and the CSV is
  reimported once the editor's filesystem is idle — never a scan during a scan. A staged resource
  keeps its target's `ext_resource` ids (the text saver keys them by the path it writes), so a
  one-field edit changes exactly one line of the file, ids and uids untouched.
- **A CSV's bytes are kept outside the rows you edit.** Every untouched row is written back byte for
  byte with its own line ending (LF or CRLF, mixed as the file mixes them); an edited row keeps its
  ending and a new row takes the file's dominant one; a byte-order mark and a missing final line
  break are kept.
- **Insert and reorder lines without renumbering.** `ShantyConversationEdits.insert_line_after()`
  keys a new line by the next free number wherever it sits; `move_line()` changes order only, no key
  and no CSV row.
- **`lint/`, pure and headless:** `ShantyCsvDocument` (with `ShantyCsvCodec` and `ShantyCsvRow`)
  reads and writes the translation CSV exactly as Godot's importer reads it; `ShantyLocaleCoverage`;
  `ShantyKeyScheme`, which names new keys from configurable patterns and never renumbers one;
  `ShantyLint` (with `ShantyLintText`), whose `ShantyLintIssue`s cover missing and doubled keys, row
  width (`row_width`: a row wider than the header is an error, since the importer ignores its extra
  cells; a shorter one only a warning, since the importer — verified on Godot 4.7.1 — reads its
  missing cells as empty, as coverage does, and Save never pads it unless it was edited), flagged words, `{name:}` tokens that differ between locales, loops, jumps
  to missing labels, unknown speakers and faces, a reply key used twice anywhere in the
  conversations it is handed (a played record could not tell them apart), and over-length lines;
  and `ShantyProjectConfig` with `ShantyFlagRule`. A forbidden word is matched whole and
  case-insensitively, a combining mark belongs to its word, and an apostrophe is a word edge.
- **`editor/model/`, testable without the editor:** `ShantyEditorModel`, `ShantySpeakerEdits`,
  `ShantyConversationEdits`, `ShantyClassCatalog`, `ShantySaveResult`, `ShantySaveTransaction` and
  `ShantyFiles`. The tab itself also instantiates and opens headlessly.
- **The project setting `shanty/config_path`**, registered by the plugin, naming the host's
  `ShantyProjectConfig`. It defaults to the example's config inside the addon, so a fresh install
  opens on the demo. With no usable config the tab names the problem (`ShantyEditorModel.Problem`),
  shows an empty state, and offers **Create config…**, which saves a new config with its CSV and
  folders beside it and points the setting at it.
- **The example is the tab's demo:** `example/shanty_config.tres` (its CSV and folders, a key scheme
  matching its line and reply keys, and one flag, `NEUTRAL`, with English pronouns), a partial French column and a
  `_flags` column in `example_strings.csv`, and this repository's `shanty/config_path` pointing at it.

### Changed

- **`plugin.cfg` is no longer editor-inert.** Enabling the plugin adds the tab and the project
  setting. The runtime still needs no plugin: every class registers through `class_name`.
- The example's two reply keys are renamed `SHANTY_EXAMPLE_REPLY_A`/`_B` →
  `SHANTY_EXAMPLE_LINE_3_A`/`_B`, so its key scheme (`reply_key = "{LINE}_{LETTER}"`) names them.
  Example data only, not a shape change; a project that followed the 0.1.0 tutorial against the
  example's strings renames the two `text_key`s in its own conversation.
- The example's placeholder face border is pure black (`Color.BLACK`), the neutral default a host's
  palette check expects, rather than a near-black.
- The example's translation loader skips an empty cell, so a partly translated locale falls back
  instead of showing nothing.

## 0.1.0

The first public release: the runtime, the host contract and an example host. The editor surface
for writers arrives in 0.2.0; until then everything is authored as `.tres` resources and CSV rows.

### Added

- **Authored data as typed resources.** Speakers with faces chosen by an emotion tag;
  conversations of lines, each with optional conditions, effects, a voice and up to three replies;
  replies that may jump to a labelled line; scenes made of steps; triggers whose candidates are
  chosen by priority; and the record a host keeps of a scene once it has finished. Text is never
  stored in a resource — only translation keys.
- **A pure runner and selector.** `ShantyRunner` walks a conversation against the host's context and
  collects what each line and reply asks the host to do; skipping a conversation collects exactly
  what playing it would, and never answers a question for the reader. `ShantySelector` picks the
  scene a trigger plays, or none. Neither touches a node.
- **A conversation that can loop is refused.** A reply that jumps back to an earlier line — or a
  gated line that, once it fails, falls through to one that does — is authoring error:
  `ShantyRunner.start()` refuses it with an error naming the conversation and returns `false`, and
  the cutscene player refuses a scene holding one before it starts, exactly as it refuses an
  unbuilt step. A skip walks a conversation in one go, so a loop would never end.
- **Four host interfaces.** A context, conditions, effects and a speaker provider: the host subclasses
  them, and Shanty never applies an effect or reads the host's state itself.
- **The dialogue bar** (`DialogueView`): a portrait, a name plate and a line typing out at the reader's
  speed; a flat name plate when a face is missing; replies as the answering speaker's turn, as
  buttons for keyboard, controller and mouse.
- **The cutscene player** (`CutscenePlayer`, a `CanvasLayer`): an input shield, a backdrop still with
  optional letterbox bars, a dim when no backdrop is up, fades, and a hold-to-skip control. One press
  is both "go on" (tapped) and "skip the scene" (held). It reports `finished` once, at the end, with
  the record and the effects.
- **Steps:** backdrop, pan (in whole art pixels), fade, say (a conversation), wait (a tap may cut it
  short unless authored not to), and music (duck the host's music bus or swap its stream, always put
  back when the scene ends by any route). Animation and video steps are declared and deliberately
  unbuilt: a scene holding one is refused before it starts.
- **Read-only replay.** A finished scene can be played again from its record: each reply is spoken
  as the reply speaker's line rather than offered, no effect is returned, and the replay ends on its
  own signal so it can never be recorded as a new playing.
- **Records that outlive their scenes.** A record keeps the scene's title, synopsis key and
  `remembered` flag as they were when it played, so a host's replay list never depends on the scene
  file surviving.
- **Text.** One highlight tag, `[hl]…[/hl]`, in a colour the host chooses; every other bracket a
  translator types is drawn as typed, never as markup. `{name:<speaker_id>}` names a speaker through
  the provider, so renaming or hiding a character changes every text that names them.
- **Reading settings the host injects:** text speed, auto-advance, speaker names on or off, reduced
  motion (no typing, no pan, no fade), text blips, a per-line voice, and the buses and music player
  Shanty may use.
- **Theming by name only.** Every control asks for a theme type variation (`ShantyBar`,
  `ShantyPortrait`, `ShantyName`, `ShantyLine`, `ShantyChoice`, `ShantyHint`, `ShantySkipBar`); a host
  that declares none gets the engine's defaults.
- **The frame's ground colour is a theme colour.** The ground behind a still, the letterbox bars,
  the fade and the dim all draw in `ground_color` on the `ShantyFrame` theme type, read when the
  player is ready and whenever its theme changes; the dim keeps 0.6 of it. Without one they are
  black, which is also all `cutscene_player.tscn` itself holds.
- **`ShantyHostContract`**, which publishes everything a host provides: the theme type variations
  and the class each styles, every theme item the code reads by name (`THEME_ITEMS`, spelled
  `<type>/<kind>/<item>` as a theme `.tres` spells it), the ground colour, and the three translation
  keys (`SHANTY_HOLD_TO_SKIP`, `SHANTY_REPLY_PLACEHOLDER`, `SHANTY_READING_AGAIN`). A test holds it
  equal to what the scenes and scripts really look up — every assigned variation, every
  `get_theme_*` call, every translated key — not to the names they merely mention.
- **`MANIFEST.sha256`**: the SHA-256 of every file in the addon (`.uid` and `.import` files aside),
  so a host can prove its copy is unmodified.
- **An example host** in `example/`, with its own strings in English and Brazilian Portuguese, that
  plays, applies and replays a scene with no other code.
- **`plugin.cfg`**, editor-inert: enabling it changes nothing, and the classes register through
  `class_name` either way.

### Changed

- **BREAKING** for anyone who used a pre-release build: the context's ordinal is
  `ShantyContext.playthrough_ordinal()`, and a played record stores it as
  `PlayedSceneRecord.playthrough_ordinal`, under the dictionary key `"playthrough_ordinal"`.
  Migration: rename the override in your context subclass, and rename the ordinal key in any record
  dictionary you saved before calling `PlayedSceneRecord.from_dictionary()` — a record whose key is
  missing reads its ordinal as 0.
