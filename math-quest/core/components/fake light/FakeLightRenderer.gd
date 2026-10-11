class_name FakeLightRenderer
extends CanvasLayer
## Created automatically by the first FakeLight2D that enters the tree.
## Draws one full-screen quad that lights the whole scene in a single pass.

const MAX_LIGHTS := 64
const SHADER := preload("res://assets/shaders/fake_light_2d.gdshader")

static var _instance: FakeLightRenderer
static var _custom_ramp: Texture2D

var _rect: ColorRect
var _mat: ShaderMaterial
var _canvas_modulate: CanvasModulate
var _search_timer := 0.0
var _pos := PackedVector4Array()
var _rgb := PackedVector4Array()


static func ensure(tree: SceneTree) -> void:
	if is_instance_valid(_instance):
		return
	_instance = FakeLightRenderer.new()
	tree.root.add_child.call_deferred(_instance)


## Shared falloff for all lights. Left->right = center->edge of the radius.
## Works exactly like a radial GradientTexture2D used on PointLight2D.
static func set_falloff_ramp(ramp: Texture2D) -> void:
	_custom_ramp = ramp
	if is_instance_valid(_instance) and _instance._mat:
		_instance._mat.set_shader_parameter("falloff_ramp", ramp)


func _ready() -> void:
	name = "FakeLightRenderer"
	layer = 1 # above the world, below UI layers (put UI on layer 2+)

	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("falloff_ramp", _custom_ramp if _custom_ramp else _default_ramp())

	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _mat
	add_child(_rect)

	_pos.resize(MAX_LIGHTS)
	_rgb.resize(MAX_LIGHTS)


func _process(delta: float) -> void:
	var vp := get_viewport()
	var view_size := vp.get_visible_rect().size

	# --- ambient from CanvasModulate (re-read every frame so tweens work) ---
	if not is_instance_valid(_canvas_modulate) or not _canvas_modulate.is_inside_tree():
		_search_timer -= delta
		if _search_timer <= 0.0:
			_search_timer = 0.5
			_canvas_modulate = _find_canvas_modulate()
	var ambient := Color.WHITE
	if is_instance_valid(_canvas_modulate) and _canvas_modulate.is_visible_in_tree():
		ambient = _canvas_modulate.color

	# --- gather visible lights ---
	var count := 0
	for n in get_tree().get_nodes_in_group(FakeLight2D.GROUP):
		var l := n as FakeLight2D
		if l == null or not l.enabled or not l.is_visible_in_tree() or l.get_viewport() != vp:
			continue
		var xf := l.get_global_transform_with_canvas()
		var p := xf * l.offset
		var r := l.radius * absf(xf.get_scale().x)
		if p.x + r < 0.0 or p.y + r < 0.0 or p.x - r > view_size.x or p.y - r > view_size.y:
			continue # off-screen
		var ignore := l.ignore_canvas_modulate and l.blend_mode == FakeLight2D.BlendMode.ADD
		var e := l.energy * (1.0 if l.blend_mode == FakeLight2D.BlendMode.ADD else -1.0)
		_pos[count] = Vector4(p.x, p.y, maxf(r, 0.001), 1.0 if ignore else 0.0)
		if ignore:
			_rgb[count] = Vector4(l.color.r, l.color.g, l.color.b, e)
		else:
			_rgb[count] = Vector4(l.color.r * e, l.color.g * e, l.color.b * e, e)
		count += 1
		if count >= MAX_LIGHTS:
			break

	# nothing to light -> skip the pass (and the screen copy) entirely
	_rect.visible = count > 0
	if count == 0:
		return

	_mat.set_shader_parameter("ambient", Vector3(ambient.r, ambient.g, ambient.b))
	_mat.set_shader_parameter("view_size", view_size)
	_mat.set_shader_parameter("light_count", count)
	_mat.set_shader_parameter("light_pos_radius", _pos)
	_mat.set_shader_parameter("light_rgb", _rgb)


func _find_canvas_modulate() -> CanvasModulate:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var found := scene.find_children("*", "CanvasModulate", true, false)
	return found[0] as CanvasModulate if not found.is_empty() else null


static func _default_ramp() -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 256
	return t
