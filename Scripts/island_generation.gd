class_name IslandGen
extends Node

var concave_gen = preload("res://Scripts/Utils/concave_hull.gd").new()

"""OLD CODE
func generate_step_shape(points):
	var concave = concave_gen.generate_concave_hull(points, 2)
	var triangles = concave[0]
	var hull = concave[1]
	
	var triangle_indices = []
	for triangle in triangles:
		#print("polygon(" + str(triangle) +")")
		triangle_indices.append(points.find(triangle[0]))
		triangle_indices.append(points.find(triangle[1]))
		triangle_indices.append(points.find(triangle[2]))
		
	var border_indices = []
	for point in hull:
		border_indices.append(points.find(point))
	
	var bevel_indices = []
	for i in range(border_indices.size()):
		var count = border_indices.size()
		var prev = border_indices[(i-1+count)%count]
		var current = border_indices[i]
		var next = border_indices[(i+1)%count]
		
		var target = [prev, current, next]
		for t in range(0, triangle_indices.size(), 3):
			var tri = [triangle_indices[t], triangle_indices[t + 1], triangle_indices[t + 2]]
			if target.all(func(x): return x in tri):
				if bevel_indices.find(prev) == -1 and bevel_indices.find(next) == -1:
					bevel_indices.append(current)
					
	var result = {}
	result["points"] = points
	result["border"] = border_indices
	result["bevel_indices"] = bevel_indices
	result["triangles"] = triangle_indices
	
	return result
"""

func generate_ellipse_points(noise, index, count, width, height, position, jitter):
	var result = []
	for i in count:
		var angle = float(i)/float(count) * TAU
		var jitter_val = jitter.get_value(noise, index+i)
		var x = cos(angle) * width/2 * jitter_val
		var y = sin(angle) * height/2 * jitter_val
		result.append(Vector2(x, y) + position)
	return result
	
func generate_inner_ellipse(noise, index, count, scale_range, max_offset, jitter, outer_polygon, outer_size, attempt_limit = 100):
	for i in attempt_limit:
		var width = outer_size.x * scale_range.get_value(noise, 0.31+index+i)
		var height = outer_size.y * scale_range.get_value(noise, -0.3-index-i)
		var widthRange = NoiseRange.new(0, (outer_size.x - width) * max_offset)
		var heightRange = NoiseRange.new(0, (outer_size.y - height) * max_offset)
		var offset = Vector2(widthRange.get_bi_range_value(noise, 0.23+index+i), heightRange.get_bi_range_value(noise, -0.3-index-i))
		var sum = Vector2.ZERO
		for p in outer_polygon:
			sum += p
		var center = sum / outer_polygon.size() 
		var inner = generate_ellipse_points(noise, index+i, count, width, height, center + offset, jitter)
		var clipped = Geometry2D.clip_polygons(outer_polygon, inner)
		
		if clipped.size() == 2:
			if Geometry2D.is_polygon_clockwise(clipped[0]) != Geometry2D.is_polygon_clockwise(clipped[1]):
				return inner
	return []

func generate_island_shape(noise, index, shape_type):
	var points = []
	var clusters = []
	for cluster in range(shape_type.cluster_size.size()):
		var size = shape_type.cluster_size[cluster]
		var width = size.x
		var height = size.y
		var gen_points = shape_type.max_cluster_points[cluster]
		var pos = shape_type.cluster_position[cluster]
		var jitter = shape_type.cluster_jitter_range
		var clusterPoints = generate_ellipse_points(noise, index, gen_points, width, height, pos, jitter)
		var hull = Geometry2D.convex_hull(clusterPoints)
		hull.resize(hull.size()-1)
		clusters.append([hull, Vector2(width, height)])
		points.append_array(clusterPoints)
		
	
	var result = concave_gen.generate_concave_hull(points, 2)
	var hull = result[1]
	
	var triangle_indices = []
	var concave_triangles = result[0]
	for triangle in concave_triangles:
		#print("polygon(" + str(triangle) +")")
		triangle_indices.append(points.find(triangle[0]))
		triangle_indices.append(points.find(triangle[1]))
		triangle_indices.append(points.find(triangle[2]))

	var plane = {}

	var border_indices = []
	for point in hull:
		border_indices.append(points.find(point))
	
	var bevel_indices = []
	for i in range(border_indices.size()):
		var count = border_indices.size()
		var prev = border_indices[(i-1+count)%count]
		var current = border_indices[i]
		var next = border_indices[(i+1)%count]
		
		var target = [prev, current, next]
		for t in range(0, triangle_indices.size(), 3):
			var tri = [triangle_indices[t], triangle_indices[t + 1], triangle_indices[t + 2]]
			if target.all(func(x): return x in tri):
				if bevel_indices.find(prev) == -1 and bevel_indices.find(next) == -1:
					bevel_indices.append(current)
	
	
	plane["points"] = points
	plane["border"] = border_indices
	plane["bevel_indices"] = bevel_indices
	plane["triangles"] = triangle_indices
	plane["clusters"] = clusters
	return plane

