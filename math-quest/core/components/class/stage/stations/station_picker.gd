extends RefCounted
class_name StationPicker

# =====================================================================
#  Chooses where Matthew works for a question.
#  Order: question "station" -> lesson "station" -> visual type ->
#         answer type -> words / operators in the text -> cauldron.
#  Stations: potion | circle | scale | clock | rune_lock | puzzle | counting | shapes
# =====================================================================

const STATIONS := ["potion", "circle", "scale", "clock", "rune_lock", "puzzle", "counting", "shapes"]

const COMPARE_WORDS := ["greater", "less", "more than", "fewer", "equal", "compare", "heavier", "lighter", "which side", "bigger", "smaller"]
const GROUP_WORDS := ["times", "divided", "groups of", "each", "per ", "multiply", "share", "split", "rows of", "bags of", "packs of"]


static func pick(lesson: Dictionary, q: Dictionary, input_type: String) -> String:
	for source in [q, lesson]:
		var forced := str(source.get("station", ""))
		if forced in STATIONS:
			return forced

	var v = q.get("visual", {})
	var visual := str(v.get("type", "")) if typeof(v) == TYPE_DICTIONARY else ""
	match visual:
		"balance":
			return "scale"
		"grid":
			return "counting"
		"shapes":
			return "shapes"
		"clock":
			return "clock"
		"groups":
			# Bundles are shown as bundles on the counting table (tap to add up)
			return "counting"
		"shape_match", "block_stack", "connect_dots":
			return "puzzle"

	match input_type:
		"time":
			return "clock"
		"list":
			return "rune_lock"
		"puzzle":
			return "puzzle"

	var text := str(q.get("text", "")).to_lower()
	var seq := ""
	if visual == "sequence":
		for token in v.get("sequence", []):
			seq += " " + str(token)
	if text.contains("hour hand") or text.contains("clock"):
		return "clock"
	if seq.contains("(") or text.contains("pmdas") or text.contains("mdas"):
		return "rune_lock"
	if seq.contains(" x") or seq.contains("×") or seq.contains("÷") or _has_any(text, GROUP_WORDS) \
			or RegEx.create_from_string("\\d\\s*[x×÷]\\s*\\d").search(text):
		return "circle"
	if input_type == "choice" and _has_any(text, COMPARE_WORDS):
		return "scale"
	return "potion"


static func _has_any(text: String, words: Array) -> bool:
	for w in words:
		if text.contains(w):
			return true
	return false
