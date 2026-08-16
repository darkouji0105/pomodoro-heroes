class_name SkillSchema
extends RefCounted

# スキルの器の「語彙」と「1件ぶんの構造検証」だけを持つ静的クラス。
# 決定台帳は docs/01_plan/PLAN_SKILL_TEMPLATE.md、指示書は
# docs/02_exec/EXEC_SKILL_TEMPLATE_PHASE1.md。
#
# 【役割は2つだけ】
#   1. 器の語彙（値の一覧）を1箇所に持つ。値を1個足すときはここと
#      SkillResolver の分岐を1本ずつ触れば済む形に保つ
#   2. スキル1件ぶんの構造を検証する。全件回すのは MasterDataLoader 側
#
# ⚠ このファイルは MasterDataLoader を参照しない。参照すると
#   MasterDataLoader → SkillSchema → MasterDataLoader の循環になる。
#   characters.json と突き合わせる検証（射程）だけは MasterDataLoader 側に置く。
#
# ⚠ ここで push_error / push_warning を呼ばない。呼ぶのは MasterDataLoader 側。
#   件数を数えたいのと、呼ぶ場所を1箇所にするため。

# --- 検証結果の重さ ---
const LEVEL_ERROR: String = "error"
const LEVEL_WARNING: String = "warning"

# --- activation（発動の型） ---
const ACTIVATION_INSTANT: String = "instant"
const ACTIVATION_CHARGE: String = "charge"
# recast / toggle は器に載せるだけ。動くのは段階5以降。
const ACTIVATION_RECAST: String = "recast"
const ACTIVATION_TOGGLE: String = "toggle"
const ACTIVATIONS_KNOWN: Array = [
	ACTIVATION_INSTANT, ACTIVATION_CHARGE, ACTIVATION_RECAST, ACTIVATION_TOGGLE
]

# --- target.team（誰を狙うか。相対で解く） ---
const TEAM_ENEMY: String = "enemy"
const TEAM_ALLY: String = "ally"
const TEAM_SELF: String = "self"
# source は「この効果を起こした相手」。段階3。
const TEAM_SOURCE: String = "source"
const TEAMS_KNOWN: Array = [TEAM_ENEMY, TEAM_ALLY, TEAM_SELF, TEAM_SOURCE]

# --- target.mode（母集団の絞り方） ---
const MODE_SELECT: String = "select"
const MODE_AREA: String = "area"   # 段階4
const MODES_KNOWN: Array = [MODE_SELECT, MODE_AREA]

# --- target.sort（並べ替え） ---
const SORT_NEAREST: String = "nearest"
const SORT_FARTHEST: String = "farthest"
const SORT_LOWEST_HP: String = "lowest_hp"
const SORT_HIGHEST_HP: String = "highest_hp"
const SORT_ALL: String = "all"
const SORTS_KNOWN: Array = [
	SORT_NEAREST, SORT_FARTHEST, SORT_LOWEST_HP, SORT_HIGHEST_HP, SORT_ALL
]

# --- effects[].type ---
const EFFECT_DAMAGE: String = "damage"
const EFFECT_HEAL: String = "heal"
const EFFECT_BUFF: String = "buff"   # 段階3で実装
const EFFECT_DOT: String = "dot"     # 段階3で実装
const EFFECT_TYPES_KNOWN: Array = [
	EFFECT_DAMAGE, EFFECT_HEAL, EFFECT_BUFF, EFFECT_DOT,
	"dispel", "cancel", "transform", "move", "summon"
]
# 実際に当たるもの。他は「書けるが飛ばす」（黄）。
const EFFECT_TYPES_IMPLEMENTED: Array = [
	EFFECT_DAMAGE, EFFECT_HEAL, EFFECT_BUFF, EFFECT_DOT
]
# 状態として残る効果。host / status_id / stack / 寿命の欄を読む（PLAN 13章）。
const EFFECT_TYPES_STATUS: Array = [EFFECT_BUFF, EFFECT_DOT]

