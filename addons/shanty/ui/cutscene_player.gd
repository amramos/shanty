class_name CutscenePlayer
extends CanvasLayer

## Plays one CutsceneDefinition: runs its steps in order, hosts the dialogue
## bar, and answers the one press that is both "go on" (tapped) and "skip the
## scene" (held; ShantyPressInput times it). Emits `finished` exactly once, at
## the end -- never at the start -- with the record and the effects the host
## should apply; Shanty applies nothing itself.
##
## **The frame, back to front:** an input shield that swallows every click
## meant for the game underneath; a ground colour and the backdrop still; two
## letterbox bars; the dim, shown only while no backdrop is up (a backdrop *is*
## the scene, so nothing behind it needs dimming); the dialogue bar; the fade;
## and the skip affordance, above the fade so it is readable from the first
## black frame.
##
## **A replay is read-only** (`play_replay()`): each reply is answered from the
## record and spoken by the reply speaker as an ordinary line, nothing is
## offered, every effect is discarded, a small caption (`READING_AGAIN_KEY`)
## sits in the frame's top-right corner throughout, and it ends on
## `replay_finished` -- never `finished`, so a host cannot record a replay as a
## new playing by accident. A line the record cannot answer ends the replay's
## dialogue there (ShantySay). A host may close a replay early with
## `stop_replay()`; a first playing has no such exit.
##
## **Reduced motion cuts every fade**, as it lands every pan at once and types
## every line whole.
##
## **The ground colour is the host's.** The ground, the letterbox bars, the fade
## and the dim all take one theme colour, `ground_color` on the `ShantyFrame`
## type (ShantyHostContract), read when the player is ready and again whenever
## its theme changes; the dim keeps `DIM_ALPHA` of it. A theme that declares none
## leaves them black.
##
## **A scene holding a step this version does not build is refused whole**
## (CutsceneStep.is_built()): an error, then `finished` at once with an empty
## record naming no scene, so the boundary is released and nothing is recorded.
##
## Pausable on purpose: a host's pause menu freezes the scene under it rather
## than cancelling it, because the typewriter, the fades and the hold all stop
## with the tree.

signal finished(record: PlayedSceneRecord, effects: Array[ShantyEffect])
## A replay reached its end. Carries nothing: a replay changes nothing.
signal replay_finished

## Seconds the advance input must be held to skip the scene.
const HOLD_TO_SKIP_SECONDS: float = 0.8
## Translation key for the caption a replay wears. The host's catalogue
## defines it.
const READING_AGAIN_KEY: String = "SHANTY_READING_AGAIN"
## The theme type and colour the frame's ground is drawn in.
const FRAME_VARIATION: StringName = &"ShantyFrame"
const GROUND_COLOR: StringName = &"ground_color"
## What the ground is when the host's theme declares no colour.
const DEFAULT_GROUND: Color = Color(0.0, 0.0, 0.0)
## How much of the ground colour the dim lays over the host's frame.
const DIM_ALPHA: float = 0.6

## Height of each cinematic bar on the UI base, when a backdrop asks for them.
@export var letterbox_height: float = 64.0

var _scene: CutsceneDefinition = null
var _context: ShantyContext = null
var _settings: ShantyViewSettings = ShantyViewSettings.new()
var _running: bool = false
var _skipping: bool = false
var _step_index: int = -1
var _step_generation: int = 0
var _step_in_progress: bool = false
## The scene's conversations: the runner, the replies taken, the effects owed.
var _say: ShantySay = null
var _fade_tween: Tween = null
## Null outside a replay; inside one, the record every reply is answered from.
var _replay: PlayedSceneRecord = null
var _music: ShantyMusic = null
var _press: ShantyPressInput = null

@onready var _shield: Control = %InputShield
@onready var _ground: ColorRect = %Ground
@onready var _backdrop: ShantyBackdrop = %Backdrop
@onready var _letterbox_top: ColorRect = %LetterboxTop
@onready var _letterbox_bottom: ColorRect = %LetterboxBottom
@onready var _dim: ColorRect = %Dim
@onready var _view: DialogueView = %DialogueView
@onready var _fade_rect: ColorRect = %Fade
@onready var _skip_hold: SkipHold = %SkipHold
@onready var _reading_again: Label = %ReadingAgain


