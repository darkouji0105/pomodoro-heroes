class_name SkillDetailText
extends RefCounted

# スキルの詳細表示（2026-10-20・回SKD-1・決定 `GR-16`）：⚠ 効果1つ＝アイコン＋1行。
#
# ⚠ 人間「⚠ 後スキルの係数とかも説明したい　詳細表示とかでアイコンとレシオなどを書く」→「⚠ １あ　２あ」：
#   ⚠ 敵の解説の窓と、味方のスキル（スキルを選ぶ窓・スキルの吹き出し）の両方 ／ ⚠ 1効果1行。
#   ⚠ 例：`[攻撃のアイコン] 攻撃力 ×200%　一番近い敵　物理` ／ `[攻撃のアイコン] 攻撃 +6　自分　8秒`。
# ⚠ 文はマスターの効果から毎回組む（⚠ 欄を書き写さない）。⚠ バフ・デバフの中身は戦闘の札と同じ `StatusText.describe()`。
# ⚠ 出すのは効果の一番上の段だけ（⚠ きっかけの中の効果＝on_kill・react の中身などは数えない）。
# ⚠ 静的クラス＝`tr()` は使わない（AGENTS.md）。

const KEY_ICON: String = "icon"
const KEY_TEXT: String = "text"
const GAP: String = "　"


# スキル1つの行（⚠ [{icon, text}]）。⚠ 効果が無ければ空。
static func lines_of_skill(skill_id: String) -> Array[Dictionary]:
	var data: Dictionary = MasterDataLoader.get_skill(skill_id)
	return lines_of_effects(data.get("effects", []) as Array, data.get("target", {}))


