extends Node3D
## VoxelWorld — The 3D block world containing all buildings and connections
## Reads from world/config data — no hardcoded positions outside config

signal building_selected(building_id: String)

const GRID_SIZE := 200
const GRID_DIVISIONS := 40
const BLOCK_SIZE := 1.0

var building_data := {}
var building_meshes := {}
var highlighted_id := ""

func _ready() -> void:
	_setup_lighting()
	_setup_ground()
	_setup_environment()

func _setup_lighting() -> void:
	var ambient := DirectionalLight3D.new()
	ambient.light_color = Color("#cceeff")
	ambient.light_energy = 0.6
	ambient.rotation_degrees = Vector3(-45, 30, 0)
	add_child(ambient)

	var point := PointLight3D.new()
	point.light_color = Color("#00d4ff")
	point.light_energy = 0.4
	point.position = Vector3(0, 20, 0)
	point.light_distance = 80
	add_child(point)

	var ambient_omni := OmniLight3D.new()
	ambient_omni.light_color = Color("#ffffff")
	ambient_omni.light_energy = 0.15
	ambient_omni.position = Vector3(0, 30, 0)
	add_child(ambient_omni)

	# Fog
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0a0a0f")
	env.fog_light_color = Color("#050810")
	env.fog_density = 0.008
	env.fog_aerial_transparency = 0.5
	world_env.environment = env
	add_child(world_env)

func _setup_environment() -> void:
	# Stars / sky dots
	var particles := GPUParticles3D.new()
	particles.amount = 200
	particles.lifetime = 100.0
	particles.explosiveness = 0.9
	particles.emitting = false

	var spread := BoxShape3D.new()
	spread.size = Vector3(GRID_SIZE * 2, 50, GRID_SIZE * 2)
	varcs := SphereShape3D.new()
	particles.visibility_box = spread
	particles.visibility_base_size = GRID_SIZE * 2

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("#ffffff")
	particles.process_material = mat
	add_child(particles)

func _setup_ground() -> void:
	# Grid floor
	var grid := GridMap.new()
	grid.cell_size = Vector3(BLOCK_SIZE, BLOCK_SIZE, BLOCK_SIZE)
	grid.map_size = Vector3i(GRID_SIZE / 2, 1, GRID_SIZE / 2)
	grid.position = Vector3(0, -0.01, 0)

	# Dark material for ground
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color("#050810")
	ground_mat.metallic = 0.1
	ground_mat.roughness = 0.9

	var tile_mesh := BoxMesh.new()
	tile_mesh.size = Vector3(BLOCK_SIZE, 0.05, BLOCK_SIZE)
	tile_mesh.material = ground_mat
	grid.mesh_library = MeshLibrary.new()
	grid.mesh_library.create_item(0)
	grid.mesh_library.set_item_mesh(0, tile_mesh)
	grid.mesh_library.set_item_navmesh(0, NavigationMesh.new())

	for x in range(-GRID_SIZE / 4, GRID_SIZE / 4):
		for z in range(-GRID_SIZE / 4, GRID_SIZE / 4):
			grid.set_cell_item(Vector3i(x, 0, z), 0)

	add_child(grid)

	# Glowing grid lines overlay
	var grid_lines :=ImmediateMesh.new()
	var mat_line := StandardMaterial3D.new()
	mat_line.albedo_color = Color("#00d4ff", 0.15)
	mat_line.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid_lines.surface_begin(Mesh.PRIMITIVE_LINES, mat_line)
	var step := 10
	for x in range(-GRID_SIZE / 2, GRID_SIZE / 2 + 1, step):
		grid_lines.surface_add_vertex(Vector3(x, 0.02, -GRID_SIZE / 2))
		grid_lines.surface_add_vertex(Vector3(x, 0.02, GRID_SIZE / 2))
	for z in range(-GRID_SIZE / 2, GRID_SIZE / 2 + 1, step):
		grid_lines.surface_add_vertex(Vector3(-GRID_SIZE / 2, 0.02, z))
		grid_lines.surface_add_vertex(Vector3(GRID_SIZE / 2, 0.02, z))
	grid_lines.surface_end()
	add_child(grid_lines)

