extends Control

# ボスを倒した後の「わかれ道の画面」（2026-09-21・決定48）。
#
# ⚠⚠ 人間の言葉：「⚠ そもそも上がるか上がらないかの選択肢を、⚠ 別画面で出して、
#   ⚠ それからショップに遷移するか拠点に戻るように」。
#
# ⚠⚠ 決定15（2026-09-02）の「⚠ ボスの直後にショップを見せ、⚠ **そこで**続行／撤退を選ぶ」と、
#   ⚠ 09-20 の「⚠ ボスの後に**自動で**ショップを見せる」を覆したもの。
#   ⚠ **決定15 の狙い（お預けポイントを作らない）は残る。⚠ 変わったのは選ぶ場所だけ。**
#
# ⚠ 拒否仕様の「ボス画面」とは別物（決定48-c・人間の裁き「⚠ 3 別物」）。
#   ⚠ ボスの演出ではなく、⚠ ボスを倒した**後**の分かれ道。
#
# ⚠⚠ 左上の「戻る」は出さない（人間「⚠ 2 は出さない」）。
#   ⚠ ここは「どちらかを選ぶ」画面なので、⚠ 戻る先が無い。
#
# ⚠ 判定は GameManager の口に聞く（⚠ 階の数や phase をここで数えない）。
#
# ⚠⚠ 2026-09-27（回UI-4・手本 DungeonFork）：⚠ **傾いた紙のカード2枚**にした。
#   ⚠ 左＝「ここで戻る」（⚠ 鞄の中身を持ち帰る・中身のマス目）／ ⚠ 右＝「さらに潜る」（⚠ 次のフロア・3人の HP・倒れたら鞄は空）。
#   ⚠ ボタンと持ち物の箱は `.tscn` のまま**カードへ付け替える**（⚠ 名前を保つ＝検査 E147 が名前で探す）。
#   ⚠ 最後の階では右のカードごと出さない（決定26・判定は `can_descend_dungeon_floor()`）。

const SHOP_PATH: String = "res://scenes/adventure/dungeon_shop.tscn"
const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const DUNGEON_MAP_PATH: String = "res://scenes/adventure/dungeon_map.tscn"
const REPORT_PATH: String = "res://scenes/adventure/run_report_screen.tscn"

@onready var heading: Label = $Margin/Layout/Heading
@onready var caption: Label = $Margin/Layout/Caption
@onready var loot_title: Label = $Margin/Layout/LootTitle
@onready var loot_box: VBoxContainer = $Margin/Layout/LootBox
@onready var descend_button: UiButton = $Margin/Layout/Buttons/DescendButton
@onready var retreat_button: UiButton = $Margin/Layout/Buttons/RetreatButton


func _ready() -> void:
	SceneManager.consume_transfer_data()
	# ⚠ ランの中では右上の常駐の通貨を出さない（決定 `NAV-4`）。
	ResourceHud.set_shown(false)

	descend_button.pressed.connect(_on_descend_pressed)
	retreat_button.pressed.connect(_on_retreat_pressed)
	_build_cards()

	# ⚠⚠ ボスを倒した先でなければ、⚠ この画面に居座らせない（⚠ 直接開かれたとき）。
	if not GameManager.can_retreat_from_dungeon():
		push_warning("[DungeonFloorClear] ⚠ ボスの先に居ないので開かない")
		SceneManager.change_scene(DUNGEON_MAP_PATH)
		return

	_rebuild()


