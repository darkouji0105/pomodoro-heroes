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

	# 刺さっている装飾。⚠ 開いている枠だけ出す（GameManager が開いているぶんだけ返す）。
	for view: Variant in GameManager.get_part_entries(instance_id):
		if not (view is Dictionary):
			continue
		var slot_index: int = int((view as Dictionary).get(GameManager.PART_VIEW_INDEX, 0))
		var part_entry: Variant = (view as Dictionary).get(GameManager.PART_VIEW_ENTRY, null)
		var body: String = tr("ui_part_slot_empty")
		if part_entry is Dictionary:
			var part_id: String = str((part_entry as Dictionary).get(GameStateKeys.PART_ITEM_ID, ""))
			# ⚠ 出目込みの確定値は get_part_stat_value() の1本（表示も加算もここを通る）。
			#   ⚠ base + roll をここで足し直さないこと。
			var part_stat: String = str(
				GameManager.get_part_definition(part_id).get(GameManager.ITEM_MASTER_PART_STAT, "")
			)
			body = tr("ui_res_" + part_id)
			if part_stat != "":
				body += "  %s +%s" % [
					tr("ui_training_stat_" + part_stat),
					_stat_value_text(part_stat, GameManager.get_part_stat_value(part_entry)),
				]
		_add_line("  [%d] %s" % [slot_index + 1, body])

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
	var count: int = int(_entry.get(
		GameManager.SLOT_ENTRY_COUNT, GameManager.get_item_count(item_id)
	))
	_add_line("%s x%d" % [tr("ui_res_" + item_id), count])

	var definition: Dictionary = GameManager.get_part_definition(item_id)
	if definition.is_empty():
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
func get_lines() -> Array[String]:
	var result: Array[String] = []
	for child in get_children():
		if child is Label:
			result.append((child as Label).text)
	return result
