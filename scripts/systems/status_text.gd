class_name StatusText
extends RefCounted

# 状態1件 → 読める文（10-17・`BT-40`・人間「⚠ 味方のばふでばふを画面の下側から確認できるように詳細も書く」→「⚠ １あ」）。
#
# ⚠⚠ 汎用の1本。⚠ 状態ごとに文を書かない（⚠ 状態には名前も説明も無い＝付けたときの欄から組み立てる）。
#   ⚠ 新しい欄を器（StatusRegistry._make_entry）に足したら、ここに1行足す（⚠ 足さないと吹き出しに出ないだけ＝赤は出ない）。
# ⚠ 値を持たない。⚠ entry は器の本物（⚠ 書き換えない）。
# ⚠ static なので tr() は呼べない（AGENTS.md）＝TranslationServer.translate()。

const ENDLESS_SEC: float = 9999.0


# まとめた札（同じ status_id）1枚ぶんの吹き出しの文。⚠ 見出し・効果・重なり・残り の順に改行で並べる。
static func describe_group(members: Array, session: BattleSession) -> String:
	var live: Array = []
	for raw: Variant in members:
		if raw is Dictionary:
			live.append(raw)
	if live.is_empty():
		return ""
	var first: Dictionary = live[0] as Dictionary
	var lines: Array[String] = []
	var head: String = header(first, session)
	if head != "":
		lines.append(head)
	lines.append_array(describe(first))
	if live.size() > 1:
		lines.append(_t("ui_status_line_stacks") % str(live.size()))
	# 残り：⚠ 中でいちばん長く残る件（⚠ 札の膜と同じ）。
	var best: Dictionary = first
	var best_left: float = _left_sec(first)
	var any_active: bool = false
	for raw: Variant in live:
		var e: Dictionary = raw as Dictionary
		if bool(e.get("active", true)):
			any_active = true
		var left: float = _left_sec(e)
		if left > best_left:
			best_left = left
			best = e
	var life_line: String = life_text(best)
	if life_line != "":
		lines.append(life_line)
	if not any_active:
		lines.append(_t("ui_status_line_inactive"))
	return "\n".join(lines)


# 見出し：⚠ 付けたスキルの名前（付けた人）。⚠ スキルが引けなければ「付けた人 から」。⚠ どちらも無ければ空。
static func header(entry: Dictionary, session: BattleSession) -> String:
	var skill_name: String = skill_name_of(str(entry.get("from_skill_id", "")))
	var unit_name: String = ""
	if session != null:
		var source: BattleUnit = session.find_unit(str(entry.get("source_unit_id", "")))
		if source != null and source.unit_name_key != "":
			unit_name = _t(source.unit_name_key)
	if skill_name != "" and unit_name != "":
		return _t("ui_status_line_header") % [skill_name, unit_name]
	if skill_name != "":
		return skill_name
	if unit_name != "":
		return _t("ui_status_line_from_unit") % unit_name
	return ""


# スキルの名前。⚠ 通常攻撃は「通常攻撃」。⚠ スキルの表に無い ID（ルーン・購読の仮の ID）は空。
static func skill_name_of(skill_id: String) -> String:
	if skill_id == "":
		return ""
	if skill_id == SkillSchema.BASIC_ATTACK_SKILL_ID:
		return _t("ui_status_line_basic_attack_name")
	if not MasterDataLoader.has_skill(skill_id):
		return ""
	var key: String = str(MasterDataLoader.get_skill(skill_id).get("name_key", ""))
	return "" if key == "" else _t(key)


