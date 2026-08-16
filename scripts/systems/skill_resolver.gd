class_name SkillResolver
extends RefCounted

# スキル効果の計算を集約する静的クラス。
# Autoload にしない。MasterDataLoader と同じ「静的クラス」スタイル。
#
# 【契約】1回ぶんの、確定したスキルデータを解く。
#         時間を持たず、次のフレームを知らず、ノードを触らない（PLAN 7-3）。
#         表示（pop_damage 等）は関与しない。戻り値の配列を BattleController に渡す。
#
# 【入口は2つ】
#   select_targets() … 対象を選ぶだけ。射程（range）で絞るのもここ
#   resolve()        … 効果を当てる
# 分けてあるのは、射程と投射物が同じ要求（「効果を当てずに対象だけ知りたい」）を
# 出したため（PLAN 4-4 / 4-5）。発動可否（SkillActivation）が select_targets() を使う。
#
# 【器の語彙】値の一覧は SkillSchema が唯一の正。ここに2本目の一覧を作らない。

# 効果の結果の形。battle_controller.gd がそのまま読むので変えないこと。
#   { "unit_id": String, "amount": int, "is_heal": bool, "is_crit": bool }


# ============================================================
# 入口1：対象を選ぶ
# ============================================================

# target_def（skills.json の target ブロック）を解いて unit_id の配列を返す。
#
# ⚠ 返すのは参照ではなく ID。段階2で「発動時に対象を確定し、あとで発火する」形に
#   なるため、今から ID で返す（PLAN 4-4）。
static func select_targets(target_def: Dictionary, user: BattleUnit, session: BattleSession) -> Array:
	var ids: Array = []
	if user == null or session == null:
		push_error("[SkillResolver] user または session が null")
		return ids
	if target_def == null or target_def.is_empty():
		push_error("[SkillResolver] target が空")
		return ids

	# 1. チームは相対で解く。TEAM_ENEMY / TEAM_PARTY を直書きしないこと。
	#    直書きすると「誰でも撃てる」前提が消え、敵がスキルを使えなくなる（PLAN 4-2）。
	var team_kind: String = str(target_def.get("team", ""))
	var team: String = ""
	match team_kind:
		SkillSchema.TEAM_SELF:
			# self は mode / sort / count / range を読まない（PLAN 21章）。
			return [user.unit_id]
		SkillSchema.TEAM_SOURCE:
			push_warning("[SkillResolver] team: source は段階3。対象なしとして扱う")
			return ids
		SkillSchema.TEAM_ENEMY:
			team = BattleUnit.TEAM_ENEMY if user.team == BattleUnit.TEAM_PARTY else BattleUnit.TEAM_PARTY
		SkillSchema.TEAM_ALLY:
			team = user.team
		_:
			push_error("[SkillResolver] 不明な team: " + team_kind)
			return ids

	# 2. 母集団（死者は入らない）
	var pool: Array = []
	for u in session.get_alive_units(team):
		if u is BattleUnit:
			pool.append(u)

	# 3. 射程で絞る。欄が無ければ絞らない（＝無制限）。
	#    ⚠ 絞った結果が0体なら空配列。発動可否はこれを見る（PLAN 4-5）。
	#    発動可否の側で別々に距離を測らないこと。
	if target_def.has("range"):
		var reach: float = float(target_def.get("range", 0.0))
		var in_range: Array = []
		for u: BattleUnit in pool:
			if absf(u.x - user.x) <= reach:
				in_range.append(u)
		pool = in_range

	if pool.is_empty():
		return ids

	# 4. mode
	var mode: String = str(target_def.get("mode", SkillSchema.MODE_SELECT))
	if mode == SkillSchema.MODE_AREA:
		push_warning("[SkillResolver] mode: area は段階4。対象なしとして扱う")
		return ids
	if mode != SkillSchema.MODE_SELECT:
		push_error("[SkillResolver] 不明な mode: " + mode)
		return ids

	# 5. 並べ替えて count 件取る
	var sort_kind: String = str(target_def.get("sort", SkillSchema.SORT_NEAREST))
	if sort_kind == SkillSchema.SORT_ALL:
		# all は count を読まない。全員返す。
		for u: BattleUnit in pool:
			ids.append(u.unit_id)
		return ids

	var ordered: Array = _sorted_units(pool, user, sort_kind)
	# ⚠ MasterDataLoader は数値を float で返す。int() 必須。
	var count: int = int(target_def.get("count", 1))
	if count < 1:
		count = 1
	# 生存者が count に満たなければ、いる分だけ返す（空振りにしない）。
	var taken: int = mini(count, ordered.size())
	for i in range(taken):
		ids.append((ordered[i] as BattleUnit).unit_id)
	return ids


