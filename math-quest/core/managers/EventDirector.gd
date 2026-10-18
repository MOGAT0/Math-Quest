extends Node

# =====================================================================
#  Random events (autoload "EventDirector").
#
#  Twice a day the game rolls RANDOM_CHANCE: when Matthew wakes up
#  (CalendarManager.day_started) and after class (world.gd ->
#  on_class_finished). On a hit, a burst of EVENTS_MIN..EVENTS_MAX events
#  from data/events.json ("random") spawns inside the world's
#  npc_spawn_area (world.tscn, unique name %npc_spawn_area), spread out
#  (MIN_SPACING apart), a toast announces them and every NPC / pickup gets
#  its own quest arrow, removed as soon as it is helped / picked up.
#  Everything unfinished vanishes when Matthew sleeps.
#
#  Every event is a visitor (NPC); each visitor appears at most once at a
#  time. Event types:
#    "riddle"   the visitor asks a math question taken from the lessons
#               already studied; answered on the class NumberPad.
#    "fetch"    the visitor lost some items: Matthew agrees to help, finds
#               them around the spawn area (one arrow each), brings them
#               back and tells how many he found (NumberPad) for the reward.
#  Major (calendar) events live in the same file under "major".
# =====================================================================

signal event_started(event_id: String)
signal event_completed(event_id: String, reward: int)
signal event_expired(event_id: String)

## Chance of a burst at each roll (after waking, after class).
## 1.0 = always (testing); ~0.45 makes events a lucky surprise.
const RANDOM_CHANCE := 0.6
## How many events a burst spawns.
const EVENTS_MIN := 2
const EVENTS_MAX := 5
## Safety cap on events alive at the same time (morning + evening bursts).
const MAX_ACTIVE := 12
## Spawn spots are never reused: a new NPC/pickup keeps at least this far
## (world pixels) from every spot already taken by a live event.
const MIN_SPACING := 48.0
const SPOT_TRIES := 25
const EVENTS_PATH := "res://data/events.json"
const SIDE_QUEST_PREFIX := "random_event_"
## Fallback spawn route when the world has no npc_spawn_area.
const ROUTE_FROM := "academy_gate2"
const ROUTE_TO := "arith_house"

## Dev/testing: the next roll always hits.
var force_next : bool = false

var _defs : Array = []
var _world : Node2D = null
## Live events: {"key", "def", "nodes": Array, "marker", "found", "total"}
var _active : Array = []
var _next_key : int = 0
var _taken_spots : Array = []    # Vector2 spots used by live events
var _toast : EventToast = null
var _tracker : QuestTracker = null


func _ready() -> void:
	_load_events()
	CalendarManager.day_ended.connect(func(_d): expire_all())
	CalendarManager.day_started.connect(func(_d): _roll.call_deferred("morning"))


func _load_events() -> void:
	_defs = []
	if not FileAccess.file_exists(EVENTS_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(EVENTS_PATH))
	if typeof(parsed) == TYPE_DICTIONARY and typeof(parsed.get("random")) == TYPE_ARRAY:
		_defs = parsed["random"]


# ----------------------------------------------------------------- rolling --

## The world scene registers itself so morning events know where to spawn.
func register_world(world: Node2D) -> void:
	if world != _world:
		_forget_world()
	_world = world


## A new world (scene reloaded): the old events' NPCs, pickups and arrow
## markers were freed with the old world, so forget them.
func _forget_world() -> void:
	for ev in _active:
		for key in ev.get("keys", []):
			GameManager.sideQuest_locations.erase(key)
		if GameManager.side_quest_focus == ev["key"]:
			GameManager.side_quest_focus = ""
	_active.clear()
	_taken_spots.clear()
	_toast = null
	_tracker = null


## Called by world.gd when a class ends.
func on_class_finished(world: Node2D) -> void:
	_world = world
	_roll("after_class")


