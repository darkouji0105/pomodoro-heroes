class_name SkillRuntime
extends RefCounted

# 「実行中のスキル」層（PLAN_SKILL_TEMPLATE.md 7-1・段階2）。
#
#   battle_controller  … 入力と表示だけ
#          ↓ cast() を1回呼ぶ
#   SkillRuntime(ここ) … 待ち行列。trigger・タイムアウト・中断・演出シーンとの往復
#          ↓ 「今この瞬間・この効果・この対象」
#   SkillResolver      … 1つの効果を確定した対象に当てる。時間を知らない
#
# 【なぜ static にしないか】待ち行列という状態を持つため。
# BattleController が1体だけ持つ。ノードツリーには入れない。
#
# 【この層はビューを知ってよい】SkillResolver は今後も知らない（PLAN 7-3）。
# 今回は effects_applied シグナルで結果を投げるところまで。
#
# ⚠ 待ち行列は1本しか作らない（PLAN 6-8・後から変えられない）。
#   「スキルごとの private な待ち行列」にすると外から取り消せない。中断は
#   自分で自分を捨てるだけなので private でも成立してしまい、気づかずに
#   閉じた作りにしやすい。段階3の効果 cancel（飛び道具の無効化）と
#   詠唱中断は、どちらも「他人の待ち行列を取り消す」操作になる。
#
# ⚠ この層を「タイマー」にしないこと（PLAN 6-5）。発火の経路は _fire() の1本で、
#   tick() はその呼び出し元の1つにすぎない。アニメーションが入るときに足すのは
#   notify_event() を呼ぶ側だけで、この層も SkillResolver も JSON も変わらない。

# resolve() の戻り値をそのまま流す。battle_controller が pop_damage する。
signal effects_applied(results: Array)

# 投射物を出してほしい、という合図。⚠ この層はノードを触らない（契約）。
#
# battle_controller が受けて演出シーンを出し、着弾したら notify_event() を呼び返す
# （PLAN 6-7「新層は演出シーンに対象IDを渡し、演出シーンは合図を返す」）。
#
# ⚠ ここで Node を作らないこと。SkillRuntime / SkillResolver / StatusRegistry は
#   全部 RefCounted で、ノードツリーを知らない。これは偶然ではなく契約。
signal projectile_requested(cast_id: int, delivery: String, user_id: String, target_ids: Array)

# 飛ぶ送り方。melee はその場で当たるので飛ばさない。
const DELIVERIES_FLYING: Array = [SkillSchema.DELIVERY_PROJECTILE, SkillSchema.DELIVERY_MAGIC]

# 待ち行列の要素が「何を待っているか」。
const WAIT_DELAY: String = "delay"
const WAIT_EVENT: String = "event"

# 合図が来ないまま何秒待つか。
# ⚠ 保険であって本命の経路ではない。着弾の合図（ProjectileView）が来れば
#   その場で発火する。ここまで来たら演出シーン側が壊れている。
const EVENT_TIMEOUT_SEC: float = 5.0

var _session: BattleSession = null

# 状態の器（段階3）。_fire() が SkillResolver へ中継するだけで、この層は中を見ない。
#
# ⚠ ここに置くのは、cast() / charge_start() / tick() / notify_event() の
#   4つの入口が全部 _fire() を通るため（PLAN 6-5）。発火経路ごとに器を引数で
#   運ぶ形にすると、「経路は1本」という決定が形骸化する。
# ⚠ この層は器を触らない。状態の寿命は器が持つ（PLAN 7-2）。
var _registry: StatusRegistry = null

# 待ち行列。要素の形は _make_entry() を見ること。
var _pending: Array = []

# 1回の発動を識別する番号。同じ発動の残りをまとめて取り消すのに使う。
var _next_cast_id: int = 1


func _init(p_session: BattleSession, p_registry: StatusRegistry) -> void:
	_session = p_session
	_registry = p_registry


