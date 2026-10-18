extends Control
class_name ClassStage

# =====================================================================
#  The left half of the class screen: a drawn classroom (wall, window,
#  chalkboard, floor) where Matthew works at the active station.
#
#  set_station(station)   swap the prop Matthew works at
#  board(text)            write on the chalkboard
#  play_result(correct)   Matthew casts -> station reacts -> Matthew reacts
# =====================================================================

const MATTHEW_SHEET := "res://assets/models/teacher/Matthew_sprite_sheet.png"
## Teachers are single pixel-art images. "foot_pad" is the empty share of
## the image below the feet, so they stand on the floor instead of floating.
const TEACHERS := {
	"archimedes": {"path": "res://assets/models/npc/mr_archimedes.png", "pixel": true, "height": 0.62, "foot_pad": 0.114},
	"cruz": {"path": "res://assets/models/teacher/teacher_sprite.png", "pixel": true, "height": 0.56, "foot_pad": 0.0},
}

var matthew : StageActor
var teacher : StageActor
var station : Station = null
var bubble : SpeechBubble
var lecture_mode : bool = false

var _board_label : Label
var _board_hint : Label
var _station_holder : Control
var _slate : PanelContainer
var _slate_box : VBoxContainer
var _time : float = 0.0
var _stars : Array = []


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS

	_station_holder = Control.new()
	_station_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_station_holder)

	_board_label = Label.new()
	_board_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_board_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_board_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_board_label.add_theme_color_override("font_color", ClassTheme.CHALK)
	_board_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board_label)

	_board_hint = Label.new()
	_board_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_board_hint.add_theme_color_override("font_color", ClassTheme.GOLD_LIGHT)
	_board_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board_hint)

	teacher = StageActor.new()
	teacher.hide()
	add_child(teacher)

	matthew = StageActor.new()
	add_child(matthew)
	var tex := load(MATTHEW_SHEET) as Texture2D
	if tex:
		matthew.setup(tex, 3, 4, 170.0)

	# Parchment "magic slate" the teacher conjures for lecture demos
	_slate = PanelContainer.new()
	_slate.add_theme_stylebox_override("panel", ClassTheme.flat(ClassTheme.PARCHMENT, ClassTheme.GOLD, 18, 3, 16))
	_slate.hide()
	add_child(_slate)
	_slate_box = VBoxContainer.new()
	_slate_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_slate_box.add_theme_constant_override("separation", 14)
	_slate.add_child(_slate_box)

	bubble = SpeechBubble.new()
	add_child(bubble)

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(14):
		_stars.append(Vector3(rng.randf(), rng.randf(), rng.randf() * TAU))

	resized.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


# --------------------------------------------------------------- layout --

func _board_rect() -> Rect2:
	return Rect2(size.x * 0.06, size.y * 0.07, size.x * 0.56, size.y * 0.27)

func _window_rect() -> Rect2:
	return Rect2(size.x * 0.69, size.y * 0.07, size.x * 0.24, size.y * 0.27)

func floor_y() -> float:
	return size.y * 0.93

func _station_rect() -> Rect2:
	return Rect2(size.x * 0.40, size.y * 0.36, size.x * 0.56, floor_y() - size.y * 0.36)

func matthew_spot() -> float:
	return size.x * 0.84 if lecture_mode else size.x * 0.22

func teacher_spot() -> float:
	return size.x * 0.14

func _slate_rect() -> Rect2:
	return Rect2(size.x * 0.27, size.y * 0.05, size.x * 0.46, size.y * 0.78)


func _layout() -> void:
	if not is_inside_tree() or size.x < 10.0:
		return
	var br := _board_rect()
	_fit_board_text()
	_board_hint.position = Vector2(br.position.x, br.end.y - 28)
	_board_hint.size = Vector2(br.size.x, 24)
	_board_hint.add_theme_font_size_override("font_size", clampi(int(br.size.y * 0.13), 12, 20))

	var sr := _station_rect()
	_station_holder.position = sr.position
	_station_holder.size = sr.size
	if station:
		station.position = Vector2.ZERO
		station.size = sr.size

	if matthew and matthew.sheet:
		var h := clampf(size.y * 0.42, 110.0, 320.0)
		if absf(matthew.display_height - h) > 1.0:
			matthew.setup(matthew.sheet, matthew.hframes, matthew.vframes, h)
		matthew.position = Vector2(matthew_spot() - matthew.size.x / 2.0, floor_y() - matthew.size.y)

	if teacher and teacher.sheet:
		var th := clampf(size.y * float(teacher.get_meta("height_ratio", 0.6)), 120.0, 420.0)
		if absf(teacher.display_height - th) > 1.0:
			teacher.setup(teacher.sheet, 1, 1, th, teacher.pixel_art)
		var foot_pad := teacher.display_height * float(teacher.get_meta("foot_pad", 0.0))
		teacher.position = Vector2(teacher_spot() - teacher.size.x / 2.0, floor_y() - teacher.size.y + foot_pad)

	_slate.position = _slate_rect().position
	_slate.size = _slate_rect().size
	_slate.custom_minimum_size = Vector2.ZERO


# -------------------------------------------------------------- lecture --

func set_teacher(kind: String) -> void:
	var info : Dictionary = TEACHERS.get(kind, TEACHERS["archimedes"])
	var tex := load(info["path"]) as Texture2D
	if tex == null:
		return
	teacher.set_meta("height_ratio", info["height"])
	teacher.set_meta("foot_pad", info.get("foot_pad", 0.0))
	teacher.setup(tex, 1, 1, clampf(size.y * info["height"], 120.0, 420.0), info["pixel"])
	_layout()


