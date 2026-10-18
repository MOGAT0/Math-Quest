extends Node

# =====================================================================
#  Festivals (autoload "FestivalDirector").
#
#  A major event in data/events.json with a "festival" block turns its
#  day into a festival in the village:
#    - the festival ground is set up around the world's %event_location
#      marker (world.gd): a stage carpet with the host (Mr. Archimedes)
#      on the marker, the booths in a ring around it, lanterns in between;
#    - the main quest arrow points to the host; talking to him gives the
#      stamp card (HUD) and every booth gets a side-quest arrow;
#    - each booth is a BoothGame (class station + NumberPad): KP, tokens,
#      a stamp and best scores; the prize booth trades tokens for prizes;
#    - a festival can also have a "hunt" (EggHunt): items hidden around
#      the ground, found with a warm/cold meter instead of arrows; it is
#      one more stamp on the card;
#    - or "lanterns" (LanternQuest): unlit lanterns to light by solving
#      their number puzzles; also one stamp;
#    - "decor": "halloween" adds glowing jack-o'-lanterns;
#    - "ending": "snow_gift" lets snow fall and a friend ("gift") bring
#      Matthew a present (a collectible) after the badge;
#    - all stamps -> back to the host for the festival badge + bonus KP.
#  Every festival also has the Traveling Trader ("trader" in the data),
#  who buys the special event tokens (sold at each prize booth, effect
#  "special_token") for KP. Special tokens are saved per id in
#  festival_profile.special (JSON {token_id: count}).
#  A festival with "opens_at" (an hour, e.g. 18) only sets up when the
#  clock reaches it; before that a toast says it starts tonight. The
#  "ending" plays when the badge is won: "lanterns" sends wish lanterns
#  up, "pumpkin" puts a prize pumpkin with a ribbon on the stage.
#  Midnight (or sleeping) ends the day and the festival packs up.
#
#  Saved in DataManager: "festival" (one row per festival per year:
#  stamps, badge) and "festival_profile" (tokens, best scores, prizes).
# =====================================================================

signal festival_started(event_id: String)
signal stamp_earned(event_id: String, booth_id: String)
signal badge_earned(event_id: String)
signal festival_closed(event_id: String)

## Marker in world.tscn where every major event is held.
const LOCATION_NAME := "event_location"
## Where that marker stands, used if a world doesn't have it.
const DEFAULT_LOCATION := Vector2(118.008, 721.942)
const RING_RADIUS := 80.0
const RING_SQUASH := 0.7        # the ring is an ellipse (top-down view)
const LANTERN_RADIUS := 1.3     # x RING_RADIUS
const KEY_PREFIX := "fest_"
const PRIZE_BOOTH_ID := "prize_booth"
const TRADER_ID := "trader"
const EVENTS_PATH := "res://data/events.json"

var _world : Node2D = null
var _event : Dictionary = {}    # today's major event (has "festival")
var _nodes : Array = []
var _spots : Array = []
var _keys : Array = []
var _host : EventNPC = null
var _host_marker : Marker2D = null
var _booths : Dictionary = {}   # booth id -> FestivalBooth
var _joined : bool = false
var _prev_target : Marker2D = null
var _card : StampCard = null
var _hunt : EggHunt = null
var _quest : LanternQuest = null
var _giver : EventNPC = null
## Calendar day whose "starts tonight" toast was already shown.
var _announced_day : int = -1
var _trader : Dictionary = {}   # data/events.json "trader"


func _ready() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(EVENTS_PATH)) if FileAccess.file_exists(EVENTS_PATH) else null
	if typeof(parsed) == TYPE_DICTIONARY and typeof(parsed.get("trader")) == TYPE_DICTIONARY:
		_trader = parsed["trader"]
	CalendarManager.day_started.connect(func(_d): _start_today.call_deferred())
	CalendarManager.day_ended.connect(func(_d):
		_stop_waiting()
		close_festival()
	)
	DataManager.data_cleared.connect(close_festival)


## The world scene registers itself (world.gd _ready). A new world means
## the old festival nodes are gone: start again from the save.
func register_world(world: Node2D) -> void:
	if world != _world:
		_release_world_refs()
		_forget()
	_world = world
	_start_today.call_deferred()


func is_active() -> bool:
	return not _event.is_empty()


