class_name ShantyPressInput
extends Node

## The one press a scene answers to, which is both "go on" (released quickly, a
## tap) and "skip the scene" (held). Accept from the keyboard or a controller
## arrives through `_unhandled_input`; the mouse through the player's input
## shield, which forwards its events to `handle_pointer()`. Purely timing: what
## a tap or a hold *means* is CutscenePlayer's, told through the two signals.
##
## It also times a scene's waits (`wait()`), since the one thing that may cut a
## wait short is a tap. The timers are paused with the tree, so a pause menu
## freezes a wait rather than letting it run out underneath.

## Released before the hold completed.
signal tapped
## Held for `hold_seconds`. Emitted once; the release that follows is no tap.
signal held

## Seconds the press must be held to count as a hold.
var hold_seconds: float = 0.8
## Off while no scene runs: every press is ignored.
var listening: bool = false
## Off for a scene authored unskippable: a long press is still only a tap.
var hold_enabled: bool = false
## Asked before a keyboard press may begin; false while something else owns
## accept (a focused reply button, whose own press would otherwise outlive the
## choice and land as a tap on the line it leads to).
var may_begin: Callable = Callable()
## Shows the hold filling. Optional.
var skip_bar: SkipHold = null

var _pressing: bool = false
var _seconds: float = 0.0
var _wait_done: Callable = Callable()
var _wait_interruptible: bool = false
## Bumped per wait, so a timer outliving the wait it was started for ends nothing.
var _wait_generation: int = 0


func _process(delta: float) -> void:
	if not _pressing or not listening or not hold_enabled:
		return
	_seconds += delta
	_show_progress(_seconds / hold_seconds)
	if _seconds >= hold_seconds:
		_pressing = false
		_show_progress(0.0)
		held.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not listening or not event.is_action(&"ui_accept") or event.is_echo():
		return
	if event.is_pressed():
		if not may_begin.is_valid() or may_begin.call():
			press()
	else:
		release()
	get_viewport().set_input_as_handled()


## The shield's own clicks. True when the event was a left button this took.
func handle_pointer(event: InputEvent) -> bool:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or not listening:
		return false
	if button.pressed:
		press()
	else:
		release()
	return true


func press() -> void:
	_pressing = true
	_seconds = 0.0


## A release before the hold completed is a tap.
func release() -> void:
	if not _pressing:
		return
	_pressing = false
	_show_progress(0.0)
	tapped.emit()


## Forgets a press in progress without reporting it.
func cancel() -> void:
	_pressing = false
	_show_progress(0.0)


## Holds for `seconds`, then calls `on_done`. `interruptible` lets
## `end_interruptible_wait()` -- a tap -- end it early.
func wait(seconds: float, interruptible: bool, on_done: Callable) -> void:
	_wait_generation += 1
	_wait_done = on_done
	_wait_interruptible = interruptible
	if seconds <= 0.0:
		end_wait()
		return
	var timer: SceneTreeTimer = get_tree().create_timer(seconds, false)
	timer.timeout.connect(_on_wait_timeout.bind(_wait_generation))


## Ends the wait in progress, if any, calling what it was owed.
func end_wait() -> void:
	var done: Callable = _wait_done
	_wait_done = Callable()
	if done.is_valid():
		done.call()


## A tap with no line to answer it: ends the wait in progress if it may be cut
## short.
func end_interruptible_wait() -> void:
	if _wait_interruptible and _wait_done.is_valid():
		end_wait()


func _on_wait_timeout(generation: int) -> void:
	if generation == _wait_generation:
		end_wait()


func _show_progress(ratio: float) -> void:
	if skip_bar != null:
		skip_bar.set_progress(ratio)
