class_name BattleUnit
extends RefCounted

# 戦闘中ユニット 1 体分のデータと振る舞い。
# RefCounted 派生（Node を継承しない）。表示は UnitView が行う。
# hp は外部から直接書き換えない。必ず take_damage() / heal() 経由。
#
# 【10軸化で作り直した（EXEC_STATS_10_AXES_FORMULA.md）】
# 以前は hp / atk / def を個別のフィールドで持ち、_init() が10個の位置引数を
# 取っていた。軸が10本になると16個になり、呼び出し側で順番を間違えても
# 型が同じなら通ってしまう。そこで：
#
#   ・能力値は _stats: Dictionary 1本にまとめ、get_stat() 経由で読む
#   ・生成は static create() だけを入口にする（_init() は引数を取らない）
#
# 軸を増やすときにこのファイルを直す必要はない。
# GameManager.get_stat_keys() に足せば create() が拾う。

# team の値。文字列リテラル直書きを避けるため const 経由で参照する。
const TEAM_PARTY: String = "party"
const TEAM_ENEMY: String = "enemy"

# 攻撃の種別。characters.json / enemies.json / skills.json の "attack_type" に入る値。
#
# 種別と参照ステータスは連動する（物理は atk と def、魔法は mag と mdef）。
# 「魔力参照だが物理ダメージ」のような組み合わせを作れないよう、欄は1つにしてある。
# BattleFormula 側ではなくここに置くのは、BattleFormula が BattleUnit に
# 依存してはいけないため（battle_formula.gd の冒頭コメント）。
const ATTACK_TYPE_PHYSICAL: String = "physical"
const ATTACK_TYPE_MAGIC: String = "magic"

# --- 識別（生成後に変わらない） ---
var unit_id: String = ""
var team: String = ""
var unit_name_key: String = ""
var is_boss: bool = false

# --- 能力値（10軸） ---
# GameStateKeys.STAT_* をキーに int を持つ。
# 直接読まないこと。Dictionary は存在しないキーを読んでも null を返すだけで
# エラーにならないため、必ず get_stat() を通す（AGENTS.md「キー名を推測して書かない」）。
var _stats: Dictionary = {}

# --- 生成時に一度だけ計算する派生値 ---
# 戦闘中に能力値が変わる仕組みは今は無い。
# バフを入れるときは、ここを計算し直す関数を足すこと。
var max_hp: int = 0
var attack_range: float = 0.0
# atkspd を適用し、下限でクランプ済みの実効値。マスターの base ではない。
var attack_interval_sec: float = 0.0
var speed: float = 0.0
# 通常攻撃の種別（ATTACK_TYPE_*）
var attack_type: String = ATTACK_TYPE_PHYSICAL

# --- 戦闘中に変わる状態 ---
var hp: int = 0
var atk_multiplier: float = 1.0
var attack_timer: float = 0.0
var x: float = 0.0
# 未設定は ""。null を入れない（型が揺れる）。
var target_unit_id: String = ""
# 所持スキルID（順序を保つため配列で持つ。ボタンの並び順になる）
var skill_ids: Array = []
# skill_id -> cooldown_remaining(float)
var skill_cooldowns: Dictionary = {}


