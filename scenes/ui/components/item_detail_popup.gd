class_name ItemDetailPopup
extends CanvasLayer

# マスにマウスを乗せると、その右側に詳細を出すドロップダウン（2026-09-07・人間の指示）。
#
# ⚠ 人間の言葉：「⚠ ホバーするだけでマウスの右側に詳細モーダルを表示」
#   「⚠ モーダルというよりドロップダウンだった」「⚠ 左上にアイコンを」。
#   ⚠ アイコンは最初 右上に置いた。⚠ 2026-09-07 の2回目に人間の指示で左上へ移した。
#
# ⚠⚠ **モーダルではない。** ⚠ 暗幕も入力の受け止めも持たない（⚠ 最初はモーダルとして
#   作ったが、⚠ 人間の裁きで作り替えた）。⚠ ホバーで出るものが背後の操作を止めると、
#   ⚠ マスの上を通るだけでボタンが押せなくなる。⚠ 全部 MOUSE_FILTER_IGNORE。
# ⚠⚠ **操作ボタンを中に入れない。** ⚠ ホバーを外すと消えるので、⚠ 中のボタンは
#   押しに行く途中で消える。⚠ 操作ボタンは画面の `ActionRow` に置いたままにする。
#
# ⚠ この部品は `ItemDetail` を1つ引き取るだけ。⚠ 画面が .tscn に持っているものを
#   実行時に親替えする（⚠ 画面の `@onready var item_detail` はそのまま生きる）。
# ⚠⚠ 2026-09-08：⚠ 自前のアイコンをやめた。⚠ `ItemDetail` の見出しがアイコンを持つ
#   （⚠ 段階③）。⚠ 両方が出すと、⚠ ホバーの枠にアイコンが2つ並ぶ。
#
# ⚠ `Modal`（`scripts/systems/modal.gd`）とは別物で、⚠ あちらは触っていない。
# ⚠ 2画面以上で使うので scenes/ui/components/（AGENTS.md）。⚠ `.tscn` を持たない。

# ⚠ `ModalDialog` は 200。⚠ こちらを下にして、⚠ 確認モーダルが必ず上に出るようにする。
const LAYER_INDEX: int = 190
# マウスと枠のすきま。⚠ 0 にすると枠がカーソルの下に入る。
const CURSOR_OFFSET_PX: float = 16.0
# 画面の端との余白。
const MARGIN_PX: float = 8.0
# 枠の最小の幅。⚠ 説明文が1行だけの品でも細くなりすぎないように。
const MIN_WIDTH_PX: float = 220.0

var _root: Control = null
var _panel: PanelContainer = null
var _detail_box: VBoxContainer = null
var _detail: ItemDetail = null


# 画面から `ItemDetail` を引き取って器を作る。
#
# ⚠ `host` は画面のルート。⚠ ここに add_child するので、⚠ 画面遷移で一緒に消える。
static func adopt(host: Node, detail: ItemDetail) -> ItemDetailPopup:
	if host == null or detail == null:
		push_error("[ItemDetailPopup] host か detail が null。引き取れない")
		return null
	var popup: ItemDetailPopup = ItemDetailPopup.new()
	popup.name = "ItemDetailPopup"
	host.add_child(popup)
	popup._take(detail)
	return popup


func _init() -> void:
	layer = LAYER_INDEX
	visible = false

	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# ⚠⚠ 全部マウスを通す。⚠ 止めると、⚠ 乗せているマスから外れたことに
	#   気づけなくなり（⚠ 器が指の下に入る）、⚠ 出たまま固まる。
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	# ⚠ アンカーは左上に固定する。⚠ 位置と大きさは open_at_mouse() がコードで当てる。
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, int(MARGIN_PX))
	_panel.add_child(margin)

	# ⚠ 左上のアイコンは `ItemDetail` の見出しが出す（2026-09-08・段階③）。
	#   ⚠ ここは文章の器だけを持つ。
	_detail_box = VBoxContainer.new()
	_detail_box.name = "DetailBox"
	_detail_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(_detail_box)


