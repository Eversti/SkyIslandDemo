extends Node3D
class_name ArchipelagoGeneration

@export var grid_size: Vector3
@export var island_count: int = 10

@export var island_types: Array[IslandShapeType]
@export var mountain_types: Array[MountainType]

@export var material: Material
@export var lake_material: Material
@export var tree_leaves_material: Material
@export var tree_trunk_material: Material

var debug_object = preload("res://heatmap_debug.tscn")

@onready var loading_panel = $"../../../CanvasLayer/Panel"
@onready var seed_input = $"../../../CanvasLayer/HBoxContainer/LineEdit"

var noise = FastNoiseLite.new()

var debug = false
var seed = 0

var islands
var pending_island_placement = false
var generating = false

var mutex = Mutex.new()

func gen_cycle():
	if generating: return
	resetSeed()
	generating = true
	islands = []
	islands.resize(island_count)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	loading_panel.set_up_load(island_count)
	generate_islands()

func on_island_gen_complete(island_data):
	mutex.lock()
	islands[island_data.data.index] = island_data
	mutex.unlock()
	loading_panel.progress_load()
	if !islands.has(null):
		loading_panel.complete_load()
		pending_island_placement = true

func build_island_from_node_tree(data):
	var node = MeshInstance3D.new()
	
	if data.mesh:
		node.mesh = data.mesh
		node.position = data.local_position
		if data.material:
			node.material_override = data.material
	else:
		node.position = data.local_position

	for child_data in data.children:
		var child_node = build_island_from_node_tree(child_data)
		node.add_child(child_node)

	return node

func place_islands():
	var placed_islands = []
	for island in islands:
		print("Placed island index: " + str(island.data.index))
		var island_node = build_island_from_node_tree(island.tree)
		var island_data = island.data
		add_child(island_node)
		island_node.set_meta("island_data", island_data)
		var attempt = 0
		var island_dist = island_data.max_dist_from_center
		while attempt < 100: 
			
			var x = noise.get_noise_2d(attempt, 0) * grid_size.x
			var y = noise.get_noise_2d(attempt, 10) * grid_size.y
			var z = noise.get_noise_2d(attempt, 1000) * grid_size.z
			var position = Vector3(x, y, z)
			
			var overlaps = false
			for isle in placed_islands:
				if isle == island_node:
					continue
				
				var isle_dist = isle.get_meta("island_data").max_dist_from_center
				
				if Vector3(position.x, 0, position.z).distance_to(Vector3(isle.position.x, 0, isle.position.z)) < (island_dist + isle_dist):
					overlaps = true
					break
					
			if not overlaps:
				var rotation = deg_to_rad(lerp(0.0, 360.0, (noise.get_noise_1d(attempt) + 1.0) / 2.0))
				island_node.rotation.y = rotation
				island_node.position = position
				break
				
			attempt+=1
		placed_islands.append(island_node)
	generating = false

func generate_islands():
	for i in range(island_count):
		var index = i
		ThreadPool.add_task(generate_island.bind(index))

func generate_island(i):
	print("Running task: ", i)
	var shapeType = chooseRandFromArray(island_types, i)
	var result = IslandGeneration.generate_island(noise, i, shapeType)
	var island_data = result[0]
	island_data.index = i
	var island_node = MeshTree.new_entry(result[1], material)
	for peak in result[2]:
		for mesh in peak:
			var peak_node = MeshTree.new_entry(mesh, material)
			island_node.children.append(peak_node)
		
	populate_island(island_data, island_node, i)
	return {"tree": island_node, "data": island_data}

