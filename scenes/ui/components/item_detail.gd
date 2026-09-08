class_name ItemDetail
extends VBoxContainer

# マスを押したときに出す「詳細」（段階18-c-2・PLAN_INVENTORY.md）。
#
# ⚠ 2画面以上で使うので scenes/ui/components/（AGENTS.md）。
#   ⚠ 出す先は 倉庫（18-c）／ ダンジョンの鞄（18-d）／ 装備画面（あとで）。
# ⚠⚠ 中身の判定を書かない。⚠ 「何が刺さっているか」「いくつ戻るか」「次の等級のコスト」は
#   全部 GameManager に聞く。⚠ ここでやるのは並べることだけ。
#   ⚠ ここに計算を書くと、⚠ 画面と本体で数字が食い違う（宿題62 の元の症状）。
# ⚠ 説明文は ja.csv の "ui_desc_" + item_id。⚠ 無ければ出さない
#   （⚠ tr() はキーが無いとキー名をそのまま返すので、⚠ それで判定する。
#     ⚠ 空の行を作らないための唯一の分岐）。
# ⚠ 再描画に await を持たせない（AGENTS.md）。remove_child してから queue_free。
#
# ⚠ .tscn を持たない。⚠ VBoxContainer に付けるだけの部品（ItemGrid と同じ流儀）。

# 説明文のキーの頭。⚠ 綴りを散らさない。
const DESC_KEY_PREFIX: String = "ui_desc_"

# 値の色（2026-09-08・段階③）。⚠ Theme の型 variation の名前。
#   ⚠ 色そのものは `tools/theme_builder.gd` が持つ。⚠ ここに書かない（AGENTS.md）。
const VARIATION_GAIN: StringName = &"GainLabel"
const VARIATION_LOSS: StringName = &"ErrorLabel"

# 見出しの中の、名前とサブ行を隔てる字。⚠ モックの「等級10 ／ アクセサリー」の「／」。
const SUB_SEPARATOR: String = " ／ "

var _entry: Dictionary = {}

# 要約だけを出すか（2026-09-08・段階④）。⚠ ホバーの枠がこれを立てる。
#   ⚠ 出すのは「⚠ 名前と等級 ／ ⚠ ステータス ／ ⚠ 部位と枠 ／ ⚠ 説明文」まで。
#   ⚠ 操作にまつわる数字（⚠ 分解の戻り・鍛えるコスト・段階上げ）は出さない
#     （⚠ 押すボタンが隣に無いので、⚠ 読んでも何もできない）。
var _summary: bool = false


# 要約にするか。⚠ 中身を差し替える前に呼ぶこと（⚠ 次の show_entry() から効く）。
func set_summary(value: bool) -> void:
	_summary = value


# いま出しているもの（⚠ 画面が「操作」を組み立てるときに使う）。
func get_entry() -> Dictionary:
	return _entry.duplicate(true)


# 中身を差し替える。⚠ 空の Dictionary を渡すと「選んでいない」の1行だけ。
func show_entry(entry: Dictionary) -> void:
	_entry = entry.duplicate(true)
	for child in get_children():
		remove_child(child)
		child.queue_free()

	if _entry.is_empty():
		_add_line(tr("ui_detail_none"))
		return

	var item_id: String = str(_entry.get(GameManager.SLOT_ENTRY_ITEM_ID, ""))
	match str(_entry.get(GameManager.SLOT_ENTRY_KIND, "")):
		GameManager.SLOT_KIND_INSTANCE:
			_show_instance(item_id, str(_entry.get(GameManager.SLOT_ENTRY_INSTANCE_ID, "")))
		GameManager.SLOT_KIND_RELIC:
			_show_relic(item_id)
		_:
			_show_item(item_id)
	_add_description(item_id)


