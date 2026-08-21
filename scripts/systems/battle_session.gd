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
# ⚠ BattleLog の見出しにしか使わない。メンバーは決めない（EXEC_PARTY_MEMBERS.md §2）。
#   編成は GameManager.get_party_members() が唯一の正。stages.json の party_id を
#   書き換えても戦闘の顔ぶれは変わらない。
var party_id: String = ""
var state: String = STATE_WAVE_INTRO
var current_wave: int = 1   # 1 始まり
var total_waves: int = 0   # stages.json の waves 要素数から取る。5 をハードコードしない。

var party_units: Array = []   # BattleUnit の配列。ウェーブ間で作り直さない（HP 引き継ぎ）
var enemy_units: Array = []   # BattleUnit の配列。ウェーブごとに作り直す

# 召喚ユニット（段階6・PLAN 14-2）。味方の召喚も敵の召喚もここに入る（team で分ける）。
#
# ⚠ 専用の配列にするのは人間の決定（2026-08-21）。おかげで is_party_wiped() /
#   is_wave_cleared() を1行も触らずに「召喚は頭数に入らない」が成り立つ
#   （PLAN 14-2「勝敗判定は本体だけ見ればよい」）。
# ⚠ 代償：走査に召喚を通すのは呼び出し側の仕事になる。battle_controller は
#   _all_units() 1本に閉じてある。8箇所に散らさないこと。
# ⚠ get_alive_units() には入る（狙われるし狙う）。PLAN 14-5 の2欄
#   （敵に狙われるか／味方の支援対象になるか）はまだ無く、今はどちらも「入る」。
var summon_units: Array = []

# 戦闘開始からの経過秒（scale_from / condition の elapsed_sec・PLAN 5-5-2）。
# ⚠ 積むのは battle_controller._process() の1箇所だけ。2本目の時計を作らない。
# ⚠ 状態1件ごとの elapsed（StatusRegistry の entry）とは別物。混同しないこと。
# ⚠ ウェーブ交代では戻さない。「戦闘開始から」であって「ウェーブ開始から」ではない。
var elapsed_sec: float = 0.0

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
	summon_units = []
	elapsed_sec = 0.0
	result = {}


# enemy_units に生存者がいない
#
# ⚠ summon_units を見ないこと（人間の決定・2026-08-21）。敵の召喚が残っていても
#   ウェーブはクリアする。PLAN 14-2「勝敗判定は本体だけ見ればよい」。
func is_wave_cleared() -> bool:
	for u in enemy_units:
		if u is BattleUnit and u.is_alive():
			return false
	return true


# party_units に生存者がいない
#
# ⚠ summon_units を見ないこと。味方の召喚だけが生き残っていても敗北する
#   （is_wave_cleared() と同じ理由）。
func is_party_wiped() -> bool:
	for u in party_units:
		if u is BattleUnit and u.is_alive():
			return false
	return true


# IDでユニットを引く。居なければ null。
#
# 【なぜここに置くか】同じ形の `_find_unit()` が SkillRuntime / SkillResolver /
# StatusRegistry / BattleController に4本あり、段階6で summon_units を足したときに
# 3本が「召喚を見つけられない」まま残った（撃った記録だけ出てダメージが1件も
# 出ない・エラーは1つも出ない）。配列を持っているのはこのクラスなので、
# 探すのもここ1本にする。
# ⚠ 新しい配列を足したら、直すのはこの関数だけにすること。
# ⚠ 生死で絞らない。死者を引く用途がある（死亡の介入点・状態の宿主）。
func find_unit(unit_id: String) -> BattleUnit:
	if unit_id == "":
		return null
	for u in party_units:
		if u is BattleUnit and (u as BattleUnit).unit_id == unit_id:
			return u
	for u in enemy_units:
		if u is BattleUnit and (u as BattleUnit).unit_id == unit_id:
			return u
	for u in summon_units:
		if u is BattleUnit and (u as BattleUnit).unit_id == unit_id:
			return u
	return null


func is_final_wave() -> bool:
	return current_wave >= total_waves


# 指定チームの生存ユニットを返す
#
# ⚠ 召喚も入る（段階6）。入れないと、召喚は誰からも狙われず誰も狙えない置物になる。
#   選抜（SkillResolver.select_targets）も対象取得（_acquire_target_if_needed）も
#   この1本を通るので、ここに足せば両方に行き渡る。
# ⚠ 末尾に足すこと。並びが変わると sort が同点のときの選ばれ方が変わり、
#   同じ入力で違うログが出る（再現性が落ちる）。
# ⚠ PLAN 14-5 の2欄（敵に狙われるか／味方の支援対象になるか）はまだ無い。
#   今はどちらも「入る」で固定（ゾンビ型＝支援を吸わない召喚は書けない）。
func get_alive_units(team: String) -> Array:
	var list: Array = []
	var source: Array = party_units if team == BattleUnit.TEAM_PARTY else enemy_units
	for u in source:
		if u is BattleUnit and u.is_alive():
			list.append(u)
	for u in summon_units:
		if u is BattleUnit and u.is_alive() and (u as BattleUnit).team == team:
			list.append(u)
	return list
