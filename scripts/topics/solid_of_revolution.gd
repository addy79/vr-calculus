extends CalcTopic
## Solid of revolution: a user-entered y = f(x) (default √x) on [0, 4] rotated
## around the x-axis (36 steps), with a movable slicing plane that highlights
## the cross-section disk. Volumes are integrated numerically.
## Uses Godot coordinates directly (x right, y up) like a textbook figure.
## Wide solids are squashed radially (radial_scale) to stay in view.

const X_MAX := 4.0
const ANGLE_STEPS := 36
const X_STEPS := 96
## Steps of the cumulative volume table (trapezoid rule on π f(x)²).
const VOLUME_STEPS := 800
## Largest radius drawn, in math units before PLOT_SCALE.
const MAX_DISPLAY_RADIUS := 2.5
const PRESETS: Array[String] = [
	"sqrt(x)", "x / 2", "1", "sqrt(4 - (x - 2)^2)", "x^2 / 8", "sin(2x) + 1.5", "2e^(-x)",
]
const PLOT_SCALE := 0.65
const SLICE_SPEED := 1.5
const SCROLL_STEP := 0.1

var slice_x := 2.0
var expr := MathExpr.compile(PRESETS[0], PackedStringArray(["x"]))
var radial_scale := 1.0

var _plot := Node3D.new()
## Holds the function-dependent geometry; scaled (1, radial_scale, radial_scale).
var _geo := Node3D.new()
var _curve_label := MathUtil.make_label("", 48)
## _volume[i] = ∫₀ˣ π f(t)² dt at x = X_MAX · i / VOLUME_STEPS.
var _volume := PackedFloat64Array()
var _slicer := StaticBody3D.new()
var _disk_pivot := Node3D.new()
var _label := MathUtil.make_label("")
var _grab_offset := 0.0


## Radius |f(x)|; 0 where f is undefined.
func profile(x: float) -> float:
	var y := expr.eval1(x)
	return absf(y) if is_finite(y) else 0.0


## x sample i of X_STEPS, denser near x = 0 so steep starts like √x stay smooth.
static func x_sample(i: int) -> float:
	var u := float(i) / X_STEPS
	return X_MAX * u * (u + 1.0) * 0.5


func _ready() -> void:
	# Angle the solid so the slicing plane and disk are not seen edge-on.
	rotation.y = deg_to_rad(30.0)
	_plot.scale = Vector3.ONE * PLOT_SCALE
	_plot.position = Vector3(-X_MAX * 0.5 * PLOT_SCALE, -0.2, 0.0)
	add_child(_plot)
	_plot.add_child(_geo)
	_curve_label.modulate = Color(1.0, 0.9, 0.2)
	_plot.add_child(_curve_label)
	_plot.add_child(MathUtil.make_axes(X_MAX + 0.6, Vector3.RIGHT, Vector3.UP, Vector3.BACK))
	_build_slicer()
	_label.position = Vector3(-1.6, 2.5, 0.0)
	add_child(_label)
	_rebuild()


## Plots a new function. Returns an error message, or "" on success.
func set_function(source: String) -> String:
	var new_expr := MathExpr.compile(source, PackedStringArray(["x"]))
	if not new_expr.is_valid():
		return new_expr.error
	expr = new_expr
	_rebuild()
	if _volume[VOLUME_STEPS] <= 0.0:
		return "f is 0 or undefined on all of [0, 4]"
	return ""


func get_function_spec() -> Dictionary:
	return {"label": "f(x) =", "variables": PackedStringArray(["x"]),
			"text": expr.text, "presets": PRESETS}


func _rebuild() -> void:
	for child in _geo.get_children():
		child.queue_free()
	_volume.resize(VOLUME_STEPS + 1)
	_volume[0] = 0.0
	var r_max := 0.0
	var prev := PI * pow(profile(0.0), 2.0)
	for i in range(1, VOLUME_STEPS + 1):
		var x := X_MAX * float(i) / VOLUME_STEPS
		var r := profile(x)
		r_max = maxf(r_max, r)
		var area := PI * r * r
		_volume[i] = _volume[i - 1] + (prev + area) * 0.5 * X_MAX / VOLUME_STEPS
		prev = area
	r_max = maxf(r_max, profile(0.0))
	radial_scale = clampf(MAX_DISPLAY_RADIUS / maxf(r_max, 1e-3), 0.02, 1.0)
	_geo.scale = Vector3(1.0, radial_scale, radial_scale)
	_build_solid()
	_build_wireframe()
	_build_profile_curve()
	_update_slice()


