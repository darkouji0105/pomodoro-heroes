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
const PRIMARY_BUTTON_SCENE: PackedScene = preload("res://scenes/ui/components/primary_button.tscn")

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

# 装飾を刺す枠を選んでいるとき、下段は「着けられる装備」ではなく
# 「刺せる装飾」に切り替わる（EXEC_DECORATION.md §3-I）。
# ⚠ _selected_part_slot が -1 のときが「装備の一覧」。画面を増やさないための切り替え。
var _selected_part_target: String = ""
var _selected_part_slot: int = -1

# ビルド（キャラプリセット）の行（EXEC_PARTY_PRESETS.md）。
#
# ⚠ 育成画面にも同じ行がある。⚠ 判定も文面も GameManager 側の1本を通るので、
#   ここに書いてあるのは器の組み立てだけ。⚠ 判定を書き足さないこと。
# ⚠ 共有部品（scripts/components/）にしていないのは、⚠ class_name を新しく作ると
#   人間がエディタを1回通すまでヘッドレスで検証できず、⚠ 「通っていないものを
#   人間に渡さない」に反するため（NEXT_STEPS §4）。⚠ 宿題に書いてある。
var _build_picker: OptionButton = null
var _selected_build: int = 0

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
	_build_preset_row()
	if _character_id == "":
		# 直接シーンを開いたときだけ来る。育成画面からは必ず ID が入る。
		push_warning("[EquipmentScreen] character_id が渡されていない")
	_rebuild()

# --- ビルドを焼く・当てる ---

# 「[ビルド1 ▼][焼く][適用]」の1行を、ヘッダの下に差し込む。
#
# ⚠ 1回だけ作る。⚠ _rebuild() のたびに作り直すと、押すたびに行が増える。
#   中身（空きかどうか）の更新は _refresh_preset_row() が持つ。
# ⚠ .tscn を触らずコードで作る。⚠ 兄弟（Label / PrimaryButton）は size_flags を
#   持たないので、こちらも合わせる（NEXT_STEPS §4「隣の兄弟の size_flags を見る」）。
func _build_preset_row() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "PresetRow"

	_build_picker = OptionButton.new()
	_build_picker.name = "BuildPicker"
	_build_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# ⚠ 接続は項目を入れる前でよい（add_item / select は item_selected を出さない）。
	_build_picker.item_selected.connect(_on_build_selected)
	row.add_child(_build_picker)

	var burn: PrimaryButton = PRIMARY_BUTTON_SCENE.instantiate()
	burn.name = "BurnButton"
	burn.label_key = "ui_party_preset_burn"
	burn.pressed.connect(_on_burn_pressed)
	row.add_child(burn)

	# ⚠ 「焼く」と「適用」は向きが逆（焼く＝現在→ビルド／適用＝ビルド→現在）。
	#   ⚠ 1つのボタンにまとめないこと。
	var apply: PrimaryButton = PRIMARY_BUTTON_SCENE.instantiate()
	apply.name = "ApplyButton"
	apply.label_key = "ui_party_preset_apply"
	apply.pressed.connect(_on_apply_pressed)
	row.add_child(apply)

	var layout: Node = name_label.get_parent()
	layout.add_child(row)
	# ⚠ add_child は末尾に付くので、必ず移動させる（ステータス表示の手前へ）。
	layout.move_child(row, stats_label.get_index())


# 選択肢の「（空き）」表示を、いまの保存状態に合わせて作り直す。
func _refresh_preset_row() -> void:
	if _build_picker == null or _character_id == "":
		return
	var presets: Array = GameManager.get_character_presets(_character_id)
	var count: int = GameManager.get_character_preset_count()
	if _selected_build >= count or _selected_build < 0:
		_selected_build = 0

	_build_picker.clear()
	for i: int in range(count):
		var label: String = tr("ui_party_preset_build") % (i + 1)
		var entry: Variant = presets[i] if i < presets.size() else null
		var saved: bool = entry is Dictionary and bool((entry as Dictionary).get(GameStateKeys.PRESET_SAVED, false))
		if not saved:
			label += "（%s）" % tr("ui_party_preset_empty")
		_build_picker.add_item(label)
	_build_picker.select(_selected_build)


