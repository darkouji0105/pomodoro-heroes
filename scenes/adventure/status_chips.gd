class_name StatusChips
extends BoxContainer

# 状態を「色付きのマス ＋ 漢字1文字」で並べる帯（EXEC_STATUS_UI.md §3-B）。
#
# ⚠⚠ 2026-09-16 から**味方も敵も召喚もユニットの本体の下端に横並び**（人間の決定・モック §5）。
#   ⚠ 向きは setup() で切り替えられる形を残してある（⚠ いまは全部が横）。
#   ⚠ HBoxContainer と VBoxContainer に分けないこと。色と漢字の決め方が2箇所になる。
#
# ⚠ このノードは StatusRegistry を知らない。entry の配列を外から受け取るだけ
#   （UnitView.set_shield() と同じ形。器を持つとリトライで古い参照を握る）。
#
# ⚠ 画像素材が1枚も無いので ColorRect ＋ Label で作る（assets/images は空）。
#   絵に差し替えるときは ColorRect を TextureRect にするだけで済む形にしてある。

# チップの区分け（2026-09-17・人間の決定「ツートンで決める」）。⚠ 決めるのは tone_of() の1本。
enum Tone {
	HIDDEN,   # ⚠ 出さない（シールドだけの状態＝HPバーに継ぎ足してあるので見ればわかる）
	BUFF,     # ⚠ 青地に白字
	DEBUFF,   # ⚠ 赤地に白字
	REVIVE,   # ⚠ 特殊：復活（黄）
}

# 前回組んだ顔ぶれ。instance_id を連ねた文字列。
# ⚠ 毎フレーム組み直さないための鍵。ColorRect と Label を毎フレーム作ると
#   重いうえに文字がちらつく。件数が同じでも中身が入れ替わることがあるので、
#   件数ではなく instance_id の並びで比べる。
var _signature: String = ""

# 入る長さ（縦なら高さ・横なら幅）。setup() で受け取る。
var _max_px: float = 0.0


func setup(is_vertical: bool, max_px: float) -> void:
	vertical = is_vertical
	_max_px = max_px
	add_theme_constant_override("separation", Balance.adventure.status_chip_separation_px)
	# ⚠ 帯そのものは入力を受け取らない。味方の帯はスキルボタンの隣に並ぶので、
	#   ここが押せると「ボタンを押したつもりが外れた」が起きる。
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# 表示する状態を差し替える。⚠ 毎フレーム呼んでよい。
func set_entries(entries: Array) -> void:
	var sig: String = _make_signature(entries)
	if sig == _signature:
		return
	_signature = sig
	_rebuild(entries)


# ⚠ remove_child() してから queue_free() する（CLAUDE.md 5番）。
#   queue_free() だけだと同じフレームの2本目の呼び出しで古いマスがまだ子に残り、
#   マスが二重に並ぶ。await を持たせないこと。
func _rebuild(entries: Array) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	# ⚠ 出さない区分けは、⚠ 数える前に外す（⚠ 件数でマスの大きさが変わるので、見えない件を数えない）。
	var shown: Array = []
	for entry: Variant in entries:
		if entry is Dictionary and tone_of(entry as Dictionary) != Tone.HIDDEN:
			shown.append(entry)
	entries = shown

	if entries.is_empty():
		return

	var side: int = _chip_side_px(entries.size())
	var step: float = float(side) + float(Balance.adventure.status_chip_separation_px)
	# 入る個数。⚠ 0 になることはない（_max_px が side を下回る設定は事故）。
	var fits: int = int(floor(_max_px / step)) if step > 0.0 else entries.size()
	var show_count: int = entries.size()
	var overflow: int = 0
	if fits > 0 and entries.size() > fits:
		# 最後の1マスを「＋N」に使う。
		show_count = fits - 1
		overflow = entries.size() - show_count

	for i in range(show_count):
		var entry: Variant = entries[i]
		if not (entry is Dictionary):
			continue
		add_child(_make_chip(entry as Dictionary, side))

	if overflow > 0:
		add_child(_make_overflow_chip(overflow, side))


