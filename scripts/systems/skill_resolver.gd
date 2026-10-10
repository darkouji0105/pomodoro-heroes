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
	# ⚠ 回GS-1：相手側を狙うときはステルスを外す（get_targetable_units の1本）。
	for u in session.get_targetable_units(team, user.team):
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
	elif origin == SkillSchema.ORIGIN_AIM and user.has_aim:
		# 溜めで動かした狙い（回GM-1）。⚠ 狙いが無いとき（自動戦闘・敵）は下の「一番近い相手」と同じ。
		center_x = user.aim_x
	elif origin == SkillSchema.ORIGIN_TARGET or origin == SkillSchema.ORIGIN_AIM:
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

	var all_targets: Array = _units_from_ids(target_ids, session)

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

		# 相手の状態で当たるかを絞る（回CH-8・「⚠ １う」の い）。⚠ when_mult ／ when_crit があるときは絞らない（強くなるだけ）。
		# 自分についての条件（回PQ-1）。⚠ 満たさなければ効果ごと飛ばす。
		if effect.has(SkillSchema.FIELD_WHEN_USER) and not when_user_ok(effect, user, session):
			continue

		# ⚠ 効果ごとに別の配列で持つ（⚠ 次の効果まで絞らない）。
		var targets: Array = all_targets
		if effect.has(SkillSchema.FIELD_WHEN_TARGET) and not effect.has(SkillSchema.FIELD_WHEN_MULT) \
				and not effect.has(SkillSchema.FIELD_WHEN_CRIT) and not effect.has(SkillSchema.FIELD_WHEN_DRAIN_MULT):
			targets = []
			for t: BattleUnit in all_targets:
				if when_target_ok(effect, t, registry, user):
					targets.append(t)
			if targets.is_empty():
				continue

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
			_apply_status(effect, user, targets, session, registry, results)
		elif effect_type == SkillSchema.EFFECT_SUMMON:
			_apply_summon(effect, user, results, targets)
		elif effect_type == SkillSchema.EFFECT_RESOURCE:
			_apply_resource(effect, user, targets, registry, session, results)
		elif effect_type == SkillSchema.EFFECT_SUMMON_CONSUME:
			_apply_summon_consume(effect, user, results, session, registry, is_dot)
		elif effect_type == SkillSchema.EFFECT_REFRESH_STATUS:
			# 状態の時計を戻す（回GM-1）。⚠ what: "debuff" ならデバフ全部（回ST-1）＝status_id に "" を渡す。
			for t: BattleUnit in targets:
				registry.refresh_status(t.unit_id, str(effect.get("status_id", "")))
		elif effect_type == SkillSchema.EFFECT_PICK:
			# 1つを選んで撃つ（回ST-1）。⚠ 同じ確率・この効果の相手に当てる。
			var choices: Array = effect.get("effects", []) as Array
			if not choices.is_empty():
				var chosen: Variant = choices[randi() % choices.size()]
				var ids: Array = []
				for t: BattleUnit in targets:
					ids.append(t.unit_id)
				results.append_array(resolve({"effects": [chosen]}, user, session, ids, registry, is_dot))
		elif effect_type == SkillSchema.EFFECT_KNOCKBACK:
			for t: BattleUnit in targets:
				_apply_knockback(effect, user, t, results)
		elif effect_type == SkillSchema.EFFECT_DASH:
			_apply_dash(effect, user, targets, results)
		elif effect_type == SkillSchema.EFFECT_COOLDOWN:
			# クールダウン（回CH-7）。⚠ 宛先はスキルの target。
			for t: BattleUnit in targets:
				t.reduce_cooldowns(
					effect.get("skills", SkillSchema.COOLDOWN_SKILLS_ALL),
					str(effect.get(SkillSchema.COOLDOWN_FIELD_EXCEPT, "")),
					float(effect.get("sec", 0.0)), float(effect.get("pct", 0.0)),
					bool(effect.get("all", false))
				)
		elif effect_type == SkillSchema.EFFECT_DISPEL:
			# 解除（回CH-7）。⚠ registry は StatusRegistry（RefCounted で受けている＝相互参照を避ける）。
			# ⚠ 回GS-1：control があればその状態だけ（投げ縄でステルス）。
			for t: BattleUnit in targets:
				if effect.has("control"):
					registry.dispel_control(t.unit_id, str(effect.get("control", "")))
				else:
					registry.dispel(t.unit_id, str(effect.get("what", "")) == SkillSchema.DISPEL_DEBUFF)
		elif effect_type == SkillSchema.EFFECT_CORPSE_BLAST:
			_apply_corpse_blast(effect, user, results, session, registry, is_dot)
		elif effect_type == SkillSchema.EFFECT_BASIC_ATTACK:
			# 自分の通常攻撃を撃つ（回GS-1）。⚠ 撃つのは戦闘の画面（⚠ 結果に載せるだけ）・近い順。
			var order: Array = targets.duplicate()
			order.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return absf(a.x - user.x) < absf(b.x - user.x))
			var ids: Array = []
			for t: BattleUnit in order:
				ids.append(t.unit_id)
			if not ids.is_empty():
				results.append({"kind": SkillSchema.EFFECT_BASIC_ATTACK, "source_unit_id": user.unit_id, "target_ids": ids})
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

	# 避けて反撃（回MC-1）。⚠ 相手からの攻撃だけ（⚠ 毒の周期では避けない）。⚠ 乱数を振る前に返す（⚠ 振る回数を変えない）。
	if not is_dot and user.team != target.team and registry != null:
		var evade: Dictionary = registry.take_evade(target.unit_id)
		if not evade.is_empty():
			BattleLog.log_intervene("evade", target.unit_id, "", user.unit_id)
			# ⚠ 画面に「回避」を出す（⚠ 結果に載せるだけ＝数字は出さない・召喚と同じ kind の1件）。
			results.append({"kind": SkillSchema.FIELD_EVADE, "unit_id": target.unit_id, "source_unit_id": user.unit_id})
			for raw: Variant in (evade.get("effects", []) as Array):
				if raw is Dictionary:
					results.append_array(resolve({"effects": [raw]}, target, session, [user.unit_id], registry))
			return

	# 空中（回MG-1）。⚠ 地面を狙う攻撃は当たらない（⚠ 数字も出さない）。
	if bool(effect.get(SkillSchema.FIELD_GROUND, false)) and target.airborne:
		BattleLog.log_intervene("airborne", target.unit_id, "", user.unit_id)
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
		# ⚠ 実体を持たせる（EXEC_SKILL_MITIGATION.md §0-1 の1）。介入点は
		#   「殴った側の状態（貫通・確定クリティカル）」と「殴られた側の状態
		#   （軽減・シールド・反射）」の両方を読むので、IDだけでは足りない。
		# ⚠ 回復の ctx が既に target の実体を持っており、形を揃えてある。
		# ⚠ ID の欄は消さないこと。results の組み立てが読んでいる。
		"user": user,
		"target": target,
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

	# 相手の状態で強くなる（回CH-8）。⚠ roll_crit() は振ったあと＝乱数の順番を変えない。
	if effect.has(SkillSchema.FIELD_WHEN_TARGET) and when_target_ok(effect, target, registry, user):
		if effect.has(SkillSchema.FIELD_WHEN_MULT):
			ctx["multiplier"] = float(ctx["multiplier"]) * float(effect.get(SkillSchema.FIELD_WHEN_MULT, 1.0))
		if bool(effect.get(SkillSchema.FIELD_WHEN_CRIT, false)):
			ctx["is_crit"] = true
	# 相手の状態で常に強い（回VP-1）・付けた人から受ける・毎秒の倍・状態の数だけ（回ST-1）・次の通常攻撃（回GS-1）。⚠ 和で足す（⚠ この器はみなそう）。
	if registry != null:
		var bonus_vs: int = int(registry.bonus_vs_pct(user.unit_id, target.unit_id)) \
				+ (int(registry.basic_taken_pct(target.unit_id, int(effect.get("_basic_cast", 0)))) if bool(effect.get("_basic", false)) else 0) \
				+ int(registry.taken_from_source_pct(target.unit_id, user.unit_id)) \
				+ int(registry.bonus_per_dot_pct(user.unit_id, target.unit_id)) \
				+ (int(registry.dot_taken_pct(target.unit_id)) if is_dot else 0)
		if bonus_vs != 0:
			ctx["multiplier"] = float(ctx["multiplier"]) * (1.0 + float(bonus_vs) / 100.0)
	# 処刑のボス（回CH-8）。⚠ ボスは倒さない代わりにダメージを上げる。
	if effect.has(SkillSchema.FIELD_EXECUTE_BELOW) and target.is_boss:
		ctx["multiplier"] = float(ctx["multiplier"]) * float(effect.get(SkillSchema.FIELD_EXECUTE_BOSS_MULT, 1.0))

	# 介入点。段階1は全部素通し。
	# ⚠ 1本の固定式にまとめないこと（PLAN 11-0-1）。まとめると、割り込む位置が
	#   増えるたびに式を書き換えることになり、途中の値も取り出せなくなる。
	_step_crit_override(ctx, registry)
	_step_reduction(ctx, registry)

	# ここで確定する。以降は再計算しない。
	ctx["amount"] = BattleFormula.damage(
		int(ctx["power"]),
		int(ctx["defense"]),
		float(ctx["multiplier"]),
		int(ctx["crit_dmg"]),
		bool(ctx["is_crit"])
	)

	# 【第2段】確定した数値を消費する。
	# ⚠ シールドは take_damage() の前（amount を減らせるのはここだけ）。
	# ⚠ 反射は take_damage() の後（「実際に減ったHP」を基準にするため）。
	# 無敵（回CH-5）。⚠ 相手からのダメージを 0 にする（⚠ 数字を出さない＝results に積まない）。
	if target.invulnerable and user.team != target.team:
		BattleLog.log_intervene("invulnerable", target.unit_id, "", "%d -> 0" % int(ctx["amount"]))
		ctx["amount"] = 0
	_step_shield(ctx, registry)
	if int(ctx["amount"]) > 0:
		target.last_attacker_id = user.unit_id
	target.take_damage(int(ctx["amount"]))
	_apply_reflect(ctx, registry, results, is_dot)

	# ⚠ 吸い切ったときに results へ積まない。積むと頭上に「0」が浮かぶ
	#   （緑でも赤でもない数字が出て、何が起きたのか画面から読めない）。
	#   何が起きたかは intervene の kind: "shield" が記録している。
	if int(ctx["amount"]) <= 0:
		return
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
	_step_drain(effect, user, target, int(ctx["amount"]), results, registry)
	_step_execute(effect, user, target, results)
	_step_on_kill(effect, user, target, results, session, registry)


