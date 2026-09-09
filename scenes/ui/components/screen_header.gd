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

@onready var title_label: Label = $TitleLabel
@onready var back_button: UiButton = $BackButton

# ⚠⚠ 資源は `ResourceHud` が画面をまたいで右上に常駐で出す（2026-09-09）。
#   ⚠ **ヘッダーは資源を持たない**（⚠ 一時期ここが持っていたが、⚠ 遷移のたびに
#   ⚠ 作り直しになるので常駐へ移した）。
# ⚠ 代わりに、⚠ HUD と「戻る」が重ならないよう**右に場所を空ける**
#   （人間の指示「⚠ 戻るボタンは適時調整する。⚠ 重なるなら少しずらして」）。
#   ⚠ 空ける幅は HUD が自分で答える。⚠ ここで数値を決めない。
var hud_spacer: Control = null


func _ready() -> void:
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	_build_hud_spacer()
	_refresh()


func _build_hud_spacer() -> void:
	hud_spacer = Control.new()
	hud_spacer.name = "HudSpacer"
	hud_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud_spacer)
	_apply_hud_width(ResourceHud.reserved_width())

	# ⚠ 桁が増えると HUD が広がる。⚠ そのたびに空ける幅を取り直す。
	var hud: ResourceHud = ResourceHud.get_instance()
	if hud != null:
		hud.width_changed.connect(_apply_hud_width)


func _apply_hud_width(width: float) -> void:
	if hud_spacer == null:
		return
	hud_spacer.custom_minimum_size = Vector2(maxf(0.0, width), 0.0)


func _refresh() -> void:
	title_label.text = tr(title_key)
	back_button.label_key = back_label_key
	back_button.visible = show_back
