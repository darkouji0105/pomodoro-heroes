# 【実行指示書】拠点画面（下部：リソース表示と遷移ボタン）

第3層・実行指示書。この指示書はAI（Ziva等）にそのまま渡して実装させることを想定している。

---

## 前提・参照ドキュメント

実装前に必ず以下を読むこと。ここに書かれていないやり方は勝手に採用しない。

- `AGENTS.md`：フォルダ構造・命名規則・状態構造の表・Autoloadの登録順・翻訳キーの運用
- `PLAN_BASE_SCREEN.md`：この実行指示書のもとになった第2層の作戦計画書

### 既存の実装状況（実コードで確認済み・推測しないこと）

以下は**実際のコードを読んで確認した事実**である。この通りに呼び出すこと。

| 対象 | 実際のシグネチャ・挙動 |
|---|---|
| `GameManager.get_state()` | `_state.duplicate(true)` のスナップショットを返す。書き換えても内部状態に影響しない |
| `GameManager.resource_changed` | `(resource_type: String, new_value: Variant)`。`resource_type` は `GameStateKeys.GOLD` / `GEMS` / `STAMINA` |
| **`resource_changed`（STAMINA時）の第2引数** | **`stamina.current` の `int` 単体。辞書ではない。`max` は含まれない**（後述 §5-3） |
| `GameManager.material_changed` | `(material_id: String, new_amount: int)` |
| `GameManager.screen_unlocked` | `(screen_id: String)` |
| `GameManager.pending_chests_changed` | `(pending_count: int)` |
| `GameManager.get_pending_chest_count()` | `opened == false` の件数を返す |
| `GameManager.is_screen_unlocked(screen_id)` | `bool` を返す |
| `SceneManager.change_scene(scene_path)` | 履歴を積んで遷移 |
| `SceneManager.change_scene_with_data(scene_path, data)` | `_transfer_data` をセットしてから遷移 |
| `SceneManager.consume_transfer_data()` | 取り出すと同時に空になる |
| `SaveManager.save_game()` | `bool` を返す。`SaveManager.SAVE_PATH` は `const` で公開されている |
| `ResourceDisplay`（共通パーツ） | `HBoxContainer`。子は `Icon`（TextureRect）と `ValueLabel`（Label）のみ。**名前ラベルは持たない**。`set_value(int)` / `set_value_with_max(current, max)` |
| `PrimaryButton`（共通パーツ） | `Button`。`@export var label_key: String` に翻訳キーを入れると `tr()` を通した文字列が表示される |
| `res://scenes/base/base_screen.tscn` / `.gd` | **仮シーンとして既に存在する。今回これを置き換える**（新規作成ではない） |

`GameManager` は「`initially_unlocked_screens = ["guild", "adventure_select", "pomodoro", "settings", "scenario"]`」で初期化済み（`initial_state_config.tres`）。よって新規開始時から遷移ボタン5つはすべて表示される状態になる。

---

## 0. 人間による決定事項（最優先・§1以降と矛盾する場合はここを優先）

本タスクの方針は人間のレビューを経て確定済み。以下は**変更しないこと**。

### 0-1.【確定】gems は表示しない

`PLAN_BASE_SCREEN.md` の階層案には `GemsLabel` があるが、**今回は作らない。**
理由：体験版に gems を増やす手段が一つも無く、常に 0 のまま表示され続けるため。
`GameManager` 側には `add_gems()` と `resource_changed(GEMS, ...)` が既にあるので、必要になった時点で1エントリ足せば済む。
`PLAN_BASE_SCREEN.md` 側も同時に修正する（別紙 `PLAN_BASE_SCREEN_DIFF.md`）。

### 0-2.【確定】上部エリア（施設・キャラ）は今回作らない

上部は**空の `Control` ノードを置いて名前だけ付けておく**。中身（施設の描画・キャラのアニメーション・タップ判定）は次の拠点タスクで作る。
これに伴い、`PLAN_BASE_SCREEN.md` の完了条件「施設・キャラタップで `SignalBus` にシグナルが発火する」は**今回のスコープから外す**（PLAN側も修正する）。
`SignalBus.facility_tapped` / `character_tapped` は定義済みのまま、発火元なしで据え置く。

### 0-3.【確定】遷移先はすべて「未実装画面」1つに集約する

