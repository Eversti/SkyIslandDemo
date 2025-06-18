extends Node
class_name TreeGen

var height_range = NoiseRange.new(4, 5)
var jitter = NoiseRange.new(0.8, 1.0)
var taper_range = NoiseRange.new(0.5, 1.0)
var taper_offset_range = NoiseRange.new(0, 1)

var leaf_height_range = NoiseRange.new(6, 8)
var mid_layer_lerp_range = NoiseRange.new(0.3, 0.7)
var mid_layer_scale_range = NoiseRange.new(0.5, 0.8)

func generate_ellipse_points(noise, index, count, width, height, jitter):
	var result = []
	for i in count:
		var angle = float(i)/float(count) * TAU
		var jitter_val = jitter.get_value(noise, index+i)
		var x = cos(angle) * width/2 * jitter_val
		var y = sin(angle) * height/2 * jitter_val
		result.append(Vector2(x, y))
	return result

func generate_trunk(noise, index, gen_points, size):
	var points = generate_ellipse_points(noise, index, gen_points, size.x, size.y, jitter)
	var hull = Geometry2D.convex_hull(points)
	hull.resize(hull.size()-1)
	var triangle_indices = Geometry2D.triangulate_delaunay(hull)
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	
	var vertex_index_map: Dictionary = {}
	var vertex_map: Dictionary = {}
	var current_index = 0
	
	var layer = 0
	vertex_index_map[layer] = []
	vertex_map[layer] = []
	for point in range(hull.size()):
		var vertex = Vector3(hull[point].x, 0, hull[point].y)
		vertex_index_map[layer].append(current_index)
		vertex_map[layer].append(vertex)
		current_index += 1
		
	layer = 1
	vertex_index_map[layer] = []
	vertex_map[layer] = []
	var yPos = height_range.get_value(noise, index)
	
	var taper = taper_range.get_value(noise, index)
	
	for point in range(hull.size()):
		var vertex = Vector3(hull[point].x, 0, hull[point].y)
		vertex *= taper
		vertex.y = yPos
		vertex_index_map[layer].append(current_index)
		vertex_map[layer].append(vertex)
		current_index += 1
		
	for vertex in vertex_map[0]:
		st.add_vertex(vertex)
	for vertex in vertex_map[1]:
		st.add_vertex(vertex)
		
	for i in triangle_indices:
		st.add_index(i)
			
	#BOTTOM INDICES
	for i in triangle_indices:
		st.add_index(i + vertex_map[0].size())
		
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
	
	return mesh

func generate_leaves(noise, index, gen_points, size):
	var points = generate_ellipse_points(noise, index, gen_points, size.x, size.y, jitter)
	var hull = Geometry2D.convex_hull(points)
	hull.resize(hull.size()-1)
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	
	var vertex_index_map: Dictionary = {}
	var vertex_map: Dictionary = {}
	var current_index = 0
	
	var startY = 1
	var height = leaf_height_range.get_value(noise, index)
	
	vertex_index_map[0] = []
	vertex_map[0] = []
	var vertex = Vector3(0, startY, 0)
	vertex_index_map[0].append(current_index)
	vertex_map[0].append(vertex)
	current_index += 1
	
	vertex_index_map[4] = []
	vertex_map[4] = []
	vertex = Vector3(0, startY+height, 0)
	vertex_index_map[4].append(current_index)
	vertex_map[4].append(vertex)
	current_index += 1
	
	
	vertex_index_map[2] = []
	vertex_map[2] = []
	for point in range(hull.size()):
		vertex = Vector3(hull[point].x, 0, hull[point].y)
		vertex.y = startY + height/2.0
		vertex_index_map[2].append(current_index)
		vertex_map[2].append(vertex)
		current_index += 1
		
	vertex_index_map[1] = []
	vertex_map[1] = []
	for point in range(hull.size()):
		vertex = Vector3(hull[point].x, 0, hull[point].y)
		vertex *= mid_layer_scale_range.get_value(noise, index+point)
		vertex.y = startY+lerp(0.0, height/2.0, mid_layer_lerp_range.get_value(noise, index+point))
		vertex_index_map[1].append(current_index)
		vertex_map[1].append(vertex)
		current_index += 1
	
	vertex_index_map[3] = []
	vertex_map[3] = []
	for point in range(hull.size()):
		vertex = Vector3(hull[point].x, 0, hull[point].y)
		vertex *= mid_layer_scale_range.get_value(noise, index+point+hull.size())
		vertex.y = startY+lerp(height/2.0, height, mid_layer_lerp_range.get_value(noise, index+point+hull.size()))
		vertex_index_map[3].append(current_index)
		vertex_map[3].append(vertex)
		current_index += 1
	
	st.add_vertex(vertex_map[0][0])
	st.add_vertex(vertex_map[4][0])
	
	for v in vertex_map[2]:
		st.add_vertex(v)
	for v in vertex_map[1]:
		st.add_vertex(v)
	for v in vertex_map[3]:
		st.add_vertex(v)
		
	for i in range(hull.size()):
		var next_i = (i + 1) % (hull.size())
		
		st.add_index(0)
		st.add_index(vertex_index_map[1][next_i])
		st.add_index(vertex_index_map[1][i])
	
	for i in range(hull.size()):
		var next_i = (i + 1) % (hull.size())
		
		st.add_index(1)
		st.add_index(vertex_index_map[3][i])
		st.add_index(vertex_index_map[3][next_i])
	
	for l in range(1, 3):
		for i in range(hull.size()):
			var next_i = (i + 1) % (hull.size())
			
			var a = vertex_index_map[l+1][i]
			var b = vertex_index_map[l+1][next_i]
			var c = vertex_index_map[l][i]
			var d = vertex_index_map[l][next_i]
			
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)

			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	
	st.generate_normals()
	var mesh = st.commit()
	
	return {"mesh": mesh, "hull": hull}

func generate_tree(noise, index, size):
	var trunk = generate_trunk(noise, index, 8, size*0.3)
	var leaves = generate_leaves(noise, index, 10, size)
	return {"trunk": trunk, "leaves": leaves.mesh, "hull": leaves.hull}