func generate_bevel_triangles(border):
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
		
		if bevel_indices.find((i-1+count)%count) == -1 and bevel_indices.find((i+1)%count) and cross > 0:
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
	
	bevel_triangles.append_array(triangles)
	return [bevel_indices, bevel_triangles]

func generate_mesh(points, border, bevel_indices, triangles, triangles_ordered, bottom_offset, bottom_rotation, top_rad_scale, bottom_rad_scale, startY, layer_height, noise, island_index):
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	
	var vertex_index_map: Dictionary = {}
	var vertex_map: Dictionary = {}
	var current_index = 0
	
	var sum = Vector3.ZERO
	for p in points:
		sum += Vector3(p.x, 0, p.y)
	var center = sum / points.size() 
	
	#TOP
	var layer = 0
	vertex_map[layer] = []
	for point in range(points.size()):
		var vertex = Vector3(points[point].x, 0, points[point].y)
		var offset = vertex - center
		offset *= top_rad_scale
		vertex = center + offset
		
		vertex.y = startY
		
		vertex_map[layer].append(vertex)
		current_index += 1
	
	#ADD INDICES FOR BORDER OF BOTTOM AND TOP LAYER
	vertex_index_map[0] = []
	vertex_index_map[1] = []
	for index in border:
		vertex_index_map[0].append(index)
		vertex_index_map[1].append(index + current_index)
	
	#BOTTOM
	layer = 1
	vertex_map[layer] = []
	var yPos = startY -layer_height * layer
	center.y = yPos
	
	for point in range(points.size()):
		var vertex = Vector3(points[point].x, 0, points[point].y)
		#Scale vector:
		var offset = vertex - center
		offset *= bottom_rad_scale
		vertex = center + offset
		
		vertex.y = yPos
		vertex += Vector3(bottom_offset.x, 0, bottom_offset.y)
		var local = vertex - center
		vertex = bottom_rotation * local + center
		vertex_map[layer].append(vertex)
		current_index += 1
	
	var bottom_bevel_indices = []
	var bevel_range = NoiseRange.new(0.1, 0.9)
	for i in range(border.size()):
		if bevel_indices.find(border[i]) != -1:
			var vertex = vertex_map[1][border[i]]
			var vertex_bellow = vertex_map[0][border[i]]
			var new_vert = vertex.lerp(vertex_bellow, bevel_range.get_value(noise, island_index+i))
			vertex_map[1][border[i]] = new_vert
			bottom_bevel_indices.append(border[i])
		

	
	#ADD VERTS
	for vertex in vertex_map[0]:
		st.add_vertex(vertex)
		
	for vert in vertex_map[1]:
		st.add_vertex(vert)

	#TOP INDICES
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
	
	#BOTTOM INDICES
	for triangle in range(0, triangles.size(), 3):
		var a = triangles[triangle]
		var b = triangles[triangle+1]
		var c = triangles[triangle+2]
		
		# Calculate signed area (positive = CCW, negative = CW)
		var area = (points[b].x - points[a].x) * (points[c].y - points[a].y) - (points[c].x - points[a].x) * (points[b].y - points[a].y)
		
		a += vertex_map[0].size()
		b += vertex_map[0].size()
		c += vertex_map[0].size()
		
		if (area < 0 or triangles_ordered):
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
		else:
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			
	#SIDE INDICES
	for index in range(border.size()):
		var next_i = (index + 1) % (border.size())
		
		var a = vertex_index_map[1][index]
		var b = vertex_index_map[1][next_i]
		var c = vertex_index_map[0][index]
		var d = vertex_index_map[0][next_i]
		
		st.add_index(a)
		st.add_index(c)
		st.add_index(b)

		st.add_index(b)
		st.add_index(c)
		st.add_index(d)

	st.generate_normals()
	var mesh = st.commit()
	
	return mesh

