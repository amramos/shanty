extends ShantyPreviewHost

## What the Shanty tab's Play asks of the example: its own context, with the
## flag its first line is gated on, its own speakers with their placeholder
## faces, and its own strings -- which this project registers nowhere, so Play
## adds them while it plays. `shanty_config.tres` names this script as its
## `preview_host_path`. Like every example script it declares no `class_name`.

const ExampleContext := preload("res://addons/shanty/example/example_context.gd")
const ExampleSpeakerProvider := preload("res://addons/shanty/example/example_speaker_provider.gd")
const ExampleHost := preload("res://addons/shanty/example/example_host.gd")


func make_context() -> ShantyContext:
	var context: ExampleContext = ExampleContext.new()
	context.set_flag(ExampleHost.STARTING_FLAG, true)
	return context


func make_speaker_provider() -> ShantySpeakerProvider:
	return ExampleSpeakerProvider.new()


func make_translations() -> Array[Translation]:
	return ExampleHost.load_translations(ExampleHost.STRINGS_PATH)
