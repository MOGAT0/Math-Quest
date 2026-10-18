extends Control
class_name StageActor

# =====================================================================
#  A character on the class stage, puppeted from a sprite sheet.
#  The control's bottom-centre is the actor's feet; every squash/hop
#  pivots there.  All actions are awaitable:  await matthew.hop()
# =====================================================================

const FACE_FRONT := "front"
const FACE_LEFT := "left"
const FACE_RIGHT := "right"
const FACE_BACK := "back"

## Sheet layout. rows maps a facing to the sheet row; idle_col is the
## standing frame inside that row.
var sheet : Texture2D
var hframes : int = 3
var vframes : int = 4
var rows : Dictionary = {FACE_FRONT: 0, FACE_LEFT: 1, FACE_RIGHT: 2, FACE_BACK: 3}
var idle_col : int = 1
var display_height : float = 170.0
var pixel_art : bool = true
var _talk_time : float = -1.0     # >= 0 while talking

var _sprite : Sprite2D
var _facing : String = FACE_FRONT
var _walking : bool = false
var _walk_time : float = 0.0
var _bob_time : float = 0.0
var _busy : bool = false
var _glow : float = 0.0:
	set(v):
		_glow = v
		queue_redraw()
var _glow_color : Color = ClassTheme.GOLD_LIGHT


## pixel_art=false smooths painted art (e.g. the Mr. Archimedes portrait).
func setup(texture: Texture2D, columns: int = 3, row_count: int = 4, height: float = 170.0, pixel_art: bool = true) -> void:
	sheet = texture
	hframes = columns
	vframes = row_count
	display_height = height
	self.pixel_art = pixel_art
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _sprite == null:
		_sprite = Sprite2D.new()
		add_child(_sprite)
	_sprite.texture = sheet
	_sprite.hframes = hframes
	_sprite.vframes = vframes
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if pixel_art else CanvasItem.TEXTURE_FILTER_LINEAR
	var frame_size := Vector2(sheet.get_width() / float(hframes), sheet.get_height() / float(vframes))
	var s := display_height / frame_size.y
	_sprite.scale = Vector2(s, s)
	_sprite.offset = Vector2(0, -frame_size.y / 2.0)   # pivot at the feet
	custom_minimum_size = Vector2(frame_size.x * s, display_height)
	size = custom_minimum_size
	_place_sprite()
	face(FACE_FRONT)


func _ready() -> void:
	resized.connect(_place_sprite)


func _place_sprite() -> void:
	if _sprite:
		_sprite.position = Vector2(size.x / 2.0, size.y)


func _process(delta: float) -> void:
	if _sprite == null:
		return
	if _walking:
		_walk_time += delta
		var col := int(_walk_time * 8.0) % hframes
		_sprite.frame_coords = Vector2i(col, _row_for(_facing))
		if hframes == 1:
			# Single-image art: a little waddle stands in for walk frames
			_sprite.rotation = sin(_walk_time * 14.0) * 0.05
	elif not _busy:
		# Gentle breathing bob while idle, a livelier bounce while talking
		_bob_time += delta
		var breathe := 1.0 + sin(_bob_time * 2.4) * 0.015
		if _talk_time >= 0.0:
			_talk_time += delta
			breathe += absf(sin(_talk_time * 9.0)) * 0.025
		_sprite.scale.y = absf(_sprite.scale.x) * breathe


func set_talking(on: bool) -> void:
	_talk_time = 0.0 if on else -1.0


func face(dir: String) -> void:
	_facing = dir
	if _sprite == null:
		return
	_sprite.frame_coords = Vector2i(mini(idle_col, hframes - 1), _row_for(dir))
	_sprite.rotation = 0.0
	if vframes == 1:
		# No turn frames: mirror the single image instead
		_sprite.flip_h = dir == FACE_LEFT


func _row_for(dir: String) -> int:
	return mini(int(rows.get(dir, 0)), vframes - 1)


# --------------------------------------------------------------- actions --

## Walks (with the walk-cycle frames) so the actor's feet end at `x`
## in the parent's coordinates.
func walk_to(x: float, speed: float = 260.0) -> void:
	var target := x - size.x / 2.0
	var dist := absf(target - position.x)
	if dist < 4.0:
		return
	face(FACE_RIGHT if target > position.x else FACE_LEFT)
	_walking = true
	_walk_time = 0.0
	var tw := create_tween()
	tw.tween_property(self, "position:x", target, dist / speed)
	await tw.finished
	_walking = false
	face(FACE_FRONT)


func hop(times: int = 2) -> void:
	_busy = true
	var base_y := _sprite.position.y
	var tw := create_tween()
	for i in range(times):
		tw.tween_property(_sprite, "position:y", base_y - display_height * 0.22, 0.16) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(_sprite, "position:y", base_y, 0.16) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	_busy = false


func slump() -> void:
	_busy = true
	var s := absf(_sprite.scale.x)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_sprite, "scale", Vector2(s * 1.08, s * 0.86), 0.18)
	tw.tween_property(_sprite, "modulate", Color(0.7, 0.7, 0.8), 0.18)
	tw.chain().tween_interval(0.45)
	tw.chain().tween_property(_sprite, "scale", Vector2(s, s), 0.25).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(_sprite, "modulate", Color.WHITE, 0.25)
	await tw.finished
	_busy = false


## Stretches up with a glowing aura: the "casting" pose.
func cast(color: Color = ClassTheme.GOLD_LIGHT, hold: float = 0.35) -> void:
	_busy = true
	_glow_color = color
	face(FACE_FRONT)
	var s := absf(_sprite.scale.x)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_sprite, "scale", Vector2(s * 0.94, s * 1.1), 0.2).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "_glow", 1.0, 0.2)
	tw.chain().tween_interval(hold)
	tw.chain().tween_property(_sprite, "scale", Vector2(s, s), 0.2)
	tw.parallel().tween_property(self, "_glow", 0.0, 0.35)
	await tw.finished
	_busy = false


func _draw() -> void:
	if _glow <= 0.0:
		return
	var c := Vector2(size.x / 2.0, size.y * 0.55)
	for i in range(3):
		var col := _glow_color
		col.a = 0.18 * _glow * (3 - i) / 3.0
		draw_circle(c, size.y * (0.35 + i * 0.12) * (0.8 + _glow * 0.2), col)
