@tool
class_name ShantySaveResult
extends RefCounted

## What one Save did, or why it wrote nothing. A refused save writes no file
## at all: lint errors and stale files are found before the first write.

var saved: bool = false
## One sentence for the tab's status line.
var message: String = ""
## The lint findings at the time of saving; errors among them refused it.
var issues: Array[ShantyLintIssue] = []
## Files that changed on disk since they were read, which refused the save.
var stale_paths: PackedStringArray = []
## The CSV, when it was written; the editor reimports it.
var csv_path: String = ""
## Every resource written; the editor updates each in its filesystem.
var resource_paths: PackedStringArray = []


static func refused(reason: String) -> ShantySaveResult:
	var result := ShantySaveResult.new()
	result.message = reason
	return result
