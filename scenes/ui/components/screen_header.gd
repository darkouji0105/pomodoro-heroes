class_name ScreenHeader
extends HBoxContainer

# 画面の見出し（2026-09-09・人間の指示「基本的なコンポーネントの見直し・追加」）。
#
# ⚠⚠ **20画面が手組みしていた**。⚠ しかも置き場所がバラバラで、
#   ⚠ **戻るが「上」の画面と「下」の画面が混ざっていた**（⚠ 倉庫は上・ギルド各画面は下）。
#   ⚠ 人間のモック（倉庫）に合わせて **上（見出しの右）に統一**する。
#
# ⚠ 中身は「⚠ 左に題 ／ ⚠ 右に戻る」。⚠ 戻るは **Ghost**（⚠ 階層の決まり：戻る・閉じるは Ghost）。
# ⚠ 押されたことは `back_pressed` で伝える。⚠ 画面はボタンを直接掴まない
#   （⚠ 掴ませると、⚠ ここの作りを変えるたびに画面ぜんぶを直すことになる）。
# ⚠ 文字は翻訳キーで受け取る（⚠ ここで日本語を書かない）。
# ⚠ 2画面以上で使うので scenes/ui/components/（AGENTS.md）。

signal back_pressed

const SCENE_PATH: String = "res://scenes/ui/components/screen_header.tscn"

# 題の翻訳キー。
@export var title_key: String = "":
	set(value):
		title_key = value
		if is_inside_tree():
			_refresh()

# 戻るボタンの翻訳キー。⚠ 「拠点へ戻る」など画面ごとに変わる。
@export var back_label_key: String = "ui_common_back":
	set(value):
		back_label_key = value
		if is_inside_tree():
			_refresh()

# 戻るボタンを出すか。⚠ 出口が別に在る画面（⚠ タイトル）では消せる。
@export var show_back: bool = true:
	set(value):
		show_back = value
		if is_inside_tree():
			_refresh()

# 資源（金・ジェム・スタミナ）を右に出すか（2026-09-09・人間の指示「資源は、右上に表示する」）。
# ⚠ 右上には既に「戻る」が居るので、⚠ **見出しの行に同居させる**
#   （⚠ 別の行にすると縦を 40〜50px 食う。⚠ 倉庫686・冒険704 と縦が詰まっている）。
# ⚠ 並びは「左に題 ／ 右に資源 ＋ 戻る」。
@export var show_resources: bool = true:
	set(value):
		show_resources = value
		if resource_bar != null:
			resource_bar.visible = show_resources

@onready var title_label: Label = $TitleLabel
@onready var back_button: UiButton = $BackButton

# ⚠ コードで作って `BackButton` の前に差す。⚠ こうするとヘッダーを使う8画面は
#   ⚠ **シーンを1つも触らずに**資源が出る。
var resource_bar: ResourceBar = null


func _ready() -> void:
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	_build_resource_bar()
	_refresh()


func _build_resource_bar() -> void:
	resource_bar = ResourceBar.new()
	resource_bar.name = "ResourceBar"
	add_child(resource_bar)
	move_child(resource_bar, back_button.get_index())
	resource_bar.visible = show_resources


func _refresh() -> void:
	title_label.text = tr(title_key)
	back_button.label_key = back_label_key
	back_button.visible = show_back
