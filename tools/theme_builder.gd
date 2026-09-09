@tool
class_name ThemeBuilder
extends RefCounted

# main_theme.tres を組み立て直す本体（2026-09-07・ボタンの4階層）。
#
# ⚠ 使い方は2通り。どちらも同じ `build()` を通る。
#   1. Godot エディタ → `tools/build_theme.gd` を開く → 「実行」
#   2. ヘッドレス：`res://tests/debug_boot.tscn -- scenario=theme`
#
# ⚠⚠ なぜ EditorScript と分けているか：⚠ `EditorScript` は
#   「エディタでしか new できない」（⚠ 実測：`Class 'EditorScript' can only be
#   instantiated by editor.`）。⚠ 素のクラスに分けないと、⚠ ヘッドレスから
#   組み立て直せない＝⚠ 設計役が `.tres` の中身を確かめられなくなる。
#   ⚠ 値（色・寸法）を持つのはこのファイルだけ。⚠ 2箇所に分裂させない。
#
# ⚠ 見た目の値（色・角丸・余白・文字の大きさ）を持ってよいのは、このファイルと
#   `main_theme.tres` だけ。⚠ シーンにも `ui_button.gd` にも色を書かない（AGENTS.md）。
# ⚠ `.tres` を手で書き換えないこと。⚠ ここを直して回し直す。
#
# ⚠ 既存の `.tres` は「読み込んでから足す」。⚠ 新規作成で上書きすると
#   `default_font`（NotoSansJP）の割り当てが消える。

const THEME_PATH: String = "res://theme/main_theme.tres"

# --- ボタンの共通の寸法 ---

const BUTTON_CORNER_RADIUS: int = 8
const BUTTON_PAD_H: float = 20.0
const BUTTON_PAD_V: float = 8.0
const BUTTON_FONT_SIZE: int = 14
const FOCUS_BORDER_WIDTH: int = 2

# --- ボタンの4階層 ---
#
# ⚠ 「Button」は基底＝Secondary（並列の選択肢）。⚠ `SecondaryButton` という
#   variation は作らない。⚠ こうすると素の `Button.new()`（15箇所）も同じ見た目になり、
#   差し替え漏れが静かな側に倒れる（人間の決定・2026-09-07）。
# ⚠ 赤は「危険・不可逆」に予約する。⚠ ギルド側の主色は真鍮。
# ⚠ 色は16進の文字列で持つ（Inspector で拾った値と見比べられるようにするため）。
#   `bg` が "" のときは完全な透明。`border` が "" のときは枠なし。
const BUTTON_LEVELS: Dictionary = {
	# 既定。並列の選択肢。
	"Button": {
		"normal": {"bg": "241d1a", "border": "4a3d36", "width": 1},
		"hover": {"bg": "2e2521", "border": "6b5a4e", "width": 1},
		"pressed": {"bg": "1c1715", "border": "4a3d36", "width": 1},
		"disabled": {"bg": "1e1917", "border": "2a2320", "width": 1},
		"focus": {"bg": "", "border": "f0c04a", "width": FOCUS_BORDER_WIDTH},
		"font_color": "e0d5ce",
		"font_hover_color": "f0e6df",
		"font_pressed_color": "e0d5ce",
		"font_disabled_color": "5a4f49",
	},
	# 真鍮。ギルド側の主要動作。⚠ 1画面に1個まで。
	"PrimaryButton": {
		"normal": {"bg": "a8791f", "border": "", "width": 0},
		"hover": {"bg": "c9922e", "border": "", "width": 0},
		"pressed": {"bg": "8a6114", "border": "", "width": 0},
		"disabled": {"bg": "1e1917", "border": "2a2320", "width": 1},
		"focus": {"bg": "", "border": "f0c04a", "width": FOCUS_BORDER_WIDTH},
		"font_color": "1a1206",
		"font_hover_color": "1a1206",
		"font_pressed_color": "1a1206",
		"font_disabled_color": "5a4f49",
	},
	# 戻る・閉じる。⚠ 地は透明のまま。⚠ 枠だけ持たせる（2026-09-08・人間の指示
	#   「⚠ 拠点のセーブするボタン、倉庫の戻るボタンなどの周りに枠を付けてほしい」）。
	#   ⚠ 枠が無いと「ただの文字」に見えて、押せるものだと分からなかった。
	# ⚠ 枠の色は Secondary と同じ段（⚠ 地の有無だけが違う＝並べたときに揃う）。
	# ⚠ 無効時は枠も文字も一段暗い（⚠ 地が無いぶん、手がかりが枠と文字の2つになった）。
	"GhostButton": {
		"normal": {"bg": "", "border": "4a3d36", "width": 1},
		"hover": {"bg": "241d1a", "border": "6b5a4e", "width": 1},
		"pressed": {"bg": "1c1715", "border": "4a3d36", "width": 1},
		"disabled": {"bg": "", "border": "2a2320", "width": 1},
		"focus": {"bg": "", "border": "f0c04a", "width": FOCUS_BORDER_WIDTH},
		"font_color": "a89b94",
		"font_hover_color": "f0e6df",
		"font_pressed_color": "e0d5ce",
		"font_disabled_color": "3f3835",
	},
	# 冒険側。潜る・撤退など。⚠ 割り当ては未定（画面が決まっていない）。
	#   ⚠ 前の赤 #c44539 とは別の値。⚠ 流用しないこと（人間の指示・2026-09-07）。
	"DangerButton": {
		"normal": {"bg": "a8352f", "border": "", "width": 0},
		"hover": {"bg": "c4433c", "border": "", "width": 0},
		"pressed": {"bg": "8a2a25", "border": "", "width": 0},
		"disabled": {"bg": "1e1917", "border": "2a2320", "width": 1},
		"focus": {"bg": "", "border": "e07a70", "width": FOCUS_BORDER_WIDTH},
		"font_color": "ffffff",
		"font_hover_color": "ffffff",
		"font_pressed_color": "ffffff",
		"font_disabled_color": "5a4f49",
	},
}