# レリック（段階17-e-3）。⚠ items.json の品ではないので個数も等級も出さない。
#
# ⚠ 効果の中身（パッシブ）はここで解釈しない。⚠ 名前と「誰に効くか」まで。
#   ⚠ 効果を文章にするには skill_schema を読むことになり、⚠ 規模が変わる（宿題62 の判断と同じ）。
#   ⚠ 説明が要るものは ja.csv に `ui_desc_<relic_id>` を足す（⚠ コードは触らない）。
func _show_relic(relic_id: String) -> void:
	var scope_key: String = (
		"ui_relic_scope_single" if GameManager.is_single_relic(relic_id)
		else "ui_relic_scope_party"
	)
	# ⚠ 名前は見出しが `ui_res_ + id` で引く。⚠ レリックも同じ綴りで在る。
	_add_header(relic_id, 0, [tr(scope_key)])
	var owner: String = str(_entry.get(GameManager.SLOT_ENTRY_EQUIPPED_BY, ""))
	if owner != "":
		var char_data: Dictionary = MasterDataLoader.get_character(owner)
		_add_line(tr("ui_equipment_equipped_by") % tr(str(char_data.get("name_key", owner))))


# 装備の個体。⚠ 等級・ステータス・刺さっている装飾・分解の戻り・次の等級のコスト。
func _show_instance(item_id: String, instance_id: String) -> void:
	var grade: int = int(_entry.get(GameManager.SLOT_ENTRY_GRADE, 1))
	var equip_slot: String = str(
		MasterDataLoader.get_item(item_id).get(GameManager.ITEM_MASTER_EQUIP_SLOT, "")
	)
	# ⚠ 要約では部位を見出しに入れない（⚠ 枠の行の頭に回す＝モック3枚目）。
	var sub_parts: Array[String] = [tr("ui_equipment_grade") % grade]
	if equip_slot != "" and not _summary:
		sub_parts.append(tr("ui_equipment_slot_" + equip_slot))
	_add_header(item_id, grade, sub_parts)

	_add_stat_rows(GameManager.get_instance_stats(instance_id))

	# 刺さっている装飾。⚠ 1行のマスで出す（2026-09-08・モック）。
	#   ⚠ 前は枠1つにつき1行の文字だった（⚠ 7枠あると詳細が枠の説明で埋まっていた）。
	# ⚠⚠ `get_part_entries()` は **開いている枠しか返さない**。⚠ 未開放のマスも出すため、
	#   ⚠ 枠の並びは `get_part_slot_defs()`（全部）から取り、⚠ 中身だけ index で重ねる。
	#   ⚠ 「開いているか」の判定は `PartSlotIcon` が `GameManager` に聞く（⚠ ここでしない）。
	var entries_by_index: Dictionary = {}
	for view: Variant in GameManager.get_part_entries(instance_id):
		if view is Dictionary:
			entries_by_index[int((view as Dictionary).get(GameManager.PART_VIEW_INDEX, 0))] = (
				(view as Dictionary).get(GameManager.PART_VIEW_ENTRY, null)
			)
	var defs: Array = []
	for def: Variant in GameManager.get_part_slot_defs(equip_slot):
		if not (def is Dictionary):
			continue
		var merged: Dictionary = (def as Dictionary).duplicate(true)
		merged[GameManager.PART_VIEW_ENTRY] = entries_by_index.get(
			int(merged.get(GameManager.PART_VIEW_INDEX, 0)), null
		)
		defs.append(merged)
	_add_part_slots(defs, grade, _slot_lead_text(equip_slot))

	if _summary:
		return

	var equipped_by: String = str(_entry.get(GameManager.SLOT_ENTRY_EQUIPPED_BY, ""))
	if equipped_by != "":
		var char_data: Dictionary = MasterDataLoader.get_character(equipped_by)
		_add_line(tr("ui_equipment_equipped_by") % tr(str(char_data.get("name_key", equipped_by))))

	# ⚠ 数値だけの行なので見出しにだけ tr() を通す（AGENTS.md）。
	_add_value_row(
		tr("ui_warehouse_dismantle"),
		str(GameManager.get_dismantle_refund_total(instance_id)),
		&""
	)
	var forge_cost: Dictionary = GameManager.get_forge_cost(instance_id)
	var forge_amount: int = int(forge_cost.get(GameManager.FORGE_COST_AMOUNT, 0))
	if forge_amount > 0:
		_add_cost_row(
			tr("ui_equipment_forge"),
			str(forge_cost.get(GameManager.FORGE_COST_MATERIAL_ID, "")),
			forge_amount
		)


