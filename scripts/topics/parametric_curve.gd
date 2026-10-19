extends CalcTopic
## Space curve r(t), t ∈ [0, 6π], rendered as a tube; user-entered, default
## the helix (R cos ωt, R sin ωt, t/3). Formulas may use the parameters R and
## w (ω), which the sliders/sticks change. A sphere travels along it showing the
## velocity r'(t) and acceleration r''(t) (numerical derivatives).
## The curve is centred and shrunk (fit_scale) to stay in view.

const T_MAX := 6.0 * PI
const SAMPLES := 600
const PLOT_SCALE := 0.45
const TUBE_RADIUS := 0.06
const VELOCITY_SCALE := 0.8
const ACCELERATION_SCALE := 0.35
## Largest half-extent drawn (math units before PLOT_SCALE).
const MAX_HALF_EXTENT := 3.2
const MAX_ARROW := 3.0
const VARIABLES := ["t", "R", "w"]
const PRESETS: Array[String] = [
	"(R cos(w t), R sin(w t), t/3)", "(R cos(t), R sin(t), sin(w t))",
	"(R sin(2t), R sin(3t), cos(w t))", "(sin(t) + 2sin(2t), cos(t) - 2cos(2t), -sin(3t))",
	"(t/6 cos(w t), t/6 sin(w t), 0)", "(R cos(t), R sin(t), 0)",
]

var frequency := 1.0  # ω
var radius := 1.0     # R
var t := 0.0
var speed := 1.5      # parameter units per second
var playing := true
var curve_text := PRESETS[0]
var fit_scale := 1.0
var fit_center := Vector3.ZERO
var arc_length := 0.0
var _components: Array[MathExpr] = []
var _args := [0.0, 1.0, 1.0]

var _plot := Node3D.new()
var _tube := MeshInstance3D.new()
var _traveler := MeshInstance3D.new()
var _velocity_arrow := Arrow3D.new(Color(1.0, 0.55, 0.1), 0.06)
var _acceleration_arrow := Arrow3D.new(Color(0.3, 1.0, 0.4), 0.05)
var _label := MathUtil.make_label("")
var _sliders := {}
var _slider_labels := {}


func _init() -> void:
	_components.assign(MathExpr.compile_tuple(curve_text, VARIABLES, 3).exprs)


## r(t) in math coordinates; non-finite components count as 0.
func position_at(tt: float) -> Vector3:
	_args[0] = tt
	_args[1] = radius
	_args[2] = frequency
	var p := Vector3(_components[0].evaluate(_args), _components[1].evaluate(_args), _components[2].evaluate(_args))
	for i in 3:
		if not is_finite(p[i]):
			p[i] = 0.0
	return p


func velocity_at(tt: float) -> Vector3:
	const DT := 1e-3
	return (position_at(tt + DT) - position_at(tt - DT)) / (2.0 * DT)


func acceleration_at(tt: float) -> Vector3:
	const DT := 1e-2
	return (position_at(tt + DT) - 2.0 * position_at(tt) + position_at(tt - DT)) / (DT * DT)


## Math point -> display position inside _plot (centred and fitted).
func _display(p: Vector3) -> Vector3:
	var q := (p - fit_center) * fit_scale
	return MathUtil.to_godot(q.x, q.y, q.z)


## Plots a new curve. Returns an error message, or "" on success.
func set_function(source: String) -> String:
	var result := MathExpr.compile_tuple(source, VARIABLES, 3)
	if not result.error.is_empty():
		return result.error
	_components.assign(result.exprs)
	curve_text = source.strip_edges()
	_rebuild_curve()
	return ""


func get_function_spec() -> Dictionary:
	return {"label": "r(t) =", "variables": PackedStringArray(VARIABLES),
			"text": curve_text, "presets": PRESETS}


func _ready() -> void:
	_plot.scale = Vector3.ONE * PLOT_SCALE
	add_child(_plot)
	_plot.add_child(MathUtil.make_axes(3.0,
			MathUtil.to_godot(1, 0, 0), MathUtil.to_godot(0, 1, 0), MathUtil.to_godot(0, 0, 1)))

	var tube_material := StandardMaterial3D.new()
	tube_material.vertex_color_use_as_albedo = true
	tube_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	tube_material.roughness = 0.35
	_tube.material_override = tube_material
	_plot.add_child(_tube)

	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	var sphere_material := StandardMaterial3D.new()
	sphere_material.albedo_color = Color.WHITE
	sphere_material.emission_enabled = true
	sphere_material.emission = Color(1.0, 0.9, 0.7)
	sphere_material.emission_energy_multiplier = 0.8
	sphere.material = sphere_material
	_traveler.mesh = sphere
	_plot.add_child(_traveler)
	_plot.add_child(_velocity_arrow)
	_plot.add_child(_acceleration_arrow)

	_label.position = Vector3(0.75, 1.6, 0.0)
	add_child(_label)
	_rebuild_curve()
	_update_traveler()


