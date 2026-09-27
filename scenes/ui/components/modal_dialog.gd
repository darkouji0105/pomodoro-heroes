class_name ModalDialog
extends CanvasLayer

# モーダルダイアログ本体（PLAN_MODAL.md）。
# 生成と破棄は Modal（scripts/systems/modal.gd）が管理する。
# 呼び出し側がこのクラスを直接 new することは想定していない。

signal closed(result: bool)

# ⚠⚠ 見た目の値は Theme が持つ（`UI-1`）。⚠ ここに数字を書かない。
#   ⚠ 引くのは `Window` 型（⚠ 結果窓と共通）。

# ⚠ 窓の幅の4段階（決定 `MD-3`）。⚠ 呼ぶ側は `Modal.WIDTH_*` を渡す。
const WIDTH_TINY: String = "tiny"
const WIDTH_SMALL: String = "small"
const WIDTH_MEDIUM: String = "medium"
const WIDTH_LARGE: String = "large"

# ⚠ 暗幕の濃さ3通り（決定 `MD-6`）。⚠⚠ `DIM_NONE` でも後ろは押せない（⚠ `Blocker` が受け止める）。
const DIM_NONE: String = "none"
const DIM_NORMAL: String = "normal"
const DIM_HEAVY: String = "heavy"

# ⚠ 本文が何行を超えたら左ぞろえにするか（決定 `MD-9`）。⚠ 1行なら中央のまま。
const MESSAGE_LEFT_ALIGN_LINES: int = 2

@onready var blocker: Control = $Blocker
@onready var dimmer: ColorRect = $Blocker/Dimmer
# 窓の見出し（2026-09-08・段階⑤-③・台帳の決定39「モーダルをウィンドウ形式に」）。
#   ⚠ 見出しを渡さない呼び出しでは出ない（⚠ 帯ごと消える）。
# ⚠⚠ 2026-09-18：⚠ 見出しを**題の帯**にした（人間の決定「全部のモーダルに付ける」）。
#   ⚠ 窓の縁・帯・題の字は戦闘の結果窓と同じ variation（`WindowPanel` / `WindowTitlePanel` /
#   ⚠ `WindowTitleLabel`）。⚠ 仕切り線（`TitleSeparator`）は帯の下辺の線に置き換えたので消した。
@onready var title_bar: PanelContainer = $Blocker/Panel/Window/TitleBar
@onready var title_label: Label = $Blocker/Panel/Window/TitleBar/TitleLabel
# 中身の置き場（⚠ 宝箱の開封結果のマス目など）。⚠ 渡さなければ出ない。
@onready var content_box: VBoxContainer = $Blocker/Panel/Window/Margin/VBox/ContentBox
# ⚠ 本文の中だけスクロールする（決定 `MD-9`）。⚠ 帯とボタンの行は動かない。
@onready var message_scroll: ScrollContainer = $Blocker/Panel/Window/Margin/VBox/MessageScroll
@onready var message_label: Label = $Blocker/Panel/Window/Margin/VBox/MessageScroll/MessageLabel
@onready var panel: PanelContainer = $Blocker/Panel
@onready var confirm_button: Button = $Blocker/Panel/Window/Margin/VBox/Buttons/ConfirmButton
@onready var close_button: Button = $Blocker/Panel/Window/Margin/VBox/Buttons/CloseButton

# ⚠ 確かめの窓の判（⚠ 紙の右上からはみ出す）。⚠ 渡されなければ作らない。
var _stamp: Stamp = null

# ⚠ 長押しの実行（`Modal.OPTION_HOLD`）。⚠ 長さ 0 ＝ふつうのボタン。
var _hold_ms: int = 0
var _hold_elapsed_ms: float = 0.0
var _holding: bool = false
var _hold_fill: ColorRect = null

# 自分がポーズを立てたかどうか。
# これを見ずに解除すると、他のモーダルが立てたポーズを勝手に戻す。
var _pause: bool = false

# closed を発火済みか。_close() と _exit_tree() の二重発火を防ぐ。
var _closed_emitted: bool = false


