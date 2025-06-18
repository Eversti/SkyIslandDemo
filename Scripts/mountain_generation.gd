class_name MountainGen
extends Node

func generate_irregular_top_and_bottom_planes(seed, base_radius, radius_reduction_rate, points_per_piece, taper):
	var rng = RandomNumberGenerator.new()
	rng.seed = seed
	
	var bottom = []
	var top = []
	
	var radius = base_radius
	
	for j in range(points_per_piece):
		rng.seed = rng.seed + j
		var angle = TAU * j / points_per_piece
		var r = radius * rng.randf_range(0.7, 1.0)
		var point = Vector2(cos(angle), sin(angle)) * r
		bottom.append(point)
	
	for k in range(points_per_piece):
		rng.seed = rng.seed + k
		var angle = TAU * k / points_per_piece
		var r = radius * rng.randf_range(0.8, 1.0) * taper
		var point = Vector2(cos(angle), sin(angle)) * r
		top.append(point)
	
	
	var top_border = Geometry2D.convex_hull(top)
	var bot_border = Geometry2D.convex_hull(bottom)
	var piece = {}
	piece["top_points"] = top
	piece["top_border"] = top_border
	piece["top_triangles"] = Geometry2D.triangulate_delaunay(top)
	piece["bottom_points"] = bottom
	piece["bottom_border"] = bot_border
	piece["bottom_triangles"] = Geometry2D.triangulate_delaunay(bottom)
	
	var triangles = []

	var top_i = 0
	var bottom_i = 0
	while top_i < (top_border.size()-1) and bottom_i < (bot_border.size()-1):
		var next_top_i = (top_i + 1) % top_border.size()
		var next_bottom_i = (bottom_i + 1) % bot_border.size()

		var dist_top = bot_border[bottom_i].distance_to(top_border[next_top_i])
		var dist_bottom = top_border[top_i].distance_to(bot_border[next_bottom_i])
		#print("top: " + str(top_i) + ", bottom: " + str(bottom_i))
		if dist_top < dist_bottom:
			var triangle = {}
			triangle["vertices"] = []
			triangle["orientation"] = "top"
			
			triangle["vertices"].append(top_border[top_i])
			triangle["vertices"].append(bot_border[bottom_i])
			triangle["vertices"].append(top_border[next_top_i])
			triangles.append(triangle)
			top_i += 1
		else:
			var triangle = {}
			triangle["vertices"] = []
			triangle["orientation"] = "bottom"
			
			triangle["vertices"].append(top_border[top_i])
			triangle["vertices"].append(bot_border[bottom_i])
			triangle["vertices"].append(bot_border[next_bottom_i])
			triangles.append(triangle)
			bottom_i += 1
	
	# Handle remaining top points
	while top_i < top_border.size() - 1:
		var next_top_i = (top_i + 1) % top_border.size()
		triangles.append({
			"vertices": [top_border[top_i], bot_border[bottom_i], top_border[next_top_i]],
			"orientation": "top"
		})
		top_i += 1

	# Handle remaining bottom points
	while bottom_i < bot_border.size() - 1:
		var next_bottom_i = (bottom_i + 1) % bot_border.size()
		triangles.append({
			"vertices": [top_border[top_i], bot_border[bottom_i], bot_border[next_bottom_i]],
			"orientation": "bottom"
		})
		bottom_i += 1
	
	piece["side_triangles"] = triangles
	
	return piece