## The festival needs the main quest arrow (pointing to its host) until
## its badge is earned; after that the arrow is free again (e.g. the
## night-time "go home" arrow from daylight_cycle.gd).
func holds_main_target() -> bool:
	return is_active() and (not _badge_earned() or _gift_waiting())


func _badge_earned() -> bool:
	return bool(_row(_event_id(), CalendarManager.year).get("badge", false))


## Today's major event with a festival, or {}.
func today_festival() -> Dictionary:
	for e in CalendarManager.events_on(CalendarManager.season, CalendarManager.day):
		if typeof(e.get("festival")) == TYPE_DICTIONARY:
			return e
	return {}


func _start_today() -> void:
	if _world == null or not is_instance_valid(_world) or is_active():
		return
	var e := today_festival()
	if e.is_empty():
		return
	# An evening festival waits for its hour (checked on every clock tick)
	var opens := int(e["festival"].get("opens_at", -1))
	if opens >= 0 and GameManager.current_time < opens:
		if _announced_day != CalendarManager.absolute_day():
			_announced_day = CalendarManager.absolute_day()
			EventDirector._toast_show("%s %s tonight at %s!" % [e.get("icon", "🎉"), e.get("title", "Festival"), hour_text(opens)], 4.0)
		if not GameManager.hour_changed.is_connected(_on_hour_changed):
			GameManager.hour_changed.connect(_on_hour_changed)
		return
	_stop_waiting()
	# One frame later, so the wake-up quest target (location.gd) is set
	# first and the festival arrow replaces it.
	await get_tree().process_frame
	if is_active() or _world == null or not is_instance_valid(_world):
		return
	start(e)


func _on_hour_changed(_hour: float) -> void:
	var e := today_festival()
	if e.is_empty():
		_stop_waiting()
	elif GameManager.current_time >= int(e["festival"].get("opens_at", 0)):
		_stop_waiting()
		_start_today()


func _stop_waiting() -> void:
	if GameManager.hour_changed.is_connected(_on_hour_changed):
		GameManager.hour_changed.disconnect(_on_hour_changed)


## 18 -> "6 PM", 12 -> "12 noon", 0 -> "midnight".
static func hour_text(hour: int) -> String:
	if hour == 0 or hour == 24:
		return "midnight"
	if hour == 12:
		return "12 noon"
	return "%d %s" % [hour % 12 if hour % 12 != 0 else 12, "AM" if hour < 12 else "PM"]


## The calendar's line for today's festival, e.g. "starts tonight at 6 PM"
## ("" when it is already on, or there is none).
func opening_note() -> String:
	var e := today_festival()
	if e.is_empty() or is_active():
		return ""
	var opens := int(e["festival"].get("opens_at", -1))
	if opens < 0 or GameManager.current_time >= opens:
		return ""
	return "%s %s tonight at %s!" % [e.get("icon", ""), e.get("title", "Festival"), hour_text(opens)]


# ------------------------------------------------------------------ setup --

func start(e: Dictionary) -> void:
	_event = e
	var fest : Dictionary = e["festival"]
	var center := _pick_center()

	var rug := FestivalDecor.new()
	_world.add_child(rug)
	rug.global_position = center
	_nodes.append(rug)

	_host = EventNPC.new()
	_host.setup(fest.get("host", {}))
	_host.player_body = _world.get("player")
	_match_player_layer(_host)
	_world.add_child(_host)
	_host.global_position = center
	_host.interacted.connect(func(_n): _on_host_talk())
	_nodes.append(_host)
	_spots.append(center)
	_host_marker = Marker2D.new()
	_host.add_child(_host_marker)

	var list := _booth_defs()
	var n := list.size()
	for i in range(n):
		var def : Dictionary = list[i]
		var a := -PI / 2.0 + TAU * i / n
		var p := _ring_point(center, a, RING_RADIUS)
		var booth := FestivalBooth.new()
		booth.setup(def)
		booth.player_body = _world.get("player")
		_match_player_layer(booth)
		_world.add_child(booth)
		booth.global_position = p
		booth.set_mark("")
		booth.interacted.connect(func(_n): _on_booth(def))
		_booths[str(def.get("id", ""))] = booth
		_nodes.append(booth)
		_spots.append(p)
		# A lantern between this booth and the next
		var la := a + PI / n
		var lantern := FestivalDecor.Lantern.new()
		_match_player_layer(lantern)
		_world.add_child(lantern)
		lantern.global_position = _ring_point(center, la, RING_RADIUS * LANTERN_RADIUS)
		_nodes.append(lantern)
	if str(fest.get("decor", "")) == "halloween":
		for i in range(n):
			var ja := -PI / 2.0 + TAU * i / n + PI / n
			var jack := FestivalDecor.JackOLantern.new()
			_match_player_layer(jack)
			_world.add_child(jack)
			jack.global_position = _ring_point(center, ja, RING_RADIUS * 0.55)
			_nodes.append(jack)
	for s in _spots:
		EventDirector.reserve_spot(s)

	_prev_target = GameManager.target_location
	if not _badge_earned():
		GameManager.target_location = _host_marker

	var row := _row(str(e.get("id", "")), CalendarManager.year)
	if not row.is_empty():
		_joined = true
		_after_join()
		if bool(row.get("badge", false)) and str(fest.get("ending", "")) == "snow_gift":
			var snow := Snowfall.new()
			_world.add_child(snow)
			snow.global_position = center
			_nodes.append(snow)
			_spawn_gift_giver()
	else:
		_host.set_mark("!")
	EventDirector._toast_show("%s The %s is today! Find %s." % [e.get("icon", "🎉"), e.get("title", "festival"), fest.get("host", {}).get("name", "the host")])
	festival_started.emit(str(e.get("id", "")))