## One roll: on a hit, spawn a burst of EVENTS_MIN..EVENTS_MAX events.
func _roll(_moment: String) -> void:
	if _world == null or not is_instance_valid(_world) or _defs.is_empty():
		return
	if not (force_next or randf() < RANDOM_CHANCE):
		return
	force_next = false
	var count := mini(randi_range(EVENTS_MIN, EVENTS_MAX), MAX_ACTIVE - _active.size())
	if count <= 0:
		return
	var visitors_here : Array = []
	for e in _active:
		visitors_here.append(str(e["def"].get("id", "")))
	var started := 0
	for i in range(count):
		var def := _pick(visitors_here)
		if def.is_empty():
			break
		visitors_here.append(str(def.get("id", "")))
		start_event(def, false)
		started += 1
	if started == 1:
		_toast_show(str(_active.back()["def"].get("announce", "Something is happening nearby...")))
	elif started > 1:
		_toast_show("%d surprises appeared around the village!" % started)


## Weighted pick. A visitor is never picked while the same visitor is
## already around.
func _pick(visitors_here: Array) -> Dictionary:
	var pool : Array = []
	var total := 0.0
	for d in _defs:
		if visitors_here.has(str(d.get("id", ""))):
			continue
		pool.append(d)
		total += float(d.get("weight", 1.0))
	if pool.is_empty():
		return {}
	var roll := randf() * total
	for d in pool:
		roll -= float(d.get("weight", 1.0))
		if roll <= 0.0:
			return d
	return pool.back()


func start_event(def: Dictionary, announce: bool = true) -> Dictionary:
	if _world == null or def.is_empty():
		return {}
	var ev := {"key": SIDE_QUEST_PREFIX + str(_next_key), "def": def, "nodes": [], "keys": [], "found": 0, "total": 0, "spots": []}
	_next_key += 1

	var npc := EventNPC.new()
	npc.setup(def)
	npc.player_body = _world.get("player")
	_match_player_layer(npc)
	_world.add_child(npc)
	npc.global_position = _free_spot(ev)
	ev["nodes"].append(npc)
	ev["npc"] = npc
	ev["stage"] = "new"
	_add_arrow(ev, npc, ev["key"])
	match str(def.get("type", "")):
		"fetch":
			npc.interacted.connect(_on_fetch_talk.bind(ev))
		_:
			npc.interacted.connect(_open_riddle.bind(ev))

	_active.append(ev)
	if announce:
		_toast_show(str(def.get("announce", "Something is happening nearby...")))
	event_started.emit(str(def.get("id", "")))
	return ev


# ---------------------------------------------------------------- spawning --

## A spawn point nobody is using yet (falls back to the last try if the
## area is too crowded to find one). Remembered on the event so it is
## freed again when the event ends.
func _free_spot(ev: Dictionary) -> Vector2:
	var p := _spawn_point()
	for i in range(SPOT_TRIES):
		var clear := not FestivalDirector.blocks_spot(p)
		for used in _taken_spots:
			if p.distance_to(used) < MIN_SPACING:
				clear = false
				break
		if clear:
			break
		p = _spawn_point()
	_taken_spots.append(p)
	ev["spots"].append(p)
	return p


## Spots used by something else (festival booths): random visitors keep
## MIN_SPACING away from them until they are released.
func reserve_spot(p: Vector2) -> void:
	_taken_spots.append(p)


func release_spot(p: Vector2) -> void:
	_taken_spots.erase(p)


func taken_spots() -> Array:
	return _taken_spots.duplicate()


## Quest arrow (target_indicator) on a spawned NPC / pickup. The marker is
## a child of that node, so it disappears together with it.
## Y-sort only orders nodes on the same z level: put NPCs and items on the
## player's level (the world root is y-sorted) so Matthew walks in front of
## or behind them by their feet position.
func _match_player_layer(node: CanvasItem) -> void:
	var player = _world.get("player")
	node.z_index = player.z_index if player is CanvasItem else 1
	node.z_as_relative = player.z_as_relative if player is CanvasItem else true


