# PRE_PLAN_BASE_SCREEN.md

`EXEC_BASE_SCREEN.md` を読んだ上での実装前計画。実装は別フェーズで行う。

## 1. 作成・変更するファイル一覧（パスと役割）

### 1-1. 既存ファイルの書き換え

| パス | 変更内容 | 役割 |
|---|---|---|
| `res://scripts/utils/state_keys.gd` | 末尾に画面ID定数5つを追記 | `SCREEN_GUILD` / `SCREEN_ADVENTURE_SELECT` / `SCREEN_POMODORO` / `SCREEN_SETTINGS` / `SCREEN_SCENARIO` を公開する。既存のキー（`GOLD` / `STAMINA` / `STAMINA_MAX` 等）は一切変更しない |
| `res://scripts/utils/transfer_keys.gd` | `SCREEN_ID` 定数を追記 | `SceneManager.change_scene_with_data()` で拠点→未実装画面へ `screen_id` を渡すために使う。現状ファイル内のコメント（「本タスク時点では空。各画面の実装時に各PLANファイル側で追記」）を活かす形で追記する |
| `res://localization/ja.csv` | 1行リネーム + 3行追加 + 既存行は維持 | UTF-8 (BOMなし) で保存。編集後に `ja.csv.import` の再生成 or Godot再起動、`res://localization/ja.translation` が Translations に登録済みか確認 |
| `res://scenes/base/base_screen.tscn` | ノード階層を §4 指示通りに丸ごと置き換え | 仮シーン（`PlaceholderLabel` / `StateLabel`）を捨て、TopArea + BottomArea の本番構成に作り直す |
| `res://scenes/base/base_screen.gd` | スクリプトを §5 指示通りに丸ごと置き換え | リソース表示・素材動的生成・シグナル購読・画面遷移・チェスト・セーブ/タイトル復帰をまとめて実装する |

### 1-2. 新規作成

| パス | 役割 |
|---|---|
| `res://scenes/ui/placeholder_screen.tscn` | 未実装画面の共通の受け皿。Background / Layout / TitleLabel / BackButton の最小構成。`change_scene_with_data` で渡された `screen_id` を `consume_transfer_data` で取り出し、タイトル文言を切り替える |
| `res://scenes/ui/placeholder_screen.gd` | 上記 `.tscn` にアタッチするスクリプト。`TransferKeys.SCREEN_ID` を取り出し、`tr("ui_nav_" + screen_id) + tr("ui_placeholder_suffix")` を表示する。BackButton 押下で `res://scenes/base/base_screen.tscn` へ戻る |
| `res://docs/03_log/IMPL_LOG_BASE_SCREEN.md` | 実装完了後に `IMPL_LOG_TEMPLATE.md` の型に沿って生成するログ。本ファイルとは別物（最終フェーズで作成） |

### 1-3. 触らないもの（明示的に禁止）

- `res://autoload/` 配下5ファイル（`balance.gd` / `game_manager.gd` / `save_manager.gd` / `scene_manager.gd` / `signal_bus.gd`）
- `res://addons/` 配下（Ziva本体）
- `res://theme/main_theme.tres`
- `project.godot` の `[input]` セクション（Input Map）
- `res://scenes/title/title_screen.tscn` / `.gd`（遷移先パス `"res://scenes/base/base_screen.tscn"` が既に正しく書かれている）

## 2. `base_screen.tscn` のノード階層（§4）

指示書 §4 の階層を、設定すべきプロパティ付きで書き起こす。
`size_flags` / `custom_minimum_size` / `anchors_preset` / `grow_*` は Godot のデフォルト挙動を理解した上で明示的に書く。`Background` の色以外で色は指定しない。

### 2-1. ルート層

```
BaseScreen (Control)                        # full rect
  anchors_preset = 15  (anchor_right=1, anchor_bottom=1)
  grow_horizontal = 2, grow_vertical = 2
  script = res://scenes/base/base_screen.gd (class_name は付けない。extends Control のまま)
```

### 2-2. 直下

```
Background (ColorRect)                       # フルrect、色のみ例外でハードコード
  anchors_preset = 15
  grow_horizontal = 2, grow_vertical = 2
  color = Color(0.101961, 0.0784314, 0.0941176, 1)   # #1A1418、指示書 §4

Layout (VBoxContainer)                       # フルrect、内側に TopArea / BottomArea を縦に積む
  anchors_preset = 15
  grow_horizontal = 2, grow_vertical = 2
  theme_override_constants/separation = 8   # 縦隙間（指示書未指定。既存仮シーンは 16 だったが、中身が仮から本番に変わるので既定値の 8 を採用。迷い箇所として §6 に記載）
```

### 2-3. Layout の子

```
TopArea (Control)
  size_flags_vertical = EXPAND_FILL
  # 中身は空（§0-2）。子ノードを置かない。CustomMinimumSize も未指定
  # 名前は仮置きで PascalCase（指示書 §4 通り）。コメント用途なので日本語の説明は書かない

BottomArea (PanelContainer)
  custom_minimum_size.y = 160                # 指示書 §4 通り（1280×720 基準）
  # 上方向に詰めたくないので size_flags_vertical は未指定のまま
  BottomLayout (VBoxContainer)
	# VBoxContainer のデフォルトで子は縦に並ぶ
```

