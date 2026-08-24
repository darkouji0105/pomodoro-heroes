extends Control

@onready var start_button: PrimaryButton = $ButtonContainer/StartButton
@onready var delete_save_button: PrimaryButton = $ButtonContainer/DeleteSaveButton
@onready var title_label: Label = $TitleLabel
@onready var error_label: Label = $ErrorLabel

func _ready() -> void:
	_refresh_ui()
	start_button.pressed.connect(_on_start_pressed)
	delete_save_button.pressed.connect(_on_delete_save_pressed)

# セーブの有無に応じてボタン表示を更新する。
# 警告ラベルもここで隠すため、メッセージを出す処理より先に呼ぶこと。
func _refresh_ui() -> void:
	if SaveManager.has_save():
		start_button.label_key = "ui_title_start_continue"
		delete_save_button.visible = true
	else:
		start_button.label_key = "ui_title_start_new"
		delete_save_button.visible = false
	error_label.visible = false

func _on_start_pressed() -> void:
	# ⚠ 「新規開始か」を決めているのはここ1箇所だけ。2本目を作らないこと。
	var start_new: bool = true
	if SaveManager.has_save():
		if SaveManager.load_game():
			start_new = false
		else:
			# 読み込み失敗。閉じるまで待ってから新規開始として続行する。
			# 以前は2秒待つ実装だったが、読み切る前に消えるおそれがあった。
			# モーダルなら本人が閉じるまで残る。
			start_button.disabled = true
			delete_save_button.disabled = true
			var dlg: ModalDialog = Modal.notify(self, "ui_title_load_failed")
			if dlg != null:
				await dlg.closed

	# ⚠ 状態を作り直す。これが無いと
	#     つづきから → 遊ぶ → タイトルへ戻る → セーブを削除 → 最初から
	#   でメモリ上の状態が残り、⚠ 「セーブを消しても消えない」に見える
	#   （2026-08-24に人間が実機で発見）。
	# ⚠ 起動直後に押したときも通るが、_ready() と同じ処理なので結果は変わらない。
	# ⚠ 版が違って読めなかったときも通す（あの枝は「新規開始として続行する」）。
	if start_new:
		GameManager.reset_to_new_game()

	SceneManager.change_scene("res://scenes/base/base_screen.tscn")

# セーブの削除は取り返しがつかない。必ず確認する。
func _on_delete_save_pressed() -> void:
	var confirmed: bool = await Modal.confirm(self, "ui_title_delete_confirm")
	if not confirmed:
		return

	var ok: bool = SaveManager.delete_save()
	# _refresh_ui() が error_label を隠すため、必ずメッセージ表示より先に呼ぶ
	_refresh_ui()
	if ok:
		Modal.notify(self, "ui_title_delete_done")
	else:
		Modal.notify(self, "ui_title_delete_failed")
