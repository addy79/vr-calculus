class_name MathUtil
extends RefCounted
## Shared helpers for the calculus visualizations.

const HEAT_STOPS: Array[Color] = [
	Color(0.15, 0.3, 1.0), Color(0.0, 0.85, 1.0), Color(0.1, 0.9, 0.3),
	Color(1.0, 0.9, 0.1), Color(1.0, 0.2, 0.1),
]

static var _font: SystemFont


## Converts math coordinates (z-up) to Godot coordinates (y-up).
static func to_godot(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, z, -y)


## Blue (t = 0) -> cyan -> green -> yellow -> red (t = 1).
static func heat_color(t: float) -> Color:
	var s := clampf(t, 0.0, 1.0) * (HEAT_STOPS.size() - 1)
	var i := mini(int(s), HEAT_STOPS.size() - 2)
	return HEAT_STOPS[i].lerp(HEAT_STOPS[i + 1], s - float(i))


## Orthonormal basis whose Y axis points along `dir`.
static func basis_from_y(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var ref := Vector3.RIGHT if absf(y.dot(Vector3.UP)) > 0.99 else Vector3.UP
	var x := y.cross(ref).normalized()
	return Basis(x, y, x.cross(y))


## System font with good coverage of math symbols (∂ ∇ ∫ √ π).
static func math_font() -> Font:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Noto Sans", "DejaVu Sans", "Liberation Sans", "sans-serif"])
	return _font


## Billboard label that stays readable on top of geometry.
static func make_label(text: String, font_size: int = 32) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = math_font()
	label.font_size = font_size
	label.pixel_size = 0.005
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label


## Builds a smooth tube along `points` using parallel-transport frames.
static func build_tube(points: PackedVector3Array, radius: float, sides: int, colors: PackedColorArray) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := points.size()
	var tangent := (points[1] - points[0]).normalized()
	var normal := tangent.cross(Vector3.UP)
	if normal.length_squared() < 1e-6:
		normal = tangent.cross(Vector3.RIGHT)
	normal = normal.normalized()
	for i in count:
		var prev := points[maxi(i - 1, 0)]
		var next := points[mini(i + 1, count - 1)]
		var t_dir := (next - prev).normalized()
		# Parallel transport: keep the previous normal, minus its tangent component.
		normal = (normal - t_dir * normal.dot(t_dir)).normalized()
		var binormal := t_dir.cross(normal)
		for s in sides + 1:
			var a := TAU * float(s) / float(sides)
			var n := normal * cos(a) + binormal * sin(a)
			st.set_color(colors[i])
			st.set_normal(n)
			st.add_vertex(points[i] + n * radius)
	var ring := sides + 1
	for i in count - 1:
		for s in sides:
			var a := i * ring + s
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + ring)
			st.add_index(a + 1)
			st.add_index(a + ring + 1)
			st.add_index(a + ring)
	return st.commit()


## Coordinate axes as thin arrows from -length to +length with x/y/z labels.
## The directions give where the math x, y and z axes point in Godot space.
static func make_axes(length: float, x_dir: Vector3, y_dir: Vector3, z_dir: Vector3) -> Node3D:
	var root := Node3D.new()
	var dirs: Array[Vector3] = [x_dir, y_dir, z_dir]
	var names: Array[String] = ["x", "y", "z"]
	var colors: Array[Color] = [Color(1.0, 0.4, 0.4), Color(0.45, 1.0, 0.5), Color(0.5, 0.65, 1.0)]
	for i in 3:
		var arrow := Arrow3D.new(colors[i], 0.015)
		arrow.position = -dirs[i] * length
		arrow.set_vector(dirs[i] * length * 2.0)
		root.add_child(arrow)
		var label := make_label(names[i], 48)
		label.modulate = colors[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = dirs[i] * (length + 0.25)
		root.add_child(label)
	return root


## Translucent, double-sided material.
static func glass_material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
