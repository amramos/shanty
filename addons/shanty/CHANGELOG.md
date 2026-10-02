# Changelog

All notable changes to Shanty are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the version numbers follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). Until 1.0.0, a minor version may
change the authored data's shape; every such change is marked **BREAKING** with a migration line.

The topmost section is always the version in `plugin.cfg`, and a release tag `vX.Y.Z` always has
its section here.

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
  and effects, and condition and effect pickers whose entries are edited in the Inspector. A toolbar
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
- **Save that never overwrites unseen work.** Save lints first and refuses on an error; it
  fingerprints every file when it is read and refuses, writing nothing, when one it would write has
  changed on disk since. It writes the CSV with every untouched row byte for byte and new rows as one
  block after their conversation's last row, saves changed resources through `ResourceSaver`, and
  reimports the CSV.
- **`lint/`, pure and headless:** `ShantyCsvDocument` (with `ShantyCsvCodec` and `ShantyCsvRow`)
  reads and writes the translation CSV exactly as Godot's importer reads it; `ShantyLocaleCoverage`;
  `ShantyKeyScheme`, which names new keys from configurable patterns and never renumbers one;
  `ShantyLint` (with `ShantyLintText`), whose `ShantyLintIssue`s cover missing and doubled keys, rows
  the importer would drop, flagged words, `{name:}` tokens that differ between locales, loops, jumps
  to missing labels, unknown speakers and faces, replies a played record could not tell apart, and
  over-length lines; and `ShantyProjectConfig` with `ShantyFlagRule`.
- **`editor/model/`, testable without the editor:** `ShantyEditorModel`, `ShantySpeakerEdits`,
  `ShantyConversationEdits`, `ShantyClassCatalog`, `ShantySaveResult` and `ShantyFiles`.
- **The project setting `shanty/config_path`**, registered by the plugin, naming the host's
  `ShantyProjectConfig`.
- **The example is the tab's demo:** `example/shanty_config.tres` (its CSV and folders, a key scheme
  matching its keys, and one flag, `NEUTRAL`, with English pronouns), a partial French column and a
  `_flags` column in `example_strings.csv`, and this repository's `shanty/config_path` pointing at it.

### Changed

- **`plugin.cfg` is no longer editor-inert.** Enabling the plugin adds the tab and the project
  setting. The runtime still needs no plugin: every class registers through `class_name`.
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