### 2-4. BottomLayout の子

```
ResourceRow (HBoxContainer)                  # 指示書では「高さ 56 目安」
  custom_minimum_size.y = 56
  # 子要素:
	GoldEntry (HBoxContainer)
	  # ResourceDisplay には名前ラベルが無いため外側で持つ（指示書 PLAN との差異）
	  NameLabel (Label)
		text = "ui_res_gold"                 # auto_translate 経由で翻訳される
		# horizontal_alignment は未指定（Left 既定）
	  Value (HBoxContainer)                  # resource_display.tscn をインスタンス配置
		# 中身は触らない（Icon + ValueLabel のみ）。icon_texture 未設定で OK
	StaminaEntry (HBoxContainer)
	  NameLabel (Label)
		text = "ui_res_stamina"
	  Value (HBoxContainer)                  # resource_display.tscn をインスタンス
	MaterialsDisplay (HBoxContainer)         # MaterialEntry を _ready() で動的追加
	  # custom_minimum_size は未指定。動的要素の合計幅に任せる
	Spacer (Control)
	  size_flags_horizontal = EXPAND_FILL    # 右側の ChestBadge を右端に押し出す
	ChestBadge (Button)                      # アイコン未設定。押下で _on_chest_badge_pressed
	  ChestCountLabel (Label)
		text = ""                            # 件数 0 のときは visible=false で隠す
	SaveButton (Button)                      # primary_button.tscn をインスタンス
	  label_key = "ui_base_save"
	BackToTitleButton (Button)               # primary_button.tscn をインスタンス
	  label_key = "ui_base_back_to_title"

NavigationButtons (HBoxContainer)            # 指示書では「高さ 104 目安」
  custom_minimum_size.y = 104
  theme_override_constants/separation = 8    # ボタン間の隙間（指示書未指定。§6 に記載）
  # 子要素（すべて primary_button.tscn のインスタンス・等幅・EXPAND_FILL）
	AdventureButton
	  label_key = "ui_nav_adventure_select"  # リネーム後のキー（§2-1）
	  size_flags_horizontal = EXPAND_FILL
	GuildButton
	  label_key = "ui_nav_guild"
	  size_flags_horizontal = EXPAND_FILL
	PomodoroButton
	  label_key = "ui_nav_pomodoro"
	  size_flags_horizontal = EXPAND_FILL
	SettingsButton
	  label_key = "ui_nav_settings"
	  size_flags_horizontal = EXPAND_FILL
	ScenarioButton
	  label_key = "ui_nav_scenario"
	  size_flags_horizontal = EXPAND_FILL
```

### 2-5. placeholder_screen.tscn のノード階層（§3）

```
PlaceholderScreen (Control)                  # full rect
  anchors_preset = 15
  grow_horizontal = 2, grow_vertical = 2
  script = res://scenes/ui/placeholder_screen.gd

Background (ColorRect)                       # 拠点と色を揃える
  anchors_preset = 15
  grow_horizontal = 2, grow_vertical = 2
  color = Color(0.101961, 0.0784314, 0.0941176, 1)

Layout (VBoxContainer)                       # 中央寄せ（指示書「中央配置」）
  anchors_preset = 8                         # center
  grow_horizontal = 2, grow_vertical = 2
  theme_override_constants/separation = 16
  TitleLabel (Label)
	text = ""                                # 初期は空、_ready() で組み立てる
	horizontal_alignment = 1                 # CENTER
  BackButton (Button)                        # primary_button.tscn をインスタンス
	label_key = "ui_common_back"
```

### 2-6. 配置の注意

- `MaterialsDisplay` 内の `MaterialEntry` は `.tscn` に書き出さない（動的生成）。
- `ChestBadge` は `Button` の素の見た目。アイコン画像は未指定。押下ハンドラで `_go_to_screen(SCREEN_GUILD)` を呼ぶ。
- `ResourceDisplay` / `PrimaryButton` はインスタンスとして配置。中身の `Icon` `ValueLabel` 等の子ノードを `.tscn` 側に複製しない。

## 3. `base_screen.gd` の関数一覧と、シグナルの接続先

### 3-1. ファイル先頭

- `class_name` は付けない（既存仮スクリプトが `extends Control` だけで `class_name` を持っていないため、置換後も同じスタイルに揃える。指示書にも class_name 追加の指示はない）
- 冒頭に「`extends Control`」「`AGENTS.md` 準拠」「オートセーブ未実装の間は SaveButton / BackToTitleButton を残している」旨のコメントを置く（§0-4）
- ファイル冒頭に「本ファイルは仮シーンの本実装への置き換えである（EXEC_BASE_SCREEN.md §4 / §5）」と目的を明記

### 3-2. 定数

