class_name StatusRegistry
extends RefCounted

# 「状態の器」（PLAN_SKILL_TEMPLATE.md 13章・段階3の前半）。
# ユニット／座標／戦場に紐づく「残るもの」を持つ。
#
#   battle_controller  … 入力と表示だけ
#          ↓ cast() を1回呼ぶ
#   SkillRuntime       … 待ち行列。寿命は「スキル発動1回ぶん」
#          ↓ 効果1件ずつ
#   SkillResolver      … 1つの効果を確定した対象に当てる。時間を知らない
#          ↓ host が none 以外なら「残るもの」を登録する
#   StatusRegistry(ここ) … 状態。寿命は「スキルより長い」
#
# ⚠ SkillRuntime と混ぜないこと（PLAN 7-2）。捨てる基準が正反対。
#
#   SkillRuntime.tick()   … 使用者（撃った本人）が死んだら捨てる
#   StatusRegistry.tick() … 宿主（付けられた側）が死んだら捨てる
#                           ⚠ 付与者の死では捨てない
#
#   混ぜると、術者が死んだ瞬間に敵に付けたDoTが消える。エラーは1つも出ない。
#
# 【なぜ static にしないか】状態という状態を持つため。
# BattleController が1体だけ持つ。ノードツリーには入れない。
#
# 【持つのはIDと数字だけ】マスターデータを複製しない（CLAUDE.md 4番）。

# dot の発火結果を流す。⚠ SkillRuntime と同じ形にしてある。
# battle_controller の表示経路を1本（_on_skill_effects_applied）に保つため。
signal effects_applied(results: Array)

# 状態の種類。effects[].type から決まる。
const KIND_BUFF: String = "buff"
const KIND_DOT: String = "dot"
# 購読（PLAN 10章）。⚠ 器は「持っている」だけ。探して撃つのは SkillRuntime。
#   器から発火させると、発火の経路が _fire() の1本でなくなる（PLAN 6-5）。
const KIND_REACT: String = "react"

# 寿命の持ち方。秒数以外は SkillSchema.UNTIL_* が入る（PLAN 13-3）。
const LIFE_SEC: String = "sec"

# 発火回数の上限が無い（until 系の dot）ことを表す。
const FIRES_UNLIMITED: int = -1

var _session: BattleSession = null

# 状態の一覧。要素の形は _make_entry() を見ること。
var _entries: Array = []

var _next_instance_id: int = 1


func _init(p_session: BattleSession) -> void:
	_session = p_session


# 全部捨てて、セッションを差し替える。
#
# ⚠ 「もう一度」で BattleSession が作り直される（battle_controller.gd の
#   _init_session()）。捨てないと、状態が前の戦闘のユニットを宿主に持ち、
#   補正の組み直しが空振りする。エラーは1つも出ない。
# ⚠ 差し替えと破棄を同時にやること。片方だけの関数を作るともう片方を忘れる。
func reset(p_session: BattleSession) -> void:
	clear_all()
	_session = p_session


# ============================================================
# 付ける
# ============================================================

# 状態を1件付ける。SkillResolver から呼ぶ。付けたら true。
#
# ⚠ 状態を変える前に全部の判定を終える（CLAUDE.md 6番）。
#   この関数は、判定を全部通してから初めて _entries を触る。
#   途中で足してから弾くと、半端な状態が残る。
#
# source    … 付与者。dot の発火時にこの人の能力値を読む
# host_unit … 宿主。host: battle のときだけ null が来る
func add(
		effect: Dictionary, source: BattleUnit, host_unit: BattleUnit, session: BattleSession
) -> bool:
	if effect == null or effect.is_empty():
		push_error("[StatusRegistry] add: effect が空")
		return false
	if source == null:
		push_error("[StatusRegistry] add: source が null")
		return false
	# ⚠ セッションが食い違うのは、リトライで作り直したあと器を差し替え忘れた形。
	#   黙って登録すると、以降ずっと空振りする（§8-8 の罠）。
	if session != _session:
		push_error("[StatusRegistry] add: 渡された session が器の session と違う（reset の呼び忘れ）")
		return false

	# --- 1. 宿主 ---
	var host: String = str(effect.get("host", SkillSchema.HOST_NONE))
	if not (host in [SkillSchema.HOST_UNIT, SkillSchema.HOST_POINT, SkillSchema.HOST_BATTLE]):
		push_warning("[StatusRegistry] host: '%s' には状態を宿せない。この効果を飛ばす" % host)
		return false
	if host == SkillSchema.HOST_UNIT and host_unit == null:
		push_error("[StatusRegistry] host: unit なのに宿主が居ない")
		return false

	# --- 2. 種類 ---
	var effect_type: String = str(effect.get("type", ""))
	var kind: String = ""
	if effect_type == SkillSchema.EFFECT_BUFF:
		kind = KIND_BUFF
	elif effect_type == SkillSchema.EFFECT_DOT:
		kind = KIND_DOT
	elif effect_type == SkillSchema.EFFECT_REACT:
		kind = KIND_REACT
	else:
		push_error("[StatusRegistry] add: 状態にできない効果: '%s'" % effect_type)
		return false

	# --- 3. 識別 ---
	var status_id: String = str(effect.get("status_id", ""))
	if status_id == "":
		push_error("[StatusRegistry] add: status_id が無い")
		return false

	# --- 4. 重ねがけ規則（省略不可・決定1-5） ---
	var stack: String = str(effect.get("stack", ""))
	if not (stack in SkillSchema.STACKS_KNOWN):
		push_error("[StatusRegistry] add: stack が無い、または不明: '%s' (status_id=%s)" % [stack, status_id])
		return false

	# --- 5. 寿命（duration_sec と until は排他） ---
	var has_duration: bool = effect.has("duration_sec")
	var has_until: bool = effect.has("until")
	if has_duration == has_until:
		push_error("[StatusRegistry] add: duration_sec と until はどちらか一方だけ (status_id=%s)" % status_id)
		return false

	var life: String = LIFE_SEC
	var duration_sec: float = 0.0
	if has_until:
		life = str(effect.get("until", ""))
		if not (life in SkillSchema.UNTILS_KNOWN):
			push_error("[StatusRegistry] add: until が不明: '%s' (status_id=%s)" % [life, status_id])
			return false
		# skill_end は剥がす配線が無い（決定1-8）。付けると永久に残るので飛ばす。
		if life == SkillSchema.UNTIL_SKILL_END:
			push_warning("[StatusRegistry] until: 'skill_end' は未実装。この効果を飛ばす (status_id=%s)" % status_id)
			return false
	else:
		duration_sec = float(effect.get("duration_sec", 0.0))
		if duration_sec <= 0.0:
			push_error("[StatusRegistry] add: duration_sec が正でない (status_id=%s)" % status_id)
			return false

	# --- 6. 種類ごとの欄 ---
	var entry: Dictionary = _make_entry(kind, host, status_id, stack, life, duration_sec, source, host_unit)
	# 上限は種類（buff / dot / react）に関係なく効くので、_fill_* ではなくここで写す。
	# ⚠ ロード時検証 E69 が independent に必須・E70 が refresh に禁止を見ている。
	if effect.has(SkillSchema.FIELD_MAX_STACK):
		entry[SkillSchema.FIELD_MAX_STACK] = int(effect.get(SkillSchema.FIELD_MAX_STACK, 0))
	if kind == KIND_BUFF:
		if not _fill_buff(entry, effect):
			return false
	elif kind == KIND_REACT:
		if not _fill_react(entry, effect):
			return false
	else:
		if not _fill_dot(entry, effect, duration_sec, life):
			return false

	# --- 6-1-2. 範囲（zone{}・EXEC_SKILL_AURA.md） ---
	#
	# ⚠ 種類（buff / dot / react）に関係なく効くので、_fill_* ではなくここで写す。
	#   max_stack と同じ扱い。
	# ⚠ ロード時検証（E108〜E113）が守っているので通常は赤にならない。二重に守る。
	# ⚠ duplicate(true) で複製する（_fill_react と同じ理由）。
	if host == SkillSchema.HOST_POINT:
		var raw_zone: Variant = effect.get(SkillSchema.FIELD_ZONE, null)
		if not (raw_zone is Dictionary) or (raw_zone as Dictionary).is_empty():
			push_error("[StatusRegistry] host: point なのに zone{} が無い (status_id=%s)" % status_id)
			return false
		var zone: Dictionary = (raw_zone as Dictionary).duplicate(true)
		if float(zone.get(SkillSchema.ZONE_RADIUS, 0.0)) <= 0.0:
			push_error("[StatusRegistry] zone.radius が正でない (status_id=%s)" % status_id)
			return false
		if not (str(zone.get(SkillSchema.ZONE_TEAM, "")) in SkillSchema.ZONE_TEAMS_KNOWN):
			push_error("[StatusRegistry] zone.team が不明 (status_id=%s)" % status_id)
			return false
		entry["zone"] = zone
	elif effect.has(SkillSchema.FIELD_ZONE):
		push_error("[StatusRegistry] zone{} は host: point にしか書けない (status_id=%s)" % status_id)
		return false

	# --- 6-2. 条件（毎フレーム評価する発火源・PLAN 10章） ---
	if not _fill_condition(entry, effect):
		return false

	# --- 6-3. 状態付与の介入点（PLAN 11-1）。免疫・CC耐性・デバフ無効はここ ---
	#
	# ⚠ ここまで状態を1つも触っていない。弾くならこの位置（CLAUDE.md 6番）。
	# ⚠ 「付けさせない」であって「付けてから剥がす」ではない。登録してから消すと
	#   status_add がログに出て「付いたのに消えた」と読める。
	# ⚠ 弾くのは host: unit だけ。battle / point は宿主が居らず、誰の免疫が
	#   効くのか決まらない。
	if host == SkillSchema.HOST_UNIT:
		var block_ctx: Dictionary = {
			"status_id": status_id,
			"kind": kind,
			"host_unit_id": host_unit.unit_id,
			"blocked": false,
			"blocked_by": "",
		}
		_step_status_block(block_ctx)
		if bool(block_ctx["blocked"]):
			BattleLog.log_intervene(
				"status", str(block_ctx["host_unit_id"]), status_id, str(block_ctx["blocked_by"])
			)
			return false

	# --- 6-4. スタックの上限（PLAN 13-2・段階3の後半④） ---
	#
	# ⚠ ここも「状態を1つも触っていない」うちに弾く（CLAUDE.md 6番）。
	# ⚠ 上限に達したら積まない。古いものを捨てて積み直さないこと。捨てる形に
	#   すると寿命が置き直され続けて実質無限になる。
	# ⚠ 上限が無いと stack:<状態ID> の閾値が一度真になったら二度と偽に戻らない
	#   （EXEC_SKILL_CONDITION.md §2-3）。ロード時検証 E69 と二重に守る。
	# ⚠ ログを出さない。上限に達しているのは正常系（正常系に警告を付けない）。
	if stack == SkillSchema.STACK_INDEPENDENT and host == SkillSchema.HOST_UNIT:
		var max_stack: int = int(entry.get(SkillSchema.FIELD_MAX_STACK, 0))
		if max_stack > 0 and count_stacks(host_unit.unit_id, status_id) >= max_stack:
			return false

	# --- 7. ここまで状態を1つも触っていない。ここで初めて入れる ---
	#
	# ⚠ 同一性のキーは (宿主, status_id, 付与者) の3つ組（決定1-5）。
	#   status_id だけにすると、2人の僧侶が同じバフを配ったとき片方が消える。
	if stack == SkillSchema.STACK_REFRESH:
		var index: int = _find_same(entry)
		if index >= 0:
			# 寿命も値も、新しいもので丸ごと置き直す。差分更新しない。
			entry["instance_id"] = int(_entries[index].get("instance_id", 0))
			_entries[index] = entry
		else:
			_entries.append(entry)
	else:
		# independent … 上限は 6-4 で既に見ている（ここで見ないこと。2箇所になる）
		_entries.append(entry)

	# 付いた時点で1回だけ評価する。⚠ 位置が要件（組み直しより前）。
	#   ここを省いて既定の true のままにすると、条件が偽の状態が「1フレームだけ真」
	#   として付く。補正が1フレーム乗って次のフレームで剥がれるので、数字がちらつく
	#   だけでエラーは1つも出ない。
	entry["active"] = _eval_one(entry)

	if host == SkillSchema.HOST_UNIT:
		_rebuild_unit_mods(str(entry.get("host_unit_id", "")))

	# 検証用のログ（EXEC_BATTLE_LOG.md）。⚠ ここ（入れ終わったあと）で出す。
	#   関数の先頭に置くと、弾かれた効果まで「付いた」ことになる。
	BattleLog.log_status_add(
		status_id, kind, str(entry.get("host_unit_id", "")),
		str(entry.get("source_unit_id", "")), life, duration_sec
	)
	# ⚠ 付いた時点の真偽を出しておくこと（EXEC_SKILL_CONDITION.md §3-1(c)）。
	#   出さないと「一度も真にならなかった」のか「最初から常に真だった」のかが
	#   ログから区別できない。どちらも無音の事故で、この回で一番あり得る。
	if not (entry.get("condition", {}) as Dictionary).is_empty():
		BattleLog.log_condition(
			status_id, str(entry.get("host_unit_id", "")), bool(entry.get("active", true)), "add"
		)
	return true


