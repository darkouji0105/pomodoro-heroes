class_name ScreenHeader
extends HBoxContainer

# 画面の見出し（2026-09-09・人間の指示「基本的なコンポーネントの見直し・追加」）。
#
# ⚠⚠ **20画面が手組みしていた**。⚠ しかも置き場所がバラバラで、
#   ⚠ **戻るが「上」の画面と「下」の画面が混ざっていた**（⚠ 倉庫は上・ギルド各画面は下）。
#   ⚠ 人間のモック（倉庫）に合わせて **上（見出しの右）に統一**する。
#
# ⚠⚠ 2026-09-11（人間のモック「ギルド／育成」）：⚠ **並びを「左に戻る ／ 題 ／ 副題」に変えた**。
#   ⚠ 前は「左に題 ／ 右に戻る」。⚠ モックは4枚とも**戻るが左端**で、⚠ その右に
#   ⚠ 「いま何の画面か（題）」と「⚠ 何を相手にしているか（副題）」が並ぶ。
#   ⚠ 戻るの文言は行き先の名前にする（⚠ 「ギルド」「一覧へ」「剣士」）＝⚠ `back_label_key`。
#   ⚠ 「戻るは画面の上」の決定は変えていない。⚠ 左右が変わっただけ。
#
# ⚠ 中身は「⚠ 左に戻る ／ ⚠ 題 ／ ⚠ 副題」。⚠ 戻るは **Ghost**（⚠ 階層の決まり：戻る・閉じるは Ghost）。
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

# 副題の翻訳キー。⚠ 空なら出さない（⚠ 場所も取らない）。
# ⚠ 翻訳を通さない文字（⚠ キャラの名前など）は `subtitle_text` に直接入れる。
@export var subtitle_key: String = "":
	set(value):
		subtitle_key = value
		if is_inside_tree():
			_refresh()

@onready var title_label: Label = $TitleLabel
@onready var subtitle_label: Label = $SubtitleLabel
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
	# ⚠⚠ キーが空のときは触らない（2026-09-14）。⚠ `UiButton` の setter が
	#   ⚠ `text = tr("")` ＝**空文字**を入れ、⚠ **戻るが潰れて見える**
	#   ⚠ （⚠ 人間が実機で発見：ステータスノードとスキル）。
	# ⚠ 2026-09-22（宿題79）：⚠ キーを空にしていた `set_back_text()` を消した
	#   （⚠ 呼び出しが0件。⚠ 「⚠ 戻るという文字にしてほしい、⚠ キャラの名前ではなく」で用が無くなった）。
	#   ⚠ この守り自体は残す（⚠ `.tscn` で空にされても潰れないように）。
	if back_label_key != "":
		back_button.label_key = back_label_key
	back_button.visible = show_back
	# ⚠ 副題はキーが空なら丸ごと消す。⚠ 空文字の Label を残すと間隔だけが空く。
	if subtitle_key != "":
		subtitle_label.text = tr(subtitle_key)
	subtitle_label.visible = subtitle_label.text != ""


# 翻訳を通さない副題（⚠ キャラの名前・ステージの名前）。
# ⚠ `subtitle_key` と両方入れないこと。⚠ あとから入れたほうが残る。
func set_subtitle_text(value: String) -> void:
	subtitle_key = ""
	if not is_inside_tree():
		await ready
	subtitle_label.text = value
	subtitle_label.visible = value != ""


# ⚠ ヘッダーの下の線。⚠ 色は Theme が持つ（⚠ ここに色を書かない）。
#   ⚠ `HBoxContainer` は面を持てないので、⚠ 線だけ自分で描く
#   （⚠ `TimerRing` / `SetDots` と同じ形）。
func _draw() -> void:
	var color: Color = get_theme_color(&"rule", &"ScreenHeader")
	draw_line(Vector2(0.0, size.y), Vector2(size.x, size.y), color, 1.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