- `PLACEHOLDER_PATH: String = "res://scenes/ui/placeholder_screen.tscn"` （指示書 §5-5 そのまま）
- `SCREEN_SCENES: Dictionary = { SCREEN_ADVENTURE_SELECT: PLACEHOLDER_PATH, ... }` （§5-5 そのまま、5画面分）
- `BASE_PATH: String = "res://scenes/base/base_screen.tscn"`（placeholder_screen からの戻り先。§3 placeholder 用）
- `TITLE_PATH: String = "res://scenes/title/title_screen.tscn"`（BackToTitleButton 用、既存仮シーンと同じパス）
- `RESOURCE_DISPLAY_SCENE: PackedScene = preload("res://scenes/ui/components/resource_display.tscn")`（§5-4 で動的生成する際に必要）
- `PRIMARY_BUTTON_SCENE: PackedScene = preload("res://scenes/ui/components/primary_button.tscn")`（使わないかもしれないが、`MaterialEntry` の生成で使う可能性に備え preload しておく。使わないなら削除）

### 3-3. @onready 参照（§4 階層と完全一致）

- `gold_value: ResourceDisplay = $Layout/BottomArea/BottomLayout/ResourceRow/GoldEntry/Value`
- `stamina_value: ResourceDisplay = .../StaminaEntry/Value`
- `materials_display: HBoxContainer = $Layout/BottomArea/BottomLayout/ResourceRow/MaterialsDisplay`
- `chest_badge: Button = $Layout/BottomArea/BottomLayout/ResourceRow/ChestBadge`
- `chest_count_label: Label = $Layout/BottomArea/BottomLayout/ResourceRow/ChestBadge/ChestCountLabel`
- `save_button: PrimaryButton = $Layout/BottomArea/BottomLayout/ResourceRow/SaveButton`
- `back_to_title_button: PrimaryButton = $Layout/BottomArea/BottomLayout/ResourceRow/BackToTitleButton`
- ナビゲーション5ボタン:
  - `adventure_button: PrimaryButton = $Layout/BottomArea/BottomLayout/NavigationButtons/AdventureButton`
  - `guild_button, pomodoro_button, settings_button, scenario_button` も同様

### 3-4. 内部状態

- `var _material_entries: Dictionary = {}` … `material_id` → `HBoxContainer`（=MaterialEntry）の対応表（§5-4）
- `var _navigation_buttons: Dictionary = {}` … `screen_id` → `PrimaryButton` の対応表（§5-5「ボタンと screen_id の対応も Dictionary かループで持たせて5回同じコードを書かない」）

### 3-5. 関数一覧

| 関数 | 役割 | 呼び出し元 |
|---|---|---|
| `_ready()` | 初期表示（§5-1）+ シグナル接続（§5-2）+ ボタン押下接続 | Godot |
| `_init_resource_displays()` | `_ready()` から呼ぶ。gold / stamina を `get_state()` から1回だけ読み、各 `ResourceDisplay` に流し込む | 内部 |
| `_init_materials(state: Dictionary)` | `_ready()` から呼ぶ。`state[GameStateKeys.MATERIALS]` を回して `MaterialEntry` を動的生成し `_material_entries` に登録（§5-4） | 内部 |
| `_init_navigation_buttons()` | `_ready()` から呼ぶ。`SCREEN_SCENES` のキーを見て5ボタンを `_navigation_buttons` に登録し、`pressed` を `_go_to_screen` にまとめて接続。`is_screen_unlocked` で `visible` を切っておく | 内部 |
| `_connect_signals()` | `_ready()` から呼ぶ。`GameManager` の4シグナルと各ボタンの `pressed` を接続 | 内部 |
| `_on_resource_changed(resource_type: String, new_value: Variant)` | §5-2 / §5-3。GOLD / STAMINA のみ更新。**STAMINA のとき `get_state()` から max を再取得**（§5） | `GameManager.resource_changed` |
| `_on_material_changed(material_id: String, new_amount: int)` | §5-2。`_material_entries` に無ければ `_create_material_entry()` を呼んで追加、有れば `set_value` だけ呼ぶ | `GameManager.material_changed` |
| `_on_screen_unlocked(screen_id: String)` | §5-2。`_navigation_buttons` を引いて `visible = true` | `GameManager.screen_unlocked` |
| `_on_pending_chests_changed(pending_count: int)` | §5-6。`ChestCountLabel.text = str(pending_count)`、0件なら `chest_badge.visible = false` | `GameManager.pending_chests_changed` |
| `_create_material_entry(material_id: String, initial_amount: int) -> void` | §5-4。`HBoxContainer` を作り、NameLabel（`tr("ui_res_" + material_id)` を text に）と `ResourceDisplay`（`preload` で `instantiate`）を子に持つ。`materials_display` に `add_child` する。`_material_entries[material_id] = entry` を登録 | `_init_materials` / `_on_material_changed` |
| `_go_to_screen(screen_id: String)` | §5-5。`SCREEN_SCENES.get(screen_id, "")` を取得。空なら `push_warning` で return。非空なら `SceneManager.change_scene_with_data(path, {TransferKeys.SCREEN_ID: screen_id})` | ナビゲーション5ボタン + `ChestBadge` 押下 |
| `_on_chest_badge_pressed()` | `_go_to_screen(GameStateKeys.SCREEN_GUILD)` を呼ぶラッパー | `ChestBadge.pressed` |
| `_on_save_pressed()` | `SaveManager.save_game()` の戻り値を `print`（§5-7） | `SaveButton.pressed` |
| `_on_back_to_title_pressed()` | `SceneManager.change_scene(TITLE_PATH)`（§5-7） | `BackToTitleButton.pressed` |

