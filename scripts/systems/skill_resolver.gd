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
#   { "unit_id": String, "amount": int, "is_heal": bool, "is_crit": bool, "is_dot": bool }
# ダメージのときだけ、購読（PLAN 10章）のために2つ足す。
#   + { "source_unit_id": String, "attack_type": String }
# ⚠ 回復には足さない（回復では合図を出さない）。読むのは SkillRuntime だけ。
#
# is_dot … 表示の色分け用（EXEC_DAMAGE_POP_COLOR.md）。周期ダメージなら true。
#   ⚠ 値は resolve() の引数で外から渡る。呼び出し元（StatusRegistry か SkillRuntime か）
#     しか「DoT の発火か」を知らないため。BattleLog が log_results() の引数で
#     dot_status_id を受け取っているのと同じ形。
#   ⚠ この欄を書くのはこのファイルだけ。受け取った側が後から fired に足す形にしない
#     （結果の形を作る場所が2つになる）。
#   ⚠ ダメージにも回復にも必ず入れる（読む側が has() を書かなくて済むように）。


# ============================================================
# 入口1：対象を選ぶ
# ============================================================

# target_def（skills.json の target ブロック）を解いて unit_id の配列を返す。
#
# ⚠ 返すのは参照ではなく ID。段階2で「発動時に対象を確定し、あとで発火する」形に
#   なるため、今から ID で返す（PLAN 4-4）。
#
# source_unit_id … team: "source"（購読のきっかけになったユニット）のときだけ読む。
#   ⚠ 既定値を "" にしてあるのは、購読と関係ない呼び出し元（SkillActivation）を
#     変えないため。空のまま team: source を解くと対象0体になる（正常系）。
static func select_targets(
		target_def: Dictionary, user: BattleUnit, session: BattleSession,
		source_unit_id: String = ""
) -> Array:
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
			# 購読のきっかけになったユニット（PLAN 10-3）。
			#
			# ⚠ 選び直さない。_sorted_units() も射程も通さない。通すと、反射が
			#   「殴ってきた相手」ではなく「一番近い敵」に返り、数字は出るので気づけない。
			# ⚠ 居ない／死んでいるときは対象0体。警告を出さない（空振りは正常系）。
			# ⚠ mode / sort / count / range は書けない（ロード時検証 E52 が赤で弾く）。
			if source_unit_id == "":
				return ids
			var src: BattleUnit = _find_unit(session, source_unit_id)
			if src == null or not src.is_alive():
				return ids
			return [src.unit_id]
		SkillSchema.TEAM_ENEMY:
			team = BattleUnit.TEAM_ENEMY if user.team == BattleUnit.TEAM_PARTY else BattleUnit.TEAM_PARTY
		SkillSchema.TEAM_ALLY:
			team = user.team
		_:
			push_error("[SkillResolver] 不明な team: " + team_kind)
			return ids

	# 2. 母集団（死者は入らない）
	#
	# ⚠ pool_all は「射程で絞る前」。上書きしないこと（段階4）。
	#   mode: area の巻き込みは range を越えて効くので、絞る前の母集団が要る
	#   （人間の決定・EXEC_SKILL_AREA.md §0）。同じ変数を使い回すと、
	#   「起点選び」と「巻き込み」のどちらかが必ず間違う。
	var pool_all: Array = []
	for u in session.get_alive_units(team):
		if u is BattleUnit:
			pool_all.append(u)

	# 3. 射程で絞る。欄が無ければ絞らない（＝無制限）。
	#    ⚠ 絞った結果が0体なら空配列。発動可否はこれを見る（PLAN 4-5）。
	#    発動可否の側で別々に距離を測らないこと。
	#    ⚠ range は「使用者からの距離」。radius（中心からの距離）と別物。
	# ⚠ range が無いときは pool_all と同じ配列を指す（GDScript の Array は参照）。
	#   どちらも以降1度も書き換えないので成立している。片方に append すると
	#   もう片方も変わるので、絞り込みは必ず「新しい配列を作って差し替える」形にすること。
	var pool_in: Array = pool_all
	if target_def.has("range"):
		var reach: float = float(target_def.get("range", 0.0))
		var in_range: Array = []
		for u: BattleUnit in pool_all:
			if absf(u.x - user.x) <= reach:
				in_range.append(u)
		pool_in = in_range

	if pool_in.is_empty():
		return ids

	# 4. mode
	var mode: String = str(target_def.get("mode", SkillSchema.MODE_SELECT))
	if mode == SkillSchema.MODE_AREA:
		return _select_area(target_def, user, pool_all, pool_in)
	if mode != SkillSchema.MODE_SELECT:
		push_error("[SkillResolver] 不明な mode: " + mode)
		return ids

	# 5. 並べ替えて count 件取る
	var sort_kind: String = str(target_def.get("sort", SkillSchema.SORT_NEAREST))
	if sort_kind == SkillSchema.SORT_ALL:
		# all は count を読まない。全員返す。
		for u: BattleUnit in pool_in:
			ids.append(u.unit_id)
		return ids

	var ordered: Array = _sorted_units(pool_in, user, sort_kind)
	# ⚠ MasterDataLoader は数値を float で返す。int() 必須。
	var count: int = int(target_def.get("count", 1))
	if count < 1:
		count = 1
	# 生存者が count に満たなければ、いる分だけ返す（空振りにしない）。
	var taken: int = mini(count, ordered.size())
	for i in range(taken):
		ids.append((ordered[i] as BattleUnit).unit_id)
	return ids


