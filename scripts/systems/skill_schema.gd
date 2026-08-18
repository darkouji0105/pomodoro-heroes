class_name SkillSchema
extends RefCounted

# スキルの器の「語彙」と「1件ぶんの構造検証」だけを持つ静的クラス。
# 決定台帳は docs/01_plan/PLAN_SKILL_TEMPLATE.md、指示書は
# docs/02_exec/EXEC_SKILL_TEMPLATE_PHASE1.md。
#
# 【役割は2つだけ】
#   1. 器の語彙（値の一覧）を1箇所に持つ。値を1個足すときはここと
#      SkillResolver の分岐を1本ずつ触れば済む形に保つ
#   2. スキル1件ぶんの構造を検証する。全件回すのは MasterDataLoader 側
#
# ⚠ このファイルは MasterDataLoader を参照しない。参照すると
#   MasterDataLoader → SkillSchema → MasterDataLoader の循環になる。
#   characters.json と突き合わせる検証（射程）だけは MasterDataLoader 側に置く。
#
# ⚠ ここで push_error / push_warning を呼ばない。呼ぶのは MasterDataLoader 側。
#   件数を数えたいのと、呼ぶ場所を1箇所にするため。

# --- 検証結果の重さ ---
const LEVEL_ERROR: String = "error"
const LEVEL_WARNING: String = "warning"

# --- activation（発動の型） ---
const ACTIVATION_INSTANT: String = "instant"
const ACTIVATION_CHARGE: String = "charge"
# recast は段階5で動く。⚠ toggle は器に載せるだけ（まだ動かない）。
const ACTIVATION_RECAST: String = "recast"
const ACTIVATION_TOGGLE: String = "toggle"
# パッシブ（PLAN 7-2・19章）。⚠ 「発動の型」であって効果の trigger ではない。
#   trigger は効果1件ごとの「いつ発火するか」なので、そちらに置くと1つのスキルの
#   中に「cast の効果」と「パッシブの効果」が混在でき、撃てるものなのか決まらない。
# ⚠ 発動の経路はスキルとまったく同じ（_fire_skill → cast → SkillResolver）。
#   違うのは引き金を引くのが誰かだけ。味方＝ボタン／敵＝攻撃拍／
#   パッシブ＝battle_controller._step_passives()。
# ⚠ 枠が別（BattleUnit.passive_ids）なので、ボタンにも敵AIにも混ざらない。
#   混ぜて後段で弾く形にしないこと（EXEC_SKILL_PASSIVE_VARS.md §0-1-1）。
const ACTIVATION_PASSIVE: String = "passive"
const ACTIVATIONS_KNOWN: Array = [
	ACTIVATION_INSTANT, ACTIVATION_CHARGE, ACTIVATION_RECAST, ACTIVATION_TOGGLE,
	ACTIVATION_PASSIVE
]

# --- target.team（誰を狙うか。相対で解く） ---
const TEAM_ENEMY: String = "enemy"
const TEAM_ALLY: String = "ally"
const TEAM_SELF: String = "self"
# source は「この効果を起こした相手」。段階3。
const TEAM_SOURCE: String = "source"
const TEAMS_KNOWN: Array = [TEAM_ENEMY, TEAM_ALLY, TEAM_SELF, TEAM_SOURCE]

# --- target.mode（母集団の絞り方） ---
const MODE_SELECT: String = "select"
const MODE_AREA: String = "area"   # 段階4で実装
const MODES_KNOWN: Array = [MODE_SELECT, MODE_AREA]

# --- target.origin（mode: area の円の中心・段階4） ---
#
# ⚠ mode: area のときだけ読む。mode: select に書いたら赤（E80）。
# ⚠ 省略できない（E77）。既定値を作らないこと。既定を user にすると「敵の団を
#   狙ったつもりが自分の足元で爆発」、target にすると逆が、どちらも書き忘れた
#   だけで黙って起きる（stack の既定値を作らなかったのと同じ理由）。
#
# ⚠ radius は「中心からの距離」。range（使用者からの距離）と混ぜないこと。
#   range は起点を1体選ぶときの絞りにしか効かず、radius は range を越えて
#   巻き込む（人間の決定・EXEC_SKILL_AREA.md §0）。
const ORIGIN_USER: String = "user"       # 使用者の位置が中心。sort / range は書けない（E78）
const ORIGIN_TARGET: String = "target"   # sort で選んだ1体の位置が中心
const ORIGINS_KNOWN: Array = [ORIGIN_USER, ORIGIN_TARGET]

# --- target.sort（並べ替え） ---
const SORT_NEAREST: String = "nearest"
const SORT_FARTHEST: String = "farthest"
const SORT_LOWEST_HP: String = "lowest_hp"
const SORT_HIGHEST_HP: String = "highest_hp"
const SORT_ALL: String = "all"
const SORTS_KNOWN: Array = [
	SORT_NEAREST, SORT_FARTHEST, SORT_LOWEST_HP, SORT_HIGHEST_HP, SORT_ALL
]

# --- effects[].type ---
const EFFECT_DAMAGE: String = "damage"
const EFFECT_HEAL: String = "heal"
const EFFECT_BUFF: String = "buff"   # 段階3で実装
const EFFECT_DOT: String = "dot"     # 段階3で実装
const EFFECT_REACT: String = "react" # 段階3の後半①で実装（購読）
const EFFECT_TYPES_KNOWN: Array = [
	EFFECT_DAMAGE, EFFECT_HEAL, EFFECT_BUFF, EFFECT_DOT, EFFECT_REACT,
	"dispel", "cancel", "transform", "move", "summon"
]
# 実際に当たるもの。他は「書けるが飛ばす」（黄）。
const EFFECT_TYPES_IMPLEMENTED: Array = [
	EFFECT_DAMAGE, EFFECT_HEAL, EFFECT_BUFF, EFFECT_DOT, EFFECT_REACT
]
# 状態として残る効果。host / status_id / stack / 寿命の欄を読む（PLAN 13章）。
const EFFECT_TYPES_STATUS: Array = [EFFECT_BUFF, EFFECT_DOT, EFFECT_REACT]

# 介入点の欄（PLAN 11-1・段階3の後半③）。⚠ buff にしか書けない。
#
# ダメージの介入点だけは受け口が段階1からあり（SkillResolver._step_crit_override /
# _step_reduction）、こちらは残る3つ（回復・状態の付与・死亡）。
#
# ⚠ 効果の種類は増えていない。EFFECT_TYPES_* に何も足さないこと。
# ⚠ stat / value と同時に持ってよい（「攻撃力＋10かつ毒に免疫」）。
#   3つを同時に持ってもよい。排他にしない。
# ⚠ 4つ目が来たら intervene{} の入れ子に畳むこと（EXEC_SKILL_INTERVENTION.md §8）。
const BUFF_ON_DEATH: String = "on_death"              # { revive_hp_ratio: float }
const BUFF_BLOCK_STATUS: String = "block_status"      # Array[String]（status_id）
const BUFF_HEAL_TAKEN_PCT: String = "heal_taken_pct"  # int（負なら低下）
const BUFF_INTERVENE_FIELDS: Array = [
	BUFF_ON_DEATH, BUFF_BLOCK_STATUS, BUFF_HEAL_TAKEN_PCT
]

# --- attack_type（どの防御で受けるか。攻撃側の参照元は scale_from） ---
# ⚠ physical / magic は BattleUnit の定数を唯一の正とする。
#    ここに書き直さないこと（2本目の一覧を作ると片方だけ直して事故る）。
const ATTACK_TYPE_TRUE: String = "true"   # 確定ダメージ（防御を0として扱う）

# --- effects[].host（効果の寿命の持ち主） ---
const HOST_NONE: String = "none"
const HOST_UNIT: String = "unit"
const HOST_POINT: String = "point"
const HOST_BATTLE: String = "battle"
const HOST_SPAWN: String = "spawn"
const HOSTS_KNOWN: Array = [HOST_NONE, HOST_UNIT, HOST_POINT, HOST_BATTLE, HOST_SPAWN]

# --- effects[].trigger（いつ発火するか） ---
# 解釈するのは SkillRuntime。⚠ SkillResolver は trigger を読まない（2箇所で解釈すると必ずズレる）。
const TRIGGER_CAST: String = "cast"
const TRIGGER_CHARGE_START: String = "charge_start"   # 段階2で実装
const TRIGGER_PREFIX_EVENT: String = "event:"