func _on_build_selected(item_index: int) -> void:
	# ⚠ ここでは状態を触らない。焼く先・当てる先が変わるだけ。
	_selected_build = item_index


func _on_burn_pressed() -> void:
	if _character_id == "":
		return
	if not GameManager.save_character_preset(_character_id, _selected_build):
		# 失敗の理由は GameManager 側が push_error 済み。
		return
	_refresh_preset_row()
	notice_label.text = tr("ui_party_preset_burned") % (_selected_build + 1)


func _on_apply_pressed() -> void:
	if _character_id == "":
		return
	var report: Dictionary = GameManager.apply_character_preset(_character_id, _selected_build)
	# ⚠ 文面は GameManager が組む（適用の口が3つあるため）。
	# ⚠ 適用は character_growth_changed を飛ばすので _rebuild() が走る。
	#   ⚠ notice はそのあとに入れる（先に入れると上書きされる）。
	notice_label.text = GameManager.format_apply_report(report)

# --- 描画 ---

func _rebuild() -> void:
	_update_header()
	_rebuild_slots()
	_rebuild_items()
	_refresh_preset_row()

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
	# ⚠ 段階が4つあるので全段階を並べる。段階の数は決め打ちしない
	#   （EquipmentConfig の対応表を伸ばせば増える）。
	var material_parts: Array[String] = []
	for tier: int in range(1, GameManager.get_forge_material_tier_count() + 1):
		var material_id: String = GameStateKeys.ITEM_FORGING_MATERIAL_PREFIX + str(tier)
		material_parts.append("%s %d" % [
			tr("ui_res_" + material_id),
			GameManager.get_material_count(material_id),
		])
	# ⚠ 装飾素材も並べる。外すと壊れて増えるので、この画面で見えないと
	#   「壊した結果」が確認できない（EXEC_DECORATION.md §7-C の 39）。
	for tier: int in range(1, GameManager.get_max_part_tier() + 1):
		var decor_id: String = GameManager.get_decor_material_id(tier)
		material_parts.append("%s %d" % [
			tr("ui_res_" + decor_id),
			GameManager.get_material_count(decor_id),
		])
	material_label.text = "  ".join(material_parts)

# --- 5部位のスロット ---

func _rebuild_slots() -> void:
	_clear(slot_list)
	for slot: String in GameManager.get_equip_slots():
		_create_slot_row(slot)
		_create_part_rows(slot)

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

# --- 装飾の枠 ---

# その部位に着けている個体の枠を、開いているぶんだけ出す。
#
# ⚠ 開いていない枠は行を出さない。等級3から順に開いて最大8枠あるので、
#   閉じた枠まで出すと5部位×8行＝40行になり、装飾を1つも持っていないうちから
#   画面が枠の行で埋まる（GAME_DESIGN.md 6-4）。
# ⚠ 位置（index）は詰めない。get_part_entries() が返す index をそのまま使う。
#   詰めると別の枠に刺さる（アクセサリーだけ位置3が開くため）。
func _create_part_rows(slot: String) -> void:
	var instance_id: String = GameManager.get_equipped_instance_id(_character_id, slot)
	if instance_id == "":
		return
	for view: Variant in GameManager.get_part_entries(instance_id):
		if view is Dictionary:
			_create_part_row(slot, instance_id, view as Dictionary)

