extends Node3D
## Entry point: picks XR or desktop mode at startup, loads the calculus topics
## and routes keyboard/mouse and controller input to the active topic.

const TOPICS: Array[Dictionary] = [
	{"title": "Surface Plot", "scene": "res://scenes/topics/SurfacePlot.tscn"},
	{"title": "Solid of Revolution", "scene": "res://scenes/topics/SolidOfRevolution.tscn"},
	{"title": "Vector Field", "scene": "res://scenes/topics/VectorField.tscn"},
	{"title": "Parametric Curve", "scene": "res://scenes/topics/ParametricCurve.tscn"},
]
const DESKTOP_START := Vector3(0.0, 3.0, 5.8)
const LOOK_TARGET := Vector3(-0.4, 1.5, 0.0)
## Smallest menu scale used when fitting it into a narrow window.
const MENU_MIN_SCALE := 0.55
## Where the menu slides to (from its scene position) as it shrinks.
const MENU_NARROW_OFFSET := Vector3(1.0, 0.0, 0.3)
## Left thumbstick deflection -> scroll steps per second in XR (grip held).
const XR_SCROLL_RATE := 8.0

var xr_interface: XRInterface
var xr_available := false
var xr_active := false
var current_topic: CalcTopic
var current_index := -1
var menu_scale := 1.0
var _menu_home: Transform3D
var locomotion := XRLocomotion.new()

@onready var topic_root: Node3D = $TopicRoot
@onready var topic_panel: Node3D = $TopicPanel
@onready var desktop_camera: Camera3D = $DesktopCamera
@onready var desktop_pointer: Node = $DesktopPointer
@onready var xr_camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var left_hand: XRController3D = $XROrigin3D/LeftHand
@onready var right_hand: XRController3D = $XROrigin3D/RightHand
@onready var hud: CanvasLayer = $HUD
@onready var function_pad: Node3D = $FunctionPad


func _ready() -> void:
	InputSetup.register()
	var titles := PackedStringArray()
	for topic in TOPICS:
		titles.append(topic.title)
	hud.setup(titles)
	hud.topic_requested.connect(load_topic)
	topic_panel.setup(titles)
	topic_panel.topic_requested.connect(load_topic)
	hud.function_submitted.connect(submit_function)
	function_pad.function_submitted.connect(submit_function)
	right_hand.button_pressed.connect(_on_xr_button)
	left_hand.button_pressed.connect(_on_xr_button)
	locomotion.name = "Locomotion"
	add_child(locomotion)
	locomotion.setup($XROrigin3D, xr_camera, left_hand, right_hand)

	_menu_home = topic_panel.transform
	get_window().min_size = Vector2i(
			ProjectSettings.get_setting("display/window/size/min_width", 800),
			ProjectSettings.get_setting("display/window/size/min_height", 600))
	desktop_camera.reset_view(DESKTOP_START, LOOK_TARGET)
	get_viewport().size_changed.connect(_on_window_resized)
	_on_window_resized()

	# OpenXR is initialised by the engine at startup when a runtime is present.
	xr_interface = XRServer.find_interface("OpenXR")
	xr_available = xr_interface != null and xr_interface.is_initialized()
	set_xr_mode(xr_available)
	if not xr_available:
		hud.toast("No XR runtime detected - desktop mode (WASD + right mouse)")

	load_topic(0)

	if OS.get_cmdline_user_args().has("--autotest"):
		var autotest: Node = load("res://tests/autotest.gd").new()
		autotest.set("main", self)
		add_child(autotest)


func load_topic(index: int) -> void:
	if index == current_index or index < 0 or index >= TOPICS.size():
		return
	desktop_pointer.pointer.release()
	left_hand.pointer.release()
	right_hand.pointer.release()
	if current_topic:
		topic_root.remove_child(current_topic)
		current_topic.queue_free()
	var scene := load(TOPICS[index].scene) as PackedScene
	current_topic = scene.instantiate() as CalcTopic
	topic_root.add_child(current_topic)
	current_index = index
	hud.set_topic(index, current_topic.topic_title, current_topic.get_hint(), current_topic.create_hud_controls())
	topic_panel.set_selected(index)
	var spec := current_topic.get_function_spec()
	hud.set_function_spec(spec)
	function_pad.set_spec(spec)
	function_pad.visible = xr_active and not spec.is_empty()


## Plots a typed function on the current topic; reports errors in both UIs.
func submit_function(text: String) -> void:
	if not current_topic:
		return
	var error := current_topic.set_function(text)
	hud.show_function_result(text, error)
	function_pad.set_text(text)
	function_pad.show_result(error)