# 唯一「合図を出す側が居る」イベント名。ProjectileView が着弾で返す（PLAN 6-7）。
# ⚠ 語彙はここに置く。SkillSchema を参照する側（SkillRuntime）で定義すると、
#   検証がイベント名を知るために相互参照になる。
const EVENT_HIT: String = "hit"
const TRIGGER_PREFIX_DELAY: String = "delay:"         # 段階2で実装

# --- react.event（外の出来事＝購読・PLAN 10章） ---
#
# ⚠ EVENT_HIT（trigger の合図）と別の一覧にすること。演出シーンの合図と
#   外の出来事は別物で、混ぜると trigger: "event:took_damage" が書けてしまう。
#
# ⚠ attacked と dealt_damage を1つにしないこと。空振り（対象0体）と、
#   当たったが0ダメージは別の出来事。
const EVENT_ATTACKED: String = "attacked"            # damage の効果が発火した（空振りでも出る）
const EVENT_DEALT_DAMAGE: String = "dealt_damage"    # ダメージが1件確定した（攻撃者に配る）
const EVENT_TOOK_DAMAGE: String = "took_damage"      # ダメージが1件確定した（被害者に配る）
const EVENTS_KNOWN: Array = [EVENT_ATTACKED, EVENT_DEALT_DAMAGE, EVENT_TOOK_DAMAGE]

# --- effects[].delivery（どう届くか。待ち行列の種別タグ・PLAN 6-8） ---
#
# ⚠ attack_type（どの防御で受けるか）とは別物。混ぜないこと。
#   attack_type は 5-2-1 で「防御の参照先だけ」に純化した欄で、送り方の意味は持たない。
#   段階3の効果 cancel（飛び道具の無効化）と詠唱中断が、このタグで待ち行列を絞る。
#
# 省略時は melee。回復と自傷にも melee が入るが、投射する回復を作るまで実害は無い。
const DELIVERY_MELEE: String = "melee"
const DELIVERY_PROJECTILE: String = "projectile"
const DELIVERY_MAGIC: String = "magic"
const DELIVERIES_KNOWN: Array = [DELIVERY_MELEE, DELIVERY_PROJECTILE, DELIVERY_MAGIC]

# --- effects[].stack（重ねがけ規則・PLAN 13-2） ---
#
# ⚠ 省略時の既定値を作らない（scale_from と同じ方針）。書き忘れがどちらに
#   倒れても無音で挙動が変わるため。
#   既定を independent にすると、上書きのつもりで書き忘れたときスタックが
#   無限に積み上がる。既定を refresh にすると、独立のつもりで書き忘れたとき
#   DoT が重ならずダメージが黙って半分になる。どちらもエラーが出ない。
const STACK_INDEPENDENT: String = "independent"   # かけるたびに別の状態が増える
const STACK_REFRESH: String = "refresh"           # 同じ状態を寿命ごと置き直す
const STACKS_KNOWN: Array = [STACK_INDEPENDENT, STACK_REFRESH]

# --- effects[].until（秒数以外の寿命・PLAN 13-3） ---
#
# ⚠ duration_sec と排他。両方書いたら赤。
const UNTIL_CHARGE_END: String = "charge_end"
# ⚠ skill_end は語彙だけ。剥がすには「その cast_id の待ち行列が空か」を
#   SkillRuntime に聞く配線が要る。段階3の後半でまとめる（書くと黄で飛ばされる）。
const UNTIL_SKILL_END: String = "skill_end"
const UNTILS_KNOWN: Array = [UNTIL_CHARGE_END, UNTIL_SKILL_END]

# --- effects[].condition（毎フレーム評価する発火源・PLAN 10章） ---
#
# ⚠ of は scale_from の of（user / target / source）と別の一覧にすること。
#   状態には user も target も居ない（宿主と付与者しかいない）。同じ語を
#   使い回すと「target って誰？」が無音でズレる。
const COND_OF_HOST: String = "host"       # 宿主（付けられた側）
const COND_OF_SOURCE: String = "source"   # 付与者（付けた側）
const COND_OF_KNOWN: Array = [COND_OF_HOST, COND_OF_SOURCE]

const COND_OP_LT: String = "lt"
const COND_OP_LTE: String = "lte"
const COND_OP_GT: String = "gt"
const COND_OP_GTE: String = "gte"
const COND_OP_EQ: String = "eq"
const COND_OPS_KNOWN: Array = [COND_OP_LT, COND_OP_LTE, COND_OP_GT, COND_OP_GTE, COND_OP_EQ]

# その状態が付いているか。⚠ 0 か 1 しか返さない。
#   件数を返す status_count を作らないこと。作るとスタック閾値（Nスタックで別の
#   効果）がここから書けてしまうが、stack の上限も消え方も未実装（宿題5）なので、
#   independent が無限に積む状態に閾値が乗り、一度真になったら二度と偽に戻らない。
#   「デバフの数だけ強く」は変数表の担当（段階3の後半④）。条件は bool だけを返す。
const COND_SOURCE_STATUS_HAS: String = "status_has"

# --- scale_from の "of"（誰の値を見るか） ---
const SCALE_OF_USER: String = "user"
const SCALE_OF_TARGET: String = "target"
const SCALE_OF_SOURCE: String = "source"   # 段階3
const SCALE_OF_KNOWN: Array = [SCALE_OF_USER, SCALE_OF_TARGET, SCALE_OF_SOURCE]

# --- scale_from の source のうち、10軸ではないもの ---
const SCALE_HP_CURRENT: String = "hp_current"
const SCALE_HP_LOST: String = "hp_lost"
const SCALE_HP_RATIO: String = "hp_ratio"
const SCALE_HP_LOST_RATIO: String = "hp_lost_ratio"
const SCALE_DISTANCE: String = "distance"

# --- scale_from の source のうち、戦闘全体の値（PLAN 5-5-2「戦闘」の群） ---
# ⚠ wave_index は 1 始まり（BattleSession.current_wave をそのまま返す）。
#   名前が _index なので 0 始まりに読めるが、"wave_index >= 2" で「2波目以降」。
const SCALE_ELAPSED_SEC: String = "elapsed_sec"
const SCALE_ALIVE_ALLY: String = "alive_count_ally"
const SCALE_ALIVE_ENEMY: String = "alive_count_enemy"
const SCALE_WAVE_INDEX: String = "wave_index"

# --- scale_from の source のうち、状態の群（PLAN 5-5-2） ---
# ⚠ 入れ子で書く。{ "source": "stack", "status_id": "..." }（人間の決定）。
#   前方一致（"stack:xxx"）にしない。scale_sources() の「列挙できる形」が崩れ、
#   利用者すべて（condition_sources / E群 / 評価器2本）に前置き分岐が要る
#   （PLAN 5-5-4「自由文字列にしない」）。
# ⚠ condition の source: "status_has" + 兄弟の status_id 欄と同じ型。
const SCALE_STACK: String = "stack"

# of を読まない source。⚠ 例外の一覧はここ1本。分岐を各所に散らさないこと。
#   distance … 2者の間の値 ／ elapsed_sec・wave_index … 戦闘全体の値
const SCALE_SOURCES_NO_OF: Array = [SCALE_DISTANCE, SCALE_ELAPSED_SEC, SCALE_WAVE_INDEX]

# independent の上限（PLAN 13-1・宿題6）。
# ⚠ 上限に達したら「積まない」。古いものを捨てて積む形にしないこと
#   （寿命が延び続けて実質無限になる）。
# ⚠ これが無いと stack:<状態ID> の閾値が一度真になったら二度と偽に戻らない
#   （EXEC_SKILL_CONDITION.md §2-3 が status_count を作らなかった理由）。
const FIELD_MAX_STACK: String = "max_stack"

# スキル直下に書いてよい欄。
# ⚠ typo を黙って既定値にしないための最後の砦（E26）。
const SKILL_FIELDS_KNOWN: Array = [
	"name_key", "user_character_id", "unlock_level", "cooldown_sec",
	"activation", "charge", "recast", "target", "effects", "phases"
]

# charge{} の必須欄（数値）
const CHARGE_FIELDS_REQUIRED: Array = [
	"just_sec", "just_window_sec", "min_ratio", "just_bonus"
]

# --- phases[] / recast（段階5・PLAN 3-2 / 8章） ---