## ∫₀ˣ π f(t)² dt, interpolated from the volume table.
func volume_to(x: float) -> float:
	var s := clampf(x / X_MAX, 0.0, 1.0) * VOLUME_STEPS
	var i := mini(int(s), VOLUME_STEPS - 1)
	return lerpf(_volume[i], _volume[i + 1], s - float(i))


func _build_solid() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in X_STEPS + 1:
		var x := x_sample(i)
		var r := profile(x)
		# Surface normal of r(x) revolved: (-r'(x), cos θ, sin θ), r' numerically.
		var slope := (profile(x + 1e-3) - profile(maxf(x - 1e-3, 0.0))) / (x + 1e-3 - maxf(x - 1e-3, 0.0))
		for k in ANGLE_STEPS + 1:
			var theta := TAU * float(k) / ANGLE_STEPS
			st.set_color(MathUtil.heat_color(x / X_MAX))
			st.set_normal(Vector3(-slope, cos(theta), sin(theta)).normalized())
			st.add_vertex(Vector3(x, r * cos(theta), r * sin(theta)))
	var ring := ANGLE_STEPS + 1
	for i in X_STEPS:
		for k in ANGLE_STEPS:
			var a := i * ring + k
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + ring)
			st.add_index(a + 1)
			st.add_index(a + ring + 1)
			st.add_index(a + ring)
	# End caps at x = 0 and x = 4 (flat disks; zero-size when r = 0 there).
	var center := (X_STEPS + 1) * ring
	st.set_color(MathUtil.heat_color(1.0))
	st.set_normal(Vector3.RIGHT)
	st.add_vertex(Vector3(X_MAX, 0.0, 0.0))
	st.set_color(MathUtil.heat_color(0.0))
	st.set_normal(Vector3.LEFT)
	st.add_vertex(Vector3.ZERO)
	for k in ANGLE_STEPS:
		st.add_index(center)
		st.add_index(X_STEPS * ring + k)
		st.add_index(X_STEPS * ring + k + 1)
		st.add_index(center + 1)
		st.add_index(k + 1)
		st.add_index(k)
	var mesh := st.commit()
	var material := MathUtil.glass_material(Color(1, 1, 1, 0.42))
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.35
	mesh.surface_set_material(0, material)
	var solid := MeshInstance3D.new()
	solid.mesh = mesh
	_geo.add_child(solid)


## Meridians (the 36 rotated copies of the profile) and a few parallels.
func _build_wireframe() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	st.set_color(Color(1, 1, 1, 0.25))
	for k in ANGLE_STEPS:
		var theta := TAU * float(k) / ANGLE_STEPS
		var dir := Vector3(0.0, cos(theta), sin(theta))
		for i in X_STEPS:
			st.add_vertex(Vector3(x_sample(i), 0, 0) + dir * profile(x_sample(i)))
			st.add_vertex(Vector3(x_sample(i + 1), 0, 0) + dir * profile(x_sample(i + 1)))
	for x in [1.0, 2.0, 3.0, 4.0]:
		var r := profile(x)
		for k in ANGLE_STEPS:
			var a := TAU * float(k) / ANGLE_STEPS
			var b := TAU * float(k + 1) / ANGLE_STEPS
			st.add_vertex(Vector3(x, r * cos(a), r * sin(a)))
			st.add_vertex(Vector3(x, r * cos(b), r * sin(b)))
	var mesh := st.commit()
	var material := MathUtil.glass_material(Color.WHITE, true)
	material.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, material)
	var lines := MeshInstance3D.new()
	lines.mesh = mesh
	_geo.add_child(lines)


## The generating curve y = |f(x)|, drawn as a bright tube.
func _build_profile_curve() -> void:
	var points := PackedVector3Array()
	var colors := PackedColorArray()
	for i in X_STEPS + 1:
		var x := x_sample(i)
		points.append(Vector3(x, profile(x), 0.0))
		colors.append(Color(1.0, 0.9, 0.2))
	var mesh := MathUtil.build_tube(points, 0.035, 8, colors)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = true
	material.emission = Color(0.6, 0.5, 0.0)
	mesh.surface_set_material(0, material)
	var tube := MeshInstance3D.new()
	tube.mesh = mesh
	_geo.add_child(tube)
	_curve_label.text = "y = " + expr.text
	_curve_label.position = Vector3(X_MAX + 0.2, profile(X_MAX) * radial_scale + 0.3, 0.0)


