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
	if skill_data == null or skill_data.is_empty():
		return REASON_SKILL_NOT_FOUND
	if not user.is_skill_ready(skill_id):
		return REASON_COOLDOWN

	# 射程で絞った結果が0体なら発動しない（決定1-6）。
	# ⚠ 射程が絞るのはスキルの母集団。効果ごとの target 上書きは見ない
	#   （吸血の「自分に回復」で発動可否が変わるのは誤り・PLAN 4-5）。
	var raw_target: Variant = skill_data.get("target", null)
	if not (raw_target is Dictionary):
		return REASON_SKILL_NOT_FOUND
	if SkillResolver.select_targets(raw_target as Dictionary, user, session).is_empty():
		return REASON_NO_TARGET

	return REASON_OK
