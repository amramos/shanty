# Changelog

All notable changes to Shanty are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the version numbers follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). Until 1.0.0, a minor version may
change the authored data's shape; every such change is marked **BREAKING** with a migration line.

The topmost section is always the version in `plugin.cfg`, and a release tag `vX.Y.Z` always has
its section here.

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
  and the class each styles, the ground colour, and the three translation keys
  (`SHANTY_HOLD_TO_SKIP`, `SHANTY_REPLY_PLACEHOLDER`, `SHANTY_READING_AGAIN`). A test holds it equal
  to what the scenes and scripts really use.
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
