@tool
class_name ShantyProjectConfig
extends Resource

## A host's settings for the Shanty tab and its lint, found through the project
## setting `shanty/config_path`. It names no locale list: the CSV header is
## that list, and adding a column adds a language.

## The project setting that names this resource.
const SETTING: String = "shanty/config_path"

## The translation CSV every key lives in.
@export_file("*.csv") var csv_path: String = ""
## Locales the host requires filled. A host rule for the host's own tests:
## Shanty only reports coverage and never refuses a save for a gap.
@export var required_locales: PackedStringArray = []
## The working locale a session opens on, when the CSV has that column.
@export var source_locale: String = "en"
## The flags the tab offers as toggles, each with its forbidden words.
@export var flags: Array[ShantyFlagRule] = []
## How new keys are named. Null uses the defaults.
@export var key_scheme: ShantyKeyScheme = null
@export_dir var speakers_folder: String = ""
@export_dir var conversations_folder: String = ""
@export_dir var scenes_folder: String = ""
@export_dir var triggers_folder: String = ""
## The moments a trigger may name. Empty allows any id.
@export var trigger_ids: PackedStringArray = []
## The theme the preview draws with.
@export_file("*.tres", "*.theme") var theme_path: String = ""
## Characters a line may run to before the lint warns. 0 is no cap.
@export var length_cap: int = 0
## The host's preview script, used by the preview pane.
@export_file("*.gd") var preview_host_path: String = ""


## The key scheme in force: the authored one, or the defaults.
func scheme() -> ShantyKeyScheme:
	return key_scheme if key_scheme != null else ShantyKeyScheme.new()


## Every flag name, in authored order, empty names and duplicates left out.
func flag_names() -> PackedStringArray:
	var names: PackedStringArray = []
	for rule: ShantyFlagRule in flags:
		if rule != null and not rule.flag.is_empty() and not names.has(rule.flag):
			names.append(rule.flag)
	return names


## The rule for `flag`, or null when the config names no such flag.
func rule_for(flag: String) -> ShantyFlagRule:
	for rule: ShantyFlagRule in flags:
		if rule != null and rule.flag == flag:
			return rule
	return null


## Every folder the tab lists, in pane order, empty ones left out.
func content_folders() -> PackedStringArray:
	var folders: PackedStringArray = []
	for folder: String in [speakers_folder, conversations_folder, scenes_folder, triggers_folder]:
		if not folder.is_empty() and not folders.has(folder):
			folders.append(folder)
	return folders