# 吸収（回GM-1・神の使いのパッシブ「聖なる炎が与えるダメージの15%を回復」）。⚠ 印（tag）の付いたダメージだけ。
# ⚠ 回復は被回復の介入点を通す（⚠ ネクロの「回復量低下」も効く）。
# ⚠ 回VP-1：効果ごとの吸収（drain_pct・相手の状態で when_drain_mult 倍）も**同じ口**で足し合わせる＝吸収は1本。
static func _step_drain(effect: Dictionary, user: BattleUnit, target: BattleUnit, amount: int, results: Array, registry: RefCounted) -> void:
	if registry == null or amount <= 0 or not user.is_alive():
		return
	var pct: float = 0.0
	var tag: String = str(effect.get(SkillSchema.FIELD_TAG, ""))
	# ⚠ 回PX-1：印の無い吸収・相手の状態つきの吸収もここで足す（⚠ 印が無くても見る）。
	pct += float(registry.drain_pct(user.unit_id, tag, target.unit_id))
	if effect.has(SkillSchema.FIELD_DRAIN_PCT):
		var own: float = float(effect.get(SkillSchema.FIELD_DRAIN_PCT, 0.0))
		if effect.has(SkillSchema.FIELD_WHEN_DRAIN_MULT) and when_target_ok(effect, target, registry):
			own *= float(effect.get(SkillSchema.FIELD_WHEN_DRAIN_MULT, 1.0))
		pct += own
	if pct <= 0.0:
		return
	var base: int = int(floor(float(amount) * pct / 100.0))
	var ctx: Dictionary = { "target": user, "base": base, "amount": base, "pct": 0 }
	_step_heal_taken(ctx, registry)
	if int(ctx["amount"]) <= 0:
		return
	user.heal(int(ctx["amount"]))
	BattleLog.log_intervene("drain", user.unit_id, tag, "%d" % int(ctx["amount"]))
	results.append({ "unit_id": user.unit_id, "amount": int(ctx["amount"]), "is_heal": true, "is_crit": false, "is_dot": false })