func _make_entry(
		kind: String, host: String, status_id: String, stack: String, life: String,
		duration_sec: float, source: BattleUnit, host_unit: BattleUnit
) -> Dictionary:
	var instance_id: int = _next_instance_id
	_next_instance_id += 1

	# host: point は座標に紐づく。宿主が居なければ付与者の位置に置く。
	# ⚠ 参照する仕組み（条件・購読）は段階3の後半。今は置くだけ。
	var host_x: float = 0.0
	if host == SkillSchema.HOST_POINT:
		host_x = host_unit.x if host_unit != null else source.x

	return {
		"instance_id": instance_id,
		"status_id": status_id,
		"kind": kind,
		"host": host,
		"host_unit_id": host_unit.unit_id if host_unit != null else "",
		"host_x": host_x,
		"source_unit_id": source.unit_id,
		"stack": stack,
		# independent の上限（PLAN 13-2）。⚠ refresh の件にも 0 で必ず持たせる。
		#   持たない件があると query() が黙って外す（"active" と同じ理由）。
		SkillSchema.FIELD_MAX_STACK: 0,
		"life": life,
		"duration_sec": duration_sec,
		# 寿命も周期も、この1本の時計から引く。
		# ⚠ 別々のカウントダウンを2本持たないこと。浮動小数の誤差が別々に積もり、
		#   「duration と interval が同時に切れるはずのフレーム」で最後の1発が
		#   落ちる。数字が少しずれるだけなのでエラーも出ず気づけない。
		"elapsed": 0.0,
		"stat": "",
		"value": 0,
		"damage_effect": {},
		"interval_sec": 0.0,
		"fires_done": 0,
		"fires_total": 0,
		# 購読（kind: react）。{ "event": String, "effects": Array }。
		# ⚠ 中身を読むのは SkillRuntime。器はここに置くだけで、event を解釈しない。
		"react": {},
		# 条件（PLAN 10章の3つ目の発火源）。空なら「条件なし＝常に有効」。
		# 形は { "source", "of", "op", "value", ("status_id") }（EXEC_SKILL_CONDITION.md §2-1）。
		"condition": {},
		# 条件が今どうか。⚠ 書くのは add() と _eval_conditions() の2箇所だけ。
		#   読む側（補正の組み直し・周期発火・購読）は、この bool を読むだけにすること。
		#   3箇所で別々に条件を評価すると、片方だけ古い真偽で動く（無音）。
		# ⚠ 条件を持たない件も必ず持つこと。持たない件があると
		#   query({"active": true}) がその件だけ黙って外す（query は文字列で比べる）。
		"active": true,
		# 汎用カウンター（PLAN 13-1）。⚠ 呼び出し元はまだ無い（段階3の後半）。
		"counter": 0,
		# 介入点（PLAN 11-1・段階3の後半③）。buff のときだけ中身が入る。
		# ⚠ 持たない件にも必ず持たせること。持たない件があると query() が
		#   その件だけ黙って外す（"active" の注記と同じ）。
		# 範囲（EXEC_SKILL_AURA.md）。host: point のときだけ中身が入る。
		# ⚠ 持たない件にも必ず持たせること（"active" の注記と同じ。query() が黙って外す）。
		"zone": {},
		# 今このユニットが範囲の中に居るか。⚠ 書くのは _eval_zones() の1箇所だけ。
		"inside": {},
		# 周期の効果を回復にする。⚠ multiplier の符号では分けない。
		"heals": false,
		"on_death": {},
		"block_status": [],
		"heal_taken_pct": 0,
		# ダメージの介入点（EXEC_SKILL_MITIGATION.md）。⚠ 持たない件にも必ず持たせる
		#   （上の "active" と同じ理由。query() がその件だけ黙って外す）。
		"shield_hp": 0,
		"reduction_pct": 0,
		"pierce_pct": 0,
		"crit_always": false,
		"reflect_pct": 0,
		"reflect_flat": 0,
	}


