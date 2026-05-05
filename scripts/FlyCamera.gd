extends Camera3D
## FlyCamera — WASD + mouse look, E/Q for up/down, right-click drag for pan
## No navmesh needed — free-flying FPS-style camera

signal target_changed(pos: Vector3)

const SPEED := 10.0
const FAST_SPEED := 25.0
const MOUSE_SENS := 0.3

var velocity := Vector3.ZERO
var current_target := Vector3.ZERO
var is_panning := false

func _ready() -> void:
	current_target = position
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.is_action_pressed("select") and not event.shift:
			# Right-click drag — pan
			rotation_degrees.y -= event.relative.x * MOUSE_SENS * 0.5
			rotation_degrees.x = clampf(rotation_degrees.x - event.relative.y * MOUSE_SENS * 0.5, -80, 80)
		elif not is_panning:
			# Left-click drag on empty — orbit
			pass
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_panning = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			position.y = max(2, position.y - 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			position.y = min(50, position.y + 1)

func _process(delta: float) -> void:
	var speed := FAST_SPEED if Input.is_action_pressed("move_forward") else SPEED
	var move := Vector3.ZERO

	if Input.is_action_pressed("move_forward"):
		move -= transform.basis.z * speed * delta
	if Input.is_action_pressed("move_backward"):
		move += transform.basis.z * speed * delta
	if Input.is_action_pressed("move_left"):
		move -= transform.basis.x * speed * delta
	if Input.is_action_pressed("move_right"):
		move += transform.basis.x * speed * delta
	if Input.is_action_pressed("move_up"):
		move.y += speed * delta
	if Input.is_action_pressed("move_down"):
		move.y -= speed * delta

	position += move
	if position.distance_squared_to(current_target) > 0.01:
		current_target = position
		target_changed.emit(current_target)