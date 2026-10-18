extends RefCounted
class_name AnswerExplainer

# =====================================================================
#  Builds the short "why" shown (and read aloud) after a wrong answer.
#
#  A question may carry its own text: "explanation": "..."  (always wins)
#  Otherwise it is worked out from the question, and only used when the
#  working actually reaches the stored answer:
#     expressions   "(5 + 3) x 4"  -> PMDAS steps
#     word problems two numbers + keywords -> "45 + 20 = 65"
#     clocks        hour/minute hands, elapsed time
#     fractions, ordering lists, comparing
#  Anything else falls back to "The correct answer is X."
# =====================================================================

const ADD_WORDS := ["more", "in all", "total", "altogether", "together", "sum", "plus", "gives him", "gives her", "added", "add "]
const SUB_WORDS := ["left", "remain", "gave away", "sold", "fewer", "difference", "less", "minus", "take away", "spent", "ate", "lost"]
const MUL_WORDS := ["each", "groups of", "times", "rows", "every", "per "]
const DIV_WORDS := ["share", "equally", "divided", "split", "each get", "each one get", "how many groups"]
const OP_SYMBOLS := {"x": "x", "×": "x", "*": "x", "÷": "÷", "/": "÷", "+": "+", "-": "-"}

static var _re_expr := RegEx.create_from_string("[\\d(][\\d\\s()+\\-x×÷*/]*[\\d)]")
static var _re_num := RegEx.create_from_string("\\d+")
static var _re_time := RegEx.create_from_string("(\\d{1,2}):(\\d{2})")


static func explain(q: Dictionary, input_type: String) -> String:
	var custom := str(q.get("explanation", "")).strip_edges()
	if custom != "":
		return custom
	var answer := str(q.get("answer", "")).strip_edges()
	var text := str(q.get("text", ""))
	var why := ""
	match input_type:
		"time":
			why = _explain_time(q, answer)
		"fraction":
			why = _explain_fraction(answer)
		"list":
			why = _explain_list(text, answer)
		"number":
			why = _explain_groups(q, answer)
			if why == "":
				why = _explain_expression(q, answer)
			if why == "":
				why = _explain_word_problem(text, answer)
		"choice":
			why = _explain_compare(q, answer)
	return why


## Turns math symbols into words so text-to-speech reads them well.
static func to_speech(text: String) -> String:
	var t := text
	t = t.replace("÷", " divided by ").replace(" x ", " times ").replace("×", " times ")
	t = t.replace(" - ", " minus ").replace(" + ", " plus ").replace(" = ", " equals ")
	var re := RegEx.create_from_string("(\\d+)/(\\d+)")
	t = re.sub(t, "$1 over $2", true)
	return t


# ----------------------------------------------------------- expressions --

static func _explain_expression(q: Dictionary, answer: String) -> String:
	for expr in _candidate_expressions(q):
		var tokens := _tokenize(expr)
		if tokens.is_empty():
			continue
		var steps : Array = []
		var value = _solve(tokens, steps)
		if value == null or steps.is_empty():
			continue
		if not answer.is_valid_float() or absf(float(value) - answer.to_float()) > 0.0001:
			continue
		if steps.size() == 1:
			return "%s." % steps[0]["text"]
		var parts := PackedStringArray()
		for i in range(steps.size()):
			var lead := "First" if i == 0 else ("Then" if i < steps.size() - 1 else "Last")
			parts.append("%s, %s: %s." % [lead, steps[i]["rule"], steps[i]["text"]])
		return " ".join(parts)
	return ""


static func _candidate_expressions(q: Dictionary) -> Array:
	var out : Array = []
	var v = q.get("visual", {})
	if typeof(v) == TYPE_DICTIONARY and str(v.get("type", "")) == "sequence":
		var parts := PackedStringArray()
		for token in v.get("sequence", []):
			var t := str(token)
			if t.contains("?") or t.contains("->") or t.contains(":"):
				continue
			parts.append(t.replace("=", "").strip_edges())
		out.append(" ".join(parts))
	for m in _re_expr.search_all(str(q.get("text", ""))):
		out.append(m.get_string())
	return out


## Numbers, operators and brackets; [] when it is not a clean expression.
static func _tokenize(expr: String) -> Array:
	var tokens : Array = []
	var num := ""
	for ch in expr:
		if ch.is_valid_int():
			num += ch
			continue
		if num != "":
			tokens.append(num.to_int())
			num = ""
		if ch == " ":
			continue
		if OP_SYMBOLS.has(ch):
			tokens.append(OP_SYMBOLS[ch])
		elif ch == "(" or ch == ")":
			tokens.append(ch)
		else:
			return []
	if num != "":
		tokens.append(num.to_int())
	# Must alternate number / operator, with at least one operator
	var ops := 0
	var expect_num := true
	for t in tokens:
		if t is String and (t == "(" or t == ")"):
			continue
		if expect_num != (t is int):
			return []
		if not (t is int):
			ops += 1
		expect_num = not expect_num
	return tokens if ops > 0 and not expect_num else []