# 効果の行（⚠ 欄ごとに1行）。⚠ 1行も作れなければ「効果あり」の1行。
static func describe(entry: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var kind: String = str(entry.get("kind", ""))

	# --- 能力値 ---
	var stat_key: String = str(entry.get("stat", ""))
	if stat_key != "":
		var stat_name: String = _t("ui_training_stat_" + stat_key)
		var unit: String = "%" if GameManager.is_percent_stat(stat_key) else ""
		if (entry.get(SkillSchema.FIELD_STAT_PCT_FROM, []) as Array).size() > 0:
			lines.append(_t("ui_status_line_stat_varies") % stat_name)
		else:
			var value: int = int(entry.get("value", 0))
			if value != 0:
				lines.append("%s %s" % [stat_name, _signed(value, unit)])
			var pct: int = int(entry.get(SkillSchema.FIELD_STAT_PCT, 0))
			if pct != 0:
				lines.append("%s %s" % [stat_name, _signed(pct, "%")])

	# --- 周期（継続ダメージ・継続回復） ---
	if kind == StatusRegistry.KIND_DOT:
		var every: String = "%.1f" % float(entry.get("interval_sec", 0.0))
		lines.append(_t("ui_status_line_dot_heal" if bool(entry.get("heals", false)) else "ui_status_line_dot_damage") % every)
	if kind == StatusRegistry.KIND_REACT:
		lines.append(_t("ui_status_line_react"))

	# --- 行動 ---
	var control: String = str(entry.get(SkillSchema.BUFF_CONTROL, ""))
	if control != "":
		lines.append(_t("ui_status_line_control_" + control))
	if int(entry.get(SkillSchema.FIELD_MISS_PCT, 0)) != 0:
		lines.append(_t("ui_status_line_miss") % ("%d%%" % int(entry.get(SkillSchema.FIELD_MISS_PCT, 0))))

	# --- 与える・受ける ---
	_add_signed(lines, entry, SkillSchema.BUFF_ATK_MULT_PCT, "ui_status_line_atk_mult")
	_add_signed(lines, entry, SkillSchema.BUFF_HEAL_TAKEN_PCT, "ui_status_line_heal_taken")
	if int(entry.get(SkillSchema.INTERVENE_REDUCTION_PCT, 0)) != 0:
		lines.append(_t("ui_status_line_reduction") % ("%d%%" % int(entry.get(SkillSchema.INTERVENE_REDUCTION_PCT, 0))))
	if int(entry.get(SkillSchema.INTERVENE_PIERCE_PCT, 0)) != 0:
		lines.append(_t("ui_status_line_pierce") % ("%d%%" % int(entry.get(SkillSchema.INTERVENE_PIERCE_PCT, 0))))
	if int(entry.get(SkillSchema.INTERVENE_REFLECT_PCT, 0)) != 0:
		lines.append(_t("ui_status_line_reflect_pct") % ("%d%%" % int(entry.get(SkillSchema.INTERVENE_REFLECT_PCT, 0))))
	if int(entry.get(SkillSchema.INTERVENE_REFLECT_FLAT, 0)) != 0:
		lines.append(_t("ui_status_line_reflect_flat") % str(int(entry.get(SkillSchema.INTERVENE_REFLECT_FLAT, 0))))
	if int(entry.get(SkillSchema.INTERVENE_SHIELD_HP, 0)) > 0:
		lines.append(_t("ui_status_line_shield") % ("%d/%d" % [int(entry.get("counter", 0)), int(entry.get(SkillSchema.INTERVENE_SHIELD_HP, 0))]))
	if bool(entry.get(SkillSchema.INTERVENE_CRIT_ALWAYS, false)):
		lines.append(_t("ui_status_line_crit_always"))
	if int(entry.get(SkillSchema.INTERVENE_DRAIN_PCT, 0)) != 0:
		lines.append(_t("ui_status_line_drain") % ("%d%%" % int(entry.get(SkillSchema.INTERVENE_DRAIN_PCT, 0))))
	_add_signed(lines, entry, SkillSchema.INTERVENE_TAKEN_FROM_SOURCE_PCT, "ui_status_line_taken_from_source")
	_add_signed(lines, entry, SkillSchema.INTERVENE_DOT_TAKEN_PCT, "ui_status_line_dot_taken")
	_add_signed(lines, entry, SkillSchema.INTERVENE_BASIC_TAKEN_PCT, "ui_status_line_basic_taken")
	_add_signed(lines, entry, SkillSchema.INTERVENE_BONUS_PER_DOT_PCT, "ui_status_line_bonus_per_dot")
	_add_signed(lines, entry, SkillSchema.INTERVENE_BONUS_VS_PCT, "ui_status_line_bonus_vs")

	# --- 守り・復活 ---
	var block: Variant = entry.get("block_status", [])
	if block is Array and not (block as Array).is_empty():
		lines.append(_t("ui_status_line_block_status"))
	var on_death: Variant = entry.get("on_death", {})
	if on_death is Dictionary and not (on_death as Dictionary).is_empty():
		var ratio: float = float((on_death as Dictionary).get("revive_hp_ratio", 0.0))
		lines.append(_t("ui_status_line_revive") % ("%d%%" % int(round(ratio * 100.0))))

	# --- 通常攻撃・きっかけ ---
	if entry.get(SkillSchema.BUFF_BASIC_ATTACK, null) is Dictionary:
		lines.append(_t("ui_status_line_basic_attack"))
	if entry.get(SkillSchema.BUFF_BASIC_EXTRA, null) is Dictionary:
		lines.append(_t("ui_status_line_basic_extra"))
	if int(entry.get("uses_left", -1)) > 0:
		lines.append(_t("ui_status_line_uses") % str(int(entry.get("uses_left", 0))))
	var pulse: Variant = entry.get(SkillSchema.FIELD_PULSE, {})
	if pulse is Dictionary and not (pulse as Dictionary).is_empty():
		lines.append(_t("ui_status_line_pulse") % ("%.1f" % float((pulse as Dictionary).get("interval_sec", 0.0))))
	if not (entry.get(SkillSchema.FIELD_EVADE, {}) as Dictionary).is_empty():
		lines.append(_t("ui_status_line_evade"))
	if not (entry.get(SkillSchema.FIELD_ON_MEET, {}) as Dictionary).is_empty():
		lines.append(_t("ui_status_line_on_meet"))
	var on_stack: Dictionary = entry.get(SkillSchema.FIELD_ON_STACK, {}) as Dictionary
	if not on_stack.is_empty():
		lines.append(_t("ui_status_line_on_stack") % str(int(on_stack.get("count", 0))))
	if not (entry.get(SkillSchema.FIELD_ON_SKILL_HIT, {}) as Dictionary).is_empty():
		lines.append(_t("ui_status_line_on_skill_hit"))

	if lines.is_empty():
		lines.append(_t("ui_status_line_unknown"))
	return lines


# 残りの行。⚠ 秒の状態は「残り ◯ 秒」（⚠ とても長いものは「戦闘中ずっと」）。⚠ 次の通常攻撃まで・溜め終わるまで。
static func life_text(entry: Dictionary) -> String:
	var life: String = str(entry.get("life", ""))
	if life == StatusRegistry.LIFE_SEC:
		var duration: float = float(entry.get("duration_sec", 0.0))
		if duration <= 0.0 or duration >= ENDLESS_SEC:
			return _t("ui_status_line_endless")
		return _t("ui_status_line_left_sec") % ("%.1f" % _left_sec(entry))
	if life == SkillSchema.UNTIL_BASIC_END:
		return _t("ui_status_line_until_basic")
	if life == SkillSchema.UNTIL_CHARGE_END:
		return _t("ui_status_line_until_charge")
	return ""


# 残り秒。⚠ 秒の状態でなければ -1（⚠ 比べるとき後ろに回る）。⚠ とても長いものは ENDLESS_SEC。
static func _left_sec(entry: Dictionary) -> float:
	if str(entry.get("life", "")) != StatusRegistry.LIFE_SEC:
		return -1.0
	var duration: float = float(entry.get("duration_sec", 0.0))
	if duration <= 0.0 or duration >= ENDLESS_SEC:
		return ENDLESS_SEC
	return maxf(0.0, duration - float(entry.get("elapsed", 0.0)))


static func _add_signed(lines: Array[String], entry: Dictionary, field: String, key: String) -> void:
	var v: int = int(entry.get(field, 0))
	if v != 0:
		lines.append(_t(key) % _signed(v, "%"))


static func _signed(v: int, unit: String) -> String:
	return ("+%d%s" % [v, unit]) if v > 0 else ("−%d%s" % [absi(v), unit])


static func _t(key: String) -> String:
	return TranslationServer.translate(key)
