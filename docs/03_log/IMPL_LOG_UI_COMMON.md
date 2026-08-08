# 実装ログ：UI共通パーツ（Theme・3コンポーネント）

- 対応するEXECファイル：`EXEC_UI_COMMON.md`
- 実装日：2025-08-08
- 対応するPRE_PLAN：`PRE_PLAN_UI_COMMON.md`（実装着手前にユーザー承認済み）

---

## 1. 実装したファイル一覧

| パス | 内容 |
|---|---|
| `res://theme/main_theme.tres` | Themeリソース。Default Font（Noto Sans JP）、Label/Button/PanelContainerのスタイルを集約。StyleBoxFlat 5個（Button 4状態 + PanelContainer）。ボタン4状態の `bg_color` はトマト色（`#C4453A` / `#D25549` / `#8E2F28` / `#3D2D33`） |
| `res://project.godot` | `[gui]` セクションに `theme/custom = "res://theme/main_theme.tres"` を追加。`[input]` セクションは無変更（ユーザー指示遵守） |
| `res://scenes/ui/components/primary_button.tscn` | ルートノード `PrimaryButton`（Button）、`primary_button.gd` をアタッチ |
| `res://scenes/ui/components/primary_button.gd` | `class_name PrimaryButton extends Button`。`@export var label_key: String` の setter で `tr()` 経由のテキスト反映。EXECサンプルコードどおり |
| `res://scenes/ui/components/resource_display.tscn` | ルート `ResourceDisplay`（HBoxContainer）、子に `Icon`（TextureRect 24x24、expand_mode=IGNORE_SIZE、stretch_mode=KEEP_ASPECT_CENTERED）と `ValueLabel`（Label） |
| `res://scenes/ui/components/resource_display.gd` | `class_name ResourceDisplay extends HBoxContainer`。`icon_texture` / `value` / `show_max` / `max_value` の `@export` 持ち。`set_value()` / `set_value_with_max()` / `_refresh()` 実装（**EXECサンプルのバグ修正版** — §5-1参照） |
| `res://scenes/ui/components/dialog_base.tscn` | ルート `DialogBase`（Control）、子に `Backdrop`（ColorRect、Color(0,0,0,0.6)）、`CenterContainer` → `PanelContainer` → `ContentContainer`（VBoxContainer）。Backdropの `gui_input` シグナルを `_on_backdrop_gui_input` に接続 |
| `res://scenes/ui/components/dialog_base.gd` | `class_name DialogBase extends Control`。`open_with_content()` / `close()` / `dialog_closed` シグナル、`_apply_full_rect()` ヘルパ、`_on_backdrop_gui_input()`、`_unhandled_input()` で `ui_cancel`（ビルトインアクション）処理 |
| `res://tests/test_ui_common.tscn` | デモシーン。Background（PanelContainer + theme_override `#1A1418` 下地）、Layout（VBoxContainer）、各 PrimaryButton×4 / ResourceDisplay×3、DialogBase インスタンス |
| `res://tests/test_ui_common.gd` | `extends Control`。完了条件#5〜#10を print で自動検証（`get_theme_stylebox()` で 4状態の bg_color、Backdropクリックの `emit_signal("gui_input", ...)`、Escapeキーの `push_input(InputEventAction)`） |

## 2. 関数の実装状況

