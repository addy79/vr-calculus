extends XRController3D
## XR controller: a laser pointer using the same interaction protocol as the
## desktop mouse. Trigger = grab/select.

var enabled := false:
	set(value):
		enabled = value
		if not enabled:
			pointer.release()

var pointer := PointerState.new()
var _laser := MeshInstance3D.new()


func _ready() -> void:
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.04, 0.03, 0.12)
	body.mesh = body_mesh
	add_child(body)
	var laser_mesh := BoxMesh.new()
	laser_mesh.size = Vector3(0.004, 0.004, 1.0)
	var laser_material := StandardMaterial3D.new()
	laser_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	laser_material.albedo_color = Color(0.4, 0.8, 1.0)
	laser_mesh.material = laser_material
	_laser.mesh = laser_mesh
	add_child(_laser)
	button_pressed.connect(_on_button_pressed)
	button_released.connect(_on_button_released)


func _process(_delta: float) -> void:
	_laser.visible = enabled and get_is_active()
	if not _laser.visible:
		return
	var origin := global_position
	var dir := -global_basis.z.normalized()
	pointer.update(get_world_3d(), origin, dir)
	var length := origin.distance_to(pointer.hit_position) if pointer.has_hit else 5.0
	_laser.scale = Vector3(1.0, 1.0, length)
	_laser.position = Vector3(0.0, 0.0, -length * 0.5)


func _on_button_pressed(action: String) -> void:
	if enabled and action == "trigger_click":
		pointer.press()


func _on_button_released(action: String) -> void:
	if action == "trigger_click":
		pointer.release()
