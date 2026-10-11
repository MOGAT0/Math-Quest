extends MeshInstance2D

@export var canvas_modulate : CanvasModulate

func _process(_delta: float) -> void:

	var c := Color.WHITE
	if canvas_modulate and canvas_modulate.is_visible_in_tree():
		c = canvas_modulate.color
	(material as ShaderMaterial).set_shader_parameter("ambient", Vector3(c.r, c.g, c.b))
 
