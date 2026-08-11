# res://scenes/guild/equipment_screen.gd
# 装備画面（第1弾：武器スロット1つ・ステータス加算のみ）。
# ショップ・作業場と同じ作りにそろえている：1画面・スクロール・行をコードで生成・詳細画面なし。
# 戻るボタンは1つだけ（育成で2つ並んだ不具合を繰り返さない）。
#
# 装備すると inventory から減り、外すと戻る。装備中のものは一覧に出ない。
# 性能値は状態に持たず、毎回 items.json から引き直す（GameManager.get_equipment_bonus）。

class_name EquipmentScreen
extends Control

const TRAINING_PATH: String = "res://scenes/guild/training_screen.tscn"

# 第1弾は武器スロットだけを扱う。armor / accessory は状態側に器があるが画面に出さない。
const TARGET_SLOT: String = GameStateKeys.EQUIP_WEAPON

# --- ノード参照 ---
@onready var name_label: Label = $Margin/Layout/NameLabel
@onready var stats_label: Label = $Margin/Layout/StatsLabel
@onready var equipped_row: HBoxContainer = $Margin/Layout/EquippedRow
@onready var equipped_label: Label = $Margin/Layout/EquippedRow/EquippedLabel
@onready var unequip_button: Button = $Margin/Layout/EquippedRow/UnequipButton
@onready var item_list: VBoxContainer = $Margin/Layout/Scroll/Content/ItemList
@onready var notice_label: Label = $Margin/Layout/NoticeLabel
@onready var back_button: PrimaryButton = $Margin/Layout/BackButton

var _character_id: String = ""

func _ready() -> void:
	# 1. どのキャラの装備を編集するかを受け取る。
	var data: Dictionary = SceneManager.consume_transfer_data()
	_character_id = str(data.get(TransferKeys.CHARACTER_ID, ""))

	# 2. ボタン接続
	back_button.pressed.connect(_on_back_pressed)
	unequip_button.pressed.connect(_on_unequip_pressed)

	# 3. GameManager のシグナル購読
	#    着脱は character_growth_changed と inventory_changed を続けて発火する。
	#    _rebuild() に await を持たせていないのはそのため（AGENTS.md「再描画は await を持たせない」）。
	GameManager.character_growth_changed.connect(_on_character_growth_changed)
	GameManager.inventory_changed.connect(_on_inventory_changed)

	# 4. 初期描画
	notice_label.text = ""
	if _character_id == "":
		# 直接シーンを開いたときだけ来る。育成画面からは必ず ID が入る。
		push_warning("[EquipmentScreen] character_id が渡されていない")
	_rebuild()

# --- 描画 ---

func _rebuild() -> void:
	_update_header()
	_update_equipped()

	# remove_child してから queue_free する。await を挟むと、1回の着脱で飛ぶ
	# 2本のシグナルによって再描画が並走し、行が二重に並ぶ。
	for child: Node in item_list.get_children():
		item_list.remove_child(child)
		child.queue_free()

	var items: Array = GameManager.get_equippable_items(TARGET_SLOT)
	if items.is_empty():
		var empty: Label = Label.new()
		empty.name = "EmptyLabel"
		empty.text = tr("ui_equipment_empty")
		item_list.add_child(empty)
		return

	for entry: Variant in items:
		if entry is Dictionary:
			_create_item_row(entry as Dictionary)

func _update_header() -> void:
	if _character_id == "":
		name_label.text = ""
		stats_label.text = ""
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
	for pair: Array in [
		[GameStateKeys.STAT_HP, "ui_training_stat_hp"],
		[GameStateKeys.STAT_ATK, "ui_training_stat_atk"],
		[GameStateKeys.STAT_DEF, "ui_training_stat_def"],
		[GameStateKeys.STAT_SPD, "ui_training_stat_spd"],
	]:
		var stat_key: String = str(pair[0])
		var value: int = int(stats.get(stat_key, 0))
		var added: int = int(bonus.get(stat_key, 0))
		if added > 0:
			lines.append("%s  %d  (+%d)" % [tr(str(pair[1])), value, added])
		else:
			lines.append("%s  %d" % [tr(str(pair[1])), value])
	stats_label.text = "\n".join(lines)

func _update_equipped() -> void:
	var item_id: String = GameManager.get_equipped_item_id(_character_id, TARGET_SLOT)
	if item_id == "":
		equipped_label.text = "%s：%s" % [tr("ui_equipment_slot_weapon"), tr("ui_equipment_none")]
		unequip_button.disabled = true
		return
	equipped_label.text = "%s：%s" % [tr("ui_equipment_slot_weapon"), tr("ui_res_" + item_id)]
	unequip_button.disabled = false

# --- 所持している装備の行 ---

func _create_item_row(entry: Dictionary) -> void:
	var item_id: String = str(entry.get(GameManager.RECIPE_IO_ITEM_ID, ""))

	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ItemRow_" + item_id

	var label: Label = Label.new()
	label.name = "NameLabel"
	label.text = "%s ×%d  %s" % [
		tr("ui_res_" + item_id),
		int(entry.get(GameManager.RECIPE_IO_COUNT, 0)),
		_stats_text(entry.get(GameManager.ITEM_MASTER_EQUIP_STATS, {})),
	]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var equip_button: Button = Button.new()
	equip_button.name = "EquipButton"
	equip_button.text = tr("ui_equipment_equip")
	equip_button.disabled = _character_id == ""
	equip_button.pressed.connect(_on_equip_pressed.bind(item_id))
	row.add_child(equip_button)

	item_list.add_child(row)

# 「攻撃 +8」の形にする。equip_stats に書かれたステータスだけを並べる。
# 装備名の翻訳キー（ui_res_*）と違い、性能はデータから組み立てるので ja.csv を触らない。
func _stats_text(stats: Variant) -> String:
	if not (stats is Dictionary):
		return ""
	var parts: Array[String] = []
	for pair: Array in [
		[GameStateKeys.STAT_HP, "ui_training_stat_hp"],
		[GameStateKeys.STAT_ATK, "ui_training_stat_atk"],
		[GameStateKeys.STAT_DEF, "ui_training_stat_def"],
		[GameStateKeys.STAT_SPD, "ui_training_stat_spd"],
	]:
		var value: int = int((stats as Dictionary).get(str(pair[0]), 0))
		if value != 0:
			parts.append("%s %+d" % [tr(str(pair[1])), value])
	return "  ".join(parts)

# --- 操作 ---

func _on_equip_pressed(item_id: String) -> void:
	if GameManager.equip_item(_character_id, TARGET_SLOT, item_id):
		notice_label.text = tr("ui_equipment_equipped")
	else:
		notice_label.text = tr("ui_equipment_failed")
	# 再描画はシグナル側で行う。

func _on_unequip_pressed() -> void:
	if GameManager.unequip_item(_character_id, TARGET_SLOT):
		notice_label.text = tr("ui_equipment_unequipped")
	else:
		notice_label.text = tr("ui_equipment_failed")

func _on_back_pressed() -> void:
	SceneManager.change_scene(TRAINING_PATH)

# --- シグナルハンドラ ---

func _on_character_growth_changed(character_id: String) -> void:
	if character_id == _character_id:
		_rebuild()

func _on_inventory_changed(_item_id: String) -> void:
	_rebuild()
