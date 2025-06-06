extends Node

func chaikin_smooth(points: Array, iterations: int = 1, angle_threshold: float = 20.0) -> Array:
	var smoothed = points.duplicate()
	for _i in range(iterations):
		var new_points = []
		for j in range(smoothed.size()):
			var p0 = smoothed[j]
			var p1 = smoothed[(j + 1) % smoothed.size()]
			var prev = smoothed[(j - 1 + smoothed.size()) % smoothed.size()]
			
			# Calculate angle between previous-p0 and p0-p1
			var v1 = (p0 - prev).normalized()
			var v2 = (p1 - p0).normalized()
			var angle = rad_to_deg(acos(clamp(v1.dot(v2), -1, 1)))

			if angle < angle_threshold:
				# Keep sharp corners
				new_points.append(p0)
			else:
				var q = p0.lerp(p1, 0.25)
				var r = p0.lerp(p1, 0.75)
				new_points.append(q)
				new_points.append(r)
		smoothed = new_points
	return smoothed
