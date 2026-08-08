# 【実行指示書】UI共通パーツ（Theme・共通コンポーネント）

第3層・実行指示書。この指示書はAI（Ziva等）にそのまま渡して実装させることを想定している。

---

## 前提・参照ドキュメント

実装前に必ず以下を読むこと。ここに書かれていないやり方は勝手に採用しない。

- `AGENTS.md`：フォルダ構造・命名規則・UIパーツの置き場所ルール・Themeの扱い
- `PLAN_UI_COMMON.md`：この実行指示書のもとになった第2層の作戦計画書

既存の共通基盤（`GameManager`等5つのAutoload）は実装済み。**今回のタスクはそれらに依存しないため、Autoloadのコードは変更しないこと。**

---

## 今回のタスク

プロジェクト全体で使い回すThemeと、共通UIコンポーネント3つを作成する。

### やること
- `res://theme/main_theme.tres` の作成と、プロジェクト全体のデフォルトThemeへの設定
- Noto Sans JP フォントの配置とThemeへの指定
- 共通コンポーネント3つの作成（`primary_button` / `resource_display` / `dialog_base`）
- 上記3つを並べて表示確認できるデモシーンの作成（`res://tests/`配下）

### やらないこと
- `cooldown_button.tscn` / `notification_label.tscn` の作成（使う画面の実装時に一緒に設計する。`PLAN_UI_COMMON.md` 3章参照）
- 各画面（拠点・ポモドーロ・戦闘・ギルド等）のシーン実装
- Autoload（`GameManager`等）の変更
- アイコン画像の作成（`resource_display`のアイコン枠は空のままでよい）

---

## 1. カラーパレット

`PLAN_UI_COMMON.md` 2章で確定済み。**この8色以外を勝手に追加しない。**

| 用途 | カラーコード | 使いどころ |
|---|---|---|
| 背景 | `#1A1418` | 画面全体の下地 |
| パネル | `#2A1F24` | ウィンドウ・カード・ダイアログ |
| プライマリ | `#C4453A` | 主要ボタン、重要な要素 |
| プライマリ濃 | `#8E2F28` | ボタン押下時、影 |
| アクセント | `#6B8F3F` | 報酬・成功・完了 |
| テキスト | `#F0E6E0` | 通常の文字 |
| テキスト薄 | `#9A8A88` | 補足、無効状態 |
| 警告 | `#D98C3A` | 注意喚起 |

コンセプトはトマト（ダークめ）。**赤を全面に敷かず、彩度の高い赤は「押す場所」に限定する**（長時間の作業画面で目が疲れないようにするため）。

ボーダーなど中間色が必要な場合は `#3D2D33`（パネルより少し明るい）を使う。

---

## 2. フォント

- **Noto Sans JP** を使用する
- 配置先：`res://assets/fonts/`
- ライセンスは SIL Open Font License 1.1（再配布可）
- **Themeの Default Font に1箇所だけ指定する。** 個別のLabel/Buttonにフォントを設定しない

> **フォントファイルが用意できない場合**：勝手にダウンロードせず、Godotのデフォルトフォントのまま進めて、その旨をIMPL_LOGに記載すること。フォントの配置は人間が行う。

---

## 3. main_theme.tres

`res://theme/main_theme.tres` として作成する。

### 設定するもの

| 対象 | 項目 | 値 |
|---|---|---|
| Default | Font | Noto Sans JP |
| Default | Font Size | 16 |
| `Label` | `font_color` | `#F0E6E0` |
| `Button` | `font_color` | `#F0E6E0` |
| `Button` | `font_disabled_color` | `#9A8A88` |
| `Button` | `normal` / `hover` / `pressed` / `disabled` | 下記StyleBox参照 |
| `PanelContainer` | `panel` | 背景`#2A1F24`、角丸8px |

### Buttonの StyleBoxFlat