# セッションを差し替え、待ち行列を捨てる。
#
# ⚠ 「もう一度」で BattleSession が作り直される（battle_controller.gd の
#   _init_session()）。古いセッションを掴んだままだと、リトライ後のスキルが
#   前の戦闘のユニットを探して見つからず、無音で空振りする。エラーは出ない。
# ⚠ 差し替えと破棄を同時にやること。片方だけの関数を作るともう片方を忘れる。
func reset(p_session: BattleSession, p_registry: StatusRegistry) -> void:
	_pending.clear()
	_session = p_session
	_registry = p_registry


# ============================================================
# 入れる（発火源ごとに1本ずつ。出口は全部 _fire()）
# ============================================================

# 発動1回ぶん。効果を待ち行列に置き、trigger: "cast" のものはその場で発火する。
#
# ⚠ cast を次のフレームに回さないこと。回すとダメージの表示が1フレーム遅れ、
#   勝敗判定との順序も変わる。既存スキルの挙動が静かに変わる。
#
# fixed_target_ids … 空でなければ対象選択を飛ばし、このIDをそのまま使う。
#
# ⚠ 通常攻撃のためにある。通常攻撃が狙うのは「歩いて近づいた相手」
#   （BattleUnit.target_unit_id）で、撃つ瞬間に選び直してはいけない。
#   select_targets() に選ばせると sort: nearest で別人に飛ぶ。
# react_ctx … 購読から入ってきたときだけ中身がある（PLAN 10章）。
#   { "source_unit_id": String, "from_reaction": true }
#
# ⚠ 入口を2本にしないこと（発火経路は1本・PLAN 6-5）。cast_basic() を足さない。
#   購読の発火も専用関数を作らず、ここから入って _fire() へ出る。
func cast(
		user: BattleUnit, skill_id: String, skill_data: Dictionary, power_ratio: float,
		fixed_target_ids: Array = [], react_ctx: Dictionary = {}
) -> void:
	if user == null or _session == null:
		push_error("[SkillRuntime] cast: user または session が null")
		return
	if skill_data == null or skill_data.is_empty():
		push_error("[SkillRuntime] cast: skill_data が空 (skill_id=%s)" % skill_id)
		return

	# チャージ倍率は effects[].multiplier に畳み込んでから割る。
	var effective: Dictionary = SkillResolver.fold_charge_ratio(skill_data, power_ratio)
	var raw_effects: Variant = effective.get("effects", null)
	if not (raw_effects is Array) or (raw_effects as Array).is_empty():
		push_error("[SkillRuntime] cast: effects が無い (skill_id=%s)" % skill_id)
		return

	var skill_target: Dictionary = {}
	if effective.get("target", null) is Dictionary:
		skill_target = effective["target"] as Dictionary

	var cast_id: int = _next_cast_id
	_next_cast_id += 1

	# 検証用のログ（EXEC_BATTLE_LOG.md）。⚠ 撃った回数はここで1回。
	#   効果ごと（_fire）に出すと多段で水増しされる。
	BattleLog.log_cast(user.unit_id, skill_id, fixed_target_ids)

	# 1回の発動で出す投射物は、送り方1つにつき1本。
	# ⚠ これが無いと、ダメージと DoT の2効果が同じ矢を待っているだけなのに
	#   矢が2本飛ぶ（癒しの光の DoT 付きなど）。
	var flying_sent: Dictionary = {}

	# 先頭から順に。effects の並び順が多段の順番になる（PLAN 6-2）。
	for raw_effect: Variant in (raw_effects as Array):
		if not (raw_effect is Dictionary):
			push_error("[SkillRuntime] cast: effects の要素が Dictionary でない (skill_id=%s)" % skill_id)
			continue
		var effect: Dictionary = raw_effect as Dictionary
		var trigger: String = str(effect.get("trigger", SkillSchema.TRIGGER_CAST))

		# charge_start は charge_start() の担当。ここでは扱わない。
		if trigger == SkillSchema.TRIGGER_CHARGE_START:
			continue

		var entry: Dictionary = _make_entry(
			cast_id, user, skill_id, effect, skill_target, fixed_target_ids, react_ctx
		)

		if trigger == SkillSchema.TRIGGER_CAST:
			_fire(entry)
		elif trigger.begins_with(SkillSchema.TRIGGER_PREFIX_DELAY):
			# ⚠ 文字列から取り出す。is_valid_float() → float() の順
			#   （SkillSchema._is_trigger_shape() が同じ判定をしている）。
			var raw_sec: String = trigger.substr(SkillSchema.TRIGGER_PREFIX_DELAY.length())
			if not raw_sec.is_valid_float():
				push_error("[SkillRuntime] delay の秒数が数値でない: '%s' (skill_id=%s)" % [trigger, skill_id])
				continue
			entry["wait"] = WAIT_DELAY
			entry["remaining"] = float(raw_sec)
			_pending.append(entry)
		elif trigger.begins_with(SkillSchema.TRIGGER_PREFIX_EVENT):
			# 合図待ち。⚠ 着弾待ちなら、ここで投射物を1本頼む。
			#   合図を出す相手が居ないまま待つと、5秒のタイムアウトで発火する
			#   （黄が出る。ダメージは消えない）。
			var delivery: String = str(entry.get("delivery", ""))
			var event_name: String = trigger.substr(SkillSchema.TRIGGER_PREFIX_EVENT.length())
			if event_name == SkillSchema.EVENT_HIT and delivery in DELIVERIES_FLYING and not flying_sent.has(delivery):
				flying_sent[delivery] = true
				projectile_requested.emit(cast_id, delivery, user.unit_id, entry.get("target_ids", []))
			entry["wait"] = WAIT_EVENT
			entry["remaining"] = EVENT_TIMEOUT_SEC
			entry["event_name"] = event_name
			_pending.append(entry)
		else:
			# ロード時検証（E24）が守っているので通常は来ない。二重に守る。
			push_error("[SkillRuntime] 不明な trigger: '%s' (skill_id=%s)" % [trigger, skill_id])