# 1件ぶんのマス。ColorRect の上に漢字を1文字。
func _make_chip(entry: Dictionary, side: int) -> Control:
	var cfg: AdventureConfig = Balance.adventure
	var box: ColorRect = ColorRect.new()
	box.custom_minimum_size = Vector2(side, side)
	box.color = _chip_color(entry)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 条件が偽の状態は半透明にする（消さない）。
	# ⚠ 消すと「条件で切れた」のか「寿命で消えた」のかが画面から区別できない。
	#   段階3の後半②で作った条件の、唯一の見え方になっている。
	if not bool(entry.get("active", true)):
		box.modulate.a = cfg.status_chip_inactive_alpha

	var label: Label = Label.new()
	label.text = _chip_char(str(entry.get("status_id", "")))
	label.add_theme_font_size_override("font_size", int(round(float(side) * 0.6)))
	label.add_theme_color_override("font_color", get_theme_color(&"text", &"StatusChip"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	return box


# 入りきらなかった件数を出すマス。⚠ 通常は出ない（人間の指示・2026-08-22）。
func _make_overflow_chip(count: int, side: int) -> Control:
	var box: ColorRect = ColorRect.new()
	box.custom_minimum_size = Vector2(side, side)
	box.color = get_theme_color(&"buff", &"StatusChip")
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label: Label = Label.new()
	label.text = "+%d" % count
	label.add_theme_font_size_override("font_size", int(round(float(side) * 0.6)))
	label.add_theme_color_override("font_color", get_theme_color(&"text", &"StatusChip"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	return box


# 地の色（⚠ Theme の `StatusChip` 型）。⚠ 区分けは tone_of() が決める。
# ⚠⚠ 2026-08-22 の「色は3つだけ（赤・緑・青）」は 2026-09-17 に人間が取り消した。
func _chip_color(entry: Dictionary) -> Color:
	match tone_of(entry):
		Tone.DEBUFF:
			return get_theme_color(&"debuff", &"StatusChip")
		Tone.REVIVE:
			return get_theme_color(&"revive", &"StatusChip")
	return get_theme_color(&"buff", &"StatusChip")


# 状態1件の区分け（2026-09-17・人間の決定）。⚠⚠ 判定はここ1本。⚠ JSON に欄を足さない
#   （⚠ 付けたときの中身から決める）。
#
# 順番（⚠ 上が優先）：
#   ① 復活（on_death）………………… REVIVE
#   ② シールドだけ ………………………… HIDDEN（⚠ シールドと別の効果を持つなら出す）
#   ③ 1つでも「悪い」向きの欄がある … DEBUFF
#        ⚠ 回復でない周期（dot）／ 能力値の加算がマイナス ／ 攻撃力の倍率がマイナス ／
#        ⚠ 被回復がマイナス ／ 被ダメージ軽減がマイナス
#   ④ それ以外 ………………………………… BUFF（⚠ 反撃 react・反射・無効・周期回復もここ）
static func tone_of(entry: Dictionary) -> Tone:
	var on_death: Variant = entry.get("on_death", {})
	if on_death is Dictionary and not (on_death as Dictionary).is_empty():
		return Tone.REVIVE
	if _is_shield_only(entry):
		return Tone.HIDDEN
	var kind: String = str(entry.get("kind", ""))
	if kind == StatusRegistry.KIND_DOT and not bool(entry.get("heals", false)):
		return Tone.DEBUFF
	if str(entry.get("stat", "")) != "" and int(entry.get("value", 0)) < 0:
		return Tone.DEBUFF
	for key: String in ["atk_mult_pct", "heal_taken_pct", SkillSchema.INTERVENE_REDUCTION_PCT]:
		if int(entry.get(key, 0)) < 0:
			return Tone.DEBUFF
	return Tone.BUFF


# シールドのほかに何も持たないか。⚠ 「持たない件にも必ず欄がある」器の決まりを前提に、既定値と比べる。
static func _is_shield_only(entry: Dictionary) -> bool:
	if str(entry.get("kind", "")) != StatusRegistry.KIND_BUFF:
		return false
	if int(entry.get(SkillSchema.INTERVENE_SHIELD_HP, 0)) <= 0:
		return false
	if str(entry.get("stat", "")) != "":
		return false
	for key: String in [
		"atk_mult_pct", "heal_taken_pct",
		SkillSchema.INTERVENE_REDUCTION_PCT, SkillSchema.INTERVENE_PIERCE_PCT,
		SkillSchema.INTERVENE_REFLECT_PCT, SkillSchema.INTERVENE_REFLECT_FLAT,
	]:
		if int(entry.get(key, 0)) != 0:
			return false
	if bool(entry.get(SkillSchema.INTERVENE_CRIT_ALWAYS, false)):
		return false
	var block: Variant = entry.get("block_status", [])
	if block is Array and not (block as Array).is_empty():
		return false
	var react: Variant = entry.get("react", {})
	if react is Dictionary and not (react as Dictionary).is_empty():
		return false
	return true


# 件数でマスの大きさを変える（人間の指示・2026-08-22）。
# ⚠ 「6個まで」のような決め打ちにしないこと。
func _chip_side_px(count: int) -> int:
	var cfg: AdventureConfig = Balance.adventure
	if count <= 4:
		return cfg.status_chip_size_large_px
	if count <= 8:
		return cfg.status_chip_size_medium_px
	return cfg.status_chip_size_small_px


# 漢字1文字は翻訳表から引く（ui_status_ch_<status_id>）。
#
# ⚠ JSON 側に欄を足さない。同じ status_id を2つのスキルが付けることがあり
#   （status_edbg_dot が実際に2ファイルから付いている）、JSON に書くと食い違う。
#
# ⚠ 行が無いときは「？」を出す。AGENTS.md は「キーがそのまま返るのを許容する」と
#   書いているが、ここは 16px 角のマスなので ui_status_ch_status_holy_burn が
#   はみ出して画面が崩れる。漏れが見えるという目的は「？」で保たれ、
#   件数は W17（ロード時の黄）でも分かる。
func _chip_char(status_id: String) -> String:
	if status_id == "":
		return "？"
	var key: String = "ui_status_ch_" + status_id
	var text: String = tr(key)
	if text == key or text == "":
		return "？"
	return text


# 顔ぶれの署名。⚠ active も混ぜる。条件が切り替わったときに
# 半透明の付け外しが要るため、instance_id だけだと組み直しが走らない。
func _make_signature(entries: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for entry: Variant in entries:
		if not (entry is Dictionary):
			continue
		var e: Dictionary = entry as Dictionary
		parts.append("%d:%d" % [int(e.get("instance_id", 0)), 1 if bool(e.get("active", true)) else 0])
	return ",".join(parts)
