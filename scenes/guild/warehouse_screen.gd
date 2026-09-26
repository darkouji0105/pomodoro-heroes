# res://scenes/guild/warehouse_screen.gd
# 倉庫：3タブ（持ち物/素材/図鑑）。指示書 EXEC_GUILD_WAREHOUSE.md §3 準拠。
# ⚠⚠ 2026-09-23：⚠ **ふつうの画面に戻した**（人間「⚠ もう倉庫の別窓はいらない」・決定 `BS-15`）。
#   ⚠ 入口はギルドのカード（⚠ 人間の決定「1ア」）。⚠ 戻るは左上で、⚠ 行き先はギルド。
#   ⚠ 2026-09-15〜22 は OS の別窓（`InventoryWindow`）の中でだけ使っていた（⚠ 窓ごと消した）。
#   ⚠ 宝箱タブは拠点の `ChestPanel` へ移した（人間の指示「宝箱は、倉庫側ではなく拠点から直接開けるように」）。
# ⚠ 持ち物のマス目・ページ送り・枠を買うは**まだ残っている**（⚠ 容量をなくすのは持ち物の画面を作り直す回・決定 `BS-10` `BS-20`）。

class_name WarehouseScreen
extends Control

# タブタイトル用翻訳キー（_ready で set_tab_title に使う）。
# ⚠ .tscn のタブの並び（持ち物・素材・図鑑）と揃えること。
# ⚠ 素材タブ（2026-09-10・人間の指示「⚠ 素材を見れるようにしたい」）は持ち物の隣。
const TAB_TITLE_KEYS: Array[String] = [
	"ui_warehouse_tab_inventory",
	"ui_warehouse_tab_material",
	"ui_warehouse_tab_codex",
]

# 素材タブのマス目の列数（⚠ 見た目の都合だけ。⚠ バランス数値ではない）。
# ⚠ items.json の sort_order は系統ごとにまとまっているので、⚠ 4列にすると
#   **1行＝1系統（段1〜4）** になる（⚠ 建築 ／ 修練 ／ 鍛冶 ／ 装飾 の4行）。
const MATERIAL_GRID_COLUMNS: int = 4

const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
# ⚠ 図鑑タブの位置（⚠ `TAB_TITLE_KEYS` の3つ目）。
const CODEX_TAB_INDEX: int = 2
# ⚠ 持ち物のマス目の組の名前（⚠ 同じマス目の中の入れ替えに使う）。
const DRAG_GROUP: String = "inventory"


