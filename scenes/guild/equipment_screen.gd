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
# 装備マスの組の名前（2026-09-15）。
const DRAG_GROUP_EQUIPMENT: String = "equipment"
# ⚠⚠ 2026-09-22（回3-b・決定 `BS-15`）：⚠ **持ち物をこの画面の中に置く**。
#   ⚠ 人間「⚠ いまいんべんとりもべつにひょうじしてるが　⚠ しょうじきいっしょのほうがべんりだから」。
#   ⚠ 組の名前は倉庫の別窓と同じ字（⚠ 装備マスが受ける組を変えないため）。
const DRAG_GROUP_INVENTORY: String = "inventory"

# --- ノード参照 ---
# ⚠⚠ 2026-09-16：⚠ **左がステータス、右が装備関連**の2列にした（人間の指示
#   「⚠ ステータスだけで画面の大半が埋まるので、⚠ ステータスを左半分 装備関連を右半分で」）。
#   ⚠ 器は `Body`（左 `Left` ／ 右 `Right`）。⚠ スクロールは右だけ。
@onready var name_label: Label = $Margin/Layout/Body/Left/NameLabel
@onready var stats_label: Label = $Margin/Layout/Body/Left/StatsLabel
# ⚠ ステータスの行の置き場（2026-09-09）。⚠ `.tscn` を触らずコードで作る
#   （⚠ プリセットの行と同じ流儀）。
@onready var stats_rows: VBoxContainer = _make_stats_rows()
# ⚠⚠ 2026-09-21：⚠ ベタ書きの1行からリソースのチップに変えた
#   （⚠ 人間の指示「⚠ 装備の素材もリソースにしてほしい」）。
#   ⚠ 並べるのは鍛冶4段＋装飾。⚠ 絞り込みは `material_ids`（⚠ 0 個でも出る）。
#   ⚠ チップの作りは `ResourceBar` の1本だけ（⚠ 2つ目を作らない）。
@onready var material_bar: ResourceBar = $Margin/Layout/Body/Right/MaterialBar
@onready var slot_list: VBoxContainer = $Margin/Layout/Body/Right/Scroll/Content/SlotList
@onready var item_header: Label = $Margin/Layout/Body/Right/Scroll/Content/ItemHeader
@onready var item_list: VBoxContainer = $Margin/Layout/Body/Right/Scroll/Content/ItemList
@onready var notice_label: Label = $Margin/Layout/NoticeLabel
# ⚠ 題と戻るは `ScreenHeader` が持つ（2026-09-09）。⚠ ボタンを直接掴まない
#   （⚠ 掴むと、⚠ 部品の作りを変えるたびに画面ぜんぶを直すことになる）。
@onready var header: ScreenHeader = $Margin/Layout/Header

var _character_id: String = ""
# いま一覧に出している部位。既定は武器（第1弾から持っている装備が武器のため）。
var _selected_slot: String = GameStateKeys.EQUIP_WEAPON

# 装飾を刺す枠を選んでいるとき、下段は「着けられる装備」ではなく
# 「刺せる装飾」に切り替わる（EXEC_DECORATION.md §3-I）。
# ⚠ _selected_part_slot が -1 のときが「装備の一覧」。画面を増やさないための切り替え。
var _selected_part_target: String = ""
var _selected_part_slot: int = -1

# ⚠⚠ 2026-09-22（回3-b）：⚠ **ビルドの行はこの画面から消した**（⚠ 人間の裁き「⚠ 消す」）。
#   ⚠ 同じ行が育成画面にもあり、⚠ 装備画面では3列に組み替えて場所が無くなったため。
#   ⚠ 口（`save_character_preset()` / `apply_character_preset()`）は**そのまま**。⚠ 押す場所が減っただけ。