func set_xr_mode(enable: bool) -> void:
	if enable and not xr_available:
		hud.toast("No OpenXR runtime available - staying in desktop mode.\nStart SteamVR or Monado, then relaunch to use XR.", 4.0)
		enable = false
	xr_active = enable
	get_viewport().use_xr = enable
	xr_camera.current = enable
	desktop_camera.current = not enable
	desktop_camera.enabled = not enable
	desktop_pointer.enabled = not enable
	left_hand.enabled = enable
	right_hand.enabled = enable
	locomotion.enabled = enable
	function_pad.visible = enable and current_topic != null and not current_topic.get_function_spec().is_empty()
	hud.set_desktop_mode(not enable)
	hud.mode_text = "XR (OpenXR)" if enable else "Desktop"
	fit_menu_to_size(get_viewport().get_visible_rect().size)


func _on_window_resized() -> void:
	var size := get_viewport().get_visible_rect().size
	# Tiling window managers often give a tall window: keep the horizontal FOV then.
	desktop_camera.keep_aspect = Camera3D.KEEP_WIDTH if size.x < size.y * 1.3 else Camera3D.KEEP_HEIGHT
	fit_menu_to_size(size)


## Shrinks the 3D menu and slides it inward until it is fully visible from the
## desktop start view at this window size. Returns true if it fits.
func fit_menu_to_size(size: Vector2) -> bool:
	if xr_active or size.x <= 0.0 or size.y <= 0.0:
		_place_menu(0.0)
		return true
	var aspect := size.x / size.y
	var tan_h := tan(deg_to_rad(desktop_camera.fov * 0.5))
	var tan_v := tan_h
	if aspect < 1.3:  # KEEP_WIDTH: fov is horizontal
		tan_v = tan_h / aspect
	else:
		tan_h = tan_v * aspect
	var view := Transform3D(Basis.looking_at(LOOK_TARGET - DESKTOP_START), DESKTOP_START).affine_inverse()
	const STEPS := 10
	for step in STEPS + 1:
		_place_menu(float(step) / STEPS)
		if _menu_visible(view, tan_h, tan_v):
			return true
	return false


## t = 0: scene placement at full size; t = 1: smallest, furthest inward.
func _place_menu(t: float) -> void:
	menu_scale = lerpf(1.0, MENU_MIN_SCALE, t)
	topic_panel.transform = Transform3D(_menu_home.basis.scaled_local(Vector3.ONE * menu_scale),
			_menu_home.origin + MENU_NARROW_OFFSET * t)


func _menu_visible(view: Transform3D, tan_h: float, tan_v: float) -> bool:
	for corner in topic_panel.get_corners():
		var p: Vector3 = view * corner
		if p.z > -0.1:
			return false
		# Normalised device coordinates with a small margin.
		if absf(p.x / (-p.z * tan_h)) > 0.95 or absf(p.y / (-p.z * tan_v)) > 0.95:
			return false
	return true


## Saves the current frame to res://screenshots and returns the file path.
func take_screenshot(file_name: String = "") -> String:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(dir)
	if file_name.is_empty():
		file_name = "vr_calculus_%s.png" % Time.get_datetime_string_from_system().replace(":", "-")
	var path := dir.path_join(file_name)
	get_viewport().get_texture().get_image().save_png(path)
	return path


func _process(delta: float) -> void:
	hud.set_crosshair_active(not xr_active and desktop_pointer.pointer.is_hovering())
	desktop_camera.typing = hud.is_typing()
	if not current_topic or hud.is_typing():
		return
	var axis := Input.get_vector("topic_left", "topic_right", "topic_down", "topic_up")
	if xr_active and locomotion.is_topic_mode():
		axis += right_hand.get_vector2("primary")
		var scroll := left_hand.get_vector2("primary").y
		if absf(scroll) > 0.2:
			current_topic.handle_scroll(scroll * XR_SCROLL_RATE * delta)
	if axis.length_squared() > 0.01:
		current_topic.handle_axis(axis.limit_length(1.0), delta)


func _unhandled_input(event: InputEvent) -> void:
	var wheel := event as InputEventMouseButton
	if wheel and wheel.pressed and current_topic:
		if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_topic.handle_scroll(1.0)
		elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_topic.handle_scroll(-1.0)
		return
	if event.is_echo():
		return
	if event.is_action_pressed("toggle_xr"):
		set_xr_mode(not xr_active)
	elif event.is_action_pressed("toggle_help"):
		hud.toggle_help()
	elif event.is_action_pressed("screenshot"):
		var path: String = await take_screenshot()
		hud.toast("Screenshot saved: " + path)
	elif event.is_action_pressed("topic_action") and current_topic:
		current_topic.handle_action()
	else:
		for i in TOPICS.size():
			if event.is_action_pressed("topic_%d" % (i + 1)):
				load_topic(i)


func _on_xr_button(action: String) -> void:
	if xr_active and current_topic and action == "ax_button":
		current_topic.handle_action()