# buff の欄を埋める。
#
# ⚠ stat / value は「書かれているときだけ」必須になる（段階3の後半③で緩めた）。
#   復活・免疫・被回復増減は能力値を動かさないので stat を持たない。
#   代わりに介入の欄（on_death / block_status / heal_taken_pct）を持つ。
# ⚠ どちらも無い buff は false。ロード時検証（E63）と二重に守る。
#   ここを省くと、stat の typo が「介入だけを持つ buff」として黙って通る。
func _fill_buff(entry: Dictionary, effect: Dictionary) -> bool:
	var has_stat: bool = effect.has("stat") or effect.has("value")
	if has_stat:
		var stat_key: String = str(effect.get("stat", ""))
		if not (stat_key in GameManager.get_stat_keys()):
			push_error("[StatusRegistry] buff の stat が10軸に無い: '%s'" % stat_key)
			return false
		# ⚠ hp は禁止。max_hp を計算し直さないため（unit.gd の refresh_derived()）。
		if stat_key == GameStateKeys.STAT_HP:
			push_error("[StatusRegistry] buff の stat に hp は書けない（max_hp を再計算しないため）")
			return false
		# ⚠ MasterDataLoader は数値を float で返す。int() で包む（CLAUDE.md 3番）。
		var value: int = int(effect.get("value", 0))
		if value == 0:
			push_error("[StatusRegistry] buff の value が0（何も起きない状態は書けない）")
			return false
		entry["stat"] = stat_key
		entry["value"] = value

	# 介入点（PLAN 11-1 ＋ EXEC_SKILL_MITIGATION.md）。⚠ duplicate(true) で複製する
	#   （_fill_react と同じ理由。参照で握ると、器が触ったときにマスターごと書き変わる）。
	#
	# ⚠ 欄は intervene{} の中にある（人間の決定2で畳んだ）。⚠ 平置きはロード時検証
	#   （E102）が赤にするので、ここには来ない。⚠ 二重に守るために効果の直下は読まない。
	var has_intervene: bool = false
	var raw_iv: Variant = effect.get(SkillSchema.BUFF_INTERVENE, null)
	if raw_iv != null and not (raw_iv is Dictionary):
		push_error("[StatusRegistry] buff の intervene が Dictionary でない")
		return false
	var effect_iv: Dictionary = (raw_iv as Dictionary) if (raw_iv is Dictionary) else {}

	if effect_iv.has(SkillSchema.BUFF_ON_DEATH):
		var raw_death: Variant = effect_iv.get(SkillSchema.BUFF_ON_DEATH, null)
		if not (raw_death is Dictionary):
			push_error("[StatusRegistry] buff の on_death が Dictionary でない")
			return false
		# ⚠ 0 以下・1 超は弾く。0 だと復活した瞬間にまた死に、走査が毎フレーム回る。
		var ratio: float = float((raw_death as Dictionary).get("revive_hp_ratio", 0.0))
		if ratio <= 0.0 or ratio > 1.0:
			push_error("[StatusRegistry] on_death.revive_hp_ratio が 0 より大きく 1 以下でない: %f" % ratio)
			return false
		entry["on_death"] = (raw_death as Dictionary).duplicate(true)
		has_intervene = true

	if effect_iv.has(SkillSchema.BUFF_BLOCK_STATUS):
		var raw_block: Variant = effect_iv.get(SkillSchema.BUFF_BLOCK_STATUS, null)
		if not (raw_block is Array) or (raw_block as Array).is_empty():
			push_error("[StatusRegistry] buff の block_status が配列でない、または空")
			return false
		entry["block_status"] = (raw_block as Array).duplicate(true)
		has_intervene = true

	if effect_iv.has(SkillSchema.BUFF_HEAL_TAKEN_PCT):
		var pct: int = int(effect_iv.get(SkillSchema.BUFF_HEAL_TAKEN_PCT, 0))
		if pct == 0:
			push_error("[StatusRegistry] buff の heal_taken_pct が0（何も起きない介入は書けない）")
			return false
		entry["heal_taken_pct"] = pct
		has_intervene = true

	# ダメージの介入点（EXEC_SKILL_MITIGATION.md）。
	#
	# ⚠ 上限（REDUCTION_PCT_MAX / PIERCE_PCT_MAX）はここで掛けない。合計してから
	#   掛ける（1件ずつ丸めると、40+40 が 80 ではなく 80 のままか 95 かで揺れる）。
	#   掛けるのは damage_taken_pct() / pierce_pct() の1箇所（下）。
	for field: String in [
		SkillSchema.INTERVENE_REDUCTION_PCT, SkillSchema.INTERVENE_PIERCE_PCT,
		SkillSchema.INTERVENE_REFLECT_PCT, SkillSchema.INTERVENE_REFLECT_FLAT,
	]:
		if effect_iv.has(field):
			var v: int = int(effect_iv.get(field, 0))
			if v < 1:
				push_error("[StatusRegistry] buff の %s が 1 未満（何も起きない介入は書けない）" % field)
				return false
			entry[field] = v
			has_intervene = true

	if effect_iv.has(SkillSchema.INTERVENE_CRIT_ALWAYS):
		# ⚠ false は持たせない。持たせると「付いているのに効かない」件が器に残り、
		#   query() で数えたときに数が合わなくなる（W14 が書き忘れを黄で言う）。
		if bool(effect_iv.get(SkillSchema.INTERVENE_CRIT_ALWAYS, false)):
			entry[SkillSchema.INTERVENE_CRIT_ALWAYS] = true
			has_intervene = true

	# ⚠ シールドの残量は counter に入れる（汎用カウンター・呼び出し元がゼロだった）。
	#   2本目の残量の置き場を作らない。
	if effect_iv.has(SkillSchema.INTERVENE_SHIELD_HP):
		var shield: int = int(effect_iv.get(SkillSchema.INTERVENE_SHIELD_HP, 0))
		if shield < 1:
			push_error("[StatusRegistry] buff の shield_hp が 1 未満")
			return false
		entry[SkillSchema.INTERVENE_SHIELD_HP] = shield
		entry["counter"] = shield
		has_intervene = true

	if not has_stat and not has_intervene:
		push_error("[StatusRegistry] buff に stat / value も介入の欄も無い（何も起きない状態は書けない）")
		return false
	return true


# 購読を1件持たせる（PLAN 10章）。
#
# ⚠ ロード時検証（E46〜E49）が守っているので通常は赤にならない。二重に守る。
# ⚠ duplicate(true) で複製すること。マスターの辞書を参照で握ると、
#   撃つ側が effects[] を触ったときにマスターごと書き変わる。
# ⚠ ここで event を解釈しない。器は「購読を持っている」だけ（KIND_REACT の注記）。
func _fill_react(entry: Dictionary, effect: Dictionary) -> bool:
	var raw: Variant = effect.get("react", null)
	if not (raw is Dictionary):
		push_error("[StatusRegistry] react に react{} が無い")
		return false
	var react: Dictionary = raw as Dictionary

	var event_name: String = str(react.get("event", ""))
	if not (event_name in SkillSchema.EVENTS_KNOWN):
		push_error("[StatusRegistry] react.event が無い、または不明: '%s'" % event_name)
		return false

	var raw_effects: Variant = react.get("effects", null)
	if not (raw_effects is Array) or (raw_effects as Array).is_empty():
		push_error("[StatusRegistry] react.effects が無い、配列でない、または空")
		return false

	entry["react"] = {
		"event": event_name,
		"effects": (raw_effects as Array).duplicate(true),
	}
	return true