# trigger: "charge_start" の効果だけを、チャージ開始時に発火させる。
#
# ⚠ fold_charge_ratio() を通さない。チャージ開始時点では倍率が存在しない。
# ⚠ チャージを途中でやめても、既に発火した効果は戻らない。本命の用途
#   （チャージ中のダメージ軽減）は状態＝段階3なので、今の利用者はゼロ。
func charge_start(user: BattleUnit, skill_id: String, skill_data: Dictionary) -> void:
	if user == null or _session == null:
		return
	if skill_data == null or skill_data.is_empty():
		return
	var raw_effects: Variant = skill_data.get("effects", null)
	if not (raw_effects is Array):
		return

	var skill_target: Dictionary = {}
	if skill_data.get("target", null) is Dictionary:
		skill_target = skill_data["target"] as Dictionary

	var cast_id: int = _next_cast_id
	_next_cast_id += 1

	for raw_effect: Variant in (raw_effects as Array):
		if not (raw_effect is Dictionary):
			continue
		var effect: Dictionary = raw_effect as Dictionary
		if str(effect.get("trigger", SkillSchema.TRIGGER_CAST)) != SkillSchema.TRIGGER_CHARGE_START:
			continue
		_fire(_make_entry(cast_id, user, skill_id, effect, skill_target))


# 演出シーンからの合図の受け口（PLAN 6-3 / 6-5）。
#
# ⚠ 呼び出し元は battle_controller.on_projectile_hit()（投射物の着弾）だけ。
#   ここが空だと tick() が唯一の発火経路になり、この層が「時間で進むもの」に
#   なってしまう（PLAN 6-5 が禁じている形）。
# ⚠ 同じ cast_id の矢が複数本あっても、取り出すのは最初の1本の合図だけ。
#   2本目以降は一致する要素が無いので何も起きない（全体攻撃で対象の数だけ飛ぶ）。
func notify_event(cast_id: int, event_name: String) -> void:
	var ready: Array = []
	var rest: Array = []
	for entry: Dictionary in _pending:
		var hit: bool = (
			str(entry.get("wait", "")) == WAIT_EVENT
			and int(entry.get("cast_id", 0)) == cast_id
			and str(entry.get("event_name", "")) == event_name
		)
		if hit:
			ready.append(entry)
		else:
			rest.append(entry)
	_pending = rest
	for entry: Dictionary in ready:
		_fire(entry)


# ============================================================
# 進める
# ============================================================