func _rebuild_curve() -> void:
	var samples: Array[Vector3] = []
	var bounds := AABB()
	arc_length = 0.0
	for i in SAMPLES:
		var p := position_at(float(i) / (SAMPLES - 1) * T_MAX)
		if i == 0:
			bounds = AABB(p, Vector3.ZERO)
		else:
			bounds = bounds.expand(p)
			arc_length += p.distance_to(samples[i - 1])
		samples.append(p)
	fit_center = bounds.get_center()
	var half := maxf(bounds.size[bounds.get_longest_axis_index()] * 0.5, 1e-3)
	fit_scale = minf(1.0, MAX_HALF_EXTENT / half)
	var points := PackedVector3Array()
	var colors := PackedColorArray()
	for i in SAMPLES:
		points.append(_display(samples[i]))
		colors.append(MathUtil.heat_color(float(i) / (SAMPLES - 1)))
	# A point "curve" (e.g. (0, 0, 0)) has no tube to draw.
	_tube.mesh = MathUtil.build_tube(points, TUBE_RADIUS, 10, colors) if bounds.size.length() > 1e-4 else null


func _process(delta: float) -> void:
	if playing:
		t = fmod(t + speed * delta, T_MAX)
	_update_traveler()


func _update_traveler() -> void:
	var p := position_at(t)
	var v := velocity_at(t)
	var a := acceleration_at(t)
	var gp := _display(p)
	_traveler.position = gp
	_velocity_arrow.position = gp
	_velocity_arrow.set_vector((MathUtil.to_godot(v.x, v.y, v.z) * VELOCITY_SCALE * fit_scale).limit_length(MAX_ARROW))
	_acceleration_arrow.position = gp
	_acceleration_arrow.set_vector((MathUtil.to_godot(a.x, a.y, a.z) * ACCELERATION_SCALE * fit_scale).limit_length(MAX_ARROW))
	_label.text = "r(t) = %s\nR = %.2f   ω = %.2f   (%s)\nt = %.2f  of 6π\nr(t) = (%.2f, %.2f, %.2f)\nr′(t) = (%.2f, %.2f, %.2f)  orange\n|r′(t)| = %.3f\nr″(t) = (%.2f, %.2f, %.2f)  green\nArc length L = ∫ |r′(t)| dt over [0, 6π] ≈ %.3f" % [
		curve_text, radius, frequency, "playing" if playing else "paused", t,
		p.x, p.y, p.z, v.x, v.y, v.z, v.length(), a.x, a.y, a.z, arc_length]
	if fit_scale < 0.999:
		_label.text += "\n(drawn ×%.2f)" % fit_scale


func set_frequency(value: float) -> void:
	frequency = clampf(value, 0.25, 3.0)
	_sync_slider("frequency", frequency)
	_rebuild_curve()


func set_radius(value: float) -> void:
	radius = clampf(value, 0.25, 2.5)
	_sync_slider("radius", radius)
	_rebuild_curve()


func set_speed(value: float) -> void:
	speed = clampf(value, 0.1, 6.0)
	_sync_slider("speed", speed)


func handle_axis(axis: Vector2, delta: float) -> void:
	if absf(axis.x) > 0.01:
		set_frequency(frequency + axis.x * 0.8 * delta)
	if absf(axis.y) > 0.01:
		set_radius(radius + axis.y * 0.8 * delta)


func handle_scroll(steps: float) -> void:
	set_speed(speed * pow(1.15, steps))


func handle_action() -> void:
	playing = not playing


func create_hud_controls() -> Control:
	var box := VBoxContainer.new()
	_add_slider(box, "frequency", "Frequency ω", 0.25, 3.0, frequency, set_frequency)
	_add_slider(box, "radius", "Radius R", 0.25, 2.5, radius, set_radius)
	_add_slider(box, "speed", "Speed", 0.1, 6.0, speed, set_speed)
	return box


func _add_slider(parent: Control, key: String, title: String, min_value: float, max_value: float,
		value: float, setter: Callable) -> void:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = title
	name_label.custom_minimum_size = Vector2(110, 0)
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = 0.01
	slider.value = value
	slider.custom_minimum_size = Vector2(240, 24)
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(setter)
	row.add_child(slider)
	var value_label := Label.new()
	value_label.text = "%.2f" % value
	value_label.custom_minimum_size = Vector2(50, 0)
	row.add_child(value_label)
	parent.add_child(row)
	_sliders[key] = slider
	_slider_labels[key] = value_label


func _sync_slider(key: String, value: float) -> void:
	# The HUD frees these when another topic is loaded, so check validity first.
	var slider: Variant = _sliders.get(key)
	if is_instance_valid(slider):
		(slider as HSlider).set_value_no_signal(value)
	var label: Variant = _slider_labels.get(key)
	if is_instance_valid(label):
		(label as Label).text = "%.2f" % value


func get_hint() -> String:
	return "Parametric curve: type any r(t) below; R and w (ω) follow the sliders. Left/Right = ω, Up/Down = R,\nwheel = speed, Space = pause."


func get_debug_state() -> Dictionary:
	return {
		"t": t, "frequency": frequency, "radius": radius,
		"traveler": _traveler.position,
		"tube_vertices": _tube.mesh.get_faces().size() if _tube.mesh else 0,
	}
