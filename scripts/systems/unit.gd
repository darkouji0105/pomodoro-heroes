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

# --- 状態による能力値の補正（段階3・StatusRegistry が書く） ---
# GameStateKeys.STAT_* をキーに int を持つ。get_stat() が素の値に足す。
#
# ⚠ ここを += / -= で更新しないこと。StatusRegistry が自分の持つ状態から
#   毎回ゼロから組み直したものを、set_stat_mods() で丸ごと受け取る。
#   差分更新にすると、剥がし忘れが「少し強いまま」として残り、エラーも出ず、
#   F3 パネルの数字ももっともらしいので気づけない。
# ⚠ 書いてよいのは StatusRegistry だけ。他所から set_stat_mods() を呼ばないこと。
var _stat_mods: Dictionary = {}

# --- 派生値 ---
# 生成時に一度だけ計算し、状態で能力値が変わったら refresh_derived() で計算し直す。
var max_hp: int = 0
var attack_range: float = 0.0
# atkspd を適用し、下限でクランプ済みの実効値。マスターの base ではない。
var attack_interval_sec: float = 0.0
var speed: float = 0.0
# マスターの attack_interval_sec（atkspd 適用前）。refresh_derived() が使う。
#
# ⚠ これを持たずに attack_interval_sec だけ持つと、atkspd のバフが付くたびに
#   実効値をさらに割ることになり、剥がしても戻らず累積で速くなる。
var _base_attack_interval_sec: float = 0.0
# 通常攻撃の種別（ATTACK_TYPE_*）
var attack_type: String = ATTACK_TYPE_PHYSICAL

# 通常攻撃の中身（characters.json / enemies.json の "basic_attack"）。
# 形は skills の1件と同じ { "effects": [ ... ] }。⚠ target は持たない
# （通常攻撃は歩いて近づいた相手を撃つ。対象を選び直さない）。
#
# ⚠ ここに持つのは「マスターの複製」だが、セーブには入らない。attack_range /
#   _base_attack_interval_sec と同じ扱いで、create() が p_source から1回だけ写す。
#   スキルのように毎回IDで引き直さないのは、BattleUnit が自分の character_id /
#   enemy_type_id を持っていないため（持たせると create() の引数が増える）。
var basic_attack: Dictionary = {}

# --- 戦闘中に変わる状態 ---
var hp: int = 0
# 死亡の介入点（復活）を通したか（PLAN 11-1・段階3の後半③）。
#
# ⚠ 書いてよいのは BattleController._step_deaths() だけ。他所から触らないこと。
# ⚠ 復活したら false に戻す。戻さないと2回目の死亡で介入点を通らない。
#   戻すのは走査の側（生きているなら false）。ここに戻す処理を書かない。
# ⚠ StatusRegistry._drop_dead_hosts() がこれを読む。真になるまで宿主の状態を
#   捨てない。捨てられると、通常攻撃で死んだ相手の復活が走査に着く前に消える
#   （EXEC_SKILL_INTERVENTION.md §1-1）。
# ⚠ セーブに入らない。ウェーブ交代・リトライは BattleUnit を作り直すので既定値でよい。
var death_handled: bool = false
var atk_multiplier: float = 1.0
var attack_timer: float = 0.0
var x: float = 0.0
# 未設定は ""。null を入れない（型が揺れる）。
var target_unit_id: String = ""
# 所持スキルID（順序を保つため配列で持つ。ボタンの並び順になる）
var skill_ids: Array = []
# 所持パッシブID（activation: "passive"・PLAN 7-2）。
#
# ⚠ skill_ids と別に持つ（人間の決定・2026-08-17）。混ぜて後段で弾く形に
#   しないこと。別枠にしてあるおかげで、
#     ・_try_enemy_skill() は skill_ids しか回さない → 敵が撃たない
#     ・スキルボタンも skill_ids しか見ない → ボタンに並ばない
#   の2つが「何もしなくても」成り立つ（EXEC_SKILL_PASSIVE_VARS.md §0-1-1）。
# ⚠ 引き金を引くのは battle_controller._step_passives() だけ。その先は
#   味方のボタン・敵の攻撃拍とまったく同じ _fire_skill() を通る。
var passive_ids: Array = []
# skill_id -> cooldown_remaining(float)
var skill_cooldowns: Dictionary = {}