func _ready() -> void:
	layer = 200

	# 背後の操作を止めるのはここ。Blocker が全画面を覆い、
	# マウス入力を自分で受け止めて奥へ通さない。
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	# 暗幕は入力を拾わない。拾わせると閉じる経路を作りたくなる。
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_dim(DIM_NORMAL)

	# ⚠ 本文がこれより高くなったら中だけスクロールする（決定 `MD-9`）。
	message_scroll.custom_minimum_size.y = 0
	# ⚠⚠ 無名関数でつながないこと（2026-09-21）。⚠ `self` を値として捕まえるので、
	#   ⚠ 畳まれるときに子から通知が飛ぶと `Lambda capture ... was freed` が出る。
	message_label.resized.connect(_on_message_resized)

	confirm_button.pressed.connect(_on_confirm_pressed)
	close_button.pressed.connect(_on_close_pressed)


# message は翻訳済みの文字列を受け取る。ここで tr() は呼ばない。
#
# ⚠ `options` は 2026-09-08 に足した（⚠ 4つ目の引数。⚠ 既存の呼び出しは触っていない）。
#   ⚠ 中身のキーは `Modal.OPTION_*`。⚠ 綴りを呼ぶ側に書かせない。
func setup(message: String, is_confirm: bool, pause: bool, options: Dictionary = {}) -> void:
	message_label.text = message
	# ⚠ 中身だけの窓もある（⚠ 宝箱の開封結果）。⚠ 空の行を残さない。
	message_label.visible = message != ""

	var title: String = str(options.get(Modal.OPTION_TITLE, ""))
	title_label.text = title
	title_bar.visible = title != ""
	# ⚠ 帯の高さは窓の共通の値（`Window` 型）。⚠ ここに数字を書かない。
	title_bar.custom_minimum_size.y = title_bar.get_theme_constant(&"title_height", &"Window")

	var content: Variant = options.get(Modal.OPTION_CONTENT, null)
	if content is Control:
		content_box.add_child(content as Control)
		content_box.visible = true

	# ⚠ 窓の幅は4段階の固定（決定 `MD-3`）。⚠ 渡されなければ小。
	_apply_width(str(options.get(Modal.OPTION_WIDTH, WIDTH_SMALL)))
	# ⚠ 暗幕の濃さ（決定 `MD-6`）。⚠ 渡されなければ今までどおり 60%。
	_apply_dim(str(options.get(Modal.OPTION_DIM, DIM_NORMAL)))

	confirm_button.visible = is_confirm
	if is_confirm:
		_become_paper(title, str(options.get(Modal.OPTION_STAMP, "")))
		confirm_button.label_key = "ui_common_yes"
		close_button.label_key = "ui_common_cancel"
		# ⚠⚠ 取り返しのつかない確認は実行を赤に（決定 `MD-5`）。
		#   ⚠ 文言も呼ぶ側が差し替えられる（⚠ 「はい」より「消す」のほうが結果が読める）。
		if bool(options.get(Modal.OPTION_DANGER, false)):
			confirm_button.variant = UiButton.Variant.DANGER
		var yes_key: String = str(options.get(Modal.OPTION_CONFIRM_LABEL, ""))
		if yes_key != "":
			confirm_button.label_key = yes_key
		var hold_hint: String = str(options.get(Modal.OPTION_HOLD, ""))
		if hold_hint != "":
			_make_hold(hold_hint)
	else:
		# ⚠ 閉じるボタンの文言を差し替えられる（⚠ 宝箱は「受け取る」）。
		close_button.label_key = str(options.get(Modal.OPTION_CLOSE_LABEL, "ui_common_close"))
	if pause:
		_apply_pause()