# --- 持ち物の列（2026-09-22・決定 `BS-15`） ---
#
# ⚠ `.tscn` を触らずコードで作る（⚠ `_make_stats_rows()` と同じ流儀）。
# ⚠ 中身の引き方は倉庫と同じ口（`get_inventory_page_entries()`）。⚠ ここで数え直さない。
var _panel: ItemActionPanel = null
var _inventory_grid: ItemGrid = null
var _inventory_header: Label = null
var _page_label: Label = null
var _prev_button: UiButton = null
var _next_button: UiButton = null
var _page: int = 0
# ⚠ いま説明の窓に出している品。⚠ 空なら何も選んでいない。
var _selected_entry: Dictionary = {}


func _ready() -> void:
	# 1. どのキャラの装備を編集するかを受け取る。
	var data: Dictionary = SceneManager.consume_transfer_data()
	_character_id = str(data.get(TransferKeys.CHARACTER_ID, ""))

	# 2. ボタン接続
	header.back_pressed.connect(_on_back_pressed)

	# 3. GameManager のシグナル購読
	#    character_growth_changed: 着脱
	#    equipment_instances_changed: 個体が増えた・等級が上がった
	GameManager.character_growth_changed.connect(_on_character_growth_changed)
	GameManager.equipment_instances_changed.connect(_on_equipment_instances_changed)
	# ⚠ 持ち物をこの画面に置いたので、⚠ 中身が動いたら並べ直す（2026-09-22）。
	GameManager.inventory_changed.connect(_on_inventory_changed)

	# 4. 初期描画
	notice_label.text = ""
	_apply_material_filter()
	_build_panel()
	_build_inventory_column()
	if _character_id == "":
		# 直接シーンを開いたときだけ来る。育成画面からは必ず ID が入る。
		push_warning("[EquipmentScreen] character_id が渡されていない")
	_rebuild()

# ステータスの行の置き場を1つ作って、`StatsLabel` の直後へ差し込む。
func _make_stats_rows() -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "StatsRows"
	var layout: Node = stats_label.get_parent()
	layout.add_child(box)
	layout.move_child(box, stats_label.get_index() + 1)
	return box


# --- 描画 ---

func _rebuild() -> void:
	_update_header()
	_rebuild_slots()
	_rebuild_inventory()
	_rebuild_panel()

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
		return

	var char_data: Dictionary = MasterDataLoader.get_character(_character_id)
	var level: int = int(GameManager.get_character_growth(_character_id).get(GameStateKeys.GROWTH_LEVEL, 1))
	name_label.text = "%s  %s" % [
		tr(str(char_data.get("name_key", ""))),
		tr("ui_training_level") % level,
	]

	# 最終値と、そのうち装備で増えているぶんを並べて出す。
	# 「装備したら数値が変わった」が画面だけで確認できるようにするため。
	# ⚠⚠ 2026-09-09：⚠ 10軸を1つの文字列に詰めるのをやめ、⚠ `ValueRow` の行にした
	#   （⚠ 倉庫の詳細と同じ読み方にするため。⚠ 値が右に寄り、⚠ 絵と色が付く）。
	# ⚠ `StatsLabel` は器として残す（⚠ `.tscn` を触らない）。⚠ 行はその下に並べる。
	var stats: Dictionary = GameManager.get_effective_stats(_character_id)
	var bonus: Dictionary = GameManager.get_equipment_bonus(_character_id)
	stats_label.text = ""
	for child: Node in stats_rows.get_children():
		stats_rows.remove_child(child)
		child.queue_free()
	for stat_key: String in GameManager.get_stat_keys():
		var value: int = int(stats.get(stat_key, 0))
		var added: int = int(bonus.get(stat_key, 0))
		# ⚠ 装備で増えているぶんは値の後ろに足す（⚠ 「120 (+8)」）。
		var value_text: String = _stat_value_text(stat_key, value)
		if added > 0:
			value_text += "  (+%s)" % _stat_value_text(stat_key, added)
		stats_rows.add_child(ValueRow.create(
			tr("ui_training_stat_" + stat_key),
			value_text,
			ValueRow.VARIATION_GAIN if added > 0 else ValueRow.VARIATION_PLAIN,
			IconTextures.for_stat(stat_key)
		))

	# ⚠ 素材の所持数はチップが自分で出す（⚠ `material_changed` を自分で受ける）。
	#   ⚠ ここで数え直さない（⚠ 同じ数字を2箇所で組み立てない）。

