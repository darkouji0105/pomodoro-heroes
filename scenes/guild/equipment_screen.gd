# res://scenes/guild/equipment_screen.gd
# 装備画面（第2弾：5部位・個体管理・鍛冶）。
# ショップ・作業場と同じ作りにそろえている：1画面・スクロール・行をコードで生成・詳細画面なし。
# 戻るボタンは1つだけ（育成で2つ並んだ不具合を繰り返さない）。
#
# 上段が5部位のスロット、下段が「選んでいる部位に着けられる個体」の一覧。
# 装備は在庫を触らないため、着脱で飛ぶシグナルは character_growth_changed の1本だけ。
#
# 鍛冶をこの画面に置いているのは、作業場が「レシピを選んでキューに入れる」形で
# 個体IDを渡す隙間が無いため。第1弾は待ち時間なし（素材だけで等級が上がる）。
#
# material_changed を購読していないのは、鍛冶が add_material() と
# equipment_instances_changed の2本を続けて飛ばすため。両方購読すると行が二重に並ぶ。
# 所持素材のラベルは _rebuild() の中で読み直している。

class_name EquipmentScreen
extends Control

const TRAINING_PATH: String = "res://scenes/guild/training_screen.tscn"

# --- ノード参照 ---
@onready var name_label: Label = $Margin/Layout/NameLabel
@onready var stats_label: Label = $Margin/Layout/StatsLabel
@onready var material_label: Label = $Margin/Layout/MaterialLabel
@onready var slot_list: VBoxContainer = $Margin/Layout/Scroll/Content/SlotList
@onready var item_header: Label = $Margin/Layout/Scroll/Content/ItemHeader
@onready var item_list: VBoxContainer = $Margin/Layout/Scroll/Content/ItemList
@onready var notice_label: Label = $Margin/Layout/NoticeLabel
@onready var back_button: PrimaryButton = $Margin/Layout/BackButton

var _character_id: String = ""
# いま一覧に出している部位。既定は武器（第1弾から持っている装備が武器のため）。
var _selected_slot: String = GameStateKeys.EQUIP_WEAPON

func _ready() -> void:
	# 1. どのキャラの装備を編集するかを受け取る。
	var data: Dictionary = SceneManager.consume_transfer_data()
	_character_id = str(data.get(TransferKeys.CHARACTER_ID, ""))

	# 2. ボタン接続
	back_button.pressed.connect(_on_back_pressed)

	# 3. GameManager のシグナル購読
	#    character_growth_changed: 着脱
	#    equipment_instances_changed: 個体が増えた・等級が上がった
	GameManager.character_growth_changed.connect(_on_character_growth_changed)
	GameManager.equipment_instances_changed.connect(_on_equipment_instances_changed)

	# 4. 初期描画
	notice_label.text = ""
	if _character_id == "":
		# 直接シーンを開いたときだけ来る。育成画面からは必ず ID が入る。
		push_warning("[EquipmentScreen] character_id が渡されていない")
	_rebuild()

# --- 描画 ---

func _rebuild() -> void:
	_update_header()
	_rebuild_slots()
	_rebuild_items()