# 条件を1件持たせる（PLAN 10章の3つ目の発火源）。
#
# ⚠ 条件が無いのは正常系。true を返して何もしない（既定の空辞書＝常に有効）。
# ⚠ ロード時検証（E55〜E62）が守っているので通常は赤にならない。二重に守る。
# ⚠ duplicate(true) で複製すること（_fill_react と同じ理由）。マスターの辞書を
#   参照で握ると、器が触ったときにマスターごと書き変わる。
# ⚠ ここで真偽を評価しない。評価するのは _eval_one() の1本だけ。
func _fill_condition(entry: Dictionary, effect: Dictionary) -> bool:
	if not effect.has("condition"):
		return true

	var raw: Variant = effect.get("condition", null)
	if not (raw is Dictionary):
		push_error("[StatusRegistry] condition が Dictionary でない")
		return false
	var cond: Dictionary = raw as Dictionary

	var source: String = str(cond.get("source", ""))
	if not (source in SkillSchema.condition_sources()):
		push_error("[StatusRegistry] condition.source が無い、または不明: '%s'" % source)
		return false
	if not (str(cond.get("of", "")) in SkillSchema.COND_OF_KNOWN):
		push_error("[StatusRegistry] condition.of が無い、または不明: '%s'" % str(cond.get("of", "")))
		return false
	if not (str(cond.get("op", "")) in SkillSchema.COND_OPS_KNOWN):
		push_error("[StatusRegistry] condition.op が無い、または不明: '%s'" % str(cond.get("op", "")))
		return false
	if not cond.has("value"):
		push_error("[StatusRegistry] condition.value が無い")
		return false

	# ⚠ ここの status_id は「見たい相手の状態のID」で、効果の status_id とは別物。
	if source == SkillSchema.COND_SOURCE_STATUS_HAS:
		if str(cond.get("status_id", "")) == "":
			push_error("[StatusRegistry] condition.source: 'status_has' に status_id が無い")
			return false
	elif cond.has("status_id"):
		push_error("[StatusRegistry] condition.status_id は source: 'status_has' のときだけ書ける")
		return false

	# ⚠ 宿り先は unit か point（EXEC_SKILL_AURA.md で point を開けた）。
	#
	# ⚠ point の条件は「オーラそのものが働いているか」であって、範囲の内外ではない。
	#   内外は inside（対ごと）が持ち、条件は active（1件につき1つ）が持つ。
	#   両方真のときだけ効く（_applies_to）。
	# ⚠ point には宿主が居ないので of: host は解けない。of: source だけ許す。
	#   許してしまうと _eval_one() が毎フレーム null を引いて常に偽になり、
	#   「オーラが一度も効かない」が無音で起きる。
	var host_kind: String = str(entry.get("host", ""))
	if host_kind == SkillSchema.HOST_POINT:
		if str(cond.get("of", "")) != SkillSchema.COND_OF_SOURCE:
			push_error("[StatusRegistry] host: point の condition は of: 'source' だけ（宿主が居ない）")
			return false
	elif host_kind != SkillSchema.HOST_UNIT:
		push_error("[StatusRegistry] condition は host: 'unit' か 'point' にしか書けない: '%s'" % host_kind)
		return false

	entry["condition"] = cond.duplicate(true)
	return true


func _fill_dot(entry: Dictionary, effect: Dictionary, duration_sec: float, life: String) -> bool:
	var interval_sec: float = float(effect.get("interval_sec", 0.0))
	if interval_sec <= 0.0:
		push_error("[StatusRegistry] dot の interval_sec が正でない")
		return false
	if not effect.has("scale_from"):
		push_error("[StatusRegistry] dot に scale_from が無い（damage と同じく必須）")
		return false
	# 周期の効果を回復にする（EXEC_SKILL_AURA.md）。⚠ attack_type は書けない（E114）。
	var heals: bool = bool(effect.get(SkillSchema.FIELD_HEALS, false))
	entry["heals"] = heals
	if not heals:
		if not (str(effect.get("attack_type", "")) in SkillSchema.attack_types_known()):
			push_error("[StatusRegistry] dot の attack_type が不明: '%s'" % str(effect.get("attack_type", "")))
			return false

	entry["interval_sec"] = interval_sec
	# 端数は切り捨て（決定1-4）。総ダメージが multiplier × floor(duration/interval)
	# で暗算できる。⚠ 割り切れない組み合わせは MasterDataLoader が黄で言う。
	if life == LIFE_SEC:
		entry["fires_total"] = int(floor(duration_sec / interval_sec))
	else:
		entry["fires_total"] = FIRES_UNLIMITED

	# 発火のたびに resolve() へ渡す実効効果。
	# ⚠ skills.json に書ける欄しか含めない（PLAN 7-3 の歯止め）。
	# ⚠ DoT 専用のダメージ計算を作らない（PLAN 11-0・式を2箇所に書かない）。
	# ⚠ heals: true なら type: heal を合成する。効果の種類を新しく足さないこと
	#   （EFFECT_TYPES_* の一覧が全部増える）。resolve() は type で分岐するので通る。
	# ⚠ heal には attack_type を入れない（回復は防御を見ない）。
	if heals:
		entry["damage_effect"] = {
			"type": SkillSchema.EFFECT_HEAL,
			"multiplier": float(effect.get("multiplier", 0.0)),
			"scale_from": effect.get("scale_from", null),
		}
	else:
		entry["damage_effect"] = {
			"type": SkillSchema.EFFECT_DAMAGE,
			"multiplier": float(effect.get("multiplier", 0.0)),
			"attack_type": str(effect.get("attack_type", "")),
			"scale_from": effect.get("scale_from", null),
		}
	return true


# 同一性のキー（宿主・status_id・付与者）が一致する要素の位置。無ければ -1。
func _find_same(entry: Dictionary) -> int:
	var index: int = 0
	for other: Dictionary in _entries:
		var hit: bool = (
			str(other.get("host_unit_id", "")) == str(entry.get("host_unit_id", ""))
			and str(other.get("status_id", "")) == str(entry.get("status_id", ""))
			and str(other.get("source_unit_id", "")) == str(entry.get("source_unit_id", ""))
		)
		if hit:
			return index
		index += 1
	return -1


# ============================================================
# 進める
# ============================================================

# 毎フレーム。⚠ 順番が要件。
#   1. 宿主が死んだ／居なくなった状態を捨てる
#   2. 時計を進める
#   3. 条件を評価する（active の更新）
#   4. 周期発火（dot）
#   5. 寿命が切れたものを捨てる
#   6. 変わったユニットの補正を組み直す
#
# ⚠ 4を5より先にやること。duration 4秒 × interval 2秒 は最後の発火と
#   寿命切れが同じフレームに来る。逆順だと最後の1発が黙って消え、
#   総ダメージが暗算と合わなくなる。
#
# ⚠ 3を4より先にやること。逆順だと、条件が偽になったフレームに DoT が
#   1発だけ余計に出る。1発なので数字を見ても気づけない。
func tick(delta: float) -> void:
	if _entries.is_empty():
		return

	# unit_id -> true。補正を組み直す必要があるユニット。
	var touched: Dictionary = {}

	_drop_dead_hosts(touched)
	if _entries.is_empty():
		_rebuild_touched(touched)
		return

	# 2. 時計は1本。寿命も周期もここから引く。
	for entry: Dictionary in _entries:
		entry["elapsed"] = float(entry.get("elapsed", 0.0)) + delta

	# ⚠ 範囲は条件より前。条件が inside を読む形を将来足せるようにしておく。
	#   逆にすると、入った同じフレームの条件が1フレーム古い inside を読む。
	_eval_zones(touched)
	_eval_conditions(touched)

	var results: Array = []
	_fire_intervals(results)
	_expire(touched)
	_rebuild_touched(touched)

	if not results.is_empty():
		effects_applied.emit(results)


# 宿主が死んだ／居なくなった状態を捨てる（決定1-7）。
#
# ⚠ 警告を出さない（正常系）。
# ⚠ 見るのは宿主だけ。付与者の生死は見ない（PLAN 7-2）。
#   SkillRuntime._drop_dead_users() をここにコピーしないこと。あちらは使用者を見る。
# ⚠ 死亡を知らせるシグナルが無いので毎フレーム走査する。件数は多くても数件。
func _drop_dead_hosts(touched: Dictionary) -> void:
	var rest: Array = []
	for entry: Dictionary in _entries:
		if str(entry.get("host", "")) != SkillSchema.HOST_UNIT:
			rest.append(entry)
			continue
		var host: BattleUnit = _find_unit(str(entry.get("host_unit_id", "")))
		if host != null and host.is_alive():
			rest.append(entry)
			continue
		# ⚠ 死んだが、死亡の介入点をまだ通していない → このフレームは捨てない。
		#   捨てると、通常攻撃で死んだ相手の復活が、走査（BattleController の
		#   勝敗判定の直前）に着く前に消える。この関数は tick() の先頭で走り、
		#   走査より先に通るため（EXEC_SKILL_INTERVENTION.md §1-1）。
		# ⚠ 走査を tick() の前に動かしても直らない。DoT で死ぬ経路は tick() の
		#   中（_fire_intervals）なので、今度はそちらが1フレーム遅れて
		#   次のフレームのここに食われる。鏡写しに壊れるだけ。
		# ⚠ 介入点が処理済みの印を付けた次のフレームに、いつもどおり捨てる。
		if host != null and not host.death_handled:
			rest.append(entry)
			continue
		touched[str(entry.get("host_unit_id", ""))] = true
		# ⚠ ここを出さないと「宿主が死んで消えた」が無音になり、status_add だけが
		#   残って寿命の追跡が切れる。why で _expire() と区別する。
		BattleLog.log_status_end(
			str(entry.get("status_id", "")), str(entry.get("host_unit_id", "")), "host_dead"
		)
	_entries = rest