# mode: area（段階4）。円の中心を1つ決め、radius に入る全員を返す。
#
# pool_all … 射程で絞る前の母集団。⚠ 巻き込みはこちらから拾う
# pool_in  … 射程で絞ったあと。⚠ 起点を選ぶのはこちらから
#
# ⚠ 2つを取り違えないこと。取り違えても対象は返るので、エラーは1つも出ない。
#   ・起点を pool_all から選ぶ → 射程外の敵を起点にできてしまう
#   ・巻き込みを pool_in から拾う → 「radius は range を越える」という決定が消える
#
# ⚠ 味方は巻き込まない（人間の決定）。母集団は team で既に決まっており、
#   この関数は母集団の外を1体も見ない。ここに team の分岐を書かないこと。
# ⚠ 距離は1次元（absf の差）。_sort_key() / range の絞りと同じ形。
#   ここだけ2次元にすると距離の意味が2つになる（2次元化は PLAN 16章・上流の話）。
# ⚠ count は読まない。ロード時検証 E80 が赤で弾いている。
static func _select_area(
		target_def: Dictionary, user: BattleUnit, pool_all: Array, pool_in: Array
) -> Array:
	var ids: Array = []
	# ⚠ MasterDataLoader は数値を float で返す。ここは int() ではない。
	var radius: float = float(target_def.get("radius", 0.0))

	# 1. 円の中心
	var origin: String = str(target_def.get("origin", ""))
	var center_x: float = 0.0
	if origin == SkillSchema.ORIGIN_USER:
		center_x = user.x
	elif origin == SkillSchema.ORIGIN_TARGET:
		# 起点を1体選ぶ。⚠ select と同じ選び方をする（既定は nearest）。
		#   sort: "all" は起点が1体に決まらないので E79 が赤で弾いている。
		# ⚠ 起点が居なければ対象0体。警告を出さない（空振りは正常系。
		#   毎フレーム走るので、ここで警告を出すと出力パネルが埋まる）。
		if pool_in.is_empty():
			return ids
		var sort_kind: String = str(target_def.get("sort", SkillSchema.SORT_NEAREST))
		var ordered: Array = _sorted_units(pool_in, user, sort_kind)
		center_x = (ordered[0] as BattleUnit).x
	else:
		push_error("[SkillResolver] 不明な origin: " + origin)
		return ids

	# 2. 巻き込む。⚠ pool_all から拾う（radius は range を越える）
	for u: BattleUnit in pool_all:
		if absf(u.x - center_x) <= radius:
			ids.append(u.unit_id)
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