# --- ノード参照 ---
# ⚠ 題と戻るは `ScreenHeader` が持つ（⚠ ボタンを直接掴まない）。
@onready var header: ScreenHeader = $Margin/Layout/Header
@onready var tabs: TabContainer = $Margin/Layout/Tabs
# 持ち物タブはマス目（段階18-c・PLAN_INVENTORY.md）。
# ⚠⚠ 2026-09-23：⚠ **ScrollContainer に戻した**（⚠ 装備画面の右の持ち物と同じ形）。
#   ⚠ 別窓をやめて題の帯が乗り、⚠ 1280 x 720 を縦に 30px 超えた（`scenario=layout` で 902 x 750）。
#   ⚠ 中のマス目は layout で測れなくなる（宿題68）が、⚠ マス目は持ち物の画面を作り直す回で消える（決定 `BS-10`）。
@onready var inventory_grid: ItemGrid = $Margin/Layout/Tabs/InventoryTab/GridArea/InventoryScroll/InventoryGrid
@onready var capacity_label: Label = $Margin/Layout/Tabs/InventoryTab/GridArea/InventoryHeader/CapacityLabel
@onready var page_label: Label = $Margin/Layout/Tabs/InventoryTab/GridArea/PagerRow/PageLabel
# 枠を買う（段階18-e）。⚠ 値段も押せるかも GameManager に聞く。⚠ ここで式を書かない。
@onready var expand_button: UiButton = $Margin/Layout/Tabs/InventoryTab/GridArea/InventoryHeader/ExpandButton
@onready var prev_page_button: UiButton = $Margin/Layout/Tabs/InventoryTab/GridArea/PagerRow/PrevPageButton
@onready var next_page_button: UiButton = $Margin/Layout/Tabs/InventoryTab/GridArea/PagerRow/NextPageButton
# 押したマスの詳細（段階18-c-2・共有部品）。⚠ 中身の判定は部品の中で GameManager に聞く。
# ⚠⚠ 2026-09-08・段階⑤：⚠ マス目の右の **常設パネル**に移した（⚠ 人間のモック）。
#   ⚠ こちらはフル版（⚠ 分解の戻り・鍛えるコストまで出る）。⚠ ホバーの枠は別の
#   ⚠ `ItemDetail` を持ち、⚠ そちらは要約（⚠ 段階④）。⚠ 2つは中身を共有しない。
@onready var item_detail: ItemDetail = $Margin/Layout/Tabs/InventoryTab/DetailPanel/DetailMargin/DetailLayout/ItemDetail
@onready var action_row: HBoxContainer = $Margin/Layout/Tabs/InventoryTab/DetailPanel/DetailMargin/DetailLayout/ActionRow
# 素材タブ（2026-09-10）。⚠ 持ち物タブと同じ組み合わせ（⚠ マス目 ＋ 右に常設の詳細）。
#   ⚠ 素材は倉庫のマスを使わないので、⚠ ページ送りも容量も無い（⚠ 16件が1画面に収まる）。
@onready var material_grid: ItemGrid = $Margin/Layout/Tabs/MaterialTab/MaterialArea/MaterialGrid
@onready var material_detail: ItemDetail = $Margin/Layout/Tabs/MaterialTab/MaterialDetailPanel/MaterialDetailMargin/MaterialDetail
@onready var codex_list: VBoxContainer = $Margin/Layout/Tabs/CodexTab/CodexList
# ⚠⚠ `ResultLabel` は消した（2026-09-10・人間が実機で見つけた）。
#   ⚠ 2026-09-08 に開封結果の**窓**（マス目）ができたのに、⚠ その前からあった
#     検証用の文字の行が残っていて、⚠ 開けるたびに窓と二重に出ていた。
#   ⚠ 開けた中身を見せる口は `_show_reward_window()` の1本（AGENTS.md
#     「検証用のコードを本番シーンに残さない」）。

# ホバーで出る要約の器（2026-09-07）。⚠ 2026-09-08 から **自前の `ItemDetail` を持つ**
#   （⚠ 常設パネルのものを引き取ると、⚠ パネルが空になる）。
var _detail_popup: ItemDetailPopup = null