# 条件を評価して active を更新する（PLAN 10章の3つ目の発火源）。
#
# ⚠ この回の決定は「真である間だけ効く」。真になった瞬間に別の状態を add() しない。
#   混ぜると「剥がれないバフ」と「二重に乗るバフ」が同時に出る（NEXT_STEPS 2-1）。
#
# ⚠ 真偽が変わった buff の宿主を touched に入れること。入れないと、状態の配列は
#   正しいのに能力値だけ古いまま残る。エラーも出ず、F3 パネルの数字も
#   もっともらしいので気づけない（clear_all() で踏んだのと同じ形）。
#
# ⚠ ログは「変わったとき」だけ。毎フレーム出すと1戦で数万行になる
#   （位置・移動を出さないのと同じ理由・EXEC_BATTLE_LOG.md）。
func _eval_conditions(touched: Dictionary) -> void:
	for entry: Dictionary in _entries:
		# ⚠ 条件を持たない件はここで抜ける。今までと同じコストに保つ。
		if (entry.get("condition", {}) as Dictionary).is_empty():
			continue
		var was: bool = bool(entry.get("active", true))
		var now: bool = _eval_one(entry)
		if now == was:
			continue
		entry["active"] = now
		# 補正に効くのは buff だけ。dot / react は組み直しに関係しない。
		# ⚠ point（オーラ）は中に居る全員を積む。宿主1体だけ積む形にすると、
		#   条件が偽になってもオーラの補正が誰からも剥がれない（エラーは出ない）。
		if str(entry.get("kind", "")) == KIND_BUFF:
			_touch_affected(entry, touched)
		BattleLog.log_condition(
			str(entry.get("status_id", "")), str(entry.get("host_unit_id", "")), now, "change"
		)


# 「この状態はこのユニットに効いているか」（EXEC_SKILL_AURA.md §0-1 の1）。
#
# 【なぜこの1本に寄せるか】`host == HOST_UNIT and host_unit_id == id and active` という
# 同じ3行が、補正・周期発火・介入点の問い合わせに合計10箇所あった。host: point を
# 足すとき1つ忘れると「オーラなのに介入点だけ効かない」という無音の欠けになる
# （段階6で _find_unit() の複製4本のうち3本を忘れたのと同じ形）。
# ⚠ 新しい host を足したら、直すのはこの関数だけにすること。
#
# ⚠ active（条件）と inside（範囲）は両方真のときだけ効く。掛け合わせないと、
#   condition{} が host: point でだけ黙って無視される。
func _applies_to(entry: Dictionary, unit_id: String) -> bool:
	if not bool(entry.get("active", true)):
		return false
	var host: String = str(entry.get("host", ""))
	if host == SkillSchema.HOST_UNIT:
		return str(entry.get("host_unit_id", "")) == unit_id
	if host == SkillSchema.HOST_POINT:
		return bool((entry.get("inside", {}) as Dictionary).get(unit_id, false))
	# host: battle は読む側がまだ無い（宿題）。誰にも効かない。
	return false


# この状態が今 効いている相手を touched に積む。
#
# ⚠ 「補正を組み直す相手」を決める唯一の場所。host: unit は宿主1体、
#   host: point は中に居る全員。⚠ 宿主だけ積む形にすると、オーラの条件が
#   偽になっても寿命が切れても、補正が誰からも剥がれない（エラーは出ない）。
func _touch_affected(entry: Dictionary, touched: Dictionary) -> void:
	var host: String = str(entry.get("host", ""))
	if host == SkillSchema.HOST_UNIT:
		touched[str(entry.get("host_unit_id", ""))] = true
		return
	if host == SkillSchema.HOST_POINT:
		for id in (entry.get("inside", {}) as Dictionary).keys():
			touched[str(id)] = true


# 範囲（zone{}）の出入りを判定する。⚠ inside を書くのはこの1箇所だけ。
#
# ⚠ 3箇所で別々に距離を測らないこと。既存の active と同じ設計
#   （書くのは1箇所・読む側は _applies_to() を通すだけ）。
# ⚠ 出入りしたユニットは touched に積む。積まないと、範囲に入っただけでは
#   補正の組み直しが走らず「入ったのに強くならない」になる（エラーは出ない）。
# ⚠ 追従（follow）はここで host_x を更新する。付与者が死んだら更新を止める
#   （最後の位置で固定・人間が見ていない決め4）。止め忘れると死者の x を読み続ける。
func _eval_zones(touched: Dictionary) -> void:
	for entry: Dictionary in _entries:
		var zone: Dictionary = entry.get("zone", {}) as Dictionary
		if zone.is_empty():
			continue

		# 追従。⚠ 付与者が居ない／死んでいるなら最後の位置のまま。
		if bool(zone.get(SkillSchema.ZONE_FOLLOW, false)):
			var owner: BattleUnit = _find_unit(str(entry.get("source_unit_id", "")))
			if owner != null and owner.is_alive():
				entry["host_x"] = owner.x

		var center: float = float(entry.get("host_x", 0.0))
		var radius: float = float(zone.get(SkillSchema.ZONE_RADIUS, 0.0))
		var was: Dictionary = entry.get("inside", {}) as Dictionary
		var now: Dictionary = {}

		for unit in _all_units():
			if not (unit is BattleUnit):
				continue
			var u: BattleUnit = unit as BattleUnit
			if not u.is_alive():
				continue
			if not _zone_team_matches(entry, u):
				continue
			# ⚠ 1次元（既存の area と同じ）。ここだけ2次元にすると radius の意味が食い違う。
			if absf(u.x - center) > radius:
				continue
			now[u.unit_id] = true

		# 出入りしたものだけログと組み直しに回す。⚠ 毎フレーム出すと1戦で数万行。
		for id in now.keys():
			if not was.has(id):
				touched[str(id)] = true
				BattleLog.log_zone(str(entry.get("status_id", "")), str(id), "enter")
		for id in was.keys():
			if not now.has(id):
				touched[str(id)] = true
				BattleLog.log_zone(str(entry.get("status_id", "")), str(id), "leave")

		entry["inside"] = now


# zone.team を「付与者から見て」解く。
# ⚠ ここだけ「味方＝プレイヤー側」にしないこと。敵が置いた毒沼が敵を焼く。
func _zone_team_matches(entry: Dictionary, unit: BattleUnit) -> bool:
	var team: String = str((entry.get("zone", {}) as Dictionary).get(SkillSchema.ZONE_TEAM, ""))
	if team == SkillSchema.ZONE_TEAM_ALL:
		return true
	var owner: BattleUnit = _find_unit(str(entry.get("source_unit_id", "")))
	if owner == null:
		return false
	if team == SkillSchema.ZONE_TEAM_ALLY:
		return unit.team == owner.team
	return unit.team != owner.team


# 味方・敵・召喚を1本で回す。⚠ 配列を足したらここも直す（BattleSession が正）。
func _all_units() -> Array:
	if _session == null:
		return []
	var list: Array = []
	list.append_array(_session.party_units)
	list.append_array(_session.enemy_units)
	list.append_array(_session.summon_units)
	return list


# 条件1件ぶんの真偽。条件が無ければ常に true。
#
# ⚠ SkillResolver._scale_variable() を呼ばないこと。あちらは user と target の
#   2者を取る契約で、状態には1者（宿主か付与者）しか居ない。呼べる形にすると
#   of の語彙が2つの意味を持ち、「target って誰？」が無音でズレる。
# ⚠ 見る相手が居なければ false。警告を出さない（宿主が死ぬフレームに必ず通る正常系）。
func _eval_one(entry: Dictionary) -> bool:
	var cond: Dictionary = entry.get("condition", {}) as Dictionary
	if cond.is_empty():
		return true

	var of: String = str(cond.get("of", ""))
	var unit_id: String = ""
	if of == SkillSchema.COND_OF_HOST:
		unit_id = str(entry.get("host_unit_id", ""))
	elif of == SkillSchema.COND_OF_SOURCE:
		unit_id = str(entry.get("source_unit_id", ""))
	else:
		push_error("[StatusRegistry] condition.of が不明: '%s'" % of)
		return false

	var unit: BattleUnit = _find_unit(unit_id)
	if unit == null:
		return false

	var left: float = _condition_value(cond, unit)
	var right: float = float(cond.get("value", 0.0))
	match str(cond.get("op", "")):
		SkillSchema.COND_OP_LT:
			return left < right
		SkillSchema.COND_OP_LTE:
			return left <= right
		SkillSchema.COND_OP_GT:
			return left > right
		SkillSchema.COND_OP_GTE:
			return left >= right
		SkillSchema.COND_OP_EQ:
			return is_equal_approx(left, right)
	push_error("[StatusRegistry] condition.op が不明: '%s'" % str(cond.get("op", "")))
	return false