func _add_arrow(ev: Dictionary, holder: Node2D, key: String) -> void:
	var marker := Marker2D.new()
	holder.add_child(marker)
	GameManager.sideQuest_locations[key] = marker
	ev["keys"].append(key)


func _spawn_area() -> Area2D:
	return SpawnSpots.find_area(_world, "npc_spawn_area")


## A random walkable point inside the world's npc_spawn_area (or along the
## road home when the world has no such area).
func _spawn_point() -> Vector2:
	var area := _spawn_area()
	if area:
		var p := SpawnSpots.random_point(_world, area)
		if p != Vector2.INF:
			return p
	var player := _player_pos()
	var a := _route_point(ROUTE_FROM, player)
	var b := _route_point(ROUTE_TO, player + Vector2(300, 0))
	return _on_navmesh(a.lerp(b, randf_range(0.3, 0.8)) + Vector2(randf_range(-40, 40), randf_range(-60, 60)))


func _route_point(key: String, fallback: Vector2) -> Vector2:
	var locs = _world.get("locations")
	if typeof(locs) == TYPE_DICTIONARY and locs.has(key) and is_instance_valid(locs[key]):
		return (locs[key] as Node2D).global_position
	return fallback


func _on_navmesh(p: Vector2) -> Vector2:
	return SpawnSpots.on_navmesh(_world, p)


func _player_pos() -> Vector2:
	var player = _world.get("player")
	if player is Node2D:
		return player.global_position
	return Vector2.ZERO


func _set_player_frozen(frozen: bool) -> void:
	var player = _world.get("player") if _world else null
	if player is Node:
		player.set_physics_process(not frozen)


# --------------------------------------------------------------- handling --

func _open_riddle(npc: EventNPC, ev: Dictionary) -> void:
	var def : Dictionary = ev["def"]
	var popup := RiddlePopup.new()
	_ui_layer().add_child(popup)
	popup.open(def, _review_question())
	_set_player_frozen(true)
	popup.finished.connect(func(solved: bool, mistakes: int):
		_set_player_frozen(false)
		if solved:
			var reward := int(def.get("reward", 10))
			if mistakes > 0:
				reward = maxi(1, reward / 2)
			npc.leave()
			_complete(ev, reward)
	)


# ------------------------------------------------------------------ fetch --

## Talking to a fetch visitor: ask for help, remind, or take the items back.
func _on_fetch_talk(npc: EventNPC, ev: Dictionary) -> void:
	var def : Dictionary = ev["def"]
	var who := str(def.get("name", "Visitor"))
	match str(ev.get("stage", "new")):
		"new":
			_talk(who, str(def.get("ask", "Could you help me find my things?")), ["I'll help!", "Later"], func(i: int):
				if i == 0:
					_start_search(npc, ev)
			)
		"searching":
			var left := int(ev["total"]) - int(ev["found"])
			_toast_show("%s: \"%d %s still missing!\"" % [who, left, str(def.get("item", "items")).to_lower()])
		"return":
			_ask_count(npc, ev)


## Items appear around the spawn area, each with its own arrow; the
## visitor's arrow waits until everything is found.
func _start_search(npc: EventNPC, ev: Dictionary) -> void:
	var def : Dictionary = ev["def"]
	ev["stage"] = "searching"
	ev["total"] = randi_range(int(def.get("min", 3)), int(def.get("max", 5)))
	ev["found"] = 0
	npc.set_mark("...")
	GameManager.side_quest_focus = ev["key"]   # hide other side-quest arrows meanwhile
	GameManager.sideQuest_locations.erase(ev["key"])
	for i in range(ev["total"]):
		var p := EventPickup.new()
		var arrow_key := "%s_item_%d" % [ev["key"], i]   # "_item_" = blue-green arrow
		p.glow_color = Color(str(def.get("color", "#f5d76e")))
		p.player_body = _world.get("player")
		p.collected.connect(_on_pickup_collected.bind(ev, arrow_key))
		_match_player_layer(p)
		_world.add_child(p)
		p.global_position = _free_spot(ev)
		ev["nodes"].append(p)
		_add_arrow(ev, p, arrow_key)
	_toast_show("Find %d %s around the village!" % [ev["total"], str(def.get("item", "items")).to_lower()])
	_get_tracker().show_task(ev["key"], "%s's %s" % [str(def.get("name", "")), str(def.get("item", "items")).to_lower()], 0, ev["total"])