# 並べ替え。⚠ 同率のときは元の配列の先頭を採る（並び順は parties.json）。
# これをやらないと、同じ距離の敵が2体いるときに撃つたびに対象が入れ替わる
# （無音でぶれる）。
static func _sorted_units(pool: Array, user: BattleUnit, sort_kind: String) -> Array:
	var entries: Array = []
	var index: int = 0
	for u: BattleUnit in pool:
		entries.append({ "unit": u, "key": _sort_key(u, user, sort_kind), "index": index })
		index += 1

	var descending: bool = (
		sort_kind == SkillSchema.SORT_FARTHEST or sort_kind == SkillSchema.SORT_HIGHEST_HP
	)

	# Array.sort_custom() を使わず挿入ソートで並べる。理由は2つ。
	#   ・sort_custom() は安定ソートではない（同率の順番が保証されない）
	#   ・対象は多くても数体なので、速度は問題にならない
	# 「入れる位置は、自分より後ろに来るべき要素の手前」なので、キーが同じ相手は
	# 追い越さない＝元の並び順（parties.json / ウェーブ定義の順）が保たれる。
	var ordered: Array = []
	for entry: Dictionary in entries:
		var pos: int = ordered.size()
		var i: int = 0
		while i < ordered.size():
			var other: Dictionary = ordered[i]
			var key: float = float(entry["key"])
			var other_key: float = float(other["key"])
			var goes_before: bool = key > other_key if descending else key < other_key
			if goes_before:
				pos = i
				break
			i += 1
		ordered.insert(pos, entry)

	var result: Array = []
	for e: Dictionary in ordered:
		result.append(e["unit"])
	return result


# 並べ替えのキー。降順は _sorted_units 側で反転する（キーは常に「小さいほど前」）。
static func _sort_key(unit: BattleUnit, user: BattleUnit, sort_kind: String) -> float:
	if sort_kind == SkillSchema.SORT_NEAREST or sort_kind == SkillSchema.SORT_FARTHEST:
		return absf(unit.x - user.x)
	if sort_kind == SkillSchema.SORT_LOWEST_HP or sort_kind == SkillSchema.SORT_HIGHEST_HP:
		# ⚠ 割合で比べる（PLAN 4-2）。実数で比べると最大HPの違うユニットで意味が変わる。
		if unit.max_hp <= 0:
			return 0.0
		return float(unit.hp) / float(unit.max_hp)
	push_error("[SkillResolver] 不明な sort: " + sort_kind)
	return 0.0


# ============================================================
# 入口2：効果を当てる
# ============================================================