## The festival's booths plus its prize booth.
func _booth_defs() -> Array:
	var fest : Dictionary = _event.get("festival", {})
	var list : Array = fest.get("booths", []).duplicate()
	if typeof(fest.get("prize_booth")) == TYPE_DICTIONARY:
		var prize : Dictionary = fest["prize_booth"].duplicate()
		prize["id"] = PRIZE_BOOTH_ID
		list.append(prize)
	if not _trader.is_empty():
		var trader := _trader.duplicate()
		trader["id"] = TRADER_ID
		list.append(trader)
	return list


## A point on the ring around the host. Exact (not snapped to the
## navigation mesh), so the booths always stand evenly around the
## %event_location marker.
func _ring_point(center: Vector2, angle: float, radius: float) -> Vector2:
	return center + Vector2(cos(angle), sin(angle) * RING_SQUASH) * radius


## The middle of the festival ground: the world's %event_location marker.
func _pick_center() -> Vector2:
	var marker = _world.get(LOCATION_NAME)
	if not (marker is Node2D):
		marker = _world.get_node_or_null("%" + LOCATION_NAME)
	if marker is Node2D and is_instance_valid(marker):
		return marker.global_position
	return DEFAULT_LOCATION


## On a festival day, random visitors keep off the festival ground (they
## roll in the morning, just before the festival is set up).
func blocks_spot(p: Vector2) -> bool:
	if _world == null or not is_instance_valid(_world) or today_festival().is_empty():
		return false
	return p.distance_to(_pick_center()) < RING_RADIUS * LANTERN_RADIUS + 24.0


# ---------------------------------------------------------------- talking --

func _on_host_talk() -> void:
	var fest : Dictionary = _event.get("festival", {})
	var host : Dictionary = fest.get("host", {})
	var who := str(host.get("name", "Host"))
	var row := _row(_event_id(), CalendarManager.year)
	if not _joined:
		_talk(who, str(host.get("welcome", "Welcome to the festival!")), ["Let's go!"], func(_i): _join())
	elif bool(row.get("badge", false)):
		_talk(who, "You already earned the %s. Enjoy the festival!" % str(fest.get("badge", {}).get("title", "badge")), ["Thanks!"], func(_i): pass)
	elif _all_stamped():
		_talk(who, str(host.get("finished", "You did it!")), ["Thank you!"], func(_i): _give_badge())
	else:
		_talk(who, str(host.get("reminder", "Visit every booth!")), ["OK!"], func(_i): pass)


func _join() -> void:
	_joined = true
	DataManager.insert("festival", {"event_id": _event_id(), "year": CalendarManager.year, "stamps": "[]", "badge": false})
	_after_join()


## Stamp card on screen, arrows on the booths still to do.
func _after_join() -> void:
	var stamps := stamps_for(_event_id())
	var row := _row(_event_id(), CalendarManager.year)
	_host.set_mark("!" if _all_stamped() and not bool(row.get("badge", false)) else "")
	for id in _booths:
		var booth : FestivalBooth = _booths[id]
		if stamps.has(id):
			booth.set_done()
		else:
			booth.set_mark("!")
			if id != PRIZE_BOOTH_ID and id != TRADER_ID:   # shops get no arrow
				_add_arrow(booth, KEY_PREFIX + id)
		if id == PRIZE_BOOTH_ID or id == TRADER_ID:
			booth.set_mark("")   # shops, not tasks (their icon is on the awning)
	_get_card().show_card("%s %s" % [_event.get("icon", "🎉"), _event.get("title", "Festival")],
		_stamp_defs(), stamps, tokens())
	_start_hunt()
	_start_lanterns()