func _ready() -> void:
	# 1. タブ名を日本語化（ノード名の英語が画面に出る前に上書き）
	for i: int in range(TAB_TITLE_KEYS.size()):
		tabs.set_tab_title(i, tr(TAB_TITLE_KEYS[i]))
	# 2. 持ち物タブから始める。⚠ 2026-09-26（回UI-3）：⚠ 施設の帯の「記録」だけ図鑑タブで開く
	#   ⚠ （⚠ 記録の画面ができるまでのつなぎ・人間の選択）。
	var data: Dictionary = SceneManager.consume_transfer_data()
	var opens_codex: bool = str(data.get(TransferKeys.WAREHOUSE_TAB, "")) == TransferKeys.WAREHOUSE_TAB_CODEX
	tabs.current_tab = CODEX_TAB_INDEX if opens_codex else 0
	# 3. 戻る（⚠ 左上・行き先は本部＝拠点。⚠ ギルドの画面は消した・回UI-3）。
	header.back_pressed.connect(_on_back_pressed)
	BaseFacilityBar.attach(self, $Margin, BaseFacilityBar.RECORDS if opens_codex else BaseFacilityBar.BELONGINGS)

	# 4. GameManager のシグナル購読
	GameManager.inventory_changed.connect(_on_inventory_changed)
	# 装備は inventory ではなく equipment_instances に入るため、こちらも購読する。
	GameManager.equipment_instances_changed.connect(_on_equipment_instances_changed)
	# ⚠ 素材タブ（2026-09-10）。⚠ 素材は専用のシグナルで飛ぶ（AGENTS.md のシグナル表）。
	GameManager.material_changed.connect(_on_material_changed)
	# ⚠⚠ 着け外し（2026-09-15）。⚠ 倉庫の窓を開いたまま装備できるようになった。
	#   ⚠ 装備するとマスから外れる（決定7）が、⚠ 着け外しで飛ぶのはこのシグナルだけ
	#   ⚠ （⚠ 受けないと、⚠ 装備した品が窓のマスに残って見える・検査 equip_drag で踏んだ）。
	GameManager.character_growth_changed.connect(_on_character_growth_changed)

	# 5. マス目の配線（段階18-c）。⚠ ページ送りは GameManager に聞く（5 を直接書かない）。
	inventory_grid.columns = GameManager.get_inventory_columns()
	inventory_grid.drag_group = DRAG_GROUP
	inventory_grid.slot_pressed.connect(_on_slot_pressed)
	inventory_grid.slot_moved.connect(_on_slot_moved)
	expand_button.pressed.connect(_on_expand_pressed)
	prev_page_button.pressed.connect(_on_prev_page_pressed)
	next_page_button.pressed.connect(_on_next_page_pressed)

	# 5-b. 素材のマス目（2026-09-10）。⚠ 個数はマスの中身が持っている（`SLOT_ENTRY_COUNT`）。
	#    ⚠ 出すのは `ItemIcon` の右下（⚠ 画面側で数を描かない）。
	#    ⚠ 動かせない（⚠ `slot_moved` を繋がない）。⚠ 素材は並び順を持たない。
	material_grid.columns = MATERIAL_GRID_COLUMNS
	material_grid.slot_pressed.connect(_on_material_slot_pressed)

	# 6. ホバーの枠に、⚠ **もう1つの** `ItemDetail` を持たせる（2026-09-08・段階⑤）。
	#    ⚠ `.tscn` の `ItemDetail` は常設パネルのもの。⚠ 引き取らせない
	#    （⚠ 引き取ると常設パネルが空になり、⚠ ホバーを外すまで何も出なくなる）。
	#    ⚠ 器がボタンを持たないのは前と同じ（⚠ ホバーで消える器に操作を入れない）。
	_detail_popup = ItemDetailPopup.adopt(self, ItemDetail.new())
	if _detail_popup != null:
		_detail_popup.watch(inventory_grid)
		_detail_popup.watch(material_grid)

	# 7. 初期描画
	_rebuild_inventory()
	_rebuild_materials()
	_rebuild_codex()

# --- インベントリタブ ---

# 持ち物タブ（段階18-c・マス目）。
#
# ⚠⚠ 「何がマスを占めるか」をここで決めない。GameManager.get_inventory_page_entries()
#   が唯一の口（⚠ 装備中の個体は出てこない＝人間の決定7。キャラの装備マスへ移っている）。
# ⚠ ページの大きさも掛け算しない（get_inventory_slots_per_page()）。
# ⚠ 再描画に await を持たせない（AGENTS.md）。⚠ この画面は inventory_changed と
#   equipment_instances_changed の2本を購読していて、⚠ 1操作で2本飛ぶ。
var _page: int = 0
# いま選んでいるマスの中身。⚠ 空なら何も選んでいない。
var _selected: Dictionary = {}
# いま選んでいるマスの番号（⚠ ページを足した「通し番号」）。⚠ -1 なら選んでいない。
#   ⚠ 捨てる口はマスの番号で呼ぶ（⚠ 中身では空のマスと同じ品を区別できない）。
var _selected_index: int = -1
# 素材タブで選んでいるマスの中身（2026-09-10）。⚠ 空なら何も選んでいない。
#   ⚠ 持ち物の `_selected` と分ける。⚠ 1つにすると、⚠ タブを行き来したときに
#     ⚠ 持ち物の操作ボタンが素材に対して出る。
#   ⚠ 番号は持たない（⚠ 素材は動かせないし捨てられない＝番号で呼ぶ口が無い）。
var _selected_material: Dictionary = {}