# 生成の唯一の入口。BattleUnit.new() を直接呼ばないこと。
#
# p_source … characters.json / enemies.json のエントリ。
#            name_key / attack_range / attack_interval_sec / attack_type を読む。
# p_stats  … 10軸の辞書。
#            味方は GameManager.get_effective_stats()（研究と装備が乗った最終値）、
#            敵はマスターのエントリそのもの（敵は p_source と同じ辞書を渡す）。
#
# 味方で p_source と p_stats が別物なのは、能力値だけが育成で変わり、
# attack_range と attack_interval_sec の base はマスターにしか無いため。
static func create(
		p_unit_id: String,
		p_team: String,
		p_source: Dictionary,
		p_stats: Dictionary,
		p_is_boss: bool = false
) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = p_unit_id
	unit.team = p_team
	unit.is_boss = p_is_boss
	unit.unit_name_key = str(p_source.get("name_key", ""))
	unit.attack_range = float(p_source.get("attack_range", 0))

	# 軸の一覧は GameManager が持つものを唯一の正とする。
	# ここに軸名を並べた2本目の配列を作らないこと（前半で equipment_screen.gd の
	# _stat_labels() が2本目の配列になっていて事故の元だった）。
	for stat_key in GameManager.get_stat_keys():
		if not p_stats.has(stat_key):
			push_warning("[BattleUnit] stats に %s が無い (unit_id=%s)" % [stat_key, p_unit_id])
		# MasterDataLoader は JSON の数値を float で返す。int() で包む。
		unit._stats[stat_key] = int(p_stats.get(stat_key, 0))

	unit.max_hp = unit.get_stat(GameStateKeys.STAT_HP)
	unit.hp = unit.max_hp
	unit.speed = float(unit.get_stat(GameStateKeys.STAT_SPD))
	unit.attack_interval_sec = BattleFormula.attack_interval(
		float(p_source.get("attack_interval_sec", 0)),
		unit.get_stat(GameStateKeys.STAT_ATKSPD)
	)

	var raw_type: String = str(p_source.get("attack_type", ATTACK_TYPE_PHYSICAL))
	if raw_type != ATTACK_TYPE_PHYSICAL and raw_type != ATTACK_TYPE_MAGIC:
		push_error("[BattleUnit] 不明な attack_type: %s (unit_id=%s)" % [raw_type, p_unit_id])
		raw_type = ATTACK_TYPE_PHYSICAL
	unit.attack_type = raw_type

	return unit


# 能力値を引く。未定義のキーは push_error して 0 を返す。
# 静かに null や 0 が返ると、式が黙って壊れて実機で気づけないため。
func get_stat(stat_key: String) -> int:
	if not _stats.has(stat_key):
		push_error("[BattleUnit] 未定義のステータス軸: %s (unit_id=%s)" % [stat_key, unit_id])
		return 0
	return int(_stats[stat_key])


# 攻撃側が使う軸。物理なら atk、魔法なら mag。
func get_power(p_attack_type: String) -> int:
	if p_attack_type == ATTACK_TYPE_MAGIC:
		return get_stat(GameStateKeys.STAT_MAG)
	return get_stat(GameStateKeys.STAT_ATK)


# 防御側が使う軸。物理なら def、魔法なら mdef。
func get_defense(p_attack_type: String) -> int:
	if p_attack_type == ATTACK_TYPE_MAGIC:
		return get_stat(GameStateKeys.STAT_MDEF)
	return get_stat(GameStateKeys.STAT_DEF)


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

# ========================================================================
# スキル関連
# ========================================================================

# 全スキルの残り時間を delta だけ減らす。0.0 を下限とする。
func tick_cooldowns(delta: float) -> void:
	for skill_id in skill_cooldowns:
		skill_cooldowns[skill_id] = max(0.0, float(skill_cooldowns[skill_id]) - delta)


# skill_id が skill_ids に無い場合は false を返す（含まれていないスキルを発動可能と誤判定しない）。
func is_skill_ready(skill_id: String) -> bool:
	if not (skill_id in skill_ids):
		return false
	return float(skill_cooldowns.get(skill_id, 0.0)) <= 0.0


# クールダウン残り時間をセットする。skill_ids 外の ID は何もしない。
# 渡す秒数は haste 適用済みの実効値（BattleFormula.cooldown() を通したもの）。
func start_cooldown(skill_id: String, sec: float) -> void:
	if not (skill_id in skill_ids):
		return
	skill_cooldowns[skill_id] = sec


# クールダウン残り時間を返す。未登録の ID は 0.0。
func get_cooldown(skill_id: String) -> float:
	return float(skill_cooldowns.get(skill_id, 0.0))
