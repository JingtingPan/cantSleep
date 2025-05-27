extends Node3D
@export var footstep_delay: float = 0.4  # 怪物音频每步间隔时间
@export var approach_speed: float = 0.1 # 怪物移动速度
@export var attack_distance: float = 1.5 # 怪物与玩家距离小于此数值时尝试攻击
@export var check_interval: float = 1.0 # （预留）检查间隔，可用于未来逻辑优化
@export var stop_delay: float = 1.5  # 玩家看到怪物后仍移动几秒
@export var not_looking_time: float = 4.0  # 玩家没有正对怪物几秒后开始行动
@onready var player = get_tree().get_first_node_in_group("player")
@onready var animator = $AnimationPlayer
@onready var walk_sound1: AudioStreamPlayer3D = $walk1
@onready var walk_sound2: AudioStreamPlayer3D = $walk2
var is_attacking: bool = false # 是否正在进行攻击流程
var last_check_time: float = 0.0 # （预留）用于记录上一次检查时间
var state = PlayerStateController
# 怪物行动相关时间记录
var time_facing: float = 0.0     # 玩家盯着怪物的持续时间
var time_not_facing: float = 0.0 # 玩家背对怪物的持续时间
var is_stunned: bool = false     # 怪物是否处于停止状态
var stun_timer: float = 0.0      # 怪物停止行动剩余时间（秒）
var has_attacked: bool = false   # 怪物是否已经攻击成功
var is_moving: bool = false
var stop_timer: float = 0.0         # 剩余延迟时间
var playing_walk1 := true
var walk_timer := 0.0# 怪物音频每步间隔时间

func _ready():
	#hide() # 初始隐藏怪物（由外部触发出现）
	walk_sound1.connect("finished", Callable(self, "_on_audio_finished"))
	walk_sound2.connect("finished", Callable(self, "_on_audio_finished"))

# ---------------------------
# 启动怪物的逼近行为
# ---------------------------
func start_approach():
	show() # 显示怪物模型
	is_attacking = true

# ---------------------------
# 每帧更新逻辑
# ---------------------------
func _process(delta):
	if not player or has_attacked:
		return
	
	if is_stunned:
		stun_timer -= delta
		if stun_timer <= 0:
			is_stunned = false
			print("[怪物] 从停滞中恢复")
		return	
	# 如果玩家背对怪物，就开始靠近
# 是否背对太久，触发移动
	if not is_facing_player():
		time_not_facing += delta
		time_facing = 0.0

		if not is_moving and time_not_facing >= not_looking_time:
			is_moving = true
			animator.play("Walk")  # 播放行走动画
			#play_sound("step")    # 示例：播放脚步声
			print("[怪物] 玩家背对超过 %.1f 秒，开始靠近" % not_looking_time)

		stop_timer = 0.0  # 重置停止延迟
	else:
		time_facing += delta
		time_not_facing = 0.0

		if is_moving:
			if stop_timer <= 0.0:
				stop_timer = stop_delay  # 玩家看到怪物时启动延迟停止

			stop_timer -= delta
			if stop_timer <= 0.0:
				is_moving = false
				animator.play("Idle")  # 回到静止动画
				stop_walk_sound()
				print("[怪物] 被玩家注视后延迟 %.1f 秒停止行动" % stop_delay)

		# 检查是否盯视达到 3 秒，触发stun
		if time_facing >= 3.0 and not is_stunned:
			stun_for_seconds(10.0)
			animator.play("Stun")     # 播放僵直动画
			#play_sound("stun") 
			time_facing = 0.0
			is_moving = false
			print("[怪物] 玩家盯视怪物，怪物停止行动 10 秒")

	# 如果正在移动，就靠近玩家
	if is_moving:
		var direction = (player.global_transform.origin - global_transform.origin).normalized()
		global_translate(direction * approach_speed * delta)
		# 已接近到攻击距离，尝试攻击
		play_walk_sound(delta)
	if global_transform.origin.distance_to(player.global_transform.origin) <= attack_distance:
		attempt_attack()

# ---------------------------
# 攻击判定逻辑
# ---------------------------
func attempt_attack():
	print(">>> attempt_attack() called")
	if player.is_covered:
		print("[怪物] 玩家盖了被子，撤退")
		retreat()
	else:
		if is_facing_player():
			print("[怪物] 玩家正面对我，攻击失败 → 撤退")
			retreat()
		else:
			print("[怪物] 玩家背对我且没盖被子 → 攻击成功")
			trigger_attack()

func play_walk_sound(delta):
	# 播放交替脚步声
		walk_timer -= delta
		if walk_timer <= 0.0:
			if playing_walk1:
				walk_sound1.pitch_scale = randf_range(0.95, 1.05)
				walk_sound1.play()
			else:
				walk_sound2.pitch_scale = randf_range(0.95, 1.05)
				walk_sound2.play()
			playing_walk1 = !playing_walk1
			walk_timer = footstep_delay
			
func stop_walk_sound():
	walk_sound1.stop()
	walk_sound2.stop()
# ---------------------------
# 判断玩家是否正对着怪物
# ---------------------------
func is_facing_player() -> bool:
	if not player:
		return false

	var player_pos = player.global_transform.origin
	var to_monster = (global_transform.origin - player_pos).normalized()
	var player_forward = player.ideal_view_vectors[player.current_view_index]
	
	var dot = player_forward.dot(to_monster)
	var threshold = 0.7  # 夹角小于约 45° 时认为是正面

	#print("[角度判断] dot = %.2f (1 是完全正面, -1 是背后)" % dot)
	#if dot > threshold:
	#	print("player facing monster")
	return dot > threshold
	
# ---------------------------
# 使怪物停止行动一段时间
# ---------------------------
func stun_for_seconds(seconds: float):
	is_stunned = true
	stun_timer = seconds

# ---------------------------
# 怪物撤退逻辑（玩家防御成功）
# ---------------------------
func retreat():
	# 成功防御，怪物撤退
	animator.play("Die")      # 播放死亡/消失动画
	#play_sound("retreat")    # 播放落地或喘息声
	is_attacking = false
	# 可在动画结束后调用 hide()
	await animator.animation_finished
	hide()
	global_transform.origin = Vector3(5, 0, 5) # 重置位置或播放消失动画


# ---------------------------
# 怪物攻击逻辑（玩家失败）
# ---------------------------
func trigger_attack():
	# 玩家失败，可以跳转到Game Over
	has_attacked = true
	PlayerStateController.sanity -= 20.0
	PlayerStateController.sleepiness -= 15.0
		# 限制范围
	PlayerStateController.sanity = max(PlayerStateController.sanity, 0)
	PlayerStateController.sleepiness = max(PlayerStateController.sleepiness, 0)
	
		# 触发幻觉或直接失败可另设条件
	if PlayerStateController.sanity <= PlayerStateController.sanity_floor:
		print(">> 玩家精神崩溃，进入幻觉阶段")
	# 可跳转GameOver场景或发送信号终止游戏
	#get_tree().change_scene_to_file("res://GameOver.tscn")
	animator.play("Eat")       # 攻击动画
	#play_sound("scream")      # 播放吃人尖叫声
	print("Monster caught you!")
	#get_tree().change_scene_to_file(\"res://GameOver.tscn\") # 示例