# effects[] を先頭から順に処理し、適用結果の配列を返す。
# ⚠ 未実装の効果に当たっても配列ごと捨てない。その効果だけ飛ばして、
#   同じ配列の他の効果は当てる（壊れ方を小さくするのが段階1の狙いの1つ）。
static func resolve(skill_data: Dictionary, user: BattleUnit, session: BattleSession) -> Array:
	var results: Array = []
	if skill_data == null or skill_data.is_empty():
		push_error("[SkillResolver] skill_data が空")
		return results
	if user == null or session == null:
		push_error("[SkillResolver] user または session が null")
		return results

	var raw_effects: Variant = skill_data.get("effects", null)
	if not (raw_effects is Array) or (raw_effects as Array).is_empty():
		push_error("[SkillResolver] effects が無い、配列でない、または空")
		return results

	for raw_effect: Variant in (raw_effects as Array):
		if not (raw_effect is Dictionary):
			push_error("[SkillResolver] effects の要素が Dictionary でない")
			continue
		var effect: Dictionary = raw_effect as Dictionary

		var trigger: String = str(effect.get("trigger", SkillSchema.TRIGGER_CAST))
		if trigger != SkillSchema.TRIGGER_CAST:
			push_warning("[SkillResolver] trigger: '%s' は段階2。この効果を飛ばす" % trigger)
			continue

		var host: String = str(effect.get("host", SkillSchema.HOST_NONE))
		if host != SkillSchema.HOST_NONE:
			push_warning("[SkillResolver] host: '%s' は段階3。この効果を飛ばす" % host)
			continue

		if float(effect.get("chance", 1.0)) < 1.0:
			push_warning("[SkillResolver] chance は段階1では読まない（必ず当てる）")

		# 効果ごとの target 上書きが無ければ、スキルの target を使う。
		var target_def: Dictionary = {}
		var raw_target: Variant = effect.get("target", null)
		if raw_target is Dictionary:
			target_def = raw_target as Dictionary
		else:
			var skill_target: Variant = skill_data.get("target", null)
			if skill_target is Dictionary:
				target_def = skill_target as Dictionary
		if target_def.is_empty():
			push_error("[SkillResolver] target が無い")
			continue

		var targets: Array = _units_from_ids(select_targets(target_def, user, session), session)

		var effect_type: String = str(effect.get("type", ""))
		if effect_type == SkillSchema.EFFECT_DAMAGE:
			for t: BattleUnit in targets:
				_apply_damage(effect, user, t, results)
		elif effect_type == SkillSchema.EFFECT_HEAL:
			_apply_heal(effect, user, targets, results)
		elif effect_type in SkillSchema.EFFECT_TYPES_KNOWN:
			push_warning("[SkillResolver] 未実装の効果: '%s'。この効果を飛ばす" % effect_type)
		else:
			push_error("[SkillResolver] 不明な効果: '%s'" % effect_type)

	return results


# ダメージ。⚠ 2段構え（PLAN 11-0・後から変えられない）。
#
#   【第1段】ctx を順に加工し、最後に1回だけ金額を確定する
#   【第2段】確定した数値を消費するだけ。式を2度と評価しない
#
# ⚠ roll_crit() は対象1体につき1回。乱数を振る回数と順番を変えないこと。
static func _apply_damage(effect: Dictionary, user: BattleUnit, target: BattleUnit, results: Array) -> void:
	if target == null:
		return

	var attack_type: String = str(effect.get("attack_type", BattleUnit.ATTACK_TYPE_PHYSICAL))
	if not (attack_type in SkillSchema.attack_types_known()):
		push_error("[SkillResolver] 不明な attack_type: " + attack_type)
		attack_type = BattleUnit.ATTACK_TYPE_PHYSICAL

	# attack_type は「どの防御で受けるか」だけを決める。攻撃側の参照元は scale_from。
	# true（確定ダメージ）は防御を 0 として扱う。
	var defense: int = 0
	if attack_type != SkillSchema.ATTACK_TYPE_TRUE:
		defense = target.get_defense(attack_type)

	var ctx: Dictionary = {
		"user_id": user.unit_id,
		"target_id": target.unit_id,
		"attack_type": attack_type,
		"power": _scale_value_sum(effect, user, target, float(user.get_power(attack_type))),
		"multiplier": float(effect.get("multiplier", 0.0)) * user.atk_multiplier,
		"defense": defense,
		"crit_dmg": user.get_stat(GameStateKeys.STAT_CRIT_DMG),
		"is_crit": BattleFormula.roll_crit(user.get_stat(GameStateKeys.STAT_CRIT_RATE)),
		"amount": 0,
	}

	# 介入点。段階1は全部素通し。
	# ⚠ 1本の固定式にまとめないこと（PLAN 11-0-1）。まとめると、割り込む位置が
	#   増えるたびに式を書き換えることになり、途中の値も取り出せなくなる。
	_step_crit_override(ctx)
	_step_reduction(ctx)

	# ここで確定する。以降は再計算しない。
	ctx["amount"] = BattleFormula.damage(
		int(ctx["power"]),
		int(ctx["defense"]),
		float(ctx["multiplier"]),
		int(ctx["crit_dmg"]),
		bool(ctx["is_crit"])
	)

	# 【第2段】確定した数値を消費する。
	# （シールドが吸う受け口はここに入る … 段階3。amount を減らせるのはそこだけ）
	target.take_damage(int(ctx["amount"]))
	# （反射の受け口はここに入る … 段階3。ctx["amount"] を読むだけ。式を再評価しない）
	results.append({
		"unit_id": target.unit_id,
		"amount": int(ctx["amount"]),
		"is_heal": false,
		"is_crit": bool(ctx["is_crit"]),
	})