# 条件の左辺。⚠ 語彙は SkillSchema.condition_sources() が唯一の正。
#   ここに2本目の一覧を作らないこと。
func _condition_value(cond: Dictionary, unit: BattleUnit) -> float:
	var source: String = str(cond.get("source", ""))

	# その状態が付いているか。⚠ 0 か 1 しか返さない。
	#   ⚠ 件数は status_count ではなく source: "stack" が返す（段階3の後半④で
	#   independent に上限（max_stack）を必須にしたので、閾値が一度真になったら
	#   二度と偽に戻らない問題が消えた。上限の必須をやめるとこの前提が崩れる）。
	if source == SkillSchema.COND_SOURCE_STATUS_HAS:
		var found: bool = has({
			"host": SkillSchema.HOST_UNIT,
			"host_unit_id": unit.unit_id,
			"status_id": str(cond.get("status_id", "")),
		})
		return 1.0 if found else 0.0

	# ⚠ この枝は SkillResolver._scale_variable() と中身を揃えること。
	#   語彙は scale_sources() の1本しか無いので、片方に足し忘れると
	#   「damage では効くのに condition では0」という壊れ方をする（赤は出る）。
	match source:
		SkillSchema.SCALE_HP_CURRENT:
			return float(unit.hp)
		SkillSchema.SCALE_HP_LOST:
			return float(unit.max_hp - unit.hp)
		SkillSchema.SCALE_HP_RATIO:
			return 0.0 if unit.max_hp <= 0 else float(unit.hp) / float(unit.max_hp)
		SkillSchema.SCALE_HP_LOST_RATIO:
			return 0.0 if unit.max_hp <= 0 else 1.0 - float(unit.hp) / float(unit.max_hp)
		SkillSchema.SCALE_ELAPSED_SEC:
			# ⚠ of を読まない（戦闘全体の値）。SCALE_SOURCES_NO_OF の一員。
			return 0.0 if _session == null else _session.elapsed_sec
		SkillSchema.SCALE_WAVE_INDEX:
			# ⚠ 1 始まり（"wave_index >= 2" で「2波目以降」）。
			return 0.0 if _session == null else float(_session.current_wave)
		SkillSchema.SCALE_ALIVE_ALLY:
			# ⚠ 「その unit から見た」味方。絶対（party 固定）にしない。
			return 0.0 if _session == null else float(_session.get_alive_units(unit.team).size())
		SkillSchema.SCALE_ALIVE_ENEMY:
			if _session == null:
				return 0.0
			var foe: String = (
				BattleUnit.TEAM_ENEMY if unit.team == BattleUnit.TEAM_PARTY else BattleUnit.TEAM_PARTY
			)
			return float(_session.get_alive_units(foe).size())
		SkillSchema.SCALE_STACK:
			# ⚠ status_id は「数えたい相手の状態のID」。E71 が空を弾いている。
			return float(count_stacks(unit.unit_id, str(cond.get("status_id", ""))))

	if source in GameManager.get_stat_keys():
		return float(unit.get_stat(source))

	push_error("[StatusRegistry] condition.source が不明: '%s'" % source)
	return 0.0


# 周期発火。⚠ 発火する回数は elapsed から引く。カウントダウンを別に持たない。
func _fire_intervals(results: Array) -> void:
	var rest: Array = []
	for entry: Dictionary in _entries:
		if str(entry.get("kind", "")) != KIND_DOT:
			rest.append(entry)
			continue
		# 当てる相手を決める。
		#
		# ⚠ host: unit は宿主1体。host: point は「今 範囲の中に居る全員」（毒沼・回復地帯）。
		#   ⚠ inside を書くのは _eval_zones() の1箇所だけで、ここでは読むだけ。
		# ⚠ host: battle は読む側がまだ無い（宿題）。飛ばす。
		var entry_host: String = str(entry.get("host", ""))
		var target_ids: Array = []
		if entry_host == SkillSchema.HOST_UNIT:
			target_ids.append(str(entry.get("host_unit_id", "")))
		elif entry_host == SkillSchema.HOST_POINT:
			for id in (entry.get("inside", {}) as Dictionary).keys():
				target_ids.append(str(id))
		else:
			rest.append(entry)
			continue

		# ⚠ 付与者が死んでいても止めない（PLAN 7-2）。死者も session に残るので
		#   能力値は読める。session から消えたときだけ捨てる（正常系・警告なし）。
		var source: BattleUnit = _find_unit(str(entry.get("source_unit_id", "")))
		if source == null:
			continue

		var interval_sec: float = float(entry.get("interval_sec", 0.0))
		var elapsed: float = float(entry.get("elapsed", 0.0))
		var total: int = int(entry.get("fires_total", 0))

		# 条件が偽の間は発火しない（EXEC_SKILL_CONDITION.md §3-1(h)）。
		#
		# 【決定】時計は進める。偽の間に来た発火は捨てる。寿命は書いたとおりに切れる。
		# ⚠ elapsed を止める案は採らない。「時計は1本」という不変条件
		#   （_make_entry() の注記）が崩れ、寿命まで一緒に延びる。
		# ⚠ fires_done を elapsed に追いつかせること。追いつかせないと、真に戻った
		#   瞬間に下の while が回り、偽だった間ぶんを一気に連射する。総ダメージが
		#   暗算と合わなくなるだけで、エラーは1つも出ない。
		if not bool(entry.get("active", true)):
			var skipped: int = int(floor(elapsed / interval_sec))
			if int(entry.get("fires_done", 0)) < skipped:
				entry["fires_done"] = skipped
			rest.append(entry)
			continue

		# ⚠ while にするのは速度8倍で1フレームに複数回跨ぐため。if だと発火が落ちる。
		# ⚠ ループの中で fires_done を必ず増やすこと。増やさないと固まる。
		while (total == FIRES_UNLIMITED or int(entry.get("fires_done", 0)) < total) \
				and elapsed >= float(int(entry.get("fires_done", 0)) + 1) * interval_sec:
			entry["fires_done"] = int(entry.get("fires_done", 0)) + 1
			var one: Dictionary = { "effects": [entry.get("damage_effect", {})] }
			# ⚠ 末尾の true が「これは DoT の発火」の印（EXEC_DAMAGE_POP_COLOR.md）。
			#   表示側は results の is_dot だけを見て色を決める。ここを落とすと
			#   毒のダメージが通常の色で出る（エラーは1つも出ない）。
			# ⚠ 範囲の場合は「今 中に居る全員」に当てる。1体だけに当てると、
			#   毒沼が最初に入った1体しか焼かない（エラーは出ない）。
			# ⚠ target_ids が空なら resolve() は空を返す（誰も中に居ない＝正常系）。
			var fired: Array = SkillResolver.resolve(one, source, _session, target_ids, self, true)
			# 検証用のログ（EXEC_BATTLE_LOG.md）。⚠ この経路は SkillRuntime を
			#   通らないので、ここに差さないと DoT のダメージだけログに出ない。
			BattleLog.log_results(fired, source.unit_id, str(entry.get("status_id", "")))
			for r: Variant in fired:
				results.append(r)

		rest.append(entry)
	_entries = rest


# 寿命が切れたものを捨てる。
# ⚠ until 系（charge_end）は時間で消えない。end_charge() だけが剥がす。
func _expire(touched: Dictionary) -> void:
	var rest: Array = []
	for entry: Dictionary in _entries:
		if str(entry.get("life", "")) != LIFE_SEC:
			rest.append(entry)
			continue
		if float(entry.get("elapsed", 0.0)) < float(entry.get("duration_sec", 0.0)):
			rest.append(entry)
			continue
		# ⚠ point（オーラ）は中に居る全員を積む（_eval_conditions と同じ理由）。
		_touch_affected(entry, touched)
		BattleLog.log_status_end(
			str(entry.get("status_id", "")), str(entry.get("host_unit_id", "")), "expire"
		)
	_entries = rest


# ============================================================
# 介入点（PLAN 11-1・段階3の後半③）
# ============================================================
#
# 割り込む場所は4つ。ダメージだけは SkillResolver 側に受け口がある
# （_step_crit_override / _step_reduction・利用者はまだゼロ）。
# ここに置くのは「状態の付与」と「死亡」の2つ。回復は SkillResolver。
#
# ⚠ 作り方をダメージと揃えること（PLAN 11-1「ブレると4箇所バラバラになる」）。
#   _step_* は ctx: Dictionary を1つ取って書き換える。戻り値で分岐しない。
#   呼ぶ側が ctx の欄を読んで判断する。
# ⚠ どの _step_* も active が偽の件を見ないこと。条件付きの免疫・復活が
#   偽の間に効いてしまう（真である間だけ効く・段階3の後半②の決定）。


