extends Control

# モーダルの検証用シーン（res://tests/ 配下・本番には出ない）。
#
# 【方針】判定はしない。人間が押して、目で見て確かめる。
# 「クリックしても反応しないこと」「表示が変わること」は
# 自動判定に向かない。前回そこを自動化しようとして時間を溶かした。
#
# ボタンはコードで並べる。.tscn には
# 親の VBoxContainer が1つあればよい。

@onready var list: VBoxContainer = $VBox

var _log_label: Label = null


func _ready() -> void:
	_add_button("1. 通知（閉じるまで残る）", _t_notify)
	_add_button("2. 通知（数値入り／宝箱3個）", _t_notify_number)
	_add_button("3. 通知を2連続（キューの確認）", _t_notify_twice)
	_add_button("4. 確認（はい／いいえ）", _t_confirm)
	_add_button("5. セーブ失敗の表示確認", _t_save_failed)
	_add_button("6. ポーズありの通知", _t_notify_paused)
	_add_button("7. 通知を出したまま拠点へ遷移", _t_notify_then_change)
	_add_button("8. ポーズありの通知を出したまま拠点へ遷移", _t_paused_then_change)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	list.add_child(spacer)

	_log_label = Label.new()
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(_log_label)
	_log("押したボタンの結果がここに出ます")


func _add_button(text: String, handler: Callable) -> void:
	var b: Button = Button.new()
	b.text = text
	b.pressed.connect(handler)
	list.add_child(b)


func _log(text: String) -> void:
	print("[ModalTest] " + text)
	if _log_label != null:
		_log_label.text = text


# --- 各テスト ---

# 期待：モーダルが出る。暗幕をクリックしても閉じない。
# 「閉じる」または Escape で閉じる。閉じたあと背後のボタンが押せる。
func _t_notify() -> void:
	Modal.notify(self, "ui_common_ok")
	_log("通知を出した。暗幕クリックで閉じないこと、Escape で閉じることを確認")


# 期待：「宝箱を3個受け取りました」と出る。%d のままでないこと。
func _t_notify_number() -> void:
	Modal.notify(self, "ui_base_chest_received", [3])
	_log("数値入りの通知を出した")


# 期待：1つ目を閉じると2つ目が出る。同時に重ならない。
# 2つ目が1つ目に上書きされて消えない。
func _t_notify_twice() -> void:
	Modal.notify(self, "ui_common_ok")
	Modal.notify(self, "ui_base_chest_received", [3])
	_log("2連続で出した。1つ目を閉じると2つ目（宝箱）が出るはず")


# 期待：「はい」「いいえ」の2つが出る。
# はい→true、いいえ→false、Escape→false がここに出る。
func _t_confirm() -> void:
	var r: bool = await Modal.confirm(self, "ui_title_back_confirm")
	_log("確認の結果： " + str(r))


func _t_save_failed() -> void:
	Modal.notify(self, "ui_base_save_failed")
	_log("セーブ失敗の文言を表示した")


# 期待：出ている間、背後のこのボタンが押せない。
# 閉じるとまた押せるようになる。
func _t_notify_paused() -> void:
	Modal.notify(self, "ui_base_save_failed", [], true)
	_log("ポーズありで出した。閉じたあとボタンが押せることを確認")


# 期待：拠点に移ったとき、モーダルが残っていないこと。
func _t_notify_then_change() -> void:
	Modal.notify(self, "ui_common_ok")
	_log("通知を出したまま拠点へ移る")
	await get_tree().create_timer(1.0).timeout
	SceneManager.change_scene("res://scenes/base/base_screen.tscn")


# 期待：拠点に移ったあと、拠点のボタンが普通に押せること。
# 押せなければポーズが戻っていない。
func _t_paused_then_change() -> void:
	Modal.notify(self, "ui_base_save_failed", [], true)
	_log("ポーズありで出したまま拠点へ移る。拠点のボタンが押せるか確認")
	await get_tree().create_timer(1.0).timeout
	SceneManager.change_scene("res://scenes/base/base_screen.tscn")
