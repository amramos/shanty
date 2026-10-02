class_name ShantySelector
extends RefCounted

## Chooses which scene, if any, a trigger plays. Pure: given the trigger's
## authored candidates, the host's context and the records of what has already
## finished, it returns one candidate or null, and touches nothing.
##
## **The rule, in full:** a candidate qualifies when it carries a scene, every
## one of its conditions holds, and -- when it is authored `once` -- no played
## record names its scene. Of those, the highest `priority` wins, and a tie goes
## to the candidate authored first. Nothing qualifying is null, which a host
## reads as "this boundary has nothing to say".


## The candidate `trigger` should play, or null. `played` is every record the
## host has persisted; only their scene ids are read.
static func select(
	trigger: StoryTriggerDefinition, context: ShantyContext, played: Array[PlayedSceneRecord]
) -> StoryCandidate:
	if trigger == null:
		return null
	var holding: ShantyContext = context if context != null else ShantyContext.new()
	var played_ids: Dictionary[StringName, bool] = {}
	for record: PlayedSceneRecord in played:
		if record != null:
			played_ids[record.scene_id] = true
	var chosen: StoryCandidate = null
	for candidate: StoryCandidate in trigger.candidates:
		if not qualifies(candidate, holding, played_ids):
			continue
		# Strictly greater, so the first of equal priorities keeps the place.
		if chosen == null or candidate.priority > chosen.priority:
			chosen = candidate
	return chosen


## Whether `candidate` may play now. Public so a host's tooling can explain why
## a scene did not show.
static func qualifies(
	candidate: StoryCandidate, context: ShantyContext, played_ids: Dictionary[StringName, bool]
) -> bool:
	if candidate == null or candidate.cutscene == null:
		return false
	if candidate.once and played_ids.has(candidate.cutscene.scene_id):
		return false
	return ShantyCondition.all_hold(candidate.conditions, context)


## True when `trigger` authors any candidate at all -- the question a host asks
## before deciding a boundary needs waiting for.
static func has_candidates(trigger: StoryTriggerDefinition) -> bool:
	if trigger == null:
		return false
	for candidate: StoryCandidate in trigger.candidates:
		if candidate != null and candidate.cutscene != null:
			return true
	return false
