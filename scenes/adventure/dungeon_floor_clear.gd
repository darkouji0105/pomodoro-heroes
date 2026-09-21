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

const SHOP_PATH: String = "res://scenes/adventure/dungeon_shop.tscn"
const BASE_PATH: String = "res://scenes/base/base_screen.tscn"
const DUNGEON_MAP_PATH: String = "res://scenes/adventure/dungeon_map.tscn"

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

	# ⚠⚠ ボスを倒した先でなければ、⚠ この画面に居座らせない（⚠ 直接開かれたとき）。
	if not GameManager.can_retreat_from_dungeon():
		push_warning("[DungeonFloorClear] ⚠ ボスの先に居ないので開かない")
		SceneManager.change_scene(DUNGEON_MAP_PATH)
		return

	_rebuild()


func _rebuild() -> void:
	# 数値のみの組み立てなので、tr() を通すのは見出しだけ（AGENTS.md）。
	heading.text = "%s %d" % [tr("ui_dungeon_clear_heading"), GameManager.get_dungeon_floor_index()]
	caption.text = tr("ui_dungeon_clear_caption")

	# ⚠⚠ 何を手に入れたかを見せる（決定48-a・人間「⚠ 何を手に入れたか見れる画面を」）。
	#   ⚠ 見せるのは**鞄の中身**（⚠ まだ渡していない。⚠ 「ここで戻る」を押したときに渡る）。
	_rebuild_loot()

	# ⚠ 最後の階を突破したら「さらに潜る」は出さない（決定26）。⚠ 判定は GameManager に聞く。
	descend_button.visible = GameManager.can_descend_dungeon_floor()


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
		entries.append({
			GameManager.SLOT_ENTRY_ITEM_ID: item_id,
			GameManager.SLOT_ENTRY_COUNT: int(bag[item_id]),
		})
	grid.rebuild(entries, entries.size())
	loot_box.add_child(grid)


# ⚠⚠ さらに潜る。⚠ ここでは潜らない（決定48）。
#   ⚠ 先に潜ると `can_retreat_from_dungeon()` が false になり、⚠ 店が空になる。
#   ⚠ 潜るのは**ショップを出たとき**（`dungeon_shop.gd`）。
# ⚠ ショップは飛ばせない（人間「⚠ 飛ばさないでもいいと思う　⚠ ただ出ればいいだけだから」）。
func _on_descend_pressed() -> void:
	SceneManager.change_scene_with_data(SHOP_PATH, {
		TransferKeys.DUNGEON_DESCEND_AFTER_SHOP: true,
	})


# ⚠⚠ ここで戻る＝鞄の中身を持ち帰ってラン終了（決定48-a）。⚠ 拠点へ直行。
#   ⚠ ラン専用の品は消える（決定17）。⚠ 全ロストではない（⚠ 自分で降りたので）。
func _on_retreat_pressed() -> void:
	var _result: Dictionary = GameManager.retreat_from_dungeon()
	SceneManager.change_scene(BASE_PATH)
