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
# ⚠⚠ 紙の上に当てるテーマ（2026-09-26・決定 `UI-14`・人間「⚠ あで」）。
#   ⚠ 紙の部品の `theme` にこれを持たせると、⚠ 中の字が全部**墨色**になる
#   ⚠ （⚠ 字を1つずつ付け替えない）。⚠ ここに無い項目は `main_theme.tres` に落ちる。
#   ⚠ 値を持つのは引き続きこのファイルだけ（⚠ `.tres` は2枚とも生成物）。
const PAPER_THEME_PATH: String = "res://theme/paper_theme.tres"

# --- ⚠⚠ 手本の色（2026-09-26・決定 `UI-11`「全部寄せる」）---
#
# ⚠ 出どころは `docs/pomodoro-heroes-ui-docs/docs/ui/ui_tokens.json`（⚠ 名前もそのまま）。
#   ⚠ 下の各所はこの定数を引く。⚠ 16進を2か所に書かない。
const TOKEN_FLOOR: String = "1b1512"          # 夜の床（画面の地）
const TOKEN_BOARD: String = "2a201a"          # 板（暗い面・戦闘の欄）
const TOKEN_LEATHER: String = "4a3526"        # 革（既定ボタン・戻る）
const TOKEN_BRASS: String = "b98a2c"          # 真鍮（主ボタン・1画面に1つ）
const TOKEN_LIGHT: String = "d4a640"          # 灯り（選択・線・光）
const TOKEN_WAX: String = "9c3a2e"            # 封蝋（危険・しおり紐・判）
const TOKEN_PAPER: String = "e9dcc0"          # 羊皮紙
const TOKEN_PAPER_SELECTED: String = "f4ead3" # 明るい紙（選んでいる行）
const TOKEN_INK: String = "2b2118"            # 墨（紙の上の字）
const TOKEN_INK_SUB: String = "6e5a43"        # 薄墨（⚠ これより薄くしない）
const TOKEN_RULE: String = "c2ae88"           # 罫
const TOKEN_BRASS_INK: String = "9c7424"      # 真鍮の墨（紙の上の強調）
const TOKEN_TEXT_ON_DARK: String = "eadfca"
const TOKEN_TEXT_DIM_ON_DARK: String = "a8987f"
const TOKEN_HP: String = "7fae5a"
const TOKEN_BUFF: String = "2f79bd"
const TOKEN_DEBUFF: String = "a8402f"
const TOKEN_REVIVE: String = "e0ac2e"
# ⚠ 紙の上の「増える」緑。⚠ `ui_tokens.json` には無く、⚠ 手本の HTML（Character / LevelUp）の値。
const TOKEN_PAPER_GAIN: String = "5f7d4f"

# --- ボタンの共通の寸法 ---

# ⚠ 角丸は手本の 6（`ui_tokens.json` `radius_button`・2026-09-26。⚠ 前は 8）。
const BUTTON_CORNER_RADIUS: int = 6
const BUTTON_PAD_H: float = 20.0
# ⚠⚠ 手本のボタンは高さ 44（`sizes.button`）。⚠ 字14 の行の高さ約20 ＋ 上下12 × 2。
#   ⚠ 前は 8（⚠ 高さ約36）。⚠ 全画面で縦が 8px 伸びる。
const BUTTON_PAD_V: float = 12.0
const BUTTON_FONT_SIZE: int = 14
const FOCUS_BORDER_WIDTH: int = 2
# ⚠ 面に重ねる「当たり」のホバーの縁（⚠ 面の外側に出す）。
const HIT_BORDER_WIDTH: int = 1