# ⚠ この画面に並べる素材（2026-09-21）。
#
# ⚠ 鍛冶に使う素材は鍛冶で減るので出す。⚠ 段階の数は決め打ちしない
#   （⚠ `EquipmentConfig` の対応表を伸ばせば増える）。
# ⚠ 装飾素材も並べる。⚠ 外すと壊れて増えるので、⚠ 見えないと「壊した結果」が確認できない
#   （`EXEC_DECORATION.md` §7-C の 39）。
func _apply_material_filter() -> void:
	var ids: PackedStringArray = PackedStringArray()
	for tier: int in range(1, GameManager.get_forge_material_tier_count() + 1):
		ids.append(GameStateKeys.ITEM_FORGING_MATERIAL_PREFIX + str(tier))
	for tier: int in range(1, GameManager.get_max_part_tier() + 1):
		ids.append(GameManager.get_decor_material_id(tier))
	material_bar.material_ids = ids


# --- 説明の窓（2026-09-22・決定 `BS-16`） ---

# ⚠ 1枚だけ作る。⚠ `_rebuild()` のたびに作り直さない（⚠ 押すたびに増える）。
# ⚠ 置き場は下段（`ItemList`）。⚠ `.tscn` は触らない。
func _build_panel() -> void:
	_panel = ItemActionPanel.new()
	_panel.accept_drop_groups = [DRAG_GROUP_INVENTORY]
	_panel.changed.connect(_on_panel_changed)
	_panel.part_slot_selected.connect(_on_part_slot_selected)
	_panel.part_slot_dropped.connect(_on_part_slot_dropped)
	item_list.add_child(_panel)
	item_header.text = ""


# ⚠ 説明の窓に何を出すか。⚠ 選んでいないときは**着けている武器**を出す
#   （⚠ 空の画面にしない＝開いた直後に「何ができるか」が読める）。
func _rebuild_panel() -> void:
	if _panel == null:
		return
	if _selected_entry.is_empty():
		var equipped: Array = GameManager.get_equipment_slot_entries(_character_id)
		for row: Variant in equipped:
			var entry: Variant = (row as Dictionary).get(GameManager.SLOT_ENTRY_ENTRY, null)
			if entry is Dictionary and not (entry as Dictionary).is_empty():
				_panel.setup(entry as Dictionary, _character_id)
				return
		_panel.setup({}, _character_id)
		return
	_panel.setup(_selected_entry, _character_id)


func _on_panel_changed() -> void:
	# ⚠ 口が状態を動かした。⚠ 選んでいたものが消えている（⚠ 壊した・段階を上げた）ことがあるので畳む。
	_selected_entry = {}
	_rebuild()


# --- 持ち物の列（2026-09-22・決定 `BS-15`） ---