# --- attack_type（どの防御で受けるか。攻撃側の参照元は scale_from） ---
# ⚠ physical / magic は BattleUnit の定数を唯一の正とする。
#    ここに書き直さないこと（2本目の一覧を作ると片方だけ直して事故る）。
const ATTACK_TYPE_TRUE: String = "true"   # 確定ダメージ（防御を0として扱う）

# --- effects[].host（効果の寿命の持ち主） ---
const HOST_NONE: String = "none"
const HOST_UNIT: String = "unit"
const HOST_POINT: String = "point"
const HOST_BATTLE: String = "battle"
const HOST_SPAWN: String = "spawn"
const HOSTS_KNOWN: Array = [HOST_NONE, HOST_UNIT, HOST_POINT, HOST_BATTLE, HOST_SPAWN]

# --- effects[].trigger（いつ発火するか） ---
# 解釈するのは SkillRuntime。⚠ SkillResolver は trigger を読まない（2箇所で解釈すると必ずズレる）。
const TRIGGER_CAST: String = "cast"
const TRIGGER_CHARGE_START: String = "charge_start"   # 段階2で実装
const TRIGGER_PREFIX_EVENT: String = "event:"         # 受け口だけ（合図を出す側が居ない）
const TRIGGER_PREFIX_DELAY: String = "delay:"         # 段階2で実装

# --- effects[].delivery（どう届くか。待ち行列の種別タグ・PLAN 6-8） ---
#
# ⚠ attack_type（どの防御で受けるか）とは別物。混ぜないこと。
#   attack_type は 5-2-1 で「防御の参照先だけ」に純化した欄で、送り方の意味は持たない。
#   段階3の効果 cancel（飛び道具の無効化）と詠唱中断が、このタグで待ち行列を絞る。
#
# 省略時は melee。回復と自傷にも melee が入るが、投射する回復を作るまで実害は無い。
const DELIVERY_MELEE: String = "melee"
const DELIVERY_PROJECTILE: String = "projectile"
const DELIVERY_MAGIC: String = "magic"
const DELIVERIES_KNOWN: Array = [DELIVERY_MELEE, DELIVERY_PROJECTILE, DELIVERY_MAGIC]

# --- effects[].stack（重ねがけ規則・PLAN 13-2） ---
#
# ⚠ 省略時の既定値を作らない（scale_from と同じ方針）。書き忘れがどちらに
#   倒れても無音で挙動が変わるため。
#   既定を independent にすると、上書きのつもりで書き忘れたときスタックが
#   無限に積み上がる。既定を refresh にすると、独立のつもりで書き忘れたとき
#   DoT が重ならずダメージが黙って半分になる。どちらもエラーが出ない。
const STACK_INDEPENDENT: String = "independent"   # かけるたびに別の状態が増える
const STACK_REFRESH: String = "refresh"           # 同じ状態を寿命ごと置き直す
const STACKS_KNOWN: Array = [STACK_INDEPENDENT, STACK_REFRESH]

# --- effects[].until（秒数以外の寿命・PLAN 13-3） ---
#
# ⚠ duration_sec と排他。両方書いたら赤。
const UNTIL_CHARGE_END: String = "charge_end"
# ⚠ skill_end は語彙だけ。剥がすには「その cast_id の待ち行列が空か」を
#   SkillRuntime に聞く配線が要る。段階3の後半でまとめる（書くと黄で飛ばされる）。
const UNTIL_SKILL_END: String = "skill_end"
const UNTILS_KNOWN: Array = [UNTIL_CHARGE_END, UNTIL_SKILL_END]

# --- scale_from の "of"（誰の値を見るか） ---
const SCALE_OF_USER: String = "user"
const SCALE_OF_TARGET: String = "target"
const SCALE_OF_SOURCE: String = "source"   # 段階3
const SCALE_OF_KNOWN: Array = [SCALE_OF_USER, SCALE_OF_TARGET, SCALE_OF_SOURCE]

# --- scale_from の source のうち、10軸ではないもの ---
const SCALE_HP_CURRENT: String = "hp_current"
const SCALE_HP_LOST: String = "hp_lost"
const SCALE_HP_RATIO: String = "hp_ratio"
const SCALE_HP_LOST_RATIO: String = "hp_lost_ratio"
const SCALE_DISTANCE: String = "distance"

