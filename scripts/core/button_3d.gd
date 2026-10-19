class_name Button3D
extends StaticBody3D
## A pressable 3D button that works with both the desktop and XR pointers.

signal pressed

const COLOR_IDLE := Color(0.18, 0.22, 0.32)
const COLOR_HOVER := Color(0.28, 0.38, 0.58)
const COLOR_SELECTED := Color(0.95, 0.55, 0.15)

var selected := false:
	set(value):
		selected = value
		_refresh()

var _hovered := false
var _material := StandardMaterial3D.new()
var _mesh := MeshInstance3D.new()


func _init(text: String = "Button", size: Vector2 = Vector2(1.6, 0.26)) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(size.x, size.y, 0.06)
	box.material = _material
	_mesh.mesh = box
	add_child(_mesh)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = box.size
	shape.shape = box_shape
	add_child(shape)
	var label := Label3D.new()
	label.text = text
	label.font = MathUtil.math_font()
	label.font_size = 36
	label.pixel_size = 0.0035
	label.outline_size = 0
	label.position = Vector3(0.0, 0.0, 0.035)
	add_child(label)
	_refresh()


func pointer_hover(hovering: bool) -> void:
	_hovered = hovering
	_refresh()


func pointer_pressed(_collider: Node, _hit_position: Vector3, _ray_origin: Vector3, _ray_dir: Vector3) -> void:
	var tween := create_tween()
	tween.tween_property(_mesh, "position:z", -0.03, 0.06)
	tween.tween_property(_mesh, "position:z", 0.0, 0.1)
	pressed.emit()


func _refresh() -> void:
	if selected:
		_material.albedo_color = COLOR_SELECTED
	else:
		_material.albedo_color = COLOR_HOVER if _hovered else COLOR_IDLE
	_material.emission_enabled = _hovered
	_material.emission = Color(0.2, 0.3, 0.5)
