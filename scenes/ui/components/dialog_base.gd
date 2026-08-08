class_name DialogBase
extends Control

# ダイアログが閉じられたときに発火するシグナル。
signal dialog_closed

@onready var _backdrop: ColorRect = $Backdrop
@onready var _center: CenterContainer = $CenterContainer
@onready var _content_container: VBoxContainer = $CenterContainer/PanelContainer/ContentContainer


func _ready() -> void:
	# DialogBase 自身・Backdrop・CenterContainer を full rect にする。
	# Control は _ready() 直後だと親の size 確定前の場合があるため、
	# call_deferred で 1 フレーム遅らせてからサイズを整える。
	_apply_full_rect.call_deferred()
	hide()


# サイズを親 Control と同じにする（full rect 化）。
# 親のサイズ変更に追従できるよう、サイズ変更シグナルも受ける。
func _apply_full_rect() -> void:
	var parent_size: Vector2 = size
	if parent_size.x <= 0 or parent_size.y <= 0:
		# 親のサイズが確定していない場合はビューポートサイズを使う
		parent_size = get_viewport_rect().size
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	# 子も full rect に
	_backdrop.anchor_left = 0.0
	_backdrop.anchor_top = 0.0
	_backdrop.anchor_right = 1.0
	_backdrop.anchor_bottom = 1.0
	_backdrop.offset_left = 0.0
	_backdrop.offset_top = 0.0
	_backdrop.offset_right = 0.0
	_backdrop.offset_bottom = 0.0
	_center.anchor_left = 0.0
	_center.anchor_top = 0.0
	_center.anchor_right = 1.0
	_center.anchor_bottom = 1.0
	_center.offset_left = 0.0
	_center.offset_top = 0.0
	_center.offset_right = 0.0
	_center.offset_bottom = 0.0


# 中身の Control を ContentContainer に差し込んで表示する。
# 既存の子ノードは queue_free() で破棄してから追加する。
func open_with_content(content: Control) -> void:
	_apply_full_rect()
	for child: Node in _content_container.get_children():
		child.queue_free()
	_content_container.add_child(content)
	show()


# ダイアログを閉じてシグナルを発火する。
func close() -> void:
	hide()
	dialog_closed.emit()


# Backdrop（ColorRect）の gui_input シグナル受信。
# マウスボタンが押されたら閉じる。
func _on_backdrop_gui_input(event: InputEvent) -> void:
	print("[DialogBase] backdrop gui_input: ", event)
	if event is InputEventMouseButton and event.is_pressed():
		close()


# Escape キー（ui_cancel ビルトインアクション）でも閉じる。
# 背後UIに伝播させないため get_viewport().set_input_as_handled() を呼ぶ。
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
