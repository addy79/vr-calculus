extends Node3D
## Floating 3D menu with one button per calculus topic (usable in XR and desktop).

signal topic_requested(index: int)

var _buttons: Array[Button3D] = []
var _board_size := Vector3.ZERO
var _board_center := Vector3.ZERO


func setup(titles: PackedStringArray) -> void:
	var height := 0.36 * titles.size() + 0.45
	var board := MeshInstance3D.new()
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(1.9, height, 0.03)
	var board_material := StandardMaterial3D.new()
	board_material.albedo_color = Color(0.05, 0.06, 0.09, 0.85)
	board_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	board_mesh.material = board_material
	board.mesh = board_mesh
	board.position = Vector3(0.0, -height * 0.5 + 0.25, -0.05)
	_board_size = board_mesh.size
	_board_center = board.position
	add_child(board)
	var title := Label3D.new()
	title.text = "Calculus Explorer"
	title.font = MathUtil.math_font()
	title.font_size = 44
	title.pixel_size = 0.0035
	title.position = Vector3(0.0, 0.08, 0.0)
	add_child(title)
	for i in titles.size():
		var button := Button3D.new(titles[i])
		button.position = Vector3(0.0, -0.25 - 0.36 * i, 0.0)
		button.pressed.connect(topic_requested.emit.bind(i))
		add_child(button)
		_buttons.append(button)


## The four front corners of the menu board in global space.
func get_corners() -> PackedVector3Array:
	var half := _board_size * 0.5
	var corners := PackedVector3Array()
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			corners.append(global_transform * (_board_center + Vector3(half.x * sx, half.y * sy, 0.0)))
	return corners


func set_selected(index: int) -> void:
	for i in _buttons.size():
		_buttons[i].selected = i == index
