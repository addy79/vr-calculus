extends CalcTopic
## Surface plot of a user-entered f(x, y) (default sin(x)·cos(y)) with a movable
## point, the tangent plane there (from numerical partial derivatives) and the
## gradient vector. Math coordinates are z-up; MathUtil.to_godot maps them into
## Godot space. Tall functions are squashed vertically (z_scale) to stay in view.

const DOMAIN := 3.0
const RESOLUTION := 72
const PLOT_SCALE := 0.6
## Step for the central-difference partial derivatives.
const H := 0.001
const MARKER_SPEED := 1.5
## Gap (display units) between the lowest point and the flat domain plane.
const BASE_GAP := 0.6
## Tallest the surface is drawn, in math units before PLOT_SCALE.
const MAX_DISPLAY_HEIGHT := 3.0
## Function values are clamped to this for display, so poles stay drawable.
const VALUE_LIMIT := 1e4
const PRESETS: Array[String] = [
	"sin(x) cos(y)", "x^2 - y^2", "(x^2 + y^2) / 4", "2e^(-(x^2 + y^2))",
	"sin(2 sqrt(x^2 + y^2))", "x y / 3", "cos(x) + sin(y)",
]
const GRADIENT_SCALE := 1.0
const TANGENT_SIZE := 1.6
## Longest gradient arrow drawn (math units before PLOT_SCALE).
const MAX_ARROW := 2.5

var marker_xy := Vector2(1.0, 0.5)
var expr := MathExpr.compile(PRESETS[0], PackedStringArray(["x", "y"]))
## Display height per math unit, and the math z drawn at the plot origin.
var z_scale := 1.0
var z_mid := 0.0
var z_min := -1.0
var z_max := 1.0

var _plot := Node3D.new()
var _surface_root := Node3D.new()
var _axes: Node3D
var _base := MeshInstance3D.new()
var _marker := MeshInstance3D.new()
var _tangent := MeshInstance3D.new()
var _gradient := Arrow3D.new(Color(1.0, 0.3, 0.85), 0.05)
var _gradient_2d := Arrow3D.new(Color(1.0, 0.3, 0.85), 0.025)
var _shadow := MeshInstance3D.new()
var _drop_line := MeshInstance3D.new()
var _label := MathUtil.make_label("")
var _f := 0.0
var _fx := 0.0
var _fy := 0.0
var _drag_height := 0.0
var _finite_count := 0


func f(x: float, y: float) -> float:
	return expr.eval2(x, y)


## Numerical partial derivatives (∂f/∂x, ∂f/∂y) by central differences.
func partials(x: float, y: float) -> Vector2:
	return Vector2(
		(f(x + H, y) - f(x - H, y)) / (2.0 * H),
		(f(x, y + H) - f(x, y - H)) / (2.0 * H))


func _ready() -> void:
	_plot.scale = Vector3.ONE * PLOT_SCALE
	add_child(_plot)
	_plot.add_child(_surface_root)
	_build_base_plane()
	_axes = MathUtil.make_axes(DOMAIN + 0.4,
			MathUtil.to_godot(1, 0, 0), MathUtil.to_godot(0, 1, 0), MathUtil.to_godot(0, 0, 1))
	_plot.add_child(_axes)
	_build_marker()

	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(TANGENT_SIZE, TANGENT_SIZE)
	plane_mesh.material = MathUtil.glass_material(Color(1.0, 0.9, 0.2, 0.55), true)
	_tangent.mesh = plane_mesh
	_plot.add_child(_tangent)
	_plot.add_child(_gradient)
	_plot.add_child(_gradient_2d)

	add_child(_label)
	_rebuild()


## Plots a new function. Returns an error message, or "" on success.
func set_function(source: String) -> String:
	var new_expr := MathExpr.compile(source, PackedStringArray(["x", "y"]))
	if not new_expr.is_valid():
		return new_expr.error
	expr = new_expr
	_rebuild()
	if _finite_count == 0:
		return "f is undefined everywhere on [-3, 3]²"
	return ""


func get_function_spec() -> Dictionary:
	return {"label": "f(x, y) =", "variables": PackedStringArray(["x", "y"]),
			"text": expr.text, "presets": PRESETS}


func _rebuild() -> void:
	for child in _surface_root.get_children():
		child.queue_free()
	var n := RESOLUTION
	var heights := PackedFloat32Array()
	heights.resize((n + 1) * (n + 1))
	_finite_count = 0
	z_min = INF
	z_max = -INF
	for j in n + 1:
		for i in n + 1:
			var z := f(lerpf(-DOMAIN, DOMAIN, float(i) / n), lerpf(-DOMAIN, DOMAIN, float(j) / n))
			if is_finite(z):
				z = clampf(z, -VALUE_LIMIT, VALUE_LIMIT)
				z_min = minf(z_min, z)
				z_max = maxf(z_max, z)
				_finite_count += 1
			heights[j * (n + 1) + i] = z
	if _finite_count == 0:
		z_min = -1.0
		z_max = 1.0
	var span := maxf(z_max - z_min, 1e-3)
	z_scale = clampf(MAX_DISPLAY_HEIGHT / span, 0.02, 1.0)
	z_mid = (z_min + z_max) * 0.5
	_axes.position = _p(0.0, 0.0, 0.0) if absf(z_mid) * z_scale < 1.5 else Vector3.ZERO
	_base.position = _p(0.0, 0.0, z_min) - Vector3(0.0, BASE_GAP, 0.0)
	_build_surface(heights, span)
	_update_marker()