# この攻撃で倒したら（回GM-1）。⚠ 処刑のあとに見る（⚠ 処刑で倒しても数える）。
# ⚠ when_status は倒れた瞬間の相手の状態（⚠ 状態が消えるのは次の tick＝ここではまだ見える）。
static func _step_on_kill(
		effect: Dictionary, user: BattleUnit, target: BattleUnit, results: Array,
		session: BattleSession, registry: RefCounted
) -> void:
	var on_kill: Variant = effect.get(SkillSchema.FIELD_ON_KILL, null)
	if not (on_kill is Dictionary) or target.is_alive():
		return
	var when_status: String = str((on_kill as Dictionary).get("when_status", ""))
	if when_status != "" and (registry == null or not bool(registry.has({"host_unit_id": target.unit_id, "status_id": when_status}))):
		return
	BattleLog.log_intervene("on_kill", target.unit_id, when_status, user.unit_id)
	for raw: Variant in ((on_kill as Dictionary).get("effects", []) as Array):
		if not (raw is Dictionary):
			continue
		var ids: Array = select_targets((raw as Dictionary).get("target", {}) as Dictionary, user, session)
		results.append_array(resolve({"effects": [raw]}, user, session, ids, registry))


# 処刑（回CH-8）。⚠ 当たったあとの HP で見る（人間「⚠ ２あ」）。⚠ ボス・無敵は倒さない。
# ⚠ 残りの HP を1件のダメージとして積む（⚠ 数字が出る・「与えた」の合図も出る）。
static func _step_execute(effect: Dictionary, user: BattleUnit, target: BattleUnit, results: Array) -> void:
	if not effect.has(SkillSchema.FIELD_EXECUTE_BELOW) or target.is_boss or not target.is_alive():
		return
	if target.invulnerable and user.team != target.team:
		return
	if target.max_hp <= 0 or float(target.hp) / float(target.max_hp) > float(effect.get(SkillSchema.FIELD_EXECUTE_BELOW, 0.0)):
		return
	var rest: int = target.hp
	target.last_attacker_id = user.unit_id
	target.take_damage(rest)
	BattleLog.log_intervene("execute", target.unit_id, "", "%d" % rest)
	results.append({
		"unit_id": target.unit_id,
		"amount": rest,
		"is_heal": false,
		"is_crit": false,
		"is_dot": false,
		"source_unit_id": user.unit_id,
		"attack_type": SkillSchema.ATTACK_TYPE_TRUE,
	})


# 決まった相手の周り（回MG-1・上乗せの「相手の周り」）。⚠ チームは target の team（相手側ならステルスを外す）。
static func area_around(target_def: Dictionary, user: BattleUnit, center: BattleUnit, session: BattleSession) -> Array:
	var team: String = user.team
	if str(target_def.get("team", "")) == SkillSchema.TEAM_ENEMY:
		team = BattleUnit.TEAM_ENEMY if user.team == BattleUnit.TEAM_PARTY else BattleUnit.TEAM_PARTY
	var ids: Array = []
	for raw: Variant in session.get_targetable_units(team, user.team):
		if absf((raw as BattleUnit).x - center.x) <= float(target_def.get("radius", 0.0)):
			ids.append((raw as BattleUnit).unit_id)
	return ids