# ⚠ 1回だけ作る。⚠ 中身の並べ直しは `_rebuild_inventory()`。
# ⚠ 器は `Body`（横並び）の3つ目。⚠ 左＝ステータス ／ 中＝装備関連 ／ 右＝持ち物。
func _build_inventory_column() -> void:
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "InventoryColumn"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_inventory_header = Label.new()
	_inventory_header.name = "InventoryHeader"
	column.add_child(_inventory_header)

	_inventory_grid = ItemGrid.new()
	_inventory_grid.name = "InventoryGrid"
	# ⚠ 1ページの大きさは GameManager に聞く（⚠ 決定 `BS-10`。⚠ ここで掛けない）。
	_inventory_grid.columns = GameManager.get_inventory_columns()
	_inventory_grid.drag_group = DRAG_GROUP_INVENTORY
	_inventory_grid.slot_pressed.connect(_on_inventory_slot_pressed)
	# ⚠⚠ マスは 10 × 10 ＝ 100（決定 `BS-10`）。⚠ そのまま置くと**画面の縦を超える**
	#   （⚠ 2026-09-22 の実測で `736 > 720`）。⚠ だから器の中でスクロールさせる。
	#   ⚠ 中の列（装備関連）もスクロールを持っている＝⚠ 形は揃っている。
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "InventoryScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(_inventory_grid)
	column.add_child(scroll)

	var pager: HBoxContainer = HBoxContainer.new()
	pager.name = "PagerRow"
	_prev_button = UiButton.create(UiButton.Variant.SECONDARY)
	_prev_button.name = "PrevPageButton"
	_prev_button.text = "◀"
	_prev_button.pressed.connect(_on_prev_page_pressed)
	pager.add_child(_prev_button)
	_page_label = Label.new()
	_page_label.name = "PageLabel"
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pager.add_child(_page_label)
	_next_button = UiButton.create(UiButton.Variant.SECONDARY)
	_next_button.name = "NextPageButton"
	_next_button.text = "▶"
	_next_button.pressed.connect(_on_next_page_pressed)
	pager.add_child(_next_button)
	column.add_child(pager)

	var body: Node = material_bar.get_parent().get_parent()
	body.add_child(column)


# ⚠⚠ 中身は倉庫と同じ口（`get_inventory_page_entries()`）。⚠ ここで「何がマスを占めるか」を決めない。
#   ⚠ 装備中の個体はマスに出てこない（⚠ 人間の決定7。⚠ キャラの装備マスへ移っている）。
# ⚠ 枠を選んでいるあいだは**刺せる装飾だけ**に絞る（⚠ 決定 `BS-15`・⚠ 2手で刺すため）。
func _rebuild_inventory() -> void:
	if _inventory_grid == null:
		return
	if _selected_part_slot >= 0:
		_rebuild_part_items()
		return
	_page = clampi(_page, 0, GameManager.get_inventory_page_count() - 1)
	_inventory_header.text = "%s  %d/%d" % [
		tr("ui_nav_warehouse"),
		GameManager.get_inventory_slots_used(), GameManager.get_inventory_slot_max(),
	]
	_inventory_grid.accept_drop_groups = []
	_inventory_grid.visible = true
	_inventory_grid.rebuild(
		GameManager.get_inventory_page_entries(_page),
		GameManager.get_inventory_slots_per_page()
	)
	_page_label.text = "%d / %d" % [_page + 1, GameManager.get_inventory_page_count()]
	_prev_button.disabled = _page <= 0
	_next_button.disabled = _page >= GameManager.get_inventory_page_count() - 1
	_prev_button.visible = true
	_next_button.visible = true