# 段の直下に書いてよい欄。⚠ typo を黙って既定値にしないための砦（E89）。
# ⚠ target は段ごとに必須。1段目から引き継がない。段は独立した発動であり
#   （cast_id も BattleLog の行も別）、引き継ぎを許すと2段目の対象が JSON から
#   読めなくなる。effects[].target の「上書き」とは意味が違う。
const PHASE_FIELDS_KNOWN: Array = ["target", "effects"]

# recast{} の必須欄（数値）
# ⚠ MasterDataLoader が返すのは float。is int で見ないこと（E69 の事故）。
const RECAST_FIELDS_REQUIRED: Array = ["window_sec"]

# 段の最小数。⚠ 1段の recast は window_sec が意味を持たず、「省略と同じ」の
#   つもりなのか「2段目を書き忘れた」のかが読めない（既定値を作らない方針）。
const PHASES_MIN: int = 2


# ============================================================
# 段（phases[]）の取り出し（段階5・PLAN 3-2）
# ============================================================

# 段の数。⚠ phases が無ければ 1（省略＝1段）。
static func phase_count(skill_data: Dictionary) -> int:
	var raw: Variant = skill_data.get("phases", null)
	if not (raw is Array):
		return 1
	return maxi((raw as Array).size(), 1)


# 段を1つ選び、その段の target / effects を直下に持つスキル定義を返す。
#
# ⚠ phases が無ければ引数をそのまま返す（複製もしない）。
#   「phases 省略の既存スキル全件が1ミリも変わらない」を、注意ではなく構造で守るため。
#   分岐を _fire_skill / blocked_reason / cast の3箇所に書くと、必ず1箇所だけ
#   直す事故になる（状態を消す経路を1本ずつ対応して踏んだのと同じ形）。
#
# ⚠ ここが段を知る唯一の場所。SkillRuntime も SkillResolver も段を知らないまま。
static func phase_of(skill_data: Dictionary, index: int) -> Dictionary:
	var raw: Variant = skill_data.get("phases", null)
	if not (raw is Array) or (raw as Array).is_empty():
		return skill_data

	var phases: Array = raw as Array
	# ⚠ 範囲外は 0 に丸める。撃てないより1段目が出るほうが、壊れ方が見える。
	var i: int = index
	if i < 0 or i >= phases.size():
		i = 0
	var raw_phase: Variant = phases[i]
	if not (raw_phase is Dictionary):
		# ロード時検証（E88）が守っているので通常は来ない。二重に守る。
		push_error("[SkillSchema] phases[%d] が Dictionary でない" % i)
		return skill_data

	var phase: Dictionary = raw_phase as Dictionary
	# ⚠ 浅い複製。中の target / effects は差し替えるので触らない。
	var out: Dictionary = skill_data.duplicate()
	out.erase("phases")
	out["target"] = phase.get("target", {})
	out["effects"] = phase.get("effects", [])
	return out


# attack_type に書ける値。BattleUnit の定数から組み立てる（2本目の一覧を作らない）。
static func attack_types_known() -> Array:
	return [BattleUnit.ATTACK_TYPE_PHYSICAL, BattleUnit.ATTACK_TYPE_MAGIC, ATTACK_TYPE_TRUE]


# scale_from の source に書ける名前（段階1ぶん）。
# 10軸は GameManager.get_stat_keys() が唯一の正。ここに軸名を並べた
# 2本目の配列を作らないこと。
static func scale_sources() -> Array:
	var sources: Array = []
	for stat_key in GameManager.get_stat_keys():
		sources.append(str(stat_key))
	sources.append(SCALE_HP_CURRENT)
	sources.append(SCALE_HP_LOST)
	sources.append(SCALE_HP_RATIO)
	sources.append(SCALE_HP_LOST_RATIO)
	sources.append(SCALE_DISTANCE)
	# 戦闘の群・状態の群（段階3の後半④）。
	# ⚠ ここに足したら、評価器2本（SkillResolver._scale_variable と
	#   StatusRegistry._condition_value）の両方に枝を足すこと。片方だけだと
	#   「damage では効くのに condition では0」という壊れ方をする。
	sources.append(SCALE_ELAPSED_SEC)
	sources.append(SCALE_ALIVE_ALLY)
	sources.append(SCALE_ALIVE_ENEMY)
	sources.append(SCALE_WAVE_INDEX)
	sources.append(SCALE_STACK)
	return sources


# condition の source に書ける名前。
#
# ⚠ scale_sources() を流用する（2本目の語彙を作らない）。
# ⚠ distance だけ除く。あちらは「使用者と対象の間」の値だが、状態には対象が居ない
#   ので、そのまま流用すると「宿主と付与者の距離」という別の意味になる。
#   座標の規則は point のオーラを入れる回で決める。
static func condition_sources() -> Array:
	var sources: Array = []
	for source_name: Variant in scale_sources():
		if str(source_name) != SCALE_DISTANCE:
			sources.append(str(source_name))
	sources.append(COND_SOURCE_STATUS_HAS)
	return sources


# スキル1件ぶんの構造を検証する。
# 戻り値は { "level": "error" or "warning", "message": String } の配列。空＝問題なし。
# message には必ず skill_id を含める（どのスキルが壊れているか分からないと直せない）。
# 通常攻撃（characters.json / enemies.json の "basic_attack"）を検証する。
# 戻り値の形は validate() と同じ。
#
# 【なぜ入口を分けるか】通常攻撃には target が無い。狙う相手は「歩いて近づいた
# 相手」（BattleUnit.target_unit_id）で決まっており、撃つ瞬間に選び直さない。
# ⚠ validate() に通すと target が必須になるが、通常攻撃は「書かなければ
#   歩いて近づいた相手を撃つ」が既定。必須にすると9件とも同じ target を
#   書き写すことになり、書いても効かない欄が増える。
#
# 【target を書いたとき】範囲攻撃になる（人間の決定・2026-08-16）。
# ⚠ 書いたユニットだけ「歩いて近づいた相手」以外にも当たる。射程の判定は
#   変わらない（近づいた相手が attack_range に入ったら発動する）。
#
# ⚠ 効果1件ぶんの検証は _validate_effect() を共用する。ここに2本目の判定を
#   書かないこと（scale_from や attack_type の規則が片方だけ古くなる）。
static func validate_basic_attack(owner_id: String, data: Dictionary) -> Array:
	var issues: Array = []

	if data == null or data.is_empty():
		_err(issues, owner_id, "basic_attack が無い、または空（通常攻撃が撃てない）")
		return issues

	# ⚠ スキルの欄を書いても効かない。黙って無視すると「書いたのに変わらない」になる。
	for field: Variant in ["activation", "charge", "cooldown_sec", "unlock_level", "phases"]:
		if data.has(field):
			_err(issues, owner_id, "basic_attack に %s は書けない（通常攻撃はスキルではない）" % str(field))

	# target は省略可。書いた場合だけ検証する（範囲攻撃）。
	# ⚠ range は書けない。通常攻撃の射程は characters.json の attack_range が持つ。
	#   2箇所に射程があると、どちらが効いているか実機でしか分からなくなる。
	if data.has("target"):
		var raw_target: Variant = data.get("target", null)
		if not (raw_target is Dictionary):
			_err(issues, owner_id, "basic_attack.target が Dictionary でない")
		else:
			_validate_target(issues, owner_id, raw_target as Dictionary, "basic_attack.target", false)

	var raw_effects: Variant = data.get("effects", null)
	if not (raw_effects is Array) or (raw_effects as Array).is_empty():
		_err(issues, owner_id, "basic_attack.effects が無い、配列でない、または空")
		return issues

	var index: int = 0
	for raw_effect: Variant in (raw_effects as Array):
		if not (raw_effect is Dictionary):
			_err(issues, owner_id, "basic_attack.effects[%d] が Dictionary でない" % index)
			index += 1
			continue
		var effect: Dictionary = raw_effect as Dictionary
		# ⚠ trigger は書ける（投射物の回に解禁した）。
		#   一度「通常攻撃は待ち行列に載せない」と禁止したが、それは誤りだった。
		#   要素は着弾で発火して消えるので伸び続けない。そして載せないと、
		#   飛び道具の無効化（cancel_by_delivery）が通常攻撃の矢にだけ効かなくなる。
		#
		# ⚠ 効果ごとの target 上書きは引き続き書けない。通常攻撃が狙うのは
		#   「歩いて近づいた相手」で、撃つ瞬間に選び直してはいけない。
		if effect.has("target"):
			_err(issues, owner_id, "basic_attack.effects[%d] に target は書けない" % index)
		_validate_effect(issues, owner_id, effect, index, ACTIVATION_INSTANT)
		index += 1

	return issues


