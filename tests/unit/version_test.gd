extends GutTest

## One version, said once in each place a reader looks: `plugin.cfg` (what the
## editor and a vendoring host read) and the topmost section of the changelog.
## CI holds a pushed tag `vX.Y.Z` to the same number.

const PLUGIN_CFG: String = "res://addons/shanty/plugin.cfg"
const CHANGELOG: String = "res://addons/shanty/CHANGELOG.md"
const SEMVER_PATTERN: String = "^\\d+\\.\\d+\\.\\d+$"


func _plugin_version() -> String:
	var config := ConfigFile.new()
	assert_eq(config.load(PLUGIN_CFG), OK, "plugin.cfg loads")
	return String(config.get_value("plugin", "version", ""))


## The version the changelog's first `## ` heading names, its brackets removed.
static func _changelog_version(text: String) -> String:
	for line: String in text.split("\n"):
		if line.begins_with("## "):
			var heading: String = line.substr(3).strip_edges()
			return heading.get_slice(" ", 0).trim_prefix("[").trim_suffix("]")
	return ""


func test_the_plugin_version_is_semantic() -> void:
	var semver := RegEx.create_from_string(SEMVER_PATTERN)

	assert_not_null(semver.search(_plugin_version()), "X.Y.Z, nothing else")


func test_the_topmost_changelog_section_is_the_plugin_version() -> void:
	var text: String = FileAccess.get_file_as_string(CHANGELOG)

	assert_eq(_changelog_version(text), _plugin_version())


func test_the_changelog_heading_reader() -> void:
	assert_eq(_changelog_version("# Changelog\n\n## 1.2.3\n\n## 1.2.2\n"), "1.2.3")
	assert_eq(_changelog_version("## [0.4.0] - 2026-01-01\n"), "0.4.0")
	assert_eq(_changelog_version("# Changelog\n"), "")