func _build_slicer() -> void:
	# Transparent plane perpendicular to the x-axis; drag it or use the wheel.
	var quad := QuadMesh.new()
	quad.size = Vector2(5.0, 5.0)
	quad.material = MathUtil.glass_material(Color(0.4, 0.8, 1.0, 0.28), true)
	var plane := MeshInstance3D.new()
	plane.mesh = quad
	plane.rotation.y = PI * 0.5
	_slicer.add_child(plane)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.08, 5.0, 5.0)
	shape.shape = box
	_slicer.add_child(shape)
	_plot.add_child(_slicer)

	# Cross-section disk, unit radius with its axis along x; scaled by r = √x.
	var disk_material := StandardMaterial3D.new()
	disk_material.albedo_color = Color(1.0, 0.5, 0.1)
	disk_material.emission_enabled = true
	disk_material.emission = Color(1.0, 0.45, 0.05)
	disk_material.emission_energy_multiplier = 0.7
	var disk_mesh := CylinderMesh.new()
	disk_mesh.top_radius = 1.0
	disk_mesh.bottom_radius = 1.0
	disk_mesh.height = 0.03
	disk_mesh.radial_segments = 48
	disk_mesh.material = disk_material
	var disk := MeshInstance3D.new()
	disk.mesh = disk_mesh
	disk.rotation.z = PI * 0.5
	_disk_pivot.add_child(disk)
	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = 0.97
	rim_mesh.outer_radius = 1.03
	rim_mesh.rings = 48
	var rim_material := StandardMaterial3D.new()
	rim_material.albedo_color = Color.WHITE
	rim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim_mesh.material = rim_material
	var rim := MeshInstance3D.new()
	rim.mesh = rim_mesh
	rim.rotation.z = PI * 0.5
	_disk_pivot.add_child(rim)
	_plot.add_child(_disk_pivot)


func _update_slice() -> void:
	slice_x = clampf(slice_x, 0.0, X_MAX)
	var r := profile(slice_x)
	_slicer.position = Vector3(slice_x, 0.0, 0.0)
	_disk_pivot.position = Vector3(slice_x, 0.0, 0.0)
	_disk_pivot.visible = r > 1e-3
	if _disk_pivot.visible:
		# Scale only y/z so the disk thickness stays constant.
		_disk_pivot.scale = Vector3(1.0, r * radial_scale, r * radial_scale)
	var area := PI * r * r
	_label.text = "y = f(x) = %s on [0, 4], about the x-axis\nSlice at x = %.2f\nr = |f(x)| = %.3f\nA(x) = π f(x)² = %.3f\nVolume so far: ∫₀ˣ π f(t)² dt = %.3f\nV = ∫₀⁴ π f(x)² dx ≈ %.3f" % [
		expr.text, slice_x, r, area, volume_to(slice_x), volume_to(X_MAX)]
	if radial_scale < 0.999:
		_label.text += "\n(radius drawn ×%.2f)" % radial_scale


## x-coordinate (math units) on the solid's axis closest to the pointer ray.
func _axis_param(ray_origin: Vector3, ray_dir: Vector3) -> float:
	var a0 := _plot.global_position
	var u := _plot.global_basis.x.normalized()
	var w0 := a0 - ray_origin
	var b := u.dot(ray_dir)
	var denom := 1.0 - b * b
	if denom < 1e-4:
		return slice_x  # Ray parallel to the axis: keep the current slice.
	var s := (b * ray_dir.dot(w0) - u.dot(w0)) / denom
	return _plot.to_local(a0 + u * s).x


func handle_axis(axis: Vector2, delta: float) -> void:
	slice_x += axis.x * SLICE_SPEED * delta
	_update_slice()


func handle_scroll(steps: float) -> void:
	slice_x += steps * SCROLL_STEP
	_update_slice()


func pointer_pressed(_collider: Node, _hit_position: Vector3, ray_origin: Vector3, ray_dir: Vector3) -> void:
	_grab_offset = slice_x - _axis_param(ray_origin, ray_dir)


func pointer_dragged(ray_origin: Vector3, ray_dir: Vector3) -> void:
	slice_x = _axis_param(ray_origin, ray_dir) + _grab_offset
	_update_slice()


func get_hint() -> String:
	return "Solid of revolution: type any f(x) below. Mouse wheel or Left/Right arrows move the slicing plane.\nYou can also drag the blue plane. Orange disk = cross-section with area A(x) = π f(x)²."


func get_debug_state() -> Dictionary:
	return {
		"slice_x": slice_x,
		"disk_radius": _disk_pivot.scale.y / radial_scale,
		"disk_visible": _disk_pivot.visible,
		"slicer_x": _slicer.position.x,
	}
