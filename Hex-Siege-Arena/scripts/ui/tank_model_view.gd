class_name TankModelView
extends SubViewportContainer

const DEFAULT_VIEWPORT_SIZE := Vector2i(320, 220)

var model_path: String = ""
var accent_color: Color = Color("72a7ff")
var spin_speed: float = 0.22

var _viewport: SubViewport
var _world_root: Node3D
var _pivot: Node3D
var _camera: Camera3D
var _sun_light: DirectionalLight3D
var _fill_light: OmniLight3D
var _base_ring: MeshInstance3D
var _backdrop: MeshInstance3D
var _model_instance: Node3D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	clip_contents = true
	_build_viewport()
	_update_viewport_size()
	if model_path != "":
		_load_model()


func _process(delta: float) -> void:
	if _pivot == null or AppState.reduced_motion:
		return
	_pivot.rotate_y(delta * spin_speed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_viewport_size()


func set_model_asset(path: String) -> void:
	model_path = path
	if is_inside_tree():
		_load_model()


func set_accent_color(color: Color) -> void:
	accent_color = color
	if _base_ring != null:
		_apply_base_material()
	if _fill_light != null:
		_fill_light.light_color = accent_color.lightened(0.08)


func _build_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.disable_3d = false
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)

	_world_root = Node3D.new()
	_viewport.add_child(_world_root)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c8d4ea")
	environment.ambient_light_energy = 1.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.04
	environment.glow_bloom = 0.08

	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_world_root.add_child(world_environment)

	_pivot = Node3D.new()
	_pivot.rotation_degrees = Vector3(-8.0, -28.0, 0.0)
	_world_root.add_child(_pivot)

	_backdrop = MeshInstance3D.new()
	_backdrop.mesh = QuadMesh.new()
	var backdrop_material := StandardMaterial3D.new()
	backdrop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	backdrop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	backdrop_material.albedo_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.09)
	_backdrop.material_override = backdrop_material
	_backdrop.position = Vector3(0.0, 0.0, -1.3)
	_backdrop.scale = Vector3(2.8, 2.0, 1.0)
	_pivot.add_child(_backdrop)

	_base_ring = MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.92
	cylinder.bottom_radius = 1.08
	cylinder.height = 0.16
	_base_ring.mesh = cylinder
	_base_ring.position = Vector3(0.0, -0.7, 0.0)
	_pivot.add_child(_base_ring)
	_apply_base_material()

	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 30.0
	_camera.position = Vector3(0.0, 0.85, 3.4)
	_camera.look_at(Vector3(0.0, 0.1, 0.0), Vector3.UP)
	_world_root.add_child(_camera)

	_sun_light = DirectionalLight3D.new()
	_sun_light.light_energy = 1.55
	_sun_light.rotation_degrees = Vector3(-46.0, 38.0, 0.0)
	_world_root.add_child(_sun_light)

	_fill_light = OmniLight3D.new()
	_fill_light.light_energy = 0.7
	_fill_light.omni_range = 8.0
	_fill_light.position = Vector3(-1.1, 0.75, 1.6)
	_fill_light.shadow_enabled = false
	_fill_light.light_color = accent_color.lightened(0.08)
	_world_root.add_child(_fill_light)


func _apply_base_material() -> void:
	var base_material := StandardMaterial3D.new()
	base_material.albedo_color = accent_color.darkened(0.08)
	base_material.metallic = 0.34
	base_material.roughness = 0.42
	base_material.emission_enabled = true
	base_material.emission = accent_color * 0.16
	_base_ring.material_override = base_material


func _update_viewport_size() -> void:
	if _viewport == null:
		return
	var width: int = maxi(int(size.x), DEFAULT_VIEWPORT_SIZE.x)
	var height: int = maxi(int(size.y), DEFAULT_VIEWPORT_SIZE.y)
	_viewport.size = Vector2i(width, height)


func _load_model() -> void:
	if _pivot == null:
		return
	if _model_instance != null:
		_model_instance.queue_free()
		_model_instance = null

	if model_path == "" or not ResourceLoader.exists(model_path):
		return

	var packed_scene: PackedScene = load(model_path)
	if packed_scene == null:
		return

	var instance: Node = packed_scene.instantiate()
	if instance is not Node3D:
		instance.queue_free()
		return

	_model_instance = instance as Node3D
	_pivot.add_child(_model_instance)
	_fit_model()


func _fit_model() -> void:
	if _model_instance == null:
		return
	var bounds: Dictionary = _collect_bounds(_model_instance)
	if not bool(bounds.get("valid", false)):
		return

	var center: Vector3 = bounds.get("center", Vector3.ZERO)
	var size_vector: Vector3 = bounds.get("size", Vector3.ONE)
	var max_dimension: float = maxf(maxf(size_vector.x, size_vector.y), size_vector.z)
	var scale_factor: float = 1.5 / maxf(max_dimension, 0.001)

	_model_instance.position = -center
	_model_instance.scale = Vector3.ONE * scale_factor

	var scaled_height: float = size_vector.y * scale_factor
	_camera.position = Vector3(0.0, 0.72 + scaled_height * 0.36, 3.1)
	_camera.look_at(Vector3(0.0, scaled_height * 0.18, 0.0), Vector3.UP)
	_base_ring.position = Vector3(0.0, -0.72, 0.0)


func _collect_bounds(root_node: Node3D) -> Dictionary:
	var points: Array[Vector3] = []
	_collect_mesh_points(root_node, Transform3D.IDENTITY, points)
	if points.is_empty():
		return {"valid": false}

	var min_point: Vector3 = points[0]
	var max_point: Vector3 = points[0]
	for point: Vector3 in points:
		min_point = Vector3(minf(min_point.x, point.x), minf(min_point.y, point.y), minf(min_point.z, point.z))
		max_point = Vector3(maxf(max_point.x, point.x), maxf(max_point.y, point.y), maxf(max_point.z, point.z))

	return {
		"valid": true,
		"center": (min_point + max_point) * 0.5,
		"size": max_point - min_point,
	}


func _collect_mesh_points(node: Node3D, parent_transform: Transform3D, points: Array[Vector3]) -> void:
	var current_transform: Transform3D = parent_transform * node.transform

	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh != null:
			for corner: Vector3 in _aabb_corners(mesh_node.mesh.get_aabb()):
				points.append(current_transform * corner)

	for child: Node in node.get_children():
		if child is Node3D:
			_collect_mesh_points(child as Node3D, current_transform, points)


func _aabb_corners(box: AABB) -> Array[Vector3]:
	var position: Vector3 = box.position
	var size_vector: Vector3 = box.size
	return [
		position,
		position + Vector3(size_vector.x, 0.0, 0.0),
		position + Vector3(0.0, size_vector.y, 0.0),
		position + Vector3(0.0, 0.0, size_vector.z),
		position + Vector3(size_vector.x, size_vector.y, 0.0),
		position + Vector3(size_vector.x, 0.0, size_vector.z),
		position + Vector3(0.0, size_vector.y, size_vector.z),
		position + size_vector,
	]
