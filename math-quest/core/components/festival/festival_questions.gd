extends RefCounted
class_name FestivalQuestions

# =====================================================================
#  Questions for the festival booths, at the player's grade, written in
#  the formats the class stations already read in setup(q, type):
#    potion / rune / circle   "text" with "a + b", "a - b" or "a x b"
#    scale                    a "balance" visual with left/right counts
#    counting                 a "groups" visual: eggs in baskets
#    pattern                  a "pattern" visual: painted eggs, "?" last
#    number_line              a "number_line" visual: bunny hops
#    constellation            skip-counted stars, one "?" star
#    shooting_stars           equal groups of stars
#    star_map                 two named constellations to count / compare
#    market                   prices and coins (booth "mode": shopping/change)
#    scale + "items":"pumpkin"  two pumpkins (kg) on the balance
#    garden                   crops in rows x columns
#    sharing                  candies shared equally into bags
#    shapes                   a jack-o'-lantern face (eye, nose, mouth)
#    clock                    a clock to read ("h:mm", input "time")
#    shooting_stars + "creature":"bat"  bats in groups
#    sharing + "item":"cookie"        cookies onto plates
#    number_line + "rider":"penguin"  a skating penguin, also backwards
#    potion + "recipe":"cocoa"        a hot cocoa recipe
#    tally                    two teams' snowball hits in tally marks
#  lantern_puzzle(grade): the puzzle on a sealed lantern / snowman.
#  Each question: {"text", "answer", "input": "number" | "choice",
#                  "options" + "choice_hint" (choice only), "visual"}
# =====================================================================

const BALANCE_ITEMS := ["crystals", "potions", "stars", "apples", "runes"]
const EGG_COLORS := ["Red", "Blue", "Yellow", "Green", "Pink", "Purple"]
const GOODS := [
	{"name": "Apples", "icon": "🍎"}, {"name": "Bread", "icon": "🍞"}, {"name": "Pie", "icon": "🥧"},
	{"name": "Cheese", "icon": "🧀"}, {"name": "Corn", "icon": "🌽"}, {"name": "Honey", "icon": "🍯"},
	{"name": "Pears", "icon": "🍐"}, {"name": "Milk", "icon": "🥛"},
]
const FRIENDS := ["Tim", "Abby", "Romeo", "Lucy", "Oscar"]
const SHAPE_NAMES := {3: "triangle", 4: "square", 5: "pentagon", 6: "hexagon", 8: "octagon"}
const CROPS := ["carrot", "cabbage", "corn"]
const CROP_NAMES := {"carrot": "carrots", "cabbage": "cabbages", "corn": "corn plants"}
const CONSTELLATIONS := ["Big Dipper", "Orion", "Little Bear", "Swan", "Dragon", "Lion", "Scorpion", "Crown"]


## The player's grade from the save ("g1" when unknown).
static func current_grade() -> String:
	var progress = db.query("SELECT current_grade FROM progress WHERE is_active = true LIMIT 1")
	if typeof(progress) == TYPE_DICTIONARY and typeof(progress.get("data")) == TYPE_ARRAY and not progress.data.is_empty():
		return str(progress.data[0].current_grade)
	return "g1"


## booth: the booth's data, for options like "mode" (market) or
## "items" (pumpkins on the scale).
static func make(station: String, grade: String, round_index: int, booth: Dictionary = {}) -> Dictionary:
	match station:
		"scale":
			if str(booth.get("items", "")) == "pumpkin":
				return _pumpkins(grade, round_index)
			return _balance(grade, round_index)
		"market":
			if str(booth.get("mode", "shopping")) == "change":
				return _change(grade)
			return _shopping(grade, round_index)
		"garden":
			return _garden(grade, round_index)
		"circle":
			return _duel(grade)
		"counting":
			return _baskets(grade, round_index)
		"pattern":
			return _pattern(grade)
		"number_line":
			if str(booth.get("rider", "")) == "penguin":
				return _skating(grade)
			return _bunny_hop(grade)
		"constellation":
			return _constellation(grade)
		"shooting_stars":
			return _shooting_stars(grade, round_index, str(booth.get("creature", "star")))
		"sharing":
			var share := _sharing(grade, round_index)
			if str(booth.get("item", "")) == "cookie":
				share["visual"]["item"] = "cookie"
				share["text"] = str(share["text"]).replace("candies", "cookies")
			return share
		"tally":
			return _tally(grade, round_index)
		"shapes":
			return _carving(grade, round_index)
		"clock":
			return _ghost_clock(grade)
		"star_map":
			return _star_map(grade, round_index)
	if str(booth.get("recipe", "")) == "cocoa":
		return _cocoa(grade)
	return _sum(grade)


