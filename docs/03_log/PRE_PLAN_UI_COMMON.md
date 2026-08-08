# PRE_PLAN：UI共通パーツ（Theme・3コンポーネント）

対応するEXEC：`EXEC_UI_COMMON.md`
本ファイルは実装着手前の計画レビュー用。実装完了後は `IMPL_LOG_UI_COMMON.md` を別途生成する。

---

## 1. 作成するファイル一覧（パスと役割）

### テーマ・フォント
| パス | 役割 |
|---|---|
| `res://theme/main_theme.tres` | プロジェクト全体のデフォルトTheme。配色8色・Noto Sans JP・Label/Button/PanelContainerのスタイルを集約。Project Settings → GUI → Theme → Custom に登録 |
| `res://assets/fonts/NotoSansJP-VariableFont_wght.ttf` | **既存**（人間配置済み）。ThemeのDefault Fontから参照する |

> フォントは既に `res://assets/fonts/` に配置済みを確認（`.ttf` と `.import` 両方あり）。「フォントを用意できない場合はデフォルトで進める」分岐は不要。

### 共通コンポーネント（`res://scenes/ui/components/`）
| パス | 役割 |
|---|---|
| `res://scenes/ui/components/primary_button.tscn` | `PrimaryButton`（Button）。全画面の確定・遷移ボタン。スタイルはTheme経由 |
| `res://scenes/ui/components/primary_button.gd` | `class_name PrimaryButton extends Button`。`@export var label_key: String` で`tr()`経由のテキスト設定 |
| `res://scenes/ui/components/resource_display.tscn` | `ResourceDisplay`（HBoxContainer）。アイコン＋数値の横並び。gold/stamina/素材表示 |
| `res://scenes/ui/components/resource_display.gd` | `class_name ResourceDisplay extends HBoxContainer`。`value`/`max_value`/`show_max` で`current/max`切替 |
| `res://scenes/ui/components/dialog_base.tscn` | `DialogBase`（Control）。Backdrop＋中央PanelContainerのオーバーレイ土台 |
| `res://scenes/ui/components/dialog_base.gd` | `class_name DialogBase extends Control`。`open_with_content()` / `close()` / `dialog_closed` シグナル。BackdropクリックとEscape(ui_cancel)で閉じる |

### デモシーン（`res://tests/`）
| パス | 役割 |
|---|---|
| `res://tests/test_ui_common.tscn` | 3コンポーネントを並べて表示確認する検証用シーン。`#1A1418` のColorRect下地＋PrimaryButton×3 / ResourceDisplay×3 / DialogBase×1 |
| `res://tests/test_ui_common.gd` | `extends Control`。各コンポーネントの動作確認（ボタン4状態、ラベルkey反映、set_value、set_value_with_max、open_with_content、Backdrop/escでclose）。printでPASS/FAIL報告 |

### 編集（`project.godot`）
| パス | 編集内容 |
|---|---|
| `res://project.godot` | `[gui]` セクションに `theme/custom = "res://theme/main_theme.tres"` を追加。**[input] セクションは触らない**（ユーザー指示） |

> Autoload（`project.godot` の `[autoload]`）は今回触らない（5件は既に登録済み。EXECの「やらないこと：Autoload変更」遵守）。

### 新規作成するフォルダ
| パス | 用途 |
|---|---|
| `res://scenes/ui/components/` | `.gitkeep` が既に存在。中身は今回初めて追加する（`AGENTS.md`「2画面以上で使い回すパーツのみ」） |

> `res://scenes/ui/components/` 自体は既に `.gitkeep` で枠だけ存在。`scenes/`/`scenes/ui/` 自体はEXEC作成と共に必要なら作るが、既存 `.gitkeep` の場所を見る限り既にフォルダはある（要再確認。なければ実装時に1ファイルで自動生成される）。

---

## 2. main_theme.tres に設定する項目の一覧

`Theme` リソース（`type="Theme"`）。`default_font` / `default_font_size` / 各コントロールタイプの `stylebox` / `font_color` 等を持つ。

### Default（全コントロール共通）
| 項目 | 値 | 備考 |
|---|---|---|
| `default_font` | `NotoSansJP-VariableFont_wght.ttf` | 1箇所だけ。個別Label/Buttonには設定しない |
| `default_font_size` | `16` | |