func _ready() -> void:
	_press = ShantyPressInput.new()
	_press.name = "PressInput"
	_press.hold_seconds = HOLD_TO_SKIP_SECONDS
	_press.skip_bar = _skip_hold
	_press.may_begin = func() -> bool: return not _view.is_waiting_for_choice()
	_press.tapped.connect(_on_tapped)
	_press.held.connect(skip)
	add_child(_press)
	_shield.gui_input.connect(_on_shield_input)
	get_viewport().size_changed.connect(_layout_frame)
	_ground.theme_changed.connect(_apply_ground_colour)
	_apply_ground_colour()
	_view.hide()
	_skip_hold.hide()
	_reading_again.hide()
	_reading_again.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_layout_frame()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _reading_again != null:
		_reading_again.text = tr(READING_AGAIN_KEY)


## Whatever a MusicStep changed is put back even when the scene is abandoned --
## a quit to the title frees the player mid-scene.
func _exit_tree() -> void:
	if _music != null:
		_music.restore()


## Starts `scene`. `context` answers the lines' conditions, `provider` names
## and draws their speakers, `settings` sets the reading pace and names the
## host's music.
func play(
	scene: CutsceneDefinition,
	context: ShantyContext,
	provider: ShantySpeakerProvider,
	settings: ShantyViewSettings
) -> void:
	_replay = null
	_start(scene, context, provider, settings)


## Plays `scene` again read-only, answering each reply from `record`; at a line
## the record has no answer for, the dialogue stops and the scene's remaining
## other steps play out. Ends on `replay_finished`, never `finished`, and nothing
## it collects is returned.
func play_replay(
	scene: CutsceneDefinition,
	record: PlayedSceneRecord,
	context: ShantyContext,
	provider: ShantySpeakerProvider,
	settings: ShantyViewSettings
) -> void:
	_replay = record if record != null else PlayedSceneRecord.new()
	_start(scene, context, provider, settings)


func is_running() -> bool:
	return _running


func is_replay() -> bool:
	return _replay != null


## Ends a replay where it stands, as if it had reached its end: `replay_finished`
## and nothing else. Refused for a first playing, which only its own end -- or
## its host leaving -- may close.
func stop_replay() -> void:
	if _replay == null or not _running:
		return
	# A step still running completes into a generation that no longer exists.
	_step_generation += 1
	_view.clear()
	_view.hide()
	_finish()


## The dialogue bar, for a host that needs to measure it or a harness that
## needs to press one of its replies.
func dialogue_view() -> DialogueView:
	return _view


## The still, for a host that measures it and for tests of a pan.
func backdrop() -> ShantyBackdrop:
	return _backdrop


## What MusicSteps changed, restored when the scene ends.
func music() -> ShantyMusic:
	if _music == null:
		_music = ShantyMusic.new(self, _settings)
	return _music


## Jumps every remaining step to its end state. Choices still owed are still
## asked; everything a skipped line would have returned is still returned.
func skip() -> void:
	if not _can_skip() or _skipping:
		return
	_skipping = true
	_say.skipping = true
	if _step_in_progress:
		_scene.steps[_step_index].skip_to_end(self)


# --- Primitives the steps call -----------------------------------------------


func show_backdrop(texture: Texture2D, letterbox: bool) -> void:
	_ground.visible = true
	_dim.visible = false
	_backdrop.show_still(texture)
	_letterbox_top.visible = letterbox
	_letterbox_bottom.visible = letterbox
	_layout_frame()


## Slides the still (art pixels from centre), then calls `on_done`. Reduced
## motion lands on `to` at once.
func pan_backdrop(from: Vector2i, to: Vector2i, seconds: float, on_done: Callable) -> void:
	_backdrop.pan(from, to, seconds, _settings.reduced_motion, on_done)


## Fades to (or in from) the ground colour, then calls `on_done`. A fade in
## starts from the ground colour, so a scene can open on it.
func fade(to_black: bool, duration: float, on_done: Callable) -> void:
	if _fade_tween != null:
		_fade_tween.kill()
		_fade_tween = null
	var target: float = 1.0 if to_black else 0.0
	if duration <= 0.0 or _settings.reduced_motion:
		_fade_rect.modulate.a = target
		on_done.call()
		return
	if not to_black:
		_fade_rect.modulate.a = 1.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_rect, ^"modulate:a", target, duration)
	_fade_tween.finished.connect(on_done, CONNECT_ONE_SHOT)


## Holds for `seconds`, then calls `on_done`. A tap ends it early when
## `interruptible`.
func wait(seconds: float, interruptible: bool, on_done: Callable) -> void:
	_press.wait(seconds, interruptible, on_done)


