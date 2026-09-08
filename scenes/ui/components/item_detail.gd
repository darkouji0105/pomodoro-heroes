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

var _entry: Dictionary = {}


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
	var relic: Dictionary = MasterDataLoader.get_relic(relic_id)
	var scope_key: String = (
		"ui_relic_scope_single" if GameManager.is_single_relic(relic_id)
		else "ui_relic_scope_party"
	)
	_add_line("%s（%s）" % [tr(str(relic.get("name_key", relic_id))), tr(scope_key)])
	var owner: String = str(_entry.get(GameManager.SLOT_ENTRY_EQUIPPED_BY, ""))
	if owner != "":
		var char_data: Dictionary = MasterDataLoader.get_character(owner)
		_add_line(tr("ui_equipment_equipped_by") % tr(str(char_data.get("name_key", owner))))


# 装備の個体。⚠ 等級・ステータス・刺さっている装飾・分解の戻り・次の等級のコスト。
func _show_instance(item_id: String, instance_id: String) -> void:
	var grade: int = int(_entry.get(GameManager.SLOT_ENTRY_GRADE, 1))
	_add_line("%s  %s" % [tr("ui_res_" + item_id), tr("ui_equipment_grade") % grade])

	var stats_text: String = _stats_text(GameManager.get_instance_stats(instance_id))
	if stats_text != "":
		_add_line(stats_text)

	# 刺さっている装飾。⚠ 1行のマスで出す（2026-09-08・モック）。
	#   ⚠ 前は枠1つにつき1行の文字だった（⚠ 7枠あると詳細が枠の説明で埋まっていた）。
	# ⚠⚠ `get_part_entries()` は **開いている枠しか返さない**。⚠ 未開放のマスも出すため、
	#   ⚠ 枠の並びは `get_part_slot_defs()`（全部）から取り、⚠ 中身だけ index で重ねる。
	#   ⚠ 「開いているか」の判定は `PartSlotIcon` が `GameManager` に聞く（⚠ ここでしない）。
	var equip_slot: String = str(
		MasterDataLoader.get_item(item_id).get(GameManager.ITEM_MASTER_EQUIP_SLOT, "")
	)
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
	_add_part_slots(defs, grade)

	var equipped_by: String = str(_entry.get(GameManager.SLOT_ENTRY_EQUIPPED_BY, ""))
	if equipped_by != "":
		var char_data: Dictionary = MasterDataLoader.get_character(equipped_by)
		_add_line(tr("ui_equipment_equipped_by") % tr(str(char_data.get("name_key", equipped_by))))

	# ⚠ 数値だけの行なので見出しにだけ tr() を通す（AGENTS.md）。
	_add_line("%s %d" % [
		tr("ui_warehouse_dismantle"), GameManager.get_dismantle_refund_total(instance_id)
	])
	var forge_cost: Dictionary = GameManager.get_forge_cost(instance_id)
	var forge_amount: int = int(forge_cost.get(GameManager.FORGE_COST_AMOUNT, 0))
	if forge_amount > 0:
		_add_line("%s %s %d" % [
			tr("ui_equipment_forge"),
			tr("ui_res_" + str(forge_cost.get(GameManager.FORGE_COST_MATERIAL_ID, ""))),
			forge_amount,
		])


