extends CalcTopic
## Vector field F(x, y, z) on a 5×5×5 grid (user-entered, default (−y, x, 0)),
## coloured by magnitude. Click an arrow to inspect it; grab the white probe to
## sample F, div F and curl F (numerical) anywhere. Particles follow the flow.

const N := 5
const EXTENT := 2.0
const PLOT_SCALE := 0.6
const PROBE_SPEED := 1.5
const PARTICLE_COUNT := 90
## Step for the central differences in div and curl.
const H := 0.001
## Fastest particle speed (math units per second), reached where |F| is largest.
const FLOW_SPEED := 1.7
const VARIABLES := ["x", "y", "z"]
const PRESETS: Array[String] = [
	"(-y, x, 0)", "(x, y, z)", "(-x, -y, -z)", "(x, -y, 0)", "(-y, x, z/2)",
	"(y z, x z, x y)", "(sin(y), sin(x), 0)",
]

var selected_index := -1
var points: Array[Vector3] = []  # grid points in math coordinates
var field_text := PRESETS[0]
var max_magnitude := 1.0
var _components: Array[MathExpr] = []
var _args := [0.0, 0.0, 0.0]

var _plot := Node3D.new()
var _arrows: Array[Arrow3D] = []
var _bodies: Array[StaticBody3D] = []
var _halo := MeshInstance3D.new()
var _selection_label := MathUtil.make_label("")
var _probe := Grabbable.new(0.1, Color.WHITE)
var _probe_arrow := Arrow3D.new(Color(1.0, 0.4, 0.9), 0.03)
var _probe_label := MathUtil.make_label("")
var _particles := MultiMeshInstance3D.new()
var _particle_pos: Array[Vector3] = []
var _particle_age: Array[float] = []
var _flow_enabled := true
var _arrow_root := Node3D.new()
var _header := MathUtil.make_label("")


func _init() -> void:
	_components.assign(MathExpr.compile_tuple(field_text, VARIABLES, 3).exprs)


## F at a math-space point; non-finite components count as 0.
func field(p: Vector3) -> Vector3:
	_args[0] = p.x
	_args[1] = p.y
	_args[2] = p.z
	var v := Vector3(_components[0].evaluate(_args), _components[1].evaluate(_args), _components[2].evaluate(_args))
	for i in 3:
		if not is_finite(v[i]):
			v[i] = 0.0
	return v


func divergence(p: Vector3) -> float:
	return ((field(p + Vector3(H, 0, 0)).x - field(p - Vector3(H, 0, 0)).x)
			+ (field(p + Vector3(0, H, 0)).y - field(p - Vector3(0, H, 0)).y)
			+ (field(p + Vector3(0, 0, H)).z - field(p - Vector3(0, 0, H)).z)) / (2.0 * H)


func curl(p: Vector3) -> Vector3:
	var dx := (field(p + Vector3(H, 0, 0)) - field(p - Vector3(H, 0, 0))) / (2.0 * H)
	var dy := (field(p + Vector3(0, H, 0)) - field(p - Vector3(0, H, 0))) / (2.0 * H)
	var dz := (field(p + Vector3(0, 0, H)) - field(p - Vector3(0, 0, H))) / (2.0 * H)
	return Vector3(dy.z - dz.y, dz.x - dx.z, dx.y - dy.x)


## Plots a new field. Returns an error message, or "" on success.
func set_function(source: String) -> String:
	var result := MathExpr.compile_tuple(source, VARIABLES, 3)
	if not result.error.is_empty():
		return result.error
	_components.assign(result.exprs)
	field_text = source.strip_edges()
	_rebuild()
	return ""


func get_function_spec() -> Dictionary:
	return {"label": "F(x, y, z) =", "variables": PackedStringArray(VARIABLES),
			"text": field_text, "presets": PRESETS}


static func fmt(v: Vector3, decimals: int = 0) -> String:
	var f := "%." + str(decimals) + "f"
	return ("(" + f + ", " + f + ", " + f + ")") % [v.x, v.y, v.z]