# スキル直下に書いてよい欄。
# ⚠ typo を黙って既定値にしないための最後の砦（E26）。
const SKILL_FIELDS_KNOWN: Array = [
	"name_key", "user_character_id", "unlock_level", "cooldown_sec",
	"activation", "charge", "target", "effects", "phases"
]

# charge{} の必須欄（数値）
const CHARGE_FIELDS_REQUIRED: Array = [
	"just_sec", "just_window_sec", "min_ratio", "just_bonus"
]


# attack_type に書ける値。BattleUnit の定数から組み立てる（2本目の一覧を作らない）。
static func attack_types_known() -> Array:
	return [BattleUnit.ATTACK_TYPE_PHYSICAL, BattleUnit.ATTACK_TYPE_MAGIC, ATTACK_TYPE_TRUE]


# scale_from の source に書ける名前（段階1ぶん）。
# 10軸は GameManager.get_stat_keys() が唯一の正。ここに軸名を並べた
# 2本目の配列を作らないこと。
static func scale_sources() -> Array:
	var sources: Array = []
	for stat_key in GameManager.get_stat_keys():
		sources.append(str(stat_key))
	sources.append(SCALE_HP_CURRENT)
	sources.append(SCALE_HP_LOST)
	sources.append(SCALE_HP_RATIO)
	sources.append(SCALE_HP_LOST_RATIO)
	sources.append(SCALE_DISTANCE)
	return sources


# スキル1件ぶんの構造を検証する。
# 戻り値は { "level": "error" or "warning", "message": String } の配列。空＝問題なし。
# message には必ず skill_id を含める（どのスキルが壊れているか分からないと直せない）。
static func validate(skill_id: String, data: Dictionary) -> Array:
	var issues: Array = []

	# E1
	if data == null or data.is_empty():
		_err(issues, skill_id, "定義が空、または Dictionary ではない")
		return issues

	# E2 旧欄の残骸。「移行し忘れ」を確実に捕まえる。
	if data.has("type"):
		_err(issues, skill_id, "旧欄 'type' が残っている（activation / target / effects[] に割ること）")

	# E3
	if str(data.get("name_key", "")) == "":
		_err(issues, skill_id, "name_key が無い")
	if str(data.get("user_character_id", "")) == "":
		_err(issues, skill_id, "user_character_id が無い")

	# E4
	if not _is_num(data.get("unlock_level", null)):
		_err(issues, skill_id, "unlock_level が数値でない")
	if not _is_num(data.get("cooldown_sec", null)):
		_err(issues, skill_id, "cooldown_sec が数値でない")

	# E5 / W1
	var activation: String = str(data.get("activation", ""))
	if not (activation in ACTIVATIONS_KNOWN):
		_err(issues, skill_id, "activation が不明: '%s'" % activation)
	elif activation == ACTIVATION_RECAST or activation == ACTIVATION_TOGGLE:
		_warn(issues, skill_id, "activation: '%s' は段階5以降。段階1では動かない" % activation)

	# E6 / E7
	var raw_charge: Variant = data.get("charge", null)
	if activation == ACTIVATION_CHARGE:
		if not (raw_charge is Dictionary):
			_err(issues, skill_id, "activation: charge なのに charge{} が無い")
		else:
			for field: Variant in CHARGE_FIELDS_REQUIRED:
				if not _is_num((raw_charge as Dictionary).get(field, null)):
					_err(issues, skill_id, "charge.%s が数値でない" % str(field))
	elif data.has("charge"):
		_err(issues, skill_id, "activation が charge 以外なのに charge{} がある")

	# E8〜E15 target
	var raw_target: Variant = data.get("target", null)
	if not (raw_target is Dictionary):
		_err(issues, skill_id, "target が無い、または Dictionary でない")
	else:
		_validate_target(issues, skill_id, raw_target as Dictionary, "target", true)

	# E17 effects
	var raw_effects: Variant = data.get("effects", null)
	if not (raw_effects is Array) or (raw_effects as Array).is_empty():
		_err(issues, skill_id, "effects が無い、配列でない、または空")
	else:
		var index: int = 0
		for raw_effect: Variant in (raw_effects as Array):
			if not (raw_effect is Dictionary):
				_err(issues, skill_id, "effects[%d] が Dictionary でない" % index)
			else:
				# activation を渡すのは E44 / E45（チャージ専用の欄を instant に
				# 書いていないか）のため。効果だけを見ても判定できない。
				_validate_effect(issues, skill_id, raw_effect as Dictionary, index, activation)
			index += 1

	# W7
	if data.has("phases"):
		_warn(issues, skill_id, "phases は段階5。段階1では読まれない")

	# E26 知らない欄（typo をここで捕まえる）
	for key: Variant in data:
		if not (str(key) in SKILL_FIELDS_KNOWN):
			_err(issues, skill_id, "知らない欄がある: '%s'" % str(key))

	return issues