# 確定クリティカルの受け口（段階3）。
# ⚠ 位置が要件。roll_crit() のあと・BattleFormula.damage() の前でなければ、
#   確定クリティカルを後から足せない（PLAN 11-2）。
static func _step_crit_override(_ctx: Dictionary) -> void:
	pass


# 軽減% / 貫通% の受け口（段階3）。defense と multiplier を触れる位置。
static func _step_reduction(_ctx: Dictionary) -> void:
	pass


# 回復。会心を振らない・atk_multiplier を掛けない・介入点も通さない（段階3）。
# attack_type は読まない（欄そのものが存在しない）。
# 今と同じく、全対象に同じ数値を配る（対象ごとに計算し直さない）。
static func _apply_heal(effect: Dictionary, user: BattleUnit, targets: Array, results: Array) -> void:
	if targets.is_empty():
		return
	var multiplier: float = float(effect.get("multiplier", 0.0))
	# スケール元は scale_from から引く。既定値を持たない（決定1-5）。
	# フォールバックが mag なのは、欄が消えたときに「なぜか1ダメージ/1回復」に
	# ならないようにするため（赤は出ているので黙って既定値にはならない）。
	var amount: int = int(floor(
		_scale_value_sum(effect, user, null, float(user.get_stat(GameStateKeys.STAT_MAG))) * multiplier
	))
	for t: BattleUnit in targets:
		if t == null:
			continue
		t.heal(amount)
		results.append({ "unit_id": t.unit_id, "amount": amount, "is_heal": true, "is_crit": false })


# ============================================================
# scale_from（スケール変数表・PLAN 5-5）
# ============================================================

# power ＝ Σ( weight × 変数 )
#
# 書き方は2通り。⚠ 「書かない」は無い（決定1-5・ロード時検証 E27 が赤で弾く）。
#   文字列 "atk" … [{ "source": "atk", "of": "user", "weight": 1.0 }] の省略形
#   配列        … { "source", "of", "weight" } の合成
#
# ⚠ 評価は発火時。段階1は cast と発火が同時なので差は出ないが、
#   fold_charge_ratio() の時点では読まないこと（PLAN 5-5-3）。
static func _scale_value_sum(
		effect: Dictionary, user: BattleUnit, target: BattleUnit, fallback: float
) -> float:
	var raw: Variant = effect.get("scale_from", null)
	if raw == null:
		# ロード時検証（E27）が赤で弾くので、正しい skills.json ならここへ来ない。
		# ⚠ フォールバックを 0 にしないこと。0 にすると必ず 1 ダメージになり、
		#   原因を追いにくい（PLAN 5-4「resolver 側の防御は残すが、主戦場はロード時」）。
		push_error("[SkillResolver] scale_from が無い（damage / heal は必須）")
		return fallback

	var terms: Array = []
	if raw is String:
		terms = [{ "source": str(raw) }]
	elif raw is Array:
		terms = raw as Array
	else:
		push_error("[SkillResolver] scale_from が文字列でも配列でもない")
		return fallback

	var total: float = 0.0
	for term: Variant in terms:
		if not (term is Dictionary):
			push_error("[SkillResolver] scale_from の要素が Dictionary でない")
			continue
		var entry: Dictionary = term as Dictionary
		var source: String = str(entry.get("source", ""))
		var of: String = str(entry.get("of", SkillSchema.SCALE_OF_USER))
		var weight: float = float(entry.get("weight", 1.0))
		total += weight * _scale_variable(source, of, user, target)
	return total


