extends Node
## Automated smoke test. Run with:  godot --path ~/"VR APPs"/vr-calculus -- --autotest
## Drives the app through real input events, checks each topic reacts,
## saves screenshots to res://screenshots and quits with the failure count.

var main: Node3D
var _failures := 0
var _checks := 0


func _ready() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	print("[TEST] %s  %s" % ["PASS" if condition else "FAIL", message])
	if not condition:
		_failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _mouse_button(button: MouseButton, pressed: bool, pos: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = pos
	event.global_position = pos
	Input.parse_input_event(event)


func _click(pos: Vector2) -> void:
	_mouse_button(MOUSE_BUTTON_LEFT, true, pos)
	await _wait(0.1)
	_mouse_button(MOUSE_BUTTON_LEFT, false, pos)
	await _wait(0.1)


func _hold(action: String, seconds: float) -> void:
	Input.action_press(action)
	await _wait(seconds)
	Input.action_release(action)


## Types into the focused control with real key events, then presses Enter.
func _type(text: String) -> void:
	for c in text:
		var event := InputEventKey.new()
		event.pressed = true
		event.unicode = c.unicode_at(0)
		Input.parse_input_event(event)
		event = event.duplicate()
		event.pressed = false
		Input.parse_input_event(event)
		await _wait(0.02)
	for pressed in [true, false]:
		var enter := InputEventKey.new()
		enter.keycode = KEY_ENTER
		enter.physical_keycode = KEY_ENTER
		enter.pressed = pressed
		Input.parse_input_event(enter)
	await _wait(0.3)


func _shot(file_name: String) -> void:
	var path: String = await main.take_screenshot(file_name)
	print("[TEST] screenshot  ", path)


func _run() -> void:
	var camera: Camera3D = main.desktop_camera
	await _wait(1.5)
	print("[TEST] mode: %s, XR available: %s" % [main.hud.mode_text, main.xr_available])
	print("[TEST] info  renderer: %s" % RenderingServer.get_current_rendering_method())
	var window_size: Vector2 = main.get_viewport().get_visible_rect().size
	print("[TEST] info  window %s: menu fits=%s scale=%.2f" % [window_size, main.fit_menu_to_size(window_size), main.menu_scale])
	for probe_size: Vector2 in [Vector2(800, 1000), Vector2(800, 600), Vector2(1920, 1080)]:
		print("[TEST] info  window %s: menu fits=%s scale=%.2f" % [probe_size, main.fit_menu_to_size(probe_size), main.menu_scale])
	main.fit_menu_to_size(window_size)
	await _shot("00_overview_surface_plot.png")

	# --- Desktop camera ---------------------------------------------------
	var start := camera.global_position
	await _hold("move_forward", 0.6)
	await _wait(0.4)
	_check(camera.global_position.distance_to(start) > 0.5,
			"W flies the camera forward (%.2f m)" % camera.global_position.distance_to(start))
	var height := camera.global_position.y
	await _hold("move_up", 0.4)
	await _wait(0.3)
	_check(camera.global_position.y > height + 0.2, "E raises the camera")
	var forward := -camera.global_basis.z
	_mouse_button(MOUSE_BUTTON_RIGHT, true, Vector2(800, 450))
	await _wait(0.05)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(120, 0)
	Input.parse_input_event(motion)
	await _wait(0.05)
	_mouse_button(MOUSE_BUTTON_RIGHT, false, Vector2(800, 450))
	await _wait(0.1)
	_check(forward.angle_to(-camera.global_basis.z) > 0.1, "right-drag rotates the view")
	camera.reset_view(main.DESKTOP_START, main.LOOK_TARGET)
	await _wait(0.3)

	# --- F1 toggle ----------------------------------------------------------
	main.set_xr_mode(true)
	_check(main.xr_active == main.xr_available, "F1 toggle: XR only activates when a runtime exists")
	main.set_xr_mode(false)

	# --- Surface plot ---------------------------------------------------------
	var topic: CalcTopic = main.current_topic
	var before := topic.get_debug_state()
	await _hold("topic_right", 0.5)
	await _hold("topic_up", 0.3)
	var after := topic.get_debug_state()
	_check(after.x > before.x and after.y > before.y, "arrow keys move the surface marker (%.2f, %.2f) -> (%.2f, %.2f)" % [before.x, before.y, after.x, after.y])
	_check(not is_equal_approx(after.fx, before.fx) and after.tangent_x_axis != before.tangent_x_axis, "tangent plane follows the marker")
	_check(after.gradient_arrow_dir != before.gradient_arrow_dir, "gradient arrow follows the marker")
	var expected_fx := cos(after.x) * cos(after.y)
	_check(absf(after.fx - expected_fx) < 1e-4, "numerical ∂f/∂x matches cos(x)cos(y) (%.5f vs %.5f)" % [after.fx, expected_fx])
	await _wait(0.3)
	await _shot("01_surface_plot.png")

	# --- Typed functions (desktop text box) ----------------------------------------
	var edit: LineEdit = main.hud._function_edit
	_check(main.hud._function_row.visible and edit.text == "sin(x) cos(y)", "function box shows the surface's f(x, y)")
	var camera_before := camera.global_position
	edit.grab_focus()
	edit.clear()
	await _type("x^2 - y^2 + wasd")
	_check(camera.global_position.distance_to(camera_before) < 1e-3, "typing w/a/s/d in the box does not move the camera")
	_check(main.hud._function_status.text.begins_with("✗"), "unknown names are reported: %s" % main.hud._function_status.text)
	edit.grab_focus()
	edit.clear()
	await _type("x^2 - y^2")
	after = topic.get_debug_state()
	_check(main.hud._function_status.text.begins_with("✓") and absf(after.fx - 2.0 * after.x) < 1e-3,
			"typed x^2 - y^2 is plotted (∂f/∂x = %.3f, 2x = %.3f)" % [after.fx, 2.0 * after.x])
	_check(topic.z_scale < 0.5, "tall surface is squashed to fit (×%.2f)" % topic.z_scale)
	await _wait(0.3)
	await _shot("01b_surface_custom.png")
	main.submit_function("sqrt(4 - x^2 - y^2)")
	_check(topic._finite_count > 0 and topic.expr.text == "sqrt(4 - x^2 - y^2)", "partly undefined function (hemisphere) still plots")
	topic.marker_xy = Vector2(1.6, 0.9)  # Steep, near the rim.
	topic._update_marker()
	_check(topic._tangent.transform.basis.x.length() < 2.0 and topic._gradient._shaft.scale.y < 2.5,
			"steep slope keeps the tangent plane and ∇f arrow a sane size")
	await _wait(0.3)
	await _shot("01c_surface_hemisphere.png")
	main.submit_function("2e^(-(x^2 + y^2))")

	# --- Solid of revolution (opened by clicking the 3D panel button) ---------
	var button: Node3D = main.topic_panel._buttons[1]
	await _click(camera.unproject_position(button.global_position))
	await _wait(0.5)
	_check(main.current_index == 1, "clicking the 3D panel button opens Solid of Revolution")
	if main.current_index != 1:
		main.load_topic(1)
		await _wait(0.5)
	topic = main.current_topic
	before = topic.get_debug_state()
	for i in 5:
		_mouse_button(MOUSE_BUTTON_WHEEL_UP, true, Vector2(800, 450))
		_mouse_button(MOUSE_BUTTON_WHEEL_UP, false, Vector2(800, 450))
		await _wait(0.05)
	after = topic.get_debug_state()
	_check(absf(after.slice_x - before.slice_x - 0.5) < 1e-3, "mouse wheel moves the slicing plane (%.2f -> %.2f)" % [before.slice_x, after.slice_x])
	_check(absf(after.disk_radius - sqrt(after.slice_x)) < 1e-4 and after.disk_visible, "cross-section disk radius = √x (%.3f)" % after.disk_radius)
	await _wait(0.3)
	await _shot("02_solid_of_revolution.png")

	# VR keypad: press its keys the way the controller would.
	var pad: Node3D = main.function_pad
	pad.set_spec(topic.get_function_spec())
	for key in ["C", "sqrt", "4", "-", "(", "x", "-", "2", ")", "^", "2", ")"]:
		pad._on_key(key)
	pad._submit()
	await _wait(0.3)
	var sphere_volume := 32.0 * PI / 3.0
	_check(absf(topic.volume_to(4.0) - sphere_volume) < 0.05,
			"keypad-typed sphere √(4-(x-2)²): V = %.3f (32π/3 = %.3f)" % [topic.volume_to(4.0), sphere_volume])
	await _shot("02b_solid_sphere.png")
	pad.visible = true
	var pad_center: Vector3 = pad.global_position + Vector3(0.0, -0.65, 0.0)
	camera.reset_view(pad_center + pad.global_basis.z * 2.3, pad_center)
	await _wait(0.3)
	await _shot("02d_keypad.png")
	pad.visible = false
	camera.reset_view(main.DESKTOP_START, main.LOOK_TARGET)
	main.submit_function("sin(2x) + 1.5")
	await _wait(0.3)
	await _shot("02c_solid_wavy.png")

	# --- Vector field ------------------------------------------------------------
	main.load_topic(2)
	await _wait(0.6)
	topic = main.current_topic
	var state := topic.get_debug_state()
	_check(state.arrow_count == 125, "5×5×5 = 125 arrows")
	var hot: Color = state.color_at_2_2_0
	var cold: Color = state.color_at_1_0_0
	_check(hot.r > 0.8 and hot.b < 0.3, "|F| max arrow is red %s" % hot)
	_check(cold.b > cold.r, "small |F| arrow is blue-ish %s" % cold)
	var target := Vector3(1, -2, 2)
	var index: int = topic.index_of_point(target)
	await _click(camera.unproject_position(topic.arrow_global_position(index)))
	state = topic.get_debug_state()
	_check(state.selected_point == target, "left-click selects the arrow at %s (got %s)" % [target, state.selected_point])
	await _wait(0.3)
	await _shot("03_vector_field.png")
	_check(main.hud._function_row.visible and main.hud._function_edit.text == "(-y, x, 0)", "function box shows F for the vector field")
	main.submit_function("(x, y, z)")
	await _wait(0.5)
	var probe_p := Vector3(0.7, -0.4, 1.1)
	_check(main.hud._function_status.text.begins_with("✓") and absf(topic.divergence(probe_p) - 3.0) < 1e-3
			and topic.curl(probe_p).length() < 1e-3,
			"typed F = (x, y, z): div F = %.3f (3), |curl F| = %.4f (0)" % [topic.divergence(probe_p), topic.curl(probe_p).length()])
	main.submit_function("(x, y)")
	_check(main.hud._function_status.text.contains("3 components"), "missing component is reported: %s" % main.hud._function_status.text)
	main.submit_function("(-y, x, z/2)")
	await _wait(1.0)
	await _shot("03b_vector_field_custom.png")

	# --- Parametric curve -------------------------------------------------------
	main.load_topic(3)
	await _wait(0.6)
	topic = main.current_topic
	before = topic.get_debug_state()
	await _wait(1.0)
	after = topic.get_debug_state()
	_check(after.t != before.t and after.traveler != before.traveler, "sphere travels along the curve (t %.2f -> %.2f)" % [before.t, after.t])
	await _hold("topic_right", 0.5)
	await _hold("topic_up", 0.5)
	after = topic.get_debug_state()
	_check(after.frequency > before.frequency and after.radius > before.radius, "keys change ω and R (ω=%.2f, R=%.2f)" % [after.frequency, after.radius])
	await _wait(0.3)
	await _shot("04_parametric_curve.png")
	main.submit_function("(R cos(t), R sin(t), 0)")
	await _wait(0.3)
	var circle_length: float = 6.0 * PI * topic.radius
	_check(main.hud._function_status.text.begins_with("✓") and absf(topic.arc_length - circle_length) < 0.01 * circle_length,
			"typed circle: arc length %.3f ≈ 6πR = %.3f" % [topic.arc_length, circle_length])
	main.submit_function("(sin(t) + 2sin(2t), cos(t) - 2cos(2t), -sin(3t))")
	await _wait(0.8)
	await _shot("04b_parametric_knot.png")
	pad.set_spec(topic.get_function_spec())
	pad.visible = true
	pad_center = pad.global_position + Vector3(0.0, -0.65, 0.0)
	camera.reset_view(pad_center + pad.global_basis.z * 2.3, pad_center)
	await _wait(0.3)
	await _shot("04c_keypad_curve.png")
	pad.visible = false

	print("[TEST] DONE  %d checks, %d failures" % [_checks, _failures])
	get_tree().quit(_failures)