func _rebuild_inventory() -> void:
	# ⚠ ページ数が減ったときに空のページを見続けないよう、⚠ 毎回丸める。
	_page = clampi(_page, 0, GameManager.get_inventory_page_count() - 1)

	var entries: Array = GameManager.get_inventory_page_entries(_page)
	inventory_grid.rebuild(entries, GameManager.get_inventory_slots_per_page())

	# 数値のみの組み立てなので tr() を通すのは見出しだけ（AGENTS.md）。
	capacity_label.text = "%s %d/%d" % [
		tr("ui_warehouse_capacity"),
		GameManager.get_inventory_slots_used(), GameManager.get_inventory_slot_max(),
	]
	page_label.text = "%d / %d" % [_page + 1, GameManager.get_inventory_page_count()]
	_update_expand_button()
	prev_page_button.disabled = _page <= 0
	next_page_button.disabled = _page >= GameManager.get_inventory_page_count() - 1

	# ⚠ 選んでいたものが無くなっていることがある（壊した・段階を上げた）。
	#   ⚠ 消えたのに操作ボタンが残ると、⚠ 押した瞬間に何も起きない画面になる。
	if not _selected.is_empty() and not _is_selection_alive():
		_selected = {}
		_selected_index = -1
	# ⚠⚠ 生きているなら中身を引き直す（2026-09-10・重ねる形にした回）。
	#   ⚠ 1マスに何個あるかが変わっている（⚠ ポーションを使った・拾った）。
	#   ⚠ 引き直さないと、⚠ 詳細の「×N」と「⚠ 何個捨てるか」の上限が古いまま残る。
	elif not _selected.is_empty():
		var layout: Array = GameManager.get_inventory_slot_layout()
		if _selected_index >= 0 and _selected_index < layout.size():
			_selected = layout[_selected_index]
	_rebuild_actions()


# 枠を買うボタン（段階18-e）。⚠ 値段も断る理由も GameManager の1本に聞く。
func _update_expand_button() -> void:
	var reason: String = GameManager.get_inventory_expand_reject_reason()
	if reason == GameManager.INVENTORY_EXPAND_REJECT_MAX:
		expand_button.text = tr("ui_warehouse_expand_max")
		expand_button.disabled = true
		return
	# 数値のみの組み立てなので tr() を通すのは見出しだけ（AGENTS.md）。
	expand_button.text = "%s(%d)" % [tr("ui_warehouse_expand"), GameManager.get_inventory_expand_cost()]
	expand_button.disabled = reason != ""


func _on_expand_pressed() -> void:
	if not GameManager.expand_inventory():
		return
	# ⚠ 再描画は inventory_changed 側でも走るが、⚠ ページ数が増えたことを確実に反映する。
	_rebuild_inventory()


func _on_prev_page_pressed() -> void:
	_page -= 1
	_rebuild_inventory()


func _on_next_page_pressed() -> void:
	_page += 1
	_rebuild_inventory()


# マスを押した。⚠ ここでは選ぶだけ。⚠ 何ができるかは _rebuild_actions() が出す。
#   ⚠ 押した瞬間に壊す/上げるを走らせないこと（マス目は押し間違えやすい）。
# 素材のマス目（2026-09-10・人間の指示「素材を見れるようにしたい」）。
#
# ⚠ 何が素材かは `GameManager.get_material_slot_entries()` が答える（⚠ 綴りで見分けない）。
# ⚠⚠ **持っていない素材も並ぶ**（⚠ 0個は薄いマス）。⚠ 段階ごとに要る素材が変わるので、
#   ⚠ 「まだ1個も無い」ことが見えるほうが要る。
# ⚠ 容量もページ送りも無い（⚠ 素材は倉庫のマスを使わない＝人間の決定5）。
#   ⚠ 枠の数を `entries.size()` にしているのはそのため（⚠ 空きマスを足さない）。
# ⚠ 再描画に await を持たせない（AGENTS.md）。⚠ `ItemGrid.rebuild()` がその形。
func _rebuild_materials() -> void:
	var entries: Array = GameManager.get_material_slot_entries()
	material_grid.rebuild(entries, entries.size())
	# ⚠ 右の常設パネルは、⚠ まだ何も選んでいなければ案内の1行を出す
	#   （⚠ `show_entry({})` がその文言を持つ）。⚠ ここで文言を書かない。
	if _selected_material.is_empty():
		material_detail.show_entry({})
		return
	# ⚠ 選んだままの素材の個数が変わっていることがある（⚠ 鍛えた・作った）。
	#   ⚠ 引き直さないと、⚠ 右のパネルだけ古い数を出し続ける。
	for entry: Variant in entries:
		if str((entry as Dictionary).get(GameManager.SLOT_ENTRY_ITEM_ID, "")) == str(
			_selected_material.get(GameManager.SLOT_ENTRY_ITEM_ID, "")
		):
			_selected_material = entry as Dictionary
			break
	material_detail.show_entry(_selected_material)