# 状態の付与を弾くか（免疫・CC耐性・デバフ無効）。
#
# ctx … { status_id, kind, host_unit_id, blocked, blocked_by }
# 宿主に付いている buff の block_status に status_id が入っていれば弾く。
func _step_status_block(ctx: Dictionary) -> void:
	var incoming: String = str(ctx.get("status_id", ""))
	var host_unit_id: String = str(ctx.get("host_unit_id", ""))
	if incoming == "" or host_unit_id == "":
		return
	for entry: Dictionary in _entries:
		if str(entry.get("kind", "")) != KIND_BUFF:
			continue
		if not _applies_to(entry, host_unit_id):
			continue
		var blocked: Array = entry.get("block_status", []) as Array
		if incoming in blocked:
			ctx["blocked"] = true
			ctx["blocked_by"] = str(entry.get("status_id", ""))
			return


# 死亡に介入するか（復活・HP1で耐える）。
#
# ctx … { unit, revived, revive_hp, by }
# 宿主に付いている buff の on_death を探す。
# ⚠ 最初に見つかった1件で決める。2件目以降は見ない（全消しで両方消えるため、
#   どちらが効いたかを競わせても次の死亡では両方無い）。
func _step_death(ctx: Dictionary) -> void:
	var unit: BattleUnit = ctx.get("unit", null)
	if unit == null:
		return
	for entry: Dictionary in _entries:
		if str(entry.get("kind", "")) != KIND_BUFF:
			continue
		if not _applies_to(entry, unit.unit_id):
			continue
		var on_death: Dictionary = entry.get("on_death", {}) as Dictionary
		if on_death.is_empty():
			continue
		var ratio: float = float(on_death.get("revive_hp_ratio", 0.0))
		if ratio <= 0.0:
			continue
		# ⚠ 最低1。0 だと復活した直後に死に、走査が毎フレーム回る。
		ctx["revived"] = true
		ctx["revive_hp"] = maxi(1, int(floor(float(unit.max_hp) * ratio)))
		ctx["by"] = str(entry.get("status_id", ""))
		return


# 死亡の介入点を1体ぶん通す。介入したら true。
#
# ⚠ 呼ぶのは BattleController._step_deaths() の1箇所だけ（PLAN 11-1）。
#   ダメージを与える各所に2本目の判定を作らないこと。
# ⚠ 順序は「復活の効果が発火 → その後に全消し」（PLAN 14-4）。逆にすると
#   復活を与えていた状態が先に消えて発火しない。
# ⚠ 「1回だけ」はこの全消しが保証する。カウンターを足さないこと（PLAN 14-4）。
# ⚠ CD はリセットしない（PLAN 14-4）。ここで skill_cooldowns を触らないこと。
func resolve_death(unit: BattleUnit) -> bool:
	if unit == null:
		return false
	var ctx: Dictionary = { "unit": unit, "revived": false, "revive_hp": 0, "by": "" }
	_step_death(ctx)
	if not bool(ctx["revived"]):
		return false

	# ⚠ hp を直接書かない。heal() を通す（unit.gd「必ず take_damage / heal 経由」）。
	unit.heal(int(ctx["revive_hp"]))
	BattleLog.log_intervene("death", unit.unit_id, str(ctx["by"]), str(int(ctx["revive_hp"])))
	# バフもデバフも全部消える（PLAN 14-4）。DoT の持ち越しで復活直後に
	# また死ぬ事故が構造的に消える。
	clear_for_unit(unit.unit_id, "revive_clear")
	return true


# ============================================================
# 剥がす
# ============================================================

# 全部捨てる。ウェーブ交代・勝敗確定・リトライで呼ぶ。捨てた件数を返す。
func clear_all() -> int:
	var dropped: int = _entries.size()
	_entries.clear()
	# ⚠ 状態を捨てただけでは補正は消えない。全ユニットぶん組み直す。
	if _session != null:
		for u in _session.party_units:
			if u is BattleUnit:
				_rebuild_unit_mods((u as BattleUnit).unit_id)
		for u in _session.enemy_units:
			if u is BattleUnit:
				_rebuild_unit_mods((u as BattleUnit).unit_id)
	# ⚠ これが無いと、ウェーブ交代で消えた状態の status_add だけがログに残り、
	#   「付いた状態が永久に残っている」ように読める（実測で踏んだ）。
	BattleLog.log_status_clear(dropped)
	return dropped


# その宿主に付いた状態を捨てる。捨てた件数を返す。
#
# why … 空でなければ、捨てた1件ごとに status_end をこの理由で出す。
#   ⚠ 既定は空（無音）。復活の全消し（"revive_clear"）だけが渡す。
#     出さないと、復活した瞬間に消えた状態の status_add がログに残り続け、
#     「付いた状態が永久に残っている」と読める（clear_all() で踏んだのと同じ形）。
func clear_for_unit(unit_id: String, why: String = "") -> int:
	var rest: Array = []
	for entry: Dictionary in _entries:
		var hit: bool = (
			str(entry.get("host", "")) == SkillSchema.HOST_UNIT
			and str(entry.get("host_unit_id", "")) == unit_id
		)
		if not hit:
			rest.append(entry)
			continue
		if why != "":
			BattleLog.log_status_end(str(entry.get("status_id", "")), unit_id, why)
	var dropped: int = _entries.size() - rest.size()
	_entries = rest
	if dropped > 0:
		_rebuild_unit_mods(unit_id)
	return dropped


# until: "charge_end" の状態を剥がす（PLAN 13-3）。捨てた件数を返す。
#
# ⚠ 剥がす相手は「付与者」。チャージしているのは付与者であって宿主ではない。
# ⚠ 正常系なので警告を出さない。
func end_charge(user_id: String) -> int:
	var rest: Array = []
	var touched: Dictionary = {}
	for entry: Dictionary in _entries:
		var hit: bool = (
			str(entry.get("life", "")) == SkillSchema.UNTIL_CHARGE_END
			and str(entry.get("source_unit_id", "")) == user_id
		)
		if not hit:
			rest.append(entry)
			continue
		if str(entry.get("host", "")) == SkillSchema.HOST_UNIT:
			touched[str(entry.get("host_unit_id", ""))] = true
	var dropped: int = _entries.size() - rest.size()
	_entries = rest
	_rebuild_touched(touched)
	return dropped


# ============================================================
# 問い合わせ口（⚠ PLAN 13-1「DLCの幅を決めるのはここ」）
# ============================================================

# 書いたキーだけで絞る。書かないキーは見ない。
#
# ⚠ 「◯◯で絞る関数」を1個ずつ増やさないこと。条件（段階3の後半）が要求するのは
#   「毒が付いた敵に追加」「デバフの数だけ強く」「自分が付けた毒だけ強化」で、
#   全部この1本の引数の違いでしかない。
#
# 絞れるキー … host / host_unit_id / status_id / source_unit_id / kind
func query(filter: Dictionary) -> Array:
	var found: Array = []
	for entry: Dictionary in _entries:
		var ok: bool = true
		for key: Variant in filter:
			if str(entry.get(str(key), "")) != str(filter[key]):
				ok = false
				break
		if ok:
			found.append(entry)
	return found


func count(filter: Dictionary) -> int:
	return query(filter).size()


func has(filter: Dictionary) -> bool:
	return not query(filter).is_empty()


# (宿主, status_id) に積まれている件数。scale_from / condition の
# source: "stack" が唯一の利用者（段階3の後半④）。
#
# ⚠ active が偽の件も数える。「積まれている数」であって「効いている数」ではない。
#   ここを active で絞ると、条件付きの状態のスタック数が条件で揺れて、
#   「積んだのに数が減る」という説明のつかない挙動になる。
# ⚠ has() と別の関数にしてある。has() は真偽しか返さない契約を保つため。
# ⚠ query() を通す。ここで _entries を直接回すと、絞り方が2本になる。
# ⚠ 呼び出し元は SkillResolver._scale_variable() の1箇所。あちらは registry を
#   RefCounted として持つので動的に呼ばれる（count_heal_taken_pct と同じ形）。
func count_stacks(host_unit_id: String, status_id: String) -> int:
	if host_unit_id == "" or status_id == "":
		return 0
	return count({
		"host": SkillSchema.HOST_UNIT,
		"host_unit_id": host_unit_id,
		"status_id": status_id,
	})


# そのユニットが受ける回復の増減（％）の合計。回復の介入点が読む。
#
# ⚠ 合計する（掛け合わせない）。-50 と -30 で -80% であって -65% ではない。
#   stat_mod() と同じ「積み上げは和」に揃えてある（scale_from も和・PLAN 5-5-1）。
# ⚠ active が偽の件は数えない（_step_status_block / _step_death と同じ）。
# ⚠ 呼び出し元は SkillResolver._step_heal_taken() の1箇所。あちらは registry を
#   RefCounted として持つので、この関数は動的に呼ばれる（add() と同じ形）。
func heal_taken_pct(unit_id: String) -> int:
	return _intervene_sum(unit_id, "heal_taken_pct")


