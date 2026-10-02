class_name ShantyViewSettings
extends RefCounted

## The reading preferences the host injects into the view. The view never
## reads the host's settings store itself.

## Characters revealed per second; 0 or less reveals each line at once.
var text_speed_chars_per_second: float = 40.0
## Advance on its own once a line without choices has finished revealing.
var auto_advance: bool = false
## Show the speaker's name. Off hides it everywhere -- the name plate and the
## flat plate a speaker with no face shows, which then stays blank.
var speaker_names: bool = true
## Who answers a line's replies: when a line's text has revealed, the bar hands
## the turn to this speaker -- their face and name, a placeholder for a line, and
## the replies as buttons. Empty keeps the asking speaker on the bar. A line may
## name its own with `DialogueLine.reply_speaker_id`.
var reply_speaker_id: StringName = &""
## Motion the reader asked to be spared: a pan jumps to where it ends, a fade
## cuts, and a line appears whole rather than typing out.
var reduced_motion: bool = false
## A short sound as the text types out, one per group of revealed characters.
var text_blips: bool = true
## The sample a blip plays. Null is silence -- a host with no sample yet is
## allowed to have none.
var text_blip: AudioStream = null
## The bus a blip plays on. Unknown falls back to the engine's first bus.
var blip_bus: StringName = &"SFX"
## The bus a line's `voice` plays on.
var voice_bus: StringName = &"Voice"
## The audio bus a MusicStep ducks. Empty or unknown leaves every bus alone.
var music_bus: StringName = &"Music"
## The host's music player a MusicStep swaps a stream on -- an
## AudioStreamPlayer, AudioStreamPlayer2D or AudioStreamPlayer3D. Null makes a
## swap do nothing, which a scene without music has every right to.
var music_player: Node = null