# ⚠ StyleBox を書く4状態＋focus。⚠ Theme のキー名そのもの。
const BUTTON_STATES: Array[String] = ["normal", "hover", "pressed", "disabled", "focus"]

# --- 余白（MarginContainer）---
#
# ⚠ 既定は 24。⚠ 画面ルートだけ 32（`ScreenMargin`）。
# ⚠ モーダルは左右24／上下16（`DialogMargin`）。
const MARGIN_DEFAULT: int = 24
const MARGIN_SCREEN: int = 32
const MARGIN_DIALOG_H: int = 24
const MARGIN_DIALOG_V: int = 16

# --- 間隔（VBoxContainer / HBoxContainer）---
#
# ⚠ 名前は「用途」で付ける。⚠ 大きさ（GapXS 等）で付けない（人間の決定・2026-09-07）。
#   ⚠ 値と名前が結びつくと、値を変えたいときに「値を直すか名前を付け替えるか」で毎回迷う。
# ⚠ 既定は最頻値（縦8／横16）。⚠ 既定に当たるノードは variation を持たない。
const SEPARATION_VBOX_DEFAULT: int = 8
const SEPARATION_HBOX_DEFAULT: int = 16

# variation 名 -> {"value": 間隔, "base": 継承元の型}
const SEPARATION_VARIATIONS: Dictionary = {
	# 詰めた一覧の行（ダンジョンのショップ一覧・通路の宝箱）
	"TightList": {"value": 2, "base": "VBoxContainer"},
	# マップのノード（フロア・ダンジョン）
	"NodeList": {"value": 4, "base": "VBoxContainer"},
	# パネル内のブロック（ダンジョンのショップ・レリック・宝箱）
	"PanelStack": {"value": 6, "base": "VBoxContainer"},
	# 縦のまとまりの区切り（タイトル・代替画面・モーダル）
	"SectionGap": {"value": 16, "base": "VBoxContainer"},
	# 選択肢のカード列（ダンジョンの層・加護を選ぶ）
	"SectionStack": {"value": 20, "base": "VBoxContainer"},
	# ⚠ フェーズの中身の柱（ポモドーロの4ビュー・2026-09-09）。
	#   ⚠ 「見出し／タイマー／入力／ボタン」のまとまりどうしの間。
	#   ⚠ まとまりの中（説明文と入力欄）は既定の 8。
	"PhaseStack": {"value": 24, "base": "VBoxContainer"},
	# ⚠ 上部バーと中身の間（ポモドーロの器・2026-09-09）。
	#   ⚠ 画面の外周 32 の2倍。⚠ タイマーを画面の上寄りに置きすぎないための間。
	"PhaseTopGap": {"value": 64, "base": "VBoxContainer"},
	# ボタンの横並び（拠点のナビ）
	# ⚠ 人間の表に無かった1件。⚠ 横の既定 16 では拠点のナビが 8 から広がるため足した。
	"ButtonRow": {"value": 8, "base": "HBoxContainer"},
	# 独立したまとまりの横並び（育成の詳細・拠点のリソース行）
	"WideRow": {"value": 32, "base": "HBoxContainer"},
}