func _ready() -> void:
	_plot.scale = Vector3.ONE * PLOT_SCALE
	add_child(_plot)
	_plot.add_child(MathUtil.make_axes(EXTENT + 0.5,
			MathUtil.to_godot(1, 0, 0), MathUtil.to_godot(0, 1, 0), MathUtil.to_godot(0, 0, 1)))
	_plot.add_child(_arrow_root)

	var halo_mesh := SphereMesh.new()
	halo_mesh.radius = 0.3
	halo_mesh.height = 0.6
	halo_mesh.material = MathUtil.glass_material(Color(1, 1, 1, 0.22), true)
	_halo.mesh = halo_mesh
	_halo.visible = false
	_plot.add_child(_halo)
	_selection_label.visible = false
	add_child(_selection_label)

	_probe.position = MathUtil.to_godot(1.3, 0.7, -1.2)
	_probe.bounds = AABB(Vector3.ONE * -(EXTENT + 0.5), Vector3.ONE * (EXTENT + 0.5) * 2.0)
	_probe.moved.connect(func(_pos: Vector3) -> void: _update_probe())
	_plot.add_child(_probe)
	_probe.add_child(_probe_arrow)
	_probe_label.font_size = 26
	add_child(_probe_label)

	_header.position = Vector3(-1.9, 2.3, 0.0)
	add_child(_header)

	_build_particles()
	_rebuild()


func _rebuild() -> void:
	for child in _arrow_root.get_children():
		child.queue_free()
	points.clear()
	_arrows.clear()
	_bodies.clear()
	selected_index = -1
	_halo.visible = false
	_selection_label.visible = false
	# Colour scale: the largest |F| on the grid.
	max_magnitude = 1e-6
	for i in N:
		for j in N:
			for k in N:
				max_magnitude = maxf(max_magnitude, field(_grid_point(i, j, k)).length())
	_build_arrows()
	for i in PARTICLE_COUNT:
		_particle_pos[i] = _random_point()
	_header.text = "F(x, y, z) = %s\nColour: |F| = 0 blue → %.2f red\nProbe shows div F and curl F" % [
			field_text, max_magnitude]
	_update_probe()


func _grid_point(i: int, j: int, k: int) -> Vector3:
	return Vector3(
		lerpf(-EXTENT, EXTENT, float(i) / (N - 1)),
		lerpf(-EXTENT, EXTENT, float(j) / (N - 1)),
		lerpf(-EXTENT, EXTENT, float(k) / (N - 1)))


func _build_arrows() -> void:
	for i in N:
		for j in N:
			for k in N:
				var p := _grid_point(i, j, k)
				var v := field(p)
				var magnitude := v.length()
				var color := MathUtil.heat_color(magnitude / max_magnitude)
				var body := StaticBody3D.new()
				body.position = MathUtil.to_godot(p.x, p.y, p.z)
				body.set_meta("arrow_index", points.size())
				var arrow := Arrow3D.new(color, 0.035)
				if magnitude > 1e-6:
					# Display length grows with |F| but stays within the grid spacing.
					var length := 0.25 + 0.6 * magnitude / max_magnitude
					var dir := MathUtil.to_godot(v.x, v.y, v.z).normalized()
					arrow.position = -dir * length * 0.5  # centre the arrow on its grid point
					arrow.set_vector(dir * length)
				else:
					# F = 0 here: direction undefined, show a dot instead.
					arrow.set_vector(Vector3.ZERO)
					var dot := MeshInstance3D.new()
					var sphere := SphereMesh.new()
					sphere.radius = 0.07
					sphere.height = 0.14
					sphere.material = arrow.material
					dot.mesh = sphere
					body.add_child(dot)
				body.add_child(arrow)
				var shape := CollisionShape3D.new()
				var sphere_shape := SphereShape3D.new()
				sphere_shape.radius = 0.22
				shape.shape = sphere_shape
				body.add_child(shape)
				_arrow_root.add_child(body)
				points.append(p)
				_arrows.append(arrow)
				_bodies.append(body)


## Small spheres carried along by the flow of F.
func _build_particles() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.04
	sphere.height = 0.08
	sphere.radial_segments = 8
	sphere.rings = 4
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = sphere
	multimesh.instance_count = PARTICLE_COUNT
	_particles.multimesh = multimesh
	_plot.add_child(_particles)
	for i in PARTICLE_COUNT:
		_particle_pos.append(_random_point())
		_particle_age.append(randf() * 4.0)


func _random_point() -> Vector3:
	return Vector3(randf_range(-EXTENT, EXTENT), randf_range(-EXTENT, EXTENT), randf_range(-EXTENT, EXTENT))