# 毎フレーム。⚠ 順番が要件。
#   1. 中断の掃除（使用者が死んだ・居ない）
#   2. 時間を進める
#   3. 時間切れになったものを、待ち行列の順のまま取り出す
#   4. 取り出したものを順に発火する
#
# 3と4を分けるのは、回しながら消すと順番が飛ぶため。
func tick(delta: float) -> void:
	if _pending.is_empty():
		return

	# 1. 中断。⚠ 警告を出さない（正常系・PLAN 6-6）。
	#    ユニットの死を知らせるシグナルが無いので毎フレーム走査する。
	#    要素は多くても数件なので速度は問題にならない。
	_drop_dead_users()

	# 2〜3.
	var ready: Array = []
	var rest: Array = []
	for entry: Dictionary in _pending:
		entry["remaining"] = float(entry.get("remaining", 0.0)) - delta
		if float(entry["remaining"]) > 0.0:
			rest.append(entry)
			continue
		# ⚠ 合図待ちの時間切れだけが異常。delay は時間が来て発火するのが正常。
		if str(entry.get("wait", "")) == WAIT_EVENT:
			push_warning("[SkillRuntime] 合図 'event:%s' が来ないままタイムアウトした。発火させる (skill=%s, user=%s)" % [
				str(entry.get("event_name", "")), str(entry.get("skill_id", "")), str(entry.get("user_id", ""))
			])
		ready.append(entry)
	_pending = rest

	# 4.
	for entry: Dictionary in ready:
		_fire(entry)


# ============================================================
# 取り消す（PLAN 6-8・外から取り消せる形）
# ============================================================

# その使用者の残りを捨てる。捨てた件数を返す。
# ⚠ 正常系なので警告を出さない（決定1-6）。
func cancel_for_user(unit_id: String) -> int:
	var rest: Array = []
	for entry: Dictionary in _pending:
		if str(entry.get("user_id", "")) != unit_id:
			rest.append(entry)
	var dropped: int = _pending.size() - rest.size()
	_pending = rest
	return dropped


# 種別タグで取り消す。捨てた件数を返す。
# ⚠ 呼び出し元はまだ無い。段階3の効果 cancel（飛び道具の無効化）と詠唱中断が使う。
#   「飛んでいる矢」の正体は待ち行列に載っている発火待ちの効果であって、壁ではない。
func cancel_by_delivery(delivery: String) -> int:
	var rest: Array = []
	for entry: Dictionary in _pending:
		if str(entry.get("delivery", "")) != delivery:
			rest.append(entry)
	var dropped: int = _pending.size() - rest.size()
	_pending = rest
	return dropped


# 全部捨てる。ウェーブ交代・勝敗確定で呼ぶ。捨てた件数を返す。
func clear_all() -> int:
	var dropped: int = _pending.size()
	_pending.clear()
	return dropped


# 外から中を見る（PLAN 6-8）。
func pending_count() -> int:
	return _pending.size()


func pending_snapshot() -> Array:
	return _pending.duplicate(true)


# ============================================================
# 内部
# ============================================================

# 待ち行列の要素を作る。対象はここで確定する。
#
# ⚠ 対象は cast 時に確定し、以降選び直さない（PLAN 4-4）。
#   発火時に選び直すと、多段の2発目が「生き残っている別の敵」に吸われる。
#   数字は出るので気づきにくい。
# ⚠ 保持するのは参照ではなく ID。参照だと解放された瞬間に壊れる。
# ⚠ 対象が0体でも積む。空振りは正常系（PLAN 4-2）。積まないと
#   pending_count() が実態と合わなくなる。
func _make_entry(
		cast_id: int, user: BattleUnit, skill_id: String, effect: Dictionary,
		skill_target: Dictionary, fixed_target_ids: Array = [], react_ctx: Dictionary = {}
) -> Dictionary:
	var source_unit_id: String = str(react_ctx.get("source_unit_id", ""))
	var from_reaction: bool = bool(react_ctx.get("from_reaction", false))

	# ⚠ 外から対象が来ていれば選び直さない（通常攻撃。cast() の注記を見ること）。
	if not fixed_target_ids.is_empty():
		return _entry_dict(
			cast_id, user, skill_id, effect, fixed_target_ids.duplicate(),
			source_unit_id, from_reaction
		)

	# 効果ごとの target 上書きが無ければ、スキルの target を使う。
	# ⚠ ここでマスターを引き直さない。渡された実効スキルデータの target を使う
	#   （引き直すと「渡されたデータ」と「マスター」の2つの正ができる）。
	var target_def: Dictionary = skill_target
	var raw_target: Variant = effect.get("target", null)
	if raw_target is Dictionary:
		target_def = raw_target as Dictionary

	var target_ids: Array = []
	if target_def.is_empty():
		push_error("[SkillRuntime] target が無い (skill_id=%s)" % skill_id)
	else:
		target_ids = SkillResolver.select_targets(target_def, user, _session, source_unit_id)

	return _entry_dict(
		cast_id, user, skill_id, effect, target_ids, source_unit_id, from_reaction
	)