# 効果を、確定した対象に当てる。
#
# 【段階2で変わったこと】
#   ・対象は cast 時に確定させ、ID で持ち回す（PLAN 4-4）。ここで選び直さない。
#     選び直すと、多段の2発目が「生き残っている別の敵」に吸われる。
#   ・trigger はここで読まない。SkillRuntime が持つ。
#     2箇所で解釈すると、片方だけ直す事故になる。
#
# ⚠ target_ids は必須。既定値を作らない（黙って全員に当たる形を作らないため）。
# ⚠ 契約は変わっていない（PLAN 7-3）：時間を持たず、次のフレームを知らず、ノードを触らない。
#   入口も2つのまま（select_targets / resolve）。ID は skill_data の外を通るので、
#   「実効スキルデータは skills.json に書ける欄しか含まない」という歯止めも無傷。
#
# 【段階3で変わったこと】
#   ・状態の器（StatusRegistry）を引数で受け取る。host が none 以外の効果は
#     器に登録して終わる。⚠ 既定値（null 許容）を作らない。許すと、渡し忘れた
#     ときに buff / dot が黙って飛ぶ。呼び出し元は2箇所しかない。
#   ・契約は変わらない（PLAN 7-3）：時間を持たず、次のフレームを知らず、
#     ノードを触らない。器は BattleSession と同じ「渡される入れ物」で、
#     ここは1件登録するだけ。時間を進めるのは器の側。
#   ・歯止めも無傷：器は skill_data の中ではなく引数で横から渡る（target_ids と同じ形）。
#
# ⚠ 未実装の効果に当たっても配列ごと捨てない。その効果だけ飛ばす。
# ⚠ registry の型を StatusRegistry と書かないこと（RefCounted のまま渡す）。
#   status_registry.gd は dot の発火で SkillResolver.resolve() を呼ぶので、
#   ここで StatusRegistry を名指しすると2つのファイルが相互参照になり、
#   Cyclic reference のパースエラーを踏みうる（battle_formula.gd 冒頭と同じ形）。
#   代償は registry.add() が動的呼び出しになること。呼ぶのは _apply_status() の
#   2行だけなので、そこだけ見ておけばよい。
#
# is_dot … この発火が状態の周期ダメージかどうか（表示の色分け用）。
#   ⚠ 既定値 false。付けないと呼び出し元2箇所のうち片方が壊れる。
#   ⚠ 計算には一切使わない。結果に載せて返すだけ（DoT だから弱い、等をここに書かない）。
static func resolve(
		skill_data: Dictionary, user: BattleUnit, session: BattleSession,
		target_ids: Array, registry: RefCounted, is_dot: bool = false
) -> Array:
	var results: Array = []
	if skill_data == null or skill_data.is_empty():
		push_error("[SkillResolver] skill_data が空")
		return results
	if user == null or session == null:
		push_error("[SkillResolver] user または session が null")
		return results
	if registry == null:
		push_error("[SkillResolver] registry が null（状態の器は必須）")
		return results

	var raw_effects: Variant = skill_data.get("effects", null)
	if not (raw_effects is Array) or (raw_effects as Array).is_empty():
		push_error("[SkillResolver] effects が無い、配列でない、または空")
		return results

	# 段階2以降、resolve() は「1つの効果」を解く。SkillRuntime が effects を1件ずつに割る。
	# 2件以上来たのは、割り忘れか、新層を通さずに呼ばれたか。処理は続ける
	# （全効果に同じ target_ids を当てる）が、黙って通さない。
	if (raw_effects as Array).size() != 1:
		push_warning("[SkillResolver] resolve() に効果が %d 件来た（1件ずつ渡すこと）" % (raw_effects as Array).size())

	var targets: Array = _units_from_ids(target_ids, session)

	for raw_effect: Variant in (raw_effects as Array):
		if not (raw_effect is Dictionary):
			push_error("[SkillResolver] effects の要素が Dictionary でない")
			continue
		var effect: Dictionary = raw_effect as Dictionary

		# ⚠ trigger はここで読まない。SkillRuntime が「いつ発火するか」を持つ。
		#   ここに残すと、新層が delay を待って発火させたのに resolve() が
		#   「cast じゃない」と言って飛ばし、ダメージが完全に消える。

		# host は「効果がどこに残るか」（PLAN 9章）。残らない効果に宿主は無い。
		# ⚠ ロード時検証（E29 / E30）が守っているので通常は来ない。二重に守る。
		var effect_type_for_host: String = str(effect.get("type", ""))
		var host: String = str(effect.get("host", SkillSchema.HOST_NONE))
		var is_status: bool = effect_type_for_host in SkillSchema.EFFECT_TYPES_STATUS
		if is_status and host == SkillSchema.HOST_NONE:
			push_error("[SkillResolver] '%s' に host が無い。この効果を飛ばす" % effect_type_for_host)
			continue
		if not is_status and host != SkillSchema.HOST_NONE:
			push_error("[SkillResolver] '%s' に host: '%s' は書けない。この効果を飛ばす" % [effect_type_for_host, host])
			continue

		if float(effect.get("chance", 1.0)) < 1.0:
			push_warning("[SkillResolver] chance はまだ読まない（必ず当てる）")

		# ⚠ 効果ごとの target 上書きもここでは読まない。cast 時に SkillRuntime が
		#   解釈して target_ids に落としてある（PLAN 4-4）。

		# ⚠ 効果の種類の分岐はここ1箇所（PLAN 9章）。
		#   「状態は SkillRuntime が作る」形にしないこと。分岐が2箇所になり、
		#   trigger を resolve() から追い出したのと同じ事故（片方だけ直す）が起きる。
		var effect_type: String = str(effect.get("type", ""))
		if effect_type == SkillSchema.EFFECT_DAMAGE:
			for t: BattleUnit in targets:
				_apply_damage(effect, user, t, results, session, registry, is_dot)
		elif effect_type == SkillSchema.EFFECT_HEAL:
			_apply_heal(effect, user, targets, results, session, registry)
		elif effect_type in SkillSchema.EFFECT_TYPES_STATUS:
			_apply_status(effect, user, targets, session, registry)
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
# ⚠ session / registry は scale_from の変数を引くためだけに通している
#   （戦闘の群＝elapsed_sec / alive_count_* / wave_index、状態の群＝stack）。
#   ダメージの計算そのものには使わない。
static func _apply_damage(
		effect: Dictionary, user: BattleUnit, target: BattleUnit, results: Array,
		session: BattleSession, registry: RefCounted, is_dot: bool = false
) -> void:
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
		"power": _scale_value_sum(
			effect, user, target, float(user.get_power(attack_type)), session, registry
		),
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
	# 購読（PLAN 10章）が要る情報を、確定した結果に載せて返す。
	#
	# ⚠ ここで購読を発火させないこと。この層は static で、待ち行列も器も持たない
	#   （PLAN 7-3：時間を持たず、次のフレームを知らない）。発火させると
	#   SkillResolver → SkillRuntime の相互参照になり、188行と同じ形を踏む。
	#   合図を配るのは SkillRuntime._fire()。ここは「何が起きたか」を書くだけ。
	# ⚠ 既存の4キーの名前も意味も変えないこと（battle_controller がそのまま読む）。
	results.append({
		"unit_id": target.unit_id,
		"amount": int(ctx["amount"]),
		"is_heal": false,
		"is_crit": bool(ctx["is_crit"]),
		"is_dot": is_dot,
		"source_unit_id": user.unit_id,
		"attack_type": attack_type,
	})