# target ブロックの検証。effects[].target からも呼ぶ（そちらは range を禁じる）。
static func _validate_target(
		issues: Array, skill_id: String, target: Dictionary, where: String, allow_range: bool
) -> void:
	var team: String = str(target.get("team", ""))

	# E9
	if not (team in TEAMS_KNOWN):
		_err(issues, skill_id, "%s.team が不明: '%s'" % [where, team])
		return

	# W3
	if team == TEAM_SOURCE:
		_warn(issues, skill_id, "%s.team: source は段階3。段階1では対象が0体になる" % where)

	# E10 team: self に mode / sort / count を書かせない
	# （mode を読むかが team で決まる逆流を作らないため。PLAN 21章）
	if team == TEAM_SELF:
		for field: Variant in ["mode", "sort", "count"]:
			if target.has(field):
				_err(issues, skill_id, "%s.team: self に %s は書けない" % [where, str(field)])
	else:
		# E11
		var mode: String = str(target.get("mode", ""))
		if not (mode in MODES_KNOWN):
			_err(issues, skill_id, "%s.mode が無い、または不明: '%s'" % [where, mode])
		elif mode == MODE_AREA:
			# W2 / E15
			_warn(issues, skill_id, "%s.mode: area は段階4。段階1では対象が0体になる" % where)
			if not _is_num(target.get("radius", null)) or float(target.get("radius", 0.0)) <= 0.0:
				_err(issues, skill_id, "%s.mode: area なのに radius が正の数値でない" % where)
		else:
			# E12 sort（省略は許す＝nearest）
			var sort: String = str(target.get("sort", SORT_NEAREST))
			if not (sort in SORTS_KNOWN):
				_err(issues, skill_id, "%s.sort が不明: '%s'" % [where, sort])
			# E13 count（sort: all は count を読まない。省略は許す＝1）
			elif sort != SORT_ALL and target.has("count"):
				var count: Variant = target.get("count", null)
				if not _is_num(count) or float(count) < 1.0 or float(count) != floor(float(count)):
					_err(issues, skill_id, "%s.count が1以上の整数でない" % where)

	# E14 / E16 range
	if target.has("range"):
		if not allow_range:
			_err(issues, skill_id, "%s に range は書けない（射程はスキルの母集団を絞るもの）" % where)
		elif not _is_num(target.get("range", null)) or float(target.get("range", 0.0)) <= 0.0:
			_err(issues, skill_id, "%s.range が正の数値でない" % where)


