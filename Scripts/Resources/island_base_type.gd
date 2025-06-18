class_name IslandBaseType
extends Resource

@export var points_per_peak: int
@export var main_peak_indices: Array[int]

@export var main_peak_count: NoiseRange
@export var main_peak_height_range: NoiseRange
@export var main_peak_height_reduction_rate_range: NoiseRange
@export var main_peak_taper_range: NoiseRange
@export var main_peak_offset_range: NoiseRange
@export var main_peak_rotation_angle_range: NoiseRange
@export var main_peak_jitter_range: NoiseRange
@export var main_peak_size_scale_mult_range: Vector2
@export var main_peak_size_scale_mult_addition_rate: float

@export var sub_peak_count: NoiseRange
@export var sub_peak_height_range: NoiseRange
@export var sub_peak_height_reduction_rate_range: NoiseRange
@export var sub_peak_taper_range: NoiseRange
@export var sub_peak_offset_range: NoiseRange
@export var sub_peak_rotation_angle_range: NoiseRange
@export var sub_peak_jitter_range: NoiseRange
@export var sub_peak_size_scale_mult_range: Vector2
@export var sub_peak_size_scale_mult_addition_rate: float