func generate_mesh_with_irregular_planes(noise, mountain_index, type, max_radius):
	var planes = generate_irregular_top_and_bottom_planes(noise.seed+mountain_index, 30, 0.55, 12, 0.7)
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	
	var layer_count = int(type.layer_count_range.get_value(noise, mountain_index))
	var layer_height = type.layer_height_range.get_value(noise, mountain_index)
	var t_max = type.taper_max_range.get_value(noise, mountain_index)
	var t_noise_intensity = type.taper_noise_intensity_range.get_value(noise, mountain_index)
	
	var vertex_index_map: Dictionary = {}
	var vertex_map: Dictionary = {}
	var current_index = 0
	
	var top_points = planes["top_points"]
	var top_border = planes["top_border"]
	var top_triangles = planes["top_triangles"]
	var bottom_points = planes["bottom_points"]
	var bottom_border = planes["bottom_border"]
	var bottom_triangles = planes["bottom_triangles"]
	var side_triangles = planes["side_triangles"]
	#TOP AND BOTTOM VERTICES
	
	vertex_index_map[0] = []
	vertex_index_map[0].resize(bottom_border.size()-1)
	vertex_map[0] = []
	for point in range(bottom_points.size()):
		var vertex = Vector3(bottom_points[point].x, 0, bottom_points[point].y) 
		for b in range(bottom_border.size()):
			if bottom_points[point] == bottom_border[b]:
				vertex_index_map[0][b] = current_index
				break
		vertex_map[0].append(vertex)
		current_index += 1
	
	#var top_rad = 1.0 - t_max
	var topY = (layer_count-1) * layer_height
	var top_layer = (layer_count-1)
	vertex_index_map[top_layer] = []
	vertex_index_map[top_layer].resize(top_border.size()-1)
	vertex_map[top_layer] = []
	for point in range(top_points.size()):
		var vertex = Vector3(top_points[point].x, 0, top_points[point].y) #* top_rad
		vertex.y = topY
		vertex_map[top_layer].append(vertex)
		for b in range(top_border.size()):
			if top_points[point] == top_border[b]:
				vertex_index_map[top_layer][b] = current_index
				break
		current_index += 1
			

	#SIDES
	for layer_index in range(1, layer_count-1):
		var t = float(layer_index) / float(layer_count - 1)
		var taper_point = 1.0 - t
		
		vertex_index_map[layer_index] = []
		vertex_map[layer_index] = []
		for triangles in side_triangles:
			var verts = triangles["vertices"]
			var top = verts[0]
			var bot = verts[1]
			var top_vert = Vector3(top.x, topY, top.y)
			var bot_vert = Vector3(bot.x, 0, bot.y)
			var vertex_point = top_vert.lerp(bot_vert, taper_point)
			vertex_map[layer_index].append(vertex_point)
			vertex_index_map[layer_index].append(current_index)
			current_index += 1
	
	
	#DEFORM
	for v in range(vertex_map[layer_count-2].size()):
		var vert = vertex_map[layer_count-2][v]
		#vert -= Vector3(0, 1, 0)
		vertex_map[layer_count-2][v] = vert
	
	var tris = []
	for t in range(0, top_triangles.size(), 3):
		tris.append([top_triangles[t], top_triangles[t+1], top_triangles[t+2]])
	
	
	for i in range(vertex_index_map[layer_count-1].size()):
		var count = vertex_index_map[layer_count-1].size()
		var indices_before = vertex_index_map[layer_count-1].min()
		
		var prev = vertex_index_map[layer_count-1][(i - 1 + count) % count] - indices_before
		var current = vertex_index_map[layer_count-1][i] - indices_before
		var next = vertex_index_map[layer_count-1][(i + 1) % count] - indices_before
		
		for tri in tris:
			if current in tri and prev in tri and next in tri:
				var vert = vertex_map[layer_count-1][current]
				#vert -= Vector3(0, 1.5, 0)
				vertex_map[layer_count-1][current] = vert
	
	
	#Add verts 
	for vertex in vertex_map[0]:
		st.add_vertex(vertex)
	for vertex in vertex_map[layer_count-1]:
		st.add_vertex(vertex)
	for layer in range(1, layer_count-1):
		for vert in vertex_map[layer]:
			st.add_vertex(vert)
	
	#INDICES
	
	for triangle in range(0, bottom_triangles.size(), 3):
		var a = bottom_triangles[triangle]
		var b = bottom_triangles[triangle+1]
		var c = bottom_triangles[triangle+2]
		
		# Calculate signed area (positive = CCW, negative = CW)
		var area = (bottom_points[b].x - bottom_points[a].x) * (bottom_points[c].y - bottom_points[a].y) - (bottom_points[c].x - bottom_points[a].x) * (bottom_points[b].y - bottom_points[a].y)
		
		if (area < 0):
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
		else:
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
	
	
	for triangle in range(0, top_triangles.size(), 3):
		var a = top_triangles[triangle]
		var b = top_triangles[triangle+1]
		var c = top_triangles[triangle+2]
		
		# Calculate signed area (positive = CCW, negative = CW)
		var area = (top_points[b].x - top_points[a].x) * (top_points[c].y - top_points[a].y) - (top_points[c].x - top_points[a].x) * (top_points[b].y - top_points[a].y)
		
		if (area > 0):
			st.add_index(a+bottom_points.size())
			st.add_index(b+bottom_points.size())
			st.add_index(c+bottom_points.size())
		else:
			st.add_index(a+bottom_points.size())
			st.add_index(c+bottom_points.size())
			st.add_index(b+bottom_points.size())
	 
	
	
	var top = 0
	var bot = 0
	
	
	for t in range(side_triangles.size()):
		print("polygon("+str(side_triangles[t]["vertices"])+")")
		match side_triangles[t]["orientation"]:
			"bottom":
				var a = vertex_index_map[1][t]
				var b = vertex_index_map[1][(t + 1) % (side_triangles.size())]
				var c = vertex_index_map[0][bot]
				var d = vertex_index_map[0][(bot + 1) % (bottom_border.size()-1)]
				
				
				st.add_index(a)
				st.add_index(c)
				st.add_index(b)
				print([[a, c, b],[b,c,d]])
				
				st.add_index(b)
				st.add_index(c)
				st.add_index(d)
			
				var e = vertex_index_map[layer_count-1][top]
				var f = vertex_index_map[layer_count-2][t]
				var g = vertex_index_map[layer_count-2][(t + 1) % (side_triangles.size())]
				
				
				st.add_index(e)
				st.add_index(f)
				st.add_index(g)
				
				print([e, f, g])
				
				bot = (bot + 1) % (bottom_border.size()-1)
			
		
			"top":
				var a = vertex_index_map[1][t]
				var b = vertex_index_map[0][bot]
				var c = vertex_index_map[1][(t + 1) % (side_triangles.size())]
				
				
				st.add_index(a)
				st.add_index(b)
				st.add_index(c)
				
				var d = vertex_index_map[layer_count-1][top]
				var e = vertex_index_map[layer_count-1][(top + 1) % (top_border.size()-1)]
				var f = vertex_index_map[layer_count-2][t]
				var g = vertex_index_map[layer_count-2][(t + 1) % (side_triangles.size())]
				
				st.add_index(d)
				st.add_index(f)
				st.add_index(e)

				st.add_index(e)
				st.add_index(f)
				st.add_index(g)
				
				
				top = (top + 1) % (top_border.size()-1)
	
			
	
	for layer in range(1, layer_count - 2):
		for index in range(side_triangles.size()):
			var next_i = (index + 1) % (side_triangles.size())
			
			var a = vertex_index_map[layer+1][index]
			var b = vertex_index_map[layer+1][next_i]
			var c = vertex_index_map[layer][index]
			var d = vertex_index_map[layer][next_i]
			
			
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)

			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	
	
	st.generate_normals()
	#st.generate_tangents()
	var mesh = st.commit()
	
	var mountain = MeshInstance3D.new()
	mountain.mesh = mesh
		
	return mountain