# effects[] の1要素ぶんの検証。
static func _validate_effect(
		issues: Array, skill_id: String, effect: Dictionary, index: int, activation: String
) -> void:
	var where: String = "effects[%d]" % index

	# E18
	var effect_type: String = str(effect.get("type", ""))
	if not (effect_type in EFFECT_TYPES_KNOWN):
		_err(issues, skill_id, "%s.type が無い、または不明: '%s'" % [where, effect_type])
		return

	# W4
	if not (effect_type in EFFECT_TYPES_IMPLEMENTED):
		_warn(issues, skill_id, "%s.type: '%s' はまだ実装していない。飛ばされる" % [where, effect_type])

	# E29〜E43 状態として残る効果（buff / dot）
	if effect_type in EFFECT_TYPES_STATUS:
		_validate_status_effect(issues, skill_id, effect, where, activation)

	if effect_type == EFFECT_DAMAGE or effect_type == EFFECT_HEAL:
		# E19
		if not _is_num(effect.get("multiplier", null)):
			_err(issues, skill_id, "%s.multiplier が数値でない" % where)

		# E20 / E21 attack_type
		if effect_type == EFFECT_DAMAGE:
			if effect.has("attack_type"):
				var attack_type: String = str(effect.get("attack_type", ""))
				if not (attack_type in attack_types_known()):
					_err(issues, skill_id, "%s.attack_type が不明: '%s'" % [where, attack_type])
		elif effect.has("attack_type"):
			# 回復が攻撃力依存だった事故の再発防止。欄そのものを作らない（PLAN 5-2）
			_err(issues, skill_id, "%s は heal なので attack_type を書けない" % where)

		# E27 scale_from は必須。既定値を作らない（決定1-5）
		if not effect.has("scale_from"):
			_err(issues, skill_id, "%s に scale_from が無い（damage / heal は必須）" % where)

	# E22 scale_from の形（buff などが書いてきた場合もここで見る）
	if effect.has("scale_from"):
		_validate_scale_from(issues, skill_id, effect.get("scale_from", null), where)

	# E23
	if effect.has("chance"):
		if not _is_num(effect.get("chance", null)):
			_err(issues, skill_id, "%s.chance が数値でない" % where)
		elif float(effect.get("chance", 1.0)) < 1.0:
			# W8
			_warn(issues, skill_id, "%s.chance は段階1では読まれない（必ず当たる扱い）" % where)
	if effect.has("charge_scales") and not (effect.get("charge_scales", null) is bool):
		_err(issues, skill_id, "%s.charge_scales が bool でない" % where)

	# E28 delivery（書いてあって値が不明なら赤。省略は許す＝melee）
	if effect.has("delivery") and not (str(effect.get("delivery", "")) in DELIVERIES_KNOWN):
		_err(issues, skill_id, "%s.delivery が不明: '%s'" % [where, str(effect.get("delivery", ""))])

	# E24 / W5 trigger
	# cast / charge_start / delay:<数値> は段階2で実装した。警告を出さない。
	# event:◯◯ だけは合図を出す側（演出シーン）が存在しないので黄のまま。
	var trigger: String = str(effect.get("trigger", TRIGGER_CAST))
	if not _is_trigger_shape(trigger):
		_err(issues, skill_id, "%s.trigger の形が不正: '%s'" % [where, trigger])
	elif trigger.begins_with(TRIGGER_PREFIX_EVENT):
		_warn(issues, skill_id, "%s.trigger: '%s' は合図を出す側が居ない（アニメ未実装）。タイムアウトで発火する" % [where, trigger])

	# E45 charge_start は SkillRuntime.charge_start() からしか流れない。
	# チャージしないスキルに書くと一度も発火しない。無音なので赤で弾く。
	if trigger == TRIGGER_CHARGE_START and activation != ACTIVATION_CHARGE:
		_err(issues, skill_id, "%s.trigger: 'charge_start' は activation: charge のスキルにしか書けない" % where)

	# E25 / E30 / W6 / W9 host
	var host: String = str(effect.get("host", HOST_NONE))
	if not (host in HOSTS_KNOWN):
		_err(issues, skill_id, "%s.host が不明: '%s'" % [where, host])
	elif host == HOST_NONE:
		pass
	elif not (effect_type in EFFECT_TYPES_STATUS) and host != HOST_SPAWN:
		# E30 … 残らないものに宿主は無い（damage / heal に host を書いている）
		_err(issues, skill_id, "%s.type: '%s' に host: '%s' は書けない（残らない効果）" % [where, effect_type, host])
	elif host == HOST_POINT or host == HOST_BATTLE:
		# W9 … 器には載るが、参照する仕組み（条件・購読）が段階3の後半なので何も起きない
		_warn(issues, skill_id, "%s.host: '%s' は器に載るだけ。参照する仕組み（条件・購読）は段階3の後半" % [where, host])
	elif host == HOST_SPAWN:
		# W6
		_warn(issues, skill_id, "%s.host: 'spawn' は段階6。今は飛ばされる" % where)

	# 効果ごとの target 上書き（range は書けない＝E16）
	var raw_target: Variant = effect.get("target", null)
	if raw_target != null:
		if not (raw_target is Dictionary):
			_err(issues, skill_id, "%s.target が Dictionary でない" % where)
		else:
			_validate_target(issues, skill_id, raw_target as Dictionary, where + ".target", false)