static func validate(skill_id: String, data: Dictionary) -> Array:
	var issues: Array = []

	# E1
	if data == null or data.is_empty():
		_err(issues, skill_id, "定義が空、または Dictionary ではない")
		return issues

	# E2 旧欄の残骸。「移行し忘れ」を確実に捕まえる。
	if data.has("type"):
		_err(issues, skill_id, "旧欄 'type' が残っている（activation / target / effects[] に割ること）")

	# E3
	if str(data.get("name_key", "")) == "":
		_err(issues, skill_id, "name_key が無い")
	if str(data.get("user_character_id", "")) == "":
		_err(issues, skill_id, "user_character_id が無い")

	# E5 / W1
	var activation: String = str(data.get("activation", ""))
	if not (activation in ACTIVATIONS_KNOWN):
		_err(issues, skill_id, "activation が不明: '%s'" % activation)
	elif activation == ACTIVATION_TOGGLE:
		_warn(issues, skill_id, "activation: '%s' は段階5以降。段階1では動かない" % activation)

	var is_passive: bool = (activation == ACTIVATION_PASSIVE)

	# E4
	# ⚠ unlock_level はパッシブにも要る（育成の枠がレベルで解放を出す）。
	# ⚠ cooldown_sec はパッシブには書けない（E73）。撃つものではないため。
	if not _is_num(data.get("unlock_level", null)):
		_err(issues, skill_id, "unlock_level が数値でない")
	if not is_passive and not _is_num(data.get("cooldown_sec", null)):
		_err(issues, skill_id, "cooldown_sec が数値でない")

	# E73 パッシブに撃つための欄は書けない。
	# ⚠ cooldown_sec を書いても BattleUnit.start_cooldown() は passive_ids を
	#   見ないので何も起きない。無音で無視される欄を書かせない。
	if is_passive:
		# E92 recast も同じ（パッシブは撃つものではないので構えようがない）。
		for field: String in ["cooldown_sec", "charge", "recast", "phases"]:
			if data.has(field):
				_err(issues, skill_id, "activation: 'passive' に %s は書けない（撃つものではない）" % field)

	# E6 / E7
	var raw_charge: Variant = data.get("charge", null)
	if activation == ACTIVATION_CHARGE:
		if not (raw_charge is Dictionary):
			_err(issues, skill_id, "activation: charge なのに charge{} が無い")
		else:
			for field: Variant in CHARGE_FIELDS_REQUIRED:
				if not _is_num((raw_charge as Dictionary).get(field, null)):
					_err(issues, skill_id, "charge.%s が数値でない" % str(field))
	elif data.has("charge"):
		_err(issues, skill_id, "activation が charge 以外なのに charge{} がある")

	# E81 / E82 / E83 recast{}
	# ⚠ charge と同じ形（軸が値を取ったときだけ読む欄）。E6 / E7 と対称に保つこと。
	var raw_recast: Variant = data.get("recast", null)
	if activation == ACTIVATION_RECAST:
		if not (raw_recast is Dictionary):
			_err(issues, skill_id, "activation: recast なのに recast{} が無い")
		else:
			for field: Variant in RECAST_FIELDS_REQUIRED:
				# ⚠ MasterDataLoader が返すのは float。is int で見ないこと（E69）。
				if not _is_num((raw_recast as Dictionary).get(field, null)):
					_err(issues, skill_id, "recast.%s が数値でない" % str(field))
				elif float((raw_recast as Dictionary).get(field, 0.0)) <= 0.0:
					_err(issues, skill_id, "recast.%s は 0 より大きいこと（構える時間が無いと再発動できない）" % str(field))
	elif data.has("recast"):
		_err(issues, skill_id, "activation が recast 以外なのに recast{} がある")

	# E84〜E91 phases[]
	# ⚠ phases があるときは target / effects を段が持つ。直下には書けない（E86）。
	var has_phases: bool = data.has("phases")
	if activation == ACTIVATION_RECAST and not has_phases:
		_err(issues, skill_id, "activation: recast なのに phases[] が無い（再発動する段が無い）")
	elif has_phases and activation != ACTIVATION_RECAST:
		_err(issues, skill_id, "phases[] は activation: recast のスキルにしか書けない")
	if has_phases:
		if data.has("target") or data.has("effects"):
			_err(issues, skill_id, "phases[] と直下の target / effects は同居できない（どちらが効くか読めなくなる）")
		_validate_phases(issues, skill_id, data.get("phases", null), activation)

	# E8〜E15 target
	# ⚠ phases があるときは走らせない。走らせると、正しく書いた recast スキルが
	#   必ず E8 と E17 の2本を出す。
	var raw_target: Variant = data.get("target", null)
	if has_phases:
		pass
	elif not (raw_target is Dictionary):
		_err(issues, skill_id, "target が無い、または Dictionary でない")
	else:
		_validate_target(issues, skill_id, raw_target as Dictionary, "target", true)
		# E74 パッシブは自分にしか効かない。
		# ⚠ _step_passives() は「宿主に付いているか」で撃ち直すので、他人に
		#   付く形にすると、相手が死ぬたびに撃ち直して無限に付け直す。
		if is_passive and str((raw_target as Dictionary).get("team", "")) != TEAM_SELF:
			_err(issues, skill_id, "activation: 'passive' の target.team は 'self' だけ")

	# E17 effects
	# ⚠ phases があるときは走らせない（E8 と同じ理由）。
	var raw_effects: Variant = data.get("effects", null)
	if has_phases:
		pass
	elif not (raw_effects is Array) or (raw_effects as Array).is_empty():
		_err(issues, skill_id, "effects が無い、配列でない、または空")
	else:
		var index: int = 0
		for raw_effect: Variant in (raw_effects as Array):
			if not (raw_effect is Dictionary):
				_err(issues, skill_id, "effects[%d] が Dictionary でない" % index)
			else:
				# activation を渡すのは E44 / E45（チャージ専用の欄を instant に
				# 書いていないか）のため。効果だけを見ても判定できない。
				_validate_effect(issues, skill_id, raw_effect as Dictionary, index, activation)
			index += 1

	# E26 知らない欄（typo をここで捕まえる）
	for key: Variant in data:
		if not (str(key) in SKILL_FIELDS_KNOWN):
			_err(issues, skill_id, "知らない欄がある: '%s'" % str(key))

	return issues


# phases[] の検証（E87〜E91）。
#
# ⚠ 段の中身は _validate_target() / _validate_effect() をそのまま呼ぶ。
#   段専用の検証を2本目として書かないこと（片方だけ古くなる）。
static func _validate_phases(
		issues: Array, skill_id: String, raw_phases: Variant, activation: String
) -> void:
	# E87
	if not (raw_phases is Array):
		_err(issues, skill_id, "phases が配列でない")
		return
	var phases: Array = raw_phases as Array
	if phases.size() < PHASES_MIN:
		_err(issues, skill_id, "phases[] は段が %d つ以上要る（今 %d つ。1段なら phases を書かないこと）" % [
			PHASES_MIN, phases.size()
		])

	var index: int = 0
	for raw_phase: Variant in phases:
		var where: String = "phases[%d]" % index
		# E88
		if not (raw_phase is Dictionary):
			_err(issues, skill_id, "%s が Dictionary でない" % where)
			index += 1
			continue
		var phase: Dictionary = raw_phase as Dictionary

		# E89 知らない欄
		for key: Variant in phase:
			if not (str(key) in PHASE_FIELDS_KNOWN):
				_err(issues, skill_id, "%s に知らない欄がある: '%s'" % [where, str(key)])

		# E90 target は段ごとに必須（1段目から引き継がない）
		var raw_target: Variant = phase.get("target", null)
		if not (raw_target is Dictionary):
			_err(issues, skill_id, "%s.target が無い、または Dictionary でない" % where)
		else:
			_validate_target(issues, skill_id, raw_target as Dictionary, where + ".target", true)

		# E91 effects
		var raw_effects: Variant = phase.get("effects", null)
		if not (raw_effects is Array) or (raw_effects as Array).is_empty():
			_err(issues, skill_id, "%s.effects が無い、配列でない、または空" % where)
		else:
			var ei: int = 0
			for raw_effect: Variant in (raw_effects as Array):
				if not (raw_effect is Dictionary):
					_err(issues, skill_id, "%s.effects[%d] が Dictionary でない" % [where, ei])
				else:
					# ⚠ where_prefix を渡すと "phases[0].effects[1]" と出る
					#   （_validate_effect が ".effects[%d]" を足す）。
					_validate_effect(
						issues, skill_id, raw_effect as Dictionary, ei, activation, where
					)
				ei += 1
		index += 1


