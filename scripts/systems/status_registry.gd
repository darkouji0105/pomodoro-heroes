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
	if kind == KIND_BUFF:
		if not _fill_buff(entry, effect):
			return false
	else:
		if not _fill_dot(entry, effect, duration_sec, life):
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
		# independent … 上限は設けない（PLAN 13-2 の「上限」は後から足せる部品）
		_entries.append(entry)

	if host == SkillSchema.HOST_UNIT:
		_rebuild_unit_mods(str(entry.get("host_unit_id", "")))
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
		# 汎用カウンター（PLAN 13-1）。⚠ 呼び出し元はまだ無い（段階3の後半）。
		"counter": 0,
	}


func _fill_buff(entry: Dictionary, effect: Dictionary) -> bool:
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
	return true


func _fill_dot(entry: Dictionary, effect: Dictionary, duration_sec: float, life: String) -> bool:
	var interval_sec: float = float(effect.get("interval_sec", 0.0))
	if interval_sec <= 0.0:
		push_error("[StatusRegistry] dot の interval_sec が正でない")
		return false
	if not effect.has("scale_from"):
		push_error("[StatusRegistry] dot に scale_from が無い（damage と同じく必須）")
		return false
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
#   3. 周期発火（dot）
#   4. 寿命が切れたものを捨てる
#   5. 変わったユニットの補正を組み直す
#
# ⚠ 3を4より先にやること。duration 4秒 × interval 2秒 は最後の発火と
#   寿命切れが同じフレームに来る。逆順だと最後の1発が黙って消え、
#   総ダメージが暗算と合わなくなる。
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
		touched[str(entry.get("host_unit_id", ""))] = true
	_entries = rest


# 周期発火。⚠ 発火する回数は elapsed から引く。カウントダウンを別に持たない。
func _fire_intervals(results: Array) -> void:
	var rest: Array = []
	for entry: Dictionary in _entries:
		if str(entry.get("kind", "")) != KIND_DOT:
			rest.append(entry)
			continue
		# 座標・戦場に宿る dot は当てる相手が決まらない（条件は段階3の後半）。
		if str(entry.get("host", "")) != SkillSchema.HOST_UNIT:
			rest.append(entry)
			continue

		# ⚠ 付与者が死んでいても止めない（PLAN 7-2）。死者も session に残るので
		#   能力値は読める。session から消えたときだけ捨てる（正常系・警告なし）。
		var source: BattleUnit = _find_unit(str(entry.get("source_unit_id", "")))
		if source == null:
			continue

		var host_id: String = str(entry.get("host_unit_id", ""))
		var interval_sec: float = float(entry.get("interval_sec", 0.0))
		var elapsed: float = float(entry.get("elapsed", 0.0))
		var total: int = int(entry.get("fires_total", 0))

		# ⚠ while にするのは速度8倍で1フレームに複数回跨ぐため。if だと発火が落ちる。
		# ⚠ ループの中で fires_done を必ず増やすこと。増やさないと固まる。
		while (total == FIRES_UNLIMITED or int(entry.get("fires_done", 0)) < total) \
				and elapsed >= float(int(entry.get("fires_done", 0)) + 1) * interval_sec:
			entry["fires_done"] = int(entry.get("fires_done", 0)) + 1
			var one: Dictionary = { "effects": [entry.get("damage_effect", {})] }
			for r: Variant in SkillResolver.resolve(one, source, _session, [host_id], self):
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
		if str(entry.get("host", "")) == SkillSchema.HOST_UNIT:
			touched[str(entry.get("host_unit_id", ""))] = true
	_entries = rest


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
	return dropped


# その宿主に付いた状態を捨てる。捨てた件数を返す。
func clear_for_unit(unit_id: String) -> int:
	var rest: Array = []
	for entry: Dictionary in _entries:
		var hit: bool = (
			str(entry.get("host", "")) == SkillSchema.HOST_UNIT
			and str(entry.get("host_unit_id", "")) == unit_id
		)
		if not hit:
			rest.append(entry)
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


# そのユニットの、その軸への合計補正。
func stat_mod(unit_id: String, stat_key: String) -> int:
	var total: int = 0
	for entry: Dictionary in _entries:
		if str(entry.get("kind", "")) != KIND_BUFF:
			continue
		if str(entry.get("host", "")) != SkillSchema.HOST_UNIT:
			continue
		if str(entry.get("host_unit_id", "")) != unit_id:
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
		if str(entry.get("host", "")) != SkillSchema.HOST_UNIT:
			continue
		if str(entry.get("host_unit_id", "")) != unit_id:
			continue
		var stat_key: String = str(entry.get("stat", ""))
		mods[stat_key] = int(mods.get(stat_key, 0)) + int(entry.get("value", 0))
	unit.set_stat_mods(mods)


func _rebuild_touched(touched: Dictionary) -> void:
	for unit_id: Variant in touched:
		_rebuild_unit_mods(str(unit_id))


func _find_unit(unit_id: String) -> BattleUnit:
	if _session == null or unit_id == "":
		return null
	for u in _session.party_units:
		if u is BattleUnit and (u as BattleUnit).unit_id == unit_id:
			return u
	for u in _session.enemy_units:
		if u is BattleUnit and (u as BattleUnit).unit_id == unit_id:
			return u
	return null