# remove_child してから queue_free する。await を挟むと再描画が並走し、行が二重に並ぶ
# （AGENTS.md「再描画は await を持たせない」）。
func _clear(container: VBoxContainer) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _update_header() -> void:
	if _character_id == "":
		name_label.text = ""
		stats_label.text = ""
		material_label.text = ""
		return

	var char_data: Dictionary = MasterDataLoader.get_character(_character_id)
	var level: int = int(GameManager.get_character_growth(_character_id).get(GameStateKeys.GROWTH_LEVEL, 1))
	name_label.text = "%s  %s" % [
		tr(str(char_data.get("name_key", ""))),
		tr("ui_training_level") % level,
	]

	# 最終値と、そのうち装備で増えているぶんを並べて出す。
	# 「装備したら数値が変わった」が画面だけで確認できるようにするため。
	var stats: Dictionary = GameManager.get_effective_stats(_character_id)
	var bonus: Dictionary = GameManager.get_equipment_bonus(_character_id)
	var lines: Array[String] = []
	for stat_key: String in GameManager.get_stat_keys():
		var label: String = tr("ui_training_stat_" + stat_key)
		var value: int = int(stats.get(stat_key, 0))
		var added: int = int(bonus.get(stat_key, 0))
		if added > 0:
			lines.append("%s  %s  (+%s)" % [
				label, _stat_value_text(stat_key, value), _stat_value_text(stat_key, added)
			])
		else:
			lines.append("%s  %s" % [label, _stat_value_text(stat_key, value)])
	stats_label.text = "\n".join(lines)

	# 鍛冶に使う素材の所持数。鍛冶で減るので、この画面に出しておく。
	material_label.text = "%s %d" % [
		tr("ui_res_" + GameManager.FORGE_MATERIAL_ID),
		GameManager.get_material_count(GameManager.FORGE_MATERIAL_ID),
	]

# --- 5部位のスロット ---

func _rebuild_slots() -> void:
	_clear(slot_list)
	for slot: String in GameManager.get_equip_slots():
		_create_slot_row(slot)

func _create_slot_row(slot: String) -> void:
	var instance_id: String = GameManager.get_equipped_instance_id(_character_id, slot)

	var row: HBoxContainer = HBoxContainer.new()
	row.name = "SlotRow_" + slot

	var label: Label = Label.new()
	label.name = "NameLabel"
	var mark: String = "> " if slot == _selected_slot else "  "
	if instance_id == "":
		label.text = "%s%s：%s" % [mark, tr("ui_equipment_slot_" + slot), tr("ui_equipment_none")]
	else:
		label.text = "%s%s：%s" % [mark, tr("ui_equipment_slot_" + slot), _instance_text(instance_id)]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	# この部位の一覧を下に出す。
	var select_button: Button = Button.new()
	select_button.name = "SelectButton"
	select_button.text = tr("ui_equipment_select")
	select_button.disabled = slot == _selected_slot
	select_button.pressed.connect(_on_select_slot_pressed.bind(slot))
	row.add_child(select_button)

	# 装備中のものを鍛える。
	var forge_button: Button = Button.new()
	forge_button.name = "ForgeButton"
	forge_button.text = _forge_button_text(instance_id)
	forge_button.disabled = instance_id == "" or not GameManager.can_forge(instance_id)
	forge_button.pressed.connect(_on_forge_pressed.bind(instance_id))
	row.add_child(forge_button)

	var unequip_button: Button = Button.new()
	unequip_button.name = "UnequipButton"
	unequip_button.text = tr("ui_equipment_unequip")
	unequip_button.disabled = instance_id == ""
	unequip_button.pressed.connect(_on_unequip_pressed.bind(slot))
	row.add_child(unequip_button)

	slot_list.add_child(row)

# --- 持っている個体の一覧 ---

func _rebuild_items() -> void:
	item_header.text = "%s（%s）" % [
		tr("ui_equipment_owned_header"),
		tr("ui_equipment_slot_" + _selected_slot),
	]
	_clear(item_list)

	var instances: Array = GameManager.get_equippable_instances(_selected_slot)
	if instances.is_empty():
		var empty: Label = Label.new()
		empty.name = "EmptyLabel"
		empty.text = tr("ui_equipment_empty")
		item_list.add_child(empty)
		return

	for entry: Variant in instances:
		if entry is Dictionary:
			_create_item_row(entry as Dictionary)

