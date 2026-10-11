@tool
class_name FakeLight2D
extends Node2D
## Drop-in stand-in for PointLight2D (no shadows). Lights are batched and
## drawn in one pass by FakeLightRenderer.

enum BlendMode { ADD, SUB }

const GROUP := &"fake_light_2d"

@export var enabled := true
@export var color := Color.WHITE
@export_range(0.0, 16.0, 0.01, "or_greater") var energy := 1.0
@export var blend_mode := BlendMode.ADD
## If true, the lit area is NOT tinted/darkened by CanvasModulate: the light fades
## from the ambient color to its own color (energy = strength, 0..1 is full range).
## If false, it behaves like PointLight2D (light is added on top of the ambient).
## Only applies to Add blend mode.
@export var ignore_canvas_modulate := true
## Light radius in world pixels (== texture width * texture_scale / 2 on a PointLight2D).
@export_range(1.0, 4096.0, 1.0, "or_greater", "suffix:px") var radius := 128.0:
	set(v):
		radius = v
		queue_redraw()
@export var offset := Vector2.ZERO:
	set(v):
		offset = v
		queue_redraw()


func _enter_tree() -> void:
	add_to_group(GROUP)
	if not Engine.is_editor_hint():
		FakeLightRenderer.ensure(get_tree())


func _draw() -> void:
	# editor-only radius gizmo; nothing is drawn at runtime
	if Engine.is_editor_hint():
		draw_arc(offset, radius, 0.0, TAU, 64, Color(color, 0.6), 1.0)
		draw_circle(offset, 3.0, color)