func generate_bevel_triangles(seed, border):
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
		
		if bevel_indices.find((i-1+count)%count) == -1 and bevel_indices.find((i+1)%count) and cross < 0:
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
		var jitter_val = jitter.get_value(noise, index+i)
		var x = cos(angle) * width/2 * jitter_val
		var y = sin(angle) * height/2 * jitter_val
		result.append(Vector2(x, y) + position)
	return result

func generate_mountain_shape(noise, index, count, scale_range, offset_range, jitter, outer_size, attempt_limit = 100, offset_data = [], min_offset_dist=0):
	for i in range(attempt_limit):
		var width = outer_size.x * scale_range.get_value(noise, 432+index+i)
		var height = outer_size.y * scale_range.get_value(noise, -13-index-i)
		var widthRange = NoiseRange.new((outer_size.x - width)/float(2) * offset_range.x, (outer_size.x - width)/float(2) * offset_range.y)
		var heightRange = NoiseRange.new((outer_size.y - height)/float(2) * offset_range.x, (outer_size.y - height)/float(2) * offset_range.y)
		
		var offset = Vector2(widthRange.get_bi_range_value(noise, .234+index+i), heightRange.get_bi_range_value(noise, -0.23-index-i))
		var attempts = 0
		if offset_data.size() > 0:
			var valid = false
			while !valid and attempts < attempt_limit:
				attempts += 1
				valid = true
				var tryoffset = Vector2(widthRange.get_bi_range_value(noise, 0.43+index+i+attempts), heightRange.get_bi_range_value(noise, -0.23-index-i-attempts))
				for o in offset_data:
					var diff = o.distance_to(tryoffset)
					if diff < min_offset_dist:
						valid = false
						break
				if valid:
					offset = tryoffset
		
		var inner = generate_ellipse_points(noise, index*25+i, count, width, height, offset, jitter)
		var outerBoundary = Rect2(-outer_size*0.5, outer_size)
		var innerSize = Vector2(width, height)
		var innerRect = Rect2(offset-innerSize*0.5, innerSize)
		if outerBoundary.encloses(innerRect):
			offset_data.append(offset)
			return [inner, offset]
	return []