func populate_island(island_data, island_node, index):
	var heatmap = Heatmap.generate_heatmap(island_data.border, 3)
	Heatmap.score_heatmap(heatmap)
	island_data.heatmap = heatmap
	
	var total_usable_cells = Heatmap.usable_cells(island_data.heatmap, 0.2)
	var mountain_budget_cells = int(total_usable_cells * 0.25)
	var lake_budget_cells = int(total_usable_cells * 0.15)
	
	#Spawn main mountain
	var attempt = 0
	var main_spawned = false
	while attempt < 100 and !main_spawned:
		attempt += 1
		var main_pos = Heatmap.sample_from_heatmap(island_data.heatmap, 0.5, 0.9, true, seed + index + attempt)
		var main_box = Heatmap.get_max_bounding_box_at_point(island_data.heatmap, main_pos, 0.1, 25, 1.3)
		var main_types = find_fitting_types(main_box.size, "main")
		if main_types.size() > 0:
			main_spawned = true
			mountain_budget_cells -= spawn_mountain(island_data, island_node, index+attempt, main_box, chooseRandFromArray(main_types, index+attempt))
	
	attempt = 0
	while mountain_budget_cells > int(total_usable_cells * 0.05) and attempt < 100:
		attempt += 1
		var pos = Heatmap.sample_from_heatmap(island_data.heatmap, 0.1, 0.6, true, seed + index + attempt)
		var box = Heatmap.get_max_bounding_box_at_point(island_data.heatmap, pos, 0.1, 15, 1.5)
		var tag = ""
		if box.size.x / box.size.y > 1.25 or box.size.y / box.size.x > 1.35:
			tag = "ridge"
		else:
			tag = "regular"
		var types = find_fitting_types(box.size, tag)
		if types.size() > 0:
			mountain_budget_cells -= spawn_mountain(island_data, island_node, index+attempt, box, chooseRandFromArray(types, index+attempt))
	
	attempt = 0
	while lake_budget_cells > int(total_usable_cells * 0.05) and attempt < 100:
		attempt += 1
		var pos = Heatmap.sample_from_heatmap(island_data.heatmap, 0.2, 0.9, true, seed + index + attempt)
		var box = Heatmap.get_max_bounding_box_at_point(island_data.heatmap, pos, 0.1, 15, 1.25)
		if box.size.x > 25 and box.size.y > 25:
			lake_budget_cells -= spawn_lake(island_data, island_node, index+attempt, box)
			
	for i in range(10):
		var pos = Heatmap.sample_from_heatmap(island_data.heatmap, 0.05, 0.4, true, seed + index + i)
		var box = Heatmap.get_max_bounding_box_at_point(island_data.heatmap, pos, 0.05, 2, 1.25)
		if box.size.x >= 3 and box.size.y >= 3:
			var rock = RockGeneration.generate_rock(noise, index+i, 10, box.size)
			var center = box.get_center()
			var rock_node = MeshTree.new_entry(rock.mesh, material, Vector3(center.x, 0, center.y))
			island_node.children.append(rock_node)
			Heatmap.mask_heatmap(island_data.heatmap, rock.hull, center, 1)
	
	for i in range(10):
		var pos = Heatmap.sample_from_heatmap(island_data.heatmap, 0.3, 0.8, true, seed + index + i)
		var box = Heatmap.get_max_bounding_box_at_point(island_data.heatmap, pos, 0.05, 1, 1)
		if box.size.x >= 6 and box.size.y >= 6:
			var tree = TreeGeneration.generate_tree(noise, index+i, box.size)
			var center = box.get_center()
			var tree_node = MeshTree.new_entry(tree.trunk, tree_trunk_material, Vector3(center.x, 0, center.y))
			var leaves_node = MeshTree.new_entry(tree.leaves, tree_leaves_material)
			tree_node.children.append(leaves_node)
			island_node.children.append(tree_node)
			Heatmap.mask_heatmap(island_data.heatmap, tree.hull, center, 1)

func spawn_mountain(island_data, island_node, index, box, type):
	var result = MountainGeneration.generate_mountains(noise, index, type, box.size)
	var main_mesh = result[0]
	var center = box.get_center()
	var mountain_node = MeshTree.new_entry(main_mesh, material, Vector3(center.x, 0, center.y))
	for peak in result[1]:
		var peak_node = MeshTree.new_entry(peak, material)
		mountain_node.children.append(peak_node)
	
	island_node.children.append(mountain_node)
	var cellsBefore = Heatmap.usable_cells(island_data.heatmap, 0.2)
	Heatmap.mask_heatmap(island_data.heatmap, result[2], center, 1.1)
	var cellsAfter = Heatmap.usable_cells(island_data.heatmap, 0.2)
	Heatmap.score_heatmap(island_data.heatmap)
	return cellsBefore-cellsAfter

func spawn_lake(island_data, island_node, index, box):
	var result = LakeGeneration.generate_lake(noise, index, 15, box.size)
	var center = box.get_center()
	var lake_node = MeshTree.new_entry(result[0], lake_material, Vector3(center.x, 0.01, center.y))
	island_node.children.append(lake_node)
	
	var cellsBefore = Heatmap.usable_cells(island_data.heatmap, 0.2)
	Heatmap.mask_heatmap(island_data.heatmap, result[1], center, 1.1)
	var cellsAfter = Heatmap.usable_cells(island_data.heatmap, 0.2)
	Heatmap.score_heatmap(island_data.heatmap)
	return cellsBefore-cellsAfter

func _ready():
	ThreadPool.connect("task_completed", on_island_gen_complete)

func _exit_tree():
	ThreadPool.stop()

func _process(delta):
	if pending_island_placement:
		pending_island_placement = false
		place_islands()

func setup_noise(seed_val):
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.25
	noise.fractal_octaves = 4
	
	seed = seed_val
	noise.seed = seed

func resetSeed():
	seed = int(seed_input.text)
	setup_noise(seed)

func chooseRandFromArray(array, index):
	var rng = RandomNumberGenerator.new()
	rng.seed = seed + index
	return array[rng.randf_range(0, array.size())]

func get_combined_aabb(node):
	var result_aabb = AABB()
	var found_first = false

	var nodes_to_check = [node]

	while nodes_to_check.size() > 0:
		var current = nodes_to_check.pop_front()

		if current is MeshInstance3D and current.mesh:
			var local_aabb = current.mesh.get_aabb()
			var global_xform = current.global_transform

			for i in range(8):
				var corner = local_aabb.get_endpoint(i)
				var world_point = global_xform * corner

				if not found_first:
					result_aabb.position = world_point
					result_aabb.size = Vector3.ZERO
					found_first = true
				else:
					result_aabb = result_aabb.expand(world_point)

		for child in current.get_children():
			if child is Node3D:
				nodes_to_check.append(child)

	return result_aabb

func find_fitting_types(bounding_size, tag):
	var fitting = []
	for type in mountain_types:
		if type.min_size.x <= bounding_size.x and type.max_size.x >= bounding_size.x and \
		   type.min_size.y <= bounding_size.y and type.max_size.y >= bounding_size.y:
			
			if tag == type.tag:
				fitting.append(type)
	return fitting

func _on_button_button_down() -> void:
	gen_cycle()

func _on_line_edit_text_submitted(new_text: String) -> void:
	gen_cycle()

func _on_randomize_button_down() -> void:
	var randomSeed = randi()
	seed_input.text = str(randomSeed)