| 状態 | 背景色 | 備考 |
|---|---|---|
| normal | `#C4453A` | 角丸8px、余白は上下10px・左右20px |
| hover | `#D25549` | normalより少し明るく |
| pressed | `#8E2F28` | プライマリ濃 |
| disabled | `#3D2D33` | 文字も`#9A8A88`になる |

### プロジェクト全体への適用

Project Settings → GUI → Theme → Custom に `res://theme/main_theme.tres` を設定する。**各シーンのルートノードに個別にThemeを割り当てないこと。**

---

## 4. primary_button.tscn

`res://scenes/ui/components/primary_button.tscn`

```
PrimaryButton (Button)
```

- ルートノードは `Button`。ルートノード名は `PrimaryButton`（PascalCase）
- スクリプト：`res://scenes/ui/components/primary_button.gd`
- **見た目のスタイルはTheme側に持たせ、このシーンで色を指定しない**
- `class_name PrimaryButton` を付ける（他シーンからインスタンス化するため）

### スクリプトの内容

```gdscript
class_name PrimaryButton
extends Button

# ボタンに表示するテキスト。tr()で翻訳を通す（AGENTS.md命名規則）
@export var label_key: String = "":
	set(value):
		label_key = value
		if is_inside_tree():
			text = tr(label_key)

func _ready() -> void:
	if label_key != "":
		text = tr(label_key)
```

- `label_key` に翻訳キーを入れると、`tr()`を通した文字列が表示される
- 直接 `text` に日本語をハードコードしない（`AGENTS.md`「全てのテキストは`tr()`で囲む」）

---

## 5. resource_display.tscn

`res://scenes/ui/components/resource_display.tscn`

アイコン＋数値を横並びで表示する小さなパーツ。拠点画面下部の gold / stamina / 建築素材の表示に使う。

```
ResourceDisplay (HBoxContainer)
├─ Icon (TextureRect)
└─ ValueLabel (Label)
```

- `Icon` のサイズは 24×24。テクスチャは**未設定でよい**（アイコン画像は後日）
- `Icon` の `expand_mode` は `Ignore Size`、`stretch_mode` は `Keep Aspect Centered`
- スクリプト：`res://scenes/ui/components/resource_display.gd`

### スクリプトの内容

```gdscript
class_name ResourceDisplay
extends HBoxContainer

@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		if is_inside_tree():
			_refresh()

# 表示する数値。set_value()経由でも設定できる
@export var value: int = 0:
	set(new_value):
		value = new_value
		if is_inside_tree():
			_refresh()

# "current/max"形式で表示するか（スタミナ用）
@export var show_max: bool = false
@export var max_value: int = 0

func _ready() -> void:
	_refresh()

func set_value(new_value: int) -> void:
	value = new_value

func set_value_with_max(new_current: int, new_max: int) -> void:
	value = new_current
	max_value = new_max
	show_max = true
	_refresh()

func _refresh() -> void:
	# ノード名は SCENES.md / PLAN_BASE_SCREEN.md の階層案に合わせること
	var icon: TextureRect = $Icon
	var value_label: Label = $ValueLabel
	icon.texture = icon_texture
	if show_max:
		value_label.text = "%d/%d" % [value, max_value]
	else:
		value_label.text = str(value)
```

- 数値そのものは翻訳不要（`tr()`で囲まない）
- 拠点画面がこれを使って gold / stamina / 素材を表示する想定

---

## 6. dialog_base.tscn

`res://scenes/ui/components/dialog_base.tscn`

オーバーレイ表示の共通土台。施設別ウィンドウや確認ダイアログの下地に使う。

```
DialogBase (Control)              # full rect、mouse_filter = Stop
├─ Backdrop (ColorRect)           # 半透明の黒。full rect
└─ PanelContainer                 # 中央配置
    └─ ContentContainer (VBoxContainer)   # 中身は使う側が差し込む
```

- `Backdrop` の色は `#000000` の透明度 60%（`Color(0, 0, 0, 0.6)`）
- `PanelContainer` は画面中央に配置。サイズは中身に合わせて伸縮する
- `DialogBase` の `mouse_filter` は `Stop`（背後のUIをクリックさせないため）
- スクリプト：`res://scenes/ui/components/dialog_base.gd`

