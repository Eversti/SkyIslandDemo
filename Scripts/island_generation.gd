class_name IslandGen
extends Resource

var concaveHull = ConcaveHull.new()

func is_ccw(a: Vector2, b: Vector2, c: Vector2) -> bool:
	return ((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)) > 0

func generate_bevel_triangles(seed, border):
	var rng = RandomNumberGenerator.new()
	var count = border.size()
	
	var bevel_triangles = []
	var bevel_indices = []
	for i in range(count):
		var prev = border[(i-1+count)%count]
		var current = border[i]
		var next = border[(i+1)%count]
		
		var v1 = (prev - current).normalized()
		var v2 = (next - current).normalized()
		var cross = v1.cross(v2)
		
		rng.seed += 1
		var chance = rng.randf()
		if chance < 0.5 and bevel_indices.find((i-1+count)%count) == -1 and bevel_indices.find((i+1)%count) and cross < 0:
			bevel_indices.append(i)
			
			bevel_triangles.append((i-1+count)%count)
			bevel_triangles.append(i)
			bevel_triangles.append((i+1)%count)
			
	
	var triangles = []
	var index_map = []
	var remainingPoints = []
	
	for i in range(count):
		if bevel_indices.find(i) == -1:
			index_map.append(i)
			remainingPoints.append(border[i])
		
	var delaunay = Geometry2D.triangulate_delaunay(remainingPoints)
	for i in delaunay:
		triangles.append(index_map[i])
	
	"""
	for i in range(0, triangles.size(), 3):
		print("polygon(" + str(border[triangles[i]]) + ", " + str(border[triangles[i+1]]) + ", " + str(border[triangles[i+2]]) + ")")
	
	print("\n")
	
	for i in range(0, bevel_triangles.size(), 3):
		print("polygon(" + str(border[bevel_triangles[i]]) + ", " + str(border[bevel_triangles[i+1]]) + ", " + str(border[bevel_triangles[i+2]]) + ")")
		
	for i in bevel_indices:
		print(border[i])
	"""
	
	bevel_triangles.append_array(triangles)
	return [bevel_indices, bevel_triangles]

func generate_ellipse_points(noise, index, count, width, height, position, jitter):
	var result = []
	for i in count:
		var angle = float(i)/float(count) * TAU
		var radius = jitter.get_value(noise, index+i)
		var x = cos(angle) * width/2 * radius
		var y = sin(angle) * height/2 * radius
		result.append(Vector2(x, y) + position)
	return result

func generate_island_shape(noise, index, shape_type):
	var points = []
	for cluster in range(shape_type.cluster_size.size()):
		var size = shape_type.cluster_size[cluster]
		var width = size.x
		var height = size.y
		var gen_points = shape_type.max_cluster_points[cluster]
		var pos = shape_type.cluster_position[cluster]
		var jitter = shape_type.cluster_jitter_range
		points.append_array(generate_ellipse_points(noise, index, gen_points, width, height, pos, jitter))
		
	
	var result = concaveHull.generate_concave_hull(points, 2)
	var hull = result[1]
	#hull.resize(hull.size()-1)
	var smooth_border = SmoothPolygon.chaikin_smooth(hull, 1, 20)
	print("index: " + str(index) + "\nhull: " + str(hull) + "\nsmooth: " + str(smooth_border))
	
	var triangle_indices = []
	var concave_triangles = result[0]
	for triangle in concave_triangles:
		print("polygon(" + str(triangle) +")")
		triangle_indices.append(points.find(triangle[0]))
		triangle_indices.append(points.find(triangle[1]))
		triangle_indices.append(points.find(triangle[2]))
	
	print(triangle_indices)
	
	var plane = {}
	var triangulation = generate_bevel_triangles(seed, smooth_border)
	
	plane["points"] = points
	plane["bevel_indices"] = triangulation[0]
	plane["triangles"] = triangle_indices
	
	
	return plane

func generate_island_main_mesh(noise, island_index, base_type, shape_type):
	var plane = generate_island_shape(noise, island_index, shape_type)
	var points = plane["points"]
	var triangles = plane["triangles"]
	var bevel_indices = plane["bevel_indices"]
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	
	var layer_count = 2
	var layer_height = 10
	var t_max = 0.5
	
	var vertex_index_map: Dictionary = {}
	var vertex_map: Dictionary = {}
	var current_index = 0
	
	#Bottom
	var layer = 0
	vertex_index_map[layer] = []
	vertex_map[layer] = []
	for point in range(points.size()):
		var vertex = Vector3(points[point].x, 0, points[point].y)
		#vertex += Vector3(offset.x, 0, offset.y)
		vertex_index_map[layer].append(current_index)
		vertex_map[layer].append(vertex)
		current_index += 1
	
	
	for vertex in vertex_map[0]:
		st.add_vertex(vertex)

	for triangle in range(0, triangles.size(), 3):
		var a = triangles[triangle]
		var b = triangles[triangle+1]
		var c = triangles[triangle+2]
		
		# Calculate signed area (positive = CCW, negative = CW)
		var area = (points[b].x - points[a].x) * (points[c].y - points[a].y) - (points[c].x - points[a].x) * (points[b].y - points[a].y)
		
		if (area > 0):
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
		else:
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)

	st.generate_normals()
	#st.generate_tangents()
	var mesh = st.commit()
	
	var island = MeshInstance3D.new()
	island.mesh = mesh
	
	#var island_data = Island.new()
	#island_data.size = size
	#island_data.base_type = base_type
	#island_data.shape_type = shape_type
	
	#var heatmap = Heatmap.generate_heatmap(hull, 3.0)
	#Heatmap.score_heatmap(heatmap, hull, noise.seed)
	#island_data.heatmap = heatmap
	
	#island.set_meta("island_data", island_data)
	return island

func generate_island():
	print("yeah")