### 3-6. シグナル接続対応表（受信 → 更新先）

| シグナル | 受信ハンドラ | 更新先ノード | 備考 |
|---|---|---|---|
| `GameManager.resource_changed(GOLD, int)` | `_on_resource_changed` | `gold_value.set_value(int)` | `_on_resource_changed` 内で `resource_type == GameStateKeys.GOLD` 分岐 |
| `GameManager.resource_changed(STAMINA, int)` | `_on_resource_changed` | `stamina_value.set_value_with_max(int, stamina.max)` | §5-3 の通り `get_state()` から max を再取得 |
| `GameManager.resource_changed(GEMS, int)` | `_on_resource_changed` | （無視） | 表示していないため no-op。`GEMS` 以外（未知の resource_type 来た場合）も push_warning のみで何もしない |
| `GameManager.material_changed(material_id, int)` | `_on_material_changed` | 該当 `MaterialEntry/Value.set_value(int)` または新規生成 | §5-4 |
| `GameManager.screen_unlocked(screen_id)` | `_on_screen_unlocked` | 該当 `_navigation_buttons[screen_id].visible = true` | `_navigation_buttons` に存在しない id は push_warning |
| `GameManager.pending_chests_changed(int)` | `_on_pending_chests_changed` | `chest_count_label.text` + `chest_badge.visible` | §5-6 |

### 3-7. ボタン → screen_id 対応（§5-5 関連）

`_navigation_buttons` を組み立てる順序：

```
{
  GameStateKeys.SCREEN_ADVENTURE_SELECT: adventure_button,
  GameStateKeys.SCREEN_GUILD:            guild_button,
  GameStateKeys.SCREEN_POMODORO:         pomodoro_button,
  GameStateKeys.SCREEN_SETTINGS:         settings_button,
  GameStateKeys.SCREEN_SCENARIO:         scenario_button,
}
```

これにより `_go_to_screen` 側は1箇所にまとまり、ボタン側コードは `_ready()` で5回 `pressed.connect(_go_to_screen.bind(screen_id))` するだけになる（重複コード禁止の指示に従う）。

### 3-8. placeholder_screen.gd の関数一覧（参考）

| 関数 | 役割 |
|---|---|
| `_ready()` | `consume_transfer_data()` を呼び、`SCREEN_ID` を取り出す。`tr("ui_nav_" + id) + tr("ui_placeholder_suffix")` を組み立てて TitleLabel.text に設定。空 / 取得失敗時は `tr("ui_placeholder_suffix")` のみ（§3 挙動3）。`back_button.pressed.connect(_on_back_pressed)` |
| `_on_back_pressed()` | `SceneManager.change_scene(BASE_PATH)` で拠点へ戻る。`go_back()` は使わない（指示書 §3 実装上の注意） |

## 4. `ja.csv` の最終的な中身

### 4-1. 編集方針

- 既存24行（現在 `ui_title_label` 〜 `ui_nav_scenario`）はすべて維持する
- 1行リネーム: `ui_nav_adventure` → `ui_nav_adventure_select`（値「冒険」は変更しない）
- 3行追加: `ui_placeholder_suffix` / `ui_base_chest` / `ui_res_material_unknown`
- 重複キーが無いことを事前確認した結果、3つの追加キーは全て新規。`ui_nav_adventure_select` も既存に無い
- 文字コードは UTF-8 (BOMなし)。日本語の値に `,` は含まれないためセルを `"` で囲む必要なし

### 4-2. 編集後の全行（順序は既存踏襲 + 末尾追加）

```
keys,ja
ui_title_label,ポモドーロヒーローズ
ui_title_start_new,はじめから
ui_title_start_continue,つづきから
ui_title_delete_save,セーブを消す
ui_title_load_failed,セーブを読み込めませんでした。新しく始めます。
ui_title_delete_done,セーブを削除しました。
ui_title_delete_failed,セーブの削除に失敗しました。
ui_base_placeholder,拠点画面（仮）
ui_base_save,セーブする
ui_base_back_to_title,タイトルへ戻る
ui_base_chest,宝箱
ui_common_ok,決定
ui_common_cancel,キャンセル
ui_common_close,閉じる
ui_common_back,戻る
ui_common_yes,はい
ui_common_no,いいえ
ui_res_gold,ゴールド
ui_res_gems,ジェム
ui_res_stamina,スタミナ
ui_res_construction_material,建築素材
ui_res_material_unknown,不明な素材
ui_nav_adventure_select,冒険
ui_nav_guild,ギルド
ui_nav_pomodoro,ポモドーロ
ui_nav_settings,設定
ui_nav_scenario,シナリオ
ui_placeholder_suffix,（未実装）
```

### 4-3. 並び替えの意図

