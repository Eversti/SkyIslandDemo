extends Node

class_name MeshTreeNode

var mesh = null
var local_position = Vector3.ZERO
var material = null
var children = []

func new_entry(mesh, material, position=Vector3.ZERO):
	var node = MeshTreeNode.new()
	node.mesh = mesh
	node.local_position = position
	node.material = material
	node.children = []
	return node
