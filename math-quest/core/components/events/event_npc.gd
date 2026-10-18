extends Area2D
class_name EventNPC

# =====================================================================
#  A visitor for a "riddle" event: an NPC sprite with a bobbing "!" that
#  the player walks up to and interacts with (same "interact" action as
#  the merchants).
# =====================================================================

signal interacted(npc: EventNPC)

const SHADOW_TEXTURE := preload("res://assets/environment/shadow.png")
const SHADOW_SCALE := 0.225   # same as the player's and Arith's shadow

## The player body (set by EventDirector). Any CharacterBody2D if unset.
var player_body : Node2D = null

var _sprite : Sprite2D
var _bang : Label
var _prompt : Label
var _player_near : bool = false
var _time : float = 0.0
var _leaving : bool = false
## World labels are drawn this many times bigger, then scaled down by the
## same amount: the camera zoom (~3-4x) would otherwise blow up small
## glyphs and blur them. Same size in the world, crisp on screen.
const LABEL_RES := 4.0
## Draw layer of the "Press [E]" prompt: an absolute z above the player
## (z 1) and the world, not y-sorted with the NPC (it is UI, not scenery).
const PROMPT_Z := 3
## Height of the "!" mark above the feet (follows the sprite's height).
var _mark_y : float = -48.0
## Middle of the NPC's head (the "Press [E]" prompt sits on it).
var _head_y : float = -20.0


func setup(def: Dictionary) -> void:
	# Soft shadow centred on the feet (this node's origin); added first so
	# it draws below the sprite.
	var shadow := Sprite2D.new()
	shadow.texture = SHADOW_TEXTURE
	shadow.scale = Vector2(SHADOW_SCALE, SHADOW_SCALE)
	shadow.self_modulate = Color(1, 1, 1, 0.6)
	add_child(shadow)

	_sprite = Sprite2D.new()
	_sprite.texture = load(str(def.get("npc", "res://assets/models/npc/Kid_Tim_idle_16x16.png")))
	_sprite.hframes = int(def.get("npc_frames", 4))
	_sprite.vframes = int(def.get("npc_vframes", 1))
	_sprite.frame = int(def.get("npc_frame", 3))          # facing the camera
	var s := float(def.get("npc_scale", 1.0))              # big single images (Mr. Archimedes)
	_sprite.scale = Vector2(s, s)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Bottom of the sprite (the feet) sits on this node's origin, which is
	# the point y-sort compares against the player and the world props.
	var frame_h := float(_sprite.texture.get_height()) / _sprite.vframes if _sprite.texture else 32.0
	_sprite.offset = Vector2(0, -frame_h / 2.0)
	add_child(_sprite)
	_mark_y = -frame_h * s - 16.0
	_head_y = -frame_h * s * 0.5

	_bang = Label.new()
	_bang.text = "!"
	_bang.add_theme_font_size_override("font_size", int(14 * LABEL_RES))
	_bang.add_theme_color_override("font_color", Color("#f5d76e"))
	_bang.add_theme_color_override("font_outline_color", Color("#241a10"))
	_bang.add_theme_constant_override("outline_size", int(4 * LABEL_RES))
	_bang.scale = Vector2.ONE / LABEL_RES
	_bang.position = Vector2(-3, _mark_y)
	add_child(_bang)

	# Keyboard hint (desktop only, see _on_body_entered), default font,
	# centred on the NPC's head
	_prompt = Label.new()
	_prompt.text = "Press [E] to interact"
	_prompt.visibility_layer = 2
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", int(8 * LABEL_RES))
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", int(3 * LABEL_RES))
	_prompt.scale = Vector2.ONE / LABEL_RES
	_prompt.z_as_relative = false
	_prompt.z_index = PROMPT_Z
	_prompt.hide()
	add_child(_prompt)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	_time += delta
	# Centre the (scaled-down) labels over the NPC
	if _bang:
		_bang.position = Vector2(-_bang.size.x * _bang.scale.x / 2.0, _mark_y + sin(_time * 4.0) * 2.0)
	if _prompt.visible:
		_prompt.position = Vector2(-_prompt.size.x * _prompt.scale.x / 2.0, _head_y - _prompt.size.y * _prompt.scale.y / 2.0)
	if _player_near and not _leaving and Input.is_action_just_pressed("interact"):
		interacted.emit(self)


func _is_player(body: Node2D) -> bool:
	return body == player_body if player_body else body is CharacterBody2D


func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		_player_near = true
		if OS.get_name().to_lower() not in ["android", "ios"]:
			_prompt.show()


func _on_body_exited(body: Node2D) -> void:
	if _is_player(body):
		_player_near = false
		_prompt.hide()


## The mark over the visitor's head: "!" (talk to me), "..." (waiting while
## you search), "?" (bring it back).
func set_mark(mark: String) -> void:
	if _bang:
		_bang.text = mark
		_bang.reset_size()   # shrink back for shorter marks ("..." -> "?")


## Thank-you hop, then fade away.
func leave() -> void:
	_leaving = true
	_bang.hide()
	_prompt.hide()
	var tw := create_tween()
	tw.tween_property(_sprite, "position:y", -6.0, 0.15)
	tw.tween_property(_sprite, "position:y", 0.0, 0.15)
	tw.tween_interval(0.6)
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)