- `ui_base_chest` は `ui_base_*` 群の末尾（`ui_base_back_to_title` の直後）に追加
- `ui_res_material_unknown` は `ui_res_construction_material` の直後に追加（素材系の連番維持）
- `ui_nav_adventure_select` は `ui_nav_adventure` があった位置（`ui_res_*` 群の直後）にリネーム後のまま据え置き
- `ui_placeholder_suffix` は末尾に追加（新規カテゴリで、他と隣接する自然な場所が無いため）

### 4-4. 編集後の必須作業（§2-3）

1. CSV編集後、Godotエディタの FileSystem パネルで `ja.csv` を選び右クリック → 再インポート（Godotが `ja.csv.import` を再生成する）
2. Project Settings → Localization → Translations に `res://localization/ja.translation` が登録されていることを確認。なければ追加
3. 完了条件4（リソース名・ボタン名が日本語で出る）はここで初めて通る。`ui_res_gold` の文字列が画面に出たら再インポート漏れ

## 5. stamina の max をどう取得するか（§5-3 対応）

### 5-1. 問題と根拠

`GameManager.resource_changed` のシグネチャは `(resource_type: String, new_value: Variant)`。`game_manager.gd` 127行 / 139行を見ると、STAMINA のときは `stamina[GameStateKeys.STAMINA_CURRENT]`（=current の int 単体）をそのまま `emit` している。**max は含まれない**。

一方 `ResourceDisplay.set_value_with_max(current: int, max: int)` は max を必要とするため、表示のたびに `max` を別口で取る必要がある。

### 5-2. 採用するコードの流れ

`_on_resource_changed(resource_type, new_value)` 内で STAMINA ブランチに来たとき：

1. `resource_type` を `GameStateKeys.STAMINA` 定数と比較（文字列リテラル禁止）
2. `var state: Dictionary = GameManager.get_state()` でスナップショットを取り直す
3. `var stamina_dict: Dictionary = state.get(GameStateKeys.STAMINA, {})` でネスト辞書を取得
4. `var stamina_max: int = int(stamina_dict.get(GameStateKeys.STAMINA_MAX, 0))` で max を int 化
5. `stamina_value.set_value_with_max(int(new_value), stamina_max)` を呼ぶ

```gdscript
if resource_type == GameStateKeys.STAMINA:
    var state: Dictionary = GameManager.get_state()
    var stamina_dict: Dictionary = state.get(GameStateKeys.STAMINA, {})
    var stamina_max: int = int(stamina_dict.get(GameStateKeys.STAMINA_MAX, 0))
    stamina_value.set_value_with_max(int(new_value), stamina_max)
```

### 5-3. なぜ `get_state()` を毎回来てもよいと判断するか

- `get_state()` は `duplicate(true)` 全体を返す。完全コピーなので無視できないコストではある
- ただし stamina 変化の頻度は「ポモドーロ完了」「戦闘参加」「時間回復」など低頻度
- 1フレームに何度も呼ばれるシグナルではない
- もっと重要な点として、現状 GameManager に「max が変わった」ことを通知する経路が**無い**。research / facility / training 等で max が増える設計が入るまで、max をキャッシュする意味が薄い
- 将来 `max` を動的に変える機能が入ったら、GameManager 側に `STAMINA_MAX_CHANGED` シグナル等を足し、その時点で `base_screen.gd` のこのブロックを「STAMINA_MAX_CHANGED を購読してローカル変数 `_stamina_max` を更新 + 表示は `_stamina_max` から読む」形へリファクタする。今はその hook がない

### 5-4. 初期表示（`_init_resource_displays()`）でも同じ

`_ready()` 内では gold / stamina を `get_state()` から1回だけ読み、`set_value_with_max(stamina_curr, stamina_max)` を呼ぶ。`_on_resource_changed` と同じ取得ロジック（ネスト経由）を再利用して不整合を防ぐ。具体的には：

```gdscript
var state: Dictionary = GameManager.get_state()
var stamina_dict: Dictionary = state.get(GameStateKeys.STAMINA, {})
var stamina_curr: int = int(stamina_dict.get(GameStateKeys.STAMINA_CURRENT, 0))
var stamina_max: int = int(stamina_dict.get(GameStateKeys.STAMINA_MAX, 0))
stamina_value.set_value_with_max(stamina_curr, stamina_max)
```

### 5-5. `10/0` 事故を避ける仕組み

- `_on_resource_changed` 内に `if stamina_max <= 0:` ガードは敢えて入れない。`set_value_with_max(0, 0)` は起きうるが、そのとき `0/0` 表示になるのは GameManager 側の初期化漏れ（バグ）なので、画面側で握り潰すより push_warning を出して気づけるほうがよい
- ただし `int(...)` 変換で null や負値が来たときにクラッシュしないよう、`int(stamina_dict.get(STAMINA_MAX, 0))` のように第2引数でデフォルト 0 を与える

### 5-6. IMPL_LOG への転記（指示書 §5-3 末尾）

この「`get_state()` 経由で max を取得する」設計は、指示書本文 §5-3 に「将来 GameManager 側に max を含む通知を追加して差し替える必要がある」と明記されている。実装後に `IMPL_LOG_BASE_SCREEN.md` の「5. 指示書からの逸脱・迷った判断」欄へ、経緯と差し替えが必要になったときの作業（GameManager 側シグナル追加 → `base_screen.gd` の当該ブロックをリファクタ）を転記する。

