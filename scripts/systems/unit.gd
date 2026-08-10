class_name BattleUnit
extends RefCounted

# 戦闘中ユニット 1 体分のデータと振る舞い。
# RefCounted 派生（Node を継承しない）。表示は UnitView が行う。
# hp は外部から直接書き換えない。必ず take_damage() / heal() 経由。

# team の値。文字列リテラル直書きを避けるため const 経由で参照する。
const TEAM_PARTY: String = "party"
const TEAM_ENEMY: String = "enemy"

var unit_id: String = ""
var team: String = ""
var unit_name_key: String = ""

var max_hp: int = 0
var hp: int = 0
var atk: int = 0
var def: int = 0
var atk_multiplier: float = 1.0

var attack_range: float = 0.0
var attack_interval_sec: float = 0.0
var speed: float = 0.0
var attack_timer: float = 0.0

var x: float = 0.0
# 未設定は ""。null を入れない（型が揺れる）。
var target_unit_id: String = ""

var is_boss: bool = false


func _init(
		p_unit_id: String,
		p_team: String,
		p_unit_name_key: String,
		p_max_hp: int,
		p_atk: int,
		p_def: int,
		p_attack_range: float,
		p_attack_interval_sec: float,
		p_speed: float,
		p_is_boss: bool = false
) -> void:
	unit_id = p_unit_id
	team = p_team
	unit_name_key = p_unit_name_key
	max_hp = p_max_hp
	hp = p_max_hp
	atk = p_atk
	def = p_def
	attack_range = p_attack_range
	attack_interval_sec = p_attack_interval_sec
	speed = p_speed
	is_boss = p_is_boss
	atk_multiplier = 1.0
	attack_timer = 0.0
	target_unit_id = ""


# hp を減らす。0 未満にしない。
func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	hp = max(0, hp - amount)


# hp を増やす。max_hp を超えない。
func heal(amount: int) -> void:
	if amount <= 0:
		return
	hp = min(max_hp, hp + amount)


func is_alive() -> bool:
	return hp > 0