## "7 + 5" style sums: g1 within 20, g2 two-digit, g3+ times tables.
static func _sum(grade: String) -> Dictionary:
	var level := _level(grade)
	if level >= 3 and randf() < 0.6:
		var x := randi_range(2, 9)
		var y := randi_range(2, 9)
		return _number("%d x %d" % [x, y], x * y)
	var a : int
	var b : int
	if level >= 2:
		a = randi_range(20, 79)
		b = randi_range(11, 19)
	else:
		a = randi_range(3, 12)
		b = randi_range(1, 8)
	if randf() < 0.5:
		return _number("%d + %d" % [a, b], a + b)
	return _number("%d - %d" % [a + b, b], a)


## The duel: small groups to multiply (g2+, the circle shows the orbs) or
## quick sums for g1.
static func _duel(grade: String) -> Dictionary:
	if _level(grade) >= 2:
		var x := randi_range(2, 5)
		var y := randi_range(2, 5)
		return _number("%d x %d" % [x, y], x * y)
	var a := randi_range(2, 9)
	var b := randi_range(1, 9)
	return _number("%d + %d" % [a, b], a + b)


## Odd rounds: "Which side is heavier?" (Left / Right / Both the same).
## Even rounds: "How many more on the heavier side?" (number).
static func _balance(grade: String, round_index: int) -> Dictionary:
	var top := 10 if _level(grade) <= 1 else 20
	var left := randi_range(2, top)
	var right := randi_range(2, top)
	var item : String = BALANCE_ITEMS.pick_random()
	var visual := {"type": "balance", "leftItems": {"count": left}, "rightItems": {"count": right}}
	if round_index % 2 == 1:
		while right == left:
			right = randi_range(2, top)
		visual["rightItems"]["count"] = right
		return {"text": "%d %s on the left, %d on the right. How many more on the heavier side?" % [left, item, right],
			"answer": str(absi(left - right)), "input": "number", "visual": visual}
	var answer := "Both the same"
	if left > right:
		answer = "Left"
	elif right > left:
		answer = "Right"
	return {"text": "%d %s on the left, %d on the right. Which side is heavier?" % [left, item, right],
		"answer": answer, "input": "choice", "options": ["Left", "Right", "Both the same"], "visual": visual,
		"choice_hint": "Which side of the balance?"}


static func _number(text: String, answer: int) -> Dictionary:
	return {"text": text + " = ?", "answer": str(answer), "input": "number"}


static func _level(grade: String) -> int:
	return maxi(1, grade.trim_prefix("g").to_int())


## Eggs packed in baskets of 5 (g1) or 10 (g2+), plus a partly filled one.
## Odd rounds: how many eggs in all; even rounds: how many full baskets.
static func _baskets(grade: String, round_index: int) -> Dictionary:
	var per := 5 if _level(grade) <= 1 else 10
	var full := randi_range(2, 4 if per == 5 else 6)
	var extra := randi_range(1, per - 1)
	var bundles : Array = []
	for i in range(full):
		bundles.append(per)
	bundles.append(extra)
	var visual := {"type": "groups", "groups": {"icon": "🥚", "bundles": bundles}}
	if round_index % 2 == 0:
		return {"text": "Each full basket holds %d eggs. How many full baskets are there?" % per,
			"answer": str(full), "input": "number", "visual": visual}
	return {"text": "Count the eggs in all the baskets. How many eggs are there?",
		"answer": str(full * per + extra), "input": "number", "visual": visual}