func _on_pickup_collected(ev: Dictionary, arrow_key: String) -> void:
	# This item's arrow goes away right away, the others stay
	GameManager.sideQuest_locations.erase(arrow_key)
	ev["keys"].erase(arrow_key)
	if not _active.has(ev):
		return
	ev["found"] += 1
	var def : Dictionary = ev["def"]
	_get_tracker().set_progress(ev["found"], ev["total"])
	if ev["found"] < ev["total"]:
		return
	# Everything found: back to the visitor
	ev["stage"] = "return"
	var npc : EventNPC = ev["npc"]
	if is_instance_valid(npc):
		npc.set_mark("?")
		_add_arrow(ev, npc, ev["key"])
	_toast_show("Bring them back to %s!" % str(def.get("name", "the visitor")))
	_get_tracker().show_return(str(def.get("name", "the visitor")))


## Handing the items back: "How many did you find?" on the NumberPad.
func _ask_count(npc: EventNPC, ev: Dictionary) -> void:
	var def : Dictionary = ev["def"]
	var popup := RiddlePopup.new()
	_ui_layer().add_child(popup)
	var item := str(def.get("item", "items")).to_lower()
	var talk := def.duplicate()
	talk["intro"] = str(def.get("thanks", "You found them! Thank you so much!"))
	popup.open(talk, {"text": "How many %s did you bring back?" % item, "answer": str(ev["total"])})
	_set_player_frozen(true)
	popup.finished.connect(func(solved: bool, mistakes: int):
		_set_player_frozen(false)
		if solved:
			var reward := int(def.get("reward", 10))
			if mistakes > 0:
				reward = maxi(1, reward / 2)
			npc.leave()
			_complete(ev, reward)
	)


func _talk(who: String, line: String, buttons: Array, on_choice: Callable) -> void:
	var popup := TalkPopup.new()
	_ui_layer().add_child(popup)
	popup.open(who, line, buttons)
	_set_player_frozen(true)
	popup.chosen.connect(func(i: int):
		_set_player_frozen(false)
		on_choice.call(i)
	)


func _complete(ev: Dictionary, reward: int) -> void:
	var def : Dictionary = ev["def"]
	var id := str(def.get("id", ""))
	_give_kp(reward)
	_toast_show("%s  +%d KP" % [str(def.get("complete", "Well done!")), reward])
	CalendarManager.mark_event_seen(id)
	_clear(ev, false)
	event_completed.emit(id, reward)


## Sleeping ends the day: whatever was not finished disappears.
func expire_all() -> void:
	for ev in _active.duplicate():
		_clear(ev, true)
		event_expired.emit(str(ev["def"].get("id", "")))


## Number of live events (tests / UI).
func active_count() -> int:
	return _active.size()


func _clear(ev: Dictionary, remove_npc: bool) -> void:
	for n in ev.get("nodes", []):
		if is_instance_valid(n) and (remove_npc or not (n is EventNPC)):
			n.queue_free()
	for key in ev.get("keys", []):
		GameManager.sideQuest_locations.erase(key)
	if GameManager.side_quest_focus == ev["key"]:
		GameManager.side_quest_focus = ""
	if _tracker and is_instance_valid(_tracker):
		_tracker.hide_task(ev["key"])
	for spot in ev.get("spots", []):
		_taken_spots.erase(spot)
	_active.erase(ev)


func _give_kp(amount: int) -> void:
	var total := GameManager.kp_amount + amount
	db.query("UPDATE progress SET kp = %d WHERE is_active = true" % total)
	GameManager._update_KP()


# ------------------------------------------------------------- questions --