ギルド・冒険選択・ポモドーロ・設定・シナリオのシーンはまだ存在しない。
5つの空シーンを作るのではなく、**`res://scenes/ui/placeholder_screen.tscn` を1つだけ作り、`screen_id` を渡して表示を切り替える。**

理由：
- 今回の検証対象は「拠点画面が正しく描画・更新・遷移するか」であり、飛び先が本物である必要がない
- 空シーンを5つ残すと、後続タスクで「既存を書き換えるのか新規で作るのか」が曖昧になる
- `change_scene_with_data()` / `consume_transfer_data()` を本番導線で初めて通す機会になる

**必須の条件**：後で本物のシーンに差し替えるとき拠点側のコードを触らずに済むよう、**遷移先は `screen_id → シーンパス` の対応表（定数 `Dictionary`）1箇所に集約する**（§5-5）。ボタンごとにパスを直書きしないこと。

### 0-4.【確定】セーブボタンとタイトルへ戻るボタンは残す

オートセーブが未実装のため、**セーブボタンを消すとゲームがセーブ不能になる。**
仮シーンにあった `SaveButton` / `BackToTitleButton` を下部に残す。
保存タイミング（オートセーブ）を設計するタスクが来たら外す前提であることを、スクリプトのコメントに明記すること。

---

## 今回のタスク

拠点画面の**下部**（リソース表示＋遷移ボタン）を実装し、仮シーンを本実装に置き換える。

### やること
- `GameStateKeys` に画面ID定数5つを追加
- `TransferKeys` に `SCREEN_ID` を追加
- `ja.csv` に不足キーを追加（既存キー1つのリネームを含む）
- `res://scenes/base/base_screen.tscn` / `.gd` の**置き換え**
- `res://scenes/ui/placeholder_screen.tscn` / `.gd` の新規作成

### やらないこと
- **上部エリアの中身**（施設・キャラの描画、タップ判定、`SignalBus` の発火）。空の `Control` を置くだけ
- **gems の表示**
- `notification_label.tscn`（キャラタップ時の吹き出し）。上部エリアと同じ次タスク送り
- 素材が3種類以上になった場合の折り返し・スクロールレイアウト（`PLAN_BASE_SCREEN.md` 7章の未確定事項。現状1種類のため今回は決めない）
- 遷移先5画面の中身の実装
- `res://autoload/` 配下の既存ファイルの変更（**`state_keys.gd` / `transfer_keys.gd` は `res://scripts/utils/` 配下なので対象外。追記してよい**）
- `main_theme.tres` の変更
- オートセーブ・保存タイミングの設計

---

## 1. 定数の追加

### 1-1. `res://scripts/utils/state_keys.gd`

**末尾に追記する。既存の定数は一切変更しないこと。**

```gdscript
# 画面ID（UNLOCKED_SCREENS のキー、および画面遷移の識別子）
# DATA_SCHEMA.md「1. 拠点（共通データ）」の unlocked_screens に対応。
# initial_state_config.tres の initially_unlocked_screens と綴りを一致させること。
const SCREEN_GUILD: String = "guild"
const SCREEN_ADVENTURE_SELECT: String = "adventure_select"
const SCREEN_POMODORO: String = "pomodoro"
const SCREEN_SETTINGS: String = "settings"
const SCREEN_SCENARIO: String = "scenario"
```

`ITEM_TYPE_EQUIPMENT` や `SHOP_TYPE_DAILY` と同じく「キーではなく値」の定数だが、既存の前例に合わせて同じファイルに置く。

### 1-2. `res://scripts/utils/transfer_keys.gd`

現在は空。以下を追記する。

```gdscript
# 未実装画面（placeholder_screen）へ、どの画面のつもりで来たかを渡すためのキー。
# 値には GameStateKeys.SCREEN_* を入れる。
const SCREEN_ID: String = "screen_id"
```

---

## 2. `res://localization/ja.csv` への追加

**UTF-8（BOMなし）で保存すること。** BOM付きだと1行目のキーが壊れて全滅する。

### 2-1. リネーム（1行）

既存の行を書き換える。

| 変更前 | 変更後 |
|---|---|
| `ui_nav_adventure,冒険` | `ui_nav_adventure_select,冒険` |

理由：翻訳キーを `"ui_nav_" + screen_id` で機械的に組み立てられるようにするため。`screen_id` は `adventure_select` なので、キー側も揃える。既存の `ui_nav_adventure` はどこからも参照されていないため、リネームして問題ない。

### 2-2. 追加（3行）

