class_name ItemActionPanel
extends VBoxContainer

# 品の「説明 ＋ できること」を1枚にまとめた器（2026-09-22・回3-b・決定 `BS-16`）。
#
# ⚠⚠ 人間の言葉：⚠ 「⚠ アイテムの説明に一本化したほうがいいかも　⚠ 装飾と鍛えるのは」。
#   ⚠ 前は操作が3箇所に散っていた（⚠ 装備画面の部位の行 ／ 倉庫の操作の列 ／ 枠の吹き出し）。
#
# ⚠ 中身は**押した品の種類で変わる**（⚠ 装備の個体 ／ 装飾 ／ 素材）。
#   ⚠ 画面ごとに if を書かない。⚠ 種類の分岐はここ1本。
# ⚠⚠ **判定は全部 `GameManager` の口に聞く。** ⚠ ここに2本目の判定を書かないこと
#   （⚠ 押せるか・値段・戻る素材・刺さるか）。
# ⚠ 説明そのものは `ItemDetail`（⚠ 既存の部品）。⚠ 名前や性能をここで組み立てない。
# ⚠ 2画面以上で使うので `scenes/ui/components/`（AGENTS.md）。⚠ `.tscn` を持たない。
#
# ⚠⚠ 無名関数をシグナルにつながない（⚠ `Lambda capture ... was freed`）。⚠ 名前付き＋`bind()`。

# ⚠ 状態が動いたので画面は描き直してほしい（⚠ 何が起きたかは言わない）。
signal changed
# ⚠ 装飾の枠を押した（⚠ 「ここに刺したい」）。⚠ 刺せる品を並べるのは画面の仕事。
signal part_slot_selected(instance_id: String, slot_index: int)
# ⚠ 装飾の枠へ品を落とした。⚠ 荷物の中身（⚠ どのマス目の何番か）を引くのは画面。
signal part_slot_dropped(instance_id: String, slot_index: int, payload: Dictionary)

# ⚠ 落とせる相手（⚠ 持ち物のマス目の組の名前）。⚠ 画面が入れる。
var accept_drop_groups: Array[String] = []

var _entry: Dictionary = {}
var _character_id: String = ""
var _detail: ItemDetail = null
var _actions: HFlowContainer = null


func _init() -> void:
	name = "ItemActionPanel"
	theme_type_variation = &"TightList"
	_detail = ItemDetail.new()
	_detail.name = "Detail"
	add_child(_detail)
	_actions = HFlowContainer.new()
	_actions.name = "Actions"
	add_child(_actions)


# 出し直す。⚠ `character_id` が空なら「着ける」を出さない（⚠ 倉庫から使うとき）。
func setup(entry: Dictionary, character_id: String = "") -> void:
	_entry = entry.duplicate(true)
	_character_id = character_id
	_rebuild()


func get_entry() -> Dictionary:
	return _entry.duplicate(true)


# ⚠ 再描画に `await` を持たせない（AGENTS.md）。⚠ `remove_child()` してから `queue_free()`。
func _rebuild() -> void:
	for child: Node in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()

	_detail.show_entry(_entry)
	if _entry.is_empty():
		return

	# ⚠ 枠は `ItemDetail` が描いている（⚠ 器を2つにしない）。⚠ ここは**押せるようにするだけ**。
	_wire_part_slots()

	var kind: String = str(_entry.get(GameManager.SLOT_ENTRY_KIND, ""))
	if kind == GameManager.SLOT_KIND_INSTANCE:
		_build_instance_actions(str(_entry.get(GameManager.SLOT_ENTRY_INSTANCE_ID, "")))
		return
	_build_item_actions(str(_entry.get(GameManager.SLOT_ENTRY_ITEM_ID, "")))


# --- 装備の個体 ---

