class_name BattleSession
extends RefCounted

# 戦闘セッション全体の進行データ。
# RefCounted 派生（_process は持たない、ループは BattleController が回す）。
# データと状態の判定だけを担当する（EXEC §4）。
# PRE_PLAN §7-1 反映: _init は (stage_id, stage_type, party_id, total_waves) の 4 引数。
# party_units と enemy_units は _init では空配列のまま、生成後に外部でセットする。

# 状態定数。文字列リテラル直書きを避けるため const 経由で参照する。
const STATE_WAVE_INTRO: String = "wave_intro"
const STATE_BATTLE_ACTIVE: String = "battle_active"
const STATE_WAVE_CLEAR: String = "wave_clear"
const STATE_VICTORY: String = "victory"
const STATE_DEFEAT: String = "defeat"

var stage_id: String = ""
var stage_type: String = ""
var party_id: String = ""
var state: String = STATE_WAVE_INTRO
var current_wave: int = 1   # 1 始まり
var total_waves: int = 0   # stages.json の waves 要素数から取る。5 をハードコードしない。

var party_units: Array = []   # BattleUnit の配列。ウェーブ間で作り直さない（HP 引き継ぎ）
var enemy_units: Array = []   # BattleUnit の配列。ウェーブごとに作り直す

# {BATTLE_VICTORY, BATTLE_WAVES_CLEARED, BATTLE_REWARDS} を確定時にセット
var result: Dictionary = {}


func _init(p_stage_id: String, p_stage_type: String, p_party_id: String, p_total_waves: int) -> void:
	stage_id = p_stage_id
	stage_type = p_stage_type
	party_id = p_party_id
	total_waves = p_total_waves
	state = STATE_WAVE_INTRO
	current_wave = 1
	party_units = []
	enemy_units = []
	result = {}


# enemy_units に生存者がいない
func is_wave_cleared() -> bool:
	for u in enemy_units:
		if u is BattleUnit and u.is_alive():
			return false
	return true


# party_units に生存者がいない
func is_party_wiped() -> bool:
	for u in party_units:
		if u is BattleUnit and u.is_alive():
			return false
	return true


func is_final_wave() -> bool:
	return current_wave >= total_waves


# 指定チームの生存ユニットを返す
func get_alive_units(team: String) -> Array:
	var list: Array = []
	var source: Array = party_units if team == BattleUnit.TEAM_PARTY else enemy_units
	for u in source:
		if u is BattleUnit and u.is_alive():
			list.append(u)
	return list