func _create_part_row(slot: String, instance_id: String, view: Dictionary) -> void:
	var slot_index: int = int(view.get(GameManager.PART_VIEW_INDEX, 0))
	var entry: Variant = view.get(GameManager.PART_VIEW_ENTRY, null)

	var row: HBoxContainer = HBoxContainer.new()
	row.name = "PartRow_%s_%d" % [slot, slot_index]

	var selected: bool = _selected_part_target == instance_id and _selected_part_slot == slot_index

	var label: Label = Label.new()
	label.name = "NameLabel"
	var mark: String = "  > " if selected else "    "
	var body: String = _part_text(entry) if entry is Dictionary else tr("ui_part_slot_empty")
	# 枠の名前は種類で出す（宝石枠 / 護符枠 / 紋章枠 / ルーン枠 / ワイルド枠）。
	# 「枠1」「枠2」だと、どの装飾が刺さるのか画面から分からない。
	label.text = "%s%s：%s" % [mark, tr(_part_slot_label_key(view)), body]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	if entry is Dictionary:
		# ⚠ 外すと壊れる（GAME_DESIGN.md 7-6）。確認モーダルはハンドラ側。
		var detach_button: Button = Button.new()
		detach_button.name = "DetachButton"
		detach_button.text = tr("ui_part_detach")
		detach_button.pressed.connect(_on_detach_part_pressed.bind(instance_id, slot_index))
		row.add_child(detach_button)
	else:
		var attach_button: Button = Button.new()
		attach_button.name = "AttachButton"
		attach_button.text = tr("ui_part_attach")
		attach_button.disabled = selected
		attach_button.pressed.connect(_on_select_part_slot_pressed.bind(instance_id, slot_index))
		row.add_child(attach_button)

	# 移動系ルーンの移動量（段階8・人間の決定・2026-08-24）。
	# ⚠ 刺す・外すと同じ行に置く。導線を2箇所にしない。
	# ⚠ 移動系でなければ何も出ない（get_rune_move_choices() が空を返す）。
	#   ⚠ part_kind で分岐しないこと。
	_add_rune_move_option(row, entry)

	slot_list.add_child(row)

# 移動量の OptionButton を1つ。移動系ルーンが刺さっていなければ何も足さない。
#
# ⚠ 選べる値も、いま選んである値も GameManager から引く。画面で計算しない。
# ⚠ 符号を必ず出す（+120 / -60）。出さないと前進か後退か読めない。
func _add_rune_move_option(row: HBoxContainer, entry: Variant) -> void:
	if not (entry is Dictionary):
		return
	var item_id: String = str((entry as Dictionary).get(GameStateKeys.PART_ITEM_ID, ""))
	var choices: Array[int] = GameManager.get_rune_move_choices(item_id)
	if choices.is_empty():
		return

	var caption: Label = Label.new()
	caption.name = "RuneMoveLabel"
	caption.text = tr("ui_part_rune_move")
	row.add_child(caption)

	var option: OptionButton = OptionButton.new()
	option.name = "RuneMoveOption"
	var current: int = GameManager.get_rune_move(_character_id, item_id)
	for i: int in range(choices.size()):
		option.add_item(tr("ui_part_rune_move_format") % choices[i], i)
		if choices[i] == current:
			option.select(i)
	option.item_selected.connect(_on_rune_move_selected.bind(item_id, choices))
	row.add_child(option)

# ⚠ 判定は set_rune_move() が持つ。ここで choices を検算しない（2本目にしない）。
func _on_rune_move_selected(item_index: int, item_id: String, choices: Array) -> void:
	if item_index < 0 or item_index >= choices.size():
		return
	GameManager.set_rune_move(_character_id, item_id, int(choices[item_index]))

# 枠の名前の翻訳キー。刺さる種類が1つならその種類、複数ならワイルド枠。
# ⚠ 種類ごとに if を分岐させない。種類が増えてもここは変わらない。
func _part_slot_label_key(view: Dictionary) -> String:
	var kinds: Variant = view.get(GameManager.PART_VIEW_KINDS, [])
	if kinds is Array and (kinds as Array).size() == 1:
		return "ui_part_slot_kind_" + str((kinds as Array)[0])
	return "ui_part_slot_kind_wild"

# 刺さっている装飾1つ分。「HPの宝石④  HP +131」。
# 加算量は GameManager.get_part_stat_value() の1本から引く（表示用に2本目を書かない）。
func _part_text(entry: Variant) -> String:
	if not (entry is Dictionary):
		return ""
	var item_id: String = str((entry as Dictionary).get(GameStateKeys.PART_ITEM_ID, ""))
	var definition: Dictionary = GameManager.get_part_definition(item_id)
	if definition.is_empty():
		# items.json から消えた装飾。加算されていないことは W18 がログで言っている。
		return tr("ui_res_" + item_id)
	var stat_key: String = str(definition.get(GameManager.ITEM_MASTER_PART_STAT, ""))
	# ステータスを足さない装飾（ルーン）。⚠ 名前だけ出す。
	#   ⚠ part_kind で分岐しない。「加算の欄があるか」で分ける（GameManager と同じ形）。
	if stat_key == "":
		return tr("ui_res_" + item_id)
	return "%s  %s +%s" % [
		tr("ui_res_" + item_id),
		tr("ui_training_stat_" + stat_key),
		_stat_value_text(stat_key, GameManager.get_part_stat_value(entry)),
	]