# 貫通の対象（回PQ-2）。⚠ 自分から前へ length の中の、生きている相手を近い順に。⚠ ID で返す（select_targets と同じ）。
static func select_pierce(user: BattleUnit, session: BattleSession, length: float) -> Array:
	var ids: Array = []
	if user == null or session == null:
		return ids
	var foe_team: String = BattleUnit.TEAM_ENEMY if user.team == BattleUnit.TEAM_PARTY else BattleUnit.TEAM_PARTY
	var forward: float = 1.0 if user.team == BattleUnit.TEAM_PARTY else -1.0
	var found: Array = []
	for raw: Variant in session.get_alive_units(foe_team):
		var u: BattleUnit = raw as BattleUnit
		var ahead: float = (u.x - user.x) * forward
		if ahead >= 0.0 and ahead <= length:
			found.append(u)
	found.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool: return absf(a.x - user.x) < absf(b.x - user.x))
	for u: BattleUnit in found:
		ids.append(u.unit_id)
	return ids


# 自分についての条件（回PQ-1）。⚠ いまは「自分の周り radius の中にいる、生きている敵の数」だけ。
static func when_user_ok(effect: Dictionary, user: BattleUnit, session: BattleSession) -> bool:
	if user == null or session == null:
		return false
	var when: Dictionary = effect.get(SkillSchema.FIELD_WHEN_USER, {}) as Dictionary
	var source: String = str(when.get("source", ""))
	if not (source in SkillSchema.WHEN_USER_SOURCES):
		return false
	var foe_team: String = BattleUnit.TEAM_ENEMY if user.team == BattleUnit.TEAM_PARTY else BattleUnit.TEAM_PARTY
	var radius: float = float(when.get("radius", 0.0))
	# 後ろ（回MC-1）＝前の逆。⚠ 前＝相手の陣の向き（味方は右）。
	var forward: float = 1.0 if user.team == BattleUnit.TEAM_PARTY else -1.0
	var count: int = 0
	for raw: Variant in session.get_alive_units(foe_team):
		var dx: float = (raw as BattleUnit).x - user.x
		if absf(dx) > radius:
			continue
		if source == SkillSchema.WHEN_ENEMIES_BEHIND and dx * forward >= 0.0:
			continue
		count += 1
	var limit: float = float(when.get("value", 0.0))
	match str(when.get("op", "")):
		SkillSchema.COND_OP_LT:
			return count < limit
		SkillSchema.COND_OP_LTE:
			return count <= limit
		SkillSchema.COND_OP_GT:
			return count > limit
		SkillSchema.COND_OP_GTE:
			return count >= limit
		SkillSchema.COND_OP_EQ:
			return is_equal_approx(float(count), limit)
	return false


# 相手についての条件（回CH-8）。⚠ registry は StatusRegistry（RefCounted で受けている）。
static func when_target_ok(effect: Dictionary, target: BattleUnit, registry: RefCounted, user: BattleUnit = null) -> bool:
	if target == null:
		return false
	var when: Dictionary = effect.get(SkillSchema.FIELD_WHEN_TARGET, {}) as Dictionary
	var source: String = str(when.get("source", ""))
	# どれか1つ（回GS-1）。⚠ 中身を1つずつ同じ関数で見る。
	if source == SkillSchema.WHEN_ANY:
		for sub_when: Variant in (when.get("of", []) as Array):
			if sub_when is Dictionary and when_target_ok({SkillSchema.FIELD_WHEN_TARGET: sub_when}, target, registry, user):
				return true
		return false
	# 前と違う相手（回GS-1）。⚠ 撃つ前の相手と比べる（⚠ 撃った瞬間に今の相手へ書き換わるため）。
	if source == SkillSchema.WHEN_NEW_TARGET:
		return user != null and target.unit_id != user.prev_basic_target_id
	if source == SkillSchema.WHEN_STATUS_HAS:
		return registry != null and bool(registry.has({
			"host_unit_id": target.unit_id, "status_id": str(when.get("status_id", "")),
		}))
	var value: float = 0.0
	if source == SkillSchema.WHEN_DEBUFF_COUNT:
		value = 0.0 if registry == null else float(registry.debuff_count(target.unit_id))
	elif source == SkillSchema.WHEN_HP_RATIO:
		value = 0.0 if target.max_hp <= 0 else float(target.hp) / float(target.max_hp)
	else:
		return false
	var limit: float = float(when.get("value", 0.0))
	match str(when.get("op", "")):
		SkillSchema.COND_OP_LT:
			return value < limit
		SkillSchema.COND_OP_LTE:
			return value <= limit
		SkillSchema.COND_OP_GT:
			return value > limit
		SkillSchema.COND_OP_GTE:
			return value >= limit
		SkillSchema.COND_OP_EQ:
			return is_equal_approx(value, limit)
	return false


# 確定クリティカル（EXEC_SKILL_MITIGATION.md）。⚠ 読むのは「殴った側」の状態。
#
# ⚠ 位置が要件。roll_crit() のあと・BattleFormula.damage() の前でなければ、
#   確定クリティカルを後から足せない（PLAN 11-2）。
# ⚠ roll_crit() を振り直さないこと。結果を上書きするだけ。振り直すと乱数を
#   引く回数が状態の有無で変わり、同じ入力で違うログが出る（PLAN 11-0）。
# ⚠ 既に会心だったときは記録しない（素通しは出さない・battle_log.gd:302）。
static func _step_crit_override(ctx: Dictionary, registry: RefCounted) -> void:
	if registry == null:
		return
	if bool(ctx.get("is_crit", false)):
		return
	var user: BattleUnit = ctx.get("user", null)
	if user == null:
		return
	if not bool(registry.has_crit_always(user.unit_id)):
		return
	ctx["is_crit"] = true
	BattleLog.log_intervene("crit", user.unit_id, "", "forced")