# 刺せる装飾だけを並べる（⚠ 枠を押したあと）。
#
# ⚠ 押せるかの判定は `get_part_reject_reason()` の1本だけを見る（⚠ 2本目を書かない）。
# ⚠ その枠に刺さらない種類は**並べない**（⚠ 押せないマスを並べるより「ここには刺さらない」が伝わる）。
# ⚠ 解放されていない種類も並べない（⚠ 枠と同じ判定を通す）。
func _rebuild_part_items() -> void:
	_inventory_header.text = "%s（%s%d）" % [
		tr("ui_part_owned_header"), tr("ui_part_slot_header"), _selected_part_slot + 1
	]
	var inventory: Dictionary = GameManager.get_state().get(GameStateKeys.INVENTORY, {})
	var rows: Array[String] = []
	for item_id: String in inventory:
		var entry: Variant = inventory[item_id]
		if not (entry is Dictionary):
			continue
		if int((entry as Dictionary).get(GameStateKeys.ITEM_COUNT, 0)) <= 0:
			continue
		var definition: Dictionary = GameManager.get_part_definition(item_id)
		if definition.is_empty():
			continue
		if GameManager.get_part_reject_reason(
			_selected_part_target, _selected_part_slot, item_id
		) == GameManager.PART_REJECT_KIND:
			continue
		if not GameManager.is_part_kind_unlocked(
			str(definition.get(GameManager.ITEM_MASTER_PART_KIND, ""))
		):
			continue
		rows.append(item_id)

	# 並びは items.json の sort_order（種類 → 軸 → 段階）。
	rows.sort_custom(func(a: String, b: String) -> bool:
		return int(MasterDataLoader.get_item(a).get(GameManager.INSTANCE_VIEW_SORT_ORDER, 0)) \
			< int(MasterDataLoader.get_item(b).get(GameManager.INSTANCE_VIEW_SORT_ORDER, 0)))

	var entries: Array = []
	for item_id: String in rows:
		entries.append({
			GameManager.SLOT_ENTRY_KIND: GameManager.SLOT_KIND_ITEM,
			GameManager.SLOT_ENTRY_ITEM_ID: item_id,
			GameManager.SLOT_ENTRY_COUNT: int(
				(inventory[item_id] as Dictionary).get(GameStateKeys.ITEM_COUNT, 0)
			),
		})
	# ⚠⚠ 1つも無いときに**空のマスを10個**並べない（2026-09-22）。
	#   ⚠ 「持っていない」のか「壊れて出ていない」のかが読めない（⚠ 門3）。
	_inventory_grid.rebuild(entries, entries.size())
	_inventory_grid.visible = not entries.is_empty()
	_page_label.text = (
		tr("ui_part_attach_hint") if not entries.is_empty() else tr("ui_part_none_hint")
	)
	_prev_button.visible = false
	_next_button.visible = false


# 持ち物のマスを押した。
#
# ⚠ 枠を選んでいるときは**そのまま刺す**（⚠ 2手＝枠を押す → 装飾を押す）。
# ⚠ それ以外は説明の窓に出すだけ（⚠ 操作は向こうが並べる）。
func _on_inventory_slot_pressed(entry: Dictionary, _index: int) -> void:
	if entry.is_empty():
		return
	if _selected_part_slot >= 0:
		_on_attach_part_pressed(str(entry.get(GameManager.SLOT_ENTRY_ITEM_ID, "")))
		return
	_selected_entry = entry
	_rebuild_panel()


func _on_prev_page_pressed() -> void:
	_page = maxi(0, _page - 1)
	_rebuild_inventory()


func _on_next_page_pressed() -> void:
	_page = mini(GameManager.get_inventory_page_count() - 1, _page + 1)
	_rebuild_inventory()


func _on_inventory_changed(_item_id: String) -> void:
	_rebuild()


# --- 5部位のスロット ---

func _rebuild_slots() -> void:
	# ⚠ 並べ直すとマスが入れ替わる。⚠ 吹き出しは古いマスの位置に出たままになるので閉じる。
	SlotActionPopover.close_in(self)
	_clear(slot_list)
	_create_equipment_grid()
	# ⚠⚠ 2026-09-22（決定 `BS-16`）：⚠ **部位の行5本と装飾の枠の行は消した**。
	#   ⚠ 「選ぶ・鍛える・外す・刺す」は全部**説明の窓**へ移った。
	#   ⚠ 前は上の5マスと下の5行が同じことを言い、⚠ 押せない灰色のボタンが12個並んでいた。