## Teacher at the left, Matthew watching from the right, no station.
func enter_lecture() -> void:
	lecture_mode = true
	teacher.show()
	teacher.modulate.a = 1.0
	_station_holder.hide()
	matthew.face(StageActor.FACE_LEFT)
	_layout()
	matthew.face(StageActor.FACE_LEFT)


## The teacher steps aside and Matthew walks over to his station.
func leave_lecture() -> void:
	if not lecture_mode:
		return
	lecture_mode = false
	clear_slate()
	bubble.hide()
	var tw := create_tween()
	tw.tween_property(teacher, "modulate:a", 0.0, 0.35)
	tw.tween_callback(teacher.hide)
	_station_holder.show()
	await matthew.walk_to(matthew_spot(), 520.0)
	_layout()


## Shows the station during a lecture "demo" step (slate goes away).
func show_station_for_demo() -> void:
	clear_slate()
	_station_holder.show()


func slate() -> VBoxContainer:
	return _slate_box


func show_slate() -> void:
	_slate.show()
	ClassTheme.pop(_slate, 1.04)
	# The slate covers most of the chalkboard: hide the board writing so it
	# doesn't peek out around the edges.
	_board_label.hide()
	_board_hint.hide()


func clear_slate() -> void:
	for c in _slate_box.get_children():
		_slate_box.remove_child(c)
		c.queue_free()
	_slate.hide()
	_board_label.show()
	_board_hint.show()


# -------------------------------------------------------------- station --

func set_station(new_station: Station) -> void:
	if station == new_station:
		return
	if station:
		station.queue_free()
	station = new_station
	_station_holder.add_child(station)
	_layout()


## Keeps the chalk writing inside the board. A wrapping Label sizes its
## height from its *current* width, so after a narrow moment (the screen
## still opening) it could stay very tall and the centred text would sink
## below the board. Set the width first, shrink the font until the text
## fits, then set the final height.
func _fit_board_text() -> void:
	if size.x < 10.0:
		return
	var br := _board_rect()
	var area := br.size - Vector2(20, 30)
	_board_label.position = br.position + Vector2(10, 6)
	_board_label.size = Vector2(area.x, 0)
	var fs := clampi(int(br.size.y * 0.22), 14, 34)
	while true:
		_board_label.add_theme_font_size_override("font_size", fs)
		if fs <= 10 or _board_label.get_minimum_size().y <= area.y:
			break
		fs -= 2
	_board_label.size = Vector2(area.x, area.y)


func board(text: String, hint: String = "") -> void:
	_board_label.text = text
	_board_hint.text = hint
	_fit_board_text()
	if text != "":
		ClassTheme.flash(_board_label, Color(1.4, 1.4, 1.4))


func play_result(correct: bool) -> void:
	if station == null:
		return
	await matthew.cast(station.cast_color())
	if correct:
		matthew.hop()
		await station.success()
	else:
		matthew.slump()
		await station.fail()


# ----------------------------------------------------------------- draw --

func _draw() -> void:
	var w := size.x
	var h := size.y
	# Wall with a lighter band and a dark wainscot
	draw_rect(Rect2(0, 0, w, h), ClassTheme.WALL)
	draw_rect(Rect2(0, h * 0.40, w, h * 0.06), ClassTheme.WALL_LIGHT)
	draw_rect(Rect2(0, h * 0.62, w, h * 0.12), ClassTheme.WOOD_DARK)
	draw_rect(Rect2(0, h * 0.62, w, 4), ClassTheme.WOOD)
	# Floor planks
	draw_rect(Rect2(0, h * 0.74, w, h * 0.26), ClassTheme.FLOOR)
	var plank := ClassTheme.FLOOR.darkened(0.2)
	for i in range(1, 4):
		var y := h * 0.74 + h * 0.065 * i
		draw_line(Vector2(0, y), Vector2(w, y), plank, 2.0)
	for i in range(8):
		var y0 := h * 0.74 + h * 0.065 * (i % 4)
		var x := fmod(i * w * 0.23 + (i % 2) * w * 0.11, w)
		draw_line(Vector2(x, y0), Vector2(x, y0 + h * 0.065), plank, 2.0)

	_draw_window(_window_rect())

	# Chalkboard
	var br := _board_rect()
	draw_rect(br.grow(8), ClassTheme.BOARD_FRAME)
	draw_rect(br, ClassTheme.BOARD)
	draw_rect(Rect2(br.position.x + br.size.x * 0.1, br.end.y + 8, br.size.x * 0.8, 6), ClassTheme.WOOD)
	draw_rect(Rect2(br.position.x + br.size.x * 0.7, br.end.y + 3, 14, 5), ClassTheme.CHALK)

	# Floating dust motes for a magical feel
	for s in _stars:
		var p := Vector2(s.x * w, h * 0.38 + s.y * h * 0.3 + sin(_time + s.z) * 6.0)
		draw_circle(p, 1.6, Color(1, 0.95, 0.75, 0.35 + 0.25 * sin(_time * 2.0 + s.z)))


func _draw_window(r: Rect2) -> void:
	draw_rect(r.grow(6), ClassTheme.BOARD_FRAME)
	draw_rect(r, Color("#1d2346"))
	for s in _stars:
		var p := r.position + Vector2(s.x, s.y) * r.size
		var a := 0.5 + 0.5 * sin(_time * 1.5 + s.z)
		draw_circle(p, 1.4, Color(1, 1, 0.9, a))
	draw_circle(r.position + r.size * Vector2(0.72, 0.32), r.size.y * 0.16, Color("#f3e9c6"))
	draw_circle(r.position + r.size * Vector2(0.78, 0.27), r.size.y * 0.14, Color("#1d2346"))
	draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), ClassTheme.BOARD_FRAME, 5.0)
	draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), ClassTheme.BOARD_FRAME, 5.0)