# 持ち物（装飾・ルーン・消耗品）。
func _show_item(item_id: String) -> void:
	# ⚠ 個数は、⚠ マスが持っていればそれを使う（⚠ ダンジョンの鞄。⚠ 拠点には1個も無い品がある）。
	#   ⚠ 無ければ拠点の所持数を引く（⚠ 倉庫のマス）。
	# ⚠ 等級を持つ見本（⚠ UI テストの「等級1〜10」）は個数ではなく等級を出す。
	#   ⚠ 個体（`_show_instance`）と同じ見出しにする＝⚠ 並べたときに読み方が変わらない。
	var grade: int = int(_entry.get(GameManager.SLOT_ENTRY_GRADE, 0))
	var sub_parts: Array[String] = []
	if grade > 0:
		sub_parts.append(tr("ui_equipment_grade") % grade)
	# ⚠ 部位は装備の品だけが持つ（⚠ 素材・消耗品は "" が返る）。
	var equip_slot: String = str(
		MasterDataLoader.get_item(item_id).get(GameManager.ITEM_MASTER_EQUIP_SLOT, "")
	)
	if equip_slot != "" and not _summary:
		sub_parts.append(tr("ui_equipment_slot_" + equip_slot))
	if grade <= 0:
		sub_parts.append("×%d" % int(_entry.get(
			GameManager.SLOT_ENTRY_COUNT, GameManager.get_item_count(item_id)
		)))
	_add_header(item_id, grade, sub_parts)

	var definition: Dictionary = GameManager.get_part_definition(item_id)
	if definition.is_empty():
		# ⚠ 装飾でなければ装備かもしれない。⚠ 装備は「品」の側にも枠の形が在る。
		_show_equipment_slots(item_id, int(_entry.get(GameManager.SLOT_ENTRY_GRADE, 0)))
		return

	# 装飾。⚠ 出目は刺すときに振れるので、⚠ 確定値ではなく幅で見せる（GAME_DESIGN.md 7-6）。
	var stat_key: String = str(definition.get(GameManager.ITEM_MASTER_PART_STAT, ""))
	var base: int = int(definition.get(GameManager.ITEM_MASTER_PART_BASE, 0))
	var roll_max: int = int(definition.get(GameManager.ITEM_MASTER_PART_ROLL_MAX, 0))
	if stat_key != "":
		_add_value_row(
			_stat_label_text(stat_key),
			"+%s〜%s" % [
				_stat_value_text(stat_key, base),
				_stat_value_text(stat_key, base + roll_max),
			],
			VARIATION_GAIN
		)

	if _summary:
		return

	# ルーンは壊しても素材にならず、段階も分解方式では上がらない（GAME_DESIGN.md 7-7）。
	# ⚠ 判定は「runes.json にエントリが在るか」。⚠ part_kind で分岐しない。
	if not GameManager.get_rune_definition(item_id).is_empty():
		_add_value_row(tr("ui_part_rune_merge"), str(GameManager.get_rune_merge_count()), &"")
		return

	var refund: int = 0
	for amount: Variant in GameManager.get_part_dismantle_refund(item_id, 1).values():
		refund += int(amount)
	if refund > 0:
		_add_value_row(tr("ui_part_dismantle"), str(refund), &"")
	if GameManager.get_upgraded_part_id(item_id) != "":
		var cost: Dictionary = GameManager.get_part_upgrade_cost(item_id)
		_add_cost_row(
			tr("ui_part_upgrade"),
			str(cost.get(GameManager.PART_UPGRADE_MATERIAL_ID, "")),
			int(cost.get(GameManager.PART_UPGRADE_AMOUNT, 0))
		)