# 構え（activation: recast の段の途中・段階5・PLAN 8章）。
#   skill_id -> {"phase": int（次に撃つ段）, "remaining": float（残りの窓）}
#
# ⚠ ここに置くのは SkillActivation.blocked_reason(user, ...) が user から
#   到達できる必要があるため。SkillRuntime の待ち行列は「効果」の待ちであって
#   「発動」の状態ではない。混ぜると「効果を取り消すと構えも消える」が無音で起きる。
# ⚠ 捨てる経路は4本ある（窓切れ・死亡・ウェーブ交代・リトライ）。5本目を作るときは
#   4本全部を見直すこと（状態を消す経路を1本ずつ対応して踏んだのと同じ形）。
# ⚠ セーブされない。戦闘のあいだだけの状態。
var recast_pending: Dictionary = {}


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

	unit._base_attack_interval_sec = float(p_source.get("attack_interval_sec", 0))
	# 派生値の式をここに書かない。refresh_derived() が唯一の計算場所
	# （2箇所に書くと、状態で計算し直したときだけ式が違う形になる）。
	unit.refresh_derived()
	unit.hp = unit.max_hp

	var raw_type: String = str(p_source.get("attack_type", ATTACK_TYPE_PHYSICAL))
	if raw_type != ATTACK_TYPE_PHYSICAL and raw_type != ATTACK_TYPE_MAGIC:
		push_error("[BattleUnit] 不明な attack_type: %s (unit_id=%s)" % [raw_type, p_unit_id])
		raw_type = ATTACK_TYPE_PHYSICAL
	unit.attack_type = raw_type

	# ⚠ 空でも落とさない。ロード時検証（MasterDataLoader）が赤で言うので、
	#   ここで二重に赤を出すと同じ事故で2本出る。撃たないだけにする。
	var raw_basic: Variant = p_source.get("basic_attack", null)
	if raw_basic is Dictionary:
		unit.basic_attack = (raw_basic as Dictionary).duplicate(true)

	return unit


# 能力値を引く。未定義のキーは push_error して 0 を返す。
# 静かに null や 0 が返ると、式が黙って壊れて実機で気づけないため。
#
# ⚠ 能力値を読む経路はここ1本。F3 パネルも SkillResolver の scale_from も
#   BattleFormula への引数も全部ここを通るので、状態の補正をここで足せば
#   呼び出し元を1つも触らずに全部へ行き渡る。
func get_stat(stat_key: String) -> int:
	if not _stats.has(stat_key):
		push_error("[BattleUnit] 未定義のステータス軸: %s (unit_id=%s)" % [stat_key, unit_id])
		return 0
	# ⚠ 0 で切る。負の防御は BattleFormula 側でも切られるが、負の atk が
	#   式に入ると表示まで意味が変わる。
	return maxi(0, int(_stats[stat_key]) + int(_stat_mods.get(stat_key, 0)))


# 素の能力値（状態の補正を含まない）。育成・装備・研究が乗った値。
# ⚠ 通常はこちらを使わない。get_stat() が正。
func get_base_stat(stat_key: String) -> int:
	if not _stats.has(stat_key):
		push_error("[BattleUnit] 未定義のステータス軸: %s (unit_id=%s)" % [stat_key, unit_id])
		return 0
	return int(_stats[stat_key])


# 状態による補正を丸ごと差し替える。⚠ StatusRegistry だけが呼ぶ。
func set_stat_mods(mods: Dictionary) -> void:
	_stat_mods = mods.duplicate()
	refresh_derived()