func _rebuild() -> void:
	# 数値のみの組み立てなので、tr() を通すのは見出しだけ（AGENTS.md）。
	# ⚠ 「40層　ボスを倒した」（2026-10-03・決定49・手本 DungeonFork）。⚠ 出口の層＝このフロアの最後の層。
	var per_floor: int = GameManager.get_dungeon_layers_per_floor()
	heading.text = tr("ui_dungeon_clear_heading") % GameManager.get_dungeon_absolute_layer(per_floor)
	caption.text = tr("ui_dungeon_clear_caption")
	# ⚠ 塔は「12階を抜けた」（2026-10-09・回D-塔・⚠ 層の字は出さない）。
	var tower: bool = GameManager.is_tower_dungeon()
	if tower:
		heading.text = tr("ui_tower_clear_heading") % GameManager.get_dungeon_floor_index()
	# ⚠ 「ふつうに戦う」（1階だけ・2026-10-10）は「クリアした」。
	if tower and GameManager.get_dungeon_max_floors() <= 1:
		heading.text = tr("ui_simple_clear_heading")

	# ⚠⚠ 何を手に入れたかを見せる（決定48-a・人間「⚠ 何を手に入れたか見れる画面を」）。
	#   ⚠ 見せるのは**鞄の中身**（⚠ まだ渡していない。⚠ 「ここで戻る」を押したときに渡る）。
	_rebuild_loot()

	# ⚠ 最後の階を突破したら「さらに潜る」は出さない（決定26）。⚠ 判定は GameManager に聞く。
	descend_button.visible = GameManager.can_descend_dungeon_floor()
	_descend_card.visible = descend_button.visible
	# ⚠ 次のフロアの層の幅「41–50層」。
	var next_first: int = GameManager.get_dungeon_floor_first_layer(GameManager.get_dungeon_floor_index() + 1)
	_next_floor_label.text = (
		tr("ui_tower_floor_no") % (GameManager.get_dungeon_floor_index() + 1) if tower
		else tr("ui_dungeon_layer_range") % [next_first, next_first + per_floor - 1]
	)
	for child in _party_box.get_children():
		_party_box.remove_child(child)
		child.queue_free()
	for member: Variant in GameManager.get_party_members():
		if str(member) != "":
			_party_box.add_child(RunPartyStrip.make_cell(GameManager.RUN_KIND_DUNGEON, str(member)))


var _descend_card: TiltedSheet = null
var _next_floor_label: Label = null
var _party_box: VBoxContainer = null


# ⚠ 2枚のカードを組む（⚠ 1回だけ）。⚠ `.tscn` のボタン・持ち物の見出し・箱を付け替える。
func _build_cards() -> void:
	heading.theme_type_variation = &"HeadingLabel"
	var layout: VBoxContainer = $Margin/Layout
	var cards: HBoxContainer = HBoxContainer.new()
	cards.name = "Cards"
	cards.theme_type_variation = &"WideRow"
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(cards)
	layout.move_child(cards, caption.get_index() + 1)

	var retreat_card: TiltedSheet = TiltedSheet.create(0)
	retreat_card.name = "RetreatCard"
	retreat_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_child(retreat_card)
	var left: VBoxContainer = _card_column(retreat_card, "ui_dungeon_clear_retreat", "ui_dungeon_fork_retreat_caption")
	_move_into(loot_title, left)
	_move_into(loot_box, left)
	loot_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	retreat_button.label_key = "ui_dungeon_retreat"
	retreat_button.variant = UiButton.Variant.SECONDARY
	retreat_button.size_flags_horizontal = Control.SIZE_FILL
	_move_into(retreat_button, left)

	_descend_card = TiltedSheet.create(2)
	_descend_card.name = "DescendCard"
	_descend_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_child(_descend_card)
	var right: VBoxContainer = _card_column(_descend_card, "ui_dungeon_clear_descend", "")
	# ⚠ 題は「もう10層」（2026-10-03・決定49・手本 DungeonFork）。⚠ 層の数は GameManager に聞く。
	(right.get_child(0) as Label).text = tr("ui_dungeon_fork_descend_title") % GameManager.get_dungeon_layers_per_floor()
	# ⚠ 塔は「上る」（2026-10-09・回D-塔）。
	if GameManager.is_tower_dungeon():
		(right.get_child(0) as Label).text = tr("ui_tower_fork_descend_title")
	_next_floor_label = Label.new()
	_next_floor_label.name = "NextRangeLabel"
	_next_floor_label.theme_type_variation = &"SheetHeadingLabel"
	_next_floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(_next_floor_label)
	_party_box = VBoxContainer.new()
	_party_box.name = "PartyBox"
	_party_box.theme_type_variation = &"TightList"
	_party_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_party_box)
	var warning: Label = Label.new()
	warning.theme_type_variation = &"ErrorLabel"
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.text = tr("ui_dungeon_fork_warning")
	right.add_child(warning)
	descend_button.label_key = "ui_tower_fork_descend_button" if GameManager.is_tower_dungeon() else "ui_dungeon_fork_descend_button"
	descend_button.variant = UiButton.Variant.SECONDARY
	descend_button.size_flags_horizontal = Control.SIZE_FILL
	_move_into(descend_button, right)
	# ⚠ 空になったボタンの行は隠す（⚠ 消すと検査の道がずれる）。
	($Margin/Layout/Buttons as Control).visible = false