func generate_island(noise, island_index, shape_type):
	var base_type = shape_type.base
	var plane = generate_island_shape(noise, island_index, shape_type)
	var taper = base_type.main_peak_taper_range.get_value(noise, island_index)
	var currentShape = plane
	var result = generate_mesh(
			currentShape["points"],
			currentShape["border"],
			currentShape["bevel_indices"],
			currentShape["triangles"],
			false,
			Vector2.ZERO,
			Basis(Vector3.UP, 0),
			1,
			0.8,
			0,
			15,
			noise,
			island_index)
	
	var island_mesh = result
	var island_data = Island.new()
	var shapePoints = currentShape["points"]
	var borderIndices = currentShape["border"]
	var borderPoints = []
	borderPoints.resize(borderIndices.size())
	var max_distance = 0
	for point in range(shapePoints.size()):
		if borderIndices.has(point):
			borderPoints[borderIndices.find(point)] = shapePoints[point]
			var dist = shapePoints[point].distance_to(Vector2.ZERO)
			if dist > max_distance: max_distance = dist
		
	island_data.border = borderPoints
	island_data.max_dist_from_center = max_distance
	
	var peaks = []
	for cluster in range(plane["clusters"].size()):
		if base_type.main_peak_indices.has(cluster):
			var main_peak_count = int(round(base_type.main_peak_count.get_value(noise, island_index)))
			var height = base_type.main_peak_height_range.get_value(noise, island_index)
			var peak = []
			for i in range(main_peak_count):
				taper = base_type.main_peak_taper_range.get_value(noise, island_index)
				var angle = deg_to_rad(base_type.main_peak_rotation_angle_range.get_bi_range_value(noise, island_index))
				var axis = Vector3(noise.get_noise_1d(324+island_index+i), 0, noise.get_noise_1d(-123-island_index-i)).normalized()
				var rotation = Basis(axis, angle)
				var offset = Vector2(base_type.main_peak_offset_range.get_bi_range_value(noise, island_index+i), base_type.main_peak_offset_range.get_bi_range_value(noise, -island_index-i))
				var clusterShape = plane["clusters"][cluster][0]
				var clusterSize = plane["clusters"][cluster][1]
				var scaleMultRange = NoiseRange.new(base_type.main_peak_size_scale_mult_range.x + base_type.main_peak_size_scale_mult_addition_rate*i, base_type.main_peak_size_scale_mult_range.y + base_type.main_peak_size_scale_mult_addition_rate*i)
				var points = generate_inner_ellipse(noise, island_index+i, base_type.points_per_peak, scaleMultRange, float(i)/float(main_peak_count), base_type.main_peak_jitter_range, clusterShape, clusterSize)
				points.reverse()
				var bevel_result = generate_bevel_triangles(points)
				var border_indices = []
				for point in range(points.size()):
					border_indices.append(point)
				result = generate_mesh(
					points,
					border_indices,
					bevel_result[0],
					bevel_result[1],
					true,
					offset,
					rotation,
					1,
					taper,
					0,
					height,
					noise,
					island_index)
				peak.append(result)
				height -= height*base_type.main_peak_height_reduction_rate_range.get_value(noise, island_index+cluster+i)
			peaks.append(peak)
		else:
			var sub_peak_count = int(round(base_type.sub_peak_count.get_value(noise, island_index)))
			var peak = []
			var height = base_type.sub_peak_height_range.get_value(noise, island_index+cluster)
			for i in range(sub_peak_count):
				taper = base_type.sub_peak_taper_range.get_value(noise, island_index)
				var angle = deg_to_rad(base_type.sub_peak_rotation_angle_range.get_bi_range_value(noise, island_index+cluster+i))
				var axis = Vector3(noise.get_noise_1d(324+island_index+cluster+i), 0, noise.get_noise_1d(-123-island_index-cluster-i)).normalized()
				var rotation = Basis(axis, angle)
				var offset = Vector2(base_type.sub_peak_offset_range.get_bi_range_value(noise, island_index+cluster+i), base_type.sub_peak_offset_range.get_bi_range_value(noise, -island_index-cluster-i))
				var clusterShape = plane["clusters"][cluster][0]
				var clusterSize = plane["clusters"][cluster][1]
				var scaleMultRange = NoiseRange.new(base_type.sub_peak_size_scale_mult_range.x + base_type.sub_peak_size_scale_mult_addition_rate*i, base_type.sub_peak_size_scale_mult_range.y + base_type.sub_peak_size_scale_mult_addition_rate*i)
				var points = generate_inner_ellipse(noise, island_index+cluster+i, base_type.points_per_peak, scaleMultRange, float(i)/float(sub_peak_count), base_type.sub_peak_jitter_range, clusterShape, clusterSize)
				points.reverse()
				var bevel_result = generate_bevel_triangles(points)
				var border_indices = []
				for point in range(points.size()):
					border_indices.append(point)
				result = generate_mesh(
					points,
					border_indices,
					bevel_result[0],
					bevel_result[1],
					true,
					offset,
					rotation,
					0.8,
					taper,
					0,
					height,
					noise,
					island_index)
				peak.append(result)
				height -= height*base_type.sub_peak_height_reduction_rate_range.get_value(noise, island_index+cluster+i)
			peaks.append(peak)
	
	return [island_data, island_mesh, peaks]
