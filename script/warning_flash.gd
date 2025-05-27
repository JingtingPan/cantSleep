# WarningFlash.gd
# 用于显示攻击前的全屏红色闪烁警告
# 挂载在 CanvasLayer 内的 ColorRect 节点上

extends ColorRect

@export var flash_speed: float = 2.0  # 闪烁速度（越高越快）
@export var min_alpha: float = 0.1   # 最小透明度
@export var max_alpha: float = 0.5   # 最大透明度

var flashing: bool = false
var time: float = 0.0

func _ready():
	color = Color(1, 0, 0, 0.0)  # 红色，初始透明
	visible = false

func _process(delta):
	if flashing:
		time += delta * flash_speed
		var alpha = lerp(min_alpha, max_alpha, 0.5 + 0.5 * sin(time))
		color.a = alpha

func start_flash():
	visible = true
	flashing = true
	time = 0.0

func stop_flash():
	flashing = false
	visible = false