## Everything that earns a stamp: the hunt (if any) and the game booths.
func _stamp_defs() -> Array:
	var fest : Dictionary = _event.get("festival", {})
	var list : Array = []
	if typeof(fest.get("hunt")) == TYPE_DICTIONARY:
		list.append(fest["hunt"])
	if typeof(fest.get("lanterns")) == TYPE_DICTIONARY:
		list.append(fest["lanterns"])
	list.append_array(fest.get("booths", []))
	return list


func _on_booth(def: Dictionary) -> void:
	if str(def.get("id", "")) == TRADER_ID:
		# The trader deals with anyone, stamp card or not
		var shop := TraderPopup.new()
		_ui_layer().add_child(shop)
		shop.open(def)
		_set_player_frozen(true)
		shop.closed.connect(func(): _set_player_frozen(false))
		return
	if not _joined:
		EventDirector._toast_show("Get your stamp card from %s first!" % str(_event.get("festival", {}).get("host", {}).get("name", "the host")))
		return
	var id := str(def.get("id", ""))
	if id == PRIZE_BOOTH_ID:
		var shop := PrizeBooth.new()
		_ui_layer().add_child(shop)
		shop.open(def, _event.get("festival", {}).get("prizes", []))
		_set_player_frozen(true)
		shop.closed.connect(func(): _set_player_frozen(false))
		return
	var game := BoothGame.new()
	_ui_layer().add_child(game)
	game.open(def, best_score(id), stamps_for(_event_id()).has(id))
	_set_player_frozen(true)
	game.finished.connect(func(result: Dictionary):
		_set_player_frozen(false)
		if bool(result.get("completed", false)):
			_booth_done(def, result)
	)


## Rewards for a finished booth game, the stamp and the best score.
func _booth_done(def: Dictionary, result: Dictionary) -> void:
	var id := str(def.get("id", ""))
	if int(result.get("kp", 0)) > 0:
		_give_kp(int(result["kp"]))
	add_tokens(int(result.get("tokens", 0)))
	if bool(result.get("new_best", false)):
		_set_best(id, int(result.get("score", 0)))
	_stamp(id, "Stamp collected! +%d KP  +%d 🪙" % [int(result.get("kp", 0)), int(result.get("tokens", 0))])
	_get_card().set_tokens(tokens())


## Stamp one activity (once): save it, drop its arrow, tick its stall and
## the card; when it was the last one, send the player back to the host.
func _stamp(id: String, toast: String) -> void:
	var stamps := stamps_for(_event_id())
	if stamps.has(id):
		return
	stamps.append(id)
	_save_stamps(stamps)
	GameManager.sideQuest_locations.erase(KEY_PREFIX + id)
	_keys.erase(KEY_PREFIX + id)
	if _booths.has(id):
		_booths[id].set_done()
	_get_card().stamp(id)
	stamp_earned.emit(_event_id(), id)
	if _all_stamped():
		_host.set_mark("!")
		EventDirector._toast_show("All stamps collected! Go back to %s for your badge!" % str(_event.get("festival", {}).get("host", {}).get("name", "the host")))
	else:
		EventDirector._toast_show(toast)


# ------------------------------------------------------------------- hunt --

## Hide the hunt's eggs (only the ones not found yet today).
func _start_hunt() -> void:
	var hunt = _event.get("festival", {}).get("hunt")
	if typeof(hunt) != TYPE_DICTIONARY or (_hunt and is_instance_valid(_hunt)):
		return
	var progress := _progress()
	var found := int(progress.get("eggs", 0))
	var golden := bool(progress.get("golden", false))
	if found >= int(hunt.get("eggs", 10)) and (golden or not bool(hunt.get("golden", false))):
		return
	_hunt = EggHunt.new()
	_world.add_child(_hunt)
	_nodes.append(_hunt)
	_hunt.begin(_world, hunt, _pick_center(), _spots, _ui_layer(), found, golden)
	_hunt.egg_found.connect(_on_egg_found)
	_hunt.hunt_finished.connect(_on_hunt_finished)
	_hunt.golden_found.connect(_on_golden_found)