# ダメージの介入点が読む問い合わせ（EXEC_SKILL_MITIGATION.md）。
#
# ⚠ 4本とも heal_taken_pct() と同じ形にすること（PLAN 11-1「ブレると4箇所
#   バラバラになる」）。⚠ どれも active が偽の件を数えない。
# ⚠ 合計してから上限を掛ける。1件ずつ丸めない（40+40 が 80 になるべき場面で
#   95 に化ける）。
#
# ⚠ 誰の状態かが欄で違う。読み違えると「効いているのに効かない」になる。
#     殴られた側 … reduction_pct / reflect_pct / reflect_flat / shield_hp
#     殴った側   … pierce_pct / crit_always
func _intervene_sum(unit_id: String, field: String) -> int:
	var total: int = 0
	for entry: Dictionary in _entries:
		if str(entry.get("kind", "")) != KIND_BUFF:
			continue
		if not _applies_to(entry, unit_id):
			continue
		total += int(entry.get(field, 0))
	return total


# 軽減%の合計。⚠ 上限は REDUCTION_PCT_MAX（100 にすると誰も死なない）。
func damage_taken_pct(unit_id: String) -> int:
	return mini(_intervene_sum(unit_id, SkillSchema.INTERVENE_REDUCTION_PCT), SkillSchema.REDUCTION_PCT_MAX)


# 貫通%の合計。⚠ 上限は PIERCE_PCT_MAX。
func pierce_pct(unit_id: String) -> int:
	return mini(_intervene_sum(unit_id, SkillSchema.INTERVENE_PIERCE_PCT), SkillSchema.PIERCE_PCT_MAX)


# 反射%の合計。⚠ 上限は掛けない（返す量は元のダメージに比例するので暴走しない）。
func reflect_pct(unit_id: String) -> int:
	return _intervene_sum(unit_id, SkillSchema.INTERVENE_REFLECT_PCT)


# 固定値の反射の合計。⚠ シールドが全部吸っても返る（人間の決定4）。
func reflect_flat(unit_id: String) -> int:
	return _intervene_sum(unit_id, SkillSchema.INTERVENE_REFLECT_FLAT)


# 確定クリティカルを持っているか。⚠ 1件でもあれば真（合計しない）。
func has_crit_always(unit_id: String) -> bool:
	for entry: Dictionary in _entries:
		if str(entry.get("kind", "")) != KIND_BUFF:
			continue
		if not _applies_to(entry, unit_id):
			continue
		if bool(entry.get(SkillSchema.INTERVENE_CRIT_ALWAYS, false)):
			return true
	return false


# シールドの合計（元の量）と残量。⚠ 表示のためだけに使う。
#
# ⚠ 戦闘の計算はここを読まない（吸うのは consume_shield の1本）。読ませると
#   「表示用に足した関数」が判定に混ざり、直すときに両方を追うことになる。
func shield_total(unit_id: String) -> int:
	return _intervene_sum(unit_id, SkillSchema.INTERVENE_SHIELD_HP)


func shield_left(unit_id: String) -> int:
	var total: int = 0
	for entry: Dictionary in _entries:
		if str(entry.get("kind", "")) != KIND_BUFF:
			continue
		if not _applies_to(entry, unit_id):
			continue
		if int(entry.get(SkillSchema.INTERVENE_SHIELD_HP, 0)) <= 0:
			continue
		total += maxi(0, int(entry.get("counter", 0)))
	return total


# シールドに肩代わりさせる。吸えた量を返す。
#
# ⚠ 残量は counter が持つ（shield_hp は「元の量」で、記録と再付与のために残す）。
# ⚠ 0 になった件はここで消す（人間が見ていない決め6）。寿命を待つと、
#   「守られているように見えて何も守らない状態」が画面に残る。
# ⚠ 消すときの why は "consumed"。expire と区別できないと、
#   「盾が切れた」のか「時間切れ」なのかログから読めない。
# ⚠ 複数のシールドが付いているときは _entries の並び順に吸う（§8 の宿題）。
func consume_shield(unit_id: String, amount: int) -> int:
	if amount <= 0:
		return 0
	var remaining: int = amount
	var absorbed: int = 0
	var consumed_ids: Array = []
	for entry: Dictionary in _entries:
		if remaining <= 0:
			break
		if str(entry.get("kind", "")) != KIND_BUFF:
			continue
		if not _applies_to(entry, unit_id):
			continue
		if int(entry.get(SkillSchema.INTERVENE_SHIELD_HP, 0)) <= 0:
			continue
		var left: int = int(entry.get("counter", 0))
		if left <= 0:
			continue
		var eaten: int = mini(left, remaining)
		entry["counter"] = left - eaten
		absorbed += eaten
		remaining -= eaten
		if int(entry["counter"]) <= 0:
			consumed_ids.append(int(entry.get("instance_id", 0)))

	# ⚠ 回しながら消さない。集めてから消す（段階6の _step_summons と同じ形）。
	if not consumed_ids.is_empty():
		var rest: Array = []
		for entry: Dictionary in _entries:
			if int(entry.get("instance_id", 0)) in consumed_ids:
				BattleLog.log_status_end(
					str(entry.get("status_id", "")), str(entry.get("host_unit_id", "")), "consumed"
				)
				continue
			rest.append(entry)
		_entries = rest
	return absorbed


# そのユニットの、その軸への合計補正。
func stat_mod(unit_id: String, stat_key: String) -> int:
	var total: int = 0
	for entry: Dictionary in _entries:
		if str(entry.get("kind", "")) != KIND_BUFF:
			continue
		if not _applies_to(entry, unit_id):
			continue
		if str(entry.get("stat", "")) != stat_key:
			continue
		total += int(entry.get("value", 0))
	return total


# カウンターを増やす。増やしたあとの値を返す。
# ⚠ 受け口だけ。呼び出し元はまだ無い（段階3の後半の購読が使う）。
#   コンボ／スタック蓄積／N回攻撃ごと／N回でデバフ が全部これを使う（PLAN 13-1）。
func bump_counter(instance_id: int, delta: int) -> int:
	for entry: Dictionary in _entries:
		if int(entry.get("instance_id", 0)) != instance_id:
			continue
		entry["counter"] = int(entry.get("counter", 0)) + delta
		return int(entry["counter"])
	push_warning("[StatusRegistry] bump_counter: instance_id=%d が見つからない" % instance_id)
	return 0


func size() -> int:
	return _entries.size()


func snapshot() -> Array:
	return _entries.duplicate(true)


# ============================================================
# 内部
# ============================================================

# 能力値の補正を、そのユニットぶんだけゼロから組み直す。
#
# ⚠ ここが「無音で剥がれる／二重に付く」を構造で防いでいる。
#   BattleUnit._stat_mods を += / -= で更新しないこと。差分更新にすると、
#   剥がし忘れが「少し強いまま」として残り、エラーも出ず、F3 パネルの数字も
#   もっともらしいので気づけない。組み直しなら、状態の配列が正しい限り
#   補正は必ず正しい。
func _rebuild_unit_mods(unit_id: String) -> void:
	if unit_id == "":
		return
	var unit: BattleUnit = _find_unit(unit_id)
	if unit == null:
		return
	var mods: Dictionary = {}
	for entry: Dictionary in _entries:
		if str(entry.get("kind", "")) != KIND_BUFF:
			continue
		# ⚠ 効いているかの判定は _applies_to() の1本だけ（EXEC_SKILL_AURA.md §0-1 の1）。
		#   宿主一致（host: unit）と範囲内（host: point）と条件（active）を全部含む。
		#
		# 条件が偽の間は補正に乗せない（PLAN 10章の3つ目の発火源）。
		# ⚠ この1行が条件の安全の本体。この関数は「ゼロから組み直す」形なので、
		#   絞り込みを1つ足すだけで「剥がれないバフ」「二重に乗るバフ」が
		#   構造的に起きない。add() や _eval_conditions() から
		#   unit.set_stat_mods() を直接呼んで近道しないこと。
		if not _applies_to(entry, unit_id):
			continue
		var stat_key: String = str(entry.get("stat", ""))
		# ⚠ 介入だけを持つ buff（復活・免疫・被回復増減）は stat を持たない。
		#   ガードが無いと mods[""] が生まれ、F3 パネルに空キーが出る
		#   （get_stat() はキーで引くので実害は無いが、読む側が迷う）。
		if stat_key == "":
			continue
		mods[stat_key] = int(mods.get(stat_key, 0)) + int(entry.get("value", 0))
	unit.set_stat_mods(mods)


func _rebuild_touched(touched: Dictionary) -> void:
	for unit_id: Variant in touched:
		_rebuild_unit_mods(str(unit_id))


func _find_unit(unit_id: String) -> BattleUnit:
	# ⚠ 自分で配列を回さない。BattleSession.find_unit() が唯一の探し方（段階6）。
	if _session == null:
		return null
	return _session.find_unit(unit_id)
