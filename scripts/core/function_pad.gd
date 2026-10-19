extends Node3D
## Floating 3D keypad for typing a function in XR: point and pull the trigger
## on the keys. Shown only for topics with an editable function.

signal function_submitted(text: String)

const KEY_SIZE := Vector2(0.28, 0.2)
const KEY_GAP := 0.03
const COLUMNS := 6
const DISPLAY_COLOR := Color(1.0, 0.95, 0.6)
const ERROR_COLOR := Color(1.0, 0.45, 0.4)
const OK_COLOR := Color(0.5, 1.0, 0.6)

var text := ""

var _spec := {}
var _preset_index := -1
var _keys_root := Node3D.new()
var _board := MeshInstance3D.new()
var _title := Label3D.new()
var _display := Label3D.new()
var _status := Label3D.new()


func _ready() -> void:
	var board_material := StandardMaterial3D.new()
	board_material.albedo_color = Color(0.05, 0.06, 0.09, 0.85)
	board_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var board_mesh := BoxMesh.new()
	board_mesh.material = board_material
	_board.mesh = board_mesh
	add_child(_board)
	for label: Label3D in [_title, _display, _status]:
		label.font = MathUtil.math_font()
		label.pixel_size = 0.0035
		label.outline_size = 0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		# Draw after the translucent board, or it washes the text out.
		label.render_priority = 1
		add_child(label)
	_title.font_size = 40
	_display.font_size = 44
	_display.modulate = DISPLAY_COLOR
	_display.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_display.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_status.font_size = 30
	add_child(_keys_root)
	visible = false


## Rebuilds the keypad for a topic's function spec ({} = no keys).
## Visibility is left to the caller.
func set_spec(spec: Dictionary) -> void:
	_spec = spec
	for child in _keys_root.get_children():
		child.queue_free()
	if spec.is_empty():
		return
	text = spec.text
	_preset_index = -1
	var vars: PackedStringArray = spec.variables
	var keys: Array[String] = [
		"7", "8", "9", "(", ")", "⌫",
		"4", "5", "6", "*", "/", "^",
		"1", "2", "3", "+", "-", ".",
		"0", "π", "e", "sin", "cos", "tan",
		"sqrt", "ln", "exp", "abs", ",", "C",
	]
	# Variable keys go first on an extra row.
	var var_row: Array[String] = []
	for v in vars:
		var_row.append(v)
	keys = var_row + keys

	var width := COLUMNS * (KEY_SIZE.x + KEY_GAP) - KEY_GAP
	var left := -width * 0.5 + KEY_SIZE.x * 0.5
	var row := 0
	var col := 0
	var top := -0.56
	for key in keys:
		_add_key(key, Vector3(left + col * (KEY_SIZE.x + KEY_GAP), top - row * (KEY_SIZE.y + KEY_GAP), 0.0),
				KEY_SIZE, _on_key.bind(key))
		col += 1
		if col == COLUMNS or (row == 0 and col == var_row.size()):
			col = 0
			row += 1
	# Bottom row: cycle presets, and plot.
	row += 1 if col > 0 else 0
	var bottom := top - row * (KEY_SIZE.y + KEY_GAP) - 0.04
	var half := (width - KEY_GAP) * 0.5
	_add_key("Example ▸", Vector3(-width * 0.5 + half * 0.5, bottom, 0.0), Vector2(half, KEY_SIZE.y + 0.04), _next_preset)
	_add_key("Plot ✓", Vector3(width * 0.5 - half * 0.5, bottom, 0.0), Vector2(half, KEY_SIZE.y + 0.04), _submit)

	var height := -bottom + KEY_SIZE.y * 0.5 + 0.2
	(_board.mesh as BoxMesh).size = Vector3(width + 0.16, height, 0.03)
	_board.position = Vector3(0.0, 0.18 - height * 0.5, -0.05)
	_title.position = Vector3(-width * 0.5, 0.06, 0.0)
	_title.text = "Type a function   " + spec.label
	_display.position = Vector3(-width * 0.5, -0.02, 0.0)
	_display.width = width / _display.pixel_size
	_status.position = Vector3(-width * 0.5, -0.42, 0.0)
	set_status("", OK_COLOR)
	_refresh_display()


func set_text(value: String) -> void:
	text = value
	_refresh_display()


func set_status(message: String, color: Color) -> void:
	_status.text = message
	_status.modulate = color


func show_result(error: String) -> void:
	if error.is_empty():
		set_status("✓ Plotted", OK_COLOR)
	else:
		set_status("✗ " + error, ERROR_COLOR)


func _add_key(label: String, pos: Vector3, size: Vector2, callback: Callable) -> void:
	var key := Button3D.new(label, size)
	key.position = pos
	key.pressed.connect(callback)
	_keys_root.add_child(key)


func _on_key(key: String) -> void:
	match key:
		"⌫":
			# Delete a whole function name (with its bracket) at once.
			for name in ["sqrt(", "sin(", "cos(", "tan(", "exp(", "abs(", "ln("]:
				if text.ends_with(name):
					text = text.left(-name.length())
					_refresh_display()
					return
			text = text.left(-1)
		"C":
			text = ""
		"sin", "cos", "tan", "sqrt", "ln", "exp", "abs":
			text += key + "("
		_:
			text += key
	set_status("", OK_COLOR)
	_refresh_display()


func _next_preset() -> void:
	var presets: Array = _spec.get("presets", [])
	if presets.is_empty():
		return
	_preset_index = (_preset_index + 1) % presets.size()
	text = presets[_preset_index]
	_refresh_display()
	_submit()


func _submit() -> void:
	function_submitted.emit(text)


func _refresh_display() -> void:
	# Smaller text for long formulas, so two lines fit above the status line.
	_display.font_size = 44 if text.length() <= 22 else 32
	_display.text = text + "▏"