# 効果の並びの行（⚠ 敵の通常攻撃にも使う）。⚠ `fallback_target` は効果が target を持たないときの相手（⚠ スキルの target）。
static func lines_of_effects(effects: Array, fallback_target: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw: Variant in effects:
		if raw is Dictionary:
			result.append(_line(raw as Dictionary, fallback_target))
	return result


# ⚠ 字だけの行（⚠ Godot の素の吹き出し用）。
static func plain_text(lines: Array[Dictionary]) -> String:
	var texts: PackedStringArray = PackedStringArray()
	for line: Dictionary in lines:
		texts.append("・" + str(line.get(KEY_TEXT, "")))
	return "\n".join(texts)


static func _line(effect: Dictionary, fallback_target: Variant) -> Dictionary:
	var type: String = str(effect.get("type", ""))
	var target: String = target_text(effect.get("target", fallback_target))
	match type:
		SkillSchema.EFFECT_DAMAGE, SkillSchema.EFFECT_HEAL, SkillSchema.EFFECT_CORPSE_BLAST:
			var parts: Array[String] = [_ratio_text(effect)]
			if type == SkillSchema.EFFECT_HEAL:
				parts[0] = _t("ui_skd_heal") % parts[0]
			parts.append(target)
			if type != SkillSchema.EFFECT_HEAL:
				parts.append(_attack_type_text(effect))
			if int(effect.get(SkillSchema.FIELD_DRAIN_PCT, 0)) > 0:
				parts.append(_t("ui_skd_drain") % int(effect.get(SkillSchema.FIELD_DRAIN_PCT, 0)))
			return _make(_scale_icon(effect) if type != SkillSchema.EFFECT_HEAL else IconTextures.for_skill_role(SkillRole.HEAL), parts)
		SkillSchema.EFFECT_DOT:
			var heals: bool = bool(effect.get("heals", false))
			var every: String = _t("ui_skd_every") % ("%.1f" % float(effect.get("interval_sec", 1.0)))
			var parts: Array[String] = [_t("ui_skd_dot_heal" if heals else "ui_skd_dot") % [every, _ratio_text(effect)], target]
			parts.append(_seconds_text(effect))
			return _make(IconTextures.for_skill_role(SkillRole.HEAL) if heals else _scale_icon(effect), parts)
		SkillSchema.EFFECT_BUFF, SkillSchema.EFFECT_REACT:
			var entry: Dictionary = effect.duplicate(true)
			var intervene: Variant = effect.get(SkillSchema.BUFF_INTERVENE, {})
			if intervene is Dictionary:
				entry.merge(intervene as Dictionary)
			entry["kind"] = StatusRegistry.KIND_REACT if type == SkillSchema.EFFECT_REACT else StatusRegistry.KIND_BUFF
			var parts: Array[String] = [_t("ui_skd_sep").join(StatusText.describe(entry)), target]
			parts.append(_seconds_text(effect))
			var stat: String = str(effect.get("stat", ""))
			var icon: Texture2D = IconTextures.for_stat(stat) if stat != "" else IconTextures.for_skill_role(SkillRole.BUFF if target_team(effect.get("target", fallback_target)) != SkillSchema.TEAM_ENEMY else SkillRole.DEBUFF)
			return _make(icon, parts)
		SkillSchema.EFFECT_STATUS_REF:
			# ⚠ 共通のデバフ（毒・火傷など＝statuses.json）：⚠ 名前 ／ 継続ダメージの倍率 ／ 能力値の下げ ／ 秒 ／ 相手。
			var status_id: String = str(effect.get(SkillSchema.FIELD_STATUS_REF, ""))
			var def: Dictionary = MasterDataLoader.get_status_def(status_id)
			var parts: Array[String] = [_t("ui_status_name_" + status_id)]
			if def.has("multiplier"):
				parts.append(_t("ui_skd_dot") % [_t("ui_skd_every") % ("%.1f" % float(def.get("interval_sec", 1.0))), _ratio_text(def)])
			# ⚠ 周期の行は上で出した＝⚠ ここは「buff」として読み、能力値・行動の行だけ足す。
			var def_entry: Dictionary = def.duplicate(true)
			def_entry["kind"] = StatusRegistry.KIND_BUFF
			for raw: String in StatusText.describe(def_entry):
				if raw != _t("ui_status_line_unknown"):
					parts.append(raw)
			parts.append(_seconds_text(def))
			parts.append(target)
			return _make(IconTextures.for_skill_role(SkillRole.DEBUFF), parts)
		SkillSchema.EFFECT_SUMMON:
			var parts: Array[String] = [_t("ui_skd_summon") % int(effect.get("count", 1))]
			parts.append(_seconds_text(effect))
			return _make(IconTextures.for_skill_role(SkillRole.SUMMON), parts)
		SkillSchema.EFFECT_DASH:
			return _make(IconTextures.for_skill_role(SkillRole.ATTACK), [_t("ui_skd_dash"), target])
	# ⚠ ほかの種類は「種類の名前」＋相手（⚠ 表に無ければ汎用）。
	var key: String = "ui_skd_type_" + type
	var name: String = _t(key)
	return _make(IconTextures.for_skill_role(SkillRole.BUFF), [name if name != key else _t("ui_skd_other"), target])


static func _make(icon: Texture2D, parts: Array[String]) -> Dictionary:
	var kept: Array[String] = []
	for part: String in parts:
		if part != "":
			kept.append(part)
	return {KEY_ICON: icon, KEY_TEXT: GAP.join(kept)}


# 「攻撃力 ×200%」・「攻撃力×100%＋魔力×100% の 10%」（⚠ 元が2つあるとき）。
static func _ratio_text(effect: Dictionary) -> String:
	var pct: int = roundi(float(effect.get("multiplier", 0.0)) * 100.0)
	var scale: Variant = effect.get("scale_from", "atk")
	if scale is Array:
		var sources: PackedStringArray = PackedStringArray()
		for raw: Variant in scale:
			if raw is Dictionary:
				var weight: int = roundi(float((raw as Dictionary).get("weight", 1.0)) * 100.0)
				var name: String = _stat_name(str((raw as Dictionary).get("source", "")))
				sources.append(name if weight == 100 else "%s×%d%%" % [name, weight])
		# ⚠ 元が2つ以上なら括弧でくくる（⚠ 「攻撃力×120%＋失ったHP×15% ×160%」が読みにくかった）。
		var joined: String = "＋".join(sources)
		return _t("ui_skd_ratio") % [joined if sources.size() <= 1 else "（%s）" % joined, pct]
	return _t("ui_skd_ratio") % [_stat_name(str(scale)), pct]


static func _scale_icon(effect: Dictionary) -> Texture2D:
	var scale: Variant = effect.get("scale_from", "atk")
	var key: String = str(scale)
	if scale is Array and not (scale as Array).is_empty() and (scale as Array)[0] is Dictionary:
		key = str(((scale as Array)[0] as Dictionary).get("source", "atk"))
	var icon: Texture2D = IconTextures.for_stat(key)
	return icon if icon != null else IconTextures.for_skill_role(SkillRole.ATTACK)


static func _stat_name(stat_key: String) -> String:
	return _t("ui_skd_stat_" + stat_key) if _t("ui_skd_stat_" + stat_key) != "ui_skd_stat_" + stat_key else _t("ui_training_stat_" + stat_key)


static func _attack_type_text(effect: Dictionary) -> String:
	var kind: String = str(effect.get("attack_type", ""))
	if kind == "":
		return ""
	var key: String = "ui_skd_attack_" + kind
	return _t(key) if _t(key) != key else ""


static func _seconds_text(effect: Dictionary) -> String:
	if effect.has("until"):
		var key: String = "ui_skd_until_" + str(effect.get("until", ""))
		return _t(key) if _t(key) != key else ""
	var sec: float = float(effect.get("duration_sec", 0.0))
	if sec <= 0.0:
		return ""
	if sec >= StatusText.ENDLESS_SEC:
		return _t("ui_status_line_endless")
	# ⚠ 「8秒」「1.5秒」（⚠ GDScript の書式に %g は無い）。
	var sec_text: String = str(int(sec)) if is_equal_approx(sec, roundf(sec)) else "%.1f" % sec
	return _t("ui_skd_seconds") % sec_text


static func target_team(target: Variant) -> String:
	return str((target as Dictionary).get("team", "")) if target is Dictionary else ""


# 相手の字（⚠ 自分 ／ 味方全員 ／ 一番近い敵 ／ 範囲（半径150）の敵 ／ 敵2体 …）。
static func target_text(target: Variant) -> String:
	if not (target is Dictionary):
		return ""
	var t: Dictionary = target
	var team: String = str(t.get("team", ""))
	if team == SkillSchema.TEAM_SELF:
		return _t("ui_skd_target_self")
	if team == SkillSchema.TEAM_SOURCE:
		return _t("ui_skd_target_source")
	var side: String = _t("ui_skd_side_" + team)
	if str(t.get("mode", "")) == "area":
		return _t("ui_skd_target_area") % [int(t.get("radius", 0)), side]
	var sort: String = str(t.get("sort", ""))
	var count: int = int(t.get("count", 1))
	if sort == "all":
		return _t("ui_skd_target_all") % side
	var key: String = "ui_skd_sort_" + sort
	var head: String = _t(key) if sort != "" and _t(key) != key else ""
	if count > 1:
		return _t("ui_skd_target_count") % [head, side, count]
	return head + side


static func _t(key: String) -> String:
	return TranslationServer.translate(key)
