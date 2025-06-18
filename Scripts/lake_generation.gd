extends Node

func generate_ellipse_points(noise, index, count, width, height, jitter):
	var result = []
	for i in count:
		var angle = float(i)/float(count) * TAU
		var jitter_val = jitter.get_value(noise, index+i)
		var x = cos(angle) * width/2 * jitter_val
		var y = sin(angle) * height/2 * jitter_val
		result.append(Vector2(x, y))
	return result
	

func generate_lake(noise, index, gen_points, size):
	var jitter = NoiseRange.new(0.7, 1.0)
	var clusterPoints = generate_ellipse_points(noise, index, gen_points, size.x, size.y, jitter)
	var hull = Geometry2D.convex_hull(clusterPoints)
	hull.resize(hull.size()-1)
	var triangulation = Geometry2D.triangulate_delaunay(hull)
	
	var min = Vector2(INF, INF)
	var max = Vector2(-INF, -INF)
	var center = Vector2.ZERO
	for p in hull:
		min = min.min(p)
		max = max.max(p)
		center += p
	
	center /= hull.size()
	var meshSize = max - min
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	
	var center_uv = (Vector2(0,0) - min) / meshSize
	st.set_uv(center_uv)
	st.set_uv2(Vector2(1, 1))
	st.add_vertex(Vector3(0,0,0))
	
	for p in hull:
		var uv = (p - min) / meshSize
		st.set_uv(uv)
		var dist = p.distance_to(center)
		st.set_uv2(Vector2(0, 0))
		st.add_vertex(Vector3(p.x, 0, p.y))
		
	for i in range(hull.size()):
		var current = i+1
		var next = (i+2) if i < hull.size()-1 else 1
		
		st.add_index(current)
		st.add_index(next)
		st.add_index(0)
	
	st.generate_normals()
	var mesh = st.commit()
	
	return [mesh, hull]