# 軽減% / 貫通%（EXEC_SKILL_MITIGATION.md）。defense と multiplier を触れる位置。
#
# ⚠ 順は貫通 → 軽減。攻撃側を先に解決してから守備側を掛ける。
# ⚠ 貫通は「殴った側」、軽減は「殴られた側」の状態。読み違えると
#   「効いているのに効かない」になり、エラーは1つも出ない。
# ⚠ 上限は registry 側（damage_taken_pct / pierce_pct）が掛けている。ここで2重に
#   掛けないこと。
static func _step_reduction(ctx: Dictionary, registry: RefCounted) -> void:
	if registry == null:
		return
	var user: BattleUnit = ctx.get("user", null)
	var target: BattleUnit = ctx.get("target", null)

	if user != null:
		var pierce: int = int(registry.pierce_pct(user.unit_id))
		if pierce > 0 and int(ctx.get("defense", 0)) > 0:
			var before: int = int(ctx["defense"])
			ctx["defense"] = int(floor(float(before) * float(100 - pierce) / 100.0))
			BattleLog.log_intervene("pierce", user.unit_id, "", "%d%% def %d->%d" % [
				pierce, before, int(ctx["defense"])
			])

	if target != null:
		var reduction: int = int(registry.damage_taken_pct(target.unit_id))
		if reduction > 0:
			ctx["multiplier"] = float(ctx.get("multiplier", 0.0)) * float(100 - reduction) / 100.0
			BattleLog.log_intervene("reduction", target.unit_id, "", "%d%%" % reduction)


# シールド（EXEC_SKILL_MITIGATION.md）。⚠ 確定した amount を肩代わりさせる。
#
# ⚠ take_damage() の前でなければならない。あとに置くと、HPが減ってから減らし直す
#   ことになり、2段構え（確定したら再計算しない・PLAN 11-0）を破る。
# ⚠ 残量を減らすのは registry の仕事。ここは金額を引くだけ。
static func _step_shield(ctx: Dictionary, registry: RefCounted) -> void:
	if registry == null:
		return
	var target: BattleUnit = ctx.get("target", null)
	if target == null:
		return
	var amount: int = int(ctx.get("amount", 0))
	if amount <= 0:
		return
	var absorbed: int = int(registry.consume_shield(target.unit_id, amount))
	if absorbed <= 0:
		return
	ctx["amount"] = amount - absorbed
	ctx["shielded"] = absorbed
	BattleLog.log_intervene("shield", target.unit_id, "", "%d absorbed (%d->%d)" % [
		absorbed, amount, int(ctx["amount"])
	])


# 反射（EXEC_SKILL_MITIGATION.md・人間の決定1・3・4）。
#
# ⚠ ここから _apply_damage() を呼ばないこと。反射を持つ者同士が殴り合うと
#   止まらなくなる（フレームが落ちるだけで、エラーは1つも出ない）。
#   深さの欄やカウンターで止めない。「呼ばない」ことで止める。
# ⚠ reflect_pct は「実際に減ったHP」基準（シールドが全部吸ったら 0）。
#   reflect_flat は殴られたら必ず返す（シールドが全部吸っても返る）。
# ⚠ DoT は反射しない。毒を「殴り返す」相手が居ない（source は付けた本人で、
#   その場に居るとは限らない）。
# ⚠ 反射で攻撃者が死んでも、ここで死亡処理を書かないこと。
#   BattleController._step_deaths() が次のフレームに全ユニットを走査して拾う
#   （復活の介入点もそちらを通る）。
static func _apply_reflect(
		ctx: Dictionary, registry: RefCounted, results: Array, is_dot: bool
) -> void:
	if registry == null or is_dot:
		return
	var user: BattleUnit = ctx.get("user", null)
	var target: BattleUnit = ctx.get("target", null)
	if user == null or target == null:
		return
	# ⚠ 自分で自分を殴った場合は返さない（無限に往復する）。
	if user.unit_id == target.unit_id:
		return
	if not user.is_alive():
		return

	var pct: int = int(registry.reflect_pct(target.unit_id))
	var flat: int = int(registry.reflect_flat(target.unit_id))
	if pct <= 0 and flat <= 0:
		return

	var back: int = flat
	if pct > 0:
		back += int(floor(float(int(ctx.get("amount", 0))) * float(pct) / 100.0))
	if back <= 0:
		return

	user.last_attacker_id = target.unit_id
	user.take_damage(back)
	BattleLog.log_intervene("reflect", target.unit_id, "", "%d to %s" % [back, user.unit_id])
	# ⚠ 既存4キーの形をそのまま使う（skill_resolver.gd:424）。
	#   unit_id ＝ 食らった側（＝殴ってきた者）／ source_unit_id ＝ 反射した側。
	results.append({
		"unit_id": user.unit_id,
		"amount": back,
		"is_heal": false,
		"is_crit": false,
		"is_dot": false,
		"source_unit_id": target.unit_id,
		"attack_type": SkillSchema.ATTACK_TYPE_TRUE,
	})


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