# キャラの装備マス（段階18-c・人間の決定7）。
#
# ⚠⚠ 「装備するとインベントリのマスからここへ移る」を目に見える形にするもの。
#   ⚠ 中身は GameManager.get_equipment_slot_entries() の1本から引く
#     （⚠ 5枠ぶん必ず返る。⚠ 空の枠も返るので、⚠ 空きマスがそのまま並ぶ）。
# ⚠ 下の行（_create_slot_row）を消さない。⚠ 装飾・ルーン・鍛冶の操作はあちらが持つ。
#   ⚠ ここは「見える形」と「部位を選ぶ」だけ。⚠ 操作を2箇所に増やさないこと。
# ⚠ 押したときの行き先は既存の _on_select_slot_pressed()。⚠ 2本目の口を作らない。
func _create_equipment_grid() -> void:
	var grid: ItemGrid = ItemGrid.new()
	grid.name = "EquipmentGrid"
	# ⚠ 枠の数は GameManager に聞く（⚠ 5 を直接書かない。⚠ 部位が増えたら追従する）。
	grid.columns = GameManager.get_equip_slots().size()
	# ⚠ インベントリの窓から落とされたら装備する（2026-09-15）。⚠ rebuild() より先に入れる。
	grid.drag_group = DRAG_GROUP_EQUIPMENT
	grid.accept_drop_groups = [InventoryWindow.DRAG_GROUP]
	grid.slot_received.connect(_on_equipment_grid_received)
	# ⚠⚠ 枠の下に部位の名前を出す（2026-09-21・人間の指示
	#   「⚠ 枠と、頭などの部位を表すテキストを対応させて」）。
	#   ⚠ 下の行（頭：なし …）と同じ翻訳キーを引く＝⚠ 字が食い違わない。
	var captions: PackedStringArray = PackedStringArray()
	for slot_name: String in GameManager.get_equip_slots():
		captions.append(tr("ui_equipment_slot_" + slot_name))
	grid.captions = captions
	var entries: Array = []
	for row: Variant in GameManager.get_equipment_slot_entries(_character_id):
		entries.append((row as Dictionary)[GameManager.SLOT_ENTRY_ENTRY])
	grid.rebuild(entries, entries.size())
	grid.slot_pressed.connect(_on_equipment_grid_pressed)
	slot_list.add_child(grid)


# 装備マスを押した。⚠ 部位を選び、⚠ **着けているものを説明の窓に出す**（2026-09-22）。
#
# ⚠ 空のマスを押しても部位は選べること（⚠ 何も着けていない枠に着けたい場合がある）。
# ⚠⚠ 中身で照合しないこと。⚠ 空のマスは中身が全部同じなので、⚠ どれを押しても
#   最初の空き枠が選ばれてしまう。⚠ 番号（ItemGrid が渡す）で引く。
func _on_equipment_grid_pressed(entry: Dictionary, index: int) -> void:
	var slots: Array = GameManager.get_equipment_slot_entries(_character_id)
	if index < 0 or index >= slots.size():
		return
	_selected_slot = str((slots[index] as Dictionary)[GameManager.SLOT_ENTRY_EQUIP_SLOT])
	# ⚠ 枠の選択は解除する（⚠ 別の装備を見るので、⚠ 「刺せる装飾」の一覧は用が無い）。
	_selected_part_target = ""
	_selected_part_slot = -1
	_selected_entry = entry
	notice_label.text = ""
	_rebuild()

# インベントリの窓から装備マスへ落とされた（2026-09-15）。
#
# ⚠ 着けられるかの判定は GameManager.equip_instance() の1本（⚠ ここで部位を見ない）。
# ⚠ 部位は落とされたマスの番号で引く（⚠ 中身で照合しない＝空のマスは全部同じ）。
# ⚠⚠ 装備は call_deferred で呼ぶ。⚠ 装備すると両方のマス目が作り直されるので、
#   ⚠ 落とした処理の途中で、⚠ 受けているマス自身を外すことになる。
func _on_equipment_grid_received(from_grid: ItemGrid, from_index: int, to_index: int) -> void:
	var entry: Dictionary = from_grid.get_entry_at(from_index)
	if str(entry.get(GameManager.SLOT_ENTRY_KIND, "")) != GameManager.SLOT_KIND_INSTANCE:
		notice_label.text = tr("ui_equipment_failed")
		return
	var slots: Array = GameManager.get_equipment_slot_entries(_character_id)
	if to_index < 0 or to_index >= slots.size():
		return
	var slot: String = str((slots[to_index] as Dictionary)[GameManager.SLOT_ENTRY_EQUIP_SLOT])
	_equip_from_drop.call_deferred(slot, str(entry.get(GameManager.SLOT_ENTRY_INSTANCE_ID, "")))