## PMDAS: brackets first, then x and ÷ left to right, then + and -.
static func _solve(tokens: Array, steps: Array):
	var t := tokens.duplicate()
	while t.has("("):
		var open := t.rfind("(")
		var close := t.find(")", open)
		if close == -1:
			return null
		var inner = _solve_flat(t.slice(open + 1, close), steps, "do the parentheses")
		if inner == null:
			return null
		t = t.slice(0, open) + [inner] + t.slice(close + 1)
	return _solve_flat(t, steps, "")


static func _solve_flat(tokens: Array, steps: Array, rule_override: String):
	var t := tokens.duplicate()
	for pass_ops in [["x", "÷"], ["+", "-"]]:
		var i := 1
		while i < t.size():
			if t[i] is String and t[i] in pass_ops:
				var a = t[i - 1]
				var b = t[i + 1]
				var r
				match t[i]:
					"x": r = a * b
					"÷":
						if b == 0:
							return null
						r = a / b if a % b == 0 else float(a) / b
					"+": r = a + b
					"-": r = a - b
				var rule := rule_override
				if rule == "":
					rule = "multiply or divide" if t[i] in ["x", "÷"] else "add or subtract"
				steps.append({"rule": rule, "text": "%s %s %s = %s" % [_fmt(a), t[i], _fmt(b), _fmt(r)]})
				t = t.slice(0, i - 1) + [r] + t.slice(i + 2)
			else:
				i += 2
	return t[0] if t.size() == 1 else null


static func _fmt(v) -> String:
	if v is float and v != floor(v):
		return "%.2f" % v
	return str(int(v))


# ----------------------------------------------------------------- groups --

## "groups" pictures: add up uneven bundles, or multiply equal ones.
static func _explain_groups(q: Dictionary, answer: String) -> String:
	var v = q.get("visual", {})
	if typeof(v) != TYPE_DICTIONARY or str(v.get("type", "")) != "groups" or not answer.is_valid_int():
		return ""
	var bundles := VisualBuilder.read_bundles(v.get("groups", {}))
	if bundles.is_empty():
		return ""
	var sizes := PackedStringArray()
	var total := 0
	for b in bundles:
		sizes.append(str(b["count"]))
		total += int(b["count"])
	if total != answer.to_int():
		return ""
	if VisualBuilder.bundles_equal(bundles) and bundles.size() > 1:
		return "There are %d bundles of %s: %s = %d, or %d x %s = %d." % [bundles.size(), sizes[0], " + ".join(sizes), total, bundles.size(), sizes[0], total]
	return "Add up every bundle: %s = %d." % [" + ".join(sizes), total]


# ---------------------------------------------------------- word problems --

## Finds the operation a word problem needs: {"op", "a", "b", "r"}, or
## {"op": "sum", "nums": [...]} when every number is added; {} if unsure.
static func _solve_word_problem(text: String, answer: String) -> Dictionary:
	if not answer.is_valid_int():
		return {}
	var target := answer.to_int()
	var nums : Array = []
	for m in _re_num.search_all(text):
		var n := m.get_string().to_int()
		if not nums.has(n):
			nums.append(n)
	if nums.size() < 2:
		return {}
	var lower := text.to_lower()
	# Try the operation the wording points to first
	var order : Array = []
	if _has_any(lower, DIV_WORDS):
		order.append("÷")
	if _has_any(lower, MUL_WORDS):
		order.append("x")
	if _has_any(lower, SUB_WORDS):
		order.append("-")
	if _has_any(lower, ADD_WORDS):
		order.append("+")
	for op in ["+", "-", "x", "÷"]:
		if not order.has(op):
			order.append(op)
	for op in order:
		for i in range(nums.size()):
			for j in range(nums.size()):
				if i == j:
					continue
				var a : int = nums[i]
				var b : int = nums[j]
				var r := -999999
				match op:
					"+": r = a + b if i < j else -999999
					"-": r = a - b
					"x": r = a * b if i < j else -999999
					"÷": r = a / b if b != 0 and a % b == 0 else -999999
				if r == target:
					return {"op": op, "a": a, "b": b, "r": r}
	# Everything added up (e.g. three amounts)
	var total := 0
	for n in nums:
		total += n
	if total == target and nums.size() >= 3:
		return {"op": "sum", "nums": nums}
	return {}