# ⚠ 主要動作（真鍮）は**1画面に1個**（決定 `UI-2`）。⚠ ここでは「鍛える」に使う。
#   ⚠ 「着ける」は既定、⚠ 「外す」は Ghost（⚠ 取り返しがつくので赤にしない）。
func _build_instance_actions(instance_id: String) -> void:
	if instance_id == "":
		return
	var equipped_by: String = str(_entry.get(GameManager.SLOT_ENTRY_EQUIPPED_BY, ""))
	if _character_id != "":
		if equipped_by == _character_id:
			var off: UiButton = UiButton.create(UiButton.Variant.GHOST, "ui_equipment_unequip")
			off.name = "UnequipButton"
			off.pressed.connect(_on_unequip_pressed.bind(instance_id))
			_actions.add_child(off)
		else:
			var on: UiButton = UiButton.create(UiButton.Variant.SECONDARY, "ui_equipment_equip")
			on.name = "EquipButton"
			on.pressed.connect(_on_equip_pressed.bind(instance_id))
			_actions.add_child(on)

	# ⚠ 文言に素材と数を入れる（⚠ 段ごとに要る素材が変わる＝押す前に読めること）。
	var forge: UiButton = UiButton.create(UiButton.Variant.PRIMARY)
	forge.name = "ForgeButton"
	forge.text = _forge_text(instance_id)
	forge.disabled = not GameManager.can_forge(instance_id)
	forge.pressed.connect(_on_forge_pressed.bind(instance_id))
	_actions.add_child(forge)

	# ⚠ 素材にする（⚠ 装備中の個体は外してからでないと出さない＝持ち物に出てこない）。
	if equipped_by == "":
		var melt: UiButton = UiButton.create()
		melt.name = "DismantleButton"
		melt.text = "%s(%d)" % [
			tr("ui_warehouse_dismantle"), GameManager.get_dismantle_refund_total(instance_id)
		]
		melt.pressed.connect(_on_dismantle_pressed.bind(instance_id))
		_actions.add_child(melt)


func _forge_text(instance_id: String) -> String:
	var cost: Dictionary = GameManager.get_forge_cost(instance_id)
	var amount: int = int(cost.get(GameManager.FORGE_COST_AMOUNT, 0))
	if amount <= 0:
		return tr("ui_equipment_max_grade")
	return "%s(%s %d)" % [
		tr("ui_equipment_forge"),
		tr("ui_res_" + str(cost.get(GameManager.FORGE_COST_MATERIAL_ID, ""))),
		amount,
	]


# --- 装飾・素材 ---

# ⚠ 装飾（`item_type: "part"`）だけボタンが付く。⚠ 決まるのは `items.json` だけ。
# ⚠⚠ 装飾は「鍛える」ではなく「段階を上げる」（決定 `BS-18`）。⚠ 混ぜない。
func _build_item_actions(item_id: String) -> void:
	if item_id == "" or GameManager.get_part_definition(item_id).is_empty():
		return
	# ⚠ ルーンは分解方式で上がらない（GAME_DESIGN.md 7-7）。⚠ ボタンは「重ねる」1つだけ。
	if not GameManager.get_rune_definition(item_id).is_empty():
		var reason: String = GameManager.get_rune_merge_reject_reason(item_id)
		if reason == GameManager.RUNE_REJECT_MAX or reason == GameManager.RUNE_REJECT_KIND:
			return
		var merge: UiButton = UiButton.create()
		merge.name = "RuneMergeButton"
		merge.text = "%s(%d)" % [tr("ui_part_rune_merge"), GameManager.get_rune_merge_count()]
		merge.disabled = reason != ""
		merge.pressed.connect(_on_rune_merge_pressed.bind(item_id))
		_actions.add_child(merge)
		return

	var refund_total: int = 0
	for amount: Variant in GameManager.get_part_dismantle_refund(item_id, 1).values():
		refund_total += int(amount)
	var break_button: UiButton = UiButton.create()
	break_button.name = "PartDismantleButton"
	break_button.text = "%s(%d)" % [tr("ui_part_dismantle"), refund_total]
	break_button.disabled = refund_total <= 0
	break_button.pressed.connect(_on_part_dismantle_pressed.bind(item_id))
	_actions.add_child(break_button)

	if GameManager.get_upgraded_part_id(item_id) == "":
		return
	var cost: Dictionary = GameManager.get_part_upgrade_cost(item_id)
	var upgrade: UiButton = UiButton.create()
	upgrade.name = "PartUpgradeButton"
	upgrade.text = "%s(%s %d)" % [
		tr("ui_part_upgrade"),
		tr("ui_res_" + str(cost.get(GameManager.PART_UPGRADE_MATERIAL_ID, ""))),
		int(cost.get(GameManager.PART_UPGRADE_AMOUNT, 0)),
	]
	upgrade.disabled = not GameManager.can_upgrade_part(item_id)
	upgrade.pressed.connect(_on_part_upgrade_pressed.bind(item_id))
	_actions.add_child(upgrade)


