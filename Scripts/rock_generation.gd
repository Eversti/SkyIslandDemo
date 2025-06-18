extends Node
class_name RockGen

var height_range = NoiseRange.new(0.2, 0.5)
var jitter = NoiseRange.new(0.5, 1.0)
var taper_range = NoiseRange.new(0.5, 1.0)
var taper_offset_range = NoiseRange.new(0, 1) 
var top_rotation_range = NoiseRange.new(10, 20)
var rotation_axis_range = NoiseRange.new(0.1, 1)

func generate_ellipse_points(noise, index, count, width, height, jitter):
	var result = []
	for i in count:
		var angle = float(i)/float(count) * TAU
		var jitter_val = jitter.get_value(noise, index+i)
		var x = cos(angle) * width/2 * jitter_val
		var y = sin(angle) * height/2 * jitter_val
		result.append(Vector2(x, y))
	return result

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
	
	bevel_triangles.append_array(triangles)
	return [bevel_indices, bevel_triangles]

func generate_rock(noise, index, gen_points, size):
	var points = generate_ellipse_points(noise, index, gen_points, size.x, size.y, jitter)
	var hull = Geometry2D.convex_hull(points)
	hull.resize(hull.size()-1)
	var bevel = generate_bevel_triangles(hull)
	var bevel_indices = bevel[0]
	var triangles = bevel[1]
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	
	var vertex_index_map: Dictionary = {}
	var vertex_map: Dictionary = {}
	var current_index = 0
	
	var layer = 0
	vertex_index_map[layer] = []
	vertex_map[layer] = []
	for point in range(points.size()):
		var vertex = Vector3(points[point].x, 0, points[point].y)
		vertex_index_map[layer].append(current_index)
		vertex_map[layer].append(vertex)
		current_index += 1
		
	layer = 1
	vertex_index_map[layer] = []
	vertex_map[layer] = []
	var yPos = (size.x+size.y)/2.0 * height_range.get_value(noise, index)
	var sum = Vector3.ZERO
	
	for p in points:
		sum += Vector3(p.x, 0, p.y)
	var center = sum / points.size()
	center.y = yPos 
	
	var taper = taper_range.get_value(noise, index)
	var taper_offset = Vector2(taper_offset_range.get_bi_range_value(noise, index), taper_offset_range.get_bi_range_value(noise, -index))
	var angle = deg_to_rad(top_rotation_range.get_value(noise, index))
	var axis = Vector3(rotation_axis_range.get_bi_range_value(noise, index), 0, rotation_axis_range.get_bi_range_value(noise, index)).normalized()
	var rotation = Basis(axis, angle)
	
	for point in range(points.size()):
		var vertex = Vector3(points[point].x, 0, points[point].y)
		vertex *= taper
		vertex.y = yPos
		vertex += Vector3(taper_offset.x, 0, taper_offset.y)
		var local = vertex - center
		vertex = rotation * local + center
		vertex_index_map[layer].append(current_index)
		vertex_map[layer].append(vertex)
		current_index += 1
		
	var bevel_range = NoiseRange.new(0.1, 0.9)
	for i in bevel_indices:
		var vertex = vertex_map[1][i]
		var vertex_bellow = vertex_map[0][i]
		var new_vert = vertex.lerp(vertex_bellow, bevel_range.get_value(noise, index+i))
		vertex_map[1][i] = new_vert
		
	for vertex in vertex_map[0]:
		st.add_vertex(vertex)
	for vertex in vertex_map[1]:
		st.add_vertex(vertex)
		
	for triangle in range(0, triangles.size(), 3):
		var a = triangles[triangle]
		var b = triangles[triangle+1]
		var c = triangles[triangle+2]
		
		st.add_index(a)
		st.add_index(c)
		st.add_index(b)
			
	#BOTTOM INDICES
	for triangle in range(0, triangles.size(), 3):
		var a = triangles[triangle]
		var b = triangles[triangle+1]
		var c = triangles[triangle+2]
		
		a += vertex_map[0].size()
		b += vertex_map[0].size()
		c += vertex_map[0].size()
		
		st.add_index(a)
		st.add_index(b)
		st.add_index(c)
		
	for i in range(vertex_index_map[0].size()):
		var next_i = (i + 1) % (vertex_index_map[0].size())
		
		var a = vertex_index_map[1][i]
		var b = vertex_index_map[1][next_i]
		var c = vertex_index_map[0][i]
		var d = vertex_index_map[0][next_i]
		
		st.add_index(a)
		st.add_index(c)
		st.add_index(b)

		st.add_index(b)
		st.add_index(c)
		st.add_index(d)
		
	st.generate_normals()
	var mesh = st.commit()
	
	return {"mesh": mesh, "hull": hull}
