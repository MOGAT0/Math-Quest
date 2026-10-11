class_name FakeLightMap2D
extends CanvasLayer
## Renders every FakeLight2D once into a (low-res) light map, then multiplies the
## world by it. Add ONE of these to your scene and remove your CanvasModulate.
##
## Everything on canvas layers BELOW this node's `layer` gets lit.
## Put HUD / unlit stuff on a CanvasLayer with a higher layer number.

const LIGHT_SHADER := preload("res://assets/shaders/fake_light_2d.gdshader")
const COMPOSITE_SHADER := preload("res://assets/shaders/fake_light_composite.gdshader")

## Replaces CanvasModulate: the darkness the world has where no light reaches.
@export var ambient_color := Color(0.12, 0.12, 0.18):
	set(value):
		ambient_color = value
		if is_instance_valid(_ambient):
			_ambient.color = value

## 0.5 is usually indistinguishable from 1.0 for soft lights, and ~4x cheaper.
@export_range(0.125, 1.0, 0.125) var resolution_scale := 0.5

## Allows energy > 1 (over-bright). Also enable rendering/viewport/hdr_2d in Project Settings.
@export var hdr := false

@export_range(0.0, 2.0, 0.05) var dither := 1.0:
	set(value):
		dither = value
		if is_instance_valid(_composite_mat):
			_composite_mat.set_shader_parameter("dither", value)

## Converts every PointLight2D in the current scene into a FakeLight2D at startup.
@export var replace_point_lights_on_ready := false

var _vp: SubViewport
var _ambient: ColorRect
var _composite: ColorRect
var _composite_mat: ShaderMaterial
var _mats: Array[ShaderMaterial] = [] # index matches FakeLight2D.BlendMode


func _ready() -> void:
	_build()
	RenderingServer.frame_pre_draw.connect(_sync)
	if replace_point_lights_on_ready:
		replace_point_lights.call_deferred()


func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_sync):
		RenderingServer.frame_pre_draw.disconnect(_sync)


func _build() -> void:
	# Light map viewport with its OWN 2D world so the proxies never show up in the main one.
	_vp = SubViewport.new()
	_vp.world_2d = World2D.new()
	_vp.transparent_bg = false
	_vp.disable_3d = true
	_vp.gui_disable_input = true
	_vp.use_hdr_2d = hdr
	_vp.size = Vector2i(2, 2)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(_vp)

	# Ambient fill lives on its own CanvasLayer so the camera transform doesn't move it.
	var amb_layer := CanvasLayer.new()
	amb_layer.layer = -128
	_vp.add_child(amb_layer)
	_ambient = ColorRect.new()
	_ambient.color = ambient_color
	_ambient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amb_layer.add_child(_ambient)
	_ambient.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# One material per blend mode, built from the same .gdshader.
	for token in ["blend_add", "blend_sub", "blend_mix"]:
		var sh := Shader.new()
		sh.code = LIGHT_SHADER.code.replace("blend_add", token)
		var mat := ShaderMaterial.new()
		mat.shader = sh
		_mats.append(mat)

	# Full-screen multiply onto the main viewport.
	_composite_mat = ShaderMaterial.new()
	_composite_mat.shader = COMPOSITE_SHADER
	_composite_mat.set_shader_parameter("light_map", _vp.get_texture())
	_composite_mat.set_shader_parameter("dither", dither)
	_composite = ColorRect.new()
	_composite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_composite.material = _composite_mat
	add_child(_composite)
	_composite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# Runs right before drawing, after cameras and scripts have moved everything.
func _sync() -> void:
	if not is_instance_valid(_vp):
		return
	var main := get_viewport()
	var size := main.get_visible_rect().size
	if size.x < 1.0 or size.y < 1.0:
		return

	var target := Vector2i(
		maxi(1, ceili(size.x * resolution_scale)),
		maxi(1, ceili(size.y * resolution_scale)))
	if _vp.size != target:
		_vp.size = target
	if _vp.use_hdr_2d != hdr:
		_vp.use_hdr_2d = hdr

	var mode := SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	if _vp.render_target_update_mode != mode:
		_vp.render_target_update_mode = mode
	if not visible:
		return

	# Same camera as the main view, scaled to the light map's resolution.
	_vp.canvas_transform = main.get_canvas_transform().scaled(Vector2(target) / size)

	for light in FakeLight2D.all_lights:
		light.push_to_map(_vp, _mats)


## Swaps PointLight2D nodes for FakeLight2D copies (shadows are dropped).
func replace_point_lights(root: Node = null) -> void:
	if root == null:
		root = get_tree().current_scene
	if root == null:
		return
	for n in root.find_children("*", "PointLight2D", true, false):
		var p := n as PointLight2D
		var f := FakeLight2D.new()
		f.name = str(p.name) + "Fake"
		f.transform = p.transform
		f.visible = p.visible
		f.z_index = p.z_index
		f.enabled = p.enabled
		f.color = p.color
		f.energy = p.energy
		f.blend_mode = p.blend_mode as FakeLight2D.BlendMode
		f.texture = p.texture
		f.offset = p.offset
		f.texture_scale = p.texture_scale
		f.height = p.height
		var parent := p.get_parent()
		parent.add_child(f)
		parent.move_child(f, p.get_index())
		p.queue_free()
