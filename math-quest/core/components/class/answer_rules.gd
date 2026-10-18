extends RefCounted
class_name AnswerRules

# =====================================================================
#  Decides HOW a question is answered and checks the player's answer.
#
#  Input types:
#     number    whole numbers                      -> number pad
#     fraction  "3/4"                              -> fraction pad
#     time      "10:55"                            -> clock hands / time pad
#     list      "2, 4, 5, 8"                       -> drag tiles into order
#     choice    words / symbols ("greater than")   -> tokens
#     puzzle    shape_match / block_stack / connect_dots (solved on stage)
#
#  A question may force one with "input": "<type>".
# =====================================================================

const TYPES := ["number", "fraction", "time", "list", "choice", "puzzle"]
const PUZZLE_VISUALS := ["shape_match", "block_stack", "connect_dots"]

static var _re_int := RegEx.create_from_string("^-?\\d+$")
static var _re_fraction := RegEx.create_from_string("^\\d+\\s*/\\s*\\d+$")
static var _re_time := RegEx.create_from_string("^\\d{1,2}\\s*:\\s*\\d{2}$")
static var _re_list := RegEx.create_from_string("^-?\\d+(\\s*,\\s*-?\\d+)+$")


static func detect(q: Dictionary) -> String:
	var forced := str(q.get("input", ""))
	if forced in TYPES:
		return forced
	var visual = q.get("visual", null)
	if typeof(visual) == TYPE_DICTIONARY and str(visual.get("type", "")) in PUZZLE_VISUALS:
		return "puzzle"
	return detect_answer(str(q.get("answer", "")))


static func detect_answer(answer: String) -> String:
	var a := answer.strip_edges()
	if _re_int.search(a):
		return "number"
	if _re_fraction.search(a):
		return "fraction"
	if _re_time.search(a):
		return "time"
	if _re_list.search(a):
		return "list"
	return "choice"


## Normalized form used for comparing; also what gets recorded/displayed.
static func normalize(value: String, input_type: String) -> String:
	var v := value.strip_edges()
	match input_type:
		"number":
			return str(v.to_int()) if _re_int.search(v) else v
		"fraction":
			var parts := v.replace(" ", "").split("/")
			if parts.size() == 2:
				return "%d/%d" % [parts[0].to_int(), parts[1].to_int()]
			return v
		"time":
			var t := v.replace(" ", "").split(":")
			if t.size() == 2:
				return "%d:%02d" % [t[0].to_int(), t[1].to_int()]
			return v
		"list":
			var out := PackedStringArray()
			for p in v.split(","):
				if p.strip_edges() != "":
					out.append(str(p.strip_edges().to_int()))
			return ", ".join(out)
	return v.to_lower()


static func matches(given: String, expected: String, input_type: String) -> bool:
	if given.strip_edges() == "":
		return false
	return normalize(given, input_type) == normalize(expected, input_type)