# --- 文字（Label）---

const LABEL_FONT_COLOR: String = "f0e6df"
const HEADING_FONT_SIZE: int = 32
const TIMER_FONT_SIZE: int = 64
# ⚠ 減少・警告の赤。⚠ 前は2箇所で色が違った（(0.9,0.3,0.3) と (1,0.4,0.4)）。
#   ⚠ 人間の決定でこの1色に揃えた（2026-09-07）。
# ⚠ 「下がる値」もこの色を使う（⚠ 装備の負の補正など）。⚠ 2色目を作らない。
const ERROR_FONT_COLOR: String = "e88a8a"
# ⚠ 増える値の緑（2026-09-08・段階③）。⚠ 減少の赤と対になる。
#   ⚠ 赤 #e88a8a と同じくらいの明度にしてある（⚠ 並べたときに片方だけ浮かないように）。
const GAIN_FONT_COLOR: String = "8ed99b"

# --- 面（PanelContainer）---

const PANEL_BG: String = "241d1a"
const PANEL_BORDER: String = "3a302b"
const PANEL_CORNER_RADIUS: int = 8
# ⚠ 画面の地。⚠ 各画面の Background は ColorRect で持っているが、
#   PanelContainer で地を敷く画面（tests/test_ui_common）はこれを使う。
const BACKGROUND_BG: String = "16110f"


static func build() -> void:
	# ⚠ 保存すると `.tres` の1行目から `uid=` が落ちる（実測・2026-09-07）。
	#   ⚠ いまは誰も uid:// で参照していないが、⚠ 黙って変わると
	#   ⚠ 後から uid で参照したときに繋がらなくなる。⚠ 保存の前に控えて後で書き戻す。
	var previous_uid: int = ResourceLoader.get_resource_uid(THEME_PATH)

	var theme: Theme = _load_theme()
	_build_buttons(theme)
	_build_margins(theme)
	_build_separations(theme)
	_build_labels(theme)
	_build_panels(theme)

	var err: int = ResourceSaver.save(theme, THEME_PATH)
	if err != OK:
		push_error("[BuildTheme] 保存に失敗した: " + str(err))
		return
	_restore_uid(previous_uid)
	print("[BuildTheme] 書き込んだ -> " + THEME_PATH)
	print("[BuildTheme] ボタン %d 階層 × %d 状態 ／ 間隔の variation %d 個" % [
		BUTTON_LEVELS.size(), BUTTON_STATES.size(), SEPARATION_VARIATIONS.size(),
	])


# ⚠ 既存を読んでから足す。⚠ 無ければ新規。
static func _load_theme() -> Theme:
	if ResourceLoader.exists(THEME_PATH):
		var existing: Resource = ResourceLoader.load(THEME_PATH, "Theme", ResourceLoader.CACHE_MODE_IGNORE)
		if existing is Theme:
			return existing as Theme
		push_warning("[BuildTheme] 既存が Theme ではない。新規で作る")
	return Theme.new()


static func _build_buttons(theme: Theme) -> void:
	for type_name: String in BUTTON_LEVELS:
		var level: Dictionary = BUTTON_LEVELS[type_name]
		if type_name != "Button":
			theme.set_type_variation(StringName(type_name), &"Button")
		for state: String in BUTTON_STATES:
			var spec: Dictionary = level[state]
			theme.set_stylebox(StringName(state), StringName(type_name), _button_style(spec))
		theme.set_color(&"font_color", StringName(type_name), _html(str(level["font_color"])))
		theme.set_color(&"font_hover_color", StringName(type_name), _html(str(level["font_hover_color"])))
		theme.set_color(&"font_pressed_color", StringName(type_name), _html(str(level["font_pressed_color"])))
		# ⚠ フォーカス時は通常と同じ色。⚠ 枠（focus の StyleBox）だけで示す。
		theme.set_color(&"font_focus_color", StringName(type_name), _html(str(level["font_color"])))
		theme.set_color(&"font_disabled_color", StringName(type_name), _html(str(level["font_disabled_color"])))
		theme.set_font_size(&"font_size", StringName(type_name), BUTTON_FONT_SIZE)


static func _button_style(spec: Dictionary) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.content_margin_left = BUTTON_PAD_H
	style.content_margin_right = BUTTON_PAD_H
	style.content_margin_top = BUTTON_PAD_V
	style.content_margin_bottom = BUTTON_PAD_V
	style.set_corner_radius_all(BUTTON_CORNER_RADIUS)
	var bg: String = str(spec.get("bg", ""))
	style.bg_color = Color(0, 0, 0, 0) if bg == "" else _html(bg)
	var border: String = str(spec.get("border", ""))
	var width: int = int(spec.get("width", 0))
	if border != "" and width > 0:
		style.set_border_width_all(width)
		style.border_color = _html(border)
	else:
		style.set_border_width_all(0)
	return style