# 召喚（type: "summon"・段階6・PLAN 14-2）。
#
# ⚠ ここでユニットもノードも作らない。この層は RefCounted で、ノードツリーも
#   BattleSession の配列の作り直しも知らない（契約・PLAN 7-3）。results に1件
#   流すだけで、生やすのは battle_controller（投射物が signal で頼むのと同じ形）。
# ⚠ target_ids を読まない。召喚は対象を取らない（E98 が target を赤で弾いている）。
#   スキルの top-level に書いてある target は選抜されるだけで当たらない。
# ⚠ 数値の欄は float() で包む。MasterDataLoader は JSON の数値を float で返す
#   （CLAUDE.md 3番）。count だけは体数なので int() に落とす。
# ⚠ "unit_id" の名前で入れないこと。既存の1件では「殴られた側」の意味で、
#   battle_controller の _on_skill_effects_applied() が _find_unit_by_id() に渡す。
# 押し出す（回CH-5）。⚠ 座標はここで触らない（⚠ 戦闘の画面が端で止めて動かす＝結果に載せるだけ）。
# ⚠ 止められない・無敵（相手から）は受けない。⚠ ボスは距離に `boss_control_ratio` を掛ける（人間「⚠ ２う」）。
static func _apply_knockback(effect: Dictionary, user: BattleUnit, target: BattleUnit, results: Array) -> void:
	if target == null or not target.is_alive():
		return
	if target.unstoppable or (target.invulnerable and user.team != target.team):
		BattleLog.log_intervene("knockback", target.unit_id, "", "blocked")
		return
	var distance: float = float(effect.get("distance", 0.0))
	if target.is_boss:
		distance *= float(Balance.adventure.boss_control_ratio)
	if distance <= 0.0:
		return
	# ⚠ 撃った人から遠ざける。⚠ 同じ位置なら相手の陣の向き（味方は左＝負・敵は右＝正）。
	var dir: float = sign(target.x - user.x)
	if dir == 0.0:
		dir = -1.0 if target.team == BattleUnit.TEAM_PARTY else 1.0
	results.append({
		"kind": SkillSchema.EFFECT_KNOCKBACK,
		"unit_id": target.unit_id,
		"source_unit_id": user.unit_id,
		"dx": dir * distance,
	})


# 自分が動く（回CH-6）。⚠ 座標はここで触らない（⚠ 行き先 x を結果に載せる・端で止めて動かすのは戦闘の画面）。
# ⚠ スネア中は動かない（⚠ 設計役の仮）。⚠ スタン中はスキル自体が撃てない（SkillActivation）。
static func _apply_dash(effect: Dictionary, user: BattleUnit, targets: Array, results: Array) -> void:
	if user.snared:
		BattleLog.log_intervene("dash", user.unit_id, "", "snared")
		return
	# ⚠ 前＝相手の陣の向き（味方は右＝正・敵は左＝負）。
	var forward: float = 1.0 if user.team == BattleUnit.TEAM_PARTY else -1.0
	var to_x: float = user.x
	if str(effect.get("to", "")) == SkillSchema.DASH_TO_AIM and user.has_aim:
		# 狙いの場所へ（回VP-1）。⚠ 狙いが無いとき（自動戦闘・敵）は下の to: target と同じ。
		to_x = user.aim_x
	elif str(effect.get("to", "")) == SkillSchema.DASH_TO_BACK:
		to_x = user.x - forward * float(effect.get("distance", 0.0))
	else:
		var alive: Array = []
		for t: BattleUnit in targets:
			if t != null and t.is_alive():
				alive.append(t)
		if alive.is_empty():
			return
		var center: float = 0.0
		for t: BattleUnit in alive:
			center += t.x
		center /= float(alive.size())
		# ⚠ 手前で止まる＝来た側へ offset だけ戻す。⚠ 同じ位置なら前から来た扱い。
		var from_dir: float = sign(center - user.x)
		if from_dir == 0.0:
			from_dir = forward
		to_x = center - from_dir * float(effect.get("offset", 0.0))
	results.append({
		"kind": SkillSchema.EFFECT_DASH,
		"unit_id": user.unit_id,
		"source_unit_id": user.unit_id,
		"x": to_x,
	})


# 固有の資源（回CH-1）。⚠ 宛先は撃った本人だけ（⚠ target_ids を読まない）。
# ⚠ 0〜max に切るのは BattleUnit の側（⚠ ここで切らない）。
static func _apply_resource(
		effect: Dictionary, user: BattleUnit, targets: Array, registry: RefCounted,
		session: BattleSession, results: Array
) -> void:
	var resource_id: String = str(effect.get(SkillSchema.RESOURCE_FIELD_ID, ""))
	var before: int = user.get_resource(resource_id)
	if effect.has(SkillSchema.RESOURCE_FIELD_SET_TO):
		user.set_resource(resource_id, int(effect.get(SkillSchema.RESOURCE_FIELD_SET_TO, 0)))
	else:
		var amount: int = int(effect.get(SkillSchema.RESOURCE_FIELD_AMOUNT, 0))
		# 相手の状態の数を掛ける（回SC-1）。⚠ 0 なら増えない。
		if effect.has(SkillSchema.RESOURCE_FIELD_PER_STACK):
			var stacks: int = 0
			if registry != null:
				for t: BattleUnit in targets:
					stacks += int(registry.count_stacks(t.unit_id, str(effect.get(SkillSchema.RESOURCE_FIELD_PER_STACK, ""))))
			amount *= stacks
		user.add_resource(resource_id, amount)
	print("[SkillResolver] resource %s.%s %d -> %d" % [
		user.unit_id, resource_id, before, user.get_resource(resource_id)
	])
	_resource_on_full(user, resource_id, registry, session, results)


