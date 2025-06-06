class_name NoiseRange
extends Resource

@export var min: float = 0.0
@export var max: float = 1.0

func get_value(noise: FastNoiseLite, key: float) -> float:
	var t = (noise.get_noise_1d(key) + 1.0) / 2.0
	return lerp(min, max, t)

func get_bi_range_value(noise: FastNoiseLite, key: float) -> float:
	var n = noise.get_noise_1d(key)
	if n < 0:
		#[-1, 0] → [-max, -min]
		return lerp(-max, -min, n + 1.0)
	else:
		#[0, 1] → [min, max]
		return lerp(min, max, n)