func generate_plane(noise, index, points):
	var hull = Geometry2D.convex_hull(points)
	hull.resize(hull.size()-1)
	#var smooth_border = SmoothPolygon.chaikin_smooth(hull, 1, 5)
	#print("index: " + str(index) + "\nhull: " + str(hull) + "\nsmooth: " + str(smooth_border))
	
	var plane = {}
	var triangulation = generate_bevel_triangles(seed, hull)
	
	plane["points"] = hull
	plane["bevel_indices"] = triangulation[0]
	plane["triangles"] = triangulation[1]
	return plane

func generate_mountain_mesh(noise, mountain_index, plane, height, taper, top_offset, top_rotation):
	var rng = RandomNumberGenerator.new()
	rng.seed = noise.seed + mountain_index
	var points = plane["points"]
	var triangles = plane["triangles"]
	var bevel_indices = plane["bevel_indices"]
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	
	var layer_count = 2
	var layer_height = height
	var t_max = taper
	
	var vertex_index_map: Dictionary = {}
	var vertex_map: Dictionary = {}
	var current_index = 0
	
	#Bottom
	var layer = 0
	vertex_index_map[layer] = []
	vertex_map[layer] = []
	for point in range(points.size()):
		var vertex = Vector3(points[point].x, 0, points[point].y)
		vertex_index_map[layer].append(current_index)
		vertex_map[layer].append(vertex)
		current_index += 1
		
	#Top
	layer = layer_count-1
	vertex_index_map[layer] = []
	vertex_map[layer] = []
	var yPos = layer_height * layer
	var sum = Vector3.ZERO
	
	for p in points:
		sum += Vector3(p.x, 0, p.y)
	var center = sum / points.size()
	center.y = yPos 
	
	for point in range(points.size()):
		var vertex = Vector3(points[point].x, 0, points[point].y)
		vertex *= t_max
		vertex.y = layer_height * layer
		vertex += Vector3(top_offset.x, 0, top_offset.y)
		var local = vertex - center
		vertex = top_rotation * local + center
		vertex_index_map[layer].append(current_index)
		vertex_map[layer].append(vertex)
		current_index += 1
	
	
	
	#Middle layers
	for l in range(1, layer_count-1):
		var t = float(l) / float(layer_count - 1)
		var taper_point = 1.0 - t
		vertex_index_map[l] = []
		vertex_map[l] = []
		for point in range(vertex_index_map[0].size()):
			var bottom = vertex_map[0][vertex_index_map[0][point]]
			var top = vertex_map[layer_count-1][vertex_index_map[0][point]]
	
			var vertex_point = top.lerp(bottom, taper_point)
			vertex_map[l].append(vertex_point)
			vertex_index_map[l].append(current_index)
			current_index += 1
	
	#DEFORM
	var verts_before_top = 0
	for l in range(vertex_map.size()-2):
		verts_before_top += vertex_map[l].size()
		
	
	for index in bevel_indices:
		rng.seed += index
		var vertex = vertex_map[layer_count-1][index]
		var vertex_bellow = vertex_map[layer_count-2][index]
		var new_vert = vertex.lerp(vertex_bellow, rng.randf_range(0.1, 0.9))
		vertex_map[layer_count-1][index] = new_vert
	
	#ADD VERTICES
	#BOTTOM
	for vertex in vertex_map[0]:
		st.add_vertex(vertex)
	
	#TOP
	for vertex in vertex_map[layer_count-1]:
		st.add_vertex(vertex)
	
	#SIDES
	for l in range(1, layer_count-1):
		for vert in vertex_map[l]:
			st.add_vertex(vert)
			
	
	#TOP INDICES
	for triangle in range(0, triangles.size(), 3):
		var a = triangles[triangle]
		var b = triangles[triangle+1]
		var c = triangles[triangle+2]
		
		# Calculate signed area (positive = CCW, negative = CW)
		var area = (points[b].x - points[a].x) * (points[c].y - points[a].y) - (points[c].x - points[a].x) * (points[b].y - points[a].y)
		
		if (area < 0):
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
		
		if (area > 0):
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
		else:
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
	

	#SIDE INDICES
	
	for l in range(layer_count -1):
		for index in range(vertex_index_map[l].size()):
			var next_i = (index + 1) % (vertex_index_map[l].size())
			
			var a = vertex_index_map[l+1][index]
			var b = vertex_index_map[l+1][next_i]
			var c = vertex_index_map[l][index]
			var d = vertex_index_map[l][next_i]
			
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)

			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	
			
	st.generate_normals()
	#st.generate_tangents()
	var mesh = st.commit()
		
	return mesh

