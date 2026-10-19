class_name XRLocomotion
extends Node
## Thumbstick locomotion for the XR origin: left stick walks (head-relative),
## right stick X snap-turns, right stick Y flies up/down. B/Y resets the view.
## Disabled while a grip is held so the sticks can drive the topic instead.

const MOVE_SPEED := 2.0
const FLY_SPEED := 1.5
const SNAP_ANGLE := deg_to_rad(30.0)
const DEADZONE := 0.2
## Stick deflection needed to trigger a snap turn, and to re-arm it.
const SNAP_THRESHOLD := 0.7
const SNAP_REARM := 0.3
const MIN_HEIGHT := -1.0
const MAX_HEIGHT := 8.0

var enabled := false
var origin: XROrigin3D
var camera: XRCamera3D
var left_hand: XRController3D
var right_hand: XRController3D

var _snap_armed := true
var _home: Transform3D


func setup(p_origin: XROrigin3D, p_camera: XRCamera3D, p_left: XRController3D, p_right: XRController3D) -> void:
	origin = p_origin
	camera = p_camera
	left_hand = p_left
	right_hand = p_right
	_home = origin.global_transform
	left_hand.button_pressed.connect(_on_button)
	right_hand.button_pressed.connect(_on_button)


## True while either grip is held: the sticks then control the topic.
func is_topic_mode() -> bool:
	return left_hand.get_float("grip") > 0.5 or right_hand.get_float("grip") > 0.5


func reset() -> void:
	origin.global_transform = _home


func _process(delta: float) -> void:
	if not enabled or is_topic_mode():
		_snap_armed = true
		return
	var move := left_hand.get_vector2("primary")
	if move.length() > DEADZONE:
		# Head-relative, flattened onto the floor plane.
		var forward := -camera.global_basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var right := Vector3(-forward.z, 0.0, forward.x)
		origin.global_position += (right * move.x + forward * move.y) * MOVE_SPEED * delta

	var turn := right_hand.get_vector2("primary")
	if absf(turn.y) > DEADZONE and absf(turn.y) > absf(turn.x):
		origin.global_position.y = clampf(origin.global_position.y + turn.y * FLY_SPEED * delta,
				MIN_HEIGHT, MAX_HEIGHT)
	if _snap_armed and absf(turn.x) > SNAP_THRESHOLD:
		_snap_turn(-signf(turn.x) * SNAP_ANGLE)
		_snap_armed = false
	elif absf(turn.x) < SNAP_REARM:
		_snap_armed = true


## Rotates the origin around the player's head, so the head stays in place.
func _snap_turn(angle: float) -> void:
	var pivot := camera.global_position
	pivot.y = origin.global_position.y
	var rotation := Transform3D(Basis(Vector3.UP, angle), Vector3.ZERO)
	origin.global_transform = Transform3D.IDENTITY.translated(pivot) * rotation \
			* Transform3D.IDENTITY.translated(-pivot) * origin.global_transform


func _on_button(action: String) -> void:
	if enabled and action == "by_button":
		reset()