## Ends the wait in progress, if any, calling what it was owed.
func end_wait() -> void:
	_press.end_wait()


func say(conversation: ConversationDefinition, on_done: Callable) -> void:
	_say.say(conversation, on_done)


func skip_say(conversation: ConversationDefinition, on_done: Callable) -> void:
	_say.skip_say(conversation, on_done)


# --- Steps --------------------------------------------------------------------


func _start(
	scene: CutsceneDefinition,
	context: ShantyContext,
	provider: ShantySpeakerProvider,
	settings: ShantyViewSettings
) -> void:
	_scene = scene
	_context = context if context != null else ShantyContext.new()
	_settings = settings if settings != null else ShantyViewSettings.new()
	_music = null
	_view.configure(provider, _settings)
	_skipping = false
	_step_index = -1
	if _say != null:
		_say.detach()
	_say = ShantySay.new(_view, _context, _replay)
	_reading_again.text = tr(READING_AGAIN_KEY)
	_reading_again.visible = _replay != null
	if scene == null or not scene.is_playable():
		push_error("CutscenePlayer: refusing a scene with a step this version does not build.")
		_finish_refused()
		return
	_running = true
	_dim.visible = true
	_press.listening = true
	_press.hold_enabled = _can_skip()
	_skip_hold.visible = _can_skip()
	_skip_hold.set_progress(0.0)
	_advance_step()


func _advance_step() -> void:
	_step_index += 1
	_step_generation += 1
	_step_in_progress = false
	if _step_index >= _scene.steps.size():
		_finish()
		return
	var step: CutsceneStep = _scene.steps[_step_index]
	if step == null:
		_advance_step.call_deferred()
		return
	_step_in_progress = true
	step.completed.connect(_on_step_completed.bind(_step_generation), CONNECT_ONE_SHOT)
	if _skipping:
		step.skip_to_end(self)
	else:
		step.begin(self)


## Deferred, so a step that completes inside `begin()` does not recurse into
## the next one, and a stale completion from an interrupted step is dropped.
func _on_step_completed(generation: int) -> void:
	if generation != _step_generation or not _running:
		return
	_step_in_progress = false
	_advance_step.call_deferred()


func _finish() -> void:
	_running = false
	_press.listening = false
	_press.cancel()
	_skip_hold.hide()
	_reading_again.hide()
	if _music != null:
		_music.restore()
	if _replay != null:
		replay_finished.emit()
		return
	var played: PlayedSceneRecord = _say.record(_scene.scene_id, _context.playthrough_ordinal())
	played.snapshot_scene(_scene)
	finished.emit(played, _say.effects.duplicate())


func _finish_refused() -> void:
	_running = false
	if _replay != null:
		replay_finished.emit()
		return
	var effects: Array[ShantyEffect] = []
	finished.emit(PlayedSceneRecord.new(), effects)


func _can_skip() -> bool:
	return _running and _scene != null and _scene.skippable


# --- Input --------------------------------------------------------------------


func _on_shield_input(event: InputEvent) -> void:
	if _press.handle_pointer(event):
		_shield.accept_event()


## A tap finishes the line or goes on; with no bar up it ends a wait that may be
## cut short.
func _on_tapped() -> void:
	if _view.visible:
		_view.handle_tap()
	else:
		_press.end_interruptible_wait()


# --- Layout -------------------------------------------------------------------


## The ground colour the frame draws in: the host theme's, or black.
func ground_colour() -> Color:
	if _ground.has_theme_color(GROUND_COLOR, FRAME_VARIATION):
		return _ground.get_theme_color(GROUND_COLOR, FRAME_VARIATION)
	return DEFAULT_GROUND


func _apply_ground_colour() -> void:
	var ground: Color = Color(ground_colour(), 1.0)
	_ground.color = ground
	_letterbox_top.color = ground
	_letterbox_bottom.color = ground
	_fade_rect.color = ground
	_dim.color = Color(ground, DIM_ALPHA)


func _layout_frame() -> void:
	if _backdrop == null:
		return
	var frame: Vector2 = get_viewport().get_visible_rect().size
	_letterbox_top.size = Vector2(frame.x, letterbox_height)
	_letterbox_top.position = Vector2.ZERO
	_letterbox_bottom.size = Vector2(frame.x, letterbox_height)
	_letterbox_bottom.position = Vector2(0.0, frame.y - letterbox_height)
	_backdrop.layout(frame)