```
ui_placeholder_suffix,（未実装）
ui_base_chest,宝箱
ui_res_material_unknown,不明な素材
```

`ui_res_gold` / `ui_res_stamina` / `ui_res_construction_material` / `ui_nav_guild` / `ui_nav_pomodoro` / `ui_nav_settings` / `ui_nav_scenario` / `ui_base_save` / `ui_base_back_to_title` は**すでに存在する。重複行を作らないこと。**

### 2-3. 編集後の必須作業

CSVを編集しただけでは反映されない。FileSystemパネルで `ja.csv` を選び、右クリック → 再インポート（またはGodotを再起動）すること。
**Project Settings → Localization → Translations に `res://localization/ja.translation` が登録されていること**も確認する。未登録の場合は追加する。

---

## 3. `res://scenes/ui/placeholder_screen.tscn` / `.gd`（新規）

まだ実装していない画面の共通の受け皿。

```
PlaceholderScreen (Control)          # full rect
├─ Background (ColorRect)            # Color(0.101961, 0.0784314, 0.0941176, 1) = #1A1418
└─ Layout (VBoxContainer)            # 中央配置
	├─ TitleLabel (Label)
	└─ BackButton (primary_button.tscn のインスタンス、label_key = "ui_common_back")
```

### 挙動

1. `_ready()` で `SceneManager.consume_transfer_data()` を呼び、`TransferKeys.SCREEN_ID` を取り出す
2. `TitleLabel` に `tr("ui_nav_" + screen_id) + tr("ui_placeholder_suffix")` を表示する
   - 例：`screen_id == "guild"` → 「ギルド（未実装）」
3. `screen_id` が空、またはキーが取れなかった場合は `tr("ui_placeholder_suffix")` のみを表示する（クラッシュさせない）
4. `BackButton` 押下 → `SceneManager.change_scene("res://scenes/base/base_screen.tscn")` で拠点へ戻る

### 実装上の注意

- `SceneManager.go_back()` は使わない。履歴管理がダミー実装（`scene_manager.gd` のコメント参照）で挙動が保証されていないため、明示的に拠点のパスを指定する
- このシーンは**本番画面ではなく仮の受け皿**であることをスクリプト冒頭のコメントに明記する

---

## 4. `res://scenes/base/base_screen.tscn`（置き換え）

**既存の仮シーンを置き換える。** ノード名は `PLAN_BASE_SCREEN.md` 3章の階層案に準拠する（差異は下記の注記のとおり）。

```
BaseScreen (Control)                      # full rect
├─ Background (ColorRect)                 # #1A1418
└─ Layout (VBoxContainer)                 # full rect
	├─ TopArea (Control)                  # size_flags_vertical = EXPAND_FILL。中身は空
	└─ BottomArea (PanelContainer)        # custom_minimum_size.y = 160
		└─ BottomLayout (VBoxContainer)
			├─ ResourceRow (HBoxContainer)          # 高さ 56 目安
			│   ├─ GoldEntry (HBoxContainer)
			│   │   ├─ NameLabel (Label)            # text = "ui_res_gold"
			│   │   └─ Value (resource_display.tscn のインスタンス)
			│   ├─ StaminaEntry (HBoxContainer)
			│   │   ├─ NameLabel (Label)            # text = "ui_res_stamina"
			│   │   └─ Value (resource_display.tscn のインスタンス)
			│   ├─ MaterialsDisplay (HBoxContainer) # MaterialEntry を動的生成
			│   ├─ Spacer (Control)                 # size_flags_horizontal = EXPAND_FILL
			│   ├─ ChestBadge (Button)
			│   │   └─ ChestCountLabel (Label)
			│   ├─ SaveButton (primary_button.tscn)         # label_key = "ui_base_save"
			│   └─ BackToTitleButton (primary_button.tscn)  # label_key = "ui_base_back_to_title"
			└─ NavigationButtons (HBoxContainer)     # 高さ 104 目安
				├─ AdventureButton (primary_button.tscn)   # label_key = "ui_nav_adventure_select"
				├─ GuildButton (primary_button.tscn)       # label_key = "ui_nav_guild"
				├─ PomodoroButton (primary_button.tscn)    # label_key = "ui_nav_pomodoro"
				├─ SettingsButton (primary_button.tscn)    # label_key = "ui_nav_settings"
				└─ ScenarioButton (primary_button.tscn)    # label_key = "ui_nav_scenario"
```