# 満タンになったら払って効果を撃つ（回NC-1・ネクロ「⚠ 魂ストックがたまるとゾンビを召喚する」）。
# ⚠ 資源の定義（characters.json の resources[]）に `"on_full": {"spend": 10, "effects": [...]}`。
# ⚠ 合図（購読）にしない：⚠ 魂は購読の中で増えるので、購読から生まれた行動は反応を生まない（10-2）に止められる。
# ⚠ 撃つ効果は召喚だけ（⚠ MasterDataLoader が見る）。⚠ results に足す＝召喚と同じ道で戦闘の画面が生やす。
static func _resource_on_full(
		user: BattleUnit, resource_id: String, registry: RefCounted,
		session: BattleSession, results: Array
) -> void:
	var def: Dictionary = user.resource_def(resource_id)
	var on_full: Variant = def.get("on_full", null)
	if not (on_full is Dictionary):
		return
	if user.get_resource(resource_id) < int(def.get("max", 0)):
		return
	user.add_resource(resource_id, -int((on_full as Dictionary).get("spend", 0)))
	print("[SkillResolver] resource %s.%s full -> spend %d" % [
		user.unit_id, resource_id, int((on_full as Dictionary).get("spend", 0))
	])
	for raw: Variant in ((on_full as Dictionary).get("effects", []) as Array):
		if raw is Dictionary:
			results.append_array(resolve({"effects": [raw]}, user, session, [], registry))


# 自分の召喚を使う（回NC-1）。⚠ 古い順＝summon_units の並び（⚠ 生やした順に足してある）。
# ⚠ ここでは消さない（⚠ 結果に載せるだけ・消すのは戦闘の画面＝召喚と同じ）。
# ⚠ blast_radius があれば、消える1体ごとに「その位置から半径の中の敵」へダメージ（⚠ 威力は撃った本人）。
static func _apply_summon_consume(
		effect: Dictionary, user: BattleUnit, results: Array,
		session: BattleSession, registry: RefCounted, is_dot: bool
) -> void:
	var picked: Array = own_summons(user, session, effect.get(SkillSchema.CONSUME_FIELD_UNIT_IDS, []) as Array)
	var raw_count: Variant = effect.get("count", 0)
	if not (raw_count is String and str(raw_count) == SkillSchema.CONSUME_COUNT_ALL):
		picked = picked.slice(0, int(float(raw_count)))
	if picked.is_empty():
		return
	if effect.has(SkillSchema.CONSUME_FIELD_BLAST_RADIUS):
		var radius: float = float(effect.get(SkillSchema.CONSUME_FIELD_BLAST_RADIUS, 0.0))
		var foe_team: String = BattleUnit.TEAM_ENEMY if user.team == BattleUnit.TEAM_PARTY else BattleUnit.TEAM_PARTY
		for z: BattleUnit in picked:
			for raw_foe: Variant in session.get_alive_units(foe_team):
				var foe: BattleUnit = raw_foe as BattleUnit
				if absf(foe.x - z.x) <= radius:
					_apply_damage(effect, user, foe, results, session, registry, is_dot)
	var ids: Array = []
	for z: BattleUnit in picked:
		ids.append(z.unit_id)
	results.append({
		"kind": SkillSchema.EFFECT_SUMMON_CONSUME,
		"source_unit_id": user.unit_id,
		"summon_ids": ids,
	})


# 死体の爆破（回MG-1）。⚠ 自分から range の中の倒れた相手ごとに、その場所で周りを爆発（⚠ 1体1回）。⚠ 威力は撃った本人。
static func _apply_corpse_blast(
		effect: Dictionary, user: BattleUnit, results: Array,
		session: BattleSession, registry: RefCounted, is_dot: bool
) -> void:
	var foe_team: String = BattleUnit.TEAM_ENEMY if user.team == BattleUnit.TEAM_PARTY else BattleUnit.TEAM_PARTY
	var corpses: Array = []
	for raw: Variant in (session.enemy_units if foe_team == BattleUnit.TEAM_ENEMY else session.party_units):
		var c: BattleUnit = raw as BattleUnit
		if c != null and not c.is_alive() and not c.corpse_used and absf(c.x - user.x) <= float(effect.get("range", 0.0)):
			corpses.append(c)
	var radius: float = float(effect.get(SkillSchema.CONSUME_FIELD_BLAST_RADIUS, 0.0))
	for c: BattleUnit in corpses:
		c.corpse_used = true
		BattleLog.log_intervene("corpse_blast", c.unit_id, "", user.unit_id)
		for raw_foe: Variant in session.get_alive_units(foe_team):
			var foe: BattleUnit = raw_foe as BattleUnit
			if absf(foe.x - c.x) <= radius:
				_apply_damage(effect, user, foe, results, session, registry, is_dot)


