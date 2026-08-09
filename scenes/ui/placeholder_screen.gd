# res://scenes/ui/placeholder_screen.gd
# まだ実装していない画面の共通の受け皿（仮）

extends Control

@onready var title_label: Label = $Layout/TitleLabel
@onready var back_button: Button = $Layout/BackButton

func _ready() -> void:
	# 渡されたデータを取得
	var data: Dictionary = SceneManager.consume_transfer_data()
	var screen_id: String = data.get(TransferKeys.SCREEN_ID, "")
	
	# タイトル文言の組み立て
	if screen_id != "":
		title_label.text = tr("ui_nav_" + screen_id) + tr("ui_placeholder_suffix")
	else:
		title_label.text = tr("ui_placeholder_suffix")
	
	# ボタンの接続
	back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	# 拠点へ戻る。履歴管理に頼らず明示的にパスを指定
	SceneManager.change_scene("res://scenes/base/base_screen.tscn")