static func _build_margins(theme: Theme) -> void:
	_set_margin(theme, "MarginContainer", MARGIN_DEFAULT, MARGIN_DEFAULT)
	theme.set_type_variation(&"ScreenMargin", &"MarginContainer")
	_set_margin(theme, "ScreenMargin", MARGIN_SCREEN, MARGIN_SCREEN)
	theme.set_type_variation(&"DialogMargin", &"MarginContainer")
	_set_margin(theme, "DialogMargin", MARGIN_DIALOG_H, MARGIN_DIALOG_V)


static func _set_margin(theme: Theme, type_name: String, horizontal: int, vertical: int) -> void:
	theme.set_constant(&"margin_left", StringName(type_name), horizontal)
	theme.set_constant(&"margin_right", StringName(type_name), horizontal)
	theme.set_constant(&"margin_top", StringName(type_name), vertical)
	theme.set_constant(&"margin_bottom", StringName(type_name), vertical)


static func _build_separations(theme: Theme) -> void:
	theme.set_constant(&"separation", &"VBoxContainer", SEPARATION_VBOX_DEFAULT)
	theme.set_constant(&"separation", &"HBoxContainer", SEPARATION_HBOX_DEFAULT)
	for name: String in SEPARATION_VARIATIONS:
		var spec: Dictionary = SEPARATION_VARIATIONS[name]
		theme.set_type_variation(StringName(name), StringName(str(spec["base"])))
		theme.set_constant(&"separation", StringName(name), int(spec["value"]))


static func _build_labels(theme: Theme) -> void:
	theme.set_color(&"font_color", &"Label", _html(LABEL_FONT_COLOR))
	theme.set_type_variation(&"HeadingLabel", &"Label")
	theme.set_font_size(&"font_size", &"HeadingLabel", HEADING_FONT_SIZE)
	theme.set_type_variation(&"TimerLabel", &"Label")
	theme.set_font_size(&"font_size", &"TimerLabel", TIMER_FONT_SIZE)
	theme.set_type_variation(&"ErrorLabel", &"Label")
	theme.set_color(&"font_color", &"ErrorLabel", _html(ERROR_FONT_COLOR))
	theme.set_type_variation(&"GainLabel", &"Label")
	theme.set_color(&"font_color", &"GainLabel", _html(GAIN_FONT_COLOR))


static func _build_panels(theme: Theme) -> void:
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = _html(PANEL_BG)
	panel.set_corner_radius_all(PANEL_CORNER_RADIUS)
	panel.set_border_width_all(1)
	panel.border_color = _html(PANEL_BORDER)
	theme.set_stylebox(&"panel", &"PanelContainer", panel)

	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = _html(BACKGROUND_BG)
	theme.set_type_variation(&"BackgroundPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"BackgroundPanel", background)


static func _html(hex: String) -> Color:
	return Color.html(hex)


# ⚠ 1行目に `uid=` を書き戻す。⚠ 元から無ければ何もしない。
# ⚠ ここだけ `.tres` を文字列として触る。⚠ 生成スクリプトの中なので許される
#   （⚠ 「`.tres` を手で書き換えない」は人間が手で開くことを指す）。
static func _restore_uid(previous_uid: int) -> void:
	if previous_uid == ResourceUID.INVALID_ID:
		return
	var text: String = FileAccess.get_file_as_string(THEME_PATH)
	if text == "":
		push_warning("[BuildTheme] 保存後の .tres を読み直せない。uid を書き戻せなかった")
		return
	var head: String = text.get_slice("\n", 0)
	if head.contains("uid="):
		return
	var uid_text: String = ResourceUID.id_to_text(previous_uid)
	var fixed: String = head.replace(
		"[gd_resource type=\"Theme\" format=3]",
		"[gd_resource type=\"Theme\" format=3 uid=\"%s\"]" % uid_text,
	)
	if fixed == head:
		push_warning("[BuildTheme] 1行目の形が想定と違う。uid を書き戻せなかった: " + head)
		return
	var file: FileAccess = FileAccess.open(THEME_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[BuildTheme] .tres を開けない。uid を書き戻せなかった")
		return
	file.store_string(fixed + text.substr(head.length()))
	file.close()
	print("[BuildTheme] uid を書き戻した: " + uid_text)