# --- 装飾の枠（⚠ `ItemDetail` が描いたマスを押せるようにする） ---

# ⚠⚠ 枠を描くのは `ItemDetail` の1本（決定 `BS-14`）。⚠ ここで並べ直さない。
#   ⚠ 描いたあとのマスを拾って、⚠ 押す・落とすをつなぐ。
func _wire_part_slots() -> void:
	var instance_id: String = str(_entry.get(GameManager.SLOT_ENTRY_INSTANCE_ID, ""))
	if instance_id == "":
		return
	# ⚠⚠ 門1（2026-09-22）：⚠ **装飾そのものがまだ解放されていない**ことがある
	#   （⚠ `floor_3` をクリアすると開く）。⚠ 前は枠の行ごと消えていて、
	#   ⚠ **画面に装飾の話が一文字も出なかった**（⚠ 人間「⚠ そもそも装飾をつけれない」）。
	#   ⚠ 押せるようにせず、⚠ 代わりに1行だけ出す。⚠ 判定は `GameManager` の1本。
	if not GameManager.is_part_kind_unlocked(GameManager.PART_KIND_GEM):
		var locked: Label = Label.new()
		locked.name = "PartGateLabel"
		locked.theme_type_variation = &"MutedLabel"
		locked.text = tr("ui_part_gate_locked")
		add_child(locked)
		move_child(locked, _actions.get_index())
		return
	for node: Node in _detail.find_children("*", "PartSlotIcon", true, false):
		var icon: PartSlotIcon = node
		icon.accept_drop_groups = accept_drop_groups.duplicate()
		icon.pressed.connect(_on_part_slot_pressed.bind(instance_id))
		icon.dropped.connect(_on_part_slot_dropped.bind(instance_id))


func _on_part_slot_pressed(view: Dictionary, instance_id: String) -> void:
	part_slot_selected.emit(instance_id, int(view.get(GameManager.PART_VIEW_INDEX, 0)))


func _on_part_slot_dropped(view: Dictionary, payload: Dictionary, instance_id: String) -> void:
	part_slot_dropped.emit(
		instance_id, int(view.get(GameManager.PART_VIEW_INDEX, 0)), payload
	)


# --- 押されたもの（⚠ 口は全部 `GameManager`。⚠ ここで状態を組み立てない） ---

func _on_equip_pressed(instance_id: String) -> void:
	if GameManager.equip_instance(
		_character_id, _instance_equip_slot(instance_id), instance_id
	):
		changed.emit()


func _on_unequip_pressed(instance_id: String) -> void:
	if GameManager.unequip_instance(_character_id, _instance_equip_slot(instance_id)):
		changed.emit()


# ⚠ 部位は品のマスターが持っている（⚠ 画面で決めない）。
func _instance_equip_slot(instance_id: String) -> String:
	var item_id: String = str(
		GameManager.get_equipment_instance(instance_id).get(GameStateKeys.INSTANCE_ITEM_ID, "")
	)
	return str(MasterDataLoader.get_item(item_id).get(GameManager.ITEM_MASTER_EQUIP_SLOT, ""))


func _on_forge_pressed(instance_id: String) -> void:
	if GameManager.forge_equipment(instance_id):
		changed.emit()


func _on_dismantle_pressed(instance_id: String) -> void:
	if GameManager.dismantle_equipment(instance_id):
		changed.emit()


func _on_rune_merge_pressed(item_id: String) -> void:
	if GameManager.merge_runes(item_id):
		changed.emit()


func _on_part_dismantle_pressed(item_id: String) -> void:
	if not GameManager.dismantle_part(item_id, 1).is_empty():
		changed.emit()


func _on_part_upgrade_pressed(item_id: String) -> void:
	if GameManager.upgrade_part(item_id):
		changed.emit()


# 検証用の行（⚠ 設計役は絵を取れるが、⚠ 「何が押せるか」は文で取る）。
func to_text() -> String:
	var parts: Array[String] = []
	for child: Node in _actions.get_children():
		if child is Button:
			parts.append("[%s%s]" % [
				(child as Button).text, "・押せない" if (child as Button).disabled else ""
			])
	return " ".join(parts)