# --- 持っている個体の一覧 ---

func _rebuild_items() -> void:
	# 枠を選んでいるあいだは「刺せる装飾」に切り替わる。
	if _selected_part_slot >= 0:
		_rebuild_part_items()
		return

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

# 刺せる装飾の一覧。
#
# ⚠ ボタンの活性は GameManager.get_part_reject_reason() の1本だけを見る。
#   画面側に2本目の判定を書かないこと（EXEC_DECORATION.md §2-7）。
# ⚠ その部位に刺さらない種類（武器の枠に宝石）は行ごと出さない。
#   出して押せないより、並ばないほうが「ここには刺さらない」が伝わる。
func _rebuild_part_items() -> void:
	item_header.text = "%s（%s%d）" % [
		tr("ui_part_owned_header"), tr("ui_part_slot_header"), _selected_part_slot + 1
	]
	_clear(item_list)

	var inventory: Dictionary = GameManager.get_state().get(GameStateKeys.INVENTORY, {})
	var rows: Array[String] = []
	for item_id: String in inventory:
		var entry: Variant = inventory[item_id]
		if not (entry is Dictionary):
			continue
		if int((entry as Dictionary).get(GameStateKeys.ITEM_COUNT, 0)) <= 0:
			continue
		if GameManager.get_part_definition(item_id).is_empty():
			continue
		var reason: String = GameManager.get_part_reject_reason(
			_selected_part_target, _selected_part_slot, item_id
		)
		if reason == GameManager.PART_REJECT_KIND:
			continue
		rows.append(item_id)

	# 並びは items.json の sort_order（種類 → 軸 → 段階）。
	# Dictionary のキー順（＝入った順）だと段階がばらばらに並ぶ。
	rows.sort_custom(func(a: String, b: String) -> bool:
		return int(MasterDataLoader.get_item(a).get(GameManager.INSTANCE_VIEW_SORT_ORDER, 0)) \
			< int(MasterDataLoader.get_item(b).get(GameManager.INSTANCE_VIEW_SORT_ORDER, 0)))

	if rows.is_empty():
		var empty: Label = Label.new()
		empty.name = "EmptyLabel"
		empty.text = tr("ui_equipment_empty")
		item_list.add_child(empty)
		return

	for item_id: String in rows:
		_create_part_item_row(item_id, int((inventory[item_id] as Dictionary).get(GameStateKeys.ITEM_COUNT, 0)))

func _create_part_item_row(item_id: String, count: int) -> void:
	var definition: Dictionary = GameManager.get_part_definition(item_id)
	var stat_key: String = str(definition.get(GameManager.ITEM_MASTER_PART_STAT, ""))
	var base: int = int(definition.get(GameManager.ITEM_MASTER_PART_BASE, 0))
	var roll_max: int = int(definition.get(GameManager.ITEM_MASTER_PART_ROLL_MAX, 0))

	var row: HBoxContainer = HBoxContainer.new()
	row.name = "PartItemRow_" + item_id

	var label: Label = Label.new()
	label.name = "NameLabel"
	# ⚠ 出目は刺すときに振れる。確定値ではなく幅で見せる（GAME_DESIGN.md 7-6）。
	label.text = "%s ×%d  %s +%s〜%s" % [
		tr("ui_res_" + item_id), count,
		tr("ui_training_stat_" + stat_key),
		_stat_value_text(stat_key, base),
		_stat_value_text(stat_key, base + roll_max),
	]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var attach_button: Button = Button.new()
	attach_button.name = "AttachButton"
	attach_button.text = tr("ui_part_attach")
	attach_button.disabled = GameManager.get_part_reject_reason(
		_selected_part_target, _selected_part_slot, item_id
	) != ""
	attach_button.pressed.connect(_on_attach_part_pressed.bind(item_id))
	row.add_child(attach_button)

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

