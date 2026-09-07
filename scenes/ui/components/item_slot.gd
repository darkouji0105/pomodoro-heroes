class_name ItemSlot
extends Button

# マス目の1マス（段階18-a・PLAN_INVENTORY.md §6）。
#
# ⚠ 2画面以上で使うので scenes/ui/components/（AGENTS.md「UIパーツの置き場所」）。
#   ⚠ 出す先は 倉庫（18-c）と ダンジョンの鞄（18-d）。
# ⚠ 中身の絵は ItemIcon に任せる。⚠ ここに2本目の「字と色」を書かないこと。
# ⚠ 空のマスも同じ部品で描く。⚠ 「空きが見える」ことがマス目にする理由そのものなので、
#   ⚠ 空のときだけ別のノードを使う形にしない（数が合わなくなる）。
# ⚠ 何がマスを占めるかはここで決めない。GameManager.get_inventory_slot_entries() が正。
#
# ⚠ 数字（右下の段数）は ItemIcon が出す。⚠ こちらが出す左下の数は
#   「同じ品を何個持っているか」ではない（重ねない＝人間の決定3）。
#   ⚠ 装備しているキャラの印だけに使う。⚠ 個数を出す形に変えないこと。

# 装備中の印。⚠ 文字にしない（キャラ名は長さがまちまちでマスからはみ出す）。
const EQUIPPED_MARK: String = "E"
# 空のマスの薄さ。⚠ 押せるが何も無いことが分かる程度に落とす。
const EMPTY_MODULATE: Color = Color(1.0, 1.0, 1.0, 0.35)

const SCENE_PATH: String = "res://scenes/ui/components/item_slot.tscn"

# 押されたら、そのマスの中身をそのまま渡す。⚠ 空のマスなら空の Dictionary。
signal slot_pressed(entry: Dictionary)
# マウスが乗った／外れた（2026-09-07・人間の指示「ホバーするだけで詳細を表示」）。
#
# ⚠ 空のマスでも飛ばす（⚠ 「空だから出さない」の判定は受け手側の1本＝`ItemDetailPopup`）。
signal slot_hovered(entry: Dictionary)
signal slot_unhovered()
# ここへ他のマスが落とされた。⚠ 渡ってくるのは「落とした側のマスの番号」。
signal slot_dropped(from_index: int)

# ドラッグの荷物の鍵（段階18-f）。⚠ 綴りを散らさない。
#   ⚠ この鍵が入っていない荷物は受け取らない（⚠ 他の画面からのドラッグを弾く）。
const DRAG_KEY: String = "item_slot_drag"
const DRAG_INDEX: String = "index"
# つまんでいるあいだの見た目の薄さ。
const DRAG_PREVIEW_MODULATE: Color = Color(1.0, 1.0, 1.0, 0.7)

@onready var icon_holder: CenterContainer = $IconHolder
@onready var count_label: Label = $CountLabel

var _entry: Dictionary = {}
var _icon: ItemIcon = null
# このマスが何番目か（段階18-f）。⚠ ItemGrid が入れる。
#   ⚠ 空のマスは中身が全部同じなので、⚠ 番号でしか区別できない。
var _index: int = 0


# 呼ぶ側の1行の口（ItemIcon.create() と同じ形）。
static func create(entry: Dictionary = {}) -> ItemSlot:
	var scene: PackedScene = load(SCENE_PATH)
	var slot: ItemSlot = scene.instantiate()
	slot.setup(entry)
	return slot


func _ready() -> void:
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_refresh()


# マスの中身を差し替える。⚠ 空にするときは {} を渡す。
func setup(entry: Dictionary) -> void:
	_entry = entry.duplicate(true)
	# ⚠ create() は add_child() の前に呼ぶので、@onready はまだ null。
	#   その場合は _ready() 側が描く（ItemIcon と同じ流儀）。
	if is_inside_tree():
		_refresh()


func get_entry() -> Dictionary:
	return _entry.duplicate(true)


# ⚠⚠ 名前に "index" だけを使わないこと。⚠ Node が get_index() を持っていて、
#   ⚠ 上書きするとパースエラーになる（2026-09-03 に踏んだ）。
func set_slot_index(index: int) -> void:
	_index = index


