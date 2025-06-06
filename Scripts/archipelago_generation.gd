extends Node3D
class_name ArchipelagoGeneration

@export var grid_size: int = 10
@export var island_count: int = 10

@export var islandGen: IslandGen
@export var mountainGen: MountainGen

@export var islandBaseTypes: Array[IslandBaseType]
@export var islandShapeTypes: Array[IslandShapeType]
@export var mountainTypes: Array[MountainType]

var noise := FastNoiseLite.new()
var islands

var rng = RandomNumberGenerator.new()
var seed = 0

var seedInput

func _ready():
	seedInput = get_node("../CanvasLayer/HBoxContainer/TextEdit")
	setup_noise(randi())
	seedInput.text = str(seed)
	generate_islands()
	

func setup_noise(seed_val):
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.25
	noise.fractal_octaves = 4
	
	seed = seed_val
	noise.seed = seed


func get_aabb(position, size) -> Rect2:
	return Rect2(position - size / 2.0, size)

func generate_islands():
	islands = []
	for i in range(island_count):
		rng.seed = seed + i
		var baseType = islandBaseTypes[rng.randf_range(0, islandBaseTypes.size())]
		var shapeType = islandShapeTypes[0]
		var island = islandGen.generate_island_main_mesh(noise, i, baseType, shapeType)
		
		add_child(island)
		islands.append(island)
		var attempt = 0
		"""
		while attempt < 10000: 
			
			var x = noise.get_noise_2d(attempt, 0) * grid_size
			var z = noise.get_noise_2d(attempt, 1000) * grid_size
			var position = Vector3(x, 0, z)
			
			var overlaps = false
			for isle in islands:
				if isle == island:
					continue
				
				var new_island_rect = get_aabb(Vector2(position.x, position.z), island.get_meta("island_data").size) 
				var isle_rect = get_aabb(Vector2(isle.position.x, isle.position.z), isle.get_meta("island_data").size) 
				
				if new_island_rect.intersects(isle_rect):
					overlaps = true
					break
					
			if not overlaps:
				island.position = position
				break
				
			attempt+=1
		"""
	for i in range(islands.size()):
		var island = islands[i]
		print(mountainTypes[0])
		var mountains = mountainGen.generate_mountains(noise, i, mountainTypes[0], Vector2(50, 50))
		for mountain in mountains:
			island.add_child(mountain)
		
		"""
		rng.seed = seed + i
		var mountainCount = rng.randi_range(1, 3)
		for m in range(mountainCount):
			rng.seed = seed + i + m
			var island = islands[i]
			var island_data = island.get_meta("island_data")
			var mountain_type = mountainTypes[rng.randf_range(0, mountainTypes.size())]
			var pos = Heatmap.sample_from_heatmap(island_data.heatmap, 0.1, 1, true, seed + i + m)
			var radius = Heatmap.get_max_radius(island_data.heatmap, pos, mountain_type.cluster_max_radius, 0.3)
			var attempt = 0
			while radius < mountain_type.cluster_min_radius and attempt < 1000:
				rng.seed = seed + i + m + attempt
				#mountain_type = mountainTypes[rng.randf_range(0, mountainTypes.size())]
				pos = Heatmap.sample_from_heatmap(island_data.heatmap, 0.1, 1, true, seed + i + m + attempt)
				radius = Heatmap.get_max_radius(island_data.heatmap, pos, 35, 0.3)
				attempt += 1
			
			if attempt != 1000:
				var mountain = mountainGen.generate_mountain_mesh(noise, i + m + attempt, mountain_type, radius)
				Heatmap.write_circle_to_heatmap(island_data.heatmap, pos, radius*0.75)
				
				mountain.position = Vector3(pos.x, 0, pos.y)
				island.add_child(mountain)
		"""
	
func generate_circle_on_island_top(radius, segments):
	var st = SurfaceTool.new()

	# Begin mesh creation using triangles
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	
	st.add_vertex(Vector3.ZERO)
	for i in range(segments):
		var angle = (TAU / segments) * i
		var v = Vector3(cos(angle)*radius,0,sin(angle)*radius)
		st.add_vertex(v)
	
	for i in range(1, segments):
		if(i < segments-1):
			st.add_index(0)
			st.add_index(i)
			st.add_index(i + 1)
		else:
			st.add_index(0)
			st.add_index(i)
			st.add_index(1)
			
	st.generate_normals()
	var mesh = st.commit()
	return mesh


func _on_button_button_down() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	
	seed = int(seedInput.text)
	setup_noise(seed)
	generate_islands()
