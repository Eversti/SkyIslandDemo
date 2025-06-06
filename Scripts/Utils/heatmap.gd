extends Node

func generate_heatmap(border_points, resolution = 1.0):
	var aabb = Rect2()
	for p in border_points:
		aabb = aabb.expand(p)

	var width = ceil(aabb.size.x / resolution)
	var height = ceil(aabb.size.y / resolution)

	var heatmap = []
	var positions = []  # actual world-space positions

	for y in range(height):
		for x in range(width):
			var local_pos = Vector2(x * resolution, y * resolution) + aabb.position
			positions.append(local_pos)
			heatmap.append(0.0)  # start with zeroes

	return {
		"positions": positions,
		"heatmap": heatmap,
		"width": width,
		"height": height,
		"aabb": aabb,
		"border": border_points,
		"resolution": resolution
	}

func score_heatmap(data, border_points, seed):
	var positions = data["positions"]
	var heatmap = data["heatmap"]
	var aabb = data["aabb"]
	var center = aabb.position + aabb.size / 2.0
	var noise = FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 0.1
	
	for i in positions.size():
		var p = positions[i]

		# 1. Distance from border
		var closest_dist = INF
		for b in border_points:
			closest_dist = min(closest_dist, p.distance_to(b))
		closest_dist = clamp(closest_dist / 50.0, 0.0, 1.0)  # normalize
		
		# 2. Centrality
		var centrality = 1.0 - clamp(p.distance_to(center) / (aabb.size.length() * 0.5), 0.0, 1.0)

		# 3. Noise (for variety)
		var noise_val = (noise.get_noise_2d(p.x, p.y) + 1.0) * 0.5

		# Combine scores with weights
		var score = 0.5 * closest_dist + 0.3 * centrality + 0.2 * noise_val
		heatmap[i] = score

func get_heatmap_index(pos, heatmap_data):
	var resolution = heatmap_data["resolution"]
	var local_pos = pos - heatmap_data["aabb"].position

	var x = int(floor(local_pos.x / resolution))
	var y = int(floor(local_pos.y / resolution))

	if x < 0 or y < 0 or x >= heatmap_data["width"] or y >= heatmap_data["height"]:
		return -1  # outside bounds

	return y * heatmap_data["width"] + x

func sample_from_heatmap(
		heatmap_data,
		min_score = 0.0,
		max_score = 1.0,
		randomize = true,
		seed = 0
	):
	
	var positions= heatmap_data["positions"]
	var scores= heatmap_data["heatmap"]
	var candidates = []

	# Filter by score
	for i in positions.size():
		var score = scores[i]
		if score >= min_score and score <= max_score:
			candidates.append(positions[i])

	# Shuffle candidates if needed
	if randomize:
		var rng = RandomNumberGenerator.new()
		rng.seed = seed
		shuffle_array(candidates, rng)

	return candidates[0]


func shuffle_array(arr, rng):
	for i in range(arr.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var temp = arr[i]
		arr[i] = arr[j]
		arr[j] = temp
		

func distance_to_border(heatmap, position):
	var closest_dist = INF
	for b in heatmap["border"]:
		closest_dist = min(closest_dist, position.distance_to(b))
	
	return closest_dist

func get_max_radius(heatmap, position, max_radius, threshold):
	var size = Vector2(heatmap["width"], heatmap["height"])
	var max_r = 0
	
	for r in range(1, max_radius + 1):
		for angle in range(0, 360, 5):
			var offset = Vector2(cos(deg_to_rad(angle)) * r, sin(deg_to_rad(angle)) * r)
			var check_pos = position + offset
			var index = get_heatmap_index(check_pos, heatmap)
			if index == -1:
				return max_r
			else:
				if heatmap["heatmap"][index] < threshold:
					return max_r
			if not Geometry2D.is_point_in_polygon(check_pos, heatmap["border"]):
				return max_r
		max_r = r
	return max_r
	
func write_circle_to_heatmap(heatmap_data, center, radius):
	var heatmap = heatmap_data["heatmap"]
	var positions = heatmap_data["positions"]
	var width = heatmap_data["width"]
	var height = heatmap_data["height"]
	var aabb = heatmap_data["aabb"]

	var resolution = heatmap_data["resolution"]
	var radius_sq = radius * radius

	for y in range(height):
		for x in range(width):
			var index = y * width + x
			var pos = positions[index]
			
			var dist_sq = center.distance_squared_to(pos)
			if dist_sq <= radius_sq:
				var dist = sqrt(dist_sq)
				var penalty = 1.0 - (dist / radius)  # center = 0, edge = 1
				var score = penalty  # so closer = lower score
				heatmap[index] = clamp(score, 0.0, heatmap[index])  # keep lowest score