# target ブロックの検証。effects[].target からも呼ぶ（そちらは range を禁じる）。
static func _validate_target(
		issues: Array, skill_id: String, target: Dictionary, where: String, allow_range: bool
) -> void:
	var team: String = str(target.get("team", ""))

	# E9
	if not (team in TEAMS_KNOWN):
		_err(issues, skill_id, "%s.team が不明: '%s'" % [where, team])
		return

	# E52 team: source に mode / sort / count / range を書かせない（PLAN 10-3）。
	# ⚠ きっかけのユニットIDをそのまま使う欄なので、選び直す語彙を書けてはならない。
	#   書ける形にすると「選び直さない」という決定が JSON 側から破れる。
	if team == TEAM_SOURCE:
		for field: Variant in ["mode", "sort", "count", "range"]:
			if target.has(field):
				_err(issues, skill_id, "%s.team: source に %s は書けない（きっかけのユニットを選び直さない）" % [where, str(field)])
		return

	# E10 team: self に mode / sort / count / origin を書かせない
	# （mode を読むかが team で決まる逆流を作らないため。PLAN 21章）
	# ⚠ origin も同じ。self は mode を読まないので、書いても1つも効かない。
	if team == TEAM_SELF:
		for field: Variant in ["mode", "sort", "count", "origin"]:
			if target.has(field):
				_err(issues, skill_id, "%s.team: self に %s は書けない" % [where, str(field)])
	else:
		# E11
		var mode: String = str(target.get("mode", ""))
		if not (mode in MODES_KNOWN):
			_err(issues, skill_id, "%s.mode が無い、または不明: '%s'" % [where, mode])
		elif mode == MODE_AREA:
			# ⚠ W2（「area は段階4」の黄）は段階4で実装したので消した。残すと
			#   正しい JSON を書くたびに黄が出る（EXEC_SKILL_AREA.md §0-1 の8）。
			#
			# E15 radius … 中心からの距離。⚠ range（使用者からの距離）ではない。
			if not _is_num(target.get("radius", null)) or float(target.get("radius", 0.0)) <= 0.0:
				_err(issues, skill_id, "%s.mode: area なのに radius が正の数値でない" % where)

			# E77 origin … 省略できない（既定値を作らない・ORIGINS_KNOWN の注記）
			var origin: String = str(target.get("origin", ""))
			if not (origin in ORIGINS_KNOWN):
				_err(issues, skill_id, "%s.mode: area の origin が無い、または不明: '%s'（'user' か 'target'）" % [where, origin])
			elif origin == ORIGIN_USER:
				# E78 … origin: user は起点を選ばないので、選ぶための欄が1つも効かない。
				# ⚠ range も同じ。radius が「近くに敵が居るときだけ撃てる」を兼ねる
				#   （radius の中が0体なら select_targets() が空を返し no_target で弾かれる）。
				for field: Variant in ["sort", "range"]:
					if target.has(field):
						_err(issues, skill_id, "%s.origin: user に %s は書けない（起点を選ばない）" % [where, str(field)])
			else:
				# E79 … all は起点が1体に決まらない
				if str(target.get("sort", SORT_NEAREST)) == SORT_ALL:
					_err(issues, skill_id, "%s.origin: target に sort: 'all' は書けない（起点が1体に決まらない）" % where)
				# ⚠ sort そのものの綴りは下の共通の検証（E12）が見る

			# E80 count … radius の中は全員に当たる（人間の決定）
			if target.has("count"):
				_err(issues, skill_id, "%s.mode: area に count は書けない（radius の中は全員）" % where)

			# E12 と同じ綴りの検査を area にも掛ける（2本目の一覧を作らない）
			var area_sort: String = str(target.get("sort", SORT_NEAREST))
			if not (area_sort in SORTS_KNOWN):
				_err(issues, skill_id, "%s.sort が不明: '%s'" % [where, area_sort])
		else:
			# E80 origin … mode: select では読まない欄
			if target.has("origin"):
				_err(issues, skill_id, "%s.origin は mode: 'area' のときだけ書ける" % where)
			# E12 sort（省略は許す＝nearest）
			var sort: String = str(target.get("sort", SORT_NEAREST))
			if not (sort in SORTS_KNOWN):
				_err(issues, skill_id, "%s.sort が不明: '%s'" % [where, sort])
			# E13 count（sort: all は count を読まない。省略は許す＝1）
			elif sort != SORT_ALL and target.has("count"):
				var count: Variant = target.get("count", null)
				if not _is_num(count) or float(count) < 1.0 or float(count) != floor(float(count)):
					_err(issues, skill_id, "%s.count が1以上の整数でない" % where)

	# E14 / E16 range
	if target.has("range"):
		if not allow_range:
			_err(issues, skill_id, "%s に range は書けない（射程はスキルの母集団を絞るもの）" % where)
		elif not _is_num(target.get("range", null)) or float(target.get("range", 0.0)) <= 0.0:
			_err(issues, skill_id, "%s.range が正の数値でない" % where)