static func _explain_word_problem(text: String, answer: String) -> String:
	var w := _solve_word_problem(text, answer)
	if w.is_empty():
		return ""
	if w["op"] == "sum":
		var parts := PackedStringArray()
		var total := 0
		for n in w["nums"]:
			parts.append(str(n))
			total += n
		return "Add them all up: %s = %d." % [" + ".join(parts), total]
	var phrases := {"+": "Put them together", "-": "Take away", "x": "Equal groups, so multiply", "÷": "Share equally, so divide"}
	return "%s: %d %s %d = %d." % [phrases[w["op"]], w["a"], w["op"], w["b"], w["r"]]


static func _has_any(text: String, words: Array) -> bool:
	for w in words:
		if text.contains(w):
			return true
	return false


# ------------------------------------------------------------------ time --

static func _explain_time(q: Dictionary, answer: String) -> String:
	var v = q.get("visual", {})
	if typeof(v) == TYPE_DICTIONARY and str(v.get("type", "")) == "sequence":
		var hour := -1
		var steps := -1
		for token in v.get("sequence", []):
			var t := str(token)
			var hm := RegEx.create_from_string("hour:\\s*(\\d+)").search(t)
			if hm:
				hour = hm.get_string(1).to_int()
			var mm := RegEx.create_from_string("minute:\\s*(\\d+)\\s*x\\s*5").search(t)
			if mm:
				steps = mm.get_string(1).to_int()
		if hour >= 0 and steps >= 0:
			return "The short hand is just past %d, so the hour is %d. The long hand points to %d, and each number is 5 minutes: %d x 5 = %d. So the time is %s." % [hour, hour, steps, steps, steps * 5, answer]
	var start := _re_time.search(str(q.get("text", "")))
	var end := _re_time.search(answer)
	if start and end:
		var a := start.get_string(1).to_int() * 60 + start.get_string(2).to_int()
		var b := end.get_string(1).to_int() * 60 + end.get_string(2).to_int()
		var diff := posmod(b - a, 12 * 60)
		if diff > 0:
			return "Start at %s and move the clock forward %s. You land on %s." % [start.get_string(), _duration(diff), answer]
	return ""


static func _duration(minutes: int) -> String:
	var h := minutes / 60
	var m := minutes % 60
	var parts := PackedStringArray()
	if h > 0:
		parts.append("%d hour%s" % [h, "" if h == 1 else "s"])
	if m > 0:
		parts.append("%d minute%s" % [m, "" if m == 1 else "s"])
	return " and ".join(parts)


# ------------------------------------------------------- fraction / list --

static func _explain_fraction(answer: String) -> String:
	var parts := answer.replace(" ", "").split("/")
	if parts.size() != 2:
		return ""
	return "The bottom number is how many equal parts there are (%s). The top number is how many of those parts we have (%s). So it is %s." % [parts[1], parts[0], answer]


static func _explain_list(text: String, answer: String) -> String:
	var lower := text.to_lower()
	if _has_any(lower, ["descending", "greatest to least", "biggest to smallest", "highest to lowest", "backward"]):
		return "Go from the biggest number down to the smallest: %s." % answer
	if _has_any(lower, ["ascending", "least to greatest", "smallest to biggest", "lowest to highest", "counting order"]):
		return "Go from the smallest number up to the biggest: %s." % answer
	if _has_any(lower, ["next", "missing", "comes after", "fill in"]):
		return "Keep counting in the same pattern: %s." % answer
	return ""


static func _explain_compare(q: Dictionary, answer: String) -> String:
	var left := -1
	var right := -1
	# The question's own numbers win; the balance picture is the fallback
	# (some pictures hold different counts than the text describes).
	var nums : Array = []
	for m in _re_num.search_all(str(q.get("text", ""))):
		nums.append(m.get_string().to_int())
	var v = q.get("visual", {})
	if nums.size() == 2:
		left = nums[0]
		right = nums[1]
	elif typeof(v) == TYPE_DICTIONARY and str(v.get("type", "")) == "balance":
		left = int(v.get("leftItems", {}).get("count", -1))
		right = int(v.get("rightItems", {}).get("count", -1))
	if left < 0 or right < 0:
		return ""
	var relation := "equal to"
	if left > right:
		relation = "greater than"
	elif left < right:
		relation = "less than"
	# Only explain when the comparison really points at the stored answer;
	# numbers pulled from a word problem can mean something else
	# ("3 boxes" of 10 coins vs "5 coins").
	var a := answer.to_lower()
	var expected := ""
	if a == ">" or a.contains("greater") or a.contains("more") or a == "left":
		expected = "greater than"
	elif a == "<" or a.contains("less") or a.contains("fewer") or a == "right":
		expected = "less than"
	elif a == "=" or a.contains("equal") or a.contains("same"):
		expected = "equal to"
	if expected != relation:
		return ""
	return "%d is %s %d. So the answer is \"%s\"." % [left, relation, right, answer]