func _equip_from_drop(slot: String, instance_id: String) -> void:
	if GameManager.equip_instance(_character_id, slot, instance_id):
		notice_label.text = tr("ui_equipment_equipped")
	else:
		notice_label.text = tr("ui_equipment_failed")
	# 再描画はシグナル側で行う。
func _add_rune_move_actions(pop: SlotActionPopover, entry: Variant) -> void:
	if not (entry is Dictionary):
		return
	var item_id: String = str((entry as Dictionary).get(GameStateKeys.PART_ITEM_ID, ""))
	var choices: Array[int] = GameManager.get_rune_move_choices(item_id)
	if choices.is_empty():
		return
	var current: int = GameManager.get_rune_move(_character_id, item_id)
	for value: int in choices:
		var button: UiButton = pop.add_action(
			tr("ui_part_rune_move_format") % value, UiButton.Variant.GHOST,
			_on_rune_move_chosen.bind(item_id, value), value == current
		)
		button.name = "RuneMove_%d" % value
	pop.set_note(tr("ui_part_rune_move"))

# ⚠ 判定は set_rune_move() が持つ。ここで choices を検算しない（2本目にしない）。
func _on_rune_move_chosen(item_id: String, value: int) -> void:
	GameManager.set_rune_move(_character_id, item_id, value)

# 枠の名前の翻訳キー。刺さる種類が1つならその種類、複数ならワイルド枠。
# ⚠ 種類ごとに if を分岐させない。種類が増えてもここは変わらない。
# ⚠ 2026-09-07：中身を `ItemDetail` へ移した（⚠ 詳細の部品でも同じ名前が要るため）。
# ⚠ 2026-09-08：さらに `PartSlotIcon` へ移した（⚠ 枠を描く部品と同じ場所。
#   ⚠ `ItemDetail` に置いたままだと `ItemDetail` ⇄ `PartSlotIcon` の循環参照になる）。
# ⚠ ここは呼ぶだけ。⚠ 2本目を書かないこと。
func _part_slot_label_key(view: Dictionary) -> String:
	return PartSlotIcon.part_slot_label_key(view)

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
func _stat_value_text(stat_key: String, value: int) -> String:
	if GameManager.is_percent_stat(stat_key):
		return "%d%%" % value
	return str(value)
# 装飾の枠を押した（2026-09-22・決定 `BS-15`）。
#
# ⚠⚠ **空きの枠** → ⚠ 右の持ち物を「刺せる装飾」に切り替える（⚠ 押して刺すまで**2手**）。
# ⚠ **刺さっている枠** → ⚠ 吹き出し（⚠ 外す・移動量）。⚠ 決定 `BS-14` のまま。
func _on_part_slot_selected(instance_id: String, slot_index: int) -> void:
	notice_label.text = ""
	var entry: Variant = _part_entry_at(instance_id, slot_index)
	if entry is Dictionary:
		_open_part_popover(instance_id, slot_index, entry as Dictionary)
		return
	_selected_part_target = instance_id
	_selected_part_slot = slot_index
	_rebuild_inventory()


# 装飾の枠へ持ち物を落とした（2026-09-22）。⚠ **つまんで落とすのも2手**。
#
# ⚠ 荷物は「どのマス目の何番か」しか運ばない（決定 `BS-6`）。⚠ 中身はここで引き直す。
# ⚠⚠ 刺すのは `call_deferred`。⚠ 刺すと両方のマス目が作り直されるので、
#   ⚠ 落とした処理の途中で、⚠ 受けているマス自身を外すことになる（⚠ 装備マスと同じ）。
func _on_part_slot_dropped(instance_id: String, slot_index: int, payload: Dictionary) -> void:
	if _inventory_grid == null:
		return
	var entry: Dictionary = _inventory_grid.get_entry_at(int(payload.get(ItemSlot.DRAG_INDEX, -1)))
	var item_id: String = str(entry.get(GameManager.SLOT_ENTRY_ITEM_ID, ""))
	if item_id == "":
		return
	_attach_from_drop.call_deferred(instance_id, slot_index, item_id)


