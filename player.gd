# FirstPersonSleepDemo.gd
# Godot 4.x 版本
# 控制在床上第一人称的基础交互：翻身、盖被子、探头看门/床底

extends CharacterBody3D
class_name Player

# 翻身方向
enum TurnDirection { LEFT, RIGHT }

# 玩家状态
var is_covered: bool = false
var looking_direction: Vector3 = Vector3.FORWARD
#固定视角
var fixed_rotations = [
	Vector3(90, 0, 0),      # 正前方
	Vector3(30, -90, -90),    # 右边
	Vector3(30, 90, 90)      # 左边
]
var ideal_view_vectors = [
	Vector3(0, 0, -1),  # 前
	Vector3(1, 0, 0),  # 右
	Vector3(-1, 0, 0)    # 左
]
var current_view_index = 0
var yaw = 0.0
var pitch = 0.0
var target_yaw: float = 0.0
var target_pitch: float = 0.0
# 输入锁
var is_turning: bool = false
var is_peeking: bool = false
var can_toggle_eye := true

# 交互参数
@export var turn_speed: float = 2.0
@export var max_peek_angle: float = 30.0 # 探头最大角度（度）
@export var max_yaw = 15.0 # 左右角度限制
@export var max_pitch_up = 25.0 # 上下角度限制
@export var max_pitch_down = -80.0 # 上下角度限制
@export var mouse_sensitivity = 0.2

# 节点引用
@onready var camera: Camera3D = $Node3D/Camera3D
@onready var blanket: MeshInstance3D = $blanket
@onready var state = PlayerStateController
@onready var eye_overlay: ColorRect = $CanvasLayer/ColorRect
@onready var head_pivot = $HeadPivot
@onready var camera_pivot = $HeadPivot/CameraPivot
func _ready():
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	blanket.visible = false
	print(eye_overlay)
func _process(delta):
	if not is_turning and not is_peeking:
		handle_basic_input()
		update_free_look()
# -------------------------
# 处理输入：翻身、盖被、探头、闭眼
# -------------------------
func handle_basic_input():
	if Input.is_action_just_pressed("turn_left"):
		start_turn(TurnDirection.LEFT)
	elif Input.is_action_just_pressed("turn_right"):
		start_turn(TurnDirection.RIGHT)
	elif Input.is_action_just_pressed("cover_toggle"):
		toggle_blanket()
	elif Input.is_action_pressed("peek"):
		start_peek()
	elif Input.is_action_just_released("peek"):
		stop_peek()
	elif Input.is_action_pressed("eye_toggle"):
		toggle_eyes()

# -------------------------
# 翻身逻辑（切换视角）
# -------------------------
func start_turn(direction: TurnDirection):
	is_turning = true
		# 根据方向改变索引
	if direction == TurnDirection.LEFT:
		current_view_index -= 1
	else:
		current_view_index += 1

	# 循环回绕视角索引，防止越界
	current_view_index = (current_view_index + fixed_rotations.size()) % fixed_rotations.size()
	# 同步状态控制器中当前视角信息
	state.set_view_index(current_view_index)  # ← 同步状态
	# 启动平滑旋转动画
	var target_rotation = fixed_rotations[current_view_index]
	var tween = create_tween()
	tween.tween_property(self, "rotation_degrees", target_rotation, 1.0 / turn_speed)
	tween.connect("finished", Callable(self, "_on_turn_finished"))
# 翻身完成后解锁输入

func _on_turn_finished():
	is_turning = false
# -------------------------
# 盖被子或掀被子逻辑
# -------------------------
func toggle_blanket():
	is_covered = not is_covered
	blanket.visible = is_covered
	state.set_covered(is_covered)  # ← 同步状态
	
# -------------------------
# 探头开始（按住 Shift + 左/右）
# -------------------------
func start_peek():
	is_peeking = true
	var peek_angle = max_peek_angle if Input.is_action_pressed("move_right") else -max_peek_angle
	var tween = create_tween()
	tween.tween_property(camera, "rotation_degrees:x", peek_angle, 0.3)
# 探头停止（松开按键）
func stop_peek():
	is_peeking = false
	var tween = create_tween()
	tween.tween_property(camera, "rotation_degrees:x", 0, 0.3)


# -------------------------
# 闭眼/睁眼状态切换（影响入睡度增长）
# ------------------------
func toggle_eyes():
	if not can_toggle_eye:
		return

	can_toggle_eye = false
	
	if state.is_eye_closed:
		open_eyes()
	else:
		close_eyes()

func close_eyes():
	state.set_eye_closed(true)
	eye_overlay.visible = true

	var tween = create_tween()
	tween.tween_property(eye_overlay, "modulate:a", 1.0, 0.3)
	tween.connect("finished", Callable(self, "_on_eye_closed"))

func _on_eye_closed():
	can_toggle_eye = true
	
func open_eyes():
	state.set_eye_closed(false)

	var tween = create_tween()
	tween.tween_property(eye_overlay, "modulate:a", 0.0, 0.3)
	tween.connect("finished", Callable(self, "_on_eye_opened"))

func _on_eye_opened():
	eye_overlay.visible = false
	can_toggle_eye = true

func _input(event):
	if event is InputEventMouseMotion and not is_turning and not is_peeking:
		target_yaw -= event.relative.x * mouse_sensitivity
		target_pitch -= event.relative.y * mouse_sensitivity

		# 限制角度在你设定的范围内
		target_yaw = clamp(target_yaw, -max_yaw, max_yaw)
		target_pitch = clamp(target_pitch, max_pitch_down, max_pitch_up)
		
func update_free_look():
	head_pivot.rotation_degrees.y = target_yaw
	camera_pivot.rotation_degrees.x = target_pitch
