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

# ⚠⚠ 無効の1組（2026-09-09・人間のモック「D案」＋人間の決定「モックに合わせて全画面明るくする」）。
#   ⚠ 4階層のどこから入っても**同じ見た目に落とす**。⚠ 真鍮の暗い版などを別に持たない
#   ⚠ （＝色が1つ増えるのを避ける。⚠ モック側の判断をそのまま採った）。
#   ⚠ 前は 地 1e1917 / 枠 2a2320 / 文字 5a4f49（⚠ Ghost だけ文字 3f3835）で、⚠ 一段暗かった。
# ⚠ 地・枠・文字とも**既存の値の使い回し**（⚠ 地=ボタンの地 ／ 枠=PANEL_BORDER ／ 文字=入力欄の下書き）。
# ⚠ Ghost だけは地を透明のまま残す（⚠ 「地を持たない」がこの階層の作りそのものなので）。
const DISABLED_BG: String = "241d1a"
const DISABLED_BORDER: String = "3a302b"
const DISABLED_FONT: String = "6f635c"

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
		"disabled": {"bg": DISABLED_BG, "border": DISABLED_BORDER, "width": 1},
		"focus": {"bg": "", "border": "f0c04a", "width": FOCUS_BORDER_WIDTH},
		"font_color": "e0d5ce",
		"font_hover_color": "f0e6df",
		"font_pressed_color": "e0d5ce",
		"font_disabled_color": DISABLED_FONT,
	},
	# 真鍮。ギルド側の主要動作。⚠ 1画面に1個まで。
	"PrimaryButton": {
		"normal": {"bg": "a8791f", "border": "", "width": 0},
		"hover": {"bg": "c9922e", "border": "", "width": 0},
		"pressed": {"bg": "8a6114", "border": "", "width": 0},
		"disabled": {"bg": DISABLED_BG, "border": DISABLED_BORDER, "width": 1},
		"focus": {"bg": "", "border": "f0c04a", "width": FOCUS_BORDER_WIDTH},
		"font_color": "1a1206",
		"font_hover_color": "1a1206",
		"font_pressed_color": "1a1206",
		"font_disabled_color": DISABLED_FONT,
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
		"disabled": {"bg": "", "border": DISABLED_BORDER, "width": 1},
		"focus": {"bg": "", "border": "f0c04a", "width": FOCUS_BORDER_WIDTH},
		"font_color": "a89b94",
		"font_hover_color": "f0e6df",
		"font_pressed_color": "e0d5ce",
		"font_disabled_color": DISABLED_FONT,
	},
	# 冒険側。潜る・撤退など。⚠ 割り当ては未定（画面が決まっていない）。
	#   ⚠ 前の赤 #c44539 とは別の値。⚠ 流用しないこと（人間の指示・2026-09-07）。
	"DangerButton": {
		"normal": {"bg": "a8352f", "border": "", "width": 0},
		"hover": {"bg": "c4433c", "border": "", "width": 0},
		"pressed": {"bg": "8a2a25", "border": "", "width": 0},
		"disabled": {"bg": DISABLED_BG, "border": DISABLED_BORDER, "width": 1},
		"focus": {"bg": "", "border": "e07a70", "width": FOCUS_BORDER_WIDTH},
		"font_color": "ffffff",
		"font_hover_color": "ffffff",
		"font_pressed_color": "ffffff",
		"font_disabled_color": DISABLED_FONT,
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
# ⚠ 沈めた字（2026-09-09・人間のモック）。⚠ 「本文より一段引く」ためのもの。
#   ⚠ 使う先：⚠ 入力欄の上の説明文 ／ ⚠ 加護の3択の右側の値。
#   ⚠ 新しい色ではない（⚠ GhostButton の文字と同じ値）。⚠ モックが両方に同じ色を当てていた。
const MUTED_FONT_COLOR: String = "a89b94"

# --- 入力欄（LineEdit / TextEdit）---
#
# ⚠⚠ **このプロジェクト初の入力欄の見た目**（2026-09-09・人間のモック）。
#   ⚠ ここまで1行も無く、⚠ Godot の既定のまま（明るい灰色）だった。
# ⚠ 使っている画面は**ポモドーロの2ビューだけ**（`grep` で確認）。⚠ 影響はそこに閉じている。
# ⚠ 地と下書きの字の2色が、⚠ このモックで**新しく増えた唯一の色**。
const INPUT_BG: String = "1e1815"
const INPUT_PLACEHOLDER: String = "6f635c"
# ⚠ 枠はボタンの既定と同じ段（⚠ 並べたときに揃う）。⚠ 角丸もボタンと同じ 8。
const INPUT_BORDER: String = "4a3d36"
# ⚠ 高さ 42px の内訳（⚠ モックの `height:42px`）。⚠ 文字16 ＋ 上下13 × 2。
const INPUT_PAD_H: int = 16
const INPUT_PAD_V: int = 13

# --- リソースが増えたときの演出（2026-09-09）---
#
# ⚠⚠ **人間のモック「採用版」の値をそのまま移した**（2026-09-09）。⚠ もう仮ではない。
# ⚠ 秒は Theme の定数が int しか持てないのでミリ秒で持つ。
# ⚠ `route` は `ResourceGainEffect.Route` の添字（0 直線 / 1 上へ山なり / 2 横へ迂回 /
#   3 S字 / 4 引いてから飛ぶ）。⚠ モックは「上へ山なり」＝ 1。
const GAIN_ROUTE: int = 1
const GAIN_FLY_MS: int = 1860
const GAIN_ARC: int = 90
# ⚠ 膨らみの上限。⚠ 出どころと着地先が遠いときに山が高くなりすぎないように。
const GAIN_ARC_MAX: int = 120
# ⚠ 鞄のマスへ飛ばすときだけ低くする（⚠ 距離が近いので 90 だと山が目立ちすぎる）。
const GAIN_ARC_CELL: int = 60
const GAIN_STAGGER_MS: int = 210
const GAIN_SPREAD: int = 24
const GAIN_RISE: int = 56
const GAIN_FLOAT_MS: int = 2700
const GAIN_FLOAT_FONT: int = 24
const GAIN_ICON: int = 28

# ⚠⚠ 飛ぶ個数は**増える量で決まる**（⚠ モックの決定）。⚠ 固定ではない。
#   ⚠ +1〜9 = 1個 ／ +10〜99 = 3個 ／ +100〜999 = 5個 ／ +1000〜 = 8個。
const GAIN_COUNT_1: int = 1
const GAIN_COUNT_2: int = 3
const GAIN_COUNT_3: int = 5
const GAIN_COUNT_4: int = 8
const GAIN_STEP_2: int = 10
const GAIN_STEP_3: int = 100
const GAIN_STEP_4: int = 1000

# ⚠ 同時に何種類も増えたとき（⚠ 宝箱は金＋ジェム＋素材3種などが一度に入る）。
#   ⚠ この数以上の種類が同時なら、⚠ 1種あたりの個数を絞って画面を静かに保つ。
#   ⚠ 種類ごとに時間をずらし、⚠ 浮かぶ数字は先頭の1種類だけ出す。
const GAIN_TYPES_BUSY: int = 3
const GAIN_COUNT_BUSY: int = 2
const GAIN_TYPE_STAGGER_MS: int = 540

# ⚠ 着いたときの表示欄の反応。⚠ ふくらみは**増える量で変えない**（⚠ モックの決定）。
#   ⚠ 百分率で持つ（⚠ Theme の定数が int しか持てないため）。114 = 1.14倍。
const GAIN_POP_PERCENT: int = 114
const GAIN_POP_MS: int = 540
# ⚠ 数字が回って増える時間。⚠ 1個ずつの遅れと同じにしてある
#   （⚠ 次の1個が着く前に必ず回り終わる）。
const GAIN_COUNT_MS: int = 210

# ⚠ 飛ぶアイコンの色。⚠ 線画は白1色なので、⚠ ここで着せる（`modulate`）。
#   ⚠ 増える緑（`GainLabel`）と揃えてある。⚠ 浮かぶ数字も同じ色になる。
const GAIN_FLYER_COLOR: String = "8ed99b"

# --- ポモドーロのタイマーの輪とセットの点（2026-09-09・人間のモック）---
#
# ⚠ 自前で `_draw()` する部品の値も**ここが持つ**。⚠ スクリプトに const で置かない。
#   ⚠ Theme に専用の型（`TimerRing` / `SetDots`）を作り、⚠ 部品は
#   ⚠ `get_theme_color()` / `get_theme_constant()` で引く。
#   ⚠ こうすれば「見た目の値を持つのは theme_builder と main_theme.tres だけ」が崩れない。
# ⚠⚠ **新しい色は1つも足していない**。⚠ 4つとも既に在る値の使い回し。
const RING_GROOVE: String = "241d1a"    # ⚠ ボタンの地と同じ。⚠ 開始前から見えている溝
const RING_FILL: String = "a8791f"      # ⚠ 真鍮。⚠ PrimaryButton の地と同じ
const RING_DIAMETER: int = 240
const RING_STROKE: int = 2
const DOT_DONE: String = "a89b94"       # ⚠ GhostButton の文字と同じ
const DOT_TODO: String = "3a302b"       # ⚠ PANEL_BORDER と同じ
const DOT_SIZE: int = 8
const DOT_CURRENT_WIDTH: int = 40
const DOT_GAP: int = 8

# --- 面（PanelContainer）---

const PANEL_BG: String = "241d1a"
const PANEL_BORDER: String = "3a302b"
const PANEL_CORNER_RADIUS: int = 8
# ⚠ 右上に出す資源のチップ（2026-09-09・人間のモック「採用版」の `.hud`）。
#   ⚠ 枠だけ既定の面より1段明るい（⚠ ボタンの枠と同じ値。⚠ 押せないが「欄」だと分かる濃さ）。
#   ⚠ 内側の余白は左右16 / 上下8（⚠ モックの `padding:8px 16px`）。
const CHIP_BORDER: String = "4a3d36"
# ⚠⚠ 2026-09-09 に小さくした（人間の指示「あともっと小さくしてほしい」）。
#   ⚠ 前は 左右16 / 上下8。⚠ 素材16件が右上に並ぶようになり、⚠ その大きさでは入らない。
const CHIP_PAD_H: int = 10
const CHIP_PAD_V: int = 4
# ⚠ チップの中のアイコン（⚠ モックの `.hud .ic` は 20px）。
#   ⚠ `ResourceDisplay` の既定は 24px だが、⚠ チップの中だけモックに合わせて 20px。
# ⚠⚠ **縦は縮まなかった**（実測：24px でも 20px でも倉庫は 712）。
#   ⚠ ヘッダーの高さを決めているのはアイコンではない。⚠ 何が決めているかは未特定。
#   ⚠ ここを動かして縦を詰めようとしないこと（⚠ 1回試して効かなかった）。
# ⚠ 2026-09-09 に 20 -> 16 -> 12（人間の指示「もっと小さく」「そもそもアイコンが大きすぎる」）。
const CHIP_ICON: int = 12
# ⚠ チップは**丸い（カプセル）**（2026-09-09・人間の参考画像）。
#   ⚠ 角丸はボタンの 8 ではなく、⚠ 高さの半分より大きい値を入れて両端を半円にする
#   （⚠ Godot は高さの半分で頭打ちにするので、⚠ 大きめを入れておけば高さが変わっても丸いまま）。
const CHIP_CORNER_RADIUS: int = 64
# ⚠ チップの中の数字。⚠ 既定16より1段小さい。⚠ **新しい段は作らない**
#   （⚠ ボタンと同じ14を使い回す。⚠ 文字の大きさの段はまだ未決なので増やさない）。
const CHIP_FONT_SIZE: int = BUTTON_FONT_SIZE
# ⚠ チップの中（絵と数字の間）と、⚠ チップどうしの間。⚠ 既定の横16では空きすぎる。
const CHIP_SEPARATION: int = 4
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
	_build_inputs(theme)
	_build_pomodoro(theme)

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
	theme.set_type_variation(&"MutedLabel", &"Label")
	theme.set_color(&"font_color", &"MutedLabel", _html(MUTED_FONT_COLOR))


static func _build_panels(theme: Theme) -> void:
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = _html(PANEL_BG)
	panel.set_corner_radius_all(PANEL_CORNER_RADIUS)
	panel.set_border_width_all(1)
	panel.border_color = _html(PANEL_BORDER)
	theme.set_stylebox(&"panel", &"PanelContainer", panel)

	var chip: StyleBoxFlat = StyleBoxFlat.new()
	chip.bg_color = _html(PANEL_BG)
	chip.set_corner_radius_all(CHIP_CORNER_RADIUS)
	chip.set_border_width_all(1)
	chip.border_color = _html(CHIP_BORDER)
	chip.content_margin_left = CHIP_PAD_H
	chip.content_margin_right = CHIP_PAD_H
	chip.content_margin_top = CHIP_PAD_V
	chip.content_margin_bottom = CHIP_PAD_V
	theme.set_type_variation(&"ResourceChip", &"PanelContainer")
	theme.set_stylebox(&"panel", &"ResourceChip", chip)
	theme.set_constant(&"icon", &"ResourceChip", CHIP_ICON)
	# ⚠ チップの中の数字。⚠ `ResourceDisplay` の中の Label に当てる。
	theme.set_type_variation(&"ChipValueLabel", &"Label")
	theme.set_font_size(&"font_size", &"ChipValueLabel", CHIP_FONT_SIZE)
	# ⚠ 絵と数字の間 ／ チップどうしの間。⚠ 同じ値を2箇所で使う。
	theme.set_type_variation(&"ChipRow", &"HBoxContainer")
	theme.set_constant(&"separation", &"ChipRow", CHIP_SEPARATION)
	# ⚠ 折り返す器（拠点は素材16件が並ぶので1行に入らない）。
	theme.set_type_variation(&"ChipFlow", &"HFlowContainer")
	theme.set_constant(&"h_separation", &"ChipFlow", CHIP_SEPARATION)
	theme.set_constant(&"v_separation", &"ChipFlow", CHIP_SEPARATION)

	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = _html(BACKGROUND_BG)
	theme.set_type_variation(&"BackgroundPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"BackgroundPanel", background)


# ⚠ 入力欄。⚠ LineEdit と TextEdit で**同じ見た目**にする（⚠ 1行と複数行の違いだけ）。
#   ⚠ `focus` は枠の色をボタンの focus と揃える（⚠ 真鍮の縁）。
static func _build_inputs(theme: Theme) -> void:
	for type_name: String in ["LineEdit", "TextEdit"]:
		var name: StringName = StringName(type_name)
		theme.set_stylebox(&"normal", name, _input_style(INPUT_BORDER, 1))
		theme.set_stylebox(&"focus", name, _input_style("f0c04a", FOCUS_BORDER_WIDTH))
		theme.set_stylebox(&"read_only", name, _input_style(DISABLED_BORDER, 1))
		theme.set_color(&"font_color", name, _html(LABEL_FONT_COLOR))
		theme.set_color(&"font_placeholder_color", name, _html(INPUT_PLACEHOLDER))
		theme.set_color(&"caret_color", name, _html(LABEL_FONT_COLOR))
	# ⚠ 無効時の文字の色だけ、⚠ 型ごとに名前が違う（⚠ Godot 側の都合）。
	theme.set_color(&"font_uneditable_color", &"LineEdit", _html(INPUT_PLACEHOLDER))
	theme.set_color(&"font_readonly_color", &"TextEdit", _html(INPUT_PLACEHOLDER))


static func _input_style(border_hex: String, width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = _html(INPUT_BG)
	style.set_corner_radius_all(BUTTON_CORNER_RADIUS)
	style.set_border_width_all(width)
	style.border_color = _html(border_hex)
	style.content_margin_left = INPUT_PAD_H
	style.content_margin_right = INPUT_PAD_H
	style.content_margin_top = INPUT_PAD_V
	style.content_margin_bottom = INPUT_PAD_V
	return style


# ⚠ 自前で描く2つ（タイマーの輪 ／ セットの点）の値。
#   ⚠ 型は variation ではなく**独立した型**にする（⚠ 継承元の Control が持つ
#   ⚠ 色や定数と名前がぶつからないようにするため）。
static func _build_pomodoro(theme: Theme) -> void:
	theme.set_color(&"groove", &"TimerRing", _html(RING_GROOVE))
	theme.set_color(&"fill", &"TimerRing", _html(RING_FILL))
	theme.set_constant(&"diameter", &"TimerRing", RING_DIAMETER)
	theme.set_constant(&"stroke", &"TimerRing", RING_STROKE)

	var gain: Dictionary = {
		"route": GAIN_ROUTE,
		"fly_ms": GAIN_FLY_MS,
		"arc": GAIN_ARC,
		"arc_max": GAIN_ARC_MAX,
		"arc_cell": GAIN_ARC_CELL,
		"stagger_ms": GAIN_STAGGER_MS,
		"spread": GAIN_SPREAD,
		"rise": GAIN_RISE,
		"float_ms": GAIN_FLOAT_MS,
		"float_font": GAIN_FLOAT_FONT,
		"icon": GAIN_ICON,
		"count_1": GAIN_COUNT_1,
		"count_2": GAIN_COUNT_2,
		"count_3": GAIN_COUNT_3,
		"count_4": GAIN_COUNT_4,
		"step_2": GAIN_STEP_2,
		"step_3": GAIN_STEP_3,
		"step_4": GAIN_STEP_4,
		"types_busy": GAIN_TYPES_BUSY,
		"count_busy": GAIN_COUNT_BUSY,
		"type_stagger_ms": GAIN_TYPE_STAGGER_MS,
		"pop_percent": GAIN_POP_PERCENT,
		"pop_ms": GAIN_POP_MS,
		"count_ms": GAIN_COUNT_MS,
	}
	for key: String in gain.keys():
		theme.set_constant(StringName(key), &"ResourceGainEffect", int(gain[key]))
	theme.set_color(&"flyer", &"ResourceGainEffect", _html(GAIN_FLYER_COLOR))

	theme.set_color(&"done", &"SetDots", _html(DOT_DONE))
	theme.set_color(&"todo", &"SetDots", _html(DOT_TODO))
	theme.set_color(&"current", &"SetDots", _html(RING_FILL))
	theme.set_constant(&"size", &"SetDots", DOT_SIZE)
	theme.set_constant(&"current_width", &"SetDots", DOT_CURRENT_WIDTH)
	theme.set_constant(&"gap", &"SetDots", DOT_GAP)


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