## 6. 判断に迷った点

指示書で明示されていない、または記述が複数解釈できる箇所を列挙する。実装時はここを参照しつつ進める。

### 6-1. `Layout (VBoxContainer)` の `theme_override_constants/separation`

指示書 §4 には `Background` の色と `BottomArea.custom_minimum_size.y = 160` 以外、具体的な spacing 値が無い。仮シーンでは `separation = 16` を使っていたが、TopArea（空）と BottomArea の間、および BottomLayout 内部の隙間は指示が無い。

**解釈**: 仮シーンの 16 をそのまま継承するか、Godot の VBoxContainer デフォルトの 8 に下げるか。今回は TopArea が空のため外側 `Layout` の separation は**デフォルト（指定なし）** とし、BottomLayout 内部の ResourceRow と NavigationButtons の間は `theme_override_constants/separation = 8` 程度を仮置きする。`NavigationButtons` 内ボタン間も `separation = 8` 程度。最終値は実装時に見た目で微調整。

### 6-2. `ChestBadge` の「アイコン未指定 Button」の見た目

指示書 §4 は「アイコン画像が未用意のため `Button` のまま、テクスチャができたら `TextureButton` に差し替える」とある。Button には `text` ではなく `ChestCountLabel` を子に持つ構造になっている。

**解釈**: `ChestBadge.text` は空のままにし、子に `ChestCountLabel` を持つ。押下ハンドラで `_go_to_screen(SCREEN_GUILD)` を呼ぶ。Button 自体のスタイル（押下時の色変化等）は `main_theme.tres` 経由なので `.tscn` 側では何も触らない。`ChestCountLabel` の位置調整は `ChestBadge` 内に `center` 系の anchor を設定して中央寄せする程度（プロパティ指定は実装時に決定）。`ChestBadge` に `custom_minimum_size` を設けるかは要観察（小さすぎると件数が見切れる）。

### 6-3. `MaterialsDisplay` の `custom_minimum_size`

指示書 §4 に `MaterialsDisplay` のサイズ指定は無い。動的生成で `MaterialEntry` が複数並ぶため、行高は `ResourceRow.custom_minimum_size.y = 56` に自動的に収まる（MaterialEntry 側でも `custom_minimum_size` は指定しない）。

**解釈**: `MaterialsDisplay` 自身には `custom_minimum_size` を指定しない。動的に増えた `MaterialEntry` の合計幅に任せる。`ResourceRow` 全体の幅が 1280 を超える場合は `ScrollContainer` で囲む等の対処が必要だが、§「やらないこと」に「素材が3種類以上になった場合の折り返し・スクロールレイアウト」と明記されており**今回は対応しない**。

### 6-4. `Spacer` を `MaterialsDisplay` と `ChestBadge` の間に置くか

指示書 §4 には `Spacer (Control) size_flags_horizontal = EXPAND_FILL` とだけある。`ResourceRow` の中での位置は明確（MaterialsDisplay の直後、ChestBadge の直前）。

**解釈**: 指示書通り `MaterialsDisplay` の直後・`ChestBadge` の直前に置く。`Spacer` は `Control` 型で `size_flags_horizontal = EXPAND_FILL` のみ。`size_flags_vertical` は未指定で OK。

### 6-5. `_init_navigation_buttons()` の接続方法

指示書 §5-5 は「ボタンと screen_id の対応も、Dictionary かループで持たせて5回同じコードを書かないこと」とある。

**解釈**: コード5行ではなく、`_navigation_buttons: Dictionary` を `_ready()` で組み立て、5回 `pressed.connect(_go_to_screen.bind(screen_id))` を回す方式（ループ）か、5つの `screen_id → button` マップを Dictionary リテラルで書く方式のどちらでも「5回同じコードを書かない」基準を満たす。今回は `@onready var` で個別に参照しつつ、ループで `pressed.connect(_go_to_screen.bind(screen_id))` する方式を採用する（マップを別に持たなくて済むため）。

```gdscript
for screen_id in SCREEN_SCENES:
    var btn: PrimaryButton = match_button_to_screen_id(screen_id)  # match 関数を使うか
    btn.pressed.connect(_go_to_screen.bind(screen_id))
```

もしくは `match` 文で 5 つのボタン参照を返す `func _button_for(screen_id: String) -> PrimaryButton:` を用意して 5 ボタン全てを `pressed` 接続する。実装時に読みやすさ優先で決定する。

### 6-6. `get_state()` 経由の max 取得 vs `signal_bus` を増やして max 通知

指示書 §5-3 自体が「現状 GameManager に `max` を通知する手段が無く、この方式を採る」と明記しており、迷う余地は実は無い。ただし「将来用に残すメモ」をどう書くかだけは判断が必要。

**解釈**: `base_screen.gd` の `_on_resource_changed` の STAMINA ブランチ直上に `# TODO(計画書): max が変わった通知を GameManager 側に追加したら、このブロックを STAMINA_MAX_CHANGED シグナル購読に置換する` のようなコメントを残し、`IMPL_LOG` にも転記する（§5-6 で既に書いた通り）。

