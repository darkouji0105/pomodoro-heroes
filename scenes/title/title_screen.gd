extends Control

# 警告を読む時間を確保するための待機秒数
const WARNING_DISPLAY_SEC: float = 2.0

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
	if SaveManager.has_save():
		var ok: bool = SaveManager.load_game()
		if not ok:
			# 読み込み失敗。警告を出してから新規開始として続行する。
			# 遷移を待たずに change_scene すると警告が1フレームも表示されないため、
			# 読む時間を確保してから遷移する。
			_show_message(tr("ui_title_load_failed"))
			start_button.disabled = true
			delete_save_button.disabled = true
			await get_tree().create_timer(WARNING_DISPLAY_SEC).timeout
	SceneManager.change_scene("res://scenes/base/base_screen.tscn")

func _on_delete_save_pressed() -> void:
	var ok: bool = SaveManager.delete_save()
	# _refresh_ui() が error_label を隠すため、必ずメッセージ表示より先に呼ぶ
	_refresh_ui()
	if ok:
		_show_message(tr("ui_title_delete_done"))
	else:
		_show_message(tr("ui_title_delete_failed"))

func _show_message(message: String) -> void:
	error_label.text = message
	error_label.visible = true