func _on_egg_found(found: int, _total: int) -> void:
	var progress := _progress()
	progress["eggs"] = found
	_save_progress(progress)


func _on_hunt_finished() -> void:
	var hunt : Dictionary = _event.get("festival", {}).get("hunt", {})
	var kp := int(hunt.get("kp", 0))
	var tok := int(hunt.get("tokens", 0))
	if kp > 0:
		_give_kp(kp)
	add_tokens(tok)
	_stamp(str(hunt.get("id", "hunt")), "All eggs found! +%d KP  +%d 🪙" % [kp, tok])
	_get_card().set_tokens(tokens())


## The golden egg: a harder riddle (one grade up) for bonus tokens. Left
## unsolved, the egg goes back where it was.
func _on_golden_found(at: Vector2) -> void:
	var hunt : Dictionary = _event.get("festival", {}).get("hunt", {})
	var grade := FestivalQuestions.current_grade()
	var harder := "g%d" % mini(grade.trim_prefix("g").to_int() + 1, 3)
	var popup := RiddlePopup.new()
	_ui_layer().add_child(popup)
	var special := str(hunt.get("special_name", "Golden Egg"))
	popup.open({"name": "✨ The " + special, "intro": "A riddle is written on the %s!" % special.to_lower(),
		"reward": int(hunt.get("golden_kp", 15))}, EventDirector._fresh_question(harder))
	_set_player_frozen(true)
	popup.finished.connect(func(solved: bool, mistakes: int):
		_set_player_frozen(false)
		if not solved:
			if _hunt and is_instance_valid(_hunt):
				_hunt.respawn_golden(at)
			return
		var kp := int(hunt.get("golden_kp", 15))
		if mistakes > 0:
			kp = maxi(1, kp / 2)
		var tok := int(hunt.get("golden_tokens", 3))
		_give_kp(kp)
		add_tokens(tok)
		var progress := _progress()
		progress["golden"] = true
		_save_progress(progress)
		_get_card().set_tokens(tokens())
		EventDirector._toast_show("✨ Golden egg riddle solved! +%d KP  +%d 🪙" % [kp, tok])
	)


# -------------------------------------------------------------- lanterns --

## Put up the lanterns to light (the lit ones stay lit after a reload).
func _start_lanterns() -> void:
	var quest = _event.get("festival", {}).get("lanterns")
	if typeof(quest) != TYPE_DICTIONARY or (_quest and is_instance_valid(_quest)):
		return
	_quest = LanternQuest.new()
	_world.add_child(_quest)
	_nodes.append(_quest)
	var lit : Array = _progress().get("lanterns", [])
	_quest.begin(_world, quest, _pick_center(), _spots, _ui_layer(), lit,
		CalendarManager.absolute_day() * 31 + CalendarManager.year)
	_quest.lantern_asked.connect(_on_lantern_asked)
	_quest.lantern_lit.connect(_on_lantern_lit)
	_quest.all_lit.connect(_on_all_lanterns_lit)


## A sealed lantern: solve its number puzzle to light it.
func _on_lantern_asked(index: int) -> void:
	var popup := RiddlePopup.new()
	_ui_layer().add_child(popup)
	var quest : Dictionary = _event.get("festival", {}).get("lanterns", {})
	popup.open({"name": str(quest.get("puzzle_title", "🏮 Sealed Lantern")),
		"intro": str(quest.get("puzzle_intro", "Solve the number puzzle to light the lantern!")),
		"reward": 0}, FestivalQuestions.lantern_puzzle(FestivalQuestions.current_grade()))
	_set_player_frozen(true)
	popup.finished.connect(func(solved: bool, _mistakes: int):
		_set_player_frozen(false)
		if solved and _quest and is_instance_valid(_quest):
			_quest.light(index)
	)


func _on_lantern_lit(_index: int, _count: int) -> void:
	var progress := _progress()
	progress["lanterns"] = _quest.lit.duplicate()
	_save_progress(progress)


func _on_all_lanterns_lit() -> void:
	var quest : Dictionary = _event.get("festival", {}).get("lanterns", {})
	var kp := int(quest.get("kp", 0))
	var tok := int(quest.get("tokens", 0))
	if kp > 0:
		_give_kp(kp)
	add_tokens(tok)
	_stamp(str(quest.get("id", "lanterns")), "%s +%d KP  +%d 🪙" % [str(quest.get("done_text", "Every lantern is glowing!")), kp, tok])
	_get_card().set_tokens(tokens())