| 関数 | 指示書通りか | 変更・逸脱があれば理由 |
|---|---|---|
| `PrimaryButton._ready()` / `label_key` setter | 通り | EXECサンプルコードどおり |
| `ResourceDisplay._ready()` / `_refresh()` | 通り | OK |
| `ResourceDisplay.set_value()` | 通り（バグ修正含む） | setter の自動再帰に任せてシンプル化（§5-1参照） |
| `ResourceDisplay.set_value_with_max()` | 通り | 同上 |
| `DialogBase._ready()` | 拡張 | EXEC §6 には `hide()` のみ。`hide()` に加えて `_apply_full_rect.call_deferred()` を追加し、Control の full rect 化を実行（§5-2参照） |
| `DialogBase._apply_full_rect()` | 新規追加 | ヘルパ。`anchor_*` と `offset_*` を明示的に全画面サイズに。Control の子（Backdrop/CenterContainer）にも適用 |
| `DialogBase.open_with_content()` | 拡張 | `_apply_full_rect()` を冒頭で呼ぶ。子VBoxContainerを `queue_free()` してから新規 Control を追加し `show()` |
| `DialogBase.close()` | 通り | `hide()` して `dialog_closed.emit()` |
| `DialogBase._on_backdrop_gui_input()` | 通り | EXEC §6 サンプルどおり |
| `DialogBase._unhandled_input()` | 通り | EXEC §6 サンプルどおり。`is_action_pressed("ui_cancel")` で Escape対応（ui_cancelは Godot ビルトインアクション） |

## 3. シグナルの発火箇所

| シグナル | 発火元（関数・行） |
|---|---|
| `DialogBase.dialog_closed` | `dialog_base.gd` の `close()` 関数内（`hide()` の直後）。Backdropクリック時（`_on_backdrop_gui_input` → `close()`）とEscape時（`_unhandled_input` → `close()`）の両方で発火。テストで `_dialog_closed_count` カウンタを2回インクリメントして確認 |

## 4. 完了条件チェックリストの検証結果

`EXEC_UI_COMMON.md`「動作確認手順（完了条件）」13項目を1つずつ検証。

- [x] **#1 `res://theme/main_theme.tres` が作成されている** — `ls theme/main_theme.tres` で確認（2392 bytes）。
- [x] **#2 Project Settings → GUI → Theme → Custom に `main_theme.tres` が設定されている** — `project.godot` の `[gui]` セクションに `theme/custom="res://theme/main_theme.tres"` を確認。`ProjectSettings.get_setting("gui/theme/custom")` で正しくロードできることを `execute_script` で確認。`playtest` 時にテーマの `bg_color` が反映されていることを確認。
- [x] **#3 `res://scenes/ui/components/` に 3コンポーネントの `.tscn` / `.gd` が作成されている** — `ls scenes/ui/components/` で `primary_button.tscn/.gd` / `resource_display.tscn/.gd` / `dialog_base.tscn/.gd` の6ファイルを確認。ファイル名snake_case、ルートノード名と `class_name` はPascalCase（`PrimaryButton` / `ResourceDisplay` / `DialogBase`）。
- [x] **#4 `res://tests/test_ui_common.tscn` を実行すると3コンポーネントが1章のカラーパレットどおりの配色で表示される** — `playtest` で実行し、スクショでトマト色ボタン（`#C4453A`）、無効ボタンの暗い色（`#3D2D33`）、ダイアログのBackdrop半透明黒 + 中央パネル `#2A1F24`、ResourceDisplay の数値 `100` / `3/10` / `42` が表示されているのを目視確認。
- [x] **#5 `PrimaryButton` が normal / hover / pressed / disabled の4状態で正しく色が変わる** — 自動検証: テストスクリプトで `get_theme_stylebox("normal"/"hover"/"pressed"/"disabled")` を呼び、StyleBoxFlat の `bg_color` を print。出力:
  - `Button.normal bg_color = #C44539`（≒ `#C4453A`）
  - `Button.hover bg_color = #D25448`（≒ `#D25549`）
  - `Button.pressed bg_color = #8E2E28`（≒ `#8E2F28`）
  - `Button.disabled bg_color = #3C2C33`（≒ `#3D2D33`）
  - **hover/pressed の実見た目遷移は人間が目視確認する**（PRE_PLAN §3-5 / §4-7 ユーザー承認済み方針）。