# 持ち物（装飾・ルーン・消耗品）。
func _show_item(item_id: String) -> void:
	# ⚠ 個数は、⚠ マスが持っていればそれを使う（⚠ ダンジョンの鞄。⚠ 拠点には1個も無い品がある）。
	#   ⚠ 無ければ拠点の所持数を引く（⚠ 倉庫のマス）。
	# ⚠ 等級を持つ見本（⚠ UI テストの「等級1〜10」）は個数ではなく等級を出す。
	#   ⚠ 個体（`_show_instance`）と同じ見出しにする＝⚠ 並べたときに読み方が変わらない。
	var grade: int = int(_entry.get(GameManager.SLOT_ENTRY_GRADE, 0))
	if grade > 0:
		_add_line("%s  %s" % [tr("ui_res_" + item_id), tr("ui_equipment_grade") % grade])
	else:
		var count: int = int(_entry.get(
			GameManager.SLOT_ENTRY_COUNT, GameManager.get_item_count(item_id)
		))
		_add_line("%s x%d" % [tr("ui_res_" + item_id), count])

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
		_add_line("%s +%s〜%s" % [
			tr("ui_training_stat_" + stat_key),
			_stat_value_text(stat_key, base),
			_stat_value_text(stat_key, base + roll_max),
		])

	# ルーンは壊しても素材にならず、段階も分解方式では上がらない（GAME_DESIGN.md 7-7）。
	# ⚠ 判定は「runes.json にエントリが在るか」。⚠ part_kind で分岐しない。
	if not GameManager.get_rune_definition(item_id).is_empty():
		_add_line("%s %d" % [tr("ui_part_rune_merge"), GameManager.get_rune_merge_count()])
		return

	var refund: int = 0
	for amount: Variant in GameManager.get_part_dismantle_refund(item_id, 1).values():
		refund += int(amount)
	if refund > 0:
		_add_line("%s %d" % [tr("ui_part_dismantle"), refund])
	if GameManager.get_upgraded_part_id(item_id) != "":
		var cost: Dictionary = GameManager.get_part_upgrade_cost(item_id)
		_add_line("%s %s %d" % [
			tr("ui_part_upgrade"),
			tr("ui_res_" + str(cost.get(GameManager.PART_UPGRADE_MATERIAL_ID, ""))),
			int(cost.get(GameManager.PART_UPGRADE_AMOUNT, 0)),
		])


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

	_add_line(tr("ui_detail_equip_slot") % tr("ui_equipment_slot_" + equip_slot))
	# ⚠ 素の値（⚠ 等級の係数が乗る前）。⚠ 個体の数字は `get_instance_stats()` が出す。
	var stats_text: String = _stats_text(
		definition.get(GameManager.ITEM_MASTER_EQUIP_STATS, {})
	)
	if stats_text != "":
		_add_line(stats_text)

	# ⚠ 品には中身が無いので全部「空き」か「未開放」。⚠ 刺さっているものを出すのは
	#   `_show_instance()` のほう（⚠ あちらは instance_id を持っている）。
	# ⚠ 「いつ開くか」は出さない（⚠ 2026-09-07 の決定）。⚠ 2026-09-08 に、
	#   ⚠ **未開放の枠が在ること自体**は鍵のマスで見せるようにした（⚠ モック）。
	_add_part_slots(GameManager.get_part_slot_defs(equip_slot), grade)


# 枠を1行のマスで出す（2026-09-08・段階②）。⚠ 見出しに「2 / 7」を付ける。
#
# ⚠ 分母は **開いている枠の数**（⚠ 未開放は数えない）。⚠ 数えるのは `PartSlotRow`。
# ⚠ 枠が1つも無い品（⚠ 消耗品・素材）では見出しごと出さない。
func _add_part_slots(defs: Array, grade: int) -> void:
	if defs.is_empty():
		return
	var row: PartSlotRow = PartSlotRow.create(defs, grade)
	# ⚠ 1つも開いていない等級（⚠ 武器・防具は等級1〜2）では見出しごと出さない。
	#   ⚠ 未開放の枠を出さなくなったので（2026-09-08）、⚠ ここが空の行になりうる。
	if row.get_open_count() == 0:
		row.queue_free()
		return
	_add_line("%s  %d / %d" % [
		tr("ui_part_slot_header"), row.get_filled_count(), row.get_open_count()
	])
	add_child(row)


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


# 0 でない軸だけを1行にする。⚠ 10軸ぶん並べると読めない。
func _stats_text(stats: Variant) -> String:
	if not (stats is Dictionary):
		return ""
	var parts: Array[String] = []
	for stat_key: String in GameManager.get_stat_keys():
		var value: int = int((stats as Dictionary).get(stat_key, 0))
		if value == 0:
			continue
		var sign_text: String = "+" if value > 0 else ""
		parts.append("%s %s%s" % [
			tr("ui_training_stat_" + stat_key), sign_text, _stat_value_text(stat_key, value)
		])
	return "  ".join(parts)


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
	return result