### 6-7. `signal_bus` に `STAMINA_MAX_CHANGED` を今回追加すべきか

指示書 §5-3 は「将来追加」と書いてあり今回は追加しない。`AGENTS.md` も「Autoload を勝手に追加しない」とあるので、SignalBus のシグナル追加は SignalBus 側の修正となる。今回は**追加しない**で `get_state()` 経由方式で行く。

### 6-8. `placeholder_screen.tscn` の Background 色

指示書 §3 は `Background (ColorRect) Color(0.101961, 0.0784314, 0.0941176, 1)` と明記（拠点と完全同一色）。`AGENTS.md` の「色・フォントは Theme 経由で、Background の ColorRect は例外」と整合する。例外扱いの背景色を placeholder 側にも転記するのは妥当と判断（拠点と同じ背景色であるべき視覚的連続性のため）。

### 6-9. `_on_pending_chests_changed` の 0 件判定

指示書 §5-6 は「件数が 0 のときは `ChestBadge` 自体を非表示にする」とある。`_ready()` 内で `GameManager.get_pending_chest_count()` を呼んだ結果も 0 のことがあるが、その場合も非表示でよい（明示的に「`_ready()` 段階では件数が確定するまで ChestBadge を一旦表示にしておく」とは指示されていない）。

**解釈**: `_ready()` 内で `get_pending_chest_count()` の戻り値 0 の場合は `chest_badge.visible = false` のまま。`pending_chests_changed(0)` シグナルを後から受信しても 0 のまま。0 → 0 の更新は冗長だが害は無い。

### 6-10. `SaveButton` 押下時の print 文

指示書 §5-7 は「`SaveManager.save_game()` を呼ぶ。戻り値を `print` に出す」とある。フォーマットは指定されていない。

**解釈**: `print("[BaseScreen] save_game() -> %s" % ok)` 程度。AGENTS.md の方針「print は翻訳キー不要（開発者向け）」に従う。

### 6-11. `IMPL_LOG_BASE_SCREEN.md` の生成タイミング

指示書 §「動作確認手順」の項目20は `IMPL_LOG` の生成を完了条件に含めている。実装完了直後に `IMPL_LOG_TEMPLATE.md` の型に沿って別ファイルで生成する。**実装フェーズで書く**ので、本 PRE_PLAN のセクション7には含めない。

## 7. 指示書に書かれていないが必要だと思われること

### 7-1. PLAN_BASE_SCREEN.md との同期更新

指示書 §0-1 / §0-2 で「PLAN_BASE_SCREEN.md も同時に修正する（別紙 `PLAN_BASE_SCREEN_DIFF.md`）」と明記されている。これは本タスクのスコープ**外**（`docs/` は AI が勝手に書き換えない領域）だが、**人間への確認事項**として伝える必要がある。実装着手前に「`PLAN_BASE_SCREEN_DIFF.md` を人間が用意したか」を確認し、無ければ人間に作成をお願いする。

### 7-2. `IMPL_LOG_BASE_SCREEN.md` の生成

指示書 §「動作確認手順」項目20で `IMPL_LOG_TEMPLATE.md` の型に沿った `IMPL_LOG_BASE_SCREEN.md` の生成が完了条件に含まれている。実装完了時に**別ファイルで**生成する。`IMPL_LOG_TEMPLATE.md` の場所・型は未確認のため、実装フェーズで `res://docs/03_log/` を覗いて確認する。

### 7-3. `tests/` 配下の検証用シーン

指示書 §「検証用の呼び出し方」で「`res://tests/` に検証用シーンを作るか、`base_screen.gd` に一時的なデバッグ用の入力処理を足してよい。**検証用コードを本番シーンに残さないこと。**」と指示がある。完了条件6〜10を検証するために `_input` ハンドラでキー入力（`g` で `add_gold(100)` 等）を受ける方式が現実的。

**解釈**: `res://tests/base_screen_debug.tscn` を作り、その中で `BaseScreen` をインスタンス化して表示する方式を採る。`base_screen.gd` 本体には検証用コードを残さない（AGENTS.md の「実験的な機能はダミー実装と明示」「本番ブランチにはマージしない」方針と整合）。検証後に `res://tests/base_screen_debug.tscn` を残すか削除するかは人間の判断に委ねる。

### 7-4. `placeholder_screen.gd` への「仮画面である」コメント

指示書 §3 実装上の注意に「このシーンは本番画面ではなく仮の受け皿であることをスクリプト冒頭のコメントに明記する」とある。これは明示済みなので、§7 の「追加で必要」リストではなく**実装時の遵守事項**として対応する。

### 7-5. `MaterialEntry` 内の NameLabel 配置

指示書 §5-4 は「`HBoxContainer`（名前は `MaterialEntry`）/ `NameLabel` (Label) / `Value`（resource_display.tscn を instantiate）」と階層を定めている。`NameLabel` の幅や alignment、`MaterialEntry` 自身の `custom_minimum_size` については指示が無い。