# 確定クリティカルの受け口（段階3）。
# ⚠ 位置が要件。roll_crit() のあと・BattleFormula.damage() の前でなければ、
#   確定クリティカルを後から足せない（PLAN 11-2）。
static func _step_crit_override(_ctx: Dictionary) -> void:
	pass


# 軽減% / 貫通% の受け口（段階3）。defense と multiplier を触れる位置。
static func _step_reduction(_ctx: Dictionary) -> void:
	pass


# 回復。会心を振らない・atk_multiplier を掛けない（段階3）。
# attack_type は読まない（欄そのものが存在しない）。
#
# 【段階3の後半③で変わったこと】回復の介入点（PLAN 11-1）を通すようになった。
# ⚠ 素の回復量は今までどおり1回だけ計算する。介入は確定値に％を掛けるだけで、
#   式を2度と評価しない（PLAN 11-0 の不変条件。ダメージの2段構えと同じ）。
# ⚠ 素の量は全対象で同じだが、介入は対象ごと。被回復低下は「受け手の性質」で、
#   誰が回復したかには関係しないため。
static func _apply_heal(
		effect: Dictionary, user: BattleUnit, targets: Array, results: Array,
		session: BattleSession, registry: RefCounted
) -> void:
	if targets.is_empty():
		return
	var multiplier: float = float(effect.get("multiplier", 0.0))
	# スケール元は scale_from から引く。既定値を持たない（決定1-5）。
	# フォールバックが mag なのは、欄が消えたときに「なぜか1ダメージ/1回復」に
	# ならないようにするため（赤は出ているので黙って既定値にはならない）。
	var base_amount: int = int(floor(
		_scale_value_sum(
			effect, user, null, float(user.get_stat(GameStateKeys.STAT_MAG)), session, registry
		) * multiplier
	))
	for t: BattleUnit in targets:
		if t == null:
			continue
		var ctx: Dictionary = { "target": t, "base": base_amount, "amount": base_amount, "pct": 0 }
		_step_heal_taken(ctx, registry)
		var amount: int = int(ctx["amount"])
		# ⚠ 介入が効いたときだけログを出す。素通しを出すと回復のたびに1行増える。
		if int(ctx["pct"]) != 0:
			BattleLog.log_intervene(
				"heal", t.unit_id, "", "%d -> %d (%d%%)" % [base_amount, amount, int(ctx["pct"])]
			)
		# ⚠ heal(0) は unit.gd が弾く。被回復100%低下は「数字も出ない」が正しい。
		t.heal(amount)
		# ⚠ is_dot は回復にも入れる（形を揃える）。周期回復（HoT）はまだ無いので常に false。
		results.append({ "unit_id": t.unit_id, "amount": amount, "is_heal": true, "is_crit": false, "is_dot": false })