# ⚠⚠ 無効の1組（2026-09-09・人間のモック「D案」＋人間の決定「モックに合わせて全画面明るくする」）。
#   ⚠ 4階層のどこから入っても**同じ見た目に落とす**。⚠ 真鍮の暗い版などを別に持たない
#   ⚠ （＝色が1つ増えるのを避ける。⚠ モック側の判断をそのまま採った）。
#   ⚠ 前は 地 1e1917 / 枠 2a2320 / 文字 5a4f49（⚠ Ghost だけ文字 3f3835）で、⚠ 一段暗かった。
# ⚠ 地・枠・文字とも**既存の値の使い回し**（⚠ 地=ボタンの地 ／ 枠=PANEL_BORDER ／ 文字=入力欄の下書き）。
# ⚠ Ghost だけは地を透明のまま残す（⚠ 「地を持たない」がこの階層の作りそのものなので）。
# ⚠ 2026-09-26：地を手本の「板」へ（`UI-11`）。⚠ 枠・文字は手本に無いので今のまま。
const DISABLED_BG: String = TOKEN_BOARD
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
#
# ⚠⚠ 2026-09-26：中身を手本（`ui_tokens.json` の `buttons`）へ差し替えた（`UI-11`）。
#   ⚠ **名前は変えていない**（`UI-4`）：手本 leather＝`Button` ／ brass＝`PrimaryButton` ／
#   ⚠ ghost＝`GhostButton` ／ red＝`DangerButton` ／ back＝`BackButton`。
#   ⚠ 手本が持つのは normal の地・枠・字だけ。⚠ hover / pressed は手本に無いので、
#   ⚠ normal から1段明るく／暗くした値を置いた（⚠ 手応えは人間の見る回）。
#   ⚠ focus の縁は手本の「灯り」（`TOKEN_LIGHT`）。
const BUTTON_LEVELS: Dictionary = {
	# 既定。並列の選択肢。⚠ 手本の「革」（⚠ 前は暗い灰 241d1a）。
	"Button": {
		"normal": {"bg": TOKEN_LEATHER, "border": "5a4330", "width": 1},
		"hover": {"bg": "5c4230", "border": "6a5340", "width": 1},
		"pressed": {"bg": "3a2a1e", "border": "5a4330", "width": 1},
		"disabled": {"bg": DISABLED_BG, "border": DISABLED_BORDER, "width": 1},
		"focus": {"bg": "", "border": TOKEN_LIGHT, "width": FOCUS_BORDER_WIDTH},
		"font_color": "f1e6cf",
		"font_hover_color": "ffffff",
		"font_pressed_color": "f1e6cf",
		"font_disabled_color": DISABLED_FONT,
	},
	# 真鍮。ギルド側の主要動作。⚠ 1画面に1個まで。
	"PrimaryButton": {
		"normal": {"bg": TOKEN_BRASS, "border": "7a5716", "width": 1},
		"hover": {"bg": TOKEN_LIGHT, "border": "7a5716", "width": 1},
		"pressed": {"bg": TOKEN_BRASS_INK, "border": "7a5716", "width": 1},
		"disabled": {"bg": DISABLED_BG, "border": DISABLED_BORDER, "width": 1},
		"focus": {"bg": "", "border": TOKEN_LIGHT, "width": FOCUS_BORDER_WIDTH},
		"font_color": "1f160f",
		"font_hover_color": "1f160f",
		"font_pressed_color": "1f160f",
		"font_disabled_color": DISABLED_FONT,
	},
	# 戻る・閉じる。⚠ 地は透明のまま。⚠ 枠だけ持たせる（2026-09-08・人間の指示
	#   「⚠ 拠点のセーブするボタン、倉庫の戻るボタンなどの周りに枠を付けてほしい」）。
	#   ⚠ 枠が無いと「ただの文字」に見えて、押せるものだと分からなかった。
	# ⚠ 枠の色は Secondary と同じ段（⚠ 地の有無だけが違う＝並べたときに揃う）。
	# ⚠ 無効時は枠も文字も一段暗い（⚠ 地が無いぶん、手がかりが枠と文字の2つになった）。
	"GhostButton": {
		"normal": {"bg": "", "border": "6a5340", "width": 1},
		"hover": {"bg": TOKEN_BOARD, "border": "8a7458", "width": 1},
		"pressed": {"bg": TOKEN_FLOOR, "border": "6a5340", "width": 1},
		"disabled": {"bg": "", "border": DISABLED_BORDER, "width": 1},
		"focus": {"bg": "", "border": TOKEN_LIGHT, "width": FOCUS_BORDER_WIDTH},
		"font_color": "d9ccb4",
		"font_hover_color": TOKEN_TEXT_ON_DARK,
		"font_pressed_color": "d9ccb4",
		"font_disabled_color": DISABLED_FONT,
	},
	# 冒険側。潜る・撤退など。⚠ 割り当ては未定（画面が決まっていない）。
	#   ⚠ 前の赤 #c44539 とは別の値。⚠ 流用しないこと（人間の指示・2026-09-07）。
	# ⚠ 2026-09-26：手本の red（`8a3327` ／ 枠 `6e2219` ／ 字 `fbeee6`）。
	"DangerButton": {
		"normal": {"bg": "8a3327", "border": "6e2219", "width": 1},
		"hover": {"bg": "a03d2f", "border": "6e2219", "width": 1},
		"pressed": {"bg": "6e2219", "border": "6e2219", "width": 1},
		"disabled": {"bg": DISABLED_BG, "border": DISABLED_BORDER, "width": 1},
		"focus": {"bg": "", "border": "e07a70", "width": FOCUS_BORDER_WIDTH},
		"font_color": "fbeee6",
		"font_hover_color": "ffffff",
		"font_pressed_color": "fbeee6",
		"font_disabled_color": DISABLED_FONT,
	},
	# ⚠⚠ 戻る専用（2026-09-14・人間の指示「⚠ 戻るボタンに色を付けて 専用の ／ 今の戻るボタンは目立たない」）。
	#   ⚠ 前は Ghost（地が透明・灰の文字）で、⚠ 左上に置いても「ただの枠」に見えていた。
	#   ⚠⚠ **革の茶色の面＋真鍮の枠**（2026-09-14・人間の指示「⚠ 青緑は目立つがマッチしてない
	#   ⚠ ギルドのような雰囲気の色で」）。⚠ 1回目は青緑（2c5f68）にして、⚠ 画面の暖色から浮いた。
	#   ⚠ 真鍮の**べた塗り**は主要動作（PrimaryButton）なので、⚠ 戻るは**茶の地に真鍮の線**で分ける。
	#   ⚠ 枠は PrimaryButton の地と同値（a8791f）、⚠ ホバーの枠はその明るい側（c9922e）。
	#   ⚠ 文字は本文の明るい段（f0e6df）。⚠ 新しい値は地の3段だけ。
	# ⚠ これで階層は5つ（⚠ 既定 ／ 真鍮 ／ Ghost ／ 赤 ／ 戻る）。
	"BackButton": {
		# ⚠ 2026-09-26：手本の back も 地 `4a3526` ／ 枠 `a8791f` で**同じ**（⚠ `UI-5` は覆らない）。⚠ 字だけ手本へ。
		"normal": {"bg": TOKEN_LEATHER, "border": "a8791f", "width": 1},
		"hover": {"bg": "5c4230", "border": "c9922e", "width": 1},
		"pressed": {"bg": "3a2a1e", "border": "a8791f", "width": 1},
		"disabled": {"bg": DISABLED_BG, "border": DISABLED_BORDER, "width": 1},
		"focus": {"bg": "", "border": TOKEN_LIGHT, "width": FOCUS_BORDER_WIDTH},
		"font_color": "f1e6cf",
		"font_hover_color": "ffffff",
		"font_pressed_color": "f1e6cf",
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
	# ⚠ 戦闘の3段（ヘッダー／戦場／下部パネル・2026-09-16）。
	#   ⚠ 段どうしは1pxの線で接するので、⚠ 間を空けない。
	"BattleBands": {"value": 0, "base": "VBoxContainer"},
	# ⚠ 下部パネルの3分割（同）。⚠ 区切りは1pxの線そのものなので、⚠ 間を空けない。
	"BattleColumns": {"value": 0, "base": "HBoxContainer"},
	# ボタンの横並び（拠点のナビ）
	# ⚠ 人間の表に無かった1件。⚠ 横の既定 16 では拠点のナビが 8 から広がるため足した。
	"ButtonRow": {"value": 8, "base": "HBoxContainer"},
	# 独立したまとまりの横並び（育成の詳細・拠点のリソース行）
	"WideRow": {"value": 32, "base": "HBoxContainer"},
}

# --- 文字（Label）---

const LABEL_FONT_COLOR: String = TOKEN_TEXT_ON_DARK  # ⚠ 2026-09-26 手本へ（前 f0e6df）
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
const MUTED_FONT_COLOR: String = TOKEN_TEXT_DIM_ON_DARK  # ⚠ 2026-09-26 手本へ（前 a89b94）
# ⚠⚠ 説明文・注記の2段（2026-09-11・人間のモック「ギルド／育成」）。
#   ⚠ モックは字の色を5段（tx 〜 tx5）で使い分けている。⚠ 上3段は既に在った
#   （tx = LABEL_FONT_COLOR ／ tx2 = ボタンの文字 ／ tx3 = MUTED_FONT_COLOR）。
#   ⚠ 下2段が無かったので足した。⚠ **新しく増えた色はこの2つだけ**。
const DIM_FONT_COLOR: String = "7d6f68"     # ⚠ カードの説明文・行の副題・効果文
const FAINT_FONT_COLOR: String = "5a4f49"   # ⚠ 小見出し（「この子の設定」）・注記
# ⚠⚠ **文字の大きさの6段目**（⚠ 覆さない決定「5段だけ」に触る。⚠ 報告済み）。
#   ⚠ モックは 10 / 11 / 12 / 13 / 15 / 18 を使っている。⚠ そのまま入れると段が11個になるので、
#   ⚠ **10・11・12 → 12 ／ 13・14 → ボタンの14 ／ 15・16・18 → 既定の16** に丸めた。
#   ⚠ ＝**増やした段は1つだけ**。⚠ これが無いと説明文が本文と同じ大きさになり、
#   ⚠ モックの「行の中に3段の情報を積む」形が成立しない。
const SMALL_FONT_SIZE: int = 12
# ⚠ 仕切り線（ヘッダーの下・小見出しの横）。⚠ モックの `--div`。
const DIVIDER_COLOR: String = "2e2724"

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
# ⚠ 何種類も同時に増えたとき、⚠ 出どころの数字を縦に積む段差（2026-09-10・人間の指示
#   「⚠ 複数素材を手に入れたら、⚠ 発射もとにも複数書いて。⚠ 1つしか書かれない」）。
#   ⚠ 字の高さ（24）＋わずかな隙間。⚠ 同じ場所に重ねると読めない。
const GAIN_FLOAT_STEP: int = 28
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
#   ⚠ 種類ごとに時間をずらす。⚠ 出どころの数字は全種類ぶん縦に積む（`GAIN_FLOAT_STEP`）。
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

# ⚠ 色が決まっていない資源のときの逃げ道（⚠ 増える緑）。
#   ⚠⚠ ふつうは**資源ごとの色**（`CHIP_COLORS`）を着せる（2026-09-10・人間の指示
#   「⚠ 色も変えて。⚠ 全部緑色」）。⚠ 右上のチップと同じ色にして、⚠ どれが飛んだか分かるようにする。
const GAIN_FLYER_COLOR: String = "8ed99b"

# --- ポモドーロのタイマーの輪とセットの点（2026-09-09・人間のモック）---
#
# ⚠ 自前で `_draw()` する部品の値も**ここが持つ**。⚠ スクリプトに const で置かない。
#   ⚠ Theme に専用の型（`TimerRing` / `SetDots`）を作り、⚠ 部品は
#   ⚠ `get_theme_color()` / `get_theme_constant()` で引く。
#   ⚠ こうすれば「見た目の値を持つのは theme_builder と main_theme.tres だけ」が崩れない。
# ⚠⚠ **新しい色は1つも足していない**。⚠ 4つとも既に在る値の使い回し。
const RING_GROOVE: String = "241d1a"    # ⚠ ボタンの地と同じ。⚠ 開始前から見えている溝
const RING_FILL: String = TOKEN_BRASS      # ⚠ 真鍮。⚠ PrimaryButton の地と同じ
const RING_DIAMETER: int = 240
const RING_STROKE: int = 2
const DOT_DONE: String = "a89b94"       # ⚠ GhostButton の文字と同じ
const DOT_TODO: String = "3a302b"       # ⚠ PANEL_BORDER と同じ
const DOT_SIZE: int = 8
const DOT_CURRENT_WIDTH: int = 40
const DOT_GAP: int = 8

# --- 割り振りの段の点（2026-09-12・人間のモック「Stat node mock」）---
#
# ⚠ 20段を1行の点で出す。⚠ `SetDots` とは別の型にする（⚠ 大きさも区切りも違う）。
#   ⚠ あちらは「4セット・今のセットだけ横長」。⚠ こちらは「20段・5段ごとに区切る」。
# ⚠⚠ **新しい色は1つも足していない**。⚠ 済み＝真鍮（`RING_FILL`）／
#   ⚠ これから＝暗い点（`DOT_TODO`）。⚠ どちらも既に在る値の使い回し。
# ⚠ 5段ごとに間を空けるのは、⚠ モックがそう区切っているのと、
#   ⚠ `nodes.json` の `cost` が **6段目から 1 -> 2 に上がる**ため
#   （⚠ 「あと何段で重くなるか」が点の並びで読める）。
const TIER_DOT_SIZE: int = 6
const TIER_DOT_GAP: int = 3
const TIER_DOT_GROUP: int = 5
const TIER_DOT_GROUP_GAP: int = 8

# --- 戦闘画面（2026-09-16・人間のモック「戦闘まわり UI 決定」）---
#
# ⚠⚠ 戦闘は27画面で唯一 `Node2D` を使う画面。⚠ それでも**値はここが持つ**
#   （⚠ `TimerRing` / `SetDots` と同じ形。⚠ `battle_controller.gd` に const を置かない）。
# ⚠ Node2D は `get_theme_*()` を持たない。⚠ 引くのは**子の Control から**
#   （⚠ `$Body.get_theme_constant(&"width", &"BattleUnitView")`）。
# ⚠ ユニットの横位置だけは**戦闘中に動く**（`unit.x += dir * speed * delta`）。
#   ⚠ ここが持つのは**並び始めの位置**であって、⚠ 毎フレームの位置ではない。

# ⚠ 画面の3段（モック §1）。⚠ ヘッダー40 ／ 戦場（可変）／ 下部パネル。
# ⚠⚠ 下部パネルは 66 → 102（2026-09-16・人間の指示「アイコンはエリアいっぱい使いたい
#   ⚠ 今は小さすぎる」→「スキルのマスそのもの」）。⚠ 余白12×2 ＋ 名前の行 ＋ 間6 ＋ マス56。
const BATTLE_HEADER_HEIGHT: int = 40
const BATTLE_SIDE_MARGIN: int = 32
const BATTLE_PANEL_HEIGHT: int = 102
const BATTLE_PANEL_PAD: int = 12
# ⚠ 戦場の地。⚠ 他の画面より一段暗い（⚠ 画面の地 `BACKGROUND_BG` は 16110f）。
const BATTLE_FIELD_BG: String = TOKEN_FLOOR  # ⚠ 2026-09-26（回UI-4）手本の地へ（前 0f0c0b）
# ⚠ 段どうし・パネルどうしの区切りの線の太さ。
# ⚠⚠ 陣営を分ける**中央の縦線は消した**（2026-09-16・人間「中央の線を消して」）。
#   ⚠ 陣営は位置とHPバーの色（味方は3段・敵は赤1色）で示す。
const BATTLE_LINE_WIDTH: int = 1
# ⚠ 画面の中央からユニットの中心までの距離。⚠ 味方は左、敵は右に同じだけ離す。
const BATTLE_CENTER_GAP: int = 50
# ⚠ ユニットの本体の中心の高さ。⚠ 下にチャージバー（次の回）が入る余地を残してある。
const BATTLE_GROUND_Y: int = 300

# ⚠ 下部パネル（モック §6・A案「顔の直下にHPバーを密着」）。
const BATTLE_FACE_SIZE: int = 40
# ⚠⚠ モックは 46 x 40 だが、⚠ **正方形にして `CharacterAvatar` を使い回す**。
#   ⚠ 顔の部品を2つに増やさない（⚠ 絵（SDキャラ）が入るときに1箇所で差し替わる形を保つ）。
const BATTLE_FACE_BAR_HEIGHT: int = 6
const BATTLE_FACE_SHIELD_HEIGHT: int = 3
const BATTLE_FACE_GAP: int = 11
const BATTLE_PANEL_NAME_GAP: int = 6
const BATTLE_SKILL_SIZE: int = 56
const BATTLE_SKILL_GAP: int = 6
# ⚠ 戦闘不能のパネルは**消さずに残す**（⚠ 消すと他の2人の位置が動く）。
#   ⚠ Theme の定数は int しか持てないので百分率で持つ（40 = 0.4）。
const BATTLE_DEAD_PERCENT: int = 40

# ⚠ 戦場のユニット（モック §3）。
const BATTLE_UNIT_WIDTH: int = 74
const BATTLE_UNIT_BODY_HEIGHT: int = 74  # ⚠ 回UI-4：丸い駒（⚠ 幅と同じ。前 64）
const BATTLE_UNIT_CORNER: int = 37  # ⚠ 回UI-4：幅の半分＝丸（前 6）
const BATTLE_UNIT_GLYPH: int = 28
const BATTLE_UNIT_GAP: int = 10
const BATTLE_UNIT_NAME_SIZE: int = 11
const BATTLE_UNIT_NAME_GAP: int = 4
const BATTLE_UNIT_BAR_HEIGHT: int = 5
const BATTLE_UNIT_BAR_GAP: int = 4
const BATTLE_UNIT_ACTIVE_WIDTH: int = 3  # ⚠ 回UI-4：行動中は灯りの太い縁（前 1）
# ⚠ 敵の行動予告のゲージ（2026-09-18・人間「ゲージは HP の下」）。⚠ HPバーより細い。
#   ⚠ 色は既存の真鍮2段（⚠ 溜め中＝暗い側 ／ 満タン＝明るい側）。⚠ 新しい色ではない。
const BATTLE_SP_HEIGHT: int = 3
# ⚠⚠ 回UI-4（2026-09-26・手本 Battle）：⚠ 駒の縁・名前の枠・浮かぶ数字。
const BATTLE_UNIT_RING_WIDTH: int = 2
const BATTLE_RING_PARTY: String = TOKEN_BRASS
const BATTLE_RING_ENEMY: String = "8a3327"      # ⚠ 手本の red ボタンの地と同じ
const BATTLE_NAME_BOX_BG: String = TOKEN_FLOOR
const BATTLE_NAME_BOX_BORDER: String = FACILITY_BAR_RULE
const BATTLE_NAME_BOX_PAD_H: int = 6
const BATTLE_POP_WEIGHT: int = 900               # ⚠ 手本「数字は Noto Sans JP 900」
const BATTLE_POP_OUTLINE: int = 6                # ⚠ 手本「戦闘の数字には黒い太いふち」
const BATTLE_POP_OFFSET: int = -84               # ⚠ 駒の中心から数字が出る高さ（⚠ 状態アイコンの上）
const BATTLE_SP_FILL: String = ACTIVE_BORDER
const BATTLE_SP_FULL: String = SKILL_FLASH

# ⚠⚠ HPバーは**味方は緑1色・敵は赤1色**（⚠ モック §4 の3段は 2026-09-17 に人間がやめた
#   「味方のHPは残量に関係なくいつも緑」）。⚠ `BATTLE_HP_LOW` は瀕死の名前の色として残る。
#   ⚠ シールドは**HPバーの右に継ぎ足す**。⚠ 別の行にしない
#   （⚠ 2026-09-16 時点の実コードは別の行で、⚠ 剣士だけ縦位置がズレていた）。
const BATTLE_HP_HIGH: String = TOKEN_HP  # ⚠ 2026-09-26 手本へ（前 7fbf47）
const BATTLE_HP_LOW: String = "e05a4a"
const BATTLE_HP_ENEMY: String = "c4534a"
const BATTLE_SHIELD: String = "58a7ee"
const BATTLE_BAR_GROOVE: String = "2a2320"
# ⚠ HPが何割を切ったら瀕死（⚠ 名前が赤）。⚠ 百分率（Theme の定数は int）。
const BATTLE_HP_LOW_PERCENT: int = 20

# ⚠ 名前の色は3つ（モック §3-2・§4）。⚠ 通常 ／ 行動中 ／ 瀕死。
#   ⚠⚠ **新しい色は足していない**：通常は `MUTED_FONT_COLOR`、
#   ⚠ 行動中は `LABEL_FONT_COLOR`、⚠ 瀕死はHPの一番下と同値。
const BATTLE_NAME_ACTIVE: String = "f0e6df"

# ⚠ 敵とボスの本体の色。⚠ 味方は `CharacterAvatar` の色表をそのまま使う
#   （⚠ 育成・スキル設定と同じ顔色になる。⚠ 戦闘だけ別の色にしない）。
const BATTLE_BODY_ENEMY_BG: String = "4a2a26"
const BATTLE_BODY_ENEMY_FG: String = "ecbcbc"
const BATTLE_BODY_BOSS_BG: String = "4a2a3a"
const BATTLE_BODY_BOSS_FG: String = "ecbcd4"

# --- 戦闘のスキルのマス（2026-09-16・人間のモック §7・§8・§10）---
#
# ⚠⚠ 3種が同じ大きさのマスに同居する（⚠ 38 → 56・2026-09-16・人間「小さすぎる」）。⚠ **動きの向きで区別する**（⚠ 色は補助）。
#   ⚠ 通常CD＝面が下から明るくなる ／ ⚠ チャージ＝枠が青→琥珀 ／ ⚠ recast＝面が上から減る。
# ⚠ 大きさは `BattleHud` の `skill_size`（⚠ ここに2つ目を持たない）。
# ⚠ `toggle` は**作っていない**（⚠ 実データ0件・実行時に動かない。⚠ 決定は台帳 §0-UI-F）。
const SKILL_CORNER: int = 10
# ⚠ 線画はマスの何%か。⚠ マスの大きさを変えても絵が一緒に大きくなるよう割合で持つ。
const SKILL_ICON_PERCENT: int = 64
const SKILL_BORDER: int = 1
const SKILL_BORDER_STRONG: int = 2
const SKILL_NUMBER_SIZE: int = 20
const SKILL_CORNER_NUMBER_SIZE: int = 13
const SKILL_MARK_SIZE: int = 13
# ⚠ 秒は Theme の定数が int しか持てないのでミリ秒で持つ。
const SKILL_FLASH_MS: int = 600
const SKILL_PULSE_MS: int = 200
# ⚠ 残り何秒を切ったら数字を琥珀にするか（モック §8「残り2秒の予告」）。
const SKILL_WARN_MS: int = 2000
# ⚠ クールダウンの幕の濃さ（百分率。⚠ モックは rgba(0,0,0,.55)）。
const SKILL_VEIL_PERCENT: int = 55
# ⚠ 右上の数字・右下の目印を角から離す距離。
const SKILL_CORNER_PAD: int = 4
# ⚠ 通常CDの段の境（⚠ 残りの割合の百分率・大きい順）。
const SKILL_CD_EDGES: Array[int] = [75, 50, 25]

# ⚠ 通常CDは残りで5段、⚠ 地・枠・絵の色が一緒に明るくなる（モック §8 の表）。
#   ⚠ 段0＝100–75% ／ 1＝75–50% ／ 2＝50–25% ／ 3＝25%–残り2秒 ／ 4＝残り2秒未満。
const SKILL_CD_STAGES: Array[Dictionary] = [
	{"bg": "1a1614", "border": "2a2320", "icon": "4a423d"},
	{"bg": "1c1715", "border": "2a2320", "icon": "5a4f49"},
	{"bg": "1f1a17", "border": "332b27", "icon": "6e625c"},
	{"bg": "221c19", "border": "3d332e", "icon": "8a7d76"},
	{"bg": "241d1a", "border": "4a3d36", "icon": "c2b4ac"},
]
const SKILL_CD_NUMBER: String = "e0d5ce"
const SKILL_CD_NUMBER_NEAR: String = "efe6e0"
const SKILL_CD_NUMBER_WARN: String = "efc775"
# ⚠ 待機（撃てる）。
const SKILL_READY_BG: String = "241d1a"
const SKILL_READY_BORDER: String = "4a3d36"
const SKILL_READY_ICON: String = "e0d5ce"
# ⚠ 明けた瞬間だけ光る枠（モック §8「復帰の演出」）。
const SKILL_FLASH: String = "f0c04a"
# ⚠ 右下のキーの名前（2026-09-17）。⚠ 既定の控えめな字の色（`MUTED_FONT_COLOR`）と同値。
const SKILL_KEY: String = "a89b94"
# ⚠⚠ ホバー・押下の見た目（2026-09-18・人間「案の通りでよい」）。⚠ モックには無い。
#   ⚠ ホバー＝枠を1段明るく（⚠ 既定ボタンのホバーの枠と同値）。⚠ 押下＝面を暗い幕で沈める（百分率）。
#   ⚠ 撃てないマス（クールダウン中・戦闘不能）には出さない。
const SKILL_HOVER_BORDER: String = "6b5a4e"
const SKILL_PRESS_PERCENT: int = 25
# ⚠ ホバーで出す説明の枠（2026-09-18・人間「ホバーするとスキルの説明が見えるように」）。
#   ⚠ 幅と内側の余白だけ。⚠ 面と字は既存の variation を使い回す。
const SKILL_TIP_WIDTH: int = 280
const SKILL_TIP_PAD: int = 12
# ⚠ マスと枠のすきま。⚠ 0 にすると枠がマスに接する。
const SKILL_TIP_GAP: int = 8
# ⚠ 押せない（戦闘不能・戦闘の外）。⚠ モック §6 の戦闘不能と同じ値。
const SKILL_OFF_BG: String = "1c1715"
const SKILL_OFF_BORDER: String = "2a2320"
const SKILL_OFF_ICON: String = "3f3835"
# ⚠ チャージ（モック §9-7）。⚠ 溜めている間は枠 2px、⚠ ジャストの窓の中は琥珀。
const SKILL_CHARGE_BORDER: String = "58a7ee"
const SKILL_CHARGE_JUST: String = "f0c04a"
# ⚠ recast（モック §10）。⚠ 待機中から枠 2px の青緑。⚠ 段が進んだ瞬間だけ明るく。
const SKILL_RECAST_BG: String = "16231f"
const SKILL_RECAST_BORDER: String = "3f9c7a"
const SKILL_RECAST_ICON: String = "7fd9b4"
const SKILL_RECAST_LAYER_PERCENT: int = 18
const SKILL_RECAST_PULSE_BG: String = "1d2a23"
const SKILL_RECAST_PULSE_BORDER: String = "6fd4ae"
const SKILL_RECAST_PULSE_ICON: String = "a8ecd0"
const SKILL_RECAST_PULSE_LAYER_PERCENT: int = 40

# --- 戦闘の中央のチャージバー（2026-09-17・人間のモック §9・人間「中央にチャージバーを」）---
#
# ⚠⚠ 進み具合は**ここだけ**に出す（モック §9-1）。⚠ マスとユニットには出さない。
# ⚠ 行は**編成順で位置を固定**（⚠ 溜めていない行も高さを確保する。⚠ 目押し中にバーが動くと事故）。
# ⚠⚠ バーの右端＝**ジャストの窓の終わり**（`just_sec + just_window_sec`）。⚠ 窓は末尾の帯になる。
#   ⚠ モックの「末尾15%」は決め打ちではなく、⚠ スキルの `charge` の数字から毎回決まる。
const CHARGE_WIDTH: int = 440
const CHARGE_ROW_GAP: int = 5
const CHARGE_ICON: int = 24
# ⚠⚠ スキル名は**バーの上**に出す（2026-09-17・人間「バーにスキル名を書いて」→「バーの上に名前を出す」）。
#   ⚠ モックの「左に幅64の名前の欄」はやめた。⚠ 字はボタンと同じ段（14）。
const CHARGE_NAME_SIZE: int = BUTTON_FONT_SIZE
const CHARGE_NAME_GAP: int = 2
const CHARGE_TRACK_HEIGHT: int = 10
const CHARGE_ROW_INNER_GAP: int = 8
# ⚠ 画面の上からの位置（⚠ ユニットの足元 `BATTLE_GROUND_Y` の下）。
const CHARGE_TOP: int = 400
# ⚠ 暗い青 → 明るい青に変わる進み具合（百分率）。
const CHARGE_MID_PERCENT: int = 50
const CHARGE_TRACK_BG: String = "181514"
const CHARGE_TRACK_BORDER: String = "2a2320"
const CHARGE_BAND_IDLE: String = "332c1e"      # ⚠ 待機中から薄く見えている帯（どこで離すか事前に分かる）
const CHARGE_FILL_LOW: String = "2f6ba8"
const CHARGE_FILL_MID: String = "58a7ee"
const CHARGE_FILL_BAND: String = "f0c04a"
const CHARGE_BORDER_BAND: String = "6b5a3a"
const CHARGE_NAME_BAND: String = "f0c04a"
# ⚠⚠ 満タン（＝ジャストちょうど）を過ぎてから窓の終わりまでの塗り（2026-09-18・モック §9-5）。
#   ⚠ 帯の琥珀より1段明るい。⚠ 「いま離すのが一番良い」瞬間を色で言う。
#   ⚠ 離したときに出す「JUST!」の字も同じ色（⚠ 色を2つに増やさない）。
const CHARGE_FILL_FULL: String = "ffdb7a"
# ⚠ 「JUST!」をバーの位置に出す時間（ミリ秒）と字の大きさ（⚠ 既存の段＝浮かぶ数字と同じ 24）。
const CHARGE_JUST_MS: int = 400
const CHARGE_JUST_SIZE: int = GAIN_FLOAT_FONT
# ⚠ 帯に入っているあいだ、⚠ その行の顔に付く枠（モック §9-7）。⚠ 色は帯の琥珀と同値。
const CHARGE_FACE_BORDER: int = 2
const CHARGE_FILL_OVER: String = "c4534a"
const CHARGE_BORDER_OVER: String = "8f4a42"
const CHARGE_NAME_OVER: String = "c4877f"

# --- 状態異常のチップ（2026-09-17・人間の決定・`StatusChip` 型）---
#
# ⚠⚠ **地の色＋白字の2色で決める**（人間「ツートンで決める」）。
#   ⚠ バフ＝青地 ／ デバフ＝赤地 ／ 特殊＝固有の色（⚠ いまは復活だけ＝黄）。
#   ⚠ シールドだけの状態はチップを出さない（人間「シールドは見たらわかる」＝HPバーの右に継ぎ足してある）。
#   ⚠ 反撃（react）・反射・無効はバフ（人間「反撃、反射もバフでいい」）。
# ⚠ どれに当たるかを決めるのは `StatusChips.tone_of()` の1本。
# ⚠⚠ **新しい色は足していない**：⚠ 青＝シールドの色（`BATTLE_SHIELD`）／ ⚠ 赤＝敵のHP（`BATTLE_HP_ENEMY`）／
#   ⚠ 黄＝琥珀（`SKILL_FLASH`）。⚠ 前は `AdventureConfig` が3色（赤・緑・青）を持っていた。
const STATUS_CHIP_BUFF: String = TOKEN_BUFF  # ⚠⚠ 2026-09-26 `BT-3` を覆した（前 58a7ee）
const STATUS_CHIP_DEBUFF: String = TOKEN_DEBUFF  # ⚠ 同（前 c4534a）
const STATUS_CHIP_REVIVE: String = TOKEN_REVIVE  # ⚠ 同（前 f0c04a）
const STATUS_CHIP_TEXT: String = "ffffff"

# --- 窓の縁と題の帯（2026-09-17 に戦闘の結果窓で作り、⚠ 2026-09-18 に全部のモーダルへ広げた）---
#
# ⚠⚠ 使う先は2つ：⚠ 戦闘の結果窓（`BattleResultView`）と ⚠ 全部のモーダル（`ModalDialog`）。
#   ⚠ 人間の決定・2026-09-18「全部のモーダルに付ける」。⚠ 窓の作りを2つに分けない。
# ⚠ 暗幕はモックの rgba(0,0,0,.55)。⚠ 0.55 × 255 ＝ 140 ＝ 8c。
const RESULT_DIM: String = "0000008c"
const RESULT_WIDTH: int = 460
const WINDOW_BG: String = "1f1a18"
# ⚠ 枠はボタンの既定の枠・チップの枠と同値（`CHIP_BORDER` はこの下で定義）。⚠ 新しい色ではない。
const WINDOW_BORDER: String = "4a3d36"
const WINDOW_CORNER: int = 10
const WINDOW_TITLE_HEIGHT: int = 36
# ⚠ 題の帯の地はバーの溝と同値（`BATTLE_BAR_GROOVE`）、⚠ 下辺の線は真鍮（`RING_FILL`）。
const WINDOW_TITLE_BG: String = BATTLE_BAR_GROOVE
const WINDOW_TITLE_RULE: String = RING_FILL
const WINDOW_TITLE_RULE_WIDTH: int = 2

# ⚠⚠ 窓の幅は3段階の固定（2026-09-21・決定 `MD-3`。⚠ 人間の裁き「3はA」）。
#   ⚠ 中身に合わせて伸ばすと `scenario=layout` で測る値が毎回変わって検査にならない。
#   ⚠ 小＝文だけ ／ 中＝マス目つき ／ 大＝行が多いもの。
# ⚠⚠ 極小（2026-09-21・人間の裁き「⚠ 詳細ウィンドウが小さいからそれに合わせて」）。
#   ⚠ 倉庫の詳細パネルと同じ 300。⚠ 品を捨てる確認はその隣に出るので、⚠ 大きいと浮く。
#   ⚠ `MD-3` を3段階から4段階に広げた。
const WINDOW_WIDTH_TINY: int = 300
const WINDOW_WIDTH_SMALL: int = 400
const WINDOW_WIDTH_MEDIUM: int = 560
const WINDOW_WIDTH_LARGE: int = 720
# ⚠ 本文がこれより高くなったら、⚠ **本文の中だけ**スクロールする（決定 `MD-9`）。
#   ⚠ 帯とボタンの行は動かない。⚠ 6行ぶん。
const WINDOW_MESSAGE_MAX_HEIGHT: int = 132
# ⚠⚠ 暗幕の濃さ3通り（決定 `MD-6`・人間「⚠ ないパターンも作る」）。⚠ 単位は %。
#   ⚠ **0 でも後ろは押せない**（⚠ 受け止めるのは `Blocker`。⚠ 暗幕は見た目だけ）。
const WINDOW_DIM_NONE_PCT: int = 0
const WINDOW_DIM_NORMAL_PCT: int = 60
const WINDOW_DIM_HEAVY_PCT: int = 72
# ⚠ 窓が続けて出るとき、⚠ 閉じてから次を出すまでの間（ミリ秒・決定 `MD-8`）。
#   ⚠ 0 にすると「中身だけ差し替わった」ように見えて、⚠ 次の知らせに気づかない。
const WINDOW_QUEUE_GAP_MS: int = 150
# ⚠⚠ 見出しはモックの 22px を**既存の段 24 に丸めた**（⚠ 文字の大きさは6段で増やさない）。
#   ⚠ 24 は「浮かぶ数字」と同じ段（`GAIN_FLOAT_FONT`）。⚠ 色は琥珀（`AccentLabel` と同値）。
const RESULT_HEADING_SIZE: int = GAIN_FLOAT_FONT
const RESULT_HEADING_COLOR: String = "f0c04a"
# ⚠ 負けの見出しは減の色（`ERROR_FONT_COLOR`）。⚠ 赤を2色にしない。
const RESULT_HEADING_DEFEAT_COLOR: String = ERROR_FONT_COLOR
# ⚠ 窓の中の余白と、⚠ まとまりどうしの間。
const RESULT_PAD: int = 16
const RESULT_GAP: int = 12
# ⚠ 見出しと副題の間（⚠ 2つで1まとまりに見せる）。
const RESULT_HEADING_GAP: int = 2
# ⚠ 獲得のマスは1行6マス（モック §12）。⚠ 7件目から次の行（人間の決定）。
const RESULT_GRID_COLUMNS: int = 6

# --- 面（PanelContainer）---

const PANEL_BG: String = TOKEN_BOARD  # ⚠ 2026-09-26 手本の「板」へ（前 241d1a）
const PANEL_BORDER: String = "3a302b"
const PANEL_CORNER_RADIUS: int = 8
# ⚠⚠ カード・行・沈めた欄・選択中の4つ（2026-09-11・人間のモック「ギルド／育成」）。
#   ⚠ **新しい色は1つも足していない**。⚠ 地は既定の面（241d1a）か入力欄の地（1e1815）、
#   ⚠ 枠は既定の面の枠か真鍮。⚠ 角丸もモックは 8 / 9 / 10 を使い分けていたが、
#   ⚠ **既定の 8 に丸めた**（⚠ 1〜2px の差で値を3つ持つ意味が無い）。
const CARD_PAD_H: int = 22          # ⚠ ギルドの入口カード
const CARD_PAD_V: int = 20
const ROW_PAD_H: int = 16           # ⚠ 一覧の行（育成のキャラ・スキルの候補）
const ROW_PAD_V: int = 11
# ⚠⚠ 詰めた行（2026-09-11・人間の指示「⚠ ステータスと右のメニューは、半分ぐらいの大きさに」）。
#   ⚠ 縦の余白を半分にし、⚠ 中の字も小さい段（`SMALL_FONT_SIZE`）にして、
#   ⚠ 1行の高さをおおよそ半分にする。⚠ 使う先は**10軸の行と右のメニューだけ**
#   （⚠ 一覧の行は顔が入るので詰めない）。
const ROW_PAD_V_COMPACT: int = 5
const CARD_PAD_V_COMPACT: int = 8
const INSET_BG: String = "1e1815"   # ⚠ 沈めた欄（素材バー・コスト行）。⚠ 入力欄の地と同値
# ⚠ 絵を入れる枠（⚠ スキルの枠と候補の左）。⚠ モックの 40 / 34 を1つに寄せた。
#   ⚠ 中の線画は器の半分（⚠ アイテムのマス 40px に線画 20px と同じ割合）。
const ICON_WELL_SIZE: int = 36
const ICON_WELL_ICON: int = 18
# ⚠ 選択中・注目（琥珀）。⚠ 地は真鍮の暗い側、⚠ 枠は PrimaryButton の地と同値。
const ACTIVE_BG: String = "221a14"
const ACTIVE_BORDER: String = TOKEN_BRASS  # ⚠ 2026-09-26 手本へ（前 a8791f）
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

# ⚠⚠ 通貨（金・ジェム・スタミナ）だけ別扱い（2026-09-09・人間の決定
#   「⚠ 参考画像のはみ出す形は**通貨3つだけ**」）。⚠ 素材16件は上の小さいままにする。
#   ⚠ 参考画像は通貨2つだけを大きく見せていた。⚠ 重要度の差を見た目に出す。
# ⚠⚠ **枠の外へはみ出す重なりは作っていない**。⚠ Godot の器は子を枠の中に収めるため、
#   ⚠ はみ出させるには器の外で座標を持つことになり、⚠ 折り返しと相性が悪い。
#   ⚠ 代わりに「⚠ カプセルの左端いっぱいに丸を置く」形にした。
# ⚠⚠ 2026-09-09 に 20 -> 14（人間の指示「大きすぎる ／ 倉庫のアイテムのアイコンと
#   ⚠ 同じような大きさにしてほしい」）。⚠ 実寸を取って合わせた：
#   ⚠ 倉庫のアイテムは **マス 40px ／ 中の線画 20px**（`icon_config.gd` の
#   ⚠ `icon_size_px` と `glyph_font_size`）＝**線画は器の 50%** で、⚠ 周りに余白がある。
#   ⚠ 20px のままだと、⚠ 高さ約30px のカプセルに丸がほぼ密着し、⚠ 同じ 20px でも詰まって見える。
#   ⚠ 左の余白も 2 -> 6 に戻して、⚠ 丸の周りに余白を作る。
const CURRENCY_CHIP_PAD_L: int = 6
const CURRENCY_CHIP_ICON: int = 14

# ⚠⚠ チップの絵の色（2026-09-09・人間の指示「⚠ 折り返しても分かりやすいよう色もつけといて」）。
#   ⚠ 線画は白1色なので、⚠ ここで着せる（`modulate`）。⚠ 19個が同じ白だと見分けが付かない。
# ⚠⚠ **新しい色は1つも足していない**。⚠ 7つとも既にプロジェクトに在る値の使い回し。
#   ⚠ 素材の4系統は `icon_config.tres` の装飾の枠の4色と同じ値にしてある
#   （⚠ あちらが「4系統を色で分ける」ために選んだ色なので、⚠ 揃えたほうが覚えやすい）。
# ⚠ 名前は `ResourceBar` が引くキー。⚠ 通貨はIDそのもの、⚠ 素材は
#   `IconTextures.MATERIAL_SERIES` の値（⚠ 系統の綴りをここに書き起こさない）。
const CHIP_COLORS: Dictionary = {
	"gold": TOKEN_BRASS,                 # ⚠ 真鍮（PrimaryButton の地と同値）
	"gems": "70b8c7",                   # ⚠ 宝石（part_slot_gem_color と同値）
	"stamina": "8ed99b",                # ⚠ 増える緑（GainLabel と同値）
	"material_construction": "c7ad66",  # ⚠ 木・石（part_slot_rune_color と同値）
	"material_training": "7ab885",      # ⚠ 修練（part_slot_charm_color と同値）
	"material_forging": "a89b94",       # ⚠ 鉄の灰（GhostButton の文字と同値）
	"material_decor": "a88ccc",         # ⚠ 装飾（part_slot_emblem_color と同値）
	# ⚠ ランの一時通貨（遺物片・2026-09-20）。⚠ 飛ぶアイコンの色に使う（⚠ 右上のチップには出ない）。
	#   ⚠ 新しい色は足していない（⚠ 装飾と同じ紫。⚠ 遺物＝装飾寄りの見え方）。
	"currency": "a88ccc",
}
# ⚠ チップの中の数字。⚠ 既定16より1段小さい。⚠ **新しい段は作らない**
#   （⚠ ボタンと同じ14を使い回す。⚠ 文字の大きさの段はまだ未決なので増やさない）。
# ⚠⚠ キャラの顔（2026-09-11・人間のモック「ギルド／育成」B・C）。
#   ⚠ 角丸の四角に絵文字を1つ置くだけのもの。⚠ **絵はまだ無い**（⚠ 段階13・素材待ち）。
#   ⚠ 色はモックの値をそのまま入れた。⚠ キーは `characters.json` のID。
#   ⚠ 表に無いキャラ（⚠ 検証用の3体）は `fallback` に落ちる。
# ⚠ 絵文字そのものは `Glyphs` が持つ（⚠ ここに絵文字を書かない）。
const AVATAR_COLORS: Dictionary = {
	"char_swordsman": {"bg": "4a3a6b", "fg": "d4bcec"},
	"char_archer": {"bg": "2f5a3a", "fg": "bcecc4"},
	"char_priest": {"bg": "2f4a6b", "fg": "bcd4ec"},
	"fallback": {"bg": "2a2320", "fg": "7d6f68"},
}
const AVATAR_CORNER_RADIUS: int = 8

# ⚠ レベルの進みの帯（モック B）。⚠ 溝の色はモックの `--track`。
const BAR_TRACK: String = "2e2521"
const BAR_HEIGHT: int = 5
const BAR_CORNER_RADIUS: int = 3

const CHIP_FONT_SIZE: int = BUTTON_FONT_SIZE
# ⚠ チップの中（絵と数字の間）と、⚠ チップどうしの間。⚠ 既定の横16では空きすぎる。
const CHIP_SEPARATION: int = 4
# ⚠ 画面の地。⚠ 各画面の Background は ColorRect で持っているが、
#   PanelContainer で地を敷く画面（tests/test_ui_common）はこれを使う。
const PAPER_CORNER_RADIUS: int = 3     # ⚠ 手本 `radius_paper`
const PAPER_SHADOW_SIZE: int = 8
const PAPER_SHADOW_OFFSET: int = 3
const BACKGROUND_BG: String = TOKEN_FLOOR  # ⚠ 2026-09-26 手本の「夜の床」へ（前 16110f）。⚠ 全画面の Background がこれを引く


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
	_build_stat_nodes(theme)
	_build_battle(theme)
	_build_skill_tile(theme)
	_build_charge_bar(theme)
	_build_battle_result(theme)
	_build_status_chip(theme)
	_build_map_nodes(theme)
	_build_run_hp_bar(theme)
	_build_run_map_view(theme)
	_build_paper_parts(theme)
	_build_body_font(theme)
	_build_heading_font(theme)

	var err: int = ResourceSaver.save(theme, THEME_PATH)
	if err != OK:
		push_error("[BuildTheme] 保存に失敗した: " + str(err))
		return
	_restore_uid(THEME_PATH, previous_uid)
	print("[BuildTheme] 書き込んだ -> " + THEME_PATH)
	_build_paper_theme()
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
	# ⚠ 増えたときに浮かぶ数字。⚠ 素は**白**にしておき、⚠ `modulate` で資源の色を乗せる
	#   （2026-09-10）。⚠ 緑のままだと色を乗せても掛け算で濁る。
	theme.set_type_variation(&"GainFloatLabel", &"Label")
	theme.set_font_size(&"font_size", &"GainFloatLabel", GAIN_FLOAT_FONT)
	theme.set_color(&"font_color", &"GainFloatLabel", Color.WHITE)
	# ⚠ 小さい本文（⚠ 詰めた行の名前）。⚠ 色は本文のまま、⚠ 大きさだけ小さい段。
	#   ⚠ `CaptionLabel`（沈めた説明文）と違い、⚠ これは読ませる字。
	theme.set_type_variation(&"SmallLabel", &"Label")
	theme.set_font_size(&"font_size", &"SmallLabel", SMALL_FONT_SIZE)
	# ⚠ 説明文（カードの本文・行の副題・スキルの効果文）。⚠ 本文より1段小さく1段暗い。
	theme.set_type_variation(&"CaptionLabel", &"Label")
	theme.set_font_size(&"font_size", &"CaptionLabel", SMALL_FONT_SIZE)
	theme.set_color(&"font_color", &"CaptionLabel", _html(DIM_FONT_COLOR))
	# ⚠ 小見出し（「この子の設定」「パッシブ」「検証用（リリース前に消す）」）。
	#   ⚠ 説明文よりさらに引く。⚠ 押せるものではないことを色で言う。
	theme.set_type_variation(&"SectionLabel", &"Label")
	theme.set_font_size(&"font_size", &"SectionLabel", SMALL_FONT_SIZE)
	theme.set_color(&"font_color", &"SectionLabel", _html(FAINT_FONT_COLOR))
	# ⚠ 小さい琥珀（「選んだスキルは 枠2 に入ります」「剣士が Lv13 に上げられます」）。
	#   ⚠ 色は真鍮の明るい側＝ボタンの focus と同じ値。⚠ 新しい色ではない。
	theme.set_type_variation(&"AccentLabel", &"Label")
	theme.set_font_size(&"font_size", &"AccentLabel", SMALL_FONT_SIZE)
	theme.set_color(&"font_color", &"AccentLabel", _html("f0c04a"))
	# ⚠ 小さい赤（「修練の証 60 が足りません」）。⚠ ErrorLabel の小さい版。
	#   ⚠ 色は ErrorLabel と同値。⚠ 赤を2色にしない。
	theme.set_type_variation(&"SmallErrorLabel", &"Label")
	theme.set_font_size(&"font_size", &"SmallErrorLabel", SMALL_FONT_SIZE)
	theme.set_color(&"font_color", &"SmallErrorLabel", _html(ERROR_FONT_COLOR))
	# ⚠ 仕切り線。⚠ ヘッダーの下と小見出しの横で同じものを使う。
	var rule: StyleBoxFlat = StyleBoxFlat.new()
	rule.bg_color = _html(DIVIDER_COLOR)
	rule.content_margin_top = 1.0
	theme.set_stylebox(&"separator", &"HSeparator", rule)
	theme.set_constant(&"separation", &"HSeparator", 1)


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

	# ⚠ 通貨のチップ。⚠ 左の余白をほぼ0にして、⚠ 大きめの丸を左端に置く。
	var currency: StyleBoxFlat = chip.duplicate()
	currency.content_margin_left = CURRENCY_CHIP_PAD_L
	theme.set_type_variation(&"CurrencyChip", &"PanelContainer")
	theme.set_stylebox(&"panel", &"CurrencyChip", currency)
	theme.set_constant(&"icon", &"CurrencyChip", CURRENCY_CHIP_ICON)

	# ⚠ 絵の色。⚠ `ResourceChip` に登録して、⚠ 通貨のチップからも同じ名前で引く。
	for key: String in CHIP_COLORS.keys():
		theme.set_color(StringName(key), &"ResourceChip", _html(str(CHIP_COLORS[key])))
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

	# ⚠ カード・行・沈めた欄・選択中。⚠ 4つとも既定の面から余白と色だけを変える。
	theme.set_type_variation(&"CardPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"CardPanel", _pad_panel(panel, CARD_PAD_H, CARD_PAD_V))
	theme.set_type_variation(&"ListRowPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"ListRowPanel", _pad_panel(panel, ROW_PAD_H, ROW_PAD_V))

	# ⚠ 詰めた面（10軸の枠 ／ 右のメニューの行）。⚠ 色も枠も同じ。⚠ 縦の余白だけ半分。
	theme.set_type_variation(&"CompactCardPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"CompactCardPanel", _pad_panel(panel, CARD_PAD_H, CARD_PAD_V_COMPACT))
	theme.set_type_variation(&"CompactRowPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"CompactRowPanel", _pad_panel(panel, ROW_PAD_H, ROW_PAD_V_COMPACT))

	# ⚠ 絵を入れる枠（⚠ スキルの枠・候補の左）。⚠ 面より1段沈めた地に、⚠ 1段明るい枠。
	#   ⚠ 中の絵の大きさも Theme が持つ（⚠ 器の約半分。⚠ アイテムのマスと同じ割合）。
	var well: StyleBoxFlat = panel.duplicate()
	well.bg_color = _html(INSET_BG)
	well.border_color = _html(CHIP_BORDER)
	theme.set_type_variation(&"IconWell", &"PanelContainer")
	theme.set_stylebox(&"panel", &"IconWell", well)
	theme.set_constant(&"size", &"IconWell", ICON_WELL_SIZE)
	theme.set_constant(&"icon", &"IconWell", ICON_WELL_ICON)

	var inset: StyleBoxFlat = panel.duplicate()
	inset.bg_color = _html(INSET_BG)
	theme.set_type_variation(&"InsetPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"InsetPanel", _pad_panel(inset, ROW_PAD_H, ROW_PAD_V))

	# ⚠ 選択中の枠。⚠ カードと行の両方に当たるので余白は行に合わせる
	#   （⚠ カードは中で自分の余白を持つ）。
	var active: StyleBoxFlat = panel.duplicate()
	active.bg_color = _html(ACTIVE_BG)
	active.border_color = _html(ACTIVE_BORDER)
	theme.set_type_variation(&"ActiveRowPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"ActiveRowPanel", _pad_panel(active, ROW_PAD_H, ROW_PAD_V))
	theme.set_type_variation(&"ActiveCardPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"ActiveCardPanel", _pad_panel(active, CARD_PAD_H, CARD_PAD_V))

	# ⚠ 右カラムの地（育成の詳細・スキルの右列）。⚠ 画面の地より1段明るい面。
	#   ⚠ 枠も角丸も持たない（⚠ 画面の端まで伸びる帯なので）。
	var side: StyleBoxFlat = StyleBoxFlat.new()
	side.bg_color = _html("191413")
	side.set_border_width_all(0)
	side.border_width_left = 1
	side.border_color = _html(DIVIDER_COLOR)
	theme.set_type_variation(&"SidePanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"SidePanel", side)

	# ⚠⚠ 面の上に重ねる「当たり」（2026-09-11・人間のモック「ギルド／育成」）。
	#   ⚠ モックのカードと一覧の行は**面ぜんぶが押せる**。⚠ `PanelContainer` は押せず、
	#   ⚠ `Button` は器ではないので中身を並べられない。⚠ そこで
	#   ⚠ **面の上に透明なボタンを1枚重ねる**（⚠ `PanelContainer` は子を全面に伸ばす）。
	# ⚠ 地を持たない。⚠ 手がかりは hover の枠と focus の縁だけ
	#   （⚠ 枠の色は Secondary の hover と同値。⚠ 新しい色ではない）。
	# ⚠⚠ 縁は**面の外側**に出す（2026-09-11・人間の指示「⚠ 内側に白い淵が出るが、外側に出して」）。
	#   ⚠ `expand_margin` はスタイルを器の外へはみ出させる。⚠ これが無いと縁が面の内側に
	#   ⚠ 重なって描かれ、⚠ カードの枠と二重線になって中身の上に乗る。
	#   ⚠ はみ出す量は線の太さと同じ＝⚠ 縁の内側の辺が、面の枠の外側の辺に接する。
	for state: String in BUTTON_STATES:
		var hit: StyleBoxFlat = StyleBoxFlat.new()
		hit.bg_color = Color(0, 0, 0, 0)
		var width: int = 0
		if state == "hover":
			width = HIT_BORDER_WIDTH
			hit.border_color = _html("6b5a4e")
		elif state == "focus":
			width = FOCUS_BORDER_WIDTH
			hit.border_color = _html(TOKEN_LIGHT)
		hit.set_border_width_all(width)
		hit.set_expand_margin_all(float(width))
		# ⚠ 外へ出したぶん角が大きくなるので、⚠ 角丸も同じだけ足す（⚠ 面の角と平行に走る）。
		hit.set_corner_radius_all(PANEL_CORNER_RADIUS + width)
		theme.set_stylebox(StringName(state), &"HitButton", hit)
	theme.set_type_variation(&"HitButton", &"Button")

	# ⚠ レベルの進み（2026-09-11・人間のモック B の細い帯）。
	#   ⚠ 溝はタイマーの輪と同じ考え方（⚠ 満ちる前から見えている）。
	#   ⚠ 色は2つとも既存の値（⚠ 溝＝チップの地の一段上 ／ 満ちる＝真鍮）。
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = _html(BAR_TRACK)
	track.set_corner_radius_all(BAR_CORNER_RADIUS)
	theme.set_stylebox(&"background", &"LevelBar", track)
	var fill: StyleBoxFlat = track.duplicate()
	fill.bg_color = _html(RING_FILL)
	theme.set_stylebox(&"fill", &"LevelBar", fill)
	theme.set_type_variation(&"LevelBar", &"ProgressBar")
	theme.set_constant(&"height", &"LevelBar", BAR_HEIGHT)

	# ⚠ キャラの顔。⚠ 色は `bg_<character_id>` / `fg_<character_id>` で引く。
	#   ⚠ 部品（`CharacterAvatar`）は角丸も色もここから引く＝値を持たない。
	for character_id: String in AVATAR_COLORS:
		var pair: Dictionary = AVATAR_COLORS[character_id]
		theme.set_color(StringName("bg_" + character_id), &"CharacterAvatar", _html(str(pair["bg"])))
		theme.set_color(StringName("fg_" + character_id), &"CharacterAvatar", _html(str(pair["fg"])))
	theme.set_constant(&"corner_radius", &"CharacterAvatar", AVATAR_CORNER_RADIUS)

	# ⚠ ヘッダーの下の線。⚠ `ScreenHeader` が自前で `_draw()` するのでここが値を持つ
	#   （⚠ `TimerRing` / `SetDots` と同じ置き方）。
	theme.set_color(&"rule", &"ScreenHeader", _html(DIVIDER_COLOR))

	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = _html(BACKGROUND_BG)
	theme.set_type_variation(&"BackgroundPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"BackgroundPanel", background)

	# ⚠⚠ 紙（2026-09-26・`UI-11`）。⚠ 羊皮紙の地・角丸3（`radius_paper`）・下に落ちる影。
	#   ⚠ 繊維の質感・角飾り・傾きは部品の回（回UI-2）で足す（⚠ ここは素の面だけ）。
	#   ⚠ 中の字を墨にするのは `paper_theme.tres`（⚠ 使う側が `theme` に持たせる）。
	var paper: StyleBoxFlat = StyleBoxFlat.new()
	paper.bg_color = _html(TOKEN_PAPER)
	paper.set_corner_radius_all(PAPER_CORNER_RADIUS)
	paper.shadow_color = Color(0, 0, 0, 0.45)
	paper.shadow_size = PAPER_SHADOW_SIZE
	paper.shadow_offset = Vector2(0, PAPER_SHADOW_OFFSET)
	paper.content_margin_left = CARD_PAD_H
	paper.content_margin_right = CARD_PAD_H
	paper.content_margin_top = CARD_PAD_V
	paper.content_margin_bottom = CARD_PAD_V
	theme.set_type_variation(&"PaperPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"PaperPanel", paper)


# ⚠ 入力欄。⚠ LineEdit と TextEdit で**同じ見た目**にする（⚠ 1行と複数行の違いだけ）。
#   ⚠ `focus` は枠の色をボタンの focus と揃える（⚠ 真鍮の縁）。
static func _build_inputs(theme: Theme) -> void:
	for type_name: String in ["LineEdit", "TextEdit"]:
		var name: StringName = StringName(type_name)
		theme.set_stylebox(&"normal", name, _input_style(INPUT_BORDER, 1))
		theme.set_stylebox(&"focus", name, _input_style(TOKEN_LIGHT, FOCUS_BORDER_WIDTH))
		theme.set_stylebox(&"read_only", name, _input_style(DISABLED_BORDER, 1))
		theme.set_color(&"font_color", name, _html(LABEL_FONT_COLOR))
		theme.set_color(&"font_placeholder_color", name, _html(INPUT_PLACEHOLDER))
		theme.set_color(&"caret_color", name, _html(LABEL_FONT_COLOR))
	# ⚠ 無効時の文字の色だけ、⚠ 型ごとに名前が違う（⚠ Godot 側の都合）。
	theme.set_color(&"font_uneditable_color", &"LineEdit", _html(INPUT_PLACEHOLDER))
	theme.set_color(&"font_readonly_color", &"TextEdit", _html(INPUT_PLACEHOLDER))


# ⚠ 面を複製して内側の余白だけ変える。⚠ 色と枠と角丸は元のまま
#   （⚠ 値をここで書き直すと、⚠ 面の色が2箇所に分裂する）。
static func _pad_panel(source: StyleBoxFlat, horizontal: int, vertical: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = source.duplicate()
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style


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
		"float_step": GAIN_FLOAT_STEP,
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


# ⚠ 割り振り（ステータスノード）だけが使う値（2026-09-12・人間のモック）。
static func _build_stat_nodes(theme: Theme) -> void:
	theme.set_color(&"done", &"TierDots", _html(RING_FILL))
	theme.set_color(&"todo", &"TierDots", _html(DOT_TODO))
	theme.set_constant(&"size", &"TierDots", TIER_DOT_SIZE)
	theme.set_constant(&"gap", &"TierDots", TIER_DOT_GAP)
	theme.set_constant(&"group", &"TierDots", TIER_DOT_GROUP)
	theme.set_constant(&"group_gap", &"TierDots", TIER_DOT_GROUP_GAP)

	# ⚠ 残ポイントの数字（⚠ モックは他より一回り大きい）。
	#   ⚠⚠ **文字の大きさの段は増やしていない**。⚠ 24 は「浮かぶ数字」と同じ段、
	#   ⚠ 色は `AccentLabel` と同値（f0c04a）。⚠ 用途が違うので型だけ分ける。
	theme.set_type_variation(&"PointsLabel", &"Label")
	theme.set_font_size(&"font_size", &"PointsLabel", GAIN_FLOAT_FONT)
	theme.set_color(&"font_color", &"PointsLabel", _html("f0c04a"))


# ⚠ 戦闘だけが使う値（2026-09-16・人間のモック）。
#
# ⚠ 型は2つ。⚠ `BattleHud`（画面の3段と下部パネル）と
#   ⚠ `BattleUnitView`（戦場の1体）。⚠ 混ぜないこと
#   （⚠ 下部パネルの顔とバーは 40/6/3、⚠ 戦場は 74/5 で、⚠ 同じ名前の別の値になる）。
static func _build_battle(theme: Theme) -> void:
	var hud: Dictionary = {
		"header_height": BATTLE_HEADER_HEIGHT,
		"side_margin": BATTLE_SIDE_MARGIN,
		"panel_height": BATTLE_PANEL_HEIGHT,
		"panel_pad": BATTLE_PANEL_PAD,
		"line_width": BATTLE_LINE_WIDTH,
		"center_gap": BATTLE_CENTER_GAP,
		"ground_y": BATTLE_GROUND_Y,
		"face_size": BATTLE_FACE_SIZE,
		"face_bar_height": BATTLE_FACE_BAR_HEIGHT,
		"face_shield_height": BATTLE_FACE_SHIELD_HEIGHT,
		"face_gap": BATTLE_FACE_GAP,
		"name_gap": BATTLE_PANEL_NAME_GAP,
		"skill_size": BATTLE_SKILL_SIZE,
		"skill_gap": BATTLE_SKILL_GAP,
		"dead_percent": BATTLE_DEAD_PERCENT,
	}
	for key: String in hud.keys():
		theme.set_constant(StringName(key), &"BattleHud", int(hud[key]))
	theme.set_color(&"field_bg", &"BattleHud", _html(BATTLE_FIELD_BG))
	theme.set_color(&"divider", &"BattleHud", _html(DIVIDER_COLOR))

	var unit: Dictionary = {
		"width": BATTLE_UNIT_WIDTH,
		"body_height": BATTLE_UNIT_BODY_HEIGHT,
		"corner_radius": BATTLE_UNIT_CORNER,
		"glyph": BATTLE_UNIT_GLYPH,
		"gap": BATTLE_UNIT_GAP,
		"name_size": BATTLE_UNIT_NAME_SIZE,
		"name_gap": BATTLE_UNIT_NAME_GAP,
		"bar_height": BATTLE_UNIT_BAR_HEIGHT,
		"bar_gap": BATTLE_UNIT_BAR_GAP,
		"active_width": BATTLE_UNIT_ACTIVE_WIDTH,
		"hp_low_percent": BATTLE_HP_LOW_PERCENT,
		"sp_height": BATTLE_SP_HEIGHT,
	}
	for key: String in unit.keys():
		theme.set_constant(StringName(key), &"BattleUnitView", int(unit[key]))
	theme.set_color(&"hp_high", &"BattleUnitView", _html(BATTLE_HP_HIGH))
	theme.set_color(&"hp_enemy", &"BattleUnitView", _html(BATTLE_HP_ENEMY))
	theme.set_color(&"shield", &"BattleUnitView", _html(BATTLE_SHIELD))
	theme.set_color(&"groove", &"BattleUnitView", _html(BATTLE_BAR_GROOVE))
	theme.set_color(&"name", &"BattleUnitView", _html(MUTED_FONT_COLOR))
	theme.set_color(&"name_active", &"BattleUnitView", _html(BATTLE_NAME_ACTIVE))
	theme.set_color(&"name_low", &"BattleUnitView", _html(BATTLE_HP_LOW))
	theme.set_color(&"active_border", &"BattleUnitView", _html(ACTIVE_BORDER))
	theme.set_color(&"sp_fill", &"BattleUnitView", _html(BATTLE_SP_FILL))
	theme.set_color(&"sp_full", &"BattleUnitView", _html(BATTLE_SP_FULL))
	theme.set_constant(&"ring_width", &"BattleUnitView", BATTLE_UNIT_RING_WIDTH)
	theme.set_constant(&"pop_offset", &"BattleUnitView", BATTLE_POP_OFFSET)
	theme.set_color(&"ring_party", &"BattleUnitView", _html(BATTLE_RING_PARTY))
	theme.set_color(&"ring_enemy", &"BattleUnitView", _html(BATTLE_RING_ENEMY))
	# ⚠ 行動中の縁は灯り（⚠ 前は `ACTIVE_BORDER`＝真鍮。⚠ 味方の縁と同じ色になるので分けた）。
	theme.set_color(&"active_border", &"BattleUnitView", _html(TOKEN_LIGHT))

	# ⚠ 駒の下の名前の枠（回UI-4）。
	var name_box: StyleBoxFlat = StyleBoxFlat.new()
	name_box.bg_color = _html(BATTLE_NAME_BOX_BG)
	name_box.set_border_width_all(1)
	name_box.border_color = _html(BATTLE_NAME_BOX_BORDER)
	name_box.set_corner_radius_all(2)
	name_box.content_margin_left = BATTLE_NAME_BOX_PAD_H
	name_box.content_margin_right = BATTLE_NAME_BOX_PAD_H
	theme.set_type_variation(&"BattleUnitNameLabel", &"Label")
	theme.set_stylebox(&"normal", &"BattleUnitNameLabel", name_box)

	# ⚠ 浮かぶ数字（回UI-4）。⚠ 字は `_build_body_font()` が 900 の包みを当てる。⚠ 大きさと色は `AdventureConfig`。
	theme.set_type_variation(&"BattlePopLabel", &"Label")
	theme.set_constant(&"outline_size", &"BattlePopLabel", BATTLE_POP_OUTLINE)
	theme.set_color(&"font_outline_color", &"BattlePopLabel", Color.BLACK)

	# ⚠ 下部パネルの中の間隔。⚠ 値は上の const が唯一の持ち主
	#   （⚠ `BattleHud` の定数と同じものを指す。⚠ 数字を書き写さない）。
	theme.set_type_variation(&"BattleFaceRow", &"HBoxContainer")
	theme.set_constant(&"separation", &"BattleFaceRow", BATTLE_FACE_GAP)
	theme.set_type_variation(&"BattleSkillRow", &"HBoxContainer")
	theme.set_constant(&"separation", &"BattleSkillRow", BATTLE_SKILL_GAP)
	theme.set_type_variation(&"BattleNameStack", &"VBoxContainer")
	theme.set_constant(&"separation", &"BattleNameStack", BATTLE_PANEL_NAME_GAP)

	# ⚠ 下部パネルの名前。⚠ 戦場のユニットの名前と同じ大きさ・同じ色にする。
	theme.set_type_variation(&"BattleNameLabel", &"Label")
	theme.set_font_size(&"font_size", &"BattleNameLabel", BATTLE_UNIT_NAME_SIZE)
	theme.set_color(&"font_color", &"BattleNameLabel", _html(MUTED_FONT_COLOR))

	# ⚠ 画面の左右の余白だけを持つ器（⚠ 縦は0）。⚠ ヘッダーは高さ40しかないので、
	#   ⚠ `ScreenMargin`（上下も32）を使うと中身が入らない。
	theme.set_type_variation(&"BattleSideMargin", &"MarginContainer")
	_set_margin(theme, "BattleSideMargin", BATTLE_SIDE_MARGIN, 0)
	# ⚠ 下部パネルの1枠ぶんの内側の余白（モック §6 の 12px）。
	theme.set_type_variation(&"BattlePanelMargin", &"MarginContainer")
	_set_margin(theme, "BattlePanelMargin", BATTLE_PANEL_PAD, BATTLE_PANEL_PAD)

	# ⚠ 敵とボスの本体は `CharacterAvatar` の表に足す。⚠ 味方（3体）と同じ引き方に
	#   なるので、⚠ `UnitView` 側に「味方か敵か」で色を分ける枝を持たなくてよい。
	theme.set_color(&"bg_enemy", &"CharacterAvatar", _html(BATTLE_BODY_ENEMY_BG))
	theme.set_color(&"fg_enemy", &"CharacterAvatar", _html(BATTLE_BODY_ENEMY_FG))
	theme.set_color(&"bg_boss", &"CharacterAvatar", _html(BATTLE_BODY_BOSS_BG))
	theme.set_color(&"fg_boss", &"CharacterAvatar", _html(BATTLE_BODY_BOSS_FG))


# ⚠ 戦闘のスキルのマス（`SkillTile` 型・2026-09-16）。
static func _build_skill_tile(theme: Theme) -> void:
	var t: StringName = &"SkillTile"
	var numbers: Dictionary = {
		"corner_radius": SKILL_CORNER,
		"icon_percent": SKILL_ICON_PERCENT,
		"border": SKILL_BORDER,
		"border_strong": SKILL_BORDER_STRONG,
		"number_size": SKILL_NUMBER_SIZE,
		"corner_number_size": SKILL_CORNER_NUMBER_SIZE,
		"mark_size": SKILL_MARK_SIZE,
		"flash_ms": SKILL_FLASH_MS,
		"pulse_ms": SKILL_PULSE_MS,
		"warn_ms": SKILL_WARN_MS,
		"veil_percent": SKILL_VEIL_PERCENT,
		"recast_layer_percent": SKILL_RECAST_LAYER_PERCENT,
		"recast_pulse_layer_percent": SKILL_RECAST_PULSE_LAYER_PERCENT,
		"cd_stage_count": SKILL_CD_STAGES.size(),
		"corner_pad": SKILL_CORNER_PAD,
		"press_percent": SKILL_PRESS_PERCENT,
		"tip_width": SKILL_TIP_WIDTH,
		"tip_gap": SKILL_TIP_GAP,
	}
	for key: String in numbers.keys():
		theme.set_constant(StringName(key), t, int(numbers[key]))

	for i: int in range(SKILL_CD_EDGES.size()):
		theme.set_constant(StringName("cd_edge_%d" % i), t, SKILL_CD_EDGES[i])
	for i: int in range(SKILL_CD_STAGES.size()):
		var stage: Dictionary = SKILL_CD_STAGES[i]
		for part: String in ["bg", "border", "icon"]:
			theme.set_color(StringName("cd%d_%s" % [i, part]), t, _html(str(stage[part])))

	var colors: Dictionary = {
		"cd_number": SKILL_CD_NUMBER,
		"cd_number_near": SKILL_CD_NUMBER_NEAR,
		"cd_number_warn": SKILL_CD_NUMBER_WARN,
		"ready_bg": SKILL_READY_BG,
		"ready_border": SKILL_READY_BORDER,
		"ready_icon": SKILL_READY_ICON,
		"flash": SKILL_FLASH,
		"key": SKILL_KEY,
		"hover_border": SKILL_HOVER_BORDER,
		"off_bg": SKILL_OFF_BG,
		"off_border": SKILL_OFF_BORDER,
		"off_icon": SKILL_OFF_ICON,
		"charge_border": SKILL_CHARGE_BORDER,
		"charge_just": SKILL_CHARGE_JUST,
		"recast_bg": SKILL_RECAST_BG,
		"recast_border": SKILL_RECAST_BORDER,
		"recast_icon": SKILL_RECAST_ICON,
		"recast_pulse_bg": SKILL_RECAST_PULSE_BG,
		"recast_pulse_border": SKILL_RECAST_PULSE_BORDER,
		"recast_pulse_icon": SKILL_RECAST_PULSE_ICON,
	}
	for key: String in colors.keys():
		theme.set_color(StringName(key), t, _html(str(colors[key])))

	# ⚠ ホバーで出す説明の枠の面。⚠ 色も角丸も既定の面のまま（⚠ 内側の余白だけ変える）。
	var tip: StyleBoxFlat = StyleBoxFlat.new()
	tip.bg_color = _html(PANEL_BG)
	tip.set_corner_radius_all(PANEL_CORNER_RADIUS)
	tip.set_border_width_all(1)
	tip.border_color = _html(CHIP_BORDER)
	theme.set_type_variation(&"SkillTipPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"SkillTipPanel", _pad_panel(tip, SKILL_TIP_PAD, SKILL_TIP_PAD))


# ⚠ 戦闘の中央のチャージバー（`ChargeBar` 型・2026-09-17）。
static func _build_charge_bar(theme: Theme) -> void:
	var t: StringName = &"ChargeBar"
	var numbers: Dictionary = {
		"width": CHARGE_WIDTH,
		"icon": CHARGE_ICON,
		"track_height": CHARGE_TRACK_HEIGHT,
		"top": CHARGE_TOP,
		"mid_percent": CHARGE_MID_PERCENT,
		"border": SKILL_BORDER,
		"just_ms": CHARGE_JUST_MS,
		"just_size": CHARGE_JUST_SIZE,
		"face_border": CHARGE_FACE_BORDER,
	}
	for key: String in numbers.keys():
		theme.set_constant(StringName(key), t, int(numbers[key]))
	var colors: Dictionary = {
		"track_bg": CHARGE_TRACK_BG,
		"track_border": CHARGE_TRACK_BORDER,
		"band_idle": CHARGE_BAND_IDLE,
		"fill_low": CHARGE_FILL_LOW,
		"fill_mid": CHARGE_FILL_MID,
		"fill_band": CHARGE_FILL_BAND,
		"fill_full": CHARGE_FILL_FULL,
		"border_band": CHARGE_BORDER_BAND,
		"name": MUTED_FONT_COLOR,
		"name_band": CHARGE_NAME_BAND,
		"fill_over": CHARGE_FILL_OVER,
		"border_over": CHARGE_BORDER_OVER,
		"name_over": CHARGE_NAME_OVER,
	}
	for key: String in colors.keys():
		theme.set_color(StringName(key), t, _html(str(colors[key])))
	# ⚠ 行の縦・横の間隔。⚠ 値は上の const が唯一の持ち主。
	theme.set_type_variation(&"ChargeRows", &"VBoxContainer")
	theme.set_constant(&"separation", &"ChargeRows", CHARGE_ROW_GAP)
	theme.set_type_variation(&"ChargeRow", &"HBoxContainer")
	theme.set_constant(&"separation", &"ChargeRow", CHARGE_ROW_INNER_GAP)
	theme.set_type_variation(&"ChargeNameStack", &"VBoxContainer")
	theme.set_constant(&"separation", &"ChargeNameStack", CHARGE_NAME_GAP)
	theme.set_type_variation(&"ChargeNameLabel", &"Label")
	theme.set_font_size(&"font_size", &"ChargeNameLabel", CHARGE_NAME_SIZE)
	theme.set_color(&"font_color", &"ChargeNameLabel", _html(MUTED_FONT_COLOR))


# ⚠ 状態異常のチップ（`StatusChip` 型・2026-09-17）。⚠ 部品は `status_chips.gd`。
static func _build_status_chip(theme: Theme) -> void:
	var t: StringName = &"StatusChip"
	theme.set_color(&"buff", t, _html(STATUS_CHIP_BUFF))
	theme.set_color(&"debuff", t, _html(STATUS_CHIP_DEBUFF))
	theme.set_color(&"revive", t, _html(STATUS_CHIP_REVIVE))
	theme.set_color(&"text", t, _html(STATUS_CHIP_TEXT))


# ⚠ 戦闘の結果窓（`BattleResult` 型・2026-09-17）。⚠ 部品は `battle_result_view.gd`。
static func _build_battle_result(theme: Theme) -> void:
	var t: StringName = &"BattleResult"
	theme.set_color(&"dim", t, _html(RESULT_DIM))
	theme.set_constant(&"width", t, RESULT_WIDTH)
	theme.set_constant(&"columns", t, RESULT_GRID_COLUMNS)

	# ⚠⚠ 窓の縁・題の帯・題の字は**窓の共通のもの**（⚠ 結果窓とモーダルの両方が使う）。
	#   ⚠ 高さは `Window` 型の定数（⚠ 型を1つにしておくと、⚠ 引く側が結果窓かモーダルかを知らずに済む）。
	theme.set_constant(&"title_height", &"Window", WINDOW_TITLE_HEIGHT)
	# ⚠ 窓の共通の値（2026-09-21・決定 `MD-3` / `MD-6` / `MD-8` / `MD-9`）。
	#   ⚠ 引く側（`ModalDialog` / `Modal`）に数字を書かせない。
	theme.set_constant(&"width_tiny", &"Window", WINDOW_WIDTH_TINY)
	theme.set_constant(&"width_small", &"Window", WINDOW_WIDTH_SMALL)
	theme.set_constant(&"width_medium", &"Window", WINDOW_WIDTH_MEDIUM)
	theme.set_constant(&"width_large", &"Window", WINDOW_WIDTH_LARGE)
	theme.set_constant(&"message_max_height", &"Window", WINDOW_MESSAGE_MAX_HEIGHT)
	theme.set_constant(&"dim_none_pct", &"Window", WINDOW_DIM_NONE_PCT)
	theme.set_constant(&"dim_normal_pct", &"Window", WINDOW_DIM_NORMAL_PCT)
	theme.set_constant(&"dim_heavy_pct", &"Window", WINDOW_DIM_HEAVY_PCT)
	theme.set_constant(&"queue_gap_ms", &"Window", WINDOW_QUEUE_GAP_MS)

	var window: StyleBoxFlat = StyleBoxFlat.new()
	window.bg_color = _html(WINDOW_BG)
	window.set_corner_radius_all(WINDOW_CORNER)
	window.set_border_width_all(1)
	window.border_color = _html(WINDOW_BORDER)
	theme.set_type_variation(&"WindowPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"WindowPanel", window)

	# ⚠ 題の帯。⚠ 窓の枠（1px）の内側に入るので、⚠ 上の角丸は 1 だけ小さくして窓の角に沿わせる。
	var title: StyleBoxFlat = StyleBoxFlat.new()
	title.bg_color = _html(WINDOW_TITLE_BG)
	title.corner_radius_top_left = WINDOW_CORNER - 1
	title.corner_radius_top_right = WINDOW_CORNER - 1
	title.border_width_bottom = WINDOW_TITLE_RULE_WIDTH
	title.border_color = _html(WINDOW_TITLE_RULE)
	title.content_margin_left = RESULT_PAD
	title.content_margin_right = RESULT_PAD
	theme.set_type_variation(&"WindowTitlePanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"WindowTitlePanel", title)

	# ⚠ 題の字はボタンと同じ段（14）・本文の色。
	theme.set_type_variation(&"WindowTitleLabel", &"Label")
	theme.set_font_size(&"font_size", &"WindowTitleLabel", BUTTON_FONT_SIZE)
	theme.set_color(&"font_color", &"WindowTitleLabel", _html(LABEL_FONT_COLOR))

	theme.set_type_variation(&"ResultHeadingLabel", &"Label")
	theme.set_font_size(&"font_size", &"ResultHeadingLabel", RESULT_HEADING_SIZE)
	theme.set_color(&"font_color", &"ResultHeadingLabel", _html(RESULT_HEADING_COLOR))
	theme.set_type_variation(&"ResultDefeatHeadingLabel", &"Label")
	theme.set_font_size(&"font_size", &"ResultDefeatHeadingLabel", RESULT_HEADING_SIZE)
	theme.set_color(&"font_color", &"ResultDefeatHeadingLabel", _html(RESULT_HEADING_DEFEAT_COLOR))

	theme.set_type_variation(&"ResultBodyMargin", &"MarginContainer")
	_set_margin(theme, "ResultBodyMargin", RESULT_PAD, RESULT_PAD)
	theme.set_type_variation(&"ResultStack", &"VBoxContainer")
	theme.set_constant(&"separation", &"ResultStack", RESULT_GAP)
	theme.set_type_variation(&"ResultHeadingStack", &"VBoxContainer")
	theme.set_constant(&"separation", &"ResultHeadingStack", RESULT_HEADING_GAP)


# --- ランの3人のHPバー（2026-09-20・人間の指示「⚠ きゃらのHPをバーにして見やすく」）---
#
# ⚠⚠ 「戦闘時 MAX HP」は素の MAX HP から**削れていく**。⚠ 削れたぶんが**溝として残って見える**こと
#   （⚠ 人間「⚠ 最大HPが先頭によって減ってる状態ならバーもそれに応じた見た目に」）。
#   ⚠ ＝バーの全体＝素の MAX HP ／ ⚠ 満ちている部分＝いまの戦闘時 MAX HP ／ ⚠ 残り＝削れたぶん（赤の暗い帯）。
# ⚠ 色は**新しく足していない**：⚠ 満ち＝戦闘の味方のHPの緑 ／ ⚠ 削れ＝戦闘の敵のHPの赤 ／ ⚠ 溝＝戦闘のバーの溝。
const RUN_HP_BAR_WIDTH: int = 96
const RUN_HP_BAR_HEIGHT: int = 8
const RUN_HP_BAR_CORNER: int = 3
# ⚠ 削れたぶんは「赤いが主張しない」濃さ（⚠ 敵のHPの赤をそのまま暗く敷く）。
const RUN_HP_LOST_ALPHA: float = 0.45


static func _build_run_hp_bar(theme: Theme) -> void:
	var groove: StyleBoxFlat = StyleBoxFlat.new()
	groove.bg_color = _html(BATTLE_BAR_GROOVE)
	groove.set_corner_radius_all(RUN_HP_BAR_CORNER)
	theme.set_stylebox(&"groove", &"RunHpBar", groove)
	var fill: StyleBoxFlat = groove.duplicate()
	fill.bg_color = _html(BATTLE_HP_HIGH)
	theme.set_stylebox(&"fill", &"RunHpBar", fill)
	var lost: StyleBoxFlat = groove.duplicate()
	var lost_color: Color = _html(BATTLE_HP_ENEMY)
	lost.bg_color = Color(lost_color, RUN_HP_LOST_ALPHA)
	theme.set_stylebox(&"lost", &"RunHpBar", lost)
	theme.set_constant(&"width", &"RunHpBar", RUN_HP_BAR_WIDTH)
	theme.set_constant(&"height", &"RunHpBar", RUN_HP_BAR_HEIGHT)


# --- ランのマップのたいまつの明かり（2026-09-20・人間の指示「⚠ 光の揺れは調整できるようにしてほしい」）---
#
# ⚠⚠ 揺れの値はここだけが持つ（⚠ `RunMapView` は `get_theme_constant()` で引く）。
#   ⚠ 直したら `scenario=theme` を回す（⚠ `.tres` を手で書き換えない）。
# ⚠ Theme の定数は整数しか持てないので、⚠ 割合は**百分率**・時間は**ミリ秒**で持つ。
# ⚠ 「炎の揺らぎ」であって明滅ではない（⚠ 読みづらくしない）。⚠ 揺れを止めたいときは `period_ms` を 0 に。
const MAP_LIGHT_PERIOD_MS: int = 2600        # ⚠ 1往復の長さ。⚠ 0 なら揺れない
const MAP_LIGHT_ALPHA_MIN_PCT: int = 70      # ⚠ 一番暗いときの濃さ
const MAP_LIGHT_ALPHA_MAX_PCT: int = 106     # ⚠ 一番明るいときの濃さ（⚠ 100 を超えてよい）
const MAP_LIGHT_SCALE_MIN_PCT: int = 94      # ⚠ 一番縮んだときの大きさ
const MAP_LIGHT_SCALE_MAX_PCT: int = 105     # ⚠ 一番広がったときの大きさ
const MAP_LIGHT_SWAY_PX: int = 4             # ⚠ 左右のゆれ幅
const MAP_LIGHT_SIZE_PX: int = 420           # ⚠ 光そのものの直径
const MAP_LIGHT_COLOR: String = "f0c04a"     # ⚠ 炎の色（⚠ フォーカスの金と同値）
const MAP_LIGHT_CENTER_PCT: int = 30         # ⚠ 中心の濃さ（⚠ 回UI-4：紙の上では 10 だと見えないので上げた）
const MAP_LIGHT_MID_PCT: int = 14            # ⚠ 途中の濃さ（⚠ 同・前 5）
const MAP_INK_COLORS: Dictionary = {
	"pin_reachable": TOKEN_BRASS_INK, "pin_current": TOKEN_WAX, "pin_visited": TOKEN_RULE, "pin_far": "8a7458",
	"edge_trap": TOKEN_WAX, "edge_gain": TOKEN_BRASS_INK, "edge_plain": "3b2a1c", "edge_hidden": "3b2a1c",
	"badge_trap": TOKEN_WAX, "badge_gain": TOKEN_BRASS_INK, "badge_plain": TOKEN_RULE, "badge_bg": TOKEN_PAPER_SELECTED,
	# ⚠ たいまつが届かない層を覆う暗さ。⚠ 紙の上なので黒ではなく焦げ茶（⚠ 前は 060408・60% / 88%）。
	"fog": "3a2c22",
	# ⚠ 09-26：通った道・通ったマスのチェック・今いるマスの点線の輪（⚠ 参考画像の赤）。
	"edge_walked": TOKEN_WAX,
	"mark": TOKEN_WAX,
}
# ⚠ 09-26（人間の参考画像）：⚠ 暗い霧は無く、⚠ 見えていない所は薄く（⚠ 前 35 / 60）。
# ⚠ 09-26（2回目）：⚠ 紙が横いっぱいになったら霧の四角が浮いた＝⚠ **霧は描かない**（⚠ しくみは残す。見えていないマスは「?」）。
const MAP_FOG_EDGE_PCT: int = 0
const MAP_FOG_TOP_PCT: int = 0
const MAP_SHEET_PAD: int = 24                 # ⚠ 地図の矩形から紙の縁まで
const MAP_NODE_SIZE: int = 40                 # ⚠ 丸いマスの直径（09-26）
const MAP_NODE_SIZE_BOSS: int = 54
const MAP_NODE_ICON: int = 22                 # ⚠ 丸の中の絵の最大幅
const MAP_MARK_WIDTH: int = 2
# ⚠ 09-26（人間の参考 HTML）：⚠ 点線の道は焦げ茶 `#3b2a1c` を 75% ／ ⚠ たいまつが届かないマスと道は 40%（⚠ 人間「⚠ そうでない場合は半透明に」）。
const MAP_EDGE_ALPHA_PCT: int = 75
const MAP_FAR_ALPHA_PCT: int = 40
const MAP_DECOR_INK: String = "3b2a1c"        # ⚠ 参考 HTML の線の色
const MAP_RIVER: String = "4d6a82"            # ⚠ 参考 HTML の川の色
const MAP_DECOR_AREA: int = 9000              # ⚠ 飾りの候補を何 px² に1つ撒くか（⚠ マスに近いものは描かない）
const MAP_RIVER_EVERY: int = 800              # ⚠ 地図の縦何 px ごとに川を1本
const MAP_DECOR_CLEARANCE: int = 46           # ⚠ マスの中心から飾りまでの最小の距離
const MAP_NODE_JITTER: int = 18               # ⚠ マスを列の真ん中から左右にずらす最大（⚠ 人間「⚠ ばらけさせる」）
const MAP_NODE_JITTER_Y: int = 3
const MAP_COMPASS_RADIUS: int = 26
const MAP_COMPASS_INSET: int = 64


static func _build_run_map_view(theme: Theme) -> void:
	var t: StringName = &"RunMapView"
	var numbers: Dictionary = {
		"light_period_ms": MAP_LIGHT_PERIOD_MS,
		"light_alpha_min_pct": MAP_LIGHT_ALPHA_MIN_PCT,
		"light_alpha_max_pct": MAP_LIGHT_ALPHA_MAX_PCT,
		"light_scale_min_pct": MAP_LIGHT_SCALE_MIN_PCT,
		"light_scale_max_pct": MAP_LIGHT_SCALE_MAX_PCT,
		"light_sway_px": MAP_LIGHT_SWAY_PX,
		"light_size_px": MAP_LIGHT_SIZE_PX,
		"light_center_pct": MAP_LIGHT_CENTER_PCT,
		"light_mid_pct": MAP_LIGHT_MID_PCT,
	}
	for key: String in numbers.keys():
		theme.set_constant(StringName(key), t, int(numbers[key]))
	theme.set_color(&"light", t, _html(MAP_LIGHT_COLOR))
	# ⚠⚠ 2026-09-26（回UI-4 マップ）：⚠ `run_map_view.gd` に直書きしていた14色をここへ移し、⚠ 紙の上の墨の色にした。
	for key: String in MAP_INK_COLORS:
		theme.set_color(StringName(key), t, _html(str(MAP_INK_COLORS[key])))
	theme.set_constant(&"fog_edge_pct", t, MAP_FOG_EDGE_PCT)
	theme.set_constant(&"fog_top_pct", t, MAP_FOG_TOP_PCT)
	theme.set_constant(&"sheet_pad", t, MAP_SHEET_PAD)
	theme.set_constant(&"node_size", t, MAP_NODE_SIZE)
	theme.set_constant(&"node_size_boss", t, MAP_NODE_SIZE_BOSS)
	theme.set_constant(&"mark_width", t, MAP_MARK_WIDTH)
	theme.set_constant(&"edge_alpha_pct", t, MAP_EDGE_ALPHA_PCT)
	theme.set_constant(&"far_alpha_pct", t, MAP_FAR_ALPHA_PCT)
	# ⚠ 地図の飾り（09-26）。⚠ 山・草＝焦げ茶の半透明 ／ 川＝青灰（⚠ 人間の参考 HTML の色）。
	theme.set_color(&"decor", t, Color(_html(MAP_DECOR_INK), 0.4))
	theme.set_color(&"river", t, Color(_html(MAP_RIVER), 0.45))
	theme.set_constant(&"decor_area", t, MAP_DECOR_AREA)
	theme.set_constant(&"river_every", t, MAP_RIVER_EVERY)
	theme.set_constant(&"decor_clearance", t, MAP_DECOR_CLEARANCE)
	theme.set_constant(&"node_jitter", t, MAP_NODE_JITTER)
	theme.set_constant(&"node_jitter_y", t, MAP_NODE_JITTER_Y)


# --- ランのマップのマス（2026-09-19・難ダンジョンのモック v2「真鍮の札」）---
#
# ⚠ ボタンの5階層（BUTTON_LEVELS）には入れない（⚠ 階層は5つのまま＝人間の決定）。
#   ⚠ 使うのは `RunMapView` のマスだけ（⚠ 素の Button に variation を当てる）。
# ⚠ 札の形は八角（⚠ 角を斜めに切る＝`corner_detail = 1`）。⚠ 状態ごとに枠と地と字の色が違う。
# ⚠ 押せるのは「進める先」だけ。⚠ ほかの状態は無効（disabled）で出るので、⚠ 無効の箱にその状態の見た目を入れる。
const MAP_NODE_CORNER: int = 30   # ⚠ 回UI-4：丸みの強い札 ／ ⚠ 09-26 参考画像：丸いマス（⚠ 大きさの半分以上＝丸になる。前 18）
# ⚠ 09-26：丸いマスの中の絵が小さく潰れたので余白を詰めた（⚠ 前 13 / 8）。
const MAP_NODE_PAD_H: float = 8.0
const MAP_NODE_PAD_V: float = 8.0
const MAP_NODE_FONT_SIZE: int = 13
const MAP_NODE_BORDER: int = 2
# 吹き出しの内側の余白と影（モック `.pop`：padding 10・影 18px の黒 .6）。
const SLOT_POPOVER_PAD: int = 10
const SLOT_POPOVER_SHADOW: int = 9
const MAP_NODE_LEVELS: Dictionary = {
	# 進める先。⚠ ホバーで金の枠（モック `.node.can:hover`）。
	# ⚠⚠ 2026-09-26（回UI-4 マップ）：⚠ 札は**羊皮紙の上**に乗る（⚠ 地図が紙になった）。⚠ 墨の縁と字。
	"MapNodeButton": {
		"normal": {"bg": TOKEN_PAPER_SELECTED, "border": TOKEN_INK},
		"hover": {"bg": TOKEN_PAPER_SELECTED, "border": TOKEN_BRASS_INK},
		"pressed": {"bg": TOKEN_PAPER, "border": TOKEN_BRASS_INK},
		"font": TOKEN_INK,
	},
	# いま立っているマス。⚠ 真鍮の枠・暗い琥珀の地・金の字。
	"MapNodeCurrent": {"normal": {"bg": "f3dfa6", "border": TOKEN_WAX}, "font": TOKEN_INK},
	# 通ったマス。⚠ 鋲が沈む＝枠も字も暗い。
	"MapNodeVisited": {"normal": {"bg": TOKEN_PAPER, "border": TOKEN_RULE}, "font": "8a7458"},
	# 見えているが、⚠ いまは進めないマス（モック `.node.dim`）。
	"MapNodeFar": {"normal": {"bg": TOKEN_PAPER, "border": "8a7458"}, "font": TOKEN_INK_SUB},
	# たいまつが届いていないマス。⚠ 静かにする（⚠ 25層並べたときの騒がしさ対策）。
	# ⚠ 09-26：たいまつが届かないマス＝縁も字も紙に溶けるくらい薄く（⚠ 地は不透明＝後ろの道を隠す）。
	"MapNodeHidden": {"normal": {"bg": TOKEN_PAPER, "border": "d9c9a6"}, "font": TOKEN_RULE},
}


static func _build_map_nodes(theme: Theme) -> void:
	for type_name: String in MAP_NODE_LEVELS:
		var level: Dictionary = MAP_NODE_LEVELS[type_name]
		theme.set_type_variation(StringName(type_name), &"Button")
		var normal: Dictionary = level["normal"]
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			var spec: Dictionary = level.get(state, normal)
			theme.set_stylebox(StringName(state), StringName(type_name), _map_node_style(spec))
		# ⚠ フォーカスの金の枠は出さない（⚠ 押したマスへすぐ移るので要らない＝地だけ透明の箱）。
		theme.set_stylebox(&"focus", StringName(type_name), StyleBoxEmpty.new())
		var font: Color = _html(str(level["font"]))
		for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
			theme.set_color(StringName(key), StringName(type_name), font)
		# ⚠ 09-26：⚠ 丸いマスの絵も字と同じ色（⚠ 線画は白1色なので Theme で着せる）。
		for key: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_disabled_color"]:
			theme.set_color(StringName(key), StringName(type_name), font)
		theme.set_constant(&"icon_max_width", StringName(type_name), MAP_NODE_ICON)
		theme.set_font_size(&"font_size", StringName(type_name), MAP_NODE_FONT_SIZE)

	# ⚠ 押したマスの近くに出す「できること」の吹き出し（2026-09-19・モック v2 `.pop`）。
	#   ⚠ 面はホバーの説明の枠（SkillTipPanel）と同じ値（⚠ 色を足さない）。⚠ 内側の余白だけ 10。
	var pop: StyleBoxFlat = StyleBoxFlat.new()
	pop.bg_color = _html(PANEL_BG)
	pop.set_corner_radius_all(PANEL_CORNER_RADIUS)
	pop.set_border_width_all(1)
	pop.border_color = _html(CHIP_BORDER)
	pop.shadow_color = Color(0, 0, 0, 0.6)
	pop.shadow_size = SLOT_POPOVER_SHADOW
	theme.set_type_variation(&"SlotPopoverPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"SlotPopoverPanel", _pad_panel(pop, SLOT_POPOVER_PAD, SLOT_POPOVER_PAD))


static func _map_node_style(spec: Dictionary) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.content_margin_left = MAP_NODE_PAD_H
	style.content_margin_right = MAP_NODE_PAD_H
	style.content_margin_top = MAP_NODE_PAD_V
	style.content_margin_bottom = MAP_NODE_PAD_V
	style.set_corner_radius_all(MAP_NODE_CORNER)
	# ⚠ 角を丸めずに斜めに切る（⚠ 1 ＝角1つを直線1本で描く＝八角の札）。
	style.bg_color = _html(str(spec["bg"]))
	style.set_border_width_all(MAP_NODE_BORDER)
	style.border_color = _html(str(spec["border"]))
	return style


# --- ⚠⚠ 本文の太さ（2026-09-26・回UI-2 で見つけた）---
#
# ⚠⚠ `NotoSansJP-VariableFont_wght.ttf` は**既定の太さが 100（Thin）**（⚠ `fvar` の既定値を読んだ）。
#   ⚠ 素のまま `default_font` にしていたので、⚠ **ゲームの字はずっと一番細い太さで出ていた**。
#   ⚠ 手本の本文は 400〜500（`ui_tokens.json` `fonts.body`）。⚠ 包み（`FontVariation`）で 400 を指定する。
const BODY_FONT_PATH: String = "res://assets/fonts/NotoSansJP-VariableFont_wght.ttf"
const BODY_FONT_WEIGHT: int = 400


static func _build_body_font(theme: Theme) -> void:
	var file: Font = load(BODY_FONT_PATH) as Font
	if file == null:
		push_warning("[BuildTheme] 本文のフォントを読めない: " + BODY_FONT_PATH)
		return
	# ⚠ 既に包んであっても中身は同じファイル。⚠ 毎回作り直す（⚠ 包みの二重包みを作らない）。
	var fallbacks: Array[Font] = []
	if theme.default_font != null:
		fallbacks = theme.default_font.fallbacks
	var body: FontVariation = FontVariation.new()
	body.base_font = file
	body.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): BODY_FONT_WEIGHT}
	body.fallbacks = fallbacks
	theme.default_font = body
	# ⚠ 回UI-4：戦闘の浮かぶ数字は 900（⚠ 同じファイルを太さ違いで包むだけ）。
	var number: FontVariation = body.duplicate() as FontVariation
	number.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): BATTLE_POP_WEIGHT}
	theme.set_font(&"font", &"BattlePopLabel", number)


# --- ⚠⚠ 見出しの明朝（2026-09-26・決定 `UI-12`）---
#
# ⚠ Shippori Mincho B1 の **ExtraBold 1本だけ**（⚠ 手本は 700〜800。⚠ 1本 15MB なので Bold は入れない）。
# ⚠ 明朝に無い字は NotoSansJP（`default_font`）に落ちる（⚠ `FontVariation` のフォールバック）。
#   ⚠ `.ttf` の中身を書き換えず、⚠ テーマの中に包みを1つ持つ（⚠ 生成物なので毎回作り直す）。
# ⚠ 数字と本文は NotoSansJP のまま（⚠ 手本「数字は明朝にしない」）。
const HEADING_FONT_PATH: String = "res://assets/fonts/ShipporiMinchoB1-ExtraBold.ttf"
const HEADING_FONT_TYPES: Array[String] = [
	"HeadingLabel", "WindowTitleLabel", "ResultHeadingLabel", "ResultDefeatHeadingLabel",
	# ⚠ 回UI-2：判の字も明朝（⚠ 手本の判は明朝）。
	"Stamp",
]
const SHEET_HEADING_SPACING: int = 3


# --- ⚠⚠ 紙の部品（2026-09-26・回UI-2）---
#
# ⚠ 絵（画像）を使わず、⚠ 面と線だけで作る（⚠ 質感の画像は素材待ち）。
# ⚠ 部品は値を持たない。⚠ 色・寸法はここから `get_theme_*` で引く（`UI-8` と同じ置き方）。
const PAPER_CORNER_SIZE: int = 16       # ⚠ 手本 `corner_ornament`
const PAPER_CORNER_WIDTH: int = 2
const PAPER_CORNER_INSET: int = 8       # ⚠ 紙の縁から角飾りまで
const PAPER_CHOSEN_BORDER: int = 2
# ⚠ 手本 `paper_tilt_deg` は -1.2〜1.4。⚠ 並びの番号で順に使う（⚠ `RelicCard.TILT_COUNT` と同じ数）。
const PAPER_TILTS_TENTHS: Array[int] = [-12, 5, 14]
const PAPER_CHOICE_CORNER: int = 22
const SHEET_HEADING_SIZE: int = 20
const SHEET_HEADING_RULE: int = 2       # ⚠ 太い下線
const SHEET_HEADING_GAP: int = 6        # ⚠ 字と下線の間
const SHEET_ORNAMENT_DIAMOND: int = 5   # ⚠ 菱形の半径
const PAPER_TAB_PAD_H: int = 22
const PAPER_TAB_PAD_V_OPEN: int = 13    # ⚠ 字14 の行 約20 ＋ 13 × 2 ＝ 手本の 46
const PAPER_TAB_PAD_V_CLOSED: int = 9   # ⚠ 同 ＝ 手本の 38
const PAPER_TAB_CORNER: int = 6
const PAPER_TAB_GAP: int = 4
const LEDGER_ROW_PAD_V: int = 10
const LEDGER_SELECTED_LINE: int = 3     # ⚠ 選んでいる行の左の線
const LEDGER_DASH: int = 3              # ⚠ 点線の罫の1片と間
const LEDGER_DISABLED_ALPHA_PCT: int = 45
const STAMP_FONT_SIZE: int = 16
const STAMP_BORDER: int = 2
const STAMP_PAD_H: int = 10
const STAMP_PAD_V: int = 4
const STAMP_TILT_DEG: int = -8
const FACILITY_BAR_HEIGHT: int = 76     # ⚠ 手本 `facility_bar`
const RELIC_LIST_WIDTH: int = 960       # ⚠ カード3枚が横に並ぶ幅
const RELIC_LIST_COLUMNS: int = 3
const RELIC_LIST_GAP: int = 24
const TORN_PAD_H: int = 28
const TORN_PAD_V: int = 20
const TORN_STEP: int = 18                # ⚠ ちぎれ目の細かさ（⚠ 何 px ごとに凹ませるか）
const TORN_DEPTH: int = 6                # ⚠ ちぎれ目の深さ
const MAP_LEGEND_ICON: int = 16
const HEADER_TITLE_SIZE: int = 22
const HEADER_DIAMOND: int = 4           # ⚠ 題の左右の◆の半径
const HEADER_DIAMOND_GAP: int = 10      # ⚠ 題の端から◆の中心まで
const FACILITY_ACTIVE_LINE: int = 3
const FACILITY_RIBBON_W: int = 12
const FACILITY_RIBBON_H: int = 24
const FACILITY_RIBBON_INSET: int = 18
const FACILITY_BAR_RULE: String = "3a2c22"
const FACILITY_HOVER_BG: String = "2f241c"
const FACILITY_ACTIVE_BG: String = "2c2119"


static func _build_paper_parts(theme: Theme) -> void:
	# 紙の角飾り（`PaperSheet` が `_draw()` で引く）。
	theme.set_color(&"corner", &"PaperPanel", _html(TOKEN_BRASS_INK))
	theme.set_constant(&"corner_size", &"PaperPanel", PAPER_CORNER_SIZE)
	theme.set_constant(&"corner_width", &"PaperPanel", PAPER_CORNER_WIDTH)
	theme.set_constant(&"corner_inset", &"PaperPanel", PAPER_CORNER_INSET)
	# ⚠ 紙の傾き（回UI-4 レリック・人間「⚠ もっとカードっぽく傾けて」）。⚠ 単位は 0.1 度（⚠ Theme の定数は int）。
	for i: int in PAPER_TILTS_TENTHS.size():
		theme.set_constant(StringName("tilt_%d" % i), &"PaperPanel", PAPER_TILTS_TENTHS[i])

	# ⚠ 選んだ紙（回UI-4 レリック）。⚠ 明るい紙 ＋ 真鍮の墨の縁（⚠ 台帳の「選んでいる行」と同じ2色）。
	var chosen: StyleBoxFlat = (theme.get_stylebox(&"panel", &"PaperPanel") as StyleBoxFlat).duplicate()
	chosen.bg_color = _html(TOKEN_PAPER_SELECTED)
	chosen.set_border_width_all(PAPER_CHOSEN_BORDER)
	chosen.border_color = _html(TOKEN_BRASS_INK)
	theme.set_type_variation(&"PaperPanelChosen", &"PanelContainer")
	theme.set_stylebox(&"panel", &"PaperPanelChosen", chosen)

	# ⚠ 紙の上で1つを選ぶ札（回UI-4 レリックの「付ける人」）。⚠ 丸い札・墨の縁。⚠ 選んだものは明るい紙＋真鍮の墨。
	#   ⚠ Ghost は紙の上だと字が明るすぎて読めないので、⚠ 紙の上の選択にはこちらを使う。
	for spec: Dictionary in [
		{"name": "PaperChoice", "bg": "", "border": TOKEN_INK_SUB, "width": 1},
		{"name": "PaperChoiceSelected", "bg": TOKEN_PAPER_SELECTED, "border": TOKEN_BRASS_INK, "width": 2},
	]:
		var type_name: StringName = StringName(str(spec["name"]))
		theme.set_type_variation(type_name, &"Button")
		for state: String in BUTTON_STATES:
			var pill: StyleBoxFlat = StyleBoxFlat.new()
			var bg: String = str(spec["bg"])
			if state == "hover":
				bg = TOKEN_PAPER_SELECTED
			pill.bg_color = Color(0, 0, 0, 0) if (bg == "" or state == "focus") else _html(bg)
			pill.set_corner_radius_all(PAPER_CHOICE_CORNER)
			pill.content_margin_left = PAPER_TAB_PAD_H
			pill.content_margin_right = PAPER_TAB_PAD_H
			pill.content_margin_top = BUTTON_PAD_V
			pill.content_margin_bottom = BUTTON_PAD_V
			if state == "focus":
				pill.set_border_width_all(FOCUS_BORDER_WIDTH)
				pill.border_color = _html(TOKEN_LIGHT)
			else:
				pill.set_border_width_all(int(spec["width"]))
				pill.border_color = _html(TOKEN_RULE if state == "disabled" else str(spec["border"]))
			theme.set_stylebox(StringName(state), type_name, pill)
		for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			theme.set_color(StringName(color_name), type_name, _html(TOKEN_INK))
		theme.set_color(&"font_disabled_color", type_name, _html(TOKEN_RULE))
		theme.set_font_size(&"font_size", type_name, BUTTON_FONT_SIZE)

	# 紙の見出し（明朝・太い下線・菱形の飾り罫）。⚠ 字の色は紙のテーマ側（`PAPER_LABEL_COLORS`）。
	theme.set_type_variation(&"SheetHeadingLabel", &"Label")
	theme.set_font_size(&"font_size", &"SheetHeadingLabel", SHEET_HEADING_SIZE)
	theme.set_type_variation(&"SheetHeading", &"VBoxContainer")
	theme.set_constant(&"separation", &"SheetHeading", 0)
	theme.set_color(&"rule", &"SheetHeading", _html(TOKEN_INK))
	theme.set_color(&"ornament", &"SheetHeading", _html(TOKEN_BRASS_INK))
	theme.set_constant(&"rule_width", &"SheetHeading", SHEET_HEADING_RULE)
	theme.set_constant(&"gap", &"SheetHeading", SHEET_HEADING_GAP)
	theme.set_constant(&"diamond", &"SheetHeading", SHEET_ORNAMENT_DIAMOND)

	# 紙のタブ（⚠ 暗い地の上に出るので、⚠ 字の色はここで持つ）。
	for spec: Dictionary in [
		{"name": "PaperTabOpen", "bg": TOKEN_PAPER, "font": TOKEN_INK, "pad": PAPER_TAB_PAD_V_OPEN},
		{"name": "PaperTabClosed", "bg": TOKEN_RULE, "font": TOKEN_INK_SUB, "pad": PAPER_TAB_PAD_V_CLOSED},
	]:
		var type_name: StringName = StringName(str(spec["name"]))
		theme.set_type_variation(type_name, &"Button")
		for state: String in BUTTON_STATES:
			var tab: StyleBoxFlat = StyleBoxFlat.new()
			tab.bg_color = Color(0, 0, 0, 0) if state == "focus" else _html(str(spec["bg"]))
			if state == "hover" and spec["name"] == "PaperTabClosed":
				tab.bg_color = _html(TOKEN_PAPER)
			if state == "focus":
				tab.set_border_width_all(FOCUS_BORDER_WIDTH)
				tab.border_color = _html(TOKEN_LIGHT)
			tab.corner_radius_top_left = PAPER_TAB_CORNER
			tab.corner_radius_top_right = PAPER_TAB_CORNER
			tab.content_margin_left = PAPER_TAB_PAD_H
			tab.content_margin_right = PAPER_TAB_PAD_H
			tab.content_margin_top = int(spec["pad"])
			tab.content_margin_bottom = int(spec["pad"])
			theme.set_stylebox(StringName(state), type_name, tab)
		for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			theme.set_color(StringName(color_name), type_name, _html(str(spec["font"])))
		theme.set_font_size(&"font_size", type_name, BUTTON_FONT_SIZE)

	# ⚠ タブの並び（⚠ タブどうしの間）と、⚠ 「タブ → 紙」を隙間なく重ねる縦の器。
	theme.set_type_variation(&"PaperTabRow", &"HBoxContainer")
	theme.set_constant(&"separation", &"PaperTabRow", PAPER_TAB_GAP)
	theme.set_type_variation(&"PaperTabStack", &"VBoxContainer")
	theme.set_constant(&"separation", &"PaperTabStack", 0)

	# 台帳の行（⚠ 暗い箱で囲まない。⚠ 区切りは点線の罫）。
	var row: StyleBoxFlat = StyleBoxFlat.new()
	row.bg_color = Color(0, 0, 0, 0)
	row.content_margin_left = ROW_PAD_H
	row.content_margin_right = ROW_PAD_H
	row.content_margin_top = LEDGER_ROW_PAD_V
	row.content_margin_bottom = LEDGER_ROW_PAD_V
	theme.set_type_variation(&"LedgerRowPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"LedgerRowPanel", row)
	var selected: StyleBoxFlat = row.duplicate()
	selected.bg_color = _html(TOKEN_PAPER_SELECTED)
	selected.border_width_left = LEDGER_SELECTED_LINE
	selected.border_color = _html(TOKEN_BRASS_INK)
	theme.set_type_variation(&"LedgerRowSelectedPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"LedgerRowSelectedPanel", selected)
	theme.set_color(&"rule", &"LedgerRow", _html(TOKEN_RULE))
	theme.set_constant(&"dash", &"LedgerRow", LEDGER_DASH)
	theme.set_constant(&"disabled_alpha_pct", &"LedgerRow", LEDGER_DISABLED_ALPHA_PCT)

	# 判（⚠ 状態を紙に押す。⚠ 通知ではない）。
	theme.set_color(&"ink", &"Stamp", _html(TOKEN_WAX))
	theme.set_font_size(&"font_size", &"Stamp", STAMP_FONT_SIZE)
	theme.set_constant(&"border", &"Stamp", STAMP_BORDER)
	theme.set_constant(&"pad_h", &"Stamp", STAMP_PAD_H)
	theme.set_constant(&"pad_v", &"Stamp", STAMP_PAD_V)
	theme.set_constant(&"tilt_deg", &"Stamp", STAMP_TILT_DEG)

	# 見出しの帯の題（回UI-3）。⚠ 明朝・字間を広く・⚠ 左右に灯りの◆（`ScreenHeader` が描く）。
	theme.set_type_variation(&"HeaderTitleLabel", &"Label")
	theme.set_font_size(&"font_size", &"HeaderTitleLabel", HEADER_TITLE_SIZE)
	theme.set_color(&"font_color", &"HeaderTitleLabel", _html(TOKEN_TEXT_ON_DARK))
	theme.set_color(&"diamond", &"ScreenHeader", _html(TOKEN_LIGHT))
	theme.set_constant(&"diamond", &"ScreenHeader", HEADER_DIAMOND)
	theme.set_constant(&"diamond_gap", &"ScreenHeader", HEADER_DIAMOND_GAP)

	# ⚠ 縁がちぎれた羊皮紙（09-26・人間の参考画像・`TornPaperPanel`）。⚠ 面は自分で描くので StyleBox は余白だけ。
	var torn: StyleBoxEmpty = StyleBoxEmpty.new()
	torn.content_margin_left = TORN_PAD_H
	torn.content_margin_right = TORN_PAD_H
	torn.content_margin_top = TORN_PAD_V
	torn.content_margin_bottom = TORN_PAD_V
	theme.set_type_variation(&"TornPaperPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"TornPaperPanel", torn)
	theme.set_constant(&"tear_step", &"TornPaper", TORN_STEP)
	theme.set_constant(&"tear_depth", &"TornPaper", TORN_DEPTH)
	theme.set_constant(&"shadow_offset", &"TornPaper", PAPER_SHADOW_OFFSET)
	theme.set_color(&"shadow", &"TornPaper", Color(0, 0, 0, 0.45))
	theme.set_color(&"burn", &"TornPaper", Color(_html(TOKEN_INK_SUB), 0.35))
	# ⚠ 方位（09-26・人間「⚠ 山とかそういうのも今は書いといて」）。
	theme.set_color(&"compass", &"TornPaper", Color(_html(MAP_DECOR_INK), 0.55))
	theme.set_constant(&"compass_radius", &"TornPaper", MAP_COMPASS_RADIUS)
	theme.set_constant(&"compass_inset", &"TornPaper", MAP_COMPASS_INSET)
	theme.set_constant(&"compass_font", &"TornPaper", SMALL_FONT_SIZE)
	# ⚠ 地図の凡例「しるし」（`MapLegend`）。
	theme.set_constant(&"icon", &"MapLegend", MAP_LEGEND_ICON)
	theme.set_color(&"icon", &"MapLegend", _html(TOKEN_INK))

	# ランの右上のメニューの板（回UI-4・`RunMenuButton`）。⚠ 板の面・影つき（⚠ 装飾の吹き出しと同じ作り）。
	var menu: StyleBoxFlat = StyleBoxFlat.new()
	menu.bg_color = _html(TOKEN_BOARD)
	menu.set_border_width_all(1)
	menu.border_color = _html(FACILITY_BAR_RULE)
	menu.set_corner_radius_all(PANEL_CORNER_RADIUS)
	menu.shadow_color = Color(0, 0, 0, 0.6)
	menu.shadow_size = SLOT_POPOVER_SHADOW
	theme.set_stylebox(&"panel", &"PopupPanel", _pad_panel(menu, SLOT_POPOVER_PAD, SLOT_POPOVER_PAD))

	# 持っているレリックをまとめて見る窓（`RunRelicListWindow`）。⚠ 暗幕は窓の既定（`MD-6` の 60%）。
	theme.set_color(&"dim", &"RunRelicList", Color(0, 0, 0, float(WINDOW_DIM_NORMAL_PCT) / 100.0))
	theme.set_constant(&"width", &"RunRelicList", RELIC_LIST_WIDTH)
	theme.set_constant(&"columns", &"RunRelicList", RELIC_LIST_COLUMNS)
	theme.set_type_variation(&"RelicListGrid", &"GridContainer")
	theme.set_constant(&"h_separation", &"RelicListGrid", RELIC_LIST_GAP)
	theme.set_constant(&"v_separation", &"RelicListGrid", RELIC_LIST_GAP)

	# 施設の帯（⚠ 下に固定・⚠ 用事がある施設にしおり紐）。
	var bar: StyleBoxFlat = StyleBoxFlat.new()
	bar.bg_color = _html(TOKEN_BOARD)
	bar.border_width_top = 1
	bar.border_color = _html(FACILITY_BAR_RULE)
	theme.set_type_variation(&"FacilityBarPanel", &"PanelContainer")
	theme.set_stylebox(&"panel", &"FacilityBarPanel", bar)
	theme.set_constant(&"height", &"FacilityBar", FACILITY_BAR_HEIGHT)
	theme.set_type_variation(&"FacilityRow", &"HBoxContainer")
	theme.set_constant(&"separation", &"FacilityRow", 0)
	theme.set_color(&"ribbon", &"FacilityBar", _html(TOKEN_WAX))
	theme.set_constant(&"ribbon_w", &"FacilityBar", FACILITY_RIBBON_W)
	theme.set_constant(&"ribbon_h", &"FacilityBar", FACILITY_RIBBON_H)
	theme.set_constant(&"ribbon_inset", &"FacilityBar", FACILITY_RIBBON_INSET)
	for spec: Dictionary in [
		{"name": "FacilityButton", "bg": "", "hover": FACILITY_HOVER_BG, "font": TOKEN_TEXT_DIM_ON_DARK, "line": false},
		{"name": "FacilityButtonActive", "bg": FACILITY_ACTIVE_BG, "hover": FACILITY_ACTIVE_BG, "font": TOKEN_TEXT_ON_DARK, "line": true},
	]:
		var type_name: StringName = StringName(str(spec["name"]))
		theme.set_type_variation(type_name, &"Button")
		for state: String in BUTTON_STATES:
			var cell: StyleBoxFlat = StyleBoxFlat.new()
			var bg: String = str(spec["hover"]) if state == "hover" else str(spec["bg"])
			cell.bg_color = Color(0, 0, 0, 0) if (bg == "" or state == "focus") else _html(bg)
			if state == "focus":
				cell.set_border_width_all(FOCUS_BORDER_WIDTH)
				cell.border_color = _html(TOKEN_LIGHT)
			elif bool(spec["line"]):
				cell.border_width_top = FACILITY_ACTIVE_LINE
				cell.border_color = _html(TOKEN_LIGHT)
			theme.set_stylebox(StringName(state), type_name, cell)
		theme.set_color(&"font_color", type_name, _html(str(spec["font"])))
		theme.set_color(&"font_hover_color", type_name, _html(TOKEN_TEXT_ON_DARK))
		theme.set_color(&"font_pressed_color", type_name, _html(TOKEN_TEXT_ON_DARK))
		theme.set_color(&"font_focus_color", type_name, _html(str(spec["font"])))
		theme.set_font_size(&"font_size", type_name, BUTTON_FONT_SIZE)


static func _build_heading_font(theme: Theme) -> void:
	if not ResourceLoader.exists(HEADING_FONT_PATH):
		push_warning("[BuildTheme] 見出しの明朝が無い（%s）。見出しは NotoSansJP のまま" % HEADING_FONT_PATH)
		for type_name: String in HEADING_FONT_TYPES:
			theme.clear_font(&"font", StringName(type_name))
		theme.clear_font(&"font", &"SheetHeadingLabel")
		theme.clear_font(&"font", &"HeaderTitleLabel")
		return
	var base: Font = load(HEADING_FONT_PATH) as Font
	var heading: FontVariation = FontVariation.new()
	heading.base_font = base
	if theme.default_font != null:
		heading.fallbacks = [theme.default_font]
	for type_name: String in HEADING_FONT_TYPES:
		theme.set_font(&"font", StringName(type_name), heading)
	# ⚠ 紙の見出しは字間を広く取る（⚠ 手本「字間を広く取る」）。⚠ 包みをもう1つ持つ。
	var spaced: FontVariation = heading.duplicate() as FontVariation
	spaced.spacing_glyph = SHEET_HEADING_SPACING
	theme.set_font(&"font", &"SheetHeadingLabel", spaced)
	theme.set_font(&"font", &"HeaderTitleLabel", spaced)


# --- ⚠⚠ 紙の上のテーマ（2026-09-26・決定 `UI-14`）---
#
# ⚠ 紙の部品が `theme` にこれを持つと、⚠ 子孫は**先にこちらを引き、無ければ `main_theme.tres`** へ落ちる
#   （⚠ Godot の Theme は「祖先のテーマ → プロジェクトのテーマ」の順に探す）。
# ⚠⚠ **置くのは字の色と罫だけ**（⚠ ボタンは手本も紙の上で同じ見た目＝`main` に任せる）。
# ⚠⚠ **`PanelContainer` をここに置かないこと。** ⚠ 置くと `ListRowPanel` など `main` の
#   ⚠ 面の variation が全部これに負ける（⚠ 探す順は「テーマごと」が外側で「型ごと」が内側）。
#   ⚠ 同じ理由で、⚠ 色を持つ字の variation は**全部ここにも書く**（⚠ 書かないと素の `Label`＝墨に落ちる）。
const PAPER_LABEL_COLORS: Dictionary = {
	"Label": TOKEN_INK,
	"HeadingLabel": TOKEN_INK,
	"SheetHeadingLabel": TOKEN_INK,
	"SmallLabel": TOKEN_INK,
	"MutedLabel": TOKEN_INK_SUB,
	"CaptionLabel": TOKEN_INK_SUB,
	"SectionLabel": TOKEN_INK_SUB,
	"AccentLabel": TOKEN_BRASS_INK,
	"ErrorLabel": TOKEN_WAX,
	"SmallErrorLabel": TOKEN_WAX,
	"GainLabel": TOKEN_PAPER_GAIN,
}


static func _build_paper_theme() -> void:
	var previous_uid: int = ResourceLoader.get_resource_uid(PAPER_THEME_PATH)
	# ⚠ 毎回新しく作る（⚠ 消した項目が残らないように）。⚠ フォントは `main` に落ちるので持たない。
	var paper: Theme = Theme.new()
	for type_name: String in PAPER_LABEL_COLORS:
		if type_name != "Label":
			paper.set_type_variation(StringName(type_name), &"Label")
		paper.set_color(&"font_color", StringName(type_name), _html(str(PAPER_LABEL_COLORS[type_name])))
	var rule: StyleBoxFlat = StyleBoxFlat.new()
	rule.bg_color = _html(TOKEN_RULE)
	rule.content_margin_top = 1.0
	paper.set_stylebox(&"separator", &"HSeparator", rule)
	var err: int = ResourceSaver.save(paper, PAPER_THEME_PATH)
	if err != OK:
		push_error("[BuildTheme] 紙のテーマの保存に失敗した: " + str(err))
		return
	_restore_uid(PAPER_THEME_PATH, previous_uid)
	print("[BuildTheme] 書き込んだ -> %s（字の型 %d 個）" % [PAPER_THEME_PATH, PAPER_LABEL_COLORS.size()])


static func _html(hex: String) -> Color:
	return Color.html(hex)


# ⚠ 1行目に `uid=` を書き戻す。⚠ 元から無ければ何もしない。
# ⚠ ここだけ `.tres` を文字列として触る。⚠ 生成スクリプトの中なので許される
#   （⚠ 「`.tres` を手で書き換えない」は人間が手で開くことを指す）。
static func _restore_uid(path: String, previous_uid: int) -> void:
	if previous_uid == ResourceUID.INVALID_ID:
		return
	var text: String = FileAccess.get_file_as_string(path)
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
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("[BuildTheme] .tres を開けない。uid を書き戻せなかった")
		return
	file.store_string(fixed + text.substr(head.length()))
	file.close()
	print("[BuildTheme] uid を書き戻した: " + uid_text)