# --- 確かめの窓は紙（2026-09-27・回UI-4・手本 Confirm）---------------
#
# ⚠ 羊皮紙の面・四隅の角飾り・明朝の題と「線 ◆◇◆ 線」・右上に傾いた判・幅いっぱいの2つのボタン。
# ⚠⚠ 知らせ（`notify`）の窓は暗い窓のまま（⚠ 手本は確かめの窓しか無い。⚠ 中身に暗い地の部品が入る）。
# ⚠ 並びは「はい｜やめる」のまま（決定 `MD-4`。⚠ 手本は逆）。⚠ 開いたときは「やめる」を選んでおく（⚠ 手本の決まり）。
# ⚠ 値は Theme（`ConfirmPaperPanel` ／ `Window` の `confirm_*`）。⚠ ここに数字を書かない。
func _become_paper(title: String, stamp_key: String) -> void:
	panel.theme_type_variation = &"ConfirmPaperPanel"
	# ⚠ 中の字は紙のテーマで墨になる（決定 `UI-14`）。⚠ ボタンは紙のテーマに無いので本体のテーマのまま。
	panel.theme = PaperSheet.PAPER_THEME
	panel.draw.connect(_on_panel_draw)
	title_bar.visible = false
	if title != "":
		var heading: SheetHeading = SheetHeading.new()
		heading.name = "PaperHeading"
		heading.title_text = title
		heading.ornament = true
		heading.ornament_below = true
		var box: VBoxContainer = content_box.get_parent() as VBoxContainer
		box.add_child(heading)
		box.move_child(heading, 0)
	# ⚠ 紙の上で Ghost は字が明るすぎて読めない（`PaperChoice` と同じ理由）。⚠ 「やめる」は既定の革。
	close_button.variant = UiButton.Variant.SECONDARY
	var height: float = float(panel.get_theme_constant(&"confirm_button_height", &"Window"))
	for button: Button in [confirm_button, close_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = height
	close_button.grab_focus.call_deferred()
	if stamp_key != "":
		_stamp = Stamp.new()
		_stamp.name = "PaperStamp"
		_stamp.label_key = stamp_key
		_stamp.filled = true
		# ⚠ 窓の面の子にすると `PanelContainer` が広げてしまう。⚠ 隣に置いて、⚠ 面が動くたびに付け直す。
		blocker.add_child(_stamp)
		panel.item_rect_changed.connect(_place_stamp)
		_stamp.resized.connect(_place_stamp)
		_place_stamp.call_deferred()


# ⚠ 実行を長押しにする（`Modal.OPTION_HOLD`・手本「押しつづけると消える。途中で離せば止まる」）。
#   ⚠ 押している間、ボタンの左から明るい赤が満ちる。⚠ 離すと 0 に戻る。
#   ⚠ キーボードの決定も同じ（⚠ `button_down` / `button_up` はキーでも飛ぶ）。
func _make_hold(hint_key: String) -> void:
	_hold_ms = panel.get_theme_constant(&"confirm_hold_ms", &"Window")
	var hint: Label = Label.new()
	hint.name = "HoldHint"
	hint.theme_type_variation = &"CaptionLabel"
	hint.text = tr(hint_key)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var box: VBoxContainer = content_box.get_parent() as VBoxContainer
	box.add_child(hint)
	box.move_child(hint, confirm_button.get_parent().get_index())
	_hold_fill = ColorRect.new()
	_hold_fill.name = "HoldFill"
	_hold_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hold_fill.color = panel.get_theme_color(&"confirm_hold_fill", &"Window")
	_hold_fill.size = Vector2.ZERO
	confirm_button.add_child(_hold_fill)
	confirm_button.button_down.connect(_on_hold_down)
	confirm_button.button_up.connect(_on_hold_up)


func _on_hold_down() -> void:
	_holding = true
	_hold_elapsed_ms = 0.0


func _on_hold_up() -> void:
	_holding = false
	_hold_elapsed_ms = 0.0
	_update_hold_fill()


func _process(delta: float) -> void:
	if not _holding or _hold_ms <= 0:
		return
	_hold_elapsed_ms += delta * 1000.0
	_update_hold_fill()
	if _hold_elapsed_ms >= float(_hold_ms):
		_holding = false
		_close(true)


func _update_hold_fill() -> void:
	if _hold_fill == null:
		return
	var ratio: float = clampf(_hold_elapsed_ms / float(maxi(_hold_ms, 1)), 0.0, 1.0)
	_hold_fill.position = Vector2.ZERO
	_hold_fill.size = Vector2(confirm_button.size.x * ratio, confirm_button.size.y)


func _on_panel_draw() -> void:
	PaperSheet.draw_corners(panel)


func _place_stamp() -> void:
	if _stamp == null or not is_instance_valid(_stamp):
		return
	var overhang: float = float(panel.get_theme_constant(&"confirm_stamp_overhang", &"Window"))
	var right: float = float(panel.get_theme_constant(&"confirm_stamp_right", &"Window"))
	_stamp.size = _stamp.custom_minimum_size
	_stamp.position = panel.position + Vector2(panel.size.x - right - _stamp.size.x, -overhang)


# --- 器のつまみ（2026-09-21・決定 MD-3 / MD-6 / MD-9）---------------

# ⚠ 窓の幅（決定 `MD-3`）。⚠ 知らない字が来たら小に落とす（⚠ 黙って伸びる形に戻さない）。
func _apply_width(size_name: String) -> void:
	var key: StringName = &"width_small"
	if size_name == WIDTH_TINY:
		key = &"width_tiny"
	elif size_name == WIDTH_MEDIUM:
		key = &"width_medium"
	elif size_name == WIDTH_LARGE:
		key = &"width_large"
	elif size_name != WIDTH_SMALL:
		push_warning("[ModalDialog] 知らない窓の幅: %s（小に落とす）" % size_name)
	var width: float = float(panel.get_theme_constant(key, &"Window"))
	panel.custom_minimum_size.x = width


# ⚠ 暗幕の濃さ（決定 `MD-6`）。⚠⚠ `none` でも後ろは押せない（⚠ 受け止めるのは `Blocker`）。
func _apply_dim(dim_name: String) -> void:
	var key: StringName = &"dim_normal_pct"
	if dim_name == DIM_NONE:
		key = &"dim_none_pct"
	elif dim_name == DIM_HEAVY:
		key = &"dim_heavy_pct"
	elif dim_name != DIM_NORMAL:
		push_warning("[ModalDialog] 知らない暗幕の濃さ: %s（60%% に落とす）" % dim_name)
	var pct: float = float(dimmer.get_theme_constant(key, &"Window"))
	dimmer.color = Color(0, 0, 0, pct / 100.0)


# ⚠ 窓が続けて出るときの間（決定 `MD-8`）。⚠ `Modal` がこれを引く。
#   ⚠ 窓が自分で答えるので、⚠ 画面のルートが `Control` かどうかに左右されない。
func queue_gap_ms() -> int:
	return panel.get_theme_constant(&"queue_gap_ms", &"Window")


# ⚠ 本文が2行以上になったら左ぞろえ、⚠ 高くなりすぎたら中だけスクロール（決定 `MD-9`）。
#   ⚠ 揃え方を変えても大きさは変わらないので、⚠ ここが呼び返されて無限に回ることはない。
func _on_message_resized() -> void:
	var lines: int = message_label.get_line_count()
	if lines >= MESSAGE_LEFT_ALIGN_LINES:
		message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var limit: float = float(message_scroll.get_theme_constant(&"message_max_height", &"Window"))
	message_scroll.custom_minimum_size.y = minf(message_label.get_combined_minimum_size().y, limit)


func _on_confirm_pressed() -> void:
	# ⚠ 長押しの窓は押しただけでは決まらない（⚠ 決めるのは `_process()`）。
	if _hold_ms > 0:
		return
	_close(true)


func _on_close_pressed() -> void:
	_close(false)


# 暗幕のクリックでは閉じない。
# gui_input を接続していないので、閉じる経路がそもそも存在しない。
# 確認ダイアログで誤って閉じると、意図しない結果になるため。
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode != KEY_ESCAPE:
		return
	get_viewport().set_input_as_handled()
	_close(false)


func _close(result: bool) -> void:
	emit_closed_once(result)
	_release_pause()
	queue_free()


# closed を1回だけ発火する。
# _close() と _exit_tree() の両方から呼ばれるため、フラグで守る。
func emit_closed_once(result: bool) -> void:
	if _closed_emitted:
		return
	_closed_emitted = true
	closed.emit(result)


# 画面遷移などでツリーから外れたときも必ず通る。
#
# ここで closed を発火しないと、confirm() を await している側が
# 永久に戻らない。Blocker が防げるのはマウス操作だけで、
# コードからの change_scene は止められない。
#
# ポーズも必ず戻す。戻し損ねるとゲームが二度と動かなくなる。
func _exit_tree() -> void:
	emit_closed_once(false)
	_release_pause()


func _apply_pause() -> void:
	if _pause:
		return
	_pause = true
	get_tree().paused = true
	# 止めた側が止まると閉じられなくなる
	process_mode = Node.PROCESS_MODE_ALWAYS


# 自分が立てたポーズだけ戻す。
# pause を指定していないモーダルは、ここで paused に一切触らない。
func _release_pause() -> void:
	if not _pause:
		return
	_pause = false
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.paused = false