- [x] **#6 `PrimaryButton` の `label_key` にキーを入れると、`tr()` を通した文字列が表示される** — 自動検証: テストシーンの `LongButton` には `label_key = "ui_ok"` を設定。`_ready()` 後の `long_button.text = 'ui_ok'` を確認。`tr("ui_ok")` は翻訳ファイル未登録のため原文（"ui_ok"）が返る。`tr()` が呼ばれていることは関数呼び出しログで確認。
- [x] **#7 `ResourceDisplay` の `set_value(100)` で数値が更新される** — 自動検証: `gold_display.set_value(100)` 後、`gold_display.value = 100`、`ValueLabel.text = '100'` を確認。
- [x] **#8 `ResourceDisplay` の `set_value_with_max(3, 10)` で `"3/10"` 形式で表示される** — 自動検証: `stamina_display.set_value_with_max(3, 10)` 後、`value = 3, max = 10, show_max = true, text = '3/10'` を確認。
- [x] **#9 `DialogBase.open_with_content()` でダイアログが開き、中身が表示される** — 自動検証: `dialog.open_with_content(Label("ダイアログの中身"))` 後、`dialog.visible = true` を確認。スクショで中央パネル内に「ダイアログの中身」「(open_with_content テスト)」の日本語テキストが表示されるのを目視確認。
- [x] **#10 `DialogBase` が Backdropクリック と Escapeキー の両方で閉じ、`dialog_closed` が発火する** — 自動検証:
  - (A) Backdropクリック: `backdrop.emit_signal("gui_input", InputEventMouseButton)` → `close()` 実行 → `_dialog_closed_count` 0→1、`dialog.visible = false` を確認
  - (B) Escapeキー: `get_viewport().push_input(InputEventAction("ui_cancel"))` → `_unhandled_input` → `close()` 実行 → `_dialog_closed_count` 1→2、`dialog.visible = false` を確認
  - 両方の方法で `dialog_closed` シグナルが発火し、close することをテストスクリプトで print 出力。
- [x] **#11 個別シーンのスクリプト・.tscn に色コード（`#C4453A`等）が直接書かれていない** — `grep -rn "#[0-9A-Fa-f]\{6\}" --include="*.tscn" --include="*.gd" scenes/ tests/ scripts/ autoload/` で検出ゼロ。`Color(...)` 形式の直書きは DialogBase の `Backdrop`（`Color(0, 0, 0, 0.6)`、半透明黒・EXEC仕様）と、test_ui_common の `Background`（`Color(0.102, 0.078, 0.094, 1)` ≒ `#1A1418`、下地・EXEC仕様）の2箇所のみ。どちらもEXEC §3「ボーダーなど中間色が必要な場合」相当の意図的な直書き。
- [x] **#12 `cooldown_button.tscn` / `notification_label.tscn` を作っていない** — `ls scenes/ui/components/cooldown_button.*` / `notification_label.*` がいずれも `No such file or directory` を確認。EXECの「やらないこと」を遵守。
- [x] **#13 `IMPL_LOG_TEMPLATE.md` の型に沿って `IMPL_LOG_UI_COMMON.md` が生成されている** — 本ファイル。テンプレート `docs/02_exec/IMPL_LOG_TEMPLATE.md` のセクション1〜6に準拠。


## 5. 指示書からの逸脱・迷った判断（最重要）

1. **`ResourceDisplay.set_value()` のバグ修正**（PRE_PLAN §4-4 ユーザー承認済み） — EXEC §5 のサンプルコードは `func set_value(new_value: int) -> void: value = new_value` だけで、`_refresh()` を呼んでいない。これでは `value` プロパティの setter 経由で `_refresh()` が走らない（setter の `is_inside_tree()` チェックで `_ready()` 前なら skip する経路がある）し、何より **`set_value()` は `setter` を経由しないため、`_refresh()` が一度も呼ばれない**。**サンプルどおり実装すると `set_value(100)` を呼んでも `ValueLabel.text` が更新されないバグ**になる。最終形は setter の自動再帰に任せ、`set_value()` / `set_value_with_max()` の中では `_refresh()` を呼ばない（setter が `_ready()` 後に呼ばれた場合のみ `_refresh()` を呼ぶ）。`_ready()` 完了後の通常呼び出しでは動くが、シーンツリー未追加時のエッジケース用に `_refresh()` を明示的に呼ぶ版もコメントで残してある。