## g1: colour patterns (AB, ABB, ABC) chosen from colour names;
## g2+: number patterns counting on by 2, 5 or 10 (or back by 1).
static func _pattern(grade: String) -> Dictionary:
	if _level(grade) <= 1:
		var colors : Array = EGG_COLORS.duplicate()
		colors.shuffle()
		var units := [[0, 1], [0, 1, 1], [0, 1, 2]]
		var unit : Array = units.pick_random()
		var row : Array = []
		var length := 6 if unit.size() == 2 else unit.size() * 2 + 1
		for i in range(length):
			row.append(colors[unit[i % unit.size()]])
		var answer : String = row[length - 1]
		row[length - 1] = "?"
		var options : Array = [colors[0], colors[1], colors[2], colors[3]]
		return {"text": "Which colour comes next in the egg pattern?", "answer": answer, "input": "choice",
			"choice_hint": "Pick the colour for the last egg:",
			"options": options, "visual": {"type": "pattern", "kind": "color", "pattern": row}}
	var step : int = [2, 5, 10, -1].pick_random()
	var start := step * randi_range(0, 4)
	if step == -1:
		start = randi_range(10, 30)
	elif step == 10 and randf() < 0.5:
		start += randi_range(1, 9)      # 3, 13, 23 ... counting on from any number
	var nums : Array = []
	for i in range(5):
		nums.append(str(start + step * i))
	var next := start + step * 5
	nums.append("?")
	return {"text": "What number goes on the next egg?", "answer": str(next), "input": "number",
		"visual": {"type": "pattern", "kind": "number", "pattern": nums}}


## The bunny starts somewhere and hops the same amount each time.
static func _bunny_hop(grade: String) -> Dictionary:
	var steps := [1, 2]
	match _level(grade):
		2:
			steps = [2, 5, 10]
		3, 4, 5, 6:
			steps = [5, 10]
	var step : int = steps.pick_random()
	var hops := randi_range(2, 4)
	var start := randi_range(0, 5 if step <= 2 else 10)
	var land := start + step * hops
	var top := land + step
	var nice := 5 if top <= 20 else 10
	top = int(ceil(float(top) / nice)) * nice
	return {"text": "The bunny starts at %d and hops %d times, %d each hop. Where does it land?" % [start, hops, step],
		"answer": str(land), "input": "number",
		"visual": {"type": "number_line", "start": start, "step": step, "hops": hops, "max": top}}


## Stars numbered by skip counting with one missing (not always the last).
static func _constellation(grade: String) -> Dictionary:
	var steps := [1, 2]
	match _level(grade):
		2:
			steps = [2, 5, 10]
		3, 4, 5, 6:
			steps = [3, 4, 5]
	var step : int = steps.pick_random()
	var count := randi_range(5, 6)
	var start := step * randi_range(0, 3) if step > 1 else randi_range(1, 8)
	var stars : Array = []
	for i in range(count):
		stars.append(str(start + step * i))
	var hole := randi_range(1, count - 1)
	var answer : String = stars[hole]
	stars[hole] = "?"
	return {"text": "The stars count by %d. What number belongs on the missing star?" % step,
		"answer": answer, "input": "number",
		"visual": {"type": "constellation", "stars": stars, "shape": randi()}}


## Equal groups of shooting stars. Odd rounds: how many in all;
## even rounds: how many groups.
static func _shooting_stars(grade: String, round_index: int, creature: String = "star") -> Dictionary:
	var bats := creature == "bat"
	var groups : int
	var per : int
	if _level(grade) <= 1:
		per = [2, 5, 10].pick_random()
		groups = randi_range(2, 4 if per == 10 else 5)
	else:
		per = randi_range(2, 6)
		groups = randi_range(2, 5)
	var visual := {"type": "shooting_stars", "groups": groups, "per": per, "creature": creature}
	var many := "bats" if bats else "shooting stars"
	var short := "bats" if bats else "stars"
	var came := "flew out of the tower" if bats else "fell"
	if round_index % 2 == 0:
		return {"text": "%d %s %s, %d in each group. How many groups are there?" % [groups * per, many, came, per],
			"answer": str(groups), "input": "number", "visual": visual}
	if _level(grade) <= 1:
		return {"text": "%d groups of %s, %d in each group. Count by %ds: how many %s in all?" % [groups, many, per, per, short],
			"answer": str(groups * per), "input": "number", "visual": visual}
	return {"text": "%d groups of %d %s. How many %s in all? (%d x %d)" % [groups, per, many, short, groups, per],
		"answer": str(groups * per), "input": "number", "visual": visual}


## Two constellations in the telescope. Odd rounds: how many stars in all;
## even rounds: how many more in the bigger one.
static func _star_map(grade: String, round_index: int) -> Dictionary:
	var top := 10 if _level(grade) <= 1 else 18
	var names : Array = CONSTELLATIONS.duplicate()
	names.shuffle()
	var a := randi_range(3, top)
	var b := randi_range(3, top)
	while b == a:
		b = randi_range(3, top)
	var visual := {"type": "star_map", "maps": [{"name": names[0], "count": a}, {"name": names[1], "count": b}]}
	if round_index % 2 == 0:
		var big : String = names[0] if a > b else names[1]
		var small : String = names[1] if a > b else names[0]
		return {"text": "%s has %d stars and %s has %d. How many more stars does %s have than %s?" % [names[0], a, names[1], b, big, small],
			"answer": str(absi(a - b)), "input": "number", "visual": visual}
	return {"text": "Count the stars in %s and %s. How many stars are there in all?" % [names[0], names[1]],
		"answer": str(a + b), "input": "number", "visual": visual}