# 回復の介入点（PLAN 11-1）。被回復低下・回復量増加はここ。
#
# ctx … { target, base, amount, pct }。amount を書き換える。
# ⚠ 作り方をダメージの受け口（_step_crit_override / _step_reduction）と揃える。
#   ctx を1つ取って書き換える。戻り値で分岐しない。
# ⚠ 0 未満にしない。負の回復（＝ダメージ）はここでは作らない。作りたくなったら
#   damage の効果として書くこと（回復とダメージで介入点も表示の色も別なので、
#   ここで符号を跨ぐと緑の数字でHPが減る）。
# ⚠ registry の型は RefCounted のまま（resolve() 冒頭の Cyclic reference の注記）。
static func _step_heal_taken(ctx: Dictionary, registry: RefCounted) -> void:
	if registry == null:
		return
	var target: BattleUnit = ctx.get("target", null)
	if target == null:
		return
	var pct: int = int(registry.heal_taken_pct(target.unit_id))
	if pct == 0:
		return
	ctx["pct"] = pct
	ctx["amount"] = maxi(0, int(floor(float(ctx["base"]) * (100.0 + float(pct)) / 100.0)))


# 状態を付ける（buff / dot・段階3）。器に1件登録するだけで、時間は進めない。
#
# ⚠ 対象0体なら何も起きない。警告を出さない（空振りは正常系・PLAN 4-2）。
# ⚠ 数値の解釈も寿命の判定も器の側でやる。ここに2本目の判定を書かないこと。
#
# ⚠ registry は RefCounted として受ける（resolve() の注記と同じ理由）。
#   add() が無いものを渡すと実行時に落ちる。渡すのは StatusRegistry だけ。
static func _apply_status(
		effect: Dictionary, user: BattleUnit, targets: Array,
		session: BattleSession, registry: RefCounted
) -> void:
	# host: battle は戦場に1つ付く。対象の数だけ増やさない。
	if str(effect.get("host", "")) == SkillSchema.HOST_BATTLE:
		registry.add(effect, user, null, session)
		return
	for t: BattleUnit in targets:
		if t == null:
			continue
		registry.add(effect, user, t, session)


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
# ⚠ session / registry は「戦闘の群」「状態の群」の変数を引くために通す
#   （段階3の後半④）。呼び出し元は _apply_damage と _apply_heal の2箇所だけ。
#   3箇所目を作らないこと。
static func _scale_value_sum(
		effect: Dictionary, user: BattleUnit, target: BattleUnit, fallback: float,
		session: BattleSession, registry: RefCounted
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
		# ⚠ status_id は source: "stack" のときだけ意味を持つ（E71 / E72 が守る）。
		var status_id: String = str(entry.get("status_id", ""))
		total += weight * _scale_variable(source, of, user, target, session, registry, status_id)
	return total


# 変数1本ぶんの値。変数表に無い名前は push_error して 0.0
# （ロード時検証でも捕まえる。二重に守る）。
static func _scale_variable(
		source: String, of: String, user: BattleUnit, target: BattleUnit,
		session: BattleSession, registry: RefCounted, status_id: String = ""
) -> float:
	# --- of を読まない群（SkillSchema.SCALE_SOURCES_NO_OF が唯一の一覧） ---
	# ⚠ 例外を各所に散らさないために、まとめてここで先に返す。
	#   4つ目を足すときは必ず SCALE_SOURCES_NO_OF にも入れること。
	if source in SkillSchema.SCALE_SOURCES_NO_OF:
		match source:
			SkillSchema.SCALE_DISTANCE:
				# 2者の間の値。対象が無い場合（回復・self）は 0.0。
				if target == null or user == null:
					return 0.0
				return absf(target.x - user.x)
			SkillSchema.SCALE_ELAPSED_SEC:
				return 0.0 if session == null else session.elapsed_sec
			SkillSchema.SCALE_WAVE_INDEX:
				# ⚠ 1 始まり。current_hp のような 0 始まりではない
				#   （"wave_index >= 2" で「2波目以降」）。
				return 0.0 if session == null else float(session.current_wave)
		push_error("[SkillResolver] SCALE_SOURCES_NO_OF に入っているが枝が無い: " + source)
		return 0.0

	var u: BattleUnit = null
	match of:
		SkillSchema.SCALE_OF_USER:
			u = user
		SkillSchema.SCALE_OF_TARGET:
			u = target
		SkillSchema.SCALE_OF_SOURCE:
			# ⚠ 実装しないと決めた（人間の決定・2026-08-17）。ロード時検証 E68 が
			#   赤で弾いているのでここへは来ないはず。二重に守るために残す。
			push_error("[SkillResolver] scale_from の of: source は書けない（E68 が弾くはず）")
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
		SkillSchema.SCALE_ALIVE_ALLY:
			# ⚠ 「of で指したユニットから見た」味方。絶対（party 固定）にしない。
			#   敵が撃つスキルに書いたら敵の生存数になる。これが正しい。
			return 0.0 if session == null else float(session.get_alive_units(u.team).size())
		SkillSchema.SCALE_ALIVE_ENEMY:
			if session == null:
				return 0.0
			var foe: String = (
				BattleUnit.TEAM_ENEMY if u.team == BattleUnit.TEAM_PARTY else BattleUnit.TEAM_PARTY
			)
			return float(session.get_alive_units(foe).size())
		SkillSchema.SCALE_STACK:
			# ⚠ registry は StatusRegistry だが RefCounted で受けている
			#   （名指しすると Cyclic reference になる。216-221行と同じ理由）。
			if registry == null or status_id == "":
				return 0.0
			return float(registry.count_stacks(u.unit_id, status_id))

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