# 状態として残る効果（buff / dot）の検証。E29〜E44 / W10 / W11。
#
# ⚠ ここで見るのは「無音で壊れる書き方」だけ。状態は、剥がれない・二重に付く・
#   一度も発火しない のどれもエラーを出さないので、書いた時点で弾く。
static func _validate_status_effect(
		issues: Array, skill_id: String, effect: Dictionary, where: String, activation: String
) -> void:
	var effect_type: String = str(effect.get("type", ""))

	# E29 残らない状態は書けない
	var host: String = str(effect.get("host", HOST_NONE))
	if host == HOST_NONE:
		_err(issues, skill_id, "%s.type: '%s' には host が要る（残らない状態は書けない）" % [where, effect_type])

	# E36 identity
	if str(effect.get("status_id", "")) == "":
		_err(issues, skill_id, "%s.status_id が無い" % where)

	# E35 重ねがけ規則は省略不可
	if not effect.has("stack"):
		_err(issues, skill_id, "%s.stack が無い（independent / refresh を必ず書く）" % where)
	elif not (str(effect.get("stack", "")) in STACKS_KNOWN):
		_err(issues, skill_id, "%s.stack が不明: '%s'" % [where, str(effect.get("stack", ""))])

	# E31 / E32 寿命は duration_sec か until のどちらか一方
	var has_duration: bool = effect.has("duration_sec")
	var has_until: bool = effect.has("until")
	if not has_duration and not has_until:
		_err(issues, skill_id, "%s に duration_sec も until も無い" % where)
	elif has_duration and has_until:
		_err(issues, skill_id, "%s に duration_sec と until の両方がある（排他）" % where)

	# E33
	if has_duration:
		if not _is_num(effect.get("duration_sec", null)) or float(effect.get("duration_sec", 0.0)) <= 0.0:
			_err(issues, skill_id, "%s.duration_sec が正の数値でない" % where)

	# E34 / E44 / W11
	if has_until:
		var until: String = str(effect.get("until", ""))
		if not (until in UNTILS_KNOWN):
			_err(issues, skill_id, "%s.until が不明: '%s'" % [where, until])
		elif until == UNTIL_CHARGE_END and activation != ACTIVATION_CHARGE:
			# ⚠ 剥がす経路がチャージ終了しか無い。instant に書くと永久に残る
			_err(issues, skill_id, "%s.until: 'charge_end' は activation: charge のスキルにしか書けない" % where)
		elif until == UNTIL_SKILL_END:
			_warn(issues, skill_id, "%s.until: 'skill_end' は未実装（剥がす配線が無い）。この効果は飛ばされる" % where)

	if effect_type == EFFECT_BUFF:
		# E37 / E38
		var stat_key: String = str(effect.get("stat", ""))
		if not (stat_key in GameManager.get_stat_keys()):
			_err(issues, skill_id, "%s.stat が10軸に無い: '%s'" % [where, stat_key])
		elif stat_key == GameStateKeys.STAT_HP:
			_err(issues, skill_id, "%s.stat に hp は書けない（max_hp を再計算しないため）" % where)
		# E39 … 0 も禁止（何も起きない状態を書かせない）
		var value: Variant = effect.get("value", null)
		if not _is_num(value) or float(value) != floor(float(value)) or int(value) == 0:
			_err(issues, skill_id, "%s.value が0以外の整数でない" % where)
		# ⚠ buff は multiplier を読まない（PLAN 5-2。意味を3つ持たせない）
		if effect.has("multiplier"):
			_err(issues, skill_id, "%s は buff なので multiplier を書けない（stat / value を使う）" % where)

	elif effect_type == EFFECT_DOT:
		# E40
		var interval: Variant = effect.get("interval_sec", null)
		if not _is_num(interval) or float(interval) <= 0.0:
			_err(issues, skill_id, "%s.interval_sec が正の数値でない" % where)
		# E41
		if not _is_num(effect.get("multiplier", null)):
			_err(issues, skill_id, "%s.multiplier が数値でない" % where)
		# E42 … damage と同じ扱い。既定値を作らない
		if not effect.has("scale_from"):
			_err(issues, skill_id, "%s に scale_from が無い（dot は damage と同じく必須）" % where)
		# E43
		if not (str(effect.get("attack_type", "")) in attack_types_known()):
			_err(issues, skill_id, "%s.attack_type が無い、または不明: '%s'" % [where, str(effect.get("attack_type", ""))])
		# W10 … 端数は切り捨て（発火は floor(duration / interval) 回）
		if has_duration and _is_num(interval) and float(interval) > 0.0:
			var duration: float = float(effect.get("duration_sec", 0.0))
			var ratio: float = duration / float(interval)
			if absf(ratio - floor(ratio)) > 0.0001:
				_warn(issues, skill_id, "%s は duration_sec が interval_sec で割り切れない。端数は切り捨てで %d 回発火する" % [
					where, int(floor(ratio))
				])