func _process(delta: float) -> void:
	_particles.visible = _flow_enabled
	if not _flow_enabled:
		return
	var multimesh := _particles.multimesh
	for i in PARTICLE_COUNT:
		_particle_age[i] -= delta
		if _particle_age[i] <= 0.0:
			_particle_pos[i] = _random_point()
			_particle_age[i] = randf_range(3.0, 6.0)
		# dp/dt = F(p), midpoint (RK2) step, time scaled so the fastest
		# particles move at FLOW_SPEED.
		var p := _particle_pos[i]
		var k := FLOW_SPEED / max_magnitude * delta
		var mid := p + field(p) * k * 0.5
		var v := field(mid)
		p += v * k
		var bound := EXTENT + 0.5
		if absf(p.x) > bound or absf(p.y) > bound or absf(p.z) > bound:
			p = _random_point()
			_particle_age[i] = randf_range(3.0, 6.0)
		_particle_pos[i] = p
		var fade := clampf(_particle_age[i], 0.0, 1.0)
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * fade), MathUtil.to_godot(p.x, p.y, p.z)))
		multimesh.set_instance_color(i, MathUtil.heat_color(v.length() / max_magnitude))


func select_arrow(index: int) -> void:
	if selected_index >= 0:
		_arrows[selected_index].set_highlight(false)
	selected_index = index
	_arrows[index].set_highlight(true)
	var p := points[index]
	var v := field(p)
	_halo.position = _bodies[index].position
	_halo.visible = true
	_selection_label.visible = true
	# Keep the label on the inner side of the point so it stays on screen.
	var right_side := _bodies[index].position.x > 0.0
	_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right_side else HORIZONTAL_ALIGNMENT_LEFT
	var offset := Vector3(-0.2 if right_side else 0.2, 0.55, 0.0)
	_selection_label.position = _plot.transform * (_bodies[index].position + offset)
	_selection_label.text = "Point (x, y, z) = %s\nF = %s\n|F| = %.3f" % [fmt(p), fmt(v, 2), v.length()]


## Global position of the arrow at a grid point (used by the self-test).
func arrow_global_position(index: int) -> Vector3:
	return _bodies[index].global_position


func index_of_point(p: Vector3) -> int:
	return points.find(p)


func _update_probe() -> void:
	var g := _probe.position
	var p := Vector3(g.x, -g.z, g.y)  # Godot -> math coordinates
	var v := field(p)
	# Longest probe arrow = 1.15 display units, wherever |F| is largest.
	_probe_arrow.set_vector(MathUtil.to_godot(v.x, v.y, v.z) * (1.15 / max_magnitude))
	_probe_label.position = _plot.transform * (g + Vector3(0.2, -0.45, 0.0))
	_probe_label.text = "Probe %s\nF = %s   |F| = %.2f\ndiv F = %.2f   curl F = %s" % [
			fmt(p, 2), fmt(v, 2), v.length(), divergence(p), fmt(curl(p), 2)]


func pointer_pressed(collider: Node, _hit_position: Vector3, _ray_origin: Vector3, _ray_dir: Vector3) -> void:
	if collider and collider.has_meta("arrow_index"):
		select_arrow(collider.get_meta("arrow_index"))


func handle_axis(axis: Vector2, delta: float) -> void:
	_move_probe(MathUtil.to_godot(axis.x, axis.y, 0.0) * PROBE_SPEED * delta)


func handle_scroll(steps: float) -> void:
	_move_probe(MathUtil.to_godot(0.0, 0.0, steps * 0.1))


func handle_action() -> void:
	_flow_enabled = not _flow_enabled


func _move_probe(offset: Vector3) -> void:
	_probe.position = (_probe.position + offset).clamp(_probe.bounds.position, _probe.bounds.end)
	_update_probe()


func get_hint() -> String:
	return "Vector field: type any F(x, y, z) below, e.g. (-y, x, 0). Click an arrow to inspect it. Drag the white probe (or Arrow keys + wheel) to sample F.\nSpace toggles the flow particles."


func get_debug_state() -> Dictionary:
	var corner := index_of_point(Vector3(2, 2, 0))
	var near := index_of_point(Vector3(1, 0, 0))
	return {
		"arrow_count": _arrows.size(),
		"selected_index": selected_index,
		"selected_point": points[selected_index] if selected_index >= 0 else Vector3.INF,
		"color_at_2_2_0": _arrows[corner].material.albedo_color,
		"color_at_1_0_0": _arrows[near].material.albedo_color,
	}