## Hunt progress today: {"eggs": n, "golden": bool} (extra field of the
## festival row; old rows simply don't have it yet).
func _progress() -> Dictionary:
	var parsed = JSON.parse_string(str(_row(_event_id(), CalendarManager.year).get("progress", "{}")))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _save_progress(progress: Dictionary) -> void:
	var row := _row(_event_id(), CalendarManager.year)
	if not row.is_empty():
		DataManager.update_by_id("festival", "id", int(row["id"]), {"progress": JSON.stringify(progress)})


func _give_badge() -> void:
	var fest : Dictionary = _event.get("festival", {})
	var row := _row(_event_id(), CalendarManager.year)
	if row.is_empty() or bool(row.get("badge", false)):
		return
	DataManager.update_by_id("festival", "id", int(row["id"]), {"badge": true})
	# Festival done: no main arrow until the next one is set (at 9 PM the
	# night-time arrow points home)
	if GameManager.target_location == _host_marker:
		GameManager.target_location = null
	var bonus := int(fest.get("bonus_kp", 0))
	if bonus > 0:
		_give_kp(bonus)
	_host.set_mark("")
	var badge : Dictionary = fest.get("badge", {})
	EventDirector._toast_show("%s %s earned!  +%d KP" % [badge.get("icon", "🏅"), badge.get("title", "Festival badge"), bonus], 4.0)
	var fx := Control.new()
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer().add_child(fx)
	ClassTheme.confetti(fx)
	get_tree().create_timer(4.0).timeout.connect(fx.queue_free)
	if str(fest.get("ending", "")) == "lanterns":
		var lanterns := LanternRelease.new()
		# Night of Lanterns: the lit lanterns themselves lift off their posts
		if _quest and is_instance_valid(_quest) and not _quest.lit.is_empty():
			var center := _pick_center()
			for p in _quest.lit_positions():
				lanterns.starts.append(p - center)
			_quest.release_all()
			get_tree().create_timer(4.2).timeout.connect(func(): EventDirector._toast_show("🏮 Happy Night of Lanterns!", 4.0))
		_world.add_child(lanterns)
		lanterns.global_position = _pick_center()
	elif str(fest.get("ending", "")) == "snow_gift":
		var snow := Snowfall.new()
		_world.add_child(snow)
		snow.global_position = _pick_center()
		_nodes.append(snow)
		_spawn_gift_giver()
	elif str(fest.get("ending", "")) == "pumpkin":
		# The prize pumpkin stays on the stage until the fair packs up
		var pumpkin := PrizePumpkin.new()
		_match_player_layer(pumpkin)
		_world.add_child(pumpkin)
		pumpkin.global_position = _pick_center() + Vector2(34, 8)
		_nodes.append(pumpkin)
	badge_earned.emit(_event_id())


func _all_stamped() -> bool:
	var stamps := stamps_for(_event_id())
	for b in _stamp_defs():
		if not stamps.has(str(b.get("id", ""))):
			return false
	return true


# ---------------------------------------------------------------- closing --

## The day is over (sleep): the festival packs up.
func close_festival() -> void:
	if not is_active():
		return
	var id := _event_id()
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	for key in _keys:
		GameManager.sideQuest_locations.erase(key)
	for s in _spots:
		EventDirector.release_spot(s)
	if GameManager.target_location == _host_marker:
		GameManager.target_location = _prev_target if is_instance_valid(_prev_target) else null
	if _card and is_instance_valid(_card):
		_card.hide()
	_forget()
	festival_closed.emit(id)


# ------------------------------------------------------------------ gift --

## After the badge, a friend brings Matthew a present ("gift" in the data).
func _gift_waiting() -> bool:
	var gift = _event.get("festival", {}).get("gift")
	return typeof(gift) == TYPE_DICTIONARY and not has_collectible(str(gift.get("id", "")))


func _spawn_gift_giver() -> void:
	if not _gift_waiting() or (_giver and is_instance_valid(_giver)):
		return
	var gift : Dictionary = _event["festival"]["gift"]
	_giver = EventNPC.new()
	_giver.setup(gift)
	_giver.player_body = _world.get("player")
	_match_player_layer(_giver)
	_world.add_child(_giver)
	_giver.global_position = _pick_center() + Vector2(-34, 10)
	_giver.set_mark("!")
	_giver.interacted.connect(func(_n): _on_gift_talk())
	_nodes.append(_giver)
	var marker := Marker2D.new()
	_giver.add_child(marker)
	GameManager.target_location = marker