# E22。文字列（省略形）か、{source, of, weight} の配列。
static func _validate_scale_from(
		issues: Array, skill_id: String, raw: Variant, where: String
) -> void:
	var terms: Array = []
	if raw is String:
		terms = [{ "source": str(raw) }]
	elif raw is Array:
		if (raw as Array).is_empty():
			_err(issues, skill_id, "%s.scale_from が空配列" % where)
			return
		terms = raw as Array
	else:
		_err(issues, skill_id, "%s.scale_from が文字列でも配列でもない" % where)
		return

	var known: Array = scale_sources()
	for term: Variant in terms:
		if not (term is Dictionary):
			_err(issues, skill_id, "%s.scale_from の要素が Dictionary でない" % where)
			continue
		var entry: Dictionary = term as Dictionary
		var source: String = str(entry.get("source", ""))
		if not (source in known):
			_err(issues, skill_id, "%s.scale_from の source が不明: '%s'" % [where, source])
		if entry.has("of") and not (str(entry.get("of", "")) in SCALE_OF_KNOWN):
			_err(issues, skill_id, "%s.scale_from の of が不明: '%s'" % [where, str(entry.get("of", ""))])
		if entry.has("weight") and not _is_num(entry.get("weight", null)):
			_err(issues, skill_id, "%s.scale_from の weight が数値でない" % where)


# trigger は cast / charge_start / event:◯◯ / delay:<数値> のどれか。
static func _is_trigger_shape(trigger: String) -> bool:
	if trigger == TRIGGER_CAST or trigger == TRIGGER_CHARGE_START:
		return true
	if trigger.begins_with(TRIGGER_PREFIX_EVENT):
		return trigger.length() > TRIGGER_PREFIX_EVENT.length()
	if trigger.begins_with(TRIGGER_PREFIX_DELAY):
		return trigger.substr(TRIGGER_PREFIX_DELAY.length()).is_valid_float()
	return false


# JSON から来る数値は float。int も許す（手書きの 1 を弾かないため）。
static func _is_num(value: Variant) -> bool:
	return (value is float) or (value is int)


static func _err(issues: Array, skill_id: String, message: String) -> void:
	issues.append({ "level": LEVEL_ERROR, "message": "%s: %s" % [skill_id, message] })


static func _warn(issues: Array, skill_id: String, message: String) -> void:
	issues.append({ "level": LEVEL_WARNING, "message": "%s: %s" % [skill_id, message] })
