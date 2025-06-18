extends MultiMeshInstance3D

var mm 

func setup_heatmap(data):
	var positions = data["positions"]
	var values = data["heatmap"]
	var resolution = data["resolution"]

	mm = MultiMesh.new()
	mm.use_colors = true
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = positions.size()
	mm.mesh = PlaneMesh.new()
	mm.mesh.size = Vector2(resolution, resolution)

	for i in positions.size():
		var pos2d = positions[i]
		var score = values[i]
		var transform = Transform3D(Basis(), Vector3(pos2d.x, 0.1, pos2d.y))
		mm.set_instance_transform(i, transform)
		mm.set_instance_color(i, Color(score, score, score))
		
	multimesh = mm
	
func rescore_heatmap(data):
	var positions = data["positions"]
	var values = data["heatmap"]
	
	for i in positions.size():
		var pos2d = positions[i]
		var score = values[i]
		var transform = Transform3D(Basis(), Vector3(pos2d.x, 0.1, pos2d.y))
		mm.set_instance_transform(i, transform)
		mm.set_instance_color(i, Color(score, score, score))
