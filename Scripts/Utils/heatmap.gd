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
		"resolution": resolution,
		"masked_positions": [],
	}

func score_heatmap(data):
	var positions = data["positions"]
	var heatmap = data["heatmap"]
	var border_points = data["border"]
	var aabb = data["aabb"]
	var masked = data["masked_positions"]
	var mask_falloff_distance = 60.0  # tweak this for spread sensitivity

	for i in positions.size():
		var p = positions[i]
		
		if !Geometry2D.is_point_in_polygon(p, border_points) or masked.has(p):
			heatmap[i] = 0
			continue

		var closest_border_dist = INF
		for b in border_points:
			closest_border_dist = min(closest_border_dist, p.distance_to(b))
		closest_border_dist = clamp(closest_border_dist / 50.0, 0.0, 1.0)

		var dist_to_masked = INF
		for m in masked:
			dist_to_masked = min(dist_to_masked, p.distance_to(m))
		var mask_score = clamp(dist_to_masked / mask_falloff_distance, 0.0, 1.0)

		heatmap[i] = 0.5 * closest_border_dist + 0.5 * mask_score

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
	
	if candidates.size() > 0:
		return candidates[0]
	return []


func shuffle_array(arr, rng):
	for i in range(arr.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var temp = arr[i]
		arr[i] = arr[j]
		arr[j] = temp
		
func is_valid(index, heatmap, positions, border, min_score):
	if index >= positions.size(): return false
	var pos = positions[index]
	return Geometry2D.is_point_in_polygon(pos, border) and heatmap[index] >= min_score

func get_max_bounding_box_at_point(data, center, min_score, max_steps, max_ratio):
	var resolution = data["resolution"]
	var positions = data["positions"]
	var heatmap = data["heatmap"]
	var width = data["width"]
	var height = data["height"]
	var border = data["border"]
	var aabb_pos = data["aabb"].position
	
	var index = positions.find(center)
	var left = 0
	var right = 0
	var up = 0
	var down = 0

	var growing = true
	while growing:
		growing = false
		var box_width = 1+positions[index+right].x - positions[index-left].x
		var box_height = 1+positions[index+up*width].y - positions[index-down*width].y

		if left < max_steps and box_width / box_height <= max_ratio:
			var valid = true
			for dy in range(-down, up + 1):
				if not is_valid(index - (left + 1) + width * dy, heatmap, positions, border, min_score):
					valid = false
					break
			if valid:
				left += 1
				growing = true

		if right < max_steps and box_width / box_height <= max_ratio:
			var valid = true
			for dy in range(-down, up + 1):
				if not is_valid(index + (right + 1) + width * dy, heatmap, positions, border, min_score):
					valid = false
					break
			if valid:
				right += 1
				growing = true

		if up < max_steps and box_height / box_width <= max_ratio:
			var valid = true
			for dx in range(-left, right + 1):
				if not is_valid(index + dx + (up + 1) * width, heatmap, positions, border, min_score):
					valid = false
					break
			if valid:
				up += 1
				growing = true

		if down < max_steps and box_height / box_width <= max_ratio:
			var valid = true
			for dx in range(-left, right + 1):
				if not is_valid(index + dx - (down + 1) * width, heatmap, positions, border, min_score):
					valid = false
					break
			if valid:
				down += 1
				growing = true
	
	var box_width =  positions[index+right].x - positions[index-left].x
	var box_height = positions[index+up*width].y - positions[index-down*width].y
	
	var size = Vector2(box_width, box_height)
	var offset = positions[index - left - down * width]
	return Rect2(offset, size)
	
func mask_heatmap(data, polygon, offset, scale_multiplier):
	for i in range(polygon.size()):
		var point = polygon[i] * scale_multiplier + offset
		polygon[i] = point

	var masked_positions = []

	for i in data["positions"].size():
		var p = data["positions"][i]
		if Geometry2D.is_point_in_polygon(p, polygon):
			data["heatmap"][i] = 0
			masked_positions.append(p)
	data["masked_positions"].append_array(masked_positions)


func usable_cells(data, min_score):
	var heatmap = data["heatmap"]
	var total_usable_cells = 0
	for i in heatmap.size():
		if heatmap[i] >= min_score:
			total_usable_cells += 1
	return total_usable_cells