func _on_material_slot_pressed(entry: Dictionary, _index: int) -> void:
	_selected_material = entry
	material_detail.show_entry(entry)


# 素材が増えた／減った。⚠ 素材は専用のシグナルで飛ぶ（AGENTS.md のシグナル表）。
func _on_material_changed(_material_id: String, _new_amount: int) -> void:
	_rebuild_materials()


func _on_slot_pressed(entry: Dictionary, index: int) -> void:
	_selected = entry
	# ⚠ ページのぶんを足して「通し番号」にする（⚠ 捨てる口はこれで呼ぶ）。
	_selected_index = _page * GameManager.get_inventory_slots_per_page() + index
	_rebuild_actions()


# マスを動かした（段階18-f・ドラッグ＆ドロップ）。
#
# ⚠ マス目の番号はページの中の番号。⚠ ページのぶんをここで足す
#   （⚠ 部品はページを知らない。⚠ 足し忘れると2ページ目で1ページ目の中身が動く）。
# ⚠ 入れ替えの判定は GameManager。⚠ ここで並びを組み立て直さないこと。
func _on_slot_moved(from_index: int, to_index: int) -> void:
	var offset: int = _page * GameManager.get_inventory_slots_per_page()
	if not GameManager.move_inventory_slot(offset + from_index, offset + to_index):
		return
	# ⚠ 選んでいたマスの中身が動いたので、⚠ 詳細も含めて描き直す。
	_rebuild_inventory()


# 選んでいるものがまだ在るか。
func _is_selection_alive() -> bool:
	var kind: String = str(_selected.get(GameManager.SLOT_ENTRY_KIND, ""))
	if kind == GameManager.SLOT_KIND_INSTANCE:
		return not GameManager.get_equipment_instance(
			str(_selected.get(GameManager.SLOT_ENTRY_INSTANCE_ID, ""))
		).is_empty()
	return GameManager.get_item_count(str(_selected.get(GameManager.SLOT_ENTRY_ITEM_ID, ""))) > 0


# 選んだマスに対してできること。⚠ ボタンの中身は前と同じ（壊す・段階を上げる・重ねる）。
#   ⚠ 判定は GameManager に聞く。⚠ ここで条件を書き直さない。
func _rebuild_actions() -> void:
	_clear_container(action_row)

	# ⚠ 詳細は共有部品が出す（段階18-c-2）。⚠ ここで名前や性能を組み立てないこと
	#   （⚠ 同じものを2箇所で組み立てると、⚠ 片方だけ古い数字を出す）。
	item_detail.show_entry(_selected)

	if _selected.is_empty():
		return

	var item_id: String = str(_selected.get(GameManager.SLOT_ENTRY_ITEM_ID, ""))
	var kind: String = str(_selected.get(GameManager.SLOT_ENTRY_KIND, ""))

	if kind == GameManager.SLOT_KIND_INSTANCE:
		var instance_id: String = str(_selected.get(GameManager.SLOT_ENTRY_INSTANCE_ID, ""))
		# ⚠⚠ 鍛える（2026-09-08・人間の指示「⚠ 倉庫から鍛えていい」）。
		#   ⚠ 口は `GameManager.forge_equipment()` の1本。⚠ 装備画面と同じものを呼ぶ。
		#   ⚠ 押せるかの判定も `can_forge()` の1本（⚠ ここで条件を書き直さない）。
		#   ⚠ 文言に素材と数を入れない。⚠ 詳細の「鍛える ◯◯ 8 / 24」が既に出している
		#     （⚠ 装備画面はボタンに入れているが、⚠ あちらには詳細の行が無い）。
		#   ⚠ この画面で唯一の主要動作＝真鍮。⚠ 1画面に1個まで。
		var forge_button: UiButton = UiButton.create(
			UiButton.Variant.PRIMARY, "ui_equipment_forge"
		)
		forge_button.name = "ForgeButton"
		forge_button.disabled = not GameManager.can_forge(instance_id)
		forge_button.pressed.connect(_on_forge_pressed.bind(instance_id))
		action_row.add_child(forge_button)
		# ⚠ 装備中の個体はマス目に出てこない（決定7）ので、⚠ ここは必ず外れている。
		var dismantle_button: UiButton = UiButton.create()
		dismantle_button.name = "DismantleButton"
		dismantle_button.text = "%s(%d)" % [
			tr("ui_warehouse_dismantle"), GameManager.get_dismantle_refund_total(instance_id),
		]
		dismantle_button.pressed.connect(_on_dismantle_pressed.bind(instance_id))
		action_row.add_child(dismantle_button)
		_add_discard_button(item_id)
		return

	var count: int = GameManager.get_item_count(item_id)
	# 装飾（item_type: "part"）だけボタンが付く。⚠ items.json だけで決まる。
	if not GameManager.get_part_definition(item_id).is_empty():
		_add_part_buttons(action_row, item_id, count)
	_add_discard_button(item_id)