# 装備の「品」（＝個体ではない）。⚠ 2026-09-07・人間の指示
#   「⚠ 装備などに関してはスロットなども人眼で見れるように」。
#
# ⚠⚠ 個体（`_show_instance`）は **刺さっているもの** を出すが、⚠ こちらは品なので
#   **枠の形**（⚠ どの部位に着くか ／ ⚠ どの枠に何が刺さるか ／ ⚠ 何等級で開くか）を出す。
#   ⚠ 前は名前と個数の2行だけで、⚠ 一覧から装備を見ても何も分からなかった。
# ⚠ 枠の定義は `GameManager.get_part_slot_defs()` の1本に聞く。⚠ ここで並びを作らない
#   （⚠ 作ると装備画面と食い違う）。
func _show_equipment_slots(item_id: String, grade: int) -> void:
	var definition: Dictionary = MasterDataLoader.get_item(item_id)
	var equip_slot: String = str(definition.get(GameManager.ITEM_MASTER_EQUIP_SLOT, ""))
	if equip_slot == "":
		return

	# ⚠ 部位は見出しのサブ行が出す（2026-09-08）。⚠ ここで2度目を出さない。
	# ⚠ 素の値（⚠ 等級の係数が乗る前）。⚠ 個体の数字は `get_instance_stats()` が出す。
	_add_stat_rows(definition.get(GameManager.ITEM_MASTER_EQUIP_STATS, {}))

	# ⚠ 品には中身が無いので全部「空き」か「未開放」。⚠ 刺さっているものを出すのは
	#   `_show_instance()` のほう（⚠ あちらは instance_id を持っている）。
	# ⚠ 「いつ開くか」は出さない（⚠ 2026-09-07 の決定）。⚠ 2026-09-08 に、
	#   ⚠ **未開放の枠が在ること自体**は鍵のマスで見せるようにした（⚠ モック）。
	_add_part_slots(GameManager.get_part_slot_defs(equip_slot), grade, _slot_lead_text(equip_slot))


# 枠を1行のマスで出す（2026-09-08・段階②）。⚠ 見出しに「2 / 7」を付ける。
#
# ⚠ 分母は **開いている枠の数**（⚠ 未開放は数えない）。⚠ 数えるのは `PartSlotRow`。
# ⚠ 枠が1つも無い品（⚠ 消耗品・素材）では見出しごと出さない。
func _add_part_slots(defs: Array, grade: int, lead_text: String = "") -> void:
	if defs.is_empty():
		return
	var row: PartSlotRow = PartSlotRow.create(defs, grade)
	# ⚠ 1つも開いていない等級（⚠ 武器・防具は等級1〜2）では見出しごと出さない。
	#   ⚠ 未開放の枠を出さなくなったので（2026-09-08）、⚠ ここが空の行になりうる。
	if row.get_open_count() == 0:
		row.queue_free()
		return
	var count_text: String = "%d / %d" % [row.get_filled_count(), row.get_open_count()]
	if lead_text == "":
		# ⚠ 常設のパネル。⚠ 見出しの行 → 枠の並び、の2行に分ける（⚠ 幅に余裕がある）。
		_add_line("%s  %s" % [tr("ui_part_slot_header"), count_text])
		add_child(row)
		return

	# ⚠ 要約（⚠ ホバーの枠）。⚠ 「部位 ／ 枠 ／ 2/7」を1行に収める（⚠ モック3枚目）。
	var line: HBoxContainer = HBoxContainer.new()
	line.name = "PartSlotSummary"
	var lead: Label = Label.new()
	lead.name = "Lead"
	lead.text = lead_text + SUB_SEPARATOR
	line.add_child(lead)
	line.add_child(row)
	var count_label: Label = Label.new()
	count_label.name = "Count"
	count_label.text = "  " + count_text
	line.add_child(count_label)
	add_child(line)