func _on_gift_talk() -> void:
	var gift : Dictionary = _event.get("festival", {}).get("gift", {})
	_talk(str(gift.get("giver", "Friend")), str(gift.get("line", "This is for you!")), ["Thank you!"], func(_i):
		var owned := collectibles()
		if not owned.has(str(gift.get("id", ""))):
			owned.append(str(gift.get("id", "")))
			_save_profile({"collectibles": JSON.stringify(owned)})
		EventDirector._toast_show("%s You got %s!" % [gift.get("icon", "🎁"), gift.get("name", "a gift")], 4.0)
		if _giver and is_instance_valid(_giver):
			for c in _giver.get_children():
				if c is Marker2D and GameManager.target_location == c:
					GameManager.target_location = null
			_giver.leave()
		_giver = null
	)


## The old world is gone (scene reloaded): its markers were freed with
## it, so the quest arrows must not keep pointing at them.
func _release_world_refs() -> void:
	for key in _keys:
		GameManager.sideQuest_locations.erase(key)
	var target = GameManager.target_location
	if target == _host_marker or not is_instance_valid(target):
		GameManager.target_location = null
	_stop_waiting()


## Drop the in-memory festival (nodes are already gone or being freed).
func _forget() -> void:
	_event = {}
	_nodes = []
	_spots = []
	_keys = []
	_booths = {}
	_host = null
	_host_marker = null
	_hunt = null
	_quest = null
	_giver = null
	_joined = false


# ------------------------------------------------------------------- save --

func _event_id() -> String:
	return str(_event.get("id", ""))


## This festival's row for a year ({} = the player didn't join).
func _row(event_id: String, year: int) -> Dictionary:
	for r in DataManager.select_all("festival"):
		if str(r.get("event_id", "")) == event_id and int(r.get("year", 0)) == year:
			return r
	return {}


func stamps_for(event_id: String) -> Array:
	var parsed = JSON.parse_string(str(_row(event_id, CalendarManager.year).get("stamps", "[]")))
	return parsed if typeof(parsed) == TYPE_ARRAY else []


func _save_stamps(stamps: Array) -> void:
	var row := _row(_event_id(), CalendarManager.year)
	if not row.is_empty():
		DataManager.update_by_id("festival", "id", int(row["id"]), {"stamps": JSON.stringify(stamps)})


func attended(event_id: String, year: int) -> bool:
	return not _row(event_id, year).is_empty()


## "badge" | "attended" | "missed" | "today" | "upcoming" | "past" for
## a major event this year (journal / calendar).
func status_of(event_id: String, season: int, day: int) -> String:
	var cal := CalendarManager
	var row := _row(event_id, cal.year)
	if bool(row.get("badge", false)):
		return "badge"
	if season == cal.season and day == cal.day:
		return "today"
	var past := season < cal.season or (season == cal.season and day < cal.day)
	if not past:
		return "upcoming"
	if not row.is_empty():
		return "attended"
	for e in cal.major_events:
		if str(e.get("id", "")) == event_id and typeof(e.get("festival")) == TYPE_DICTIONARY:
			return "missed"
	return "past"


func _profile() -> Dictionary:
	var rows : Array = DataManager.select_all("festival_profile")
	if rows.is_empty():
		DataManager.insert("festival_profile", {"tokens": 0, "best": "{}", "collectibles": "[]"})
		rows = DataManager.select_all("festival_profile")
	return rows[0] if not rows.is_empty() else {}


func _save_profile(values: Dictionary) -> void:
	var p := _profile()
	if not p.is_empty():
		DataManager.update_by_id("festival_profile", "id", int(p["id"]), values)


func tokens() -> int:
	return int(_profile().get("tokens", 0))


func add_tokens(amount: int) -> void:
	if amount != 0:
		_save_profile({"tokens": maxi(0, tokens() + amount)})


func _best_scores() -> Dictionary:
	var parsed = JSON.parse_string(str(_profile().get("best", "{}")))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## Best score of a booth, or null when never played.
func best_score(booth_id: String):
	var best := _best_scores()
	return best[booth_id] if best.has(booth_id) else null


