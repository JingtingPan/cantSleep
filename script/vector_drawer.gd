# DebugVectorDrawer.gd
# 用于在 3D 空间中绘制向量线条，帮助调试方向判断逻辑
# 挂载到任意 Node3D 节点下即可使用

extends Node3D

var start_point: Vector3 = Vector3.ZERO
var end_point: Vector3 = Vector3.ZERO
var color: Color = Color.RED

@onready var line_mesh := ImmediateMesh.new()
@onready var mesh_instance := MeshInstance3D.new()

func _ready():
	# 创建用于绘制的 mesh 实例
	mesh_instance.mesh = line_mesh
	add_child(mesh_instance)
	set_notify_transform(true)

func _process(_delta):
	_update_line()

func set_line(from_point: Vector3, to_point: Vector3, line_color: Color = Color.RED):
	start_point = from_point
	end_point = to_point
	color = line_color

func _update_line():
	line_mesh.clear_surfaces()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	line_mesh.surface_set_color(color)
	line_mesh.surface_add_vertex(start_point)
	line_mesh.surface_add_vertex(end_point)
	line_mesh.surface_end()