# 要素の形はここ1箇所。⚠ 対象の決め方が2通りあるので、欄の並びを2箇所に書かない。
#   購読の印（from_reaction）が漏れないのは、この関数が1本道だからである。
func _entry_dict(
		cast_id: int, user: BattleUnit, skill_id: String, effect: Dictionary, target_ids: Array,
		source_unit_id: String = "", from_reaction: bool = false
) -> Dictionary:
	return {
		"cast_id": cast_id,
		"user_id": user.unit_id,
		"skill_id": skill_id,
		"effect": effect,
		"target_ids": target_ids,
		"delivery": str(effect.get("delivery", SkillSchema.DELIVERY_MELEE)),
		"wait": "",
		"remaining": 0.0,
		"event_name": "",
		# 購読（PLAN 10章）
		"source_unit_id": source_unit_id,   # team: "source" が指す相手
		"from_reaction": from_reaction,     # 10-2 の印
	}


# 発火。⚠ 経路はここ1本（PLAN 6-5）。cast も delay も event も charge_start も
#   最後はここへ入る。この関数は時間を知らない。
func _fire(entry: Dictionary) -> void:
	var user: BattleUnit = _find_unit(str(entry.get("user_id", "")))
	if user == null or not user.is_alive():
		# 中断の掃除で消えているはず。二重に守る（正常系なので警告しない）。
		return

	# ⚠ SkillResolver に渡すのは「効果1つぶんの実効スキルデータ」だけ。
	#   歯止め（PLAN 7-3）：実効スキルデータは skills.json に書ける欄しか含まない。
	#   対象 ID は skill_data の中に入れず、引数で横から渡す。
	var one: Dictionary = { "effects": [entry.get("effect", {})] }
	var results: Array = SkillResolver.resolve(one, user, _session, entry.get("target_ids", []), _registry)

	# 検証用のログ（EXEC_BATTLE_LOG.md）。⚠ 観測点はここ（results を受け取る側）。
	#   SkillResolver._apply_damage() は DoT からも呼ばれる static なので、
	#   あちらに差すと発火点と観測点を取り違える。
	BattleLog.log_results(results, str(entry.get("user_id", "")))

	# ⚠ 10-2 の印。反応から生まれた行動は、さらなる反応を生まない。
	#   判定はここ1箇所だけ。購読を探す側・撃つ側に散らさないこと。
	#   この1行で、反射の無限ループ・追撃の発散・コンボの水増しが同時に止まる。
	# ⚠ results.is_empty() の early return より前に置くこと。
	#   空振り（対象0体）でも「攻撃した」は出る。
	if not bool(entry.get("from_reaction", false)):
		_dispatch_events(entry, results)

	if results.is_empty():
		return
	effects_applied.emit(results)


# ============================================================
# 購読（PLAN 10章）
# ============================================================