static func _goods(n: int) -> Array:
	var list : Array = GOODS.duplicate()
	list.shuffle()
	return list.slice(0, n)


## A budget and two things to buy. Odd rounds: what they cost together;
## even rounds: how many coins are left. g3 buys several of one thing.
static func _shopping(grade: String, round_index: int) -> Dictionary:
	var level := _level(grade)
	var g := _goods(2)
	var qty_a := randi_range(2, 4) if level >= 3 else 1
	var price_a := randi_range(2, 9) if level <= 1 else randi_range(5, 30)
	var price_b := randi_range(2, 8) if level <= 1 else randi_range(5, 30)
	if level >= 3:
		price_a = randi_range(2, 9)
	var cost := price_a * qty_a + price_b
	var budget := cost + (randi_range(1, 6) if level <= 1 else randi_range(5, 40))
	var items := [
		{"name": g[0]["name"], "icon": g[0]["icon"], "price": price_a, "qty": qty_a},
		{"name": g[1]["name"], "icon": g[1]["icon"], "price": price_b, "qty": 1},
	]
	var what_a := ("%d %s" % [qty_a, str(g[0]["name"]).to_lower()]) if qty_a > 1 else str(g[0]["name"]).to_lower()
	var visual := {"type": "market", "mode": "shopping", "budget": budget, "items": items}
	if round_index % 2 == 0:
		return {"text": "You have %d coins and buy %s and %s. How many coins are left?" % [budget, what_a, str(g[1]["name"]).to_lower()],
			"answer": str(budget - cost), "input": "number", "visual": visual}
	return {"text": "You buy %s and %s. How many coins do they cost together?" % [what_a, str(g[1]["name"]).to_lower()],
		"answer": str(cost), "input": "number", "visual": visual}


## Be the shopkeeper: the customer pays with round coins, give the change.
static func _change(grade: String) -> Dictionary:
	var level := _level(grade)
	var g := _goods(2)
	var items : Array = []
	var cost := 0
	if level <= 1:
		var price := randi_range(2, 9)
		items.append({"name": g[0]["name"], "icon": g[0]["icon"], "price": price, "qty": 1})
		cost = price
	else:
		var pa := randi_range(5, 35)
		var pb := randi_range(5, 30)
		items.append({"name": g[0]["name"], "icon": g[0]["icon"], "price": pa, "qty": 1})
		items.append({"name": g[1]["name"], "icon": g[1]["icon"], "price": pb, "qty": 1})
		cost = pa + pb
	var paid := 10
	for note in [10, 20, 50, 100]:
		if note > cost:
			paid = note
			break
	var what := str(items[0]["name"]).to_lower()
	if items.size() > 1:
		what += " and " + str(items[1]["name"]).to_lower()
	return {"text": "A customer buys %s and pays %d coins. How much change do you give?" % [what, paid],
		"answer": str(paid - cost), "input": "number",
		"visual": {"type": "market", "mode": "change", "paid": paid, "items": items}}


## Two pumpkins (kg) on the magic balance. Odd rounds: which is heavier;
## even rounds: by how many kg.
static func _pumpkins(grade: String, round_index: int) -> Dictionary:
	var top := 10 if _level(grade) <= 1 else 20
	var left := randi_range(2, top)
	var right := randi_range(2, top)
	while right == left:
		right = randi_range(2, top)
	var visual := {"type": "balance", "leftItems": {"count": left}, "rightItems": {"count": right}}
	if round_index % 2 == 0:
		return {"text": "The left pumpkin weighs %d kg and the right one %d kg. How many kg heavier is the bigger pumpkin?" % [left, right],
			"answer": str(absi(left - right)), "input": "number", "visual": visual}
	return {"text": "The left pumpkin weighs %d kg and the right one %d kg. Which pumpkin is heavier?" % [left, right],
		"answer": "Left" if left > right else "Right", "input": "choice",
		"options": ["Left", "Right", "Both the same"], "choice_hint": "Which pumpkin is heavier?", "visual": visual}