### PLANの階層案との差異（意図的・理由あり）

| PLAN案 | 本指示書 | 理由 |
|---|---|---|
| `ResourceDisplay`（コンテナ名） | `ResourceRow` | 共通パーツの `class_name ResourceDisplay` と同名で紛らわしいため |
| `GoldLabel` / `StaminaLabel` | `GoldEntry` / `StaminaEntry`（名前ラベル＋`ResourceDisplay`の組） | `ResourceDisplay` は `Icon` と `ValueLabel` しか持たず、**名前を出す手段が無い**。アイコン画像が未用意の現状、数字だけが並んで何の値か分からなくなるため、名前ラベルを外側で持たせる |
| `GemsLabel` | なし | §0-1 の決定による |
| `ChestIcon` | `ChestBadge` 自体を `Button` にする | アイコン画像が未用意のため。テクスチャができたら `TextureButton` に差し替える |

### レイアウトの数値（1280×720基準）

- `BottomArea` の高さ：160（`custom_minimum_size.y = 160`）
- `ResourceRow` と `NavigationButtons` の比率は 56 : 104 を目安とする
- `NavigationButtons` の各ボタンは `size_flags_horizontal = EXPAND_FILL` で等幅に広げる
- `ChestBadge` は `Spacer` を挟んで右側に置き、リソース表示と視覚的に分離する（所持数ではなく画面遷移の導線であるため）

### 実装上の注意

- `NameLabel` の `text` には**翻訳キーをそのまま入れる**（例：`ui_res_gold`）。Godotの `Control.auto_translate` が有効なため、表示時に自動で翻訳される。既存の `base_screen.tscn` の `PlaceholderLabel` も同じ方式になっている
- 色は `Background` の `ColorRect` を除きハードコードしない。`main_theme.tres` 経由にする
- `resource_display.tscn` / `primary_button.tscn` は**インスタンスとして配置**する。中身をコピーしない

---

## 5. `res://scenes/base/base_screen.gd`（置き換え）

### 5-1. 初期表示（`_ready()`）

`GameManager.get_state()` を1回だけ呼び、以下を初期化する。

- `gold` → `GoldEntry/Value.set_value(int)`
- `stamina.current` / `stamina.max` → `StaminaEntry/Value.set_value_with_max(current, max)`
- `materials` の各キー → `MaterialEntry` を生成（§5-4）
- `unlocked_screens` → 各遷移ボタンの `visible`（`GameManager.is_screen_unlocked(screen_id)` を使う）
- `GameManager.get_pending_chest_count()` → `ChestBadge`（§5-6）

### 5-2. シグナル購読

`_ready()` で以下を接続し、**該当箇所のみ差分更新する**。画面に戻るたびに全部作り直さないこと。

| シグナル | やること |
|---|---|
| `GameManager.resource_changed` | `resource_type` を見て分岐。`GameStateKeys.GOLD` なら gold を更新、`GameStateKeys.STAMINA` なら §5-3 の手順。`GEMS` は今回無視する（表示していないため） |
| `GameManager.material_changed` | 該当 `MaterialEntry` のみ更新。未生成なら新規生成（§5-4） |
| `GameManager.screen_unlocked` | 該当ボタンの `visible = true` |
| `GameManager.pending_chests_changed` | §5-6 |

**`resource_type` を文字列リテラルで比較しないこと。** 必ず `GameStateKeys.GOLD` 等の定数と比較する。

### 5-3.【重要】stamina の max の扱い

`resource_changed(STAMINA, ...)` の第2引数は **`current` の `int` 単体で、`max` を含まない**（`game_manager.gd` 127行・139行で確認済み）。
一方 `ResourceDisplay.set_value_with_max()` は `max` を必要とする。

**そのまま `set_value_with_max(new_value, 0)` と書くと `10/0` と表示される。これは典型的な事故なので必ず避けること。**

対応：`resource_changed` で `STAMINA` を受け取ったら、`GameManager.get_state()` から `stamina.max` を読み直してから `set_value_with_max(new_value, max)` を呼ぶ。

```gdscript
if resource_type == GameStateKeys.STAMINA:
	var state: Dictionary = GameManager.get_state()
	var stamina: Dictionary = state.get(GameStateKeys.STAMINA, {})
	var stamina_max: int = int(stamina.get(GameStateKeys.STAMINA_MAX, 0))
	stamina_value.set_value_with_max(int(new_value), stamina_max)
```