### Label
| 項目 | 値 | 備考 |
|---|---|---|
| `font_color` | `Color("#F0E6E0")` | テキスト（温かみのある白） |

### Button（PrimaryButtonで使う）
| 状態 | StyleBoxFlat項目 | 値 |
|---|---|---|
| **normal** | `bg_color` | `Color("#C4453A")`（プライマリ） |
|  | `corner_radius_*`（4方向） | `8` |
|  | `content_margin_top/bottom` | `10` |
|  | `content_margin_left/right` | `20` |
| **hover** | `bg_color` | `Color("#D25549")`（normalより少し明るく） |
|  | 角丸・余白 | normalと同一 |
| **pressed** | `bg_color` | `Color("#8E2F28")`（プライマリ濃） |
|  | 角丸・余白 | normalと同一 |
| **disabled** | `bg_color` | `Color("#3D2D33")`（ボーダー中間色） |
|  | 角丸・余白 | normalと同一 |
| ボタン共通 | `font_color` | `Color("#F0E6E0")` |
|  | `font_color_disabled` | `Color("#9A8A88")` |

> StyleBoxは `StyleBoxFlat` を使う。4状態それぞれ別sub_resourceとして`theme_override_styles/normal` 等に割り当てる。
> `border_color` / `border_width_*` は今回未設定（EXECにも指定なし）。必要なら中間色 `#3D2D33` を将来追加。

### PanelContainer（DialogBaseのPanelContainerで使う）
| 項目 | 値 | 備考 |
|---|---|---|
| `panel` (StyleBoxFlat) | `bg_color` | `Color("#2A1F24")`（パネル） |
|  | `corner_radius_*` | `8`（4方向） |

> DialogBaseの Backdrop はColorRect（テーマではなく直書き）。`Color(0, 0, 0, 0.6)` をBackdropノードの `color` プロパティに直接設定する（テストシーンの`#1A1418`下地ColorRectも同様）。

### プロジェクト全体への適用
- `project.godot` の `[gui]` セクションに `theme/custom = "res://theme/main_theme.tres"` を1行追加
- Project Settings → GUI → Theme → Custom は上の編集と等価

### 完了条件#11（ハードコードなし）の担保
- 個別シーン・個別スクリプトに `#C4453A` 等の色コードを直書きしない（Backdropとテスト下地以外）
- レビュー時は `grep` で `#[0-9A-Fa-f]{6}` を含む`.tscn`/`.gd`を検出し、`theme/`・`tests/test_ui_common.tscn`のColorRect下地・DialogBase Backdrop以外で検出されないことを確認

---

## 3. 各コンポーネントのシーン階層

### 3-1. `primary_button.tscn`

```
PrimaryButton (Button)              [class_name PrimaryButton, script=primary_button.gd]
```

- ルートノードは `Button`。ルートノード名 = `PrimaryButton`（PascalCase、AGENTS.md命名規則）
- スクリプト：`res://scenes/ui/components/primary_button.gd`
- **見た目の色はTheme任せ。シーン側で `theme_override_styles/*` や `theme_override_colors/*` を使わない**
- ノード自体に固有の `text` / `size_flags_*` 等のプロパティは設定しない（使う側が配置後に上書き）
- .tscn 内に外部参照（`ext_resource`）はスクリプトの1つのみ

### 3-2. `resource_display.tscn`

```
ResourceDisplay (HBoxContainer)     [class_name ResourceDisplay, script=resource_display.gd]
├─ Icon (TextureRect)
└─ ValueLabel (Label)
```

- ルートは `HBoxContainer`。ルートノード名 = `ResourceDisplay`
- スクリプト：`res://scenes/ui/components/resource_display.gd`
- **`Icon` のサイズ：24×24**。`custom_minimum_size = Vector2(24, 24)`
- **`Icon` の `expand_mode` = `Ignore Size`**、`stretch_mode` = `Keep Aspect Centered`（EXEC §5）
- `Icon` の `texture` は**未設定でよい**（アイコン画像は後日）
- `ValueLabel` の `text` は `"0"` などの初期値（`_refresh()` で上書き）
- `value` / `max_value` / `show_max` / `icon_texture` は `@export` でInspectorから差し替え可能
- 色```
DialogBase (Control)                [class_name DialogBase, script=dialog_base.gd, full rect, mouse_filter=Stop]
├─ Backdrop (ColorRect)             color = Color(0, 0, 0, 0.6), full rect, mouse_filter=Stop
└─ CenterContainer                  全画面中央寄せ担当（リサイズ追従）
	└─ PanelContainer              PanelContainerスタイルはTheme任せ
		└─ ContentContainer (VBoxContainer)
```mouse_filter = Stop, full rect
└─ PanelContainer                   PanelContainerスタイルはTheme任せ
	└─ ContentContainer (VBoxContainer)