## A number question from a lesson the player has already studied, so the
## riddles double as review. Falls back to a simple sum.
func _review_question() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/curriculum.json"))
	var progress = db.query("SELECT current_grade, current_lesson FROM progress WHERE is_active = true LIMIT 1")
	var cur_grade := "g1"
	var cur_lesson := "g1-l1"
	if typeof(progress) == TYPE_DICTIONARY and typeof(progress.get("data")) == TYPE_ARRAY and not progress.data.is_empty():
		cur_grade = str(progress.data[0].current_grade)
		cur_lesson = str(progress.data[0].current_lesson)
	var pool : Array = []
	if typeof(data) == TYPE_DICTIONARY:
		var grades : Array = data.keys()
		grades.sort_custom(func(x, y): return String(x).trim_prefix("g").to_int() < String(y).trim_prefix("g").to_int())
		var done := false
		for g in grades:
			for lesson in data[g]:
				for q in lesson.get("questions", []):
					if _works_as_riddle(q):
						pool.append(q)
				if g == cur_grade and str(lesson.get("id", "")) == cur_lesson:
					done = true
					break
			if done:
				break
	# Early on only a few lesson questions exist; mix in fresh sums so the
	# riddles don't repeat (always fresh when the pool is empty).
	var fresh_chance := 0.3 if pool.size() >= 8 else 0.5
	if not pool.is_empty() and randf() >= fresh_chance:
		return pool.pick_random()
	return _fresh_question(cur_grade)


## A new sum at the player's level: g1 within 10, g2 two-digit, g3 times tables.
func _fresh_question(grade: String) -> Dictionary:
	match grade:
		"g2", "g4":
			var a := randi_range(20, 79)
			var b := randi_range(11, 19)
			if randf() < 0.5:
				return {"text": "I had %d magic beans and found %d more. How many beans do I have now?" % [a, b], "answer": str(a + b)}
			return {"text": "I had %d magic beans and gave %d away. How many beans are left?" % [a, b], "answer": str(a - b)}
		"g3":
			var x := randi_range(2, 9)
			var y := randi_range(2, 9)
			return {"text": "I have %d pouches with %d crystals in each. How many crystals is that?" % [x, y], "answer": str(x * y)}
	var m := randi_range(1, 6)
	var n := randi_range(1, 4)
	if randf() < 0.5:
		return {"text": "I picked %d apples, then %d more. How many apples do I have?" % [m, n], "answer": str(m + n)}
	return {"text": "I had %d apples and ate %d. How many apples are left?" % [m + n, n], "answer": str(m)}


## Riddles have no pictures, so skip questions that need one ("count how
## many boxes...", shapes, clocks, balances). Equation pictures like
## "(5 + 3) x 4 = ?" are fine: the popup prints them under the question.
func _works_as_riddle(q: Dictionary) -> bool:
	if AnswerRules.detect(q) != "number":
		return false
	var v = q.get("visual", {})
	var visual := str(v.get("type", "")) if typeof(v) == TYPE_DICTIONARY else ""
	if visual != "" and visual != "sequence":
		return false
	var text := str(q.get("text", "")).to_lower()
	for phrase in ["this shape", "these", "count how many", "look at", "shown", "picture", "count the"]:
		if text.contains(phrase):
			return false
	return true


# --------------------------------------------------------------------- UI --

func _ui_layer() -> CanvasLayer:
	var layer := _world.get_node_or_null("EventUI") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "EventUI"
		layer.layer = 40
		_world.add_child(layer)
	return layer


## The on-screen counter for the item hunt (stays until the task ends).
func _get_tracker() -> QuestTracker:
	if _tracker == null or not is_instance_valid(_tracker):
		_tracker = QuestTracker.new()
		_ui_layer().add_child(_tracker)
	return _tracker


func _toast_show(text: String, seconds: float = 3.0) -> void:
	if _world == null:
		return
	if _toast == null or not is_instance_valid(_toast):
		_toast = EventToast.new()
		_ui_layer().add_child(_toast)
	_toast.show_text(text, seconds)