# カードの中の縦の並び（⚠ 題＝明朝 ／ 小さい説明）。
func _card_column(card: TiltedSheet, title_key: String, caption_key: String) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.theme_type_variation = &"SectionGap"
	card.sheet.add_child(column)
	var title: Label = Label.new()
	title.theme_type_variation = &"SheetHeadingLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = tr(title_key)
	column.add_child(title)
	if caption_key != "":
		var note: Label = Label.new()
		note.theme_type_variation = &"CaptionLabel"
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.text = tr(caption_key)
		column.add_child(note)
	return column


func _move_into(node: Node, parent: Node) -> void:
	node.get_parent().remove_child(node)
	parent.add_child(node)


# 鞄の中身をマス目で出す。⚠ 空なら「手ぶら」と出す（⚠ 行ごと消さない＝何も無いことが読めない）。
func _rebuild_loot() -> void:
	# ⚠ 先に外してから捨てる（CLAUDE.md 5番）。
	for child in loot_box.get_children():
		loot_box.remove_child(child)
		child.queue_free()

	var bag: Dictionary = GameManager.get_dungeon_bag()
	var item_ids: Array = bag.keys()
	item_ids.sort()
	loot_title.text = tr("ui_dungeon_clear_loot")
	if item_ids.is_empty():
		var empty: Label = Label.new()
		empty.name = "EmptyLabel"
		# ⚠ この画面は見出しも説明もボタンも中央。⚠ 既定の左寄せだと**ここだけ左端に落ちる**
		#   （⚠ 2026-09-22 に絵で見つけた。⚠ 空のときにしか出ないので実機で見落とされていた）。
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.theme_type_variation = &"MutedLabel"
		empty.text = tr("ui_dungeon_clear_loot_none")
		loot_box.add_child(empty)
		return

	var grid: ItemGrid = ItemGrid.new()
	grid.name = "LootGrid"
	grid.columns = GameManager.get_dungeon_bag_slots()
	var entries: Array = []
	for raw: Variant in item_ids:
		var item_id: String = str(raw)
		# ⚠ 鍵（⚠ 等級つきの装備は `item_id#等級`）からマスを作る口は GameManager の1本（2026-10-03・回4-b）。
		entries.append(GameManager.make_run_item_entry(item_id, int(bag[item_id])))
	grid.rebuild(entries, entries.size())
	loot_box.add_child(grid)


# ⚠⚠ さらに潜る。⚠ ここでは潜らない（決定48）。
#   ⚠ 先に潜ると `can_retreat_from_dungeon()` が false になり、⚠ 店が空になる。
#   ⚠ 潜るのは**ショップを出たとき**（`dungeon_shop.gd`）。
# ⚠ ショップは飛ばせない（人間「⚠ 飛ばさないでもいいと思う　⚠ ただ出ればいいだけだから」）。
func _on_descend_pressed() -> void:
	# ⚠⚠ 塔は店を挟まず上る（2026-10-09・回D-塔・`DG-3`＝商人は特別な階だけ）。
	if GameManager.is_tower_dungeon():
		if not GameManager.descend_dungeon_floor():
			push_warning("[DungeonFloorClear] ⚠ 塔の次の階へ上れなかった（⚠ 最後の階か、主の先に居ない）")
		SceneManager.change_scene(DUNGEON_MAP_PATH)
		return
	SceneManager.change_scene_with_data(SHOP_PATH, {
		TransferKeys.DUNGEON_DESCEND_AFTER_SHOP: true,
	})


# ⚠⚠ ここで戻る＝鞄の中身を持ち帰ってラン終了（決定48-a）。⚠ 拠点へ直行。
#   ⚠ ラン専用の品は消える（決定17）。⚠ 全ロストではない（⚠ 自分で降りたので）。
#   ⚠ 2026-09-29（回UI-仕組み④・`EXEC_RUN_REPORT.md`）：⚠ 拠点へ直行せず**帰還報告書**へ（⚠ 本部へはそこから）。
func _on_retreat_pressed() -> void:
	var _result: Dictionary = GameManager.retreat_from_dungeon()
	SceneManager.change_scene(REPORT_PATH)