```

- ルートは `Control`。ルートノード名 = `DialogBase`
- スクリプト：`res://scenes/ui/components/dialog_base.gd`
- **`DialogBase` の `mouse_filter = Stop`**（背後UIに伝播させないため）
- **`DialogBase` の `anchors_preset = 15` (Full Rect)** で全画面覆う
- `Backdrop`：
  - `ColorRect`。`color = Color(0, - `CenterContainer`：
  - `DialogBase` 直下（Backdropと同階層）。`anchors_preset = 15` (Full Rect)
  - 子コントロールを自動で画面中央に配置する（リサイズ追従、`_ready()` での手動計算不要）
- `PanelContainer`：
  - サイズは中身（ContentContainer）に合わせて伸縮
  - パネル背景はThemeの `PanelContainer/panel` が効く（`#2A1F24`・角丸8px）
  - `mouse_filter = Stop`（背景クリックをContentContainer配下に届かないようにするため）  - パネル背景はThemeの `PanelContainer/panel` が効く（`#2A1F24`・角丸8px）
  - `mouse_filter = Stop` または `Pass`（背景クリックをContentContainer配下に届かないようにするため、`Stop` を推奨）
- `ContentContainer`（`VBoxContainer`）：
  - PanelContainerの直下
  - この中に使う側が好きなControl（`Label`/`Button`/`VBoxContainer`等）を `add_child()` する
  - `open_with_content()` 呼び出し時に既存の子を `queue_free()` してから追加

### 3-4. `test_ui_common.tscn`（デモシーン）

```
TestUICommon (Control)              [script=test_ui_common.gd, full rect]
├─ Background (ColorRect)           color = Color("#1A1418"), full rect
├─ PrimaryButton (instance of res://scenes/ui/components/primary_button.tscn)
│       label_key = "test_button_normal"（または空にしてtext直接指定）
├─ PrimaryButton (disabled版)
├─ PrimaryButton (label_key = "test_button_long"、長いラベル)
├─ GoldDisplay (instance of resource_display.tscn)
│       value=100, icon_texture=null
├─ StaminaDisplay (instance of resource_display.tscn)
│       show_max=true, value=3, max_value=10
├─ MaterialDisplay (instance of resource_display.tscn)
│       value=42
└─ DialogBase (instance of dialog_base.tscn)
```

- レイアウト：垂直方向に `VBoxContainer` で並べるか、`Control` 直下に `offset_*` で絶対配置。`VBoxContainer` 推奨（後述 §4-3 参照）
- `DialogBase` は最初は `hide()`（スクリプトの `_ready()` で `hide()` される）。「Dialogを開く」PrimaryButtonを押すと `open_with_content()`| 確認項目 | 検証方法 |
|---|---|
| ボタン4状態 | シーン上の任意のPrimaryButtonから `get_theme_stylebox("normal"/"hover"/"pressed"/"disabled")` を呼び、StyleBoxFlat の `bg_color` を4つともprint（マウス入力不要・ユーザー承認済み） |
| `label_key` の `tr()` 反映 | 一方のPrimaryButtonに `label_key = "ui_ok"` 等を入れて、表示テキストが翻訳後になっているかprint |
| `set_value(100)` | 起動時に `GoldDisplay.set_value(100)` を呼び、数値が `"100"` になるかprint |
| `set_value_with_max(3, 10)` | 起動時に `StaminaDisplay.set_value_with_max(3, 10)` を呼び、`"3/10"` になるかprint |
| `open_with_content()` | `OpenDialogButton` 押下時に `Label("テスト")` を渡して開く。表示確認とBackdrop/Esc close確認 |
| Backdropクリックで close | `OpenDialogButton` を押して開いたあと、`_on_backdrop_gui_input` に相当する `InputEventMouseButton` を `Input.parse_input_event()` で投げる。または `DialogBase` の Backdrop を `call_deferred` で直接呼ぶ |
| Escapeで close | `Input.action_press("ui_cancel")` を呼んで `_unhandled_input` を発火させ、`close()` が走るか確認 |
| `dialog_closed` シグナル発火 | close後にシグナル接続側のカウンタを+1し、print |

