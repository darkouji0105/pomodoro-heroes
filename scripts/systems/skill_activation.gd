class_name SkillActivation
extends RefCounted

# 「そのスキルを今撃てるか」を1箇所で答える静的クラス（PLAN 12章）。
#
# battle_controller に条件を散らさないこと。散らすと、リソースや遮蔽を足すたびに
# 判定が2箇所3箇所に増えて、片方だけ直す事故になる。
#
# ⚠ この関数は状態を1つも変えない。クールダウンを回すのは呼び出し側
#   （CLAUDE.md「状態を変える前に全部の判定を終える」）。

# 撃てない理由。文字列リテラルを散らさないため定数で持つ。
const REASON_OK: String = ""
const REASON_NO_SESSION: String = "no_session"
const REASON_NOT_ACTIVE: String = "not_active"
const REASON_USER_DEAD: String = "user_dead"
const REASON_SKILL_NOT_FOUND: String = "skill_not_found"
const REASON_COOLDOWN: String = "cooldown"
const REASON_NO_TARGET: String = "no_target"
# 資源が足りない（回CH-2・人間「⚠ １あ」＝マスは暗く押せない）。
const REASON_COST: String = "cost"
# スタン中（回CH-5・人間「⚠ １あ」＝スキルも止める）。
const REASON_STUNNED: String = "stunned"


# 資源が足りないか（回CH-2）。⚠ 構え中（2段目以降）は見ない（⚠ 払うのは1段目だけ＝クールダウンと同じ）。
# ⚠ cost は段ではなくスキルの直下にあるので、⚠ 段のデータではなくマスターから引く。
# ⚠ マスの暗転とチャージの押し始めもこれを呼ぶ（⚠ 判定を2本にしない）。
# ⚠ 自分の召喚が足りない（回NC-1・`need_summons`）もここ（⚠ 暗転を同じにする）。⚠ session が無ければ召喚は見ない。
static func is_cost_short(user: BattleUnit, skill_id: String, session: BattleSession = null) -> bool:
	if user == null or user.recast_phase(skill_id) >= 0:
		return false
	var data: Dictionary = MasterDataLoader.get_skill(skill_id)
	if not user.can_pay_cost(SkillSchema.cost_of(data)):
		return true
	# 倒れた味方が居ないと撃てない（回PR-1）。⚠ 暗転は資源が足りないときと同じ。
	if bool(data.get(SkillSchema.FIELD_NEED_FALLEN, false)) and session != null and not SkillResolver.has_fallen_ally(user, session):
		return true
	var need: Variant = data.get(SkillSchema.FIELD_NEED_SUMMONS, null)
	if need is Dictionary and session != null:
		var have: int = SkillResolver.own_summons(
			user, session, (need as Dictionary).get(SkillSchema.CONSUME_FIELD_UNIT_IDS, []) as Array
		).size()
		if have < int(float((need as Dictionary).get("count", 0))):
			return true
	return false


# 撃てない理由を返す。撃てるなら REASON_OK（空文字）。
#
# ⚠ 判定の順番は重い順に後ろ。no_target を最後にするのは select_targets() が
#   一番重いため。
#
# ⚠ 将来ここに足すもの：リソース（マナ・スタック）／発動者が生きているか（召喚）／
#   遮蔽。どれも「行を1本足すだけ」で済む形を保つこと。
static func blocked_reason(
		user: BattleUnit, skill_id: String, skill_data: Dictionary, session: BattleSession
) -> String:
	if session == null:
		return REASON_NO_SESSION
	if session.state != BattleSession.STATE_BATTLE_ACTIVE:
		return REASON_NOT_ACTIVE
	if user == null or not user.is_alive():
		return REASON_USER_DEAD
	if user.stunned:
		return REASON_STUNNED
	if skill_data == null or skill_data.is_empty():
		return REASON_SKILL_NOT_FOUND
	# ⚠ 構え中（recast の2段目以降）はクールダウンを見ない。
	#   クールダウンは1段目で回り始める（人間の決定・2026-08-18）ので、ここで見ると
	#   「同じボタンをもう一度」という再発動の入力が必ず cooldown で弾かれる。
	# ⚠ 「構え中か」は引数で受け取らない。撃てるかの判定はこの関数に集約してある
	#   （PLAN 12章）。bool を引数にすると、呼び出し側が判定を持つことになる。
	if user.recast_phase(skill_id) < 0 and not user.is_skill_ready(skill_id):
		return REASON_COOLDOWN
	if is_cost_short(user, skill_id, session):
		return REASON_COST

	# 射程で絞った結果が0体なら発動しない（決定1-6）。
	# ⚠ 射程が絞るのはスキルの母集団。効果ごとの target 上書きは見ない
	#   （吸血の「自分に回復」で発動可否が変わるのは誤り・PLAN 4-5）。
	var raw_target: Variant = skill_data.get("target", null)
	if not (raw_target is Dictionary):
		return REASON_SKILL_NOT_FOUND
	# ⚠ 狙いを動かして離した（回GM-1）＝人間が選んだ場所なので、空振りでも撃つ（⚠ クールダウンも回る）。
	if user.has_aim and str((raw_target as Dictionary).get("origin", "")) == SkillSchema.ORIGIN_AIM:
		return REASON_OK
	if SkillResolver.select_targets(raw_target as Dictionary, user, session).is_empty():
		return REASON_NO_TARGET

	return REASON_OK
