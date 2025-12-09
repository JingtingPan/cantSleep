# StareMonster.gd
# 玩家长时间盯着一个方向后生成的怪物，必须切换视角才能驱散，否则攻击玩家

extends Node3D

#@export var appear_time: float = 7.0         # 玩家盯着同一方向多久后怪物出现
@export var attack_time: float = 5.0       # 玩家仍未转视角则攻击时间
@export var attack_distance: float = 2.0     # 攻击距离（用于更强沉浸）
@export var stare_sanity_drain: float = 3.0 # 每秒盯着时理智值下降速度
@export var despawn_delay: float = 5.0     # 玩家转头后多少秒怪物才消失
@export var warning_threshold: float = 3.5 # 距离攻击还有几秒时开始警告
@export var attack_reduce_sanity: float = 15.0 # 每次怪物攻击时扣掉的玩家的理智值
@export var attack_reduce_sleepiness: float = 20.0 # 每次怪物攻击时扣掉的玩家的入睡度

@onready var player = get_tree().get_first_node_in_group("player")
@onready var state = PlayerStateController
@onready var appear_sound: AudioStreamPlayer3D = $Appear
@onready var disappear_sound: AudioStreamPlayer3D = $Disappear
@onready var warning_ui = get_node_or_null("/root/main/CanvasLayer/WarningFlash")
var active_view_index: int = -1              # 怪物当前出现的视角索引
var has_spawned: bool = false
var attack_timer: float = 0.0
var despawn_timer: float = 0.0
var waiting_to_despawn: bool = false
var is_warning_shown: bool = false
#var cooldown_timer: float = 0.0

func _ready():
	hide()
	if warning_ui:
		warning_ui.stop_flash()
func _process(delta):
	# 如果尚未生成，检查玩家是否持续盯着一个方向
	if not has_spawned:
		return

	# 玩家转头，怪物立即消失
	if state.current_view_index != active_view_index:
		if not waiting_to_despawn:
			waiting_to_despawn = true
			despawn_timer = despawn_delay
			print("[StareMonster] 玩家转视角，开始倒计时消失")
		else:
			despawn_timer -= delta
			if despawn_timer <= 0.0:
				despawn()
				return
	else:
		if waiting_to_despawn:
			waiting_to_despawn = false
			print("[StareMonster] 玩家重新看向怪物，取消消失")
			
	# 玩家继续盯着 → 降理智
	PlayerStateController.sanity -= stare_sanity_drain * delta
	PlayerStateController.sanity = max(PlayerStateController.sanity, 0)

	# 到达攻击时间
	attack_timer += delta
	if attack_timer >= attack_time:
		trigger_attack()
	
	# 警告 UI 控制
	if warning_ui:
		if not is_warning_shown and attack_time - attack_timer <= warning_threshold:
			warning_ui.start_flash()
			is_warning_shown = true
		elif is_warning_shown and attack_time - attack_timer > warning_threshold:
			warning_ui.stop_flash()
			is_warning_shown = false

func appear(view_index: int):
	has_spawned = true
	active_view_index = view_index
	attack_timer = 0.0
	waiting_to_despawn = false
	is_warning_shown = false
	if warning_ui:
		warning_ui.stop_flash()
	# 设置怪物在当前视角前方一定距离生成
	#var spawn_pos = player.global_transform.origin + get_direction_from_view(view_index) * 1.25
	#global_transform.origin = spawn_pos
	#look_at(player.global_transform.origin, Vector3.UP)
	show()
	appear_sound.play()
	print("[StareMonster] 玩家长时间盯着方向 %d，怪物出现" % view_index)

func despawn():
	has_spawned = false
	active_view_index = -1
	waiting_to_despawn = false
	is_warning_shown = false
	hide()
	disappear_sound.play()
	if warning_ui:
		warning_ui.stop_flash()
	print("[StareMonster] 消失")

	

func trigger_attack():
	print("[StareMonster] 玩家未转视角，被攻击！")
	PlayerStateController.sanity -= attack_reduce_sanity
	PlayerStateController.sleepiness -= attack_reduce_sleepiness
		# 限制范围
	PlayerStateController.sanity = max(PlayerStateController.sanity, 0)
	PlayerStateController.sleepiness = max(PlayerStateController.sleepiness, 0)
	
		# 触发幻觉或直接失败可另设条件
	if PlayerStateController.sanity <= PlayerStateController.sanity_floor:
		print(">> 玩家精神崩溃，进入幻觉阶段")
	# 可跳转GameOver场景或发送信号终止游戏
	#get_tree().change_scene_to_file("res://GameOver.tscn")
	despawn()
	
func get_direction_from_view(view_index: int) -> Vector3:
	match view_index:
		0: return Vector3(0, 0, -1)  # 前方
		1: return Vector3(-1, 0, 0)  # 右方
		2: return Vector3(1, 0, 0)   # 左方
		_: return Vector3(0, 0, -1)