> 完了条件#5「normal/hover/pressed/disabledの4状態で正しく色が変わる」は **`get_theme_stylebox()` で4状態の `bg_color` をprint**するだけでTheme側の設定は確認できる（ユーザー承認）。hover/pressed の**実際の見た目遷移**はヘッドレスでは再現しないため、**人間がエディタで実行して目視確認**する。`Input.parse_input_event()` で `hover` / `pressed` を投げる案はユーザー判断で**不採用**（OS入力依存で不安定なため）。5「normal/hover/pressed/disabledの4状態で正しく色が変わる」はマウス入力が必要。テストシーンでは disabled だけ実動作、他3状態は「ボタンの `get_theme_stylebox()` を呼んで StyleBoxFlat の `bg_color` をprint」で確認する（これでThemeが正しく設定されているか検証できる）。

---

## 4. 判断に迷った点（「特になし」は避ける）

1. **ThemeのStyleBoxの `content_margin` を Button の default に置くか、各インスタンスで `theme_override_constants/content_margin_*` するか** — EXEC §3 には「余白は上下10px・左右20px」とあり、Button全体のdefaultとするのがTheme一元化に沿う。`StyleBoxFlat` の `content_margin_*` を4状態すべてに設定する（AGENTS.md「個別シーンで色やフォントを直接指定しない」方針と整合）。

2. **`primary_button.tscn` で `text` をどう扱うか** — EXEC §4 には `label_key` 経由の例しか示されていない。`label_key` が空のときは `text` プロパティに直接書くことを許容する（Theme適用済みのButtonとして機能すればよい）。`label_key` が入っていれば `_ready()` で `tr()` を通す実装にする（EXECのサンプルコードに従う）。

3. **`resource_display` の `Icon` 初期サイズ** — EXEC §5 に「24×24」と明記済み。`custom_minimum_size = Vector2(24, 24)` を設定する。`expand_mode = IGNORE_SIZE` / `stretch_mode = KEEP_ASPECT_CENTERED` もEXEC指定どおり。`texture` 未設定時は空の24×24の透明領域になるが、これは仕様（アイコン画像は後日）。

4. **`resource_display` の 5. **`dialog_base` の `PanelContainer` を中央配置にする方法** — 方法は2つ：
   - (a) `PanelContainer` の `anchor_*` を `0.5` にしてサイズを固定（`custom_minimum_size`）する
   - (b) `DialogBase` 直下に `CenterContainer` を挟み、PanelContainerを子にする（**採用案**）
   - **(b) を採用**（ユーザー承認）：`DialogBase > Backdrop / CenterContainer > PanelContainer > ContentContainer` の階層にする。`CenterContainer` は子コントロールを自動で画面中央に配置し、ウィンドウリサイズにも自動追従する。`_ready()` で `await` を使って `PanelContainer.size` 取得・手動計算する必要がない。`CenterContainer` 自体の `mouse_filter` は `Pass` にしてBackdropクリックが伝わるようにする。。**最終案：`PanelContainer` 配下に `CenterContainer` を使わず、`PanelContainer.position` を `_ready()` で計算する**（依存ノードを増やさず最小）。
   - 中身サイズ確定は `await get_tree().process_frame` を1フレーム待ってから `PanelContainer.size` を再計算する。