# 捨てる（段階18-e）。⚠ 満杯で拡張も買えないときの逃げ道（台帳 §4-2）。
#
# ⚠ 取り返しがつかないので確認モーダルを出す（⚠ 装飾の「壊す」と同じ流儀）。
# ⚠⚠ 2026-09-10：⚠ **個数を選べる**（人間の決定「⚠ 捨てるのは選べるように」）。
#   ⚠ 持ち物を重ねる形にしたので、⚠ 1マスに10個入っていることがある。
#   ⚠ 前は「1マス＝1個なので1個ずつ」だった。⚠ その前提はもう無い。
# ⚠ 装備は「素材にする」のほうが素材が戻る。⚠ ただしここで弾かない（逃げ道は塞がない）。
func _add_discard_button(item_id: String) -> void:
	# ⚠ 捨てるは **戻ってくるものが何も無い**（2026-09-09）。⚠ ＝ 危険の赤。
	#   ⚠ 「素材にする」「壊す」は素材が戻るので赤にしない（⚠ 赤を薄めない）。
	var button: UiButton = UiButton.create(UiButton.Variant.DANGER)
	button.name = "DiscardButton"
	button.text = tr("ui_warehouse_discard")
	button.pressed.connect(_on_discard_pressed.bind(item_id))
	action_row.add_child(button)


# 鍛える（2026-09-08）。⚠ 成否は GameManager が返す。⚠ ここで素材を減らさない。
#   ⚠ 再描画は equipment_instances_changed / material_changed 側でも走るが、
#   ⚠ 押した直後に「等級が上がった詳細」を出したいので、⚠ ここでも描き直す。
func _on_forge_pressed(instance_id: String) -> void:
	if not GameManager.forge_equipment(instance_id):
		return
	_rebuild_inventory()