func _create_item_row(view: Dictionary) -> void:
	var instance_id: String = str(view.get(GameManager.INSTANCE_VIEW_ID, ""))

	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ItemRow_" + instance_id

	var label: Label = Label.new()
	label.name = "NameLabel"
	label.text = _instance_text(instance_id)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var equip_button: Button = Button.new()
	equip_button.name = "EquipButton"
	equip_button.text = tr("ui_equipment_equip")
	equip_button.disabled = _character_id == ""
	equip_button.pressed.connect(_on_equip_pressed.bind(instance_id))
	row.add_child(equip_button)

	var forge_button: Button = Button.new()
	forge_button.name = "ForgeButton"
	forge_button.text = _forge_button_text(instance_id)
	forge_button.disabled = not GameManager.can_forge(instance_id)
	forge_button.pressed.connect(_on_forge_pressed.bind(instance_id))
	row.add_child(forge_button)

	item_list.add_child(row)

# --- 表示の組み立て ---

# 「鉄の剣 等級2  攻撃 +10」の形にする。
# 装備名だけ翻訳キー（ui_res_*）を引き、性能はデータから組み立てる。
func _instance_text(instance_id: String) -> String:
	var instance: Dictionary = GameManager.get_equipment_instance(instance_id)
	if instance.is_empty():
		return instance_id
	var item_id: String = str(instance.get(GameStateKeys.INSTANCE_ITEM_ID, ""))
	var grade: int = int(instance.get(GameStateKeys.INSTANCE_GRADE, 1))
	return "%s %s  %s" % [
		tr("ui_res_" + item_id),
		tr("ui_equipment_grade") % grade,
		_stats_text(GameManager.get_instance_stats(instance_id)),
	]

func _stats_text(stats: Variant) -> String:
	if not (stats is Dictionary):
		return ""
	var parts: Array[String] = []
	for stat_key: String in GameManager.get_stat_keys():
		var value: int = int((stats as Dictionary).get(stat_key, 0))
		# 0 の軸は出さない。10軸ぶん並べると1行が読めなくなる。
		if value == 0:
			continue
		var sign_text: String = "+" if value > 0 else ""
		parts.append("%s %s%s" % [
			tr("ui_training_stat_" + stat_key), sign_text, _stat_value_text(stat_key, value)
		])
	return "  ".join(parts)

# 「鍛える(4)」。上限に達していれば「最大」。
func _forge_button_text(instance_id: String) -> String:
	if instance_id == "":
		return tr("ui_equipment_forge")
	var cost: Dictionary = GameManager.get_forge_cost(instance_id)
	var amount: int = int(cost.get(GameManager.FORGE_COST_AMOUNT, 0))
	if amount <= 0:
		return tr("ui_equipment_max_grade")
	return "%s(%d)" % [tr("ui_equipment_forge"), amount]

# ％系は "25%" と出す。実数はそのまま（training_screen.gd と同じ形）。
func _stat_value_text(stat_key: String, value: int) -> String:
	if GameManager.is_percent_stat(stat_key):
		return "%d%%" % value
	return str(value)

# --- 操作 ---

# 部位の切り替えはシグナルを伴わないため、ここで直接描き直す。
func _on_select_slot_pressed(slot: String) -> void:
	_selected_slot = slot
	notice_label.text = ""
	_rebuild()

func _on_equip_pressed(instance_id: String) -> void:
	if GameManager.equip_instance(_character_id, _selected_slot, instance_id):
		notice_label.text = tr("ui_equipment_equipped")
	else:
		notice_label.text = tr("ui_equipment_failed")
	# 再描画はシグナル側で行う。

func _on_unequip_pressed(slot: String) -> void:
	if GameManager.unequip_instance(_character_id, slot):
		notice_label.text = tr("ui_equipment_unequipped")
	else:
		notice_label.text = tr("ui_equipment_failed")

func _on_forge_pressed(instance_id: String) -> void:
	if GameManager.forge_equipment(instance_id):
		notice_label.text = tr("ui_equipment_forged")
	else:
		notice_label.text = tr("ui_equipment_failed")

func _on_back_pressed() -> void:
	SceneManager.change_scene(TRAINING_PATH)

# --- シグナルハンドラ ---

func _on_character_growth_changed(character_id: String) -> void:
	if character_id == _character_id:
		_rebuild()

func _on_equipment_instances_changed(_instance_id: String) -> void:
	_rebuild()