6. **`dialog_base` の `_unhandled_input` のEsc処理で `ui_cancel` アクションを使う** — 現状の `project.godot` のInput Mapには `ui_cancel` が**登録されていない**。EXEC §6 のコードは `is_action_pressed("ui_cancel")` を使う前提だが、**ユーザー指示「Input Mapは変更しないでください」と矛盾する可能性がある**。
   - ただし `ui_cancel` は Godot の **デフォルトで組み込まれている** ビルトインアクション（Escapeキーにバインド済み）。Project SettingsのInput Mapに表示されないだけで、`Input.is_action_pressed("ui_cancel")` は動作する。
   - 確認：`get_input_map(include_inbuilt_actions: true)` で `ui_cancel` がビルトインとして存在することを確認する。→ **本実装ではビルトインの `ui_cancel` を使用し、Project SettingsのInput Mapには触らない**。IMPL_LOG §5 に「ui_cancelはGodot標準のビルトインアクション（Input Mapを変7. **テストシーンでの「ボタン4状態の色確認」方法** — ユーザー承認により **`Input.parse_input_event()` での hover/pressed 再現は不要**。代わりに `get_theme_stylebox("normal"/"hover"/"pressed"/"disabled")` で StyleBoxFlat の `bg_color` を取得して print する。マウス操作による実際の見た目遷移は**人間が目視確認**する。arse_input_event()` で投げてhover/pressedを再現するのは不安定
   - **代替策**：4つのStyleBoxそれぞれを `Theme.get_stylebox()` で取得し、`bg_color` をprint出力する「検証ボタン」を1つ用意。これで完了条件#5を満たす（hover/pressedの色が定義通りであることを静的に確認できる）

8. **Project Settings の `[gui]` セクション編集方法** — `[gui]` セクションは `project.godot` に**まだ存在しない**（現状ファイルに該当行なし）。セクションごと新規追加する。`[input]` セクションは触らない（ユーザー指示厳守）。

9. **`main_theme.tres` の Default Font 指定方法** — `.tres` ファイル内に `[ext_resource type="FontFile" path="res://assets/fonts/NotoSansJP-VariableFont_wght.ttf"]` を定義し、`default_font = ExtResource("...")` で参照する。`.import` ファイル経由で `FontFile` として読み込まれる。

10. **`cooldown_button` / `notification_label` を「作らない」ことをどう担保するか** — EXEC §「やらないこと」に明記済み。実装中にうっかり作らないよう、完了条件#12で明示的にチェックする（IMPL_LOGに「該当ファイルが存在しないこと」を記載）。

---

## 5. 指示書に書かれていないが必要だと思われること

1. **テストシーンで動作確認する各項目の自動print** — EXEC §7 には「printでも報告する」とある。各完了条件（#5〜#10）に対応するprint文を `test_ui_common.gd` に組み込み、コンソール出力で検証可能にする。具体的には：
   - 各ボタンの `get_theme_stylebox("normal")` 等の `bg_color` をprint（#5）
   - `tr(label_key)` の結果をprint（#6）
   - `set_value(100)` 後の `ValueLabel.text` をprint（#7）
   - `set_value_with_max(3, 10)` 後の `ValueLabel.text` をprint（#8）
   - `open_with_content()` 後に `ContentContainer` の子数と子のテキストをprint（#9）
   - `close()` 後に `dialog_closed` シグナルの発火をカウンタで記録しprint（#10）

2. **`test_ui_common.gd` の基底クラス** — シーンのルートが `Control` なので `extends Control` にする。`@onready` でインスタンスを取得する。EXEC §7 には「`extends Node`」と書かれているが、`Control` を継承したほうが `set_size()` 等が使える。**結論：`extends Control` で実装** （EXECからの逸脱として IMPL_LOG §5 に記載）。

3. **ラベルkeyの翻訳テーブル整備** — EXECの `label_key = "ui_ok"` 例で動くように、`localization/` フォルダに `.po` ファイルを用意する必要がある。ただし「翻訳ファイルは後で一括投入」運用が現実的（AGENTS.md参照）。**今回は翻訳ファイルを作らず、`label_key = "ui_ok"` 等で `tr()` 関数が呼ばれても原文（英語）がそのまま返る状態を許容**する。デモシーンのラベルは「あいうえお」等の日本語を `text` 直接指定でも可。完了条件#6は「`tr()` を通した文字列が表示される」ことを要求しているので、`tr("ui_ok")` が呼ばれること（戻り値の確認）までで十分とする。

4. **`primary_button.gd` の `label_key` の setter で `_ready()` 前後に注意** — サンプルコードには `if is_inside_tree(): text = tr(label_key)` の分岐があり、Inspector編集時もリアルタイム反映される。これは実装どおり採用する。

5. **`dialog_base.gd` の `_on_backdrop_gui_input` シグナル接続を `.tscn` 側で行うか `.gd` 側で行うか** — EXEC §6 末尾に「Backdrop の `gui_input` シグナルを `_on_backdrop_gui_input` に接続すること」とある。`.tscn` で `[connection signal="gui_input" from="Backdrop" to="." method="_on_backdrop_gui_input"]` を1行書く。`.gd` 側で `connect()` するより `.tscn` 側のほうがシーン編集で可視化される（AGENTS.mdの暗黙の運用方針と整合）。

6. **`main_theme.tres` の `[sub_resource type="StyleBoxFlat" id="..."]` を4状態＋PanelContainerで計5個作る** — Button.normal / Button.hover / Button.pressed / Button.disabled / PanelContainer.panel の5つのStyleBoxFlat。`bg_color` だけ違うので、StyleBoxFlat.sub_resource は5つ別IDで生成する（Themeが StyleBox を `theme_override_styles/<state>` で別々に持つため共有不可）。

7. **完了条件#2（Project Settings）の検証** — `project.godot` の `[gui]` セクションに `theme/custom = "res://theme/main_theme.tres"` が含まれているか grep で確認。エディタの再起動は不要（直接編集でもProject Settingsが反映される）。

8. **完了条件#11（色ハードコードなし）の検証手順** — `grep -rn "#[0-9A-Fa-f]\{6\}" --include="*.tscn" --include="*.gd" res/scenes/ res/tests/ res/scripts/ res/autoload/` を実行し、検出された箇所が「DialogBase の Backdrop の `color = Color(0, 0, 0, 0.6)`」「テストシーンのBackground ColorRect `#1A1418`」「テーマファイル内 `Color("#XXXXXX")` 形式のStyleBox定義」以外にないことを確認する。`res://theme/main_theme.tres` 内の色文字列はテーマ自体なので除外可。