# effects[] の1要素ぶんの検証。
#
# where_prefix … react.effects[] から再帰で呼ぶときの位置（"effects[0].react" の形）。
#                空なら "effects[%d]"。⚠ 表示のためだけの引数。判定に使わない。
# in_react     … 購読の中を見ている（E53：購読の入れ子を禁じる）。
static func _validate_effect(
		issues: Array, skill_id: String, effect: Dictionary, index: int, activation: String,
		where_prefix: String = "", in_react: bool = false
) -> void:
	var where: String = "effects[%d]" % index
	if where_prefix != "":
		where = "%s.effects[%d]" % [where_prefix, index]

	# E18
	var effect_type: String = str(effect.get("type", ""))
	if not (effect_type in EFFECT_TYPES_KNOWN):
		_err(issues, skill_id, "%s.type が無い、または不明: '%s'" % [where, effect_type])
		return

	# W4
	if not (effect_type in EFFECT_TYPES_IMPLEMENTED):
		_warn(issues, skill_id, "%s.type: '%s' はまだ実装していない。飛ばされる" % [where, effect_type])

	# E29〜E43 状態として残る効果（buff / dot / react）
	if effect_type in EFFECT_TYPES_STATUS:
		_validate_status_effect(issues, skill_id, effect, where, activation)

	# E46〜E53 購読（PLAN 10章）
	if effect_type == EFFECT_REACT:
		_validate_react_effect(issues, skill_id, effect, where, activation, in_react)
	elif effect.has("react"):
		# E50 … react{} は react 以外の効果には書けない。
		# ⚠ trigger と購読を同じ欄にしないための歯止め（PLAN 10章）。
		_err(issues, skill_id, "%s.type: '%s' に react{} は書けない（購読は type: 'react' だけ）" % [where, effect_type])

	# E62 … condition{} は残る効果（buff / dot / react）にしか書けない。
	# ⚠ E50 と同じ形の歯止め。書ける場所を1箇所に閉じる。残らない効果に書くと、
	#   毎フレーム評価する相手（状態）が存在しないので、黙って何も起きない。
	if effect.has("condition") and not (effect_type in EFFECT_TYPES_STATUS):
		_err(issues, skill_id, "%s.type: '%s' に condition{} は書けない（残らない効果は毎フレーム評価できない）" % [where, effect_type])

	if effect_type == EFFECT_DAMAGE or effect_type == EFFECT_HEAL:
		# E19
		if not _is_num(effect.get("multiplier", null)):
			_err(issues, skill_id, "%s.multiplier が数値でない" % where)

		# E20 / E21 attack_type
		if effect_type == EFFECT_DAMAGE:
			if effect.has("attack_type"):
				var attack_type: String = str(effect.get("attack_type", ""))
				if not (attack_type in attack_types_known()):
					_err(issues, skill_id, "%s.attack_type が不明: '%s'" % [where, attack_type])
		elif effect.has("attack_type"):
			# 回復が攻撃力依存だった事故の再発防止。欄そのものを作らない（PLAN 5-2）
			_err(issues, skill_id, "%s は heal なので attack_type を書けない" % where)

		# E27 scale_from は必須。既定値を作らない（決定1-5）
		if not effect.has("scale_from"):
			_err(issues, skill_id, "%s に scale_from が無い（damage / heal は必須）" % where)

	# E22 scale_from の形（buff などが書いてきた場合もここで見る）
	if effect.has("scale_from"):
		_validate_scale_from(issues, skill_id, effect.get("scale_from", null), where)

	# E23
	if effect.has("chance"):
		if not _is_num(effect.get("chance", null)):
			_err(issues, skill_id, "%s.chance が数値でない" % where)
		elif float(effect.get("chance", 1.0)) < 1.0:
			# W8
			_warn(issues, skill_id, "%s.chance は段階1では読まれない（必ず当たる扱い）" % where)
	if effect.has("charge_scales") and not (effect.get("charge_scales", null) is bool):
		_err(issues, skill_id, "%s.charge_scales が bool でない" % where)

	# E28 delivery（書いてあって値が不明なら赤。省略は許す＝melee）
	if effect.has("delivery") and not (str(effect.get("delivery", "")) in DELIVERIES_KNOWN):
		_err(issues, skill_id, "%s.delivery が不明: '%s'" % [where, str(effect.get("delivery", ""))])

	# E24 / W5 trigger
	# cast / charge_start / delay:<数値> は段階2で実装した。警告を出さない。
	# event:◯◯ だけは合図を出す側（演出シーン）が存在しないので黄のまま。
	var trigger: String = str(effect.get("trigger", TRIGGER_CAST))
	if not _is_trigger_shape(trigger):
		_err(issues, skill_id, "%s.trigger の形が不正: '%s'" % [where, trigger])
	elif trigger == TRIGGER_PREFIX_EVENT + EVENT_HIT:
		# ⚠ 'hit' だけは合図を出す側が居る（ProjectileView が着弾で返す）。
		#   ここで黄を出さないこと。飛ぶ効果は十数件あるので、出すと本物の異常が埋まる。
		pass
	elif trigger.begins_with(TRIGGER_PREFIX_EVENT):
		_warn(issues, skill_id, "%s.trigger: '%s' は合図を出す側が居ない（アニメ未実装）。タイムアウトで発火する" % [where, trigger])

	# E45 charge_start は SkillRuntime.charge_start() からしか流れない。
	# チャージしないスキルに書くと一度も発火しない。無音なので赤で弾く。
	if trigger == TRIGGER_CHARGE_START and activation != ACTIVATION_CHARGE:
		_err(issues, skill_id, "%s.trigger: 'charge_start' は activation: charge のスキルにしか書けない" % where)

	# E75 / E76 パッシブの効果の縛り（EXEC_SKILL_PASSIVE_VARS.md §2-6 / §2-7）
	#
	# ⚠ どれも「_step_passives() が毎フレーム撃ち直す」形になるのを防ぐもの。
	#   走査は「宿主にその status_id が付いていなければ撃つ」しか見ていないので、
	#   付き方がズレると毎フレーム cast が走り、フレームレートごと落ちる。
	if activation == ACTIVATION_PASSIVE:
		# E76 … 遅れて付くものは、付くまでの間ずっと「欠けている」と判定される
		if trigger != TRIGGER_CAST:
			_err(issues, skill_id, "%s.trigger: activation: 'passive' の効果は 'cast' だけ（遅れて付くと毎フレーム撃ち直す）" % where)
		if effect.has("status_id"):
			# E75 … independent だと撃つたびに新しい1件が積まれる
			if str(effect.get("stack", "")) != STACK_REFRESH:
				_err(issues, skill_id, "%s.stack: activation: 'passive' の効果は 'refresh' だけ（毎フレーム積み上がる）" % where)
			# host: unit 以外だと「宿主に付いているか」で判定できない
			if str(effect.get("host", HOST_NONE)) != HOST_UNIT:
				_err(issues, skill_id, "%s.host: activation: 'passive' の効果は 'unit' だけ" % where)

	# E25 / E30 / W6 / W9 host
	var host: String = str(effect.get("host", HOST_NONE))
	if not (host in HOSTS_KNOWN):
		_err(issues, skill_id, "%s.host が不明: '%s'" % [where, host])
	elif host == HOST_NONE:
		pass
	elif not (effect_type in EFFECT_TYPES_STATUS) and host != HOST_SPAWN:
		# E30 … 残らないものに宿主は無い（damage / heal に host を書いている）
		_err(issues, skill_id, "%s.type: '%s' に host: '%s' は書けない（残らない効果）" % [where, effect_type, host])
	elif host == HOST_POINT or host == HOST_BATTLE:
		# W9 … 器には載るが、参照する仕組み（条件・購読）が段階3の後半なので何も起きない
		_warn(issues, skill_id, "%s.host: '%s' は器に載るだけ。参照する仕組み（条件・購読）は段階3の後半" % [where, host])
	elif host == HOST_SPAWN:
		# W6
		_warn(issues, skill_id, "%s.host: 'spawn' は段階6。今は飛ばされる" % where)

	# 効果ごとの target 上書き（range は書けない＝E16）
	var raw_target: Variant = effect.get("target", null)
	if raw_target != null:
		if not (raw_target is Dictionary):
			_err(issues, skill_id, "%s.target が Dictionary でない" % where)
		else:
			_validate_target(issues, skill_id, raw_target as Dictionary, where + ".target", false)


# 購読（type: "react"）の検証。E46〜E53。
#
# ⚠ 寿命・重ねがけ・status_id は _validate_status_effect() が共通で見る。
#   ここで見るのは react{} の中身だけ（同じ判定を2箇所に書かない）。
static func _validate_react_effect(
		issues: Array, skill_id: String, effect: Dictionary, where: String,
		activation: String, in_react: bool
) -> void:
	# E53 購読の入れ子。⚠ 再帰の深さを1段に固定する歯止め。
	#    入れ子を許すと「反応の反応」が書けてしまい、10-2 の印だけでは止まらない。
	if in_react:
		_err(issues, skill_id, "%s: 購読の中に購読は書けない（反応から反応を生まない・PLAN 10-2）" % where)
		return

	# E51 宿り先は unit だけ。point（罠）は座標の規則が要る、battle（コンボ）は段階3の後半②以降。
	var host: String = str(effect.get("host", HOST_NONE))
	if host != HOST_UNIT:
		_err(issues, skill_id, "%s.host: '%s' に購読は載せられない（今は host: 'unit' だけ）" % [where, host])

	# E46
	var raw_react: Variant = effect.get("react", null)
	if not (raw_react is Dictionary):
		_err(issues, skill_id, "%s に react{} が無い、または Dictionary でない" % where)
		return
	var react: Dictionary = raw_react as Dictionary

	# E47 出来事の名前。⚠ trigger の合図（EVENT_HIT）は書けない（別の一覧）。
	var event_name: String = str(react.get("event", ""))
	if not (event_name in EVENTS_KNOWN):
		_err(issues, skill_id, "%s.react.event が無い、または不明: '%s'" % [where, event_name])

	# E48
	var raw_effects: Variant = react.get("effects", null)
	if not (raw_effects is Array) or (raw_effects as Array).is_empty():
		_err(issues, skill_id, "%s.react.effects が無い、配列でない、または空" % where)
		return

	# E49 … 中身は effects[] と同じ検証を通す（2本目の語彙を作らない）。
	var index: int = 0
	for raw_effect: Variant in (raw_effects as Array):
		if not (raw_effect is Dictionary):
			_err(issues, skill_id, "%s.react.effects[%d] が Dictionary でない" % [where, index])
		else:
			# E54 … 購読にはスキルの target が無い（反応する側の効果は単独で立つ）。
			# ⚠ 書き忘れると実行時に「target が無い」の赤が出るだけで、何も起きない。
			if not (raw_effect as Dictionary).has("target"):
				_err(issues, skill_id, "%s.react.effects[%d] に target が無い（購読の効果は各自に要る）" % [where, index])
			_validate_effect(
				issues, skill_id, raw_effect as Dictionary, index, activation,
				where + ".react", true
			)
		index += 1