## Crops in rows and columns. Odd rounds: how many in all (g1 counts by
## 2s, 5s or 10s); even rounds: how many rows.
static func _garden(grade: String, round_index: int) -> Dictionary:
	var crop : String = CROPS.pick_random()
	var plants : String = CROP_NAMES[crop]
	var rows : int
	var cols : int
	if _level(grade) <= 1:
		cols = [2, 5, 10].pick_random()
		rows = randi_range(2, 4 if cols == 10 else 5)
	else:
		cols = randi_range(2, 9)
		rows = randi_range(2, 6)
	var visual := {"type": "garden", "rows": rows, "cols": cols, "crop": crop}
	if round_index % 2 == 0:
		return {"text": "There are %d %s, %d in each row. How many rows are there?" % [rows * cols, plants, cols],
			"answer": str(rows), "input": "number", "visual": visual}
	if _level(grade) <= 1:
		return {"text": "%d rows of %s, %d in each row. Count by %ds: how many %s in all?" % [rows, plants, cols, cols, plants],
			"answer": str(rows * cols), "input": "number", "visual": visual}
	return {"text": "%d rows of %d %s. How many %s in all? (%d x %d)" % [rows, cols, plants, plants, rows, cols],
		"answer": str(rows * cols), "input": "number", "visual": visual}


## Candies shared equally into treat bags. g3 even rounds: leftovers.
static func _sharing(grade: String, round_index: int) -> Dictionary:
	var level := _level(grade)
	var bags := 2
	var each := randi_range(2, 5)
	if level == 2:
		bags = randi_range(2, 5)
		each = randi_range(2, 6)
	elif level >= 3:
		bags = randi_range(3, 5)
		each = randi_range(3, 9)
	var names : Array = FRIENDS.duplicate()
	names.shuffle()
	var friends : Array = names.slice(0, bags)
	var total := bags * each
	if level >= 3 and round_index % 2 == 0:
		var extra := randi_range(1, bags - 1)
		total += extra
		return {"text": "%d candies are shared equally by %d friends. How many candies are left over?" % [total, bags],
			"answer": str(extra), "input": "number",
			"visual": {"type": "sharing", "total": total, "friends": friends}}
	return {"text": "%d candies are shared equally by %d friends. How many candies does each friend get?" % [total, bags],
		"answer": str(each), "input": "number",
		"visual": {"type": "sharing", "total": total, "friends": friends}}


## A jack-o'-lantern face made of shapes: eye, nose and mouth.
static func _carving(grade: String, round_index: int) -> Dictionary:
	var level := _level(grade)
	var eye : int = 3 if level <= 1 else [3, 4].pick_random()
	var nose : int = [3, 4, 5].pick_random()
	var mouth : int = [4, 6].pick_random() if level <= 1 else [4, 6, 8].pick_random()
	var shapes := [
		{"sides": eye, "label": "eye (%s)" % SHAPE_NAMES[eye]},
		{"sides": nose, "label": "nose (%s)" % SHAPE_NAMES[nose]},
		{"sides": mouth, "label": "mouth (%s)" % SHAPE_NAMES[mouth]},
	]
	var visual := {"type": "shapes", "shapes": shapes, "interactive": false,
		"instruction": "Carve the jack-o'-lantern! It has two eyes, a nose and a mouth."}
	match round_index % 3:
		1:
			return {"text": "Both eyes are %ss. How many sides do the two eyes have in all?" % SHAPE_NAMES[eye],
				"answer": str(eye * 2), "input": "number", "visual": visual}
		2:
			return {"text": "How many corners does the mouth have?", "answer": str(mouth), "input": "number", "visual": visual}
	return {"text": "How many sides do the nose and the mouth have together?",
		"answer": str(nose + mouth), "input": "number", "visual": visual}


## Read the ghost's clock: g1 o'clock / half past, g2 quarters and
## 5 minutes, g3 any 5 minutes.
static func _ghost_clock(grade: String) -> Dictionary:
	var level := _level(grade)
	var hour := randi_range(1, 12)
	var minute := 0
	if level <= 1:
		minute = [0, 30].pick_random()
	elif level == 2:
		minute = [0, 15, 30, 45, 5 * randi_range(1, 11)].pick_random()
	else:
		minute = 5 * randi_range(0, 11)
	return {"text": "The ghost appears at the time on the clock. What time is it?",
		"answer": "%d:%02d" % [hour, minute], "input": "time",
		"visual": {"type": "clock", "clocks": [{"hour": hour, "minute": minute}]}}