### スクリプトの内容

```gdscript
class_name DialogBase
extends Control

signal dialog_closed

func _ready() -> void:
	hide()

# 中身のノードをContentContainerに差し込んで開く
func open_with_content(content: Control) -> void:
	var container: VBoxContainer = $PanelContainer/ContentContainer
	for child: Node in container.get_children():
		child.queue_free()
	container.add_child(content)
	show()

func close() -> void:
	hide()
	dialog_closed.emit()

# Backdropをクリックしたら閉じる
func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		close()

# Escapeキーでも閉じる（GODOT_SETUP.md 3章：ui_cancelに統合済み）
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
```

- `Backdrop` の `gui_input` シグナルを `_on_backdrop_gui_input` に接続すること
- `Backdrop` の `mouse_filter` は `Stop`

---

## 7. デモシーン（表示確認用）

`res://tests/test_ui_common.tscn` / `.gd`

3つのコンポーネントを並べて、Themeが効いているか目視確認するためのシーン。

- 背景に `#1A1418` のColorRect（full rect）を敷く
- `PrimaryButton` を3つ配置（通常 / disabled / 長いラベル）
- `ResourceDisplay` を3つ配置（gold / stamina（max付き） / 建築素材）
- `DialogBase` を1つ配置し、ボタンを押すと開く／Backdropクリックとescで閉じる
- 各コンポーネントが正しく表示されることをprintでも報告する

> このシーンは検証用であり、本番画面ではない。`res://tests/`配下に隔離すること。

---

## 動作確認手順（完了条件）

以下をすべて満たしたら完了とする。

1. `res://theme/main_theme.tres` が作成されている
2. Project Settings → GUI → Theme → Custom に `main_theme.tres` が設定されている
3. `res://scenes/ui/components/` に `primary_button.tscn` / `resource_display.tscn` / `dialog_base.tscn` と、対応する `.gd` が作成されている（ファイル名はsnake_case、ルートノード名とclass_nameはPascalCase）
4. `res://tests/test_ui_common.tscn` をF6で実行すると、3つのコンポーネントが1章のカラーパレットどおりの配色で表示される
5. `PrimaryButton` が normal / hover / pressed / disabled の4状態で正しく色が変わる
6. `PrimaryButton` の `label_key` にキーを入れると、`tr()`を通した文字列が表示される
7. `ResourceDisplay` の `set_value(100)` で数値が更新される
8. `ResourceDisplay` の `set_value_with_max(3, 10)` で `"3/10"` 形式で表示される
9. `DialogBase.open_with_content()` でダイアログが開き、中身が表示される
10. `DialogBase` が Backdropクリック と Escapeキー の両方で閉じ、`dialog_closed` が発火する
11. **個別シーンのスクリプト・.tscn に色コード（`#C4453A`等）が直接書かれていない**ことをコードレビューで確認できる（Theme経由になっているか）
12. **`cooldown_button.tscn` / `notification_label.tscn` を作っていない**（今回のスコープ外）
13. `IMPL_LOG_TEMPLATE.md`の型に沿って `res://docs/03_log/IMPL_LOG_UI_COMMON.md` が生成されている

---

## 遵守事項（AGENTS.mdより再掲）

- 変数・関数・ファイル名はsnake_case、`class_name`とノード名はPascalCase、シグナルは過去形にする
- 全ての表示テキストは `tr()` で囲む（日本語ハードコード禁止）。数値のみの表示は対象外
- 色・フォントは個別シーンにハードコードせず、必ずTheme経由にする
- `scenes/ui/components/` に置くのは2画面以上で使うパーツのみ
- `res://autoload/` と `res://addons/` の既存ファイルには無断で触れない
- 新しいフォルダが必要になった場合は、勝手に作らず人間に提案してから作成する
- 同じ箇所を3回以上直す必要が出た場合は実装を止め、設計を見直す