# 説明文（宿題62）。⚠ ja.csv に "ui_desc_<item_id>" が在るときだけ出す。
#
# ⚠ 全部の品に説明を書く必要は無い。⚠ 足りない品はキーを足せば出る
#   （⚠ コードは1行も触らない）。
func _add_description(item_id: String) -> void:
	var key: String = DESC_KEY_PREFIX + item_id
	var text: String = tr(key)
	if text == key:
		return
	_add_line(text)


# 軸の名前（2026-09-08・人間の指示「⚠ ステータスの種類ごとにアイコンを」）。
#
# ⚠ 絵文字は `Glyphs.for_stat()` の1本。⚠ ここに軸ごとの分岐を書かない。
# ⚠ フォントに無い軸は ""（⚠ そのときは名前だけになる。⚠ 豆腐を出さない）。
func _stat_label_text(stat_key: String) -> String:
	var glyph: String = Glyphs.for_stat(stat_key)
	var name_text: String = tr("ui_training_stat_" + stat_key)
	return name_text if glyph == "" else "%s %s" % [glyph, name_text]


# ％の軸だけ "%" を付ける。⚠ 判定は GameManager.is_percent_stat() の1本。
func _stat_value_text(stat_key: String, value: int) -> String:
	if GameManager.is_percent_stat(stat_key):
		return "%d%%" % value
	return str(value)


func _add_line(text: String) -> void:
	var label: Label = Label.new()
	label.name = "DetailLine_%d" % get_child_count()
	label.text = text
	add_child(label)


# 見出し（2026-09-08・段階③・モック）。⚠ 左にアイコン、⚠ 右に名前とサブ行。
#
# ⚠ 名前は **等級の色**で出す（⚠ マスの枠線と同じ色＝⚠ 一覧と詳細で読み方が変わらない）。
#   ⚠ 色は `Balance.icon` から引く。⚠ ここに10色を書かない。
# ⚠ サブ行は「等級10 ／ アクセサリー ／ ×12」のように、⚠ 在るものだけを「／」で繋ぐ。
# ⚠⚠ アイコンはここが持つ。⚠ 2026-09-08 に `ItemDetailPopup` の自前のアイコンを外した
#   （⚠ 両方が出すと、⚠ ホバーの枠にアイコンが2つ並ぶ）。
func _add_header(item_id: String, grade: int, sub_parts: Array[String]) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "HeaderRow"

	var icon: ItemIcon = ItemIcon.create(item_id, grade)
	# ⚠ ホバーの枠の中にも入る。⚠ そこでは全部マウスを通す決まり（`ItemDetailPopup`）。
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon)

	var texts: VBoxContainer = VBoxContainer.new()
	texts.name = "HeaderTexts"
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)

	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = tr("ui_res_" + item_id)
	var config: IconConfig = Balance.icon
	if config != null:
		# ⚠ 等級を持たない品（⚠ 素材・消耗品・レリック）は `grade_and_number()` が
		#   ⚠ 既定の等級を返す。⚠ ここで分岐を書かない。
		name_label.add_theme_color_override("font_color", config.color_of_grade(int(
			ItemIcon.grade_and_number(item_id, grade).get(ItemIcon.RESULT_GRADE, config.default_grade)
		)))
	texts.add_child(name_label)

	if not sub_parts.is_empty():
		var sub_label: Label = Label.new()
		sub_label.name = "SubLabel"
		sub_label.text = SUB_SEPARATOR.join(sub_parts)
		texts.add_child(sub_label)

	add_child(row)


# 左に名前・右に値の行（2026-09-08・段階③・モック）。
#
# ⚠ 値の色は Theme の型 variation（⚠ 増える＝緑 ／ 減る＝赤）。⚠ 色を直接書かない。
# ⚠ `variation` が空なら色を変えない（⚠ 個数やコストのように、⚠ 増減ではない値）。
func _add_value_row(left_text: String, right_text: String, variation: StringName) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ValueRow_%d" % get_child_count()

	var left: Label = Label.new()
	left.name = "Name"
	left.text = left_text
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)

	var right: Label = Label.new()
	right.name = "Value"
	right.text = right_text
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if variation != &"":
		right.theme_type_variation = variation
	row.add_child(right)

	add_child(row)