## The number puzzle sealing a lantern (answered on the NumberPad).
static func lantern_puzzle(grade: String) -> Dictionary:
	var level := _level(grade)
	if randf() < 0.5:
		var step : int = 1
		if level <= 1:
			step = [1, 2].pick_random()
		elif level == 2:
			step = [2, 5, 10].pick_random()
		else:
			step = [3, 4, 6, 7].pick_random()
		var start := randi_range(1, 9) if level <= 1 else step * randi_range(1, 4)
		var seq : Array = []
		for i in range(4):
			seq.append(str(start + step * i))
		return {"text": "The lantern's runes count on. Which number comes next?",
			"answer": str(start + step * 4), "visual": {"type": "sequence", "sequence": [", ".join(seq) + ", ?"]}}
	if level >= 3:
		var a := randi_range(2, 9)
		var b := randi_range(2, 9)
		return {"text": "Find the missing number to unlock the lantern.", "answer": str(b),
			"visual": {"type": "sequence", "sequence": ["%d x ? = %d" % [a, a * b]]}}
	var top := 10 if level <= 1 else 50
	var x := randi_range(1, top - 2)
	var y := randi_range(1, top - x)
	return {"text": "Find the missing number to unlock the lantern.", "answer": str(y),
		"visual": {"type": "sequence", "sequence": ["%d + ? = %d" % [x, x + y]]}}


## The penguin skates jumps along the ice; g2+ sometimes backwards.
static func _skating(grade: String) -> Dictionary:
	var level := _level(grade)
	var steps := [1, 2] if level <= 1 else ([2, 5, 10] if level == 2 else [3, 4, 5, 10])
	var step : int = steps.pick_random()
	var jumps := randi_range(2, 4)
	if level >= 2 and randf() < 0.5:
		var start := step * jumps + randi_range(0, 10)
		var land := start - step * jumps
		var top := start + step
		var nice := 5 if top <= 20 else 10
		top = int(ceil(float(top) / nice)) * nice
		return {"text": "The penguin starts at %d and skates %d jumps back, %d each jump. Where does it stop?" % [start, jumps, step],
			"answer": str(land), "input": "number",
			"visual": {"type": "number_line", "start": start, "step": -step, "hops": jumps, "max": top, "rider": "penguin"}}
	var q := _bunny_hop(grade)
	var v : Dictionary = q["visual"]
	v["rider"] = "penguin"
	q["text"] = "The penguin starts at %d and skates %d jumps, %d each jump. Where does it stop?" % [int(v["start"]), int(v["hops"]), int(v["step"])]
	return q


## Hot cocoa recipe in the pot (the jars read "a + b" / "a x b").
static func _cocoa(grade: String) -> Dictionary:
	var level := _level(grade)
	var q := {}
	if level <= 1:
		var a := randi_range(2, 8)
		var b := randi_range(1, 7)
		q = _number("Cocoa recipe: %d scoops of cocoa + %d marshmallows. How many go in the pot? %d + %d" % [a, b, a, b], a + b)
	elif level == 2:
		var n := randi_range(3, 12)
		q = _number("Double the cocoa recipe! It needs %d spoons of sugar. Doubled, that is 2 x %d" % [n, n], 2 * n)
	else:
		var cups := randi_range(2, 6)
		var each := randi_range(2, 6)
		q = _number("%d cups of cocoa, %d marshmallows in each cup. How many marshmallows? %d x %d" % [cups, each, cups, each], cups * each)
	q["visual"] = {"brew": "cocoa"}
	return q


## Two teams' snowball hits in tally marks. Round 1: read one team;
## round 2: hits in all; round 3: how many more.
static func _tally(grade: String, round_index: int) -> Dictionary:
	var top := 15 if _level(grade) <= 1 else 30
	var a := randi_range(4, top)
	var b := randi_range(4, top)
	while b == a:
		b = randi_range(4, top)
	var teams := [{"name": "Red", "count": a}, {"name": "Blue", "count": b}]
	var visual := {"type": "tally", "teams": teams}
	match round_index % 3:
		1:
			return {"text": "Count the tally marks. How many snowballs hit the Red team's fort?",
				"answer": str(a), "input": "number", "visual": visual}
		2:
			return {"text": "How many snowballs hit the two forts in all?",
				"answer": str(a + b), "input": "number", "visual": visual}
	var more := "Red" if a > b else "Blue"
	return {"text": "How many more hits does the %s team's fort have?" % more,
		"answer": str(absi(a - b)), "input": "number", "visual": visual}
