class_name ModalDialog
extends CanvasLayer

# モーダルダイアログ本体（PLAN_MODAL.md）。
# 生成と破棄は Modal（scripts/systems/modal.gd）が管理する。
# 呼び出し側がこのクラスを直接 new することは想定していない。

signal closed(result: bool)

const DIMMER_COLOR: Color = Color(0, 0, 0, 0.6)

@onready var blocker: Control = $Blocker
@onready var dimmer: ColorRect = $Blocker/Dimmer
# 窓の見出し（2026-09-08・段階⑤-③・台帳の決定39「モーダルをウィンドウ形式に」）。
#   ⚠ 見出しを渡さない呼び出しでは出ない（⚠ 今までの見た目のまま）。
@onready var title_bar: HBoxContainer = $Blocker/Panel/Margin/VBox/TitleBar
@onready var title_label: Label = $Blocker/Panel/Margin/VBox/TitleBar/TitleLabel
@onready var title_separator: HSeparator = $Blocker/Panel/Margin/VBox/TitleSeparator
# 中身の置き場（⚠ 宝箱の開封結果のマス目など）。⚠ 渡さなければ出ない。
@onready var content_box: VBoxContainer = $Blocker/Panel/Margin/VBox/ContentBox
@onready var message_label: Label = $Blocker/Panel/Margin/VBox/MessageLabel
@onready var confirm_button: Button = $Blocker/Panel/Margin/VBox/Buttons/ConfirmButton
@onready var close_button: Button = $Blocker/Panel/Margin/VBox/Buttons/CloseButton

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
	dimmer.color = DIMMER_COLOR

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
	title_separator.visible = title != ""

	var content: Variant = options.get(Modal.OPTION_CONTENT, null)
	if content is Control:
		content_box.add_child(content as Control)
		content_box.visible = true

	confirm_button.visible = is_confirm
	if is_confirm:
		confirm_button.label_key = "ui_common_yes"
		close_button.label_key = "ui_common_no"
	else:
		# ⚠ 閉じるボタンの文言を差し替えられる（⚠ 宝箱は「受け取る」）。
		close_button.label_key = str(options.get(Modal.OPTION_CLOSE_LABEL, "ui_common_close"))
	if pause:
		_apply_pause()


func _on_confirm_pressed() -> void:
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
