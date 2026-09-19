class_name SlotActionPopover
extends PanelContainer

# 押したマスの近くに出す「詳細＋できること」の吹き出し（2026-09-19・難ダンジョンのモック v2 `.pop`）。
#
# ⚠ 使う画面：難ダンジョンのマップの鞄 ／ 拾いものの窓 ／ ボスの間の商人（⚠ 2画面以上＝components）。
# ⚠ ホバーの詳細（`ItemDetailPopup`）とは別物。⚠ あちらはマウスを素通しするのでボタンを載せられない。
# ⚠ この部品は GameManager を知らない。⚠ 何を押せるか・押せないかは画面が決めて渡す。
# ⚠ ボタンを押したら、⚠ 渡された処理を呼んでから自分を閉じる（⚠ 画面は描き直すだけでよい）。
# ⚠ 見た目は Theme の `SlotPopoverPanel`（⚠ 値をここに書かない）。

# 吹き出しの幅（モック `.pop` の 236px）。⚠ 高さは中身で決まる。
const WIDTH: float = 236.0
# マスとの隙間。
const GAP: float = 6.0
# 画面の端から離す幅。
const EDGE_MARGIN: float = 8.0

var _body: VBoxContainer = null
var _buttons: HFlowContainer = null
var _anchor: Rect2 = Rect2()


# 開く。⚠ host の下に1枚だけ置く（⚠ 前のものは閉じる）。⚠ anchor はマスの画面上の矩形。
static func open(host: Control, anchor: Rect2, title: String, body: String) -> SlotActionPopover:
	close_in(host)
	var pop: SlotActionPopover = SlotActionPopover.new()
	pop.name = "SlotActionPopover"
	pop._anchor = anchor
	pop._build(title, body)
	host.add_child(pop)
	return pop


# host の下にある吹き出しを閉じる。⚠ remove_child() してから queue_free()（AGENTS.md）。
static func close_in(host: Node) -> void:
	for child: Node in host.get_children():
		if child is SlotActionPopover:
			host.remove_child(child)
			child.queue_free()


func _build(title: String, body: String) -> void:
	theme_type_variation = &"SlotPopoverPanel"
	# ⚠ 親の並べ方に巻き込まれない（⚠ VBox の中に置いても画面の座標で出る）。
	top_level = true
	custom_minimum_size = Vector2(WIDTH, 0.0)
	_body = VBoxContainer.new()
	_body.theme_type_variation = &"TightList"
	add_child(_body)
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = title
	_body.add_child(name_label)
	if body != "":
		var desc: Label = Label.new()
		desc.name = "BodyLabel"
		desc.theme_type_variation = &"MutedLabel"
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.text = body
		_body.add_child(desc)
	_buttons = HFlowContainer.new()
	_buttons.name = "Actions"
	_body.add_child(_buttons)


# ボタンを足す。⚠ 押せないものは disabled で出す（⚠ 押してから弾かない＝ショップと同じ流儀）。
func add_action(text: String, variant: UiButton.Variant, handler: Callable, disabled: bool = false) -> UiButton:
	var button: UiButton = UiButton.new()
	button.variant = variant
	button.text = text
	button.disabled = disabled
	button.pressed.connect(func() -> void:
		var host: Node = get_parent()
		if host != null:
			SlotActionPopover.close_in(host)
		handler.call()
	)
	_buttons.add_child(button)
	return button


# ボタンの下の小さな注記（「誰に使うか選ぶ」など）。⚠ 色を付けたいボタンは呼ぶ側が variant で決める。
func set_note(text: String) -> void:
	var note: Label = Label.new()
	note.name = "NoteLabel"
	note.theme_type_variation = &"CaptionLabel"
	note.text = text
	_body.add_child(note)


func _ready() -> void:
	_place.call_deferred()


# マスの上に出す。⚠ 上に入らなければ下。⚠ 画面の端からはみ出さない。
func _place() -> void:
	if not is_inside_tree():
		return
	var view: Rect2 = get_viewport_rect()
	var box: Vector2 = get_combined_minimum_size()
	size = box
	var x: float = clampf(_anchor.position.x - 20.0, EDGE_MARGIN, view.size.x - box.x - EDGE_MARGIN)
	var y: float = _anchor.position.y - box.y - GAP
	if y < EDGE_MARGIN:
		y = _anchor.end.y + GAP
	global_position = Vector2(x, clampf(y, EDGE_MARGIN, view.size.y - box.y - EDGE_MARGIN))