func spawn_building(data: Dictionary) -> void:
	var id: String = data.get("id", "")
	if id.is_empty():
		return

	building_data[id] = data

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = id

	var size: Vector3 = data.get("size", Vector3(3, 5, 3))
	var pos: Vector3 = data.get("pos", Vector3.ZERO)
	var color: Color = data.get("color", Color("#00d4ff"))

	# Main body box
	var box := BoxMesh.new()
	box.size = size

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.7
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.3
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.88
	box.material = mat

	mesh_instance.mesh = box
	mesh_instance.position = pos + Vector3(0, size.y / 2, 0)
	mesh_instance.physicsInterpolation = true

	# Collision shape
	var body := StaticBody3D.new()
	body.add_child(mesh_instance)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	# Top cap glow
	var cap := MeshInstance3D.new()
	var cap_mesh := BoxMesh.new()
	cap_mesh.size = Vector3(size.x * 0.7, 0.25, size.z * 0.7)
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = color
	cap_mat.emission_enabled = true
	cap_mat.emission = color
	cap_mat.emission_energy_multiplier = 1.5
	cap_mesh.material = cap_mat
	cap.mesh = cap_mesh
	cap.position = Vector3(0, size.y / 2 + 0.15, 0)
	body.add_child(cap)

	# Status indicator
	var indicator := MeshInstance3D.new()
	var ind_mesh := SphereMesh.new()
	ind_mesh.radius = 0.18
	ind_mesh.height = 0.36
	var status: String = data.get("status", "healthy")
	var status_color := Color("#30d158") if status == "healthy" else Color("#ffd60a") if status == "degraded" else Color("#ff453a")
	var ind_mat := StandardMaterial3D.new()
	ind_mat.albedo_color = status_color
	ind_mat.emission_enabled = true
	ind_mat.emission = status_color
	ind_mat.emission_energy_multiplier = 2.0
	ind_mesh.material = ind_mat
	indicator.mesh = ind_mesh
	indicator.position = Vector3(size.x / 2 - 0.3, size.y / 2 + 0.15, size.z / 2)
	body.add_child(indicator)

	body.building_id = id
	building_meshes[id] = body
	add_child(body)

	# Spawn connection lines from config
	_spawn_connections(id, data)

func _spawn_connections(from_id: String, from_data: Dictionary) -> void:
	var connections := [
		{"to": "api-gateway", "label": "REST"},
		{"to": "postgres-main", "label": "SQL"},
		{"to": "redis-cache", "label": "CACHE"},
	]
	var service_connections := {
		"auth-service": [{"to": "api-gateway", "label": "REST"}, {"to": "postgres-main", "label": "SQL"}],
		"api-gateway": [{"to": "postgres-main", "label": "SQL"}, {"to": "redis-cache", "label": "CACHE"}],
		"user-service": [{"to": "api-gateway", "label": "REST"}, {"to": "redis-cache", "label": "SESSION"}],
		"payment-service": [{"to": "api-gateway", "label": "REST"}, {"to": "message-queue", "label": "EVENTS"}],
		"message-queue": [{"to": "notification-fn", "label": "ASYNC"}],
	}
	var conn_list: Array = service_connections.get(from_id, [])
	for c in conn_list:
		var to_id: String = c.get("to", "")
		if not to_id in building_data:
			continue
		var to_data: Dictionary = building_data[to_id]
		var from_pos: Vector3 = (from_data.get("pos", Vector3.ZERO) + Vector3(0, from_data.get("size", Vector3.ONE).y / 2, 0))
		var to_pos: Vector3 = (to_data.get("pos", Vector3.ZERO) + Vector3(0, to_data.get("size", Vector3.ONE).y / 2, 0))
		var mid: Vector3 = from_pos.lerp(to_pos, 0.5) + Vector3(0, 2, 0)
		_spawn_corridor(from_pos, to_pos, mid, from_data.get("color", Color("#00d4ff")))

