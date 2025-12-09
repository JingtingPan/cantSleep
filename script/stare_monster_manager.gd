extends Node3D

# StareMonsterManager.gd

@onready var monsters = {
	0: $stareMonster_mid,
	1: $stareMonster_right,
	2: $stareMonster_left
}
var already_triggered: bool = false
var cooldown_timer: float = 0.0
# 闭眼预生成记录
var pending_view_index: int = -1
var waiting_to_generate: bool = false

@export var appear_time: float = 7.0
@export var cooldown: float = 10.0
@export var eye_closed_time_check: float = 5.0 #当玩家闭眼时固定在一个视角的时间后生成怪物
@export var eye_open_time_check: float = 5.0 #当玩家睁眼时固定在一个视角的时间后生成怪物

func _process(delta):
	check_if_spawned(delta)
	check_monster_generate()

# -----------------------------
# 检测怪物是否已经生成，如果已经生成进入冷却时间
# -----------------------------
func check_if_spawned(delta):
	if already_triggered:
		cooldown_timer -= delta
		if cooldown_timer <= 0.0:
			already_triggered = false
			print("[StareMonsterManager] 怪物冷却结束，允许再次触发")

# -----------------------------
# 检测玩家视角是否在一个位置固定超过一定时间，是睁眼还是闭眼
# -----------------------------		
func check_monster_generate():
	if already_triggered:
		return
	
	var view_time = PlayerStateController.view_hold_time
	var view_index = PlayerStateController.current_view_index
	var is_eye_closed = PlayerStateController.is_eye_closed

	#  闭眼：不立刻生成怪物，但进入待生成状态
	if is_eye_closed:
		if view_time >= eye_closed_time_check and not waiting_to_generate:
			pending_view_index = view_index
			waiting_to_generate = true
			print("[StareMonsterManager] 闭眼期间视角 %d 达标，等待睁眼触发怪物生成" % view_index)
		return
	
	#  玩家睁眼
	if not is_eye_closed:
		# 玩家视角与等待生成视角一致 → 执行怪物生成
		if waiting_to_generate and view_index == pending_view_index:
			monster_generate(pending_view_index)
			waiting_to_generate = false
			pending_view_index = -1
			return

		# 玩家一直睁眼停留超过设定时间 → 直接生成
		if view_time >= eye_open_time_check:
			monster_generate(view_index)
			

# -----------------------------
# 在玩家当前视角生成怪物
# -----------------------------
func monster_generate(index: int):
	if monsters.has(index):
		monsters[index].appear(index)
		already_triggered = true
		cooldown_timer = cooldown
		print("[StareMonsterManager] 在视角 %d 生成盯视怪" % index)
