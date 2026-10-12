extends CharacterBody2D
class_name Merchant

@onready var merchant_sprite: Sprite2D = %merchant_sprite
@onready var vendors_ui: VendorShop = %VendorsUi
#@onready var key: Sprite2D = %key
@onready var key_label: Label = %key_label

#merchant main color
var color_find1 : Color = Color("#966888")
var color_find2 : Color = Color("#654956")

var has_customer : bool = false

func _ready() -> void:
	#key.hide()
	key_label.hide()
	randomize_merchant_style()

func _process(_delta: float) -> void:
	if has_customer:
		if Input.is_action_just_pressed("interact"):
			vendors_ui.start_shop()

func randomize_merchant_style() -> void:
	if merchant_sprite.material:
		merchant_sprite.material = merchant_sprite.material.duplicate()

	var shader_mat = merchant_sprite.material as ShaderMaterial

	if shader_mat:
		var random_main_color = Color(randf(), randf(), randf())
		var random_shade_color = random_main_color.darkened(0.4)

		shader_mat.set_shader_parameter("color_to_find_1", color_find1)
		shader_mat.set_shader_parameter("replacement_color_1", random_main_color)

		shader_mat.set_shader_parameter("color_to_find_2", color_find2)
		shader_mat.set_shader_parameter("replacement_color_2", random_shade_color)

#func _unhandled_input(_event: InputEvent) -> void:
	#if key.visible:
		#

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Player:
		#key.show()
		has_customer = true
		if OS.get_name().to_lower() not in ["android", "ios"]:
			key_label.show()
			



func _on_area_2d_body_exited(body: Node2D) -> void:
	if body is Player:
		#key.hide()
		has_customer = false
		key_label.hide()
		vendors_ui._leave_shop()
