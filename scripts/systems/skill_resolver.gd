class_name SkillResolver
extends RefCounted

# スキル効果の計算を集約する静的クラス。
# Autoload にしない（EXEC §4）。MasterDataLoader と同じ「静的クラス」スタイル。
# 計算式はすべてここに置く。BattleUnit や BattleController に書かない（PLAN §7）。
# 表示（pop_damage 等）は関与しない。戻り値の配列を BattleController に渡し、
# そこで数値表示する。


# skill_data の type に応じて効果を適用し、適用結果の配列を返す。
# 戻り値の各要素: { "unit_id": String, "amount": int, "is_heal": bool }
static func resolve(skill_data: Dictionary, user: BattleUnit, session: BattleSession) -> Array:
	var results: Array = []
	if skill_data == null or skill_data.is_empty():
		push_error("[SkillResolver] skill_data が空")
		return results
	if user == null or session == null:
		push_error("[SkillResolver] user または session が null")
		return results

	var skill_type: String = str(skill_data.get("type", ""))
	var multiplier: float = float(skill_data.get("multiplier", 0.0))

	match skill_type:
		"single":
			_resolve_single(user, session, multiplier, results)
		"aoe":
			_resolve_aoe(user, session, multiplier, results)
		"heal":
			_resolve_heal(user, session, multiplier, results)
		"buff", "dot", "projectile":
			push_warning("[SkillResolver] 未実装のスキルタイプ: " + skill_type)
			return []
		_:
			push_error("[SkillResolver] 不明なスキルタイプ: " + skill_type)
			return []

	return results


# type == "single": 敵の生存者のうち user.x に最も近い1体にダメージ。
# 対象が0体なら何もせず空配列を返す。
static func _resolve_single(user: BattleUnit, session: BattleSession, multiplier: float, results: Array) -> void:
	var targets: Array = session.get_alive_units(BattleUnit.TEAM_ENEMY)
	if targets.is_empty():
		return
	var nearest: BattleUnit = null
	var nearest_dist: float = INF
	for t in targets:
		if not (t is BattleUnit):
			continue
		var d: float = abs(t.x - user.x)
		if d < nearest_dist:
			nearest_dist = d
			nearest = t
	if nearest == null:
		return
	_apply_damage(nearest, user, multiplier, results)


# type == "aoe": 敵の生存者全員にダメージ。対象は必ず TEAM_ENEMY 固定。
# 各ターゲットごとに def を引く（通常攻撃と同じ式）。
static func _resolve_aoe(user: BattleUnit, session: BattleSession, multiplier: float, results: Array) -> void:
	var targets: Array = session.get_alive_units(BattleUnit.TEAM_ENEMY)
	if targets.is_empty():
		return
	for t in targets:
		if not (t is BattleUnit):
			continue
		_apply_damage(t, user, multiplier, results)


# type == "heal": 味方の生存者全員を回復。使用者自身も対象に含まれる。
# max_hp を超えるかは BattleUnit.heal() が担保する。
static func _resolve_heal(user: BattleUnit, session: BattleSession, multiplier: float, results: Array) -> void:
	var targets: Array = session.get_alive_units(BattleUnit.TEAM_PARTY)
	if targets.is_empty():
		return
	var amount: int = int(floor(user.atk * multiplier))
	for t in targets:
		if not (t is BattleUnit):
			continue
		t.heal(amount)
		results.append({ "unit_id": t.unit_id, "amount": amount, "is_heal": true })


# 1体へのダメージ計算と take_damage 適用。
# 必ず max(1, ...) を通す（防御力の高い敵に撃って 0 や負になっても通常攻撃より弱くしない）。
static func _apply_damage(target: BattleUnit, user: BattleUnit, multiplier: float, results: Array) -> void:
	var raw: int = int(floor(user.atk * multiplier)) - target.def
	var dmg: int = max(1, raw)
	target.take_damage(dmg)
	results.append({ "unit_id": target.unit_id, "amount": dmg, "is_heal": false })
