extends Node3D

# StareMonsterManager.gd

@onready var monsters = {
	0: $stareMonster_mid,
	1: $stareMonster_right,
	2: $stareMonster_left
}
var already_triggered: bool = false
var cooldown_timer: float = 0.0
@export var appear_time: float = 7.0
@export var cooldown: float = 10.0

func _process(delta):
	if already_triggered:
		cooldown_timer -= delta
		if cooldown_timer <= 0.0:
			already_triggered = false
			print("[StareMonsterManager] 怪物冷却结束，允许再次触发")
		return
	if PlayerStateController.view_hold_time > 7.0:
		var index = PlayerStateController.current_view_index
		if monsters.has(index):
			monsters[index].appear(index)
			already_triggered = true
			cooldown_timer = cooldown
			print("[StareMonsterManager] 在视角 %d 生成盯视怪" % index)
