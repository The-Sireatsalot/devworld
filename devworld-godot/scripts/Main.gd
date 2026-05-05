extends Node3D
## DevWorld Main Scene — Spatial IDE in Godot 4.6.2
## Run this in Godot 4.6.2 by opening project.godot

signal building_selected(building_id: String)
signal code_edited(file_path: String, content: String)

@onready var world: VoxelWorld = $VoxelWorld
@onready var camera: FlyCamera = $FlyCamera
@onready var editor_panel: PanelContainer = $EditorPanel
@onready var status_bar: Label = $StatusBar
@onready var building_info: PanelContainer = $BuildingInfo

var editor_visible := true
var selected_building_id: String = ""

func _ready() -> void:
	world.building_selected.connect(_on_building_selected)
	camera.target_changed.connect(_on_target_changed)
	_build_initial_world()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_editor"):
		_toggle_editor_panel()
	if event.is_action_pressed("select") and event is InputEventMouseButton:
		_handle_click(event as InputEventMouseButton)

func _toggle_editor_panel() -> void:
	editor_visible = not editor_visible
	var tween := create_tween()
	if editor_visible:
		tween.tween_property(editor_panel, "position:x", 0, 0.25)
	else:
		tween.tween_property(editor_panel, "position:x", -400, 0.25)

func _handle_click(event: InputEventMouseButton) -> void:
	var from := camera.project_ray_origin(event.position)
	var to := from + camera.project_ray_normal(event.position) * 1000
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var result := space.intersect_ray(query)
	if result:
		var collider := result["collider"]
		if collider and collider.get_parent() is ServiceBuilding:
			_select_building(collider.get_parent().building_id)
		else:
			_deselect_building()

func _select_building(id: String) -> void:
	selected_building_id = id
	world.highlight_building(id)
	_show_building_info(id)
	status_bar.text = "Selected: %s" % id

func _deselect_building() -> void:
	selected_building_id = ""
	world.clear_highlight()
	building_info.hide()
	status_bar.text = "Ready"

func _on_building_selected(id: String) -> void:
	_select_building(id)

func _on_target_changed(pos: Vector3) -> void:
	status_bar.text = "Camera at (%.1f, %.1f, %.1f)" % [pos.x, pos.y, pos.z]

func _show_building_info(id: String) -> void:
	var data := world.get_building_data(id)
	if data.is_empty():
		return
	var label := building_info.get_node("VBox/Title") as Label
	var desc := building_info.get_node("VBox/Description") as Label
	var files := building_info.get_node("VBox/Files") as Label
	label.text = data.get("name", id)
	desc.text = data.get("description", "")
	files.text = "\n".join(data.get("files", []))
	building_info.show()

func _build_initial_world() -> void:
	# Seed the world with initial buildings
	var buildings := [
		{"id": "auth-service", "name": "Auth Service", "type": "service", "pos": Vector3(-8, 0, -5), "size": Vector3(3, 6, 3), "color": Color("#00d4ff"), "description": "JWT authentication & session management", "files": ["src/services/auth.ts", "src/middleware/auth.ts"]},
		{"id": "api-gateway", "name": "API Gateway", "type": "gateway", "pos": Vector3(0, 0, 0), "size": Vector3(5, 4, 5), "color": Color("#bf5af2"), "description": "Request routing & rate limiting", "files": ["src/gateway/index.ts", "src/gateway/routes.ts"]},
		{"id": "user-service", "name": "User Service", "type": "service", "pos": Vector3(8, 0, -5), "size": Vector3(3, 5, 3), "color": Color("#30d158"), "description": "User profiles & account management", "files": ["src/services/user.ts", "src/models/User.ts"]},
		{"id": "payment-service", "name": "Payment Service", "type": "service", "pos": Vector3(-8, 0, 5), "size": Vector3(3, 7, 3), "color": Color("#ff453a"), "description": "Stripe integration & billing", "files": ["src/services/payment.ts"]},
		{"id": "postgres-main", "name": "Postgres (Main)", "type": "database", "pos": Vector3(8, 0, 5), "size": Vector3(4, 3, 4), "color": Color("#64d2ff"), "description": "Primary relational database", "files": ["prisma/schema.prisma"]},
		{"id": "redis-cache", "name": "Redis Cache", "type": "database", "pos": Vector3(0, 0, 10), "size": Vector3(2.5, 2, 2.5), "color": Color("#ff6b35"), "description": "In-memory cache & sessions", "files": ["src/cache/redis.ts"]},
		{"id": "message-queue", "name": "Message Queue", "type": "queue", "pos": Vector3(-15, 0, 0), "size": Vector3(3, 2.5, 3), "color": Color("#ffd60a"), "description": "Async job processing", "files": ["src/workers/queue.ts"]},
		{"id": "notification-fn", "name": "Notification Fn", "type": "function", "pos": Vector3(15, 0, 0), "size": Vector3(2, 8, 2), "color": Color("#ac8e68"), "description": "Email & push notifications", "files": ["src/fns/sendNotification.ts"]},
	]
	for b in buildings:
		world.spawn_building(b)