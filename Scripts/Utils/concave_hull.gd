extends Node

var triangle_was_removed = false

func generate_concave_hull(points, threshold = 1.8):
	var triangles = get_delaunay_triangles(points)
	var boundaries = get_boundaries(triangles)
	var boundary_triangles = get_boundary_triangles(triangles, boundaries)
	var concave_points = get_concave_points(points, boundaries)
	
	
	var current_index = 0
	
	while concave_points.size() > 0:
		var concave_point = concave_points[current_index]
		var concave_triangles = get_concave_triangle(concave_point, boundary_triangles)
		
		while concave_triangles.size() > 0:
			triangles = remove_triangles(triangles, concave_triangles, boundaries, threshold)
			if triangle_was_removed:
				boundaries = get_boundaries(triangles)
				boundary_triangles = get_boundary_triangles(triangles, boundaries)
				concave_points = get_concave_points(points, boundaries)
				current_index = 0	
			
			break
		if triangle_was_removed:
			triangle_was_removed = false
			
		if current_index + 1 == concave_points.size():
			boundaries = get_boundaries(triangles)
			var sorted = sort_vertices(boundaries)
			
			return [triangles, sorted]
				
		if current_index +1 < concave_points.size():
			current_index += 1
			continue
		else: current_index = 0
	return []

func get_delaunay_triangles(points):
	var triangulate = Geometry2D.triangulate_delaunay(points)
	var triangles = []
	
	for i in range(0, triangulate.size(), 3):
		var triangle = PackedVector2Array()
		
		for n in range(3):
			var point = Vector2(points[triangulate[i + n]].x, points[triangulate[i + n]].y)
			triangle.append(point)
		
		triangles.append(triangle)
	return triangles

func get_boundaries(triangles):
	var edges = []
	var outer_edges = []
	var inner_edges = []
	
	for triangle in triangles:
		for i in range(3):
			var edge = [triangle[i], triangle[(i + 1) % 3]]
			edge.sort()
			edges.append(edge)
	
	var edge_occurances = {}
	
	for edge in edges:
		if edge_occurances.has(edge):
			edge_occurances[edge] += 1
		else:
			edge_occurances[edge] = 1
			
	for key in edge_occurances.keys():
		if edge_occurances[key] == 1:
			outer_edges.append(key)
		elif edge_occurances[key] == 2:
			inner_edges.append(key)
		
	return outer_edges
	
func get_boundary_triangles(triangles, boundaries):
	var boundary_triangles = []
	
	for triangle in triangles:
		for i in range(3):
			var edge = [triangle[i], triangle[(i + 1) % 3]]
			edge.sort()
			
			if boundaries.has(edge):
				boundary_triangles.append(triangle)
				
	return boundary_triangles
	
func get_concave_points(points, boundaries):
	var concave_points = []
	var sorted_points = sort_vertices(boundaries)
	var sorted_edges = sort_edges(sorted_points)
	var deflated_shape = scale_points_by_normals(sorted_points, sorted_edges, -0.1)
	
	for point in points:
		var point_is_concave = Geometry2D.is_point_in_polygon(point, deflated_shape)
		
		if point_is_concave:
			concave_points.append(point)
	
	return concave_points

func sort_vertices(boundaries):
	var edge_map := {}

	# Step 1: Build map of connections
	for edge in boundaries:
		var a = edge[0]
		var b = edge[1]

		if not edge_map.has(a):
			edge_map[a] = []
		edge_map[a].append(b)

		if not edge_map.has(b):
			edge_map[b] = []
		edge_map[b].append(a)

	# Step 2: Find starting point
	var start = boundaries[0][0]
	var path := []
	var current = start
	var previous = null

	# Step 3: Walk the loop
	while true:
		path.append(current)
		var neighbors = edge_map[current]
		
		# Pick next point that isn't the one we just came from
		var next_point = null
		for n in neighbors:
			if n != previous:
				next_point = n
				break

		if next_point == null or next_point == start:
			break  # We're done

		previous = current
		current = next_point
	
	#ensure clockwise winding
	var area := 0.0
	for i in range(path.size()):
		var p1 = path[i]
		var p2 = path[(i + 1) % path.size()]
		area += (p2.x - p1.x) * (p2.y + p1.y)

	if area < 0:
		path.reverse()

	return path

func sort_edges(sorted_points):
	var sorted_edges = []
	
	for i in range(sorted_points.size()):
		var current_vertex = sorted_points[i]
		var next_index = (i + 1) % sorted_points.size()
		var next_vertex = sorted_points[next_index]
		
		var edge = [current_vertex, next_vertex]
		sorted_edges.append(edge)
		
	return sorted_edges

func scale_points_by_normals(sorted_points, sorted_edges, scale_factor):
	var scaled_points = []
	var vertex_normals = get_vertex_normals(sorted_points, sorted_edges)
	
	for i in range(sorted_points.size()):
		var scaled_point = sorted_points[i] + vertex_normals[i] * scale_factor
		scaled_points.append(scaled_point)
		
	return scaled_points

func get_vertex_normals(sorted_points, sorted_edges):
	var vertex_normals = []
	var edge_normals = []
	
	for i in range(sorted_edges.size()):
		edge_normals.append(get_edge_normal(sorted_edges[i]))
	
	for i in range(sorted_points.size()):
		var prev_index = (i - 1 + sorted_edges.size()) % sorted_edges.size()
		var prev_normal = edge_normals[prev_index]
		
		var current_normal 
		if i == sorted_points.size() - 1:
			current_normal = edge_normals[0]
		else:
			current_normal = edge_normals[i]
			
		var vertex_normal = (current_normal + prev_normal).normalized()
		vertex_normals.append(vertex_normal)
	
	return vertex_normals

func get_edge_normal(edge):
	var start = edge[0]
	var end = edge[1]
	
	var direction = end-start
	var normal = Vector2(-direction.y, direction.x).normalized()
	
	return normal

func get_concave_triangle(concave_point, boundary_triangles):
	var concave_triangles = []
	
	for triangle in boundary_triangles:
		if triangle.has(concave_point):
			concave_triangles.append(triangle)
			
	return concave_triangles

func remove_triangles(triangles, concave_triangles, boundaries, ratio_threshold):
	for triangle in concave_triangles:
		if triangle_was_removed:
			break
		var edge_lengths = []
		var boundary_edge = null
		for i in range(3):
			var edge = [triangle[i], triangle[(i + 1) % 3]]
			edge.sort()
		
			var edge_length = edge[0].distance_to(edge[1])
			edge_lengths.append(edge_length)
			
			if boundaries.has(edge):
				boundary_edge = edge
			
		if boundary_edge:
			var boundary_edge_length = boundary_edge[0].distance_to(boundary_edge[1])
			
			var other_edges = []
			
			for length in edge_lengths:
				if length != boundary_edge_length:
					other_edges.append(length)
					
			var other_edge_length_1 = other_edges[0]
			var other_edge_length_2 = other_edges[1]	
			
			var ratio1 = boundary_edge_length / other_edge_length_1
			var ratio2 = boundary_edge_length / other_edge_length_2
			
			if ratio1 > ratio_threshold or ratio2 > ratio_threshold:
				for tri in triangles:
					var triangle_array = PackedVector2Array(triangle)
					tri.sort()
					triangle_array.sort()
					if tri == triangle_array:
						triangles.erase(triangle)
						triangle_was_removed = true
						break
				
	return triangles
