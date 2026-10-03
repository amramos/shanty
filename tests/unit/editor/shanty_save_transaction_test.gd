extends GutTest

## ShantySaveTransaction writes all or nothing: every output is staged before
## any target is touched, and a failure while committing puts back every
## target it already replaced, byte for byte.

const ROOT: String = "user://shanty_transaction_probe"
const CSV_PATH: String = ROOT + "/strings.csv"
const FIRST_PATH: String = ROOT + "/first.tres"
const SECOND_PATH: String = ROOT + "/second.tres"
const ORIGINAL_CSV: String = "keys,en\r\nA,x\r\n"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT)
	ShantyFiles.write_text(CSV_PATH, ORIGINAL_CSV)
	ResourceSaver.save(_speaker(&"first"), FIRST_PATH)
	ResourceSaver.save(_speaker(&"second"), SECOND_PATH)


func after_each() -> void:
	for file: String in DirAccess.get_files_at(ROOT):
		DirAccess.remove_absolute(ROOT.path_join(file))
	DirAccess.remove_absolute(ROOT)


static func _speaker(id: StringName) -> SpeakerDefinition:
	var speaker := SpeakerDefinition.new()
	speaker.speaker_id = id
	return speaker


func _stage_all(transaction: ShantySaveTransaction) -> bool:
	return (
		transaction.stage_text(CSV_PATH, "keys,en\r\nA,changed\r\n")
		and transaction.stage_resource(_speaker(&"first_changed"), FIRST_PATH)
		and transaction.stage_resource(_speaker(&"second_changed"), SECOND_PATH)
	)


func _staged_files_left() -> PackedStringArray:
	var left: PackedStringArray = []
	for file: String in DirAccess.get_files_at(ROOT):
		if file.contains(ShantyFiles.STAGING_MARK):
			left.append(file)
	return left


func test_a_commit_writes_every_target_and_leaves_no_staged_file() -> void:
	var transaction := ShantySaveTransaction.new()

	assert_true(_stage_all(transaction))
	assert_eq(ShantyFiles.read_text(CSV_PATH), ORIGINAL_CSV, "staging touches no target")
	assert_true(transaction.commit(), transaction.failure)
	transaction.discard()

	assert_eq(ShantyFiles.read_text(CSV_PATH), "keys,en\r\nA,changed\r\n")
	assert_string_contains(ShantyFiles.read_text(FIRST_PATH), "first_changed")
	assert_string_contains(ShantyFiles.read_text(SECOND_PATH), "second_changed")
	assert_eq(_staged_files_left(), PackedStringArray())


func test_a_failed_commit_puts_back_every_target_it_replaced() -> void:
	var before: Array[PackedByteArray] = [
		ShantyFiles.read_bytes(CSV_PATH),
		ShantyFiles.read_bytes(FIRST_PATH),
		ShantyFiles.read_bytes(SECOND_PATH),
	]
	var transaction := ShantySaveTransaction.new()
	var calls: Array[int] = [0]
	transaction.replace_file = func(staged: String, target: String) -> Error:
		calls[0] += 1
		if calls[0] == 3:
			return ERR_FILE_CANT_WRITE
		return ShantyFiles.replace(staged, target)

	assert_true(_stage_all(transaction))
	assert_false(transaction.commit(), "the third replace fails")
	transaction.discard()

	assert_eq(calls[0], 3, "the CSV and the first resource were replaced first")
	assert_string_contains(transaction.failure, "second.tres")
	assert_eq(ShantyFiles.read_bytes(CSV_PATH), before[0], "the CSV is back, byte for byte")
	assert_eq(ShantyFiles.read_bytes(FIRST_PATH), before[1], "so is the first resource")
	assert_eq(ShantyFiles.read_bytes(SECOND_PATH), before[2])
	assert_eq(_staged_files_left(), PackedStringArray())


func test_a_failed_commit_removes_a_file_that_did_not_exist() -> void:
	var fresh: String = ROOT + "/fresh.tres"
	var transaction := ShantySaveTransaction.new()
	transaction.replace_file = func(staged: String, target: String) -> Error:
		if target == CSV_PATH:
			return ERR_FILE_CANT_WRITE
		return ShantyFiles.replace(staged, target)

	assert_true(transaction.stage_resource(_speaker(&"fresh"), fresh))
	assert_true(transaction.stage_text(CSV_PATH, "keys,en\n"))
	assert_false(transaction.commit())
	transaction.discard()

	assert_false(FileAccess.file_exists(fresh), "a file the save made is gone again")
	assert_eq(ShantyFiles.read_text(CSV_PATH), ORIGINAL_CSV)
	assert_eq(_staged_files_left(), PackedStringArray())


func test_a_failed_stage_touches_no_target() -> void:
	var transaction := ShantySaveTransaction.new()

	assert_true(transaction.stage_text(CSV_PATH, "keys,en\nA,changed\n"))
	assert_false(
		transaction.stage_resource(_speaker(&"lost"), ROOT + "/missing/folder/lost.tres"),
		"a folder that does not exist cannot be written"
	)
	assert_engine_error("ERR_CANT_OPEN", "the saver reports the folder it could not open")
	transaction.discard()

	assert_eq(ShantyFiles.read_text(CSV_PATH), ORIGINAL_CSV)
	assert_eq(_staged_files_left(), PackedStringArray())


func test_staging_paths_keep_a_resource_extension_and_hide_a_csv() -> void:
	assert_eq(
		ShantyFiles.resource_staging_path("res://a/talk.tres"), "res://a/talk.shanty-tmp.tres"
	)
	assert_eq(
		ShantyFiles.text_staging_path("res://a/strings.csv"), "res://a/strings.csv.shanty-tmp"
	)


func test_a_claimed_path_is_kept_by_a_commit_and_taken_back_by_a_failure() -> void:
	var kept := _speaker(&"kept")
	var transaction := ShantySaveTransaction.new()
	transaction.claim_paths({kept: ROOT + "/kept.tres"} as Dictionary[Resource, String])
	assert_eq(kept.resource_path, ROOT + "/kept.tres", "named before anything is staged")
	assert_true(transaction.stage_resource(kept, ROOT + "/kept.tres"))
	assert_true(transaction.commit())
	transaction.discard()
	assert_eq(kept.resource_path, ROOT + "/kept.tres")

	var lost := _speaker(&"lost")
	var failing := ShantySaveTransaction.new()
	failing.replace_file = func(_staged: String, _target: String) -> Error: return FAILED
	failing.claim_paths({lost: ROOT + "/lost.tres"} as Dictionary[Resource, String])
	assert_true(failing.stage_resource(lost, ROOT + "/lost.tres"))
	assert_false(failing.commit())
	failing.discard()
	assert_eq(lost.resource_path, "", "a failed save names nothing")


func test_two_resources_never_claim_one_file() -> void:
	var first := _speaker(&"lamp")
	var second := _speaker(&"lamp_too")
	var transaction := ShantySaveTransaction.new()
	var paths: Dictionary[Resource, String] = {
		first: ROOT + "/lamp.tres", second: ROOT + "/lamp.tres"
	}

	assert_false(transaction.claim_paths(paths))
	assert_string_contains(transaction.failure, ROOT + "/lamp.tres")
	assert_eq(first.resource_path, "", "nothing is claimed")
	assert_eq(second.resource_path, "")