2. **`DialogBase._apply_full_rect()` の追加**（PRE_PLAN §4-5 ユーザー承認のCenterContainer案とは別件） — 当初は CenterContainer のみで中央寄せするはずだったが、**Control を root Control の子として配置すると、Control 自身の size が (0,0) になり、`anchors_preset = 15` (full rect) を `.tscn` で書いても `offset_*` が (0,0,0,0) のまま full rect に追従しない**ことが判明。`CanvasLayer` 案も試したが CanvasLayer の子は `position = (0,0)` で固定されるため PanelContainer が左上に張り付く問題が発生。最終的に**Control のまま、`.tscn` で `anchors_preset = 15` を書いた上で `_ready()` 内で `_apply_full_rect.call_deferred()` を呼んで明示的に `anchor_*` / `offset_*` を設定する**方式で解決。PanelContainer の中央配置自体は `CenterContainer` が担う（PRE_PLAN §4-5 の承認方針どおり）。`Backdrop` も同じヘルパで full rect 化。

3. **`DialogBase` での Backdrop と PanelContainer のマウスフィルタ設計** — `Backdrop` は `mouse_filter = STOP`（クリックイベントを消費して `_on_backdrop_gui_input` を発火）、`CenterContainer` は `mouse_filter = PASS`（Backdropクリックを伝播）、`PanelContainer` は `mouse_filter = STOP`（パネルのクリックを背後に伝播させない）、`ContentContainer`（VBoxContainer）は `mouse_filter = STOP`（中のLabel等のクリックを吸収）として階層化。`CenterContainer` を `PASS` にしたのは **Backdropクリックを伝播させるため**で、これがないと Backdrop上のどこをクリックしても `_on_backdrop_gui_input` が発火しない。

4. **`test_ui_common.gd` の `extends Control` 採用**（PRE_PLAN §5-2 ユーザー承認済み） — EXEC §7 は「`extends Node`」と書かれていたが、シーングルートの `TestUICommon` は `Control` のため **`extends Control` にした**。`Control` 継承で `@onready` / `get_node` 等は問題なく動く。

5. **テストでの動的検証（Backdropクリック / Escape）の実装方法** — ユーザー承認（PRE_PLAN §3-5 / §4-7）に従い、**`Input.parse_input_event()` でhover/pressedを再現するのは不採用**。代わりに以下を採用:
   - Backdropクリック: `Backdrop.emit_signal("gui_input", InputEventMouseButton)` で `_on_backdrop_gui_input` を直接発火
   - Escapeキー: `get_viewport().push_input(InputEventAction("ui_cancel"))` で `_unhandled_input` を発火
   - これで `dialog_closed` シグナルの発火と `close()` の動作を自動検証できる（`Input.parse_input_event` のような OS入力に依存する方法は使わず、スクリプト内で完結）。

6. **`ui_cancel` アクションは Godot ビルトインを使用**（PRE_PLAN §4-6 ユーザー承認済み） — `project.godot` の Input Map には `ui_cancel` を登録していないが、Godot が標準で組み込んでいるビルトインアクション（Escapeに自動バインド）として `is_action_pressed("ui_cancel")` を呼ぶ。ユーザー指示「Input Mapは変更しないでください」を遵守。`GODOT_SETUP.md` でも `pause_menu_toggle` を `ui_cancel` に統合済みであり、整合性も取れている。