# 派生値を、今の実効ステータスから計算し直す。
#
# ⚠ max_hp をここで動かす道はまだ無い。hp 軸のバフは StatusRegistry が赤で弾く。
#   max_hp が動くと、現在HPのクランプと割合計算（sort: lowest_hp /
#   scale_from: hp_ratio）が同時に動く。それは別の回でやる。
#   ⚠ 禁止を外すなら、hp のクランプをこの関数に足すこと。忘れると
#     「最大HPが減ったのに現在HPがはみ出したまま」になる。
# ⚠ attack_range はマスター由来で能力値に依存しないので、ここには出てこない。
func refresh_derived() -> void:
	max_hp = get_stat(GameStateKeys.STAT_HP)
	speed = float(get_stat(GameStateKeys.STAT_SPD))
	attack_interval_sec = BattleFormula.attack_interval(
		_base_attack_interval_sec,
		get_stat(GameStateKeys.STAT_ATKSPD)
	)


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


# skill_id が skill_ids にも passive_ids にも無い場合は false を返す
# （含まれていないスキルを発動可能と誤判定しない）。
#
# ⚠ passive_ids を見るのを外さないこと。外すと _fire_skill() が
#   REASON_COOLDOWN を返し、クールダウンを持たないパッシブが「クールダウン中」
#   で弾かれる。理由が嘘になるうえエラーが1つも出ない
#   （EXEC_SKILL_PASSIVE_VARS.md §1-6）。
# ⚠ start_cooldown() は skill_ids のままにしてある（非対称）。パッシブに
#   クールダウンを持たせないため。この非対称を揃えないこと。
func is_skill_ready(skill_id: String) -> bool:
	if not (skill_id in skill_ids) and not (skill_id in passive_ids):
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


# ========================================================================
# 構え（activation: recast・段階5）
# ========================================================================

# 次に撃つ段の番号。構えていなければ -1。
#
# ⚠ 「構え中か」の判定はこの1本だけ。呼び出し側で recast_pending を直接見ないこと
#   （SkillActivation に集約している「撃てるかの判定」が2箇所に散る）。
func recast_phase(skill_id: String) -> int:
	var entry: Variant = recast_pending.get(skill_id, null)
	if not (entry is Dictionary):
		return -1
	return int((entry as Dictionary).get("phase", -1))


# 構えを立てる（＝次の段を window_sec のあいだ受け付ける）。
#
# ⚠ 状態を変えるので、撃てるかの判定を全部終えてから呼ぶこと
#   （CLAUDE.md「状態を変える前に全部の判定を終える」）。
func begin_recast(skill_id: String, next_phase: int, window_sec: float) -> void:
	recast_pending[skill_id] = {"phase": next_phase, "remaining": window_sec}


# 構えの残り秒数。構えていなければ 0.0。⚠ 表示にしか使わない。
func recast_remaining(skill_id: String) -> float:
	var entry: Variant = recast_pending.get(skill_id, null)
	if not (entry is Dictionary):
		return 0.0
	return float((entry as Dictionary).get("remaining", 0.0))


func clear_recast(skill_id: String) -> void:
	recast_pending.erase(skill_id)


# 全部捨て、捨てた skill_id を返す（ログ用）。死亡・ウェーブ交代・リトライで呼ぶ。
func clear_all_recast() -> Array:
	var dropped: Array = recast_pending.keys()
	recast_pending.clear()
	return dropped


# 窓の残りを delta だけ減らし、切れた skill_id を捨てて返す。
#
# ⚠ 切れたら「そのまま終わる」（人間の決定・2026-08-18）。最終段を自動で出さない。
#   既に出たダメージも巻き戻さない（発火済みの効果は取り消せない）。
# ⚠ Dictionary を回している最中に erase しない。消す ID を集めてから消すこと。
func tick_recast(delta: float) -> Array:
	var expired: Array = []
	for raw_id: Variant in recast_pending:
		var entry: Variant = recast_pending[raw_id]
		if not (entry is Dictionary):
			continue
		var e: Dictionary = entry as Dictionary
		e["remaining"] = float(e.get("remaining", 0.0)) - delta
		if float(e["remaining"]) <= 0.0:
			expired.append(str(raw_id))
	for skill_id: Variant in expired:
		recast_pending.erase(str(skill_id))
	return expired