# 状態として残る効果（buff / dot / react）の検証。E29〜E44 / W10 / W11。
#
# ⚠ ここで見るのは「無音で壊れる書き方」だけ。状態は、剥がれない・二重に付く・
#   一度も発火しない のどれもエラーを出さないので、書いた時点で弾く。
static func _validate_status_effect(
		issues: Array, skill_id: String, effect: Dictionary, where: String, activation: String
) -> void:
	var effect_type: String = str(effect.get("type", ""))

	# E29 残らない状態は書けない
	var host: String = str(effect.get("host", HOST_NONE))
	if host == HOST_NONE:
		_err(issues, skill_id, "%s.type: '%s' には host が要る（残らない状態は書けない）" % [where, effect_type])

	# E55〜E61 条件（毎フレーム評価する発火源・PLAN 10章）
	if effect.has("condition"):
		_validate_condition(issues, skill_id, effect.get("condition", null), where, host)

	# E36 identity
	if str(effect.get("status_id", "")) == "":
		_err(issues, skill_id, "%s.status_id が無い" % where)

	# E35 重ねがけ規則は省略不可
	if not effect.has("stack"):
		_err(issues, skill_id, "%s.stack が無い（independent / refresh を必ず書く）" % where)
	elif not (str(effect.get("stack", "")) in STACKS_KNOWN):
		_err(issues, skill_id, "%s.stack が不明: '%s'" % [where, str(effect.get("stack", ""))])

	# E69 / E70 上限（PLAN 13-1・宿題6）
	# ⚠ independent は上限が無いと無限に積む。stack:<状態ID> の変数を作った以上、
	#   上限が無いと閾値が一度真になったら二度と偽に戻らない
	#   （EXEC_SKILL_CONDITION.md §2-3）。だから必須にする。
	var stack_rule: String = str(effect.get("stack", ""))
	if stack_rule == STACK_INDEPENDENT:
		var raw_max: Variant = effect.get(FIELD_MAX_STACK, null)
		# ⚠ `raw_max is int` と書かないこと。JSON の 5 は 5.0（float）で来るので
		#   常に偽になり、正しく書いてある max_stack が全部赤になる（CLAUDE.md 3番）。
		#   ⚠ 2026-08-18 に実機で発覚。④-a から9件ぶん赤が出続けていた。
		#   整数かどうかは floor と比べて見る（E13 と同じ形）。
		if not _is_num(raw_max) or float(raw_max) < 1.0 or float(raw_max) != floor(float(raw_max)):
			_err(issues, skill_id, "%s.%s が無い、または1以上の整数でない（stack: 'independent' には必須）" % [
				where, FIELD_MAX_STACK
			])
	elif effect.has(FIELD_MAX_STACK):
		# ⚠ refresh は同一性のキーで置き直すので上限が意味を持たない。
		#   何も起きない欄を書かせない（E39 と同じ考え方）。
		_err(issues, skill_id, "%s.%s は stack: 'independent' のときだけ書ける" % [where, FIELD_MAX_STACK])

	# E31 / E32 寿命は duration_sec か until のどちらか一方
	var has_duration: bool = effect.has("duration_sec")
	var has_until: bool = effect.has("until")
	if not has_duration and not has_until:
		_err(issues, skill_id, "%s に duration_sec も until も無い" % where)
	elif has_duration and has_until:
		_err(issues, skill_id, "%s に duration_sec と until の両方がある（排他）" % where)

	# E33
	if has_duration:
		if not _is_num(effect.get("duration_sec", null)) or float(effect.get("duration_sec", 0.0)) <= 0.0:
			_err(issues, skill_id, "%s.duration_sec が正の数値でない" % where)

	# E34 / E44 / W11
	if has_until:
		var until: String = str(effect.get("until", ""))
		if not (until in UNTILS_KNOWN):
			_err(issues, skill_id, "%s.until が不明: '%s'" % [where, until])
		elif until == UNTIL_CHARGE_END and activation != ACTIVATION_CHARGE:
			# ⚠ 剥がす経路がチャージ終了しか無い。instant に書くと永久に残る
			_err(issues, skill_id, "%s.until: 'charge_end' は activation: charge のスキルにしか書けない" % where)
		elif until == UNTIL_SKILL_END:
			_warn(issues, skill_id, "%s.until: 'skill_end' は未実装（剥がす配線が無い）。この効果は飛ばされる" % where)

	# 介入点の欄（PLAN 11-1・段階3の後半③）。buff にしか書けない。
	# ⚠ 一覧はここ1本。status_registry.gd に2本目を作らないこと。
	var has_intervene: bool = false
	for field: String in BUFF_INTERVENE_FIELDS:
		if effect.has(field):
			has_intervene = true
			# E67 … buff 以外・host: unit 以外には書けない。
			# 宿主が居ないと「誰の死亡か」「誰への回復か」が決まらない。
			if effect_type != EFFECT_BUFF:
				_err(issues, skill_id, "%s.%s は buff にしか書けない（type: '%s'）" % [where, field, effect_type])
			elif host != HOST_UNIT:
				_err(issues, skill_id, "%s.%s は host: unit にしか書けない（host: '%s'）" % [where, field, host])

	if effect_type == EFFECT_BUFF:
		# ⚠ stat は「書かれているときだけ」見る。介入だけを持つ buff（復活・免疫・
		#   被回復増減）は stat も value も持たないため（段階3の後半③で緩めた）。
		var has_stat: bool = effect.has("stat") or effect.has("value")
		if has_stat:
			# E37 / E38
			var stat_key: String = str(effect.get("stat", ""))
			if not (stat_key in GameManager.get_stat_keys()):
				_err(issues, skill_id, "%s.stat が10軸に無い: '%s'" % [where, stat_key])
			elif stat_key == GameStateKeys.STAT_HP:
				_err(issues, skill_id, "%s.stat に hp は書けない（max_hp を再計算しないため）" % where)
			# E39 … 0 も禁止（何も起きない状態を書かせない）
			var value: Variant = effect.get("value", null)
			if not _is_num(value) or float(value) != floor(float(value)) or int(value) == 0:
				_err(issues, skill_id, "%s.value が0以外の整数でない" % where)
		# E63 … 何もしない buff を書かせない。
		# ⚠ これが無いと、stat を必須にしなくなった分だけ typo（"stt"）が
		#   「介入だけを持つ buff」として黙って通る。
		if not has_stat and not has_intervene:
			# ⚠ 欄名は BUFF_INTERVENE_FIELDS が唯一の正。ここで並べ直さないこと。
			var field_names: PackedStringArray = PackedStringArray()
			for f: String in BUFF_INTERVENE_FIELDS:
				field_names.append(f)
			_err(issues, skill_id, "%s は buff なのに stat / value も介入の欄（%s）も無い" % [
				where, ", ".join(field_names)
			])
		# ⚠ buff は multiplier を読まない（PLAN 5-2。意味を3つ持たせない）
		if effect.has("multiplier"):
			_err(issues, skill_id, "%s は buff なので multiplier を書けない（stat / value を使う）" % where)

		# E64 … 復活。割合は 0 より大きく 1 以下。
		# ⚠ 0 を許すと「復活した瞬間にまた死ぬ」を書けてしまい、走査が毎フレーム回る。
		if effect.has(BUFF_ON_DEATH):
			var raw_death: Variant = effect.get(BUFF_ON_DEATH, null)
			if not (raw_death is Dictionary):
				_err(issues, skill_id, "%s.%s が Dictionary でない" % [where, BUFF_ON_DEATH])
			else:
				var ratio: Variant = (raw_death as Dictionary).get("revive_hp_ratio", null)
				if not _is_num(ratio) or float(ratio) <= 0.0 or float(ratio) > 1.0:
					_err(issues, skill_id, "%s.%s.revive_hp_ratio が 0 より大きく 1 以下の数値でない" % [
						where, BUFF_ON_DEATH
					])

		# E65 … 免疫。付けさせない status_id の配列。
		if effect.has(BUFF_BLOCK_STATUS):
			var raw_block: Variant = effect.get(BUFF_BLOCK_STATUS, null)
			if not (raw_block is Array) or (raw_block as Array).is_empty():
				_err(issues, skill_id, "%s.%s が配列でない、または空" % [where, BUFF_BLOCK_STATUS])
			else:
				for item: Variant in (raw_block as Array):
					if not (item is String) or str(item) == "":
						_err(issues, skill_id, "%s.%s の要素が空でない文字列でない" % [where, BUFF_BLOCK_STATUS])
						break

		# E66 … 被回復増減。0 は禁止（E39 と同じ考え方）。
		if effect.has(BUFF_HEAL_TAKEN_PCT):
			var pct: Variant = effect.get(BUFF_HEAL_TAKEN_PCT, null)
			if not _is_num(pct) or float(pct) != floor(float(pct)) or int(pct) == 0:
				_err(issues, skill_id, "%s.%s が0以外の整数でない" % [where, BUFF_HEAL_TAKEN_PCT])

	elif effect_type == EFFECT_DOT:
		# E40
		var interval: Variant = effect.get("interval_sec", null)
		if not _is_num(interval) or float(interval) <= 0.0:
			_err(issues, skill_id, "%s.interval_sec が正の数値でない" % where)
		# E41
		if not _is_num(effect.get("multiplier", null)):
			_err(issues, skill_id, "%s.multiplier が数値でない" % where)
		# E42 … damage と同じ扱い。既定値を作らない
		if not effect.has("scale_from"):
			_err(issues, skill_id, "%s に scale_from が無い（dot は damage と同じく必須）" % where)
		# E43
		if not (str(effect.get("attack_type", "")) in attack_types_known()):
			_err(issues, skill_id, "%s.attack_type が無い、または不明: '%s'" % [where, str(effect.get("attack_type", ""))])
		# W10 … 端数は切り捨て（発火は floor(duration / interval) 回）
		if has_duration and _is_num(interval) and float(interval) > 0.0:
			var duration: float = float(effect.get("duration_sec", 0.0))
			var ratio: float = duration / float(interval)
			if absf(ratio - floor(ratio)) > 0.0001:
				_warn(issues, skill_id, "%s は duration_sec が interval_sec で割り切れない。端数は切り捨てで %d 回発火する" % [
					where, int(floor(ratio))
				])