func _take(detail: ItemDetail) -> void:
	_detail = detail
	# ⚠⚠ ホバーの枠は **要約**（2026-09-08・段階④・モック3枚目）。
	#   ⚠ 分解の戻り・鍛えるコストは出さない（⚠ 押すボタンが隣に無い＝読んでも何もできない）。
	#   ⚠ フルの中身は常設のパネル側（⚠ 段階⑤）が出す。
	detail.set_summary(true)
	var parent: Node = detail.get_parent()
	if parent != null:
		parent.remove_child(detail)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_box.add_child(detail)


# マス目を1つ見張る。⚠ 画面はこれを呼ぶだけでよい（⚠ 出す口を画面ごとに書かない）。
#
# ⚠ マス目が複数ある画面（宝箱）は、⚠ そのぶん呼ぶ。
func watch(grid: ItemGrid) -> void:
	if grid == null:
		return
	grid.slot_hovered.connect(_on_slot_hovered)
	grid.slot_unhovered.connect(_on_slot_unhovered)


func is_open() -> bool:
	return visible


# 中身を差し替えてマウスの右側に出す。⚠ 空のマスでは出さない。
func show_entry(entry: Dictionary) -> void:
	if _detail == null:
		return
	if entry.is_empty() or str(entry.get(GameManager.SLOT_ENTRY_ITEM_ID, "")) == "":
		close()
		return
	_detail.show_entry(entry)
	# ⚠⚠ 中身を作り直すたびに、⚠ 新しい子まで含めて全部マウスを通す。
	#   ⚠ `PartSlotIcon` は `Panel`＝既定でマウスを止める（⚠ ツールチップを出すため）。
	#   ⚠ 止めたままだと、⚠ 器が指の下に入ったときに「⚠ マスから外れた」ことに
	#   ⚠ 気づけず、⚠ 枠が出たまま固まる（⚠ この器の一番上のコメントの通り）。
	# ⚠ 常設のパネル（段階⑤）では止めたままにする＝⚠ あちらではツールチップが要る。
	_pass_mouse_through(_detail)
	_open_at_mouse()


# 自分と子孫を全部 MOUSE_FILTER_IGNORE にする。
func _pass_mouse_through(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_pass_mouse_through(child)


# マウスの右側に置く。⚠ 右がはみ出すならマウスの左へ返す。
#
# ⚠ 大きさは get_combined_minimum_size() で取る。⚠ レイアウトが済む前でも取れる
#   （⚠ `scenario=layout` が同じ口で測っている）。⚠ ここで await しない。
func _open_at_mouse() -> void:
	visible = true
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var mouse: Vector2 = _root.get_global_mouse_position()

	var wanted: Vector2 = _panel.get_combined_minimum_size()
	wanted.x = maxf(wanted.x, MIN_WIDTH_PX)
	_panel.size = wanted

	var pos: Vector2 = Vector2(mouse.x + CURSOR_OFFSET_PX, mouse.y)
	if pos.x + wanted.x > screen.x:
		pos.x = mouse.x - CURSOR_OFFSET_PX - wanted.x
	# ⚠ 画面からはみ出したぶんを押し戻す。⚠ 枠が画面より大きいときは左上に寄せる。
	pos.x = clampf(pos.x, MARGIN_PX, maxf(MARGIN_PX, screen.x - wanted.x - MARGIN_PX))
	pos.y = clampf(pos.y, MARGIN_PX, maxf(MARGIN_PX, screen.y - wanted.y - MARGIN_PX))
	_panel.position = pos


func close() -> void:
	visible = false


func _on_slot_hovered(entry: Dictionary, _index: int) -> void:
	show_entry(entry)


func _on_slot_unhovered(_index: int) -> void:
	close()