# 捨てる。⚠ 2個以上あるときだけ「何個捨てるか」を選ばせる。
#
# ⚠ 1個しか無いとき（⚠ 装備の個体はいつもこれ）に選ばせても、⚠ 押す手数が増えるだけ。
# ⚠ 個数の器は確認モーダルの中に入れる（`Modal.OPTION_CONTENT`）。⚠ 窓を2枚出さない。
# ⚠⚠ 器は `await` をまたいで生きている必要がある（⚠ 閉じたあとに値を読む）ので、
#   ⚠ 参照をローカルに持っておく。⚠ 閉じても `ModalDialog` が解放するまでは読める。
func _on_discard_pressed(item_id: String) -> void:
	if _selected_index < 0:
		return
	var held: int = int(_selected.get(GameManager.SLOT_ENTRY_COUNT, 1))
	# ⚠⚠ 取り返しのつかない確認なので実行を赤に（決定 `MD-5`）。
	#   ⚠ 文言も「はい」ではなく「捨てる」（⚠ 押した結果が読める）。
	# ⚠ 隣の詳細パネル（幅300）と同じ大きさに合わせる（2026-09-21・決定 `MD-3`）。
	var options: Dictionary = {
		Modal.OPTION_TITLE: tr("ui_common_title_confirm"),
		Modal.OPTION_DANGER: true,
		Modal.OPTION_CONFIRM_LABEL: "ui_warehouse_discard",
		Modal.OPTION_WIDTH: Modal.WIDTH_TINY,
	}
	var picker: SpinBox = null
	# ⚠ 文言は個数の器の有無で変える。⚠ 器を出しているのに「1個捨てます」と書くと、
	#   ⚠ 器で選んだ数と文面が食い違う（⚠ 2026-09-10 に人間が実機で見つけた）。
	var message_key: String = "ui_warehouse_discard_confirm"
	if held > 1:
		picker = _make_discard_picker(held)
		options[Modal.OPTION_CONTENT] = picker
		message_key = "ui_warehouse_discard_confirm_count"
	var confirmed: bool = await Modal.confirm(
		self, message_key, [tr("ui_res_" + item_id)], false, options
	)
	if not confirmed:
		return
	# ⚠ `closed` は `queue_free()` の**前**に飛ぶので、⚠ ここではまだ器が生きている。
	#   ⚠ それでも `is_instance_valid()` で守る（⚠ 画面遷移で捨てられた道がある）。
	var count: int = 1
	if picker != null and is_instance_valid(picker):
		count = int(picker.value)
	if not GameManager.discard_inventory_slot(_selected_index, count):
		return
	_selected = {}
	_selected_index = -1
	_rebuild_inventory()


# 「何個捨てるか」の器。⚠ 1 〜 持っている数。⚠ 既定は1個（⚠ 事故を小さいほうに倒す）。
#   ⚠ 見た目の値は Theme が持つ（AGENTS.md）。⚠ ここで色も大きさも書かない。
func _make_discard_picker(held: int) -> SpinBox:
	var picker: SpinBox = SpinBox.new()
	picker.name = "DiscardCount"
	picker.min_value = 1
	picker.max_value = held
	picker.value = 1
	picker.step = 1
	# ⚠ 押し続けて max を超えないように（⚠ Godot の既定は循環しない）。
	picker.allow_greater = false
	picker.allow_lesser = false
	return picker


# 子を消す。await を持たせない（AGENTS.md「再描画は await を持たせない」）。
func _clear_container(container: Container) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _on_dismantle_pressed(instance_id: String) -> void:
	if not GameManager.dismantle_equipment(instance_id):
		push_warning("[WarehouseScreen] dismantle_equipment failed: " + instance_id)
	# 再描画は equipment_instances_changed 側で行う。

# 装飾の行に付くボタン。装備の個体の行（_create_instance_entry）と同じ形。
#
# ⚠ 「壊す」は確認モーダルを出さない。減るのは在庫の余りだけで、装備に刺さっている
#   ものは減らないため（装備の「素材にする」も確認を出していない）。
#   ⚠ 刺さっているものを壊すのは装備画面の「外す」側。あちらは取り返しがつかないので
#     確認モーダルを出す（EXEC_DECORATION.md §3-J）。
# ⚠ 段階が上限の装飾には「段階を上げる」を出さない（行き先が無い）。
# ⚠ 段階18-c で置き場所が「行の中」から「選んだときの操作の列」へ移った。
# ⚠ 中身は変えていない（壊す・段階を上げる・重ねる）。
func _add_part_buttons(entry: Container, item_id: String, count: int) -> void:
	# ルーンは分解方式で上がらず、壊しても素材にならない（GAME_DESIGN.md 7-7）。
	# ⚠ ボタンは「重ねる」の1つだけ。⚠ part_kind で分岐しない。
	if not GameManager.get_rune_definition(item_id).is_empty():
		_add_rune_merge_button(entry, item_id)
		return

	var refund_total: int = 0
	for amount: Variant in GameManager.get_part_dismantle_refund(item_id, 1).values():
		refund_total += int(amount)

	var dismantle_button: UiButton = UiButton.create()
	dismantle_button.name = "PartDismantleButton"
	dismantle_button.text = "%s(%d)" % [tr("ui_part_dismantle"), refund_total]
	dismantle_button.disabled = count <= 0 or refund_total <= 0
	dismantle_button.pressed.connect(_on_part_dismantle_pressed.bind(item_id))
	entry.add_child(dismantle_button)

	if GameManager.get_upgraded_part_id(item_id) == "":
		return

	var cost: Dictionary = GameManager.get_part_upgrade_cost(item_id)
	var upgrade_button: UiButton = UiButton.create()
	upgrade_button.name = "PartUpgradeButton"
	# ⚠ 素材名を出すのは、段階ごとに要る素材が変わるため（鍛冶ボタンと同じ理由）。
	upgrade_button.text = "%s(%s %d)" % [
		tr("ui_part_upgrade"),
		tr("ui_res_" + str(cost.get(GameManager.PART_UPGRADE_MATERIAL_ID, ""))),
		int(cost.get(GameManager.PART_UPGRADE_AMOUNT, 0)),
	]
	upgrade_button.disabled = not GameManager.can_upgrade_part(item_id)
	upgrade_button.pressed.connect(_on_part_upgrade_pressed.bind(item_id))
	entry.add_child(upgrade_button)