## Math point -> display position inside _plot (z is squashed and centred).
func _p(x: float, y: float, z: float) -> Vector3:
	return MathUtil.to_godot(x, y, (z - z_mid) * z_scale)


func _build_surface(heights: PackedFloat32Array, span: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := RESOLUTION
	for j in n + 1:
		for i in n + 1:
			var x := lerpf(-DOMAIN, DOMAIN, float(i) / n)
			var y := lerpf(-DOMAIN, DOMAIN, float(j) / n)
			var z := heights[j * (n + 1) + i]
			var finite := is_finite(z)
			if not finite:
				z = z_mid
			var d := partials(x, y) * z_scale if finite else Vector2.ZERO
			if not (is_finite(d.x) and is_finite(d.y)):
				d = Vector2.ZERO
			# Height-based colour: blue (low) -> red (high).
			st.set_color(MathUtil.heat_color((z - z_min) / span))
			# Surface normal (-fx, -fy, 1) in (squashed) math space.
			st.set_normal(MathUtil.to_godot(-d.x, -d.y, 1.0).normalized())
			st.add_vertex(_p(x, y, z))
	for j in n:
		for i in n:
			var a := j * (n + 1) + i
			var c := a + n + 1
			# Leave holes where f is undefined (e.g. sqrt of a negative).
			if not (is_finite(heights[a]) and is_finite(heights[a + 1])
					and is_finite(heights[c]) and is_finite(heights[c + 1])):
				continue
			st.add_index(a)
			st.add_index(c)
			st.add_index(a + 1)
			st.add_index(a + 1)
			st.add_index(c)
			st.add_index(c + 1)
	if _finite_count == 0:
		return
	var mesh := st.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.55
	mesh.surface_set_material(0, material)
	var surface := MeshInstance3D.new()
	surface.mesh = mesh
	_surface_root.add_child(surface)

	# Thin grid lines on the surface every half unit, for reading coordinates.
	var lines := SurfaceTool.new()
	lines.begin(Mesh.PRIMITIVE_LINES)
	lines.set_color(Color(0, 0, 0, 0.35))
	var lift := 0.01 / z_scale
	for k in 13:
		var c := lerpf(-DOMAIN, DOMAIN, k / 12.0)
		for s in n:
			var a := lerpf(-DOMAIN, DOMAIN, float(s) / n)
			var b := lerpf(-DOMAIN, DOMAIN, float(s + 1) / n)
			_grid_segment(lines, Vector2(c, a), Vector2(c, b), lift)
			_grid_segment(lines, Vector2(a, c), Vector2(b, c), lift)
	var line_mesh := lines.commit()
	var line_material := MathUtil.glass_material(Color.WHITE, true)
	line_material.vertex_color_use_as_albedo = true
	line_mesh.surface_set_material(0, line_material)
	var grid := MeshInstance3D.new()
	grid.mesh = line_mesh
	_surface_root.add_child(grid)

	# Clicking the surface moves the point there.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	_surface_root.add_child(body)


func _grid_segment(lines: SurfaceTool, a: Vector2, b: Vector2, lift: float) -> void:
	var za := f(a.x, a.y)
	var zb := f(b.x, b.y)
	if is_finite(za) and is_finite(zb):
		lines.add_vertex(_p(a.x, a.y, clampf(za, -VALUE_LIMIT, VALUE_LIMIT) + lift))
		lines.add_vertex(_p(b.x, b.y, clampf(zb, -VALUE_LIMIT, VALUE_LIMIT) + lift))


func _build_base_plane() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(DOMAIN * 2.0, DOMAIN * 2.0)
	plane.material = MathUtil.glass_material(Color(0.25, 0.35, 0.6, 0.35))
	_base.mesh = plane
	_plot.add_child(_base)

	var dot := SphereMesh.new()
	dot.radius = 0.07
	dot.height = 0.03
	dot.material = MathUtil.glass_material(Color(1, 1, 1, 0.9), true)
	_shadow.mesh = dot
	_plot.add_child(_shadow)

	var line := CylinderMesh.new()
	line.top_radius = 0.008
	line.bottom_radius = 0.008
	line.height = 1.0
	line.material = MathUtil.glass_material(Color(1, 1, 1, 0.5), true)
	_drop_line.mesh = line
	_plot.add_child(_drop_line)


func _build_marker() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.emission_enabled = true
	material.emission = Color(0.6, 0.8, 1.0)
	material.emission_energy_multiplier = 0.6
	sphere.material = material
	_marker.mesh = sphere
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.3
	shape.shape = sphere_shape
	body.add_child(shape)
	_marker.add_child(body)
	_plot.add_child(_marker)


## Recomputes f, the partials, tangent plane, gradient and label at the marker.
func _update_marker() -> void:
	marker_xy = marker_xy.clamp(Vector2(-DOMAIN, -DOMAIN), Vector2(DOMAIN, DOMAIN))
	var x := marker_xy.x
	var y := marker_xy.y
	_f = f(x, y)
	var d := partials(x, y)
	_fx = d.x
	_fy = d.y
	var defined := is_finite(_f) and is_finite(_fx) and is_finite(_fy)
	_marker.visible = is_finite(_f)
	_tangent.visible = defined
	_gradient.visible = defined
	_gradient_2d.visible = defined
	_drop_line.visible = _marker.visible
	var p := _p(x, y, clampf(_f, -VALUE_LIMIT, VALUE_LIMIT) if is_finite(_f) else z_min)
	_marker.position = p
	var sx := _fx * z_scale
	var sy := _fy * z_scale

	if defined:
		# Tangent plane z = f + fx·dx + fy·dy. The PlaneMesh lies in local XZ, so a
		# (skewed) basis maps local (u, 0, w) -> (u, fx·u - fy·w, w), where dx = u, dy = -w.
		# Near-vertical planes are shrunk so they don't tower over the scene.
		var shrink := minf(1.0, 1.5 / maxf(absf(sx), absf(sy)))
		_tangent.transform = Transform3D(Basis(Vector3(1.0, sx, 0.0) * shrink, Vector3.UP,
				Vector3(0.0, -sy, 1.0) * shrink), p)

		# ∇f lifted onto the tangent plane (direction of steepest ascent); its
		# shadow on the domain plane is the 2D gradient itself. Long arrows are
		# shortened (same direction) for display; the label shows true values.
		_gradient.position = p
		_gradient.set_vector((MathUtil.to_godot(_fx, _fy, (_fx * _fx + _fy * _fy) * z_scale)
				* GRADIENT_SCALE).limit_length(MAX_ARROW))
		_gradient_2d.set_vector((MathUtil.to_godot(_fx, _fy, 0.0) * GRADIENT_SCALE).limit_length(MAX_ARROW))
	var base := Vector3(p.x, _base.position.y, p.z)
	_shadow.position = base
	_gradient_2d.position = base + Vector3(0.0, 0.01, 0.0)
	_drop_line.position = (base + p) * 0.5
	_drop_line.scale = Vector3(1.0, maxf(p.y - base.y, 0.001), 1.0)

	_label.position = _plot.transform * (p + Vector3(0.3, 1.1, 0.0))
	if not is_finite(_f):
		_label.text = "f(x, y) = %s\n(x, y) = (%.2f, %.2f)\nf is undefined here" % [expr.text, x, y]
		return
	_label.text = "f(x, y) = %s\n(x, y) = (%.2f, %.2f)\nf = %.3f\n∂f/∂x = %.3f\n∂f/∂y = %.3f\n|∇f| = %.3f" % [
		expr.text, x, y, _f, _fx, _fy, Vector2(_fx, _fy).length()]
	if z_scale < 0.999:
		_label.text += "\n(height drawn ×%.2f)" % z_scale


func _set_from_global(point: Vector3) -> void:
	var local := _plot.to_local(point)
	marker_xy = Vector2(local.x, -local.z)
	_update_marker()


func handle_axis(axis: Vector2, delta: float) -> void:
	marker_xy += axis * MARKER_SPEED * delta
	_update_marker()


func pointer_pressed(_collider: Node, hit_position: Vector3, _ray_origin: Vector3, _ray_dir: Vector3) -> void:
	_set_from_global(hit_position)
	_drag_height = _marker.global_position.y


func pointer_dragged(ray_origin: Vector3, ray_dir: Vector3) -> void:
	# Drag on a horizontal plane at the height where the drag started.
	var hit: Variant = Plane(Vector3.UP, _drag_height).intersects_ray(ray_origin, ray_dir)
	if hit != null:
		_set_from_global(hit)


func get_hint() -> String:
	return "Surface plot: type any f(x, y) below. Arrow keys move the point (x, y). Click the surface or drag the white sphere.\nYellow = tangent plane,  pink arrow = ∇f (lifted onto the tangent plane; its shadow below is ∇f)."


func get_debug_state() -> Dictionary:
	return {
		"x": marker_xy.x, "y": marker_xy.y, "f": _f, "fx": _fx, "fy": _fy,
		"tangent_x_axis": _tangent.transform.basis.x,
		"gradient_arrow_dir": _gradient.basis.y,
		"marker_global": _marker.global_position,
	}