# 枠の行の頭に出す字。⚠ 要約のときだけ部位を出す（⚠ 常設のパネルは見出しが出している）。
func _slot_lead_text(equip_slot: String) -> String:
	if not _summary:
		return ""
	if equip_slot == "":
		return tr("ui_part_slot_header")
	return tr("ui_equipment_slot_" + equip_slot)


# 素材のコストの行（2026-09-08・段階③・モック「⚠ 鍛える 64 / 40」）。
#
# ⚠ 「持っている数 / 必要な数」を出す。⚠ 足りていれば緑、⚠ 足りなければ赤。
#   ⚠ 前は必要な数しか出ておらず、⚠ 足りるかどうかは倉庫の別の場所を見るしかなかった。
# ⚠ 持っている数は `GameManager` に聞く（⚠ 画面で数えない）。
func _add_cost_row(label_text: String, material_id: String, need: int) -> void:
	var owned: int = GameManager.get_material_count(material_id)
	_add_value_row(
		"%s  %s" % [label_text, tr("ui_res_" + material_id)],
		"%d / %d" % [owned, need],
		VARIATION_GAIN if owned >= need else VARIATION_LOSS
	)


# 0 でない軸を1軸ずつの行にする（2026-09-08・段階③）。
#
# ⚠ 前は10軸を1行に繋いでいた（⚠ `_stats_text()`）。⚠ モックは1軸1行で右に値。
# ⚠ 増える／減るで色が変わる。⚠ 符号は必ず出す（⚠ 「+25」「-2」）。
func _add_stat_rows(stats: Variant) -> void:
	if not (stats is Dictionary):
		return
	for stat_key: String in GameManager.get_stat_keys():
		var value: int = int((stats as Dictionary).get(stat_key, 0))
		if value == 0:
			continue
		_add_value_row(
			_stat_label_text(stat_key),
			("+" if value > 0 else "-") + _stat_value_text(stat_key, absi(value)),
			VARIATION_GAIN if value > 0 else VARIATION_LOSS
		)


# 出している行を上から並べて返す。⚠ 検証用（設計役は画面の絵を取れない）。
#   ⚠ ゲームのロジックから呼ばないこと。
#
# ⚠⚠ 枠の行（`PartSlotRow`）も文字にして返す。⚠ 2026-09-08 に枠を文字から
#   マスに変えた。⚠ Label だけを拾っていると、⚠ 枠の行がこの検証から黙って消える。
func get_lines() -> Array[String]:
	var result: Array[String] = []
	for child in get_children():
		if child is Label:
			result.append((child as Label).text)
		elif child is PartSlotRow:
			result.append((child as PartSlotRow).to_text())
		elif child is Container:
			# ⚠ 見出しと「左に名前・右に値」の行（2026-09-08・段階③）。
			#   ⚠ 中の Label を順に繋ぐ。⚠ 入れ子（見出しの VBox）も辿る。
			result.append(_container_text(child as Container))
	return result


# 器の中の Label を上から繋いだ1行。⚠ 検証用（⚠ 画面の絵は取れない）。
func _container_text(node: Node) -> String:
	var parts: Array[String] = []
	for child in node.get_children():
		if child is Label:
			var text: String = (child as Label).text
			if text != "":
				parts.append(text)
		elif child is PartSlotRow:
			# ⚠ 要約では枠の並びが行の中に入る。⚠ ここで拾わないと検証から消える。
			parts.append((child as PartSlotRow).to_text())
		elif child is Container:
			var inner: String = _container_text(child)
			if inner != "":
				parts.append(inner)
	return "  ".join(parts)