# 起きたことを合図に変えて配る。⚠ ここは「何が起きたか」を知っている唯一の場所。
#
# ⚠ print を書かないこと（正常系が毎フレーム大量に起きる）。
#   ログを出すのは、購読が実際に発火したとき（_notify）だけ。
func _dispatch_events(entry: Dictionary, results: Array) -> void:
	var user_id: String = str(entry.get("user_id", ""))
	var effect: Dictionary = entry.get("effect", {}) as Dictionary

	# 1. 攻撃した … 効果1件につき1回。⚠ 対象0体（空振り）でも出す。
	#    多段は効果ごとに出る（effects[] が2件なら2回）。
	if str(effect.get("type", "")) == SkillSchema.EFFECT_DAMAGE:
		var first_target: String = ""
		var target_ids: Array = entry.get("target_ids", [])
		if not target_ids.is_empty():
			first_target = str(target_ids[0])
		_notify(SkillSchema.EVENT_ATTACKED, user_id, first_target)

	# 2. ダメージを与えた／受けた … 確定した1件につき1回ずつ。
	#    ⚠ 「攻撃した」と1つにしないこと。空振りと、当たったが0ダメージは別の出来事。
	#    ⚠ 回復では出さない。
	for raw: Variant in results:
		if not (raw is Dictionary):
			continue
		var r: Dictionary = raw as Dictionary
		if bool(r.get("is_heal", false)):
			continue
		var victim_id: String = str(r.get("unit_id", ""))
		var attacker_id: String = str(r.get("source_unit_id", ""))
		_notify(SkillSchema.EVENT_DEALT_DAMAGE, attacker_id, victim_id)
		_notify(SkillSchema.EVENT_TOOK_DAMAGE, victim_id, attacker_id)


# その出来事を購読しているものを探して撃つ。
#
# host_unit_id   … 合図を配る相手（その状態を宿しているユニット）
# source_unit_id … きっかけになった相手（target.team: "source" が指す）
#
# ⚠ 購読が無いのは正常系。警告も print も出さない（毎フレーム大量に起きる）。
# ⚠ query() は器の辞書を参照で返す（status_registry.gd）。書き換えないこと。
# ⚠ 取り出してから発火する。回しながら撃つと、発火の中で器が増減したときに再入する。
#   subs は query() が作った別の配列なので、この形で守れている。
func _notify(event_name: String, host_unit_id: String, source_unit_id: String) -> void:
	if _registry == null or host_unit_id == "":
		return
	# ⚠ "active": true を落とさないこと。条件が偽の間も反応してしまう（無音）。
	#   器は active を bool で持ち、query() は文字列に直して比べるので、この
	#   1行だけで効く（query() 側に条件の判定を書き足さないこと）。
	var subs: Array = _registry.query({
		"kind": StatusRegistry.KIND_REACT,
		"host_unit_id": host_unit_id,
		"active": true,
	})
	if subs.is_empty():
		return

	var host: BattleUnit = _find_unit(host_unit_id)
	if host == null or not host.is_alive():
		return

	for raw: Variant in subs:
		if not (raw is Dictionary):
			continue
		var sub: Dictionary = raw as Dictionary
		var react: Dictionary = sub.get("react", {}) as Dictionary
		if str(react.get("event", "")) != event_name:
			continue
		var effects: Variant = react.get("effects", null)
		if not (effects is Array) or (effects as Array).is_empty():
			continue

		var status_id: String = str(sub.get("status_id", ""))
		# ⚠ 出どころが分かる名前にする。タイムアウトの黄と発火のログに出る。
		var react_skill_id: String = "%s#react:%s" % [status_id, event_name]

		# ⚠ コンソールではなくファイルへ出す（EXEC_BATTLE_LOG.md §2-4）。
		#   ここに print を戻さないこと。
		BattleLog.log_react(
			status_id, event_name, host_unit_id, source_unit_id, (effects as Array).size()
		)

		# ⚠ 専用の発火関数を作らない（PLAN 6-5）。既存の cast() から入る。
		#   印を付けて渡すので、ここから生まれた行動はさらなる反応を生まない。
		cast(
			host, react_skill_id, { "effects": (effects as Array).duplicate(true) }, 1.0, [],
			{ "source_unit_id": source_unit_id, "from_reaction": true }
		)


# 使用者が死んだ／居なくなった要素を捨てる（中断・PLAN 6-6）。
func _drop_dead_users() -> void:
	var rest: Array = []
	for entry: Dictionary in _pending:
		var user: BattleUnit = _find_unit(str(entry.get("user_id", "")))
		if user != null and user.is_alive():
			rest.append(entry)
	_pending = rest


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
