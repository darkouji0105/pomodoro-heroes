class_name SkillRole
extends RefCounted

# スキルの役割（2026-10-19・回SEE29-E・決定 `GR-13`）。
#
# ⚠ 人間「⚠ ビルドのアイコンが読み込まれない？」→ 原因＝スキルの絵が 18 枚しか無い（⚠ スキルは約 180）
#   →「⚠ ７い」＝絵の無いスキルは役割（攻撃・回復など）ごとの共通のアイコン。
# ⚠ 役割はデータに欄を足さず、⚠ **最初の効果の種類と相手**から毎回決める（⚠ スキルを足しても書き足さなくてよい）。
#   ⚠ 相手は効果の `target` があればそれ・無ければスキルの `target`（⚠ 戦闘と同じ読み方）。
# ⚠ 静的クラス＝`tr()` は使わない（AGENTS.md）。

const ATTACK: String = "attack"
const HEAL: String = "heal"
const BUFF: String = "buff"
const DEBUFF: String = "debuff"
const SUMMON: String = "summon"
const ALL: Array[String] = [ATTACK, HEAL, BUFF, DEBUFF, SUMMON]

const _ATTACK_TYPES: Array[String] = [
	SkillSchema.EFFECT_DAMAGE, SkillSchema.EFFECT_DOT, SkillSchema.EFFECT_DASH, SkillSchema.EFFECT_KNOCKBACK,
	SkillSchema.EFFECT_BASIC_ATTACK, SkillSchema.EFFECT_CORPSE_BLAST,
]
const _HEAL_TYPES: Array[String] = [SkillSchema.EFFECT_HEAL, SkillSchema.EFFECT_REVIVE]
const _SUMMON_TYPES: Array[String] = [SkillSchema.EFFECT_SUMMON, SkillSchema.EFFECT_SUMMON_CONSUME]


static func of(skill_id: String) -> String:
	var data: Dictionary = MasterDataLoader.get_skill(skill_id)
	var effects: Variant = data.get("effects", [])
	if not (effects is Array) or (effects as Array).is_empty() or not ((effects as Array)[0] is Dictionary):
		return BUFF
	var first: Dictionary = (effects as Array)[0]
	var type: String = str(first.get("type", ""))
	var target: Variant = first.get("target", data.get("target", {}))
	var team: String = str((target as Dictionary).get("team", "")) if target is Dictionary else ""
	if type in _HEAL_TYPES:
		return HEAL
	if type in _SUMMON_TYPES:
		return SUMMON
	# ⚠ 継続ダメージは相手が敵のときだけ攻撃（⚠ 自分に付ける dot は代償＝強化に寄せる）。
	if type in _ATTACK_TYPES and (team == SkillSchema.TEAM_ENEMY or type != SkillSchema.EFFECT_DOT):
		return ATTACK
	if team == SkillSchema.TEAM_ENEMY:
		return DEBUFF
	return BUFF