`get_state()` は `duplicate(true)` の全体コピーを返すため軽い処理ではないが、stamina の変化頻度は低く、`max` を通知する手段が現状 GameManager に無いためこの方式を採る。
**この経緯を `IMPL_LOG` の「5. 指示書からの逸脱・迷った判断」に転記すること。** 将来 `max` を変更する機能（研究・施設強化等）が入ったら、GameManager 側に `max` を含む通知を追加して差し替える必要がある。

### 5-4. 素材エントリ（`MaterialEntry`）の動的生成

`materials` は種類が増える想定のため、`.tscn` に決め打ちで並べず、スクリプトから生成する。

- 生成物：`HBoxContainer`（名前は `MaterialEntry`）
  - `NameLabel` (Label)：`tr("ui_res_" + material_id)` の結果を `text` に入れる
  - `Value`：`resource_display.tscn` を `preload` して `instantiate()`
- 生成した `MaterialEntry` は `material_id` をキーにした `Dictionary` で保持し、`material_changed` 受信時に**該当エントリの `Value.set_value()` だけを呼ぶ**（全エントリを作り直さない）
- `material_changed` で未知の `material_id` が来たら、その場で新規エントリを生成して追加する
- 翻訳キーが `ja.csv` に無い場合、`tr()` はキー文字列をそのまま返す（例：`ui_res_ore`）。**これは意図した挙動**として許容する。素材を追加したときに `ja.csv` への追記漏れが画面上ですぐ分かるため。フォールバック処理は入れないこと

### 5-5.【重要】遷移先の対応表

**ボタンごとにシーンパスを直書きしないこと。** 以下の定数1箇所に集約する。

```gdscript
const PLACEHOLDER_PATH: String = "res://scenes/ui/placeholder_screen.tscn"

# screen_id → 遷移先シーンパス。
# 各画面が実装できたら、この表の該当行を本物のパスに差し替えるだけでよい。
# ボタン側のコードは触らないこと。
const SCREEN_SCENES: Dictionary = {
	GameStateKeys.SCREEN_ADVENTURE_SELECT: PLACEHOLDER_PATH,
	GameStateKeys.SCREEN_GUILD: PLACEHOLDER_PATH,
	GameStateKeys.SCREEN_POMODORO: PLACEHOLDER_PATH,
	GameStateKeys.SCREEN_SETTINGS: PLACEHOLDER_PATH,
	GameStateKeys.SCREEN_SCENARIO: PLACEHOLDER_PATH,
}
```

各遷移ボタンの押下時は、共通のハンドラで以下を行う：

```gdscript
func _go_to_screen(screen_id: String) -> void:
	var path: String = str(SCREEN_SCENES.get(screen_id, ""))
	if path == "":
		push_warning("[BaseScreen] unknown screen_id: %s" % screen_id)
		return
	SceneManager.change_scene_with_data(path, {TransferKeys.SCREEN_ID: screen_id})
```

- **`get_tree().change_scene_to_file()` を直接呼ばない。** 必ず `SceneManager` 経由
- ボタンと `screen_id` の対応も、`Dictionary` かループで持たせて5回同じコードを書かないこと

### 5-6. チェストバッジ

- 表示件数：`pending_chests_changed(pending_count)` の値をそのまま `ChestCountLabel` に入れる
- 初期表示：`_ready()` で `GameManager.get_pending_chest_count()` を呼ぶ
- **件数が 0 のときは `ChestBadge` 自体を非表示にする**（`visible = false`）
- タップ時：`_go_to_screen(GameStateKeys.SCREEN_GUILD)` を呼ぶ。倉庫は現状ギルド配下であり、単独のシーンがまだ無いため、ギルドの遷移先を共用する
- 受け取り処理（開封演出・報酬付与）は倉庫画面側のタスクで扱う。ここでは遷移のトリガーのみ

### 5-7. セーブ・タイトルへ戻る（仮）

- `SaveButton` 押下 → `SaveManager.save_game()` を呼ぶ。戻り値を `print` に出す
- `BackToTitleButton` 押下 → `SceneManager.change_scene("res://scenes/title/title_screen.tscn")`
- **この2つはオートセーブが未実装の間の暫定措置であることを、スクリプトのコメントに明記すること**

---

## 動作確認手順（完了条件）

以下をすべて満たしたら完了とする。