func _spawn_corridor(from: Vector3, to: Vector3, mid: Vector3, color: Color) -> void:
	# Build tube mesh manually using ArrayMesh
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	var rad : float = 0.06
	var segs : int = 8
	var path_pts : int = 32
	
	var curve := Curve3D.new()
	curve.add_point(from)
	curve.add_point(mid)
	curve.add_point(to)
	var baked := curve.get_baked_points()
	
	if baked.size() < 2:
		return
	
	for i in range(baked.size()):
		var p : Vector3 = baked[i]
		var tangent : Vector3 = curve.get_sample_baked_mode()
		var up := Vector3.UP
		if tangent.abs().dot(Vector3.UP) > 0.95:
			up = Vector3.RIGHT
		var right := tangent.cross(up).normalized()
		var upvec := right.cross(tangent).normalized()
		
		for j in range(segs):
			var angle := TAU * float(j) / float(segs)
			var offset := (right * cos(angle) + upvec * sin(angle)) * rad
			verts.append(p + offset)
	
	var ring_count : int = baked.size()
	for i in range(ring_count - 1):
		for j in range(segs):
			var a_idx := i * segs + j
			var b_idx := i * segs + (j + 1) % segs
			var c_idx := (i + 1) * segs + j
			var d_idx := (i + 1) * segs + (j + 1) % segs
			indices.append(a_idx); indices.append(c_idx); indices.append(b_idx)
			indices.append(b_idx); indices.append(c_idx); indices.append(d_idx)
	
	var arrays := []
	arrays.append(verts)
	arrays.append(PackedVector3Array()) # normals
	arrays.append(PackedColorArray())   # colors
	arrays.append(PackedVector2Array()) # uvs
	arrays.append(indices)
	
	var arr_mesh := ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	var tube_mat := StandardMaterial3D.new()
	tube_mat.albedo_color = color
	tube_mat.emission_enabled = true
	tube_mat.emission = color
	tube_mat.emission_energy_multiplier = 0.5
	tube_mat.metallic = 0.8
	tube_mat.roughness = 0.1
	tube_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tube_mat.albedo_color.a = 0.4
	
	var tube_mesh := MeshInstance3D.new()
	tube_mesh.mesh = arr_mesh
	tube_mesh.mesh.surface_set_material(0, tube_mat)
	add_child(tube_mesh)

func highlight_building(id: String) -> void:
	# Reset previous
	if highlighted_id != "" and building_meshes.has(highlighted_id):
		_reset_material(highlighted_id)
	highlighted_id = id
	if not building_meshes.has(id):
		return
	var body: StaticBody3D = building_meshes[id]
	var mesh: MeshInstance3D = body.get_child(0) as MeshInstance3D
	if mesh and mesh.mesh:
		var mat: StandardMaterial3D = mesh.mesh.material.duplicate()
		mat.emission_energy_multiplier = 2.5
		mesh.mesh = mesh.mesh.duplicate()
		mesh.mesh.material = mat

func clear_highlight() -> void:
	if highlighted_id != "" and building_meshes.has(highlighted_id):
		_reset_material(highlighted_id)
	highlighted_id = ""

func _reset_material(id: String) -> void:
	var body: StaticBody3D = building_meshes[id]
	var mesh: MeshInstance3D = body.get_child(0) as MeshInstance3D
	if mesh and mesh.mesh and building_data.has(id):
		var color: Color = building_data[id].get("color", Color("#00d4ff"))
		var mat: StandardMaterial3D = mesh.mesh.material.duplicate()
		mat.emission_energy_multiplier = 0.3
		mesh.mesh.material = mat

func get_building_data(id: String) -> Dictionary:
	return building_data.get(id, {})