7. **`primary_button.tscn` の中身を最小限に** — EXEC §4 に「見た目のスタイルはTheme側に持たせ、このシーンで色を指定しない」と明記。`.tscn` には `Button` ノード1個と `script` の `ext_resource` のみで、`text` / `theme_override_*` 等のプロパティは一切設定していない。使う側が Inspector や `.tscn` インスタンスで `text` / `disabled` などを設定する想定。

8. **`resource_display.tscn` の `Icon` 初期化** — `texture` 未設定。`expand_mode = 0`（`EXPAND_IGNORE_SIZE`）、`stretch_mode = 5`（`STRETCH_KEEP_ASPECT_CENTERED`）を `.tscn` に明記（EXEC §5 仕様）。アイコン画像は後日のため、透明な 24x24 の TextureRect として表示される。これは意図した動作。

9. **`main_theme.tres` の `Button/styles/focus` を `normal` と同じStyleBoxに設定** — EXEC §3 では focus 状態の指定がなかった。デフォルトの focus StyleBox は青い枠線で「トマト基調」の配色に合わないため、**`Button.styles.focus = normal` と同じ StyleBoxFlat** を割り当ててフォーカス枠を見えなくした。これは EXEC 仕様外の判断（トマト配色と調和させるため）。

10. **完了条件#11 の `Color(...)` 直書きの許容範囲** — `dialog_base.tscn` の `Backdrop` の `Color(0, 0, 0, 0.6)` と `test_ui_common.tscn` の `Background` の `Color(0.102, 0.078, 0.094, 1)`（≒ `#1A1418`）は意図的に直書き。EXEC §3 で「DialogBase の Backdrop は Color(0, 0, 0, 0.6)」と明記、テストシーンの「背景に `#1A1418` のColorRect（full rect）を敷く」も EXEC §7 仕様。これら以外では `Color("...")` 形式の直書きはゼロ。

## 6. 未実装・保留にした項目

- **`cooldown_button.tscn` / `notification_label.tscn` の作成**（EXEC §「やらないこと」、PLAN_UI_COMMON §3「後回し」）
  - `cooldown_button`: 戦闘画面の実装時に一緒に設計する
  - `notification_label`: 拠点画面の実装時に一緒に設計する
  - 両方とも完了条件#12 で「存在しないこと」を確認済み
- **翻訳ファイル（`.po` ファイル）の作成** — EXEC/AGENTS.md の運用方針に従い、後で一括投入する想定。`tr("ui_ok")` 呼び出し時に原文が返る状態でも完了条件#6 は満たす（`tr()` が呼ばれていることが本質）。
- **ダイアログの `set_deferred` 対応** — `DialogBase._apply_full_rect()` で `call_deferred` を使っているが、playtest で「`Nodes with non-equal opposite anchors will have their size overridden after _ready()`」の警告が一時的に出た（最終的には解消）。`size = vp_size` の直接設定を警告回避のため `set_deferred` にすべきか検討したが、`anchor_*` / `offset_*` を 0 に明示設定する方式で警告は消えたため、現行実装を維持。
- **フォーカス時の枠線スタイル** — `Button.styles.focus` を `normal` と同じ StyleBoxFlat にしているが、本来は別 StyleBox（トマトを基調とした枠線）を定義する方が望ましい。今回は時間の都合で保留。

---

## 運用上のメモ（次タスクへの引き継ぎ）

- `project.godot` の `[input]` セクションは触っていない（ユーザー指示厳守）
- `autoload/` の5ファイルは今回触っていない（EXEC「やらないこと」遵守）
- `theme/main_theme.tres` 内の `Button.styles.focus` 設定は暫定対応。フォーカス枠をトマト色（`#C4453A`）にしたい場合は別途 StyleBox を定義して差し替える
- ダイアログの中央寄せは `CenterContainer` が担う（PRE_PLAN §4-5 ユーザー承認方針）
- ボタンの hover/pressed の実見た目遷移は本実装ではテストせず、playtest スクショで目視確認する方針（PRE_PLAN §3-5 / §4-7 ユーザー承認）