**解釈**: `NameLabel` の `text` には `tr("ui_res_" + material_id)` の結果（既知の素材IDなら「建築素材」、未知なら「ui_res_ore」のようなキー文字列）を入れる。`horizontal_alignment` は未指定（Left 既定）。`MaterialEntry` 自身にも `custom_minimum_size` は指定しない。`ResourceDisplay` の `Icon` 未設定の見た目は 24×24 の空 TextureRect となる（既存仕様）。視覚的に整うかは実装時に観察し、必要なら `NameLabel` に `custom_minimum_size.x` を設けて折り返しを防ぐ程度。

### 7-6. `pending_chests_changed` の受信タイミングと `_ready()` 接続順

`_ready()` 内で `GameManager.pending_chests_changed.connect(...)` を呼ぶ前に `get_pending_chest_count()` を呼んで ChestBadge の初期表示を行う。シグナル接続はその直後。接続前に「シグナルが飛んで初期値と食い違う」事故を避けるため、`_ready()` の最後にまとめて `_connect_signals()` を呼ぶ構成にする（指示書 §5-1 / §5-2 の流れと一致）。

## 8. 人間による決定事項（実装時はここを最優先で従うこと）

本PRE_PLANは人間のレビューを経て承認済み。§1〜§7の方針は基本的にそのまま
実装してよいが、以下が §1〜§7 の記述と矛盾する場合は **この §8 を優先する。**

### 8-1.【要修正】placeholder_screen の Layout を CenterContainer で包む

§2-5 の `Layout (VBoxContainer) anchors_preset = 8` は**そのままだと表示されない
可能性が高い。** Control を親 Control の直下に置くと size が (0,0) になり、
center プリセットでも offset が 0 のままで潰れる。
`IMPL_LOG_UI_COMMON.md` §5-2 で DialogBase が実際に踏んだ罠と同じもの。

対応：以下の階層にする。

PlaceholderScreen (Control) # full rect
├─ Background (ColorRect) # full rect
└─ CenterContainer # full rect (anchors_preset = 15)
└─ Layout (VBoxContainer)
├─ TitleLabel
└─ BackButton


中央寄せは `CenterContainer` に担当させる（`dialog_base.tscn` と同じ方式）。
`Layout` 自身には anchors を設定しない。

### 8-2.【要修正】§6-5 の match 方式は破棄する

§3-4 / §3-7 で `_navigation_buttons: Dictionary` 方式が既に決まっているのに、
§6-5 で `match_button_to_screen_id()` という別案を出して未決にしている。
**§3-7 の Dictionary 方式で確定。** match 関数は作らないこと。

### 8-3.【要修正】不要な定数を削る

- `PRIMARY_BUTTON_SCENE` の preload（§3-2）は**削除する。**
  MaterialEntry は NameLabel と ResourceDisplay だけで、PrimaryButton を使わない。
  「使うかもしれないので preload」はしない
- `BASE_PATH`（§3-2）は `base_screen.gd` ではなく
  **`placeholder_screen.gd` 側の定数にする。** 拠点自身は自分へ戻らない

### 8-4.【要修正】separation の矛盾を解消する

§2-2 は `Layout` に `separation = 8` と書き、§6-1 は「外側 Layout は指定なし」と
書いていて矛盾している。**外側 `Layout` には separation を指定しない**（§6-1が正）。
`BottomLayout` と `NavigationButtons` の `separation = 8` はそのまま採用する。

### 8-5.【明確化】非表示にするのは ChestBadge 自体

§2-4 のコメントが `ChestCountLabel` の行に付いていて紛らわしい。
0件のときに `visible = false` にするのは **`ChestBadge`（Button）自体**であり、
`ChestCountLabel` ではない。§3-6 の記述が正しい。

### 8-6.【情報提供】IMPL_LOG_TEMPLATE.md の場所

§7-2 で「場所・型は未確認」とあるが、
`res://docs/02_exec/IMPL_LOG_TEMPLATE.md` に存在する。実装完了後、この型に沿って
`res://docs/03_log/IMPL_LOG_BASE_SCREEN.md` を生成すること。

### 8-7.【対応不要】PLAN_BASE_SCREEN.md の同期

§7-1 の懸念は解消済み。`PLAN_BASE_SCREEN.md` は人間が修正済みで、
`PLAN_BASE_SCREEN_DIFF.md` は存在しない（差分ではなく全文を差し替えた）。
実装側は PLAN を確認する必要はなく、`EXEC_BASE_SCREEN.md` と本ファイルだけを見ればよい。

### 8-8. 検証用シーンは残す

§7-3 の `res://tests/base_screen_debug.tscn` は**削除せず残す。**
完了条件6〜10（add_gold / add_material / spend_stamina / add_pending_chest）を
後から再検証できるようにするため。`base_screen.gd` 本体には検証用コードを残さない
という方針はそのまま守ること。

### 8-9. そのまま採用する判断

以下は人間が確認済み。記述どおり実装してよい：
§5（stamina の max 取得。get_state() 経由で正しい）、
§3-7（ボタンと screen_id の Dictionary 対応表）、
§4（ja.csv の最終形。重複なし）、
§6-2、§6-3、§6-4、§6-6〜§6-11、§7-4、§7-5、§7-6