func _attach_from_drop(instance_id: String, slot_index: int, item_id: String) -> void:
	if GameManager.attach_part(instance_id, slot_index, item_id):
		notice_label.text = tr("ui_part_attached")
		return
	# ⚠ 落とせたのに失敗した＝判定と受けがずれている。⚠ 理由をそのまま出す。
	notice_label.text = tr(GameManager.get_part_reject_reason(instance_id, slot_index, item_id))


# その枠に刺さっているもの（⚠ 無ければ null）。
#
# ⚠ `get_part_entries()` は「開いている枠」だけを返し、⚠ index は詰めない。
#   ⚠ 配列の添字ではなく index で探すこと。
func _part_entry_at(instance_id: String, slot_index: int) -> Variant:
	for view: Variant in GameManager.get_part_entries(instance_id):
		if view is Dictionary and int(
			(view as Dictionary).get(GameManager.PART_VIEW_INDEX, -1)
		) == slot_index:
			return (view as Dictionary).get(GameManager.PART_VIEW_ENTRY, null)
	return null


# 刺さっている枠の吹き出し（⚠ 外す・移動量）。⚠ 幅も置き方も部品が持つ（決定 `BS-14`）。
func _open_part_popover(instance_id: String, slot_index: int, entry: Dictionary) -> void:
	var icon: Control = _find_part_slot_icon(slot_index)
	if icon == null:
		SlotActionPopover.close_in(self)
		return
	var view: Dictionary = {}
	for raw: Variant in GameManager.get_part_entries(instance_id):
		if raw is Dictionary and int(
			(raw as Dictionary).get(GameManager.PART_VIEW_INDEX, -1)
		) == slot_index:
			view = raw
	var pop: SlotActionPopover = SlotActionPopover.open(
		self, icon.get_global_rect(), tr(_part_slot_label_key(view)), _part_text(entry)
	)
	# ⚠⚠ 外すと壊れる（GAME_DESIGN.md 7-6）＝赤（決定 `MD-5`）。⚠ 確認はハンドラ側。
	var detach: UiButton = pop.add_action(
		tr("ui_part_detach"), UiButton.Variant.DANGER,
		_on_detach_part_pressed.bind(instance_id, slot_index)
	)
	detach.name = "DetachButton"
	_add_rune_move_actions(pop, entry)


# 押した枠のマス（⚠ 吹き出しを出す位置に要る）。⚠ 描いたのは説明の窓の中の `ItemDetail`。
func _find_part_slot_icon(slot_index: int) -> Control:
	if _panel == null:
		return null
	for node: Node in _panel.find_children("PartSlot_%d" % slot_index, "", true, false):
		return node as Control
	return null

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

	# ⚠⚠ 壊すと戻らないので実行を赤に（決定 `MD-5`）。
	var confirmed: bool = await Modal.confirm(
		self, "ui_part_break_confirm", [tr("ui_res_" + item_id)], false, {
			Modal.OPTION_TITLE: tr("ui_common_title_confirm"),
			Modal.OPTION_DANGER: true,
			Modal.OPTION_CONFIRM_LABEL: "ui_common_break",
		}
	)
	if not is_instance_valid(self):
		return
	if not confirmed:
		return

	if GameManager.detach_part(instance_id, slot_index):
		notice_label.text = tr("ui_part_broken")
	else:
		notice_label.text = tr("ui_equipment_failed")
func _on_back_pressed() -> void:
	SceneManager.change_scene_with_data(TRAINING_PATH, {TransferKeys.CHARACTER_ID: _character_id})

# --- シグナルハンドラ ---

func _on_character_growth_changed(character_id: String) -> void:
	if character_id == _character_id:
		_rebuild()

func _on_equipment_instances_changed(_instance_id: String) -> void:
	_rebuild()