9. **完了条件#12（`cooldown_button` / `notification_label` 不在の検証）** — `glob` で `res://scenes/ui/components/cooldown_button.*` と `notification_label.*` を検索し、どちらも**存在しないこと**を確認。IMPL_LOG §6「未実装・保留にした項目」に明記。

10. **`IMPL_LOG_UI_COMMON.md` の生成** — EXEC §完了条件#13。テンプレート（`docs/02_exec/IMPL_LOG_TEMPLATE.md`）の型に沿って、`res://docs/03_log/IMPL_LOG_UI_COMMON.md` に生成する。セクション5（逸脱・迷った判断）は本PRE_PLAN §4 をベースに必ず埋める。

---

## 6. 実装手順の概要（参考）

1. `res://theme/main_theme.tres` を作成（ext_resource + 5 StyleBoxFlat + Default Font/Size + Label/Button/PanelContainerエントリ）
2. `res://project.godot` の `[gui]` セクションに `theme/custom = "res://theme/main_theme.tres"` を追加
3. `res://scenes/ui/components/primary_button.tscn` / `.gd` を作成
4. `res://scenes/ui/components/resource_display.tscn` / `.gd` を作成（`set_value()` で `_refresh()` 呼ぶようサンプルから微修正）
5. `res://scenes/ui/components/dialog_base.tscn` / `.gd` を作成（Backdrop gui_input接続を.tscnに、`PanelContainer` 中央配置を `_ready()` で計算）
6. `res://tests/test_ui_common.tscn` / `.gd` を作成（各コンポーネント配置＋print検証）
7. 完了条件13項目を1つずつ検証し、`IMPL_LOG_UI_COMMON.md` を生成

---

## 7. 関連ドキュメント参照

- `res://docs/02_exec/EXEC_UI_COMMON.md`（本PRE_PLANのもと）
- `res://docs/01_plan/PLAN_UI_COMMON.md`（第2層・作戦計画）
- `res://AGENTS.md`（プロジェクトルール・UIパーツ置き場所・命名規則・Theme扱い）
- `res://docs/02_exec/IMPL_LOG_TEMPLATE.md`（実装ログの型）
- `res://docs/03_log/PRE_PLAN_COMMON_INFRA.md`（先タスクのPRE_PLAN。Autoload側の整合性確認用）
- `res://docs/03_log/IMPL_LOG_COMMON_INFRA.md`（先タスクの実装ログ）