func _set_best(booth_id: String, score: int) -> void:
	var best := _best_scores()
	best[booth_id] = score
	_save_profile({"best": JSON.stringify(best)})


func collectibles() -> Array:
	var parsed = JSON.parse_string(str(_profile().get("collectibles", "[]")))
	return parsed if typeof(parsed) == TYPE_ARRAY else []


func has_collectible(prize_id: String) -> bool:
	return collectibles().has(prize_id)


## Spend tokens on a prize and apply it. False when it can't be bought.
func buy_prize(prize: Dictionary) -> bool:
	var cost := int(prize.get("cost", 1))
	var effect : Dictionary = prize.get("effect", {})
	var id := str(prize.get("id", ""))
	if tokens() < cost:
		return false
	if bool(effect.get("collectible", false)):
		if has_collectible(id):
			return false
		var owned := collectibles()
		owned.append(id)
		_save_profile({"collectibles": JSON.stringify(owned)})
	if bool(effect.get("special_token", false)):
		var special := special_tokens()
		special[id] = int(special.get(id, 0)) + 1
		_save_profile({"special": JSON.stringify(special)})
	add_tokens(-cost)
	if effect.has("stamina"):
		GameManager.refill_stamina(float(effect["stamina"]))
	if effect.has("kp"):
		_give_kp(int(effect["kp"]))
	if _card and is_instance_valid(_card):
		_card.set_tokens(tokens())
	return true


## Special event tokens owned: {token_id: count}.
func special_tokens() -> Dictionary:
	var parsed = JSON.parse_string(str(_profile().get("special", "{}")))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## Every special token of the year (from all festival prize booths), in
## calendar order.
func special_token_defs() -> Array:
	var events : Array = CalendarManager.major_events.duplicate()
	events.sort_custom(func(a, b): return int(a.get("season", 0)) * 100 + int(a.get("day", 0)) < int(b.get("season", 0)) * 100 + int(b.get("day", 0)))
	var out : Array = []
	for e in events:
		var fest = e.get("festival", {})
		if typeof(fest) != TYPE_DICTIONARY:
			continue
		for p in fest.get("prizes", []):
			if bool(p.get("effect", {}).get("special_token", false)):
				out.append(p)
	return out


## The trader buys `count` special tokens; returns the KP paid (0 = none).
func trade_special_tokens(token_id: String, count: int) -> int:
	var special := special_tokens()
	var have := int(special.get(token_id, 0))
	count = mini(count, have)
	if count <= 0:
		return 0
	var value := 50
	for t in special_token_defs():
		if str(t.get("id", "")) == token_id:
			value = int(t.get("kp_value", 50))
	special[token_id] = have - count
	_save_profile({"special": JSON.stringify(special)})
	var kp := value * count
	_give_kp(kp)
	return kp


func _give_kp(amount: int) -> void:
	var total := GameManager.kp_amount + amount
	db.query("UPDATE progress SET kp = %d WHERE is_active = true" % total)
	GameManager._update_KP()


# --------------------------------------------------------------------- UI --

func _add_arrow(holder: Node2D, key: String) -> void:
	var marker := Marker2D.new()
	holder.add_child(marker)
	GameManager.sideQuest_locations[key] = marker
	_keys.append(key)


func _match_player_layer(node: CanvasItem) -> void:
	var player = _world.get("player")
	node.z_index = player.z_index if player is CanvasItem else 1
	node.z_as_relative = player.z_as_relative if player is CanvasItem else true


func _set_player_frozen(frozen: bool) -> void:
	var player = _world.get("player") if _world else null
	if player is Node:
		player.set_physics_process(not frozen)


func _talk(who: String, line: String, buttons: Array, on_choice: Callable) -> void:
	var popup := TalkPopup.new()
	_ui_layer().add_child(popup)
	popup.open(who, line, buttons)
	_set_player_frozen(true)
	popup.chosen.connect(func(i: int):
		_set_player_frozen(false)
		on_choice.call(i)
	)


## Same CanvasLayer as the random events ("EventUI" on the world).
func _ui_layer() -> CanvasLayer:
	var layer := _world.get_node_or_null("EventUI") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "EventUI"
		layer.layer = 40
		_world.add_child(layer)
	return layer


func _get_card() -> StampCard:
	if _card == null or not is_instance_valid(_card):
		_card = StampCard.new()
		_ui_layer().add_child(_card)
	return _card
