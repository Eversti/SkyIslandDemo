class_name MountainType
extends Resource

@export var tag: String

@export var min_size: Vector2
@export var max_size: Vector2

@export var gen_points: int
@export var jitter_range: NoiseRange

@export var main_peak_taper_range: NoiseRange
@export var main_peak_size_scale_mult_range: NoiseRange
@export var main_peak_height: NoiseRange
@export var main_peak_taper_offset_range: NoiseRange
@export var main_peak_top_rotation_angle_range: NoiseRange

@export var sub_peak_count: NoiseRange
@export var sub_peak_taper_range: NoiseRange
@export var sub_peak_size_scale_mult_range: NoiseRange
@export var sub_peak_offset: Vector2
@export var sub_peak_min_offset_distance: int
@export var sub_peak_min_height_diff: float
@export var sub_peak_height: NoiseRange
@export var sub_peak_taper_offset_range: NoiseRange
@export var taper_direction_same_as_offset: bool
@export var sub_peak_top_rotation_angle_range: NoiseRange