1. `res://scenes/base/base_screen.tscn` が §4 の階層どおりに作られており、旧仮シーンの内容が残っていない
2. F5（メインシーン実行）でタイトル画面から「はじめから」を押すと拠点画面に遷移し、下部に gold・stamina・建築素材が表示される
3. 表示が `gold 100` / `stamina 10/10` / `建築素材 5` になっている（`initial_state_config.tres` の値）。**`10/0` になっていないこと**
4. リソース名が「ゴールド」「スタミナ」「建築素材」と日本語で表示されている（`ui_res_gold` のようなキー名がそのまま出ていない＝`ja.csv` の再インポートとLocalization登録ができている）
5. 遷移ボタン5つが「冒険 / ギルド / ポモドーロ / 設定 / シナリオ」と日本語で表示され、等幅で並んでいる
6. 任意のノードから `GameManager.add_gold(100)` を呼ぶと、`GoldEntry` の数値だけが自動で更新される（画面の再構築が起きていないこと）
7. `GameManager.add_material("construction_material", 3)` を呼ぶと、該当 `MaterialEntry` のみが更新される
8. `GameManager.add_material("test_ore", 1)` のように**未知の素材IDを渡すと、新しい `MaterialEntry` が動的に追加される**（ラベルは `ui_res_test_ore` とキーのまま出てよい）
9. `GameManager.spend_stamina(3)` を呼ぶと表示が `7/10` になる（`max` が 0 に化けないこと）
10. `pending_chests` が0件のとき `ChestBadge` が非表示、`GameManager.add_pending_chest({...})` を呼ぶと表示され件数が出る
11. `ChestBadge` を押すとギルドの遷移先（未実装画面）へ遷移する
12. 遷移ボタン5つがそれぞれ未実装画面へ遷移し、**画面名が「ギルド（未実装）」のようにボタンごとに変わる**
13. 未実装画面の「戻る」ボタンで拠点画面に戻れる
14. `GameManager.unlock_screen()` を使わずに `initially_unlocked_screens` から1つ削って起動すると、対応するボタンが非表示になる（確認後、値は元に戻すこと）
15. `SaveButton` を押すと `save_game()` が呼ばれ、`true` が出力される
16. 画面遷移がすべて `SceneManager` 経由であり、`change_scene_to_file()` の直接呼び出しが `scene_manager.gd` 以外に無いことを `grep` で確認できる
17. `resource_type` の比較が文字列リテラルではなく `GameStateKeys` の定数経由になっていることをコードレビューで確認できる
18. 遷移先のシーンパスが `SCREEN_SCENES` の1箇所にのみ書かれており、ボタンごとに直書きされていないことをコードレビューで確認できる
19. `.gd` / `.tscn` に色コード（`#C4453A` 等）の直書きが無い（`Background` の `ColorRect` を除く）
20. `IMPL_LOG_TEMPLATE.md` の型に沿って `res://docs/03_log/IMPL_LOG_BASE_SCREEN.md` が生成されている

### 検証用の呼び出し方

項目6〜10は、`res://tests/` に検証用シーンを作るか、`base_screen.gd` に一時的なデバッグ用の入力処理を足して確認してよい。**検証用コードを本番シーンに残さないこと。** 残す場合は `res://tests/` 配下に隔離する。

---

## 遵守事項（AGENTS.mdより再掲）

- 変数・関数・ファイル名は snake_case、`class_name` とノード名は PascalCase、シグナルは過去形にする
- 状態のキーは文字列リテラルではなく `GameStateKeys` の定数を使う（**ネストしたキーも含む**）
- `_state` を直接書き換えない。`GameManager` の関数を経由する。`get_state()` の返り値はスナップショットであり、書き換えても内部状態には反映されない
- 全ての表示テキストは `tr()`（または `auto_translate` が効く `text` への翻訳キー）を経由する。日本語をハードコードしない。数値のみの表示は対象外
- 色・フォントは個別シーンにハードコードせず、Theme経由にする（背景の `ColorRect` は例外）
- 画面遷移は必ず `SceneManager` 経由
- `res://addons/` と `res://autoload/` の既存ファイルには無断で触れない（`res://scripts/utils/` への追記は本指示書で許可済み）
- 新しいフォルダが必要になった場合は、勝手に作らず人間に提案してから作成する
- Autoload を追加しない（5つ固定）
- Input Map（`project.godot` の `[input]`）は変更しない
- 同じ箇所を3回以上直す必要が出た場合は実装を止め、設計を見直す