# 条件（condition{}）の検証。E55〜E61。
#
# ⚠ 条件は「一度も真にならない」「常に真」のどちらも実行時にエラーを出さず、
#   画面を見ても分からない。書き方の誤りはここで全部弾く。
static func _validate_condition(
		issues: Array, skill_id: String, raw: Variant, where: String, host: String
) -> void:
	# E55
	if not (raw is Dictionary):
		_err(issues, skill_id, "%s.condition が Dictionary でない" % where)
		return
	var cond: Dictionary = raw as Dictionary

	# E56 … 語彙は condition_sources() が唯一の正（distance は除いてある）
	var source: String = str(cond.get("source", ""))
	if not (source in condition_sources()):
		_err(issues, skill_id, "%s.condition.source が無い、または不明: '%s'" % [where, source])

	# E57 … ⚠ scale_from の of（user / target）と別の一覧
	if not (str(cond.get("of", "")) in COND_OF_KNOWN):
		_err(issues, skill_id, "%s.condition.of が無い、または不明: '%s'（host / source のどちらか）" % [
			where, str(cond.get("of", ""))
		])

	# E58
	if not (str(cond.get("op", "")) in COND_OPS_KNOWN):
		_err(issues, skill_id, "%s.condition.op が無い、または不明: '%s'" % [where, str(cond.get("op", ""))])

	# E59
	if not _is_num(cond.get("value", null)):
		_err(issues, skill_id, "%s.condition.value が数値でない" % where)

	# E60 / E71 … ⚠ ここの status_id は「見たい相手の状態のID」で、効果の status_id とは別物
	# ⚠ status_has（付いているか）と stack（何件積まれているか）の2つが status_id を取る。
	#   どちらも入れ子の形で書く（前方一致にしない・PLAN 5-5-4）。
	if source == COND_SOURCE_STATUS_HAS or source == SCALE_STACK:
		if str(cond.get("status_id", "")) == "":
			_err(issues, skill_id, "%s.condition.source: '%s' に status_id が無い（見たい相手の状態のID）" % [where, source])
	elif cond.has("status_id"):
		_err(issues, skill_id, "%s.condition.status_id は source: 'status_has' / 'stack' のときだけ書ける" % where)

	# ⚠ ここに「of を読まない source」の黄（W12）を足さないこと。
	#   condition の of は E57 が必須にしているので、elapsed_sec / wave_index を
	#   書くたびに黄が出る＝正常系に警告を付けることになる。
	#   scale_from 側は of が省略可なので、あちらにだけ W12 を置いてある。

	# E61 … 宿り先は unit だけ。point（オーラ）は真偽が「状態 × ユニットの対」ごとに
	#       なり、状態1件につき1つの真偽では足りない（段階3の後半②の担当外）。
	if host != HOST_UNIT:
		_err(issues, skill_id, "%s.host: '%s' に condition は書けない（今は host: 'unit' だけ）" % [where, host])


# E22。文字列（省略形）か、{source, of, weight} の配列。
static func _validate_scale_from(
		issues: Array, skill_id: String, raw: Variant, where: String
) -> void:
	var terms: Array = []
	if raw is String:
		terms = [{ "source": str(raw) }]
	elif raw is Array:
		if (raw as Array).is_empty():
			_err(issues, skill_id, "%s.scale_from が空配列" % where)
			return
		terms = raw as Array
	else:
		_err(issues, skill_id, "%s.scale_from が文字列でも配列でもない" % where)
		return

	var known: Array = scale_sources()
	for term: Variant in terms:
		if not (term is Dictionary):
			_err(issues, skill_id, "%s.scale_from の要素が Dictionary でない" % where)
			continue
		var entry: Dictionary = term as Dictionary
		var source: String = str(entry.get("source", ""))
		if not (source in known):
			_err(issues, skill_id, "%s.scale_from の source が不明: '%s'" % [where, source])
		if entry.has("of") and not (str(entry.get("of", "")) in SCALE_OF_KNOWN):
			_err(issues, skill_id, "%s.scale_from の of が不明: '%s'" % [where, str(entry.get("of", ""))])
		if entry.has("weight") and not _is_num(entry.get("weight", null)):
			_err(issues, skill_id, "%s.scale_from の weight が数値でない" % where)

		# E68 … of: "source" は実装しないと決めた（人間の決定・2026-08-17）。
		# ⚠ 定数 SCALE_OF_SOURCE は残してある。外すと「of が不明」という
		#   別の文言で赤が出て、なぜ書けないのかが読み手に伝わらないため。
		# ⚠ 書けるのに 0.0 になる経路を消すのがこの赤の目的。
		if str(entry.get("of", "")) == SCALE_OF_SOURCE:
			_err(issues, skill_id, "%s.scale_from の of: 'source' は実装しないと決めた。of: 'user' / 'target' で書くこと" % where)

		# E71 / E72 … stack は入れ子で書く（{ source: "stack", status_id: "..." }）。
		# ⚠ condition 側の status_has と同じ型。前方一致にしない。
		if source == SCALE_STACK:
			if str(entry.get("status_id", "")) == "":
				_err(issues, skill_id, "%s.scale_from の source: 'stack' に status_id が無い" % where)
		elif entry.has("status_id"):
			_err(issues, skill_id, "%s.scale_from の status_id は source: 'stack' のときだけ書ける" % where)

		# W12 … of を読まない source に of を書いても無視される。
		# ⚠ 黄にしてある。赤にすると、既存の distance + of の書き方が全部止まる。
		if entry.has("of") and (source in SCALE_SOURCES_NO_OF):
			_warn(issues, skill_id, "%s.scale_from の source: '%s' は of を読まない（無視される）" % [where, source])


# trigger は cast / charge_start / event:◯◯ / delay:<数値> のどれか。
static func _is_trigger_shape(trigger: String) -> bool:
	if trigger == TRIGGER_CAST or trigger == TRIGGER_CHARGE_START:
		return true
	if trigger.begins_with(TRIGGER_PREFIX_EVENT):
		return trigger.length() > TRIGGER_PREFIX_EVENT.length()
	if trigger.begins_with(TRIGGER_PREFIX_DELAY):
		return trigger.substr(TRIGGER_PREFIX_DELAY.length()).is_valid_float()
	return false


# JSON から来る数値は float。int も許す（手書きの 1 を弾かないため）。
static func _is_num(value: Variant) -> bool:
	return (value is float) or (value is int)


static func _err(issues: Array, skill_id: String, message: String) -> void:
	issues.append({ "level": LEVEL_ERROR, "message": "%s: %s" % [skill_id, message] })


static func _warn(issues: Array, skill_id: String, message: String) -> void:
	issues.append({ "level": LEVEL_WARNING, "message": "%s: %s" % [skill_id, message] })
