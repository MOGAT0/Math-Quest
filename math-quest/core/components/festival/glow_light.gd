extends RefCounted
class_name GlowLight

# =====================================================================
#  A small soft PointLight2D for things that should shine at night (the
#  night colour is a CanvasModulate, which darkens everything drawn; a
#  2D light is added on top of it). Used by festival lamps, fallen stars
#  and wish lanterns.
# =====================================================================

const TEXTURE_SIZE := 64
static var _texture : GradientTexture2D = null


## radius: glow radius in world pixels.
static func make(color: Color, radius: float, energy: float = 1.0) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = _soft_texture()
	light.texture_scale = radius * 2.0 / TEXTURE_SIZE
	light.color = color
	light.energy = energy
	return light


## Is it dark enough for lamps to be lit (6 PM - 5 AM)?
static func is_night() -> bool:
	return GameManager.current_time >= 18.0 or GameManager.current_time < 5.0


static func _soft_texture() -> GradientTexture2D:
	if _texture == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.55))
		_texture = GradientTexture2D.new()
		_texture.gradient = g
		_texture.fill = GradientTexture2D.FILL_RADIAL
		_texture.fill_from = Vector2(0.5, 0.5)
		_texture.fill_to = Vector2(1.0, 0.5)
		_texture.width = TEXTURE_SIZE
		_texture.height = TEXTURE_SIZE
	return _texture