# 自分の召喚（⚠ 生きているもの・古い順）。⚠ unit_ids の種類だけ（⚠ 撃てるかの判定＝SkillActivation も使う）。
static func own_summons(user: BattleUnit, session: BattleSession, unit_ids: Array) -> Array:
	var list: Array = []
	if user == null or session == null:
		return list
	for raw: Variant in session.summon_units:
		var u: BattleUnit = raw as BattleUnit
		if u != null and u.is_alive() and u.summon_owner_id == user.unit_id and u.summon_kind_id in unit_ids:
			list.append(u)
	return list


static func _apply_summon(effect: Dictionary, user: BattleUnit, results: Array, targets: Array = []) -> void:
	results.append({
		# ⚠ kind を持つのは召喚の1件だけ。既存の damage / heal の1件には足さない
		#   （battle_last.jsonl が1バイト変わる）。
		"kind": SkillSchema.EFFECT_SUMMON,
		"source_unit_id": user.unit_id,
		"summon_unit_id": str(effect.get("unit_id", "")),
		"count": int(float(effect.get("count", 0))),
		"duration_sec": float(effect.get("duration_sec", 0.0)),
		"offset_x": float(effect.get("offset_x", 0.0)),
		# 上限（回NC-1）。⚠ 0＝上限なし（⚠ 書かなければいままでどおり）。
		"max_per_owner": int(float(effect.get(SkillSchema.SUMMON_FIELD_MAX_PER_OWNER, 0))),
		# 置き場所・置く側（回GS-1）。⚠ 相手の真ん中＝この効果の相手の平均。
		"at_x": _center_x(targets, user.x) if str(effect.get(SkillSchema.SUMMON_FIELD_AT, "")) == "target" else NAN,
		"foe_side": str(effect.get(SkillSchema.SUMMON_FIELD_SIDE, "")) == "foe",
	})


static func _center_x(targets: Array, fallback: float) -> float:
	var sum: float = 0.0
	var n: int = 0
	for t: Variant in targets:
		if t is BattleUnit and (t as BattleUnit).is_alive():
			sum += (t as BattleUnit).x
			n += 1
	return fallback if n == 0 else sum / float(n)


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
		session: BattleSession, registry: RefCounted, results: Array
) -> void:
	# host: battle は戦場に1つ付く。対象の数だけ増やさない。
	if str(effect.get("host", "")) == SkillSchema.HOST_BATTLE:
		registry.add(effect, user, null, session)
		return
	for t: BattleUnit in targets:
		if t == null:
			continue
		# 「状態を付けたら」（回VP-1）。⚠ 付いたときだけ結果に載せる＝SkillRuntime が付けた人へ合図を配る。
		if registry.add(effect, user, t, session):
			results.append({
				"kind": SkillSchema.EVENT_STATUS_APPLIED, "unit_id": t.unit_id,
				"source_unit_id": user.unit_id, "status_id": str(effect.get("status_id", "")),
			})


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
		# 払った量（回CH-2）。⚠ 撃つ瞬間に fold_resource_spent() が項へ書いた値（⚠ 無ければ 0）。
		if source == SkillSchema.SCALE_RESOURCE_SPENT:
			total += weight * float(entry.get(SkillSchema.SCALE_FIELD_SPENT, 0.0))
			continue
		# 定数（回MC-1）。⚠ weight がそのまま値。
		if source == SkillSchema.SCALE_FLAT:
			total += weight
			continue
		# いまの資源の量（回SC-1）。⚠ 撃った本人の資源。
		if source == SkillSchema.SCALE_RESOURCE_NOW:
			total += weight * float(user.get_resource(str(entry.get(SkillSchema.RESOURCE_FIELD_ID, ""))) if user != null else 0.0)
			continue
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

# 払った量を scale_from の resource_spent の項へ書き込んだ実効データを返す（回CH-2）。
# ⚠ fold_charge_ratio() と同じ形（⚠ resolve() は払ったことを知らずに済む）。
# ⚠ 撃つ瞬間に1回だけ。⚠ 遅れて発火する効果・購読の中にも同じ値が届く。
static func fold_resource_spent(skill_data: Dictionary, spent: int) -> Dictionary:
	var effective: Dictionary = skill_data.duplicate(true)
	var raw_effects: Variant = effective.get("effects", null)
	if raw_effects is Array:
		_fold_spent_into(raw_effects as Array, spent)
	return effective


static func _fold_spent_into(effects: Array, spent: int) -> void:
	for raw_effect: Variant in effects:
		if not (raw_effect is Dictionary):
			continue
		var effect: Dictionary = raw_effect as Dictionary
		var raw_scale: Variant = effect.get("scale_from", null)
		if raw_scale is String and str(raw_scale) == SkillSchema.SCALE_RESOURCE_SPENT:
			effect["scale_from"] = [{"source": SkillSchema.SCALE_RESOURCE_SPENT}]
			raw_scale = effect["scale_from"]
		if raw_scale is Array:
			for term: Variant in (raw_scale as Array):
				if term is Dictionary and str((term as Dictionary).get("source", "")) == SkillSchema.SCALE_RESOURCE_SPENT:
					(term as Dictionary)[SkillSchema.SCALE_FIELD_SPENT] = spent
		var raw_react: Variant = effect.get("react", null)
		if raw_react is Dictionary and (raw_react as Dictionary).get("effects", null) is Array:
			_fold_spent_into((raw_react as Dictionary)["effects"] as Array, spent)


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
	# ⚠ 自分で配列を回さない。BattleSession.find_unit() が唯一の探し方（段階6）。
	if session == null:
		return null
	return session.find_unit(unit_id)