# ================================================================== hints --
#  A nudge toward the method, never the answer.  A question's own
#  "hint": "..." always wins.

static func hint(q: Dictionary, input_type: String) -> String:
	var custom := str(q.get("hint", "")).strip_edges()
	if custom != "":
		return custom
	var answer := str(q.get("answer", "")).strip_edges()
	var text := str(q.get("text", ""))
	var lower := text.to_lower()
	var v = q.get("visual", {})
	var visual := str(v.get("type", "")) if typeof(v) == TYPE_DICTIONARY else ""

	match visual:
		"grid":
			return "Tap each charm once and count out loud. The last number you say is how many there are!"
		"groups":
			var bundles := VisualBuilder.read_bundles(v.get("groups", {}))
			if VisualBuilder.bundles_equal(bundles) and bundles.size() > 1:
				var per := int(bundles[0]["count"])
				return "Count by %ds, one bundle at a time. Start at %d and keep going!" % [per, per]
			return "Tap each bundle and keep adding: the running total is your answer."
		"shapes":
			return "Tap each side to count it. A side is one straight edge of the shape."
		"balance":
			return "Look at both sides. Which one holds the bigger number?"

	match input_type:
		"time":
			var start := _re_time.search(text)
			if start:
				return "Start at %s on the clock and move it forward by the time in the question." % start.get_string()
			return "The short hand shows the hour. For the long hand, count by 5s for each number: 5, 10, 15..."
		"fraction":
			return "The bottom number is how many equal parts in all. The top number is how many parts we take."
		"list":
			if _has_any(lower, ["descending", "greatest to least", "biggest to smallest", "most", "highest to lowest", "backward"]):
				return "Find the BIGGEST number first, then the next biggest, and so on."
			if _has_any(lower, ["next", "missing", "comes after", "fill in"]):
				return "Look at how the numbers change each step, and keep the same pattern going."
			return "Find the SMALLEST number first, then the next smallest, and so on."
		"choice":
			if _has_any(lower, ["greater", "less", "more", "fewer", "equal", "bigger", "smaller", "heavier", "lighter"]):
				return "Find the two amounts in the question, then ask: which number is bigger?"
		"number":
			var step := _first_step(q, answer)
			if step != "":
				return step
			var w := _solve_word_problem(text, answer)
			if not w.is_empty():
				match w["op"]:
					"+", "sum":
						return "Clue: the amounts are being put together, so add!"
					"-":
						return "Clue: some are taken away or used up, so subtract!"
					"x":
						return "Clue: there are equal groups, so multiply!"
					"÷":
						return "Clue: something is shared equally, so divide!"
	if lower.contains("side"):
		return "A side is one straight edge. Trace around the shape and count each edge once."
	return "Read the question again slowly. Look for clue words like 'more', 'left', 'each' or 'share'."


## The first PMDAS step without its result: "First, do the parentheses: 5 + 3."
static func _first_step(q: Dictionary, answer: String) -> String:
	for expr in _candidate_expressions(q):
		var tokens := _tokenize(expr)
		if tokens.is_empty():
			continue
		var steps : Array = []
		var value = _solve(tokens, steps)
		if value == null or steps.is_empty():
			continue
		if not answer.is_valid_float() or absf(float(value) - answer.to_float()) > 0.0001:
			continue
		var first : String = str(steps[0]["text"]).split(" = ")[0]
		if steps.size() > 1:
			return "Start here: %s first. What does %s make?" % [steps[0]["rule"], first]
		# One step: give a strategy for that operation instead of repeating it
		var parts := first.split(" ")
		if parts.size() != 3:
			return ""
		var a := parts[0]
		var b := parts[2]
		match parts[1]:
			"+":
				var small := mini(a.to_int(), b.to_int())
				if small >= 10:
					return "Add the ones first, then the tens. %s + %s: start with the ones!" % [a, b]
				return "Start at the bigger number and count on %d more." % small
			"-":
				if b.to_int() >= 10:
					return "Subtract the ones first, then the tens. If the top ones are too small, borrow a ten!"
				return "Start at %s and count back %s." % [a, b]
			"x":
				return "Think of %s groups of %s. Count by %ss, %s times." % [a, b, b, a]
			"÷":
				return "Share %s into %s equal groups. How many land in each group?" % [a, b]
	return ""
