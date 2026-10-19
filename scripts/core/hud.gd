extends CanvasLayer
## Desktop HUD: crosshair, FPS/mode readout, controls help, topic buttons,
## a slot for topic-specific controls (sliders) and short toast messages.

signal topic_requested(index: int)
signal function_submitted(text: String)

var mode_text := "Desktop"
var topic_text := ""

var _root := Control.new()
var _crosshair := Crosshair.new()
var _status := Label.new()
var _help := Label.new()
var _hint := Label.new()
var _toast := Label.new()
var _topic_slot := VBoxContainer.new()
var _function_row := HBoxContainer.new()
var _function_label := Label.new()
var _function_edit := LineEdit.new()
var _function_presets := OptionButton.new()
var _function_status := Label.new()
var _topic_buttons: Array[Button] = []
var _toast_tween: Tween


## Small cross in the screen centre; turns green over something interactive.
class Crosshair:
	extends Control

	var active := false:
		set(value):
			if value != active:
				active = value
				queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var color := Color(0.4, 1.0, 0.5) if active else Color(1, 1, 1, 0.85)
		var gap := 4.0
		var arm := 10.0
		for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(c + d * gap, c + d * (gap + arm), Color(0, 0, 0, 0.6), 4.0)
			draw_line(c + d * gap, c + d * (gap + arm), color, 2.0)
		if active:
			draw_arc(c, 16.0, 0.0, TAU, 32, color, 2.0)


func setup(titles: PackedStringArray) -> void:
	var theme := Theme.new()
	theme.default_font = MathUtil.math_font()
	theme.default_font_size = 16
	_root.theme = theme
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_crosshair)

	# Topic buttons along the top edge.
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 12)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.add_theme_constant_override("separation", 8)
	_root.add_child(bar)
	for i in titles.size():
		var button := Button.new()
		button.text = "%d  %s" % [i + 1, titles[i]]
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(170, 36)
		button.pressed.connect(topic_requested.emit.bind(i))
		bar.add_child(button)
		_topic_buttons.append(button)

	# Status + controls panel, top-left.
	var panel := _panel()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2(12, 56)
	_root.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_status.add_theme_font_size_override("font_size", 15)
	box.add_child(_status)
	_help.add_theme_font_size_override("font_size", 14)
	_help.modulate = Color(0.85, 0.9, 1.0)
	box.add_child(_help)
	_help.text = _controls_text()

	# Topic hint + topic controls, bottom-left.
	var bottom := _panel()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(bottom)
	var bottom_box := VBoxContainer.new()
	bottom.add_child(bottom_box)
	_hint.add_theme_font_size_override("font_size", 14)
	bottom_box.add_child(_hint)
	_build_function_row(bottom_box)
	bottom_box.add_child(_topic_slot)

	# Toast, bottom-centre.
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 60)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast.add_theme_font_size_override("font_size", 20)
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.modulate.a = 0.0
	_root.add_child(_toast)


func _process(_delta: float) -> void:
	_status.text = "FPS: %d   |   Mode: %s\nTopic: %s" % [Engine.get_frames_per_second(), mode_text, topic_text]


func set_topic(index: int, title: String, hint: String, controls: Control) -> void:
	topic_text = title
	for i in _topic_buttons.size():
		_topic_buttons[i].set_pressed_no_signal(i == index)
	_hint.text = hint
	for child in _topic_slot.get_children():
		child.queue_free()
	if controls:
		_topic_slot.add_child(controls)


## Shows the function editor for `spec` (see CalcTopic.get_function_spec), or
## hides it when the spec is empty.
func set_function_spec(spec: Dictionary) -> void:
	_function_row.visible = not spec.is_empty()
	_function_status.visible = false
	if spec.is_empty():
		return
	_function_label.text = spec.label
	_function_edit.text = spec.text
	_function_edit.placeholder_text = "e.g. " + ", ".join(PackedStringArray(spec.presets.slice(1, 3)))
	_function_presets.clear()
	_function_presets.add_item("Examples…")
	for preset: String in spec.presets:
		_function_presets.add_item(preset)


func show_function_result(text: String, error: String) -> void:
	_function_edit.text = text
	_function_status.visible = true
	if error.is_empty():
		_function_status.text = "✓ Plotted"
		_function_status.modulate = Color(0.5, 1.0, 0.6)
	else:
		_function_status.text = "✗ " + error
		_function_status.modulate = Color(1.0, 0.5, 0.45)


## True while the function text box has keyboard focus (so keys type, not move).
func is_typing() -> bool:
	return _function_edit.has_focus()


func _build_function_row(parent: Control) -> void:
	_function_row.add_theme_constant_override("separation", 6)
	parent.add_child(_function_row)
	_function_label.add_theme_font_size_override("font_size", 16)
	_function_row.add_child(_function_label)
	_function_edit.custom_minimum_size = Vector2(260, 0)
	_function_edit.text_submitted.connect(_on_function_entered)
	_function_row.add_child(_function_edit)
	var plot := Button.new()
	plot.text = "Plot"
	plot.focus_mode = Control.FOCUS_NONE
	plot.pressed.connect(func() -> void: _on_function_entered(_function_edit.text))
	_function_row.add_child(plot)
	_function_presets.focus_mode = Control.FOCUS_NONE
	_function_presets.item_selected.connect(_on_preset_selected)
	_function_row.add_child(_function_presets)
	_function_status.add_theme_font_size_override("font_size", 14)
	_function_status.visible = false
	parent.add_child(_function_status)
	_function_row.visible = false


func _on_function_entered(text: String) -> void:
	_function_edit.release_focus()
	function_submitted.emit(text)


func _on_preset_selected(index: int) -> void:
	_function_presets.select(0)
	if index > 0:
		_on_function_entered(_function_presets.get_item_text(index))


func set_crosshair_active(active: bool) -> void:
	_crosshair.active = active


func set_desktop_mode(desktop: bool) -> void:
	_crosshair.visible = desktop


func toggle_help() -> void:
	_help.visible = not _help.visible


func toast(message: String, seconds: float = 3.0) -> void:
	_toast.text = message
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.09, 0.72)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _controls_text() -> String:
	var keys := {}
	for action in ["move_forward", "move_left", "move_back", "move_right", "move_down",
			"move_up", "sprint", "topic_action", "toggle_xr", "screenshot", "toggle_help"]:
		keys[action] = InputSetup.key_label(action)
	return "\n".join(PackedStringArray([
		"{move_forward} {move_left} {move_back} {move_right}  move    {move_down} / {move_up}  down / up    {sprint}  sprint".format(keys),
		"Hold right mouse  look around",
		"Left click  grab / select / press",
		"1-4  switch topic    Arrows / wheel / {topic_action}  topic controls".format(keys),
		"{toggle_xr}  toggle XR    {screenshot}  screenshot    {toggle_help}  hide help".format(keys),
	]))