# ルーンを重ねるボタン。⚠ 段階が上限なら出さない（かけらは今回作っていない）。
#
# ⚠ 押せるかの判定は get_rune_merge_reject_reason() の1本。画面で数えないこと。
func _add_rune_merge_button(entry: Container, item_id: String) -> void:
	var reason: String = GameManager.get_rune_merge_reject_reason(item_id)
	if reason == GameManager.RUNE_REJECT_MAX or reason == GameManager.RUNE_REJECT_KIND:
		return
	var cost: int = GameManager.get_rune_merge_count()
	var merge_button: UiButton = UiButton.create()
	merge_button.name = "RuneMergeButton"
	merge_button.text = "%s(%d)" % [tr("ui_part_rune_merge"), cost]
	merge_button.disabled = reason != ""
	merge_button.pressed.connect(_on_rune_merge_pressed.bind(item_id))
	entry.add_child(merge_button)

func _on_rune_merge_pressed(item_id: String) -> void:
	if not GameManager.merge_runes(item_id):
		push_warning("[WarehouseScreen] merge_runes failed: " + item_id)
	# 再描画は inventory_changed 側で行う。

func _on_part_dismantle_pressed(item_id: String) -> void:
	if GameManager.dismantle_part(item_id, 1).is_empty():
		push_warning("[WarehouseScreen] dismantle_part failed: " + item_id)
	# 再描画は inventory_changed 側で行う。

func _on_part_upgrade_pressed(item_id: String) -> void:
	if not GameManager.upgrade_part(item_id):
		push_warning("[WarehouseScreen] upgrade_part failed: " + item_id)

# --- 図鑑タブ ---

func _rebuild_codex() -> void:
	_clear_container(codex_list)

	var state: Dictionary = GameManager.get_state()
	var codex: Dictionary = state.get(GameStateKeys.CODEX, {})

	if codex.is_empty():
		codex_list.add_child(EmptyState.create("ui_warehouse_empty"))
		return

	for item_id: String in codex:
		var entry: Dictionary = codex[item_id]
		var discovered: bool = bool(entry.get(GameStateKeys.CODEX_DISCOVERED, false))
		_create_codex_row(item_id, discovered)

func _create_codex_row(item_id: String, discovered: bool) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "CodexRow_" + item_id

	# ⚠ 未発見の行にアイコンを出さない。文字で中身が割れる。
	if discovered:
		row.add_child(ItemIcon.create(item_id))

	var name_label: Label = Label.new()
	if discovered:
		name_label.text = tr("ui_res_" + item_id)
	else:
		name_label.text = tr("ui_warehouse_undiscovered")
	name_label.name = "NameLabel"
	row.add_child(name_label)

	codex_list.add_child(row)

# --- シグナルハンドラ ---

# 着けた／外した（2026-09-15）。⚠ 持ち物のマスから出入りする（決定7）。
func _on_character_growth_changed(_character_id: String) -> void:
	_rebuild_inventory()


func _on_inventory_changed(_item_id: String) -> void:
	_rebuild_inventory()
	_rebuild_codex()

func _on_equipment_instances_changed(_instance_id: String) -> void:
	_rebuild_inventory()
	_rebuild_codex()


func _on_back_pressed() -> void:
	SceneManager.change_scene(BASE_PATH)