# 「鍛える(鍛冶の欠片 8)」。上限に達していれば「最大」。
#
# ⚠ 素材名を出すのは、等級が上がると要求される段階が変わるため
#   （4→段階2 / 7→段階3 / 10→段階4）。数だけだと何が要るのか画面で分からない。
func _forge_button_text(instance_id: String) -> String:
	if instance_id == "":
		return tr("ui_equipment_forge")
	var cost: Dictionary = GameManager.get_forge_cost(instance_id)
	var amount: int = int(cost.get(GameManager.FORGE_COST_AMOUNT, 0))
	if amount <= 0:
		return tr("ui_equipment_max_grade")
	var material_id: String = str(cost.get(GameManager.FORGE_COST_MATERIAL_ID, ""))
	return "%s(%s %d)" % [tr("ui_equipment_forge"), tr("ui_res_" + material_id), amount]

# ％系は "25%" と出す。実数はそのまま（training_screen.gd と同じ形）。
func _stat_value_text(stat_key: String, value: int) -> String:
	if GameManager.is_percent_stat(stat_key):
		return "%d%%" % value
	return str(value)

# --- 操作 ---

# 部位の切り替えはシグナルを伴わないため、ここで直接描き直す。
func _on_select_slot_pressed(slot: String) -> void:
	_selected_slot = slot
	# 部位を選び直したら、枠の選択は解除して装備の一覧に戻す。
	_selected_part_target = ""
	_selected_part_slot = -1
	notice_label.text = ""
	_rebuild()

# 枠を選ぶ。下段が「刺せる装飾」に切り替わる（シグナルを伴わないので直接描き直す）。
func _on_select_part_slot_pressed(instance_id: String, slot_index: int) -> void:
	_selected_part_target = instance_id
	_selected_part_slot = slot_index
	notice_label.text = ""
	_rebuild()

func _on_attach_part_pressed(item_id: String) -> void:
	var target: String = _selected_part_target
	var slot_index: int = _selected_part_slot
	if GameManager.attach_part(target, slot_index, item_id):
		notice_label.text = tr("ui_part_attached")
		# 刺したらいったん装備の一覧へ戻す。枠は埋まったので、
		# 同じ一覧を出したままだと「押せないボタンが並ぶ画面」になる。
		_selected_part_target = ""
		_selected_part_slot = -1
		# 再描画は equipment_instances_changed 側で行う。
	else:
		# 押せたのに失敗した＝判定と活性がずれている。理由をそのまま出す。
		notice_label.text = tr(GameManager.get_part_reject_reason(target, slot_index, item_id))

# 外すと壊れる（GAME_DESIGN.md 7-6・人間の決定D）。取り返しがつかないので確認を出す。
#
# ⚠ await のあいだに別のシグナルで再描画が走り、このノード自身が消えることがある。
#   続きを書く前に is_instance_valid(self) を見ること。
func _on_detach_part_pressed(instance_id: String, slot_index: int) -> void:
	# ⚠ get_part_entries() は「開いている枠」だけを返し、index は詰めない。
	#   配列の添字ではなく index で探すこと。
	var entry: Variant = null
	for view: Variant in GameManager.get_part_entries(instance_id):
		if view is Dictionary and int((view as Dictionary).get(GameManager.PART_VIEW_INDEX, -1)) == slot_index:
			entry = (view as Dictionary).get(GameManager.PART_VIEW_ENTRY, null)
			break
	if not (entry is Dictionary):
		return
	var item_id: String = str((entry as Dictionary).get(GameStateKeys.PART_ITEM_ID, ""))

	var confirmed: bool = await Modal.confirm(self, "ui_part_break_confirm", [tr("ui_res_" + item_id)])
	if not is_instance_valid(self):
		return
	if not confirmed:
		return

	if GameManager.detach_part(instance_id, slot_index):
		notice_label.text = tr("ui_part_broken")
	else:
		notice_label.text = tr("ui_equipment_failed")

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