# 変数1本ぶんの値。変数表に無い名前は push_error して 0.0
# （ロード時検証でも捕まえる。二重に守る）。
static func _scale_variable(source: String, of: String, user: BattleUnit, target: BattleUnit) -> float:
	# distance は2者の間の値なので of を読まない。
	# 対象が無い場合（回復・self）は 0.0。
	if source == SkillSchema.SCALE_DISTANCE:
		if target == null or user == null:
			return 0.0
		return absf(target.x - user.x)

	var u: BattleUnit = null
	match of:
		SkillSchema.SCALE_OF_USER:
			u = user
		SkillSchema.SCALE_OF_TARGET:
			u = target
		SkillSchema.SCALE_OF_SOURCE:
			push_warning("[SkillResolver] scale_from の of: source は段階3。0.0 として扱う")
			return 0.0
		_:
			push_error("[SkillResolver] scale_from の of が不明: " + of)
			return 0.0
	if u == null:
		push_error("[SkillResolver] scale_from の of: '%s' に当たるユニットが居ない" % of)
		return 0.0

	match source:
		SkillSchema.SCALE_HP_CURRENT:
			return float(u.hp)
		SkillSchema.SCALE_HP_LOST:
			return float(u.max_hp - u.hp)
		SkillSchema.SCALE_HP_RATIO:
			return 0.0 if u.max_hp <= 0 else float(u.hp) / float(u.max_hp)
		SkillSchema.SCALE_HP_LOST_RATIO:
			return 0.0 if u.max_hp <= 0 else 1.0 - float(u.hp) / float(u.max_hp)

	if source in GameManager.get_stat_keys():
		return float(u.get_stat(source))

	push_error("[SkillResolver] scale_from の source が不明: " + source)
	return 0.0


# ============================================================
# チャージ
# ============================================================

# チャージ倍率を effects[].multiplier に畳み込んだ実効スキルデータを返す。
# こうすると resolve() は「倍率が違うスキル」を解くだけでよく、
# チャージという概念を知らずに済む。
#
# ⚠ skills.json に書ける欄しか触らない（PLAN 7-3 の歯止め）。
# ⚠ multiplier は1つのまま。scale_from の weight には掛けない（PLAN 5-5-1）。
static func fold_charge_ratio(skill_data: Dictionary, power_ratio: float) -> Dictionary:
	var effective: Dictionary = skill_data.duplicate(true)
	var raw_effects: Variant = effective.get("effects", null)
	if not (raw_effects is Array):
		return effective
	for raw_effect: Variant in (raw_effects as Array):
		if not (raw_effect is Dictionary):
			continue
		var effect: Dictionary = raw_effect as Dictionary
		if effect.has("charge_scales") and not bool(effect.get("charge_scales", true)):
			continue
		effect["multiplier"] = float(effect.get("multiplier", 0.0)) * power_ratio
	return effective


# ============================================================
# 内部
# ============================================================

# unit_id から BattleUnit を引き直す。
# BattleSession には無いのでここに持つ。セッションは器のまま保つ（PLAN 4-2）。
static func _units_from_ids(ids: Array, session: BattleSession) -> Array:
	var units: Array = []
	for id: Variant in ids:
		var u: BattleUnit = _find_unit(session, str(id))
		if u != null:
			units.append(u)
	return units


static func _find_unit(session: BattleSession, unit_id: String) -> BattleUnit:
	if session == null or unit_id == "":
		return null
	for u in session.party_units:
		if u is BattleUnit and (u as BattleUnit).unit_id == unit_id:
			return u
	for u in session.enemy_units:
		if u is BattleUnit and (u as BattleUnit).unit_id == unit_id:
			return u
	return null