func get_slot_index() -> int:
	return _index


# --- ドラッグ＆ドロップ（段階18-f） ---
#
# ⚠ Godot の Control の仕組みをそのまま使う（_get_drag_data / _can_drop_data / _drop_data）。
#   ⚠ プロジェクト初のドラッグ実装。⚠ 自前で「押した座標を覚えて動かす」を書かないこと。
# ⚠ 中身は荷物に入れない。⚠ 入れるのは「何番目のマスか」だけ。
#   ⚠ 中身を入れると、⚠ 落ちるまでのあいだに壊された品が荷物の中で生き続ける。
# ⚠ 空のマスからはドラッグを始めない。⚠ 空のマスへ落とすのは許す（＝そこへ動かす）。

func _get_drag_data(_at_position: Vector2) -> Variant:
	if is_empty():
		return null
	# つまんでいるものを指の下に出す。⚠ 出さないと何をつかんだのか分からない。
	var preview: ItemSlot = ItemSlot.create(_entry)
	preview.modulate = DRAG_PREVIEW_MODULATE
	preview.disabled = true
	set_drag_preview(preview)
	return {DRAG_KEY: true, DRAG_INDEX: _index}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	if not (data as Dictionary).has(DRAG_KEY):
		return false
	return int((data as Dictionary).get(DRAG_INDEX, -1)) != _index


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return
	slot_dropped.emit(int((data as Dictionary).get(DRAG_INDEX, -1)))


func is_empty() -> bool:
	return _entry.is_empty()


func _refresh() -> void:
	# ⚠ 作り直しに await を持たせない（AGENTS.md）。remove_child してから queue_free。
	if _icon != null and is_instance_valid(_icon):
		icon_holder.remove_child(_icon)
		_icon.queue_free()
		_icon = null

	if _entry.is_empty():
		count_label.text = ""
		modulate = EMPTY_MODULATE
		tooltip_text = ""
		return

	modulate = Color.WHITE
	var item_id: String = str(_entry.get(GameManager.SLOT_ENTRY_ITEM_ID, ""))
	# ⚠ 等級は装備の個体だけが持つ（item_id からは引けない）。持ち物は 0 のまま。
	var grade: int = int(_entry.get(GameManager.SLOT_ENTRY_GRADE, 0))
	_icon = ItemIcon.create(item_id, grade)
	# ⚠⚠ アイコンにクリックを飲ませない（2026-09-03・人間が実機で見つけた）。
	#   ⚠ ItemIcon は Panel で、⚠ Control の既定の mouse_filter は STOP。
	#     ⚠ そのままだと、⚠ マスの中央（＝アイコンの 40px）を押しても
	#       ⚠ 押下がアイコンで止まり、⚠ 選べない・ドラッグも始まらない
	#       （⚠ 反応するのはマスの縁 4px だけだった）。
	#   ⚠ ItemIcon 側の .tscn を直さないこと。⚠ あちらは倉庫の行・ショップ・レリック選択でも
	#     使っていて、⚠ 「押せる部品」にすると別の画面の当たり判定が変わる。
	#   ⚠ マスの中に入れるときだけ通す。
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.add_child(_icon)

	# 装備中の印。⚠ 誰に着いているかはツールチップ側へ（マスは狭い）。
	var equipped_by: String = str(_entry.get(GameManager.SLOT_ENTRY_EQUIPPED_BY, ""))
	count_label.text = EQUIPPED_MARK if equipped_by != "" else ""

	var name_text: String = tr("ui_res_" + item_id)
	if equipped_by == "":
		tooltip_text = name_text
	else:
		var char_data: Dictionary = MasterDataLoader.get_character(equipped_by)
		tooltip_text = "%s (%s)" % [name_text, tr(str(char_data.get("name_key", equipped_by)))]


func _on_pressed() -> void:
	slot_pressed.emit(get_entry())


func _on_mouse_entered() -> void:
	slot_hovered.emit(get_entry())


func _on_mouse_exited() -> void:
	slot_unhovered.emit()