func generate_mountains(noise, mountain_index, type, max_size):
	var mountains = []
	var all_points = []
	var axisRange = NoiseRange.new(0.05, 1.0)
	
	var main_peak_height = type.main_peak_height.get_value(noise, 98.2+mountain_index)
	var taper = type.main_peak_taper_range.get_value(noise, 54.4+mountain_index)
	var angle = deg_to_rad(type.main_peak_top_rotation_angle_range.get_bi_range_value(noise, mountain_index))
	var axis = Vector3(axisRange.get_bi_range_value(noise, 0.32+mountain_index), 0, axisRange.get_bi_range_value(noise, -0.123-mountain_index)).normalized()
	var rotation = Basis(axis, angle)
	var top_offset = Vector2(type.main_peak_taper_offset_range.get_bi_range_value(noise, 0.12+mountain_index), type.main_peak_taper_offset_range.get_bi_range_value(noise, -0.43-mountain_index))
	var shape = generate_mountain_shape(noise, mountain_index, type.gen_points, type.main_peak_size_scale_mult_range, Vector2(0, 0), type.jitter_range, max_size, 100)
	var points = shape[0]
	var plane = generate_plane(noise, mountain_index, points)
	
	var main = generate_mountain_mesh(noise, mountain_index, plane, main_peak_height, taper, top_offset, rotation)
	all_points.append_array(plane["points"])
	
	var count = int(round(type.sub_peak_count.get_value(noise, mountain_index)))
	var height_data = []
	var offset_data = []
	
	for i in range(1, count+1):
		var sub_peak_height = (type.sub_peak_height.max + type.sub_peak_height.min) / float(2)
		
		var attempts = 0
		var valid = false
		while !valid and attempts < 1000 :
			var try_height = type.sub_peak_height.get_value(noise, mountain_index+i+attempts)
			valid = true
			attempts += 1
			for sub in height_data:
				var height_diff = abs(sub - try_height)
				if height_diff < type.sub_peak_min_height_diff:
					valid = false
					break
			if valid:
				sub_peak_height = try_height
				height_data.append(try_height)
		
		taper = type.sub_peak_taper_range.get_value(noise, .45+mountain_index+i)
		angle = deg_to_rad(type.sub_peak_top_rotation_angle_range.get_bi_range_value(noise, 0.34+mountain_index+i))
		axis = Vector3(axisRange.get_bi_range_value(noise, 0.32+mountain_index+i), 0, axisRange.get_bi_range_value(noise, -0.123-mountain_index-i)).normalized()
		rotation = Basis(axis, angle)
		shape = generate_mountain_shape(noise, mountain_index+i, type.gen_points, type.sub_peak_size_scale_mult_range, type.sub_peak_offset, type.jitter_range, max_size, 100, offset_data, type.sub_peak_min_offset_distance)
		points = shape[0]
		var offset = shape[1]
		if type.taper_direction_same_as_offset:
			top_offset = offset.normalized() * type.sub_peak_taper_offset_range.get_value(noise, 0.134+mountain_index+i)
		else:
			top_offset = Vector2(type.sub_peak_taper_offset_range.get_bi_range_value(noise, 0.134+mountain_index+i), type.sub_peak_taper_offset_range.get_bi_range_value(noise, -0.24-mountain_index-i))
		plane = generate_plane(noise, mountain_index+i, points)
		mountains.append(generate_mountain_mesh(noise, mountain_index+i, plane, sub_peak_height, taper, top_offset, rotation))
		all_points.append_array(plane["points"])
		
	var mountain_hull = Geometry2D.convex_hull(all_points)
	mountain_hull.resize(mountain_hull.size()-1)
	
	return [main, mountains, mountain_hull]
