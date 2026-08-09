# 【実装計画】スタミナポーション

対象指示書: `res://docs/02_exec/EXEC_STAMINA_POTION.md`
実装先: `D:/pomodoro-heroes`
作成方針: 二段構えのうち【A】計画段階のドキュメント。コードは書かない。人間が確認・修正後に【C】人間による決定事項を末尾へ追記し、【D】実装へ進む。

---

## 1. 作成・変更するファイル一覧

### 1-1. 新規作成

なし。すべて既存ファイルの追記・編集で完結する。

### 1-2. 既存の書き換え

| ファイル | 変更内容 | 既存要素を消すか |
|---|---|---|
| `res://scripts/utils/state_keys.gd` | 末尾に `POTION_FOCUS_REMAINDER` / `ITEM_STAMINA_POTION` の2定数を追加（EXEC §1） | 消さない（追記のみ） |
| `res://resources/balance/pomodoro_config.gd` | 末尾に `@export var potion_focus_minutes_per_unit: int = 25` と `@export var stamina_potion_recovery: int = 50` を2行追加（EXEC §2-1） | 消さない（追記のみ） |
| `res://resources/balance/pomodoro_config.tres` | `[resource]` セクション末尾に `potion_focus_minutes_per_unit = 25` と `stamina_potion_recovery = 50` を2行追加。`stamina_per_focus_minute` を `0.2` → `0.0` に書き換え（EXEC §2-2） | `presets` / `chest_contents` / `protection_*` などの参照行は残す。`stamina_per_focus_minute` 行はフィールドを残して値だけ変更 |
| `res://autoload/game_manager.gd` | `_empty_state_template()` に `POTION_FOCUS_REMAINDER: 0` を1行追加（EXEC §3-1）。`grant_stamina_potions(focus_minutes: int) -> int` / `get_stamina_potion_count() -> int` / `use_stamina_potion() -> bool` の3関数を新規追加（EXEC §3-2〜§3-4） | 既存関数のシグネチャは変更しない。`add_stamina` は触らない |
| `res://scenes/pomodoro/pomodoro.gd` | `_return_to_base()` の中身のみを差し替え。`stamina_reward` / `reward_data` の組み立てを `grant_stamina_potions` 呼び出し + 空 `apply_pomodoro_rewards({})` に置換。`claim_pending_chests` / `SceneManager.change_scene` は据え置き（EXEC §4） | `_return_to_base` 以外の関数・定数は変更しない。完走・途中終了の分岐を新たに作らない |
| `res://scenes/base/base_screen.tscn` | `ResourceRow` 内の `MaterialsDisplay` と `Spacer` のあいだに `PotionEntry`（HBoxContainer）を追加。中身は `NameLabel`（text="ui_res_stamina_potion"） + `Value`（resource_display.tscn のインスタンス） + `UseButton`（primary_button.tscn のインスタンス、label_key="ui_base_use_potion"）（EXEC §5-1） | 既存ノード（GoldEntry / StaminaEntry / MaterialsDisplay / Spacer / ChestBadge / SaveButton / BackToTitleButton）は消さない。挿入位置だけ追加 |
| `res://scenes/base/base_screen.gd` | `PotionEntry` の子ノードへの `@onready` 参照を3つ追加。`_ready()` で `get_stamina_potion_count()` を初期表示。`_connect_signals()` で `GameManager.inventory_changed` を購読。`_on_inventory_changed(item_id)` を新規追加し、`item_id == ITEM_STAMINA_POTION` のときだけ所持数ラベルと `UseButton.disabled` を更新。`_on_use_potion_pressed()` を追加し `use_stamina_potion()` を呼ぶ（EXEC §5-2） | 既存ハンドラ `_on_resource_changed` / `_on_material_changed` などのロジックは変更しない |
| `res://localization/ja.csv` | 末尾に `ui_res_stamina_potion,スタミナポーション` と `ui_base_use_potion,使う` の2行を追記（EXEC §6） | 既存行は消さない（追記のみ） |

### 1-3. 触らないもの

- `res://autoload/` 配下の `game_manager.gd` 以外（`balance.gd` / `save_manager.gd` / `scene_manager.gd` / `signal_bus.gd`）
- `res://resources/balance/initial_state_config.tres`（`max: 100` / `current: 20` のまま。EXEC「やらないこと」明記）
- `project.godot` の `[input]` セクション（Input Map の変更禁止）
- `res://addons/` 配下
- `res://docs/` 配下の設計ドキュメント（`PLAN_*` / `DATA_SCHEMA.md` / `CONCEPT.md` など。AIは指示されたもの以外読み書きしない）
- `res://scenes/ui/components/resource_display.tscn` / `primary_button.tscn`（インスタンス化して使うだけ）
- `res://scripts/utils/transfer_keys.gd`

## 2. GameManager に追加する3関数の実装方針

追加位置は `res://autoload/game_manager.gd` の `# --- ポモドーロ報酬 ---` セクション（apply_pomodoro_rewards の付近）に固まりとして置く。`_empty_state_template` への追加は既存の返却 Dictionary 末尾付近（POMODORO 系のキー群のそば）に行う。

### 2-1. `grant_stamina_potions(focus_minutes: int) -> int`

引数と戻り値の役割:
- `focus_minutes`: 今回のセッションで確定した作業分（`session_accumulated_focus_min` の値そのもの）
- 戻り値: 付与したポーション個数（0 のこともある）

処理の流れ（EXEC §3-3 を実装手順に展開）:

1. `Balance.pomodoro.potion_focus_minutes_per_unit` を `unit_per_min` に読み出す。**`unit_per_min <= 0` の場合は `push_warning("[GameManager] grant_stamina_potions: invalid potion_focus_minutes_per_unit=%d" % unit_per_min)` を出して 0 を返す**。ゼロ除算防止のため、状態は書き換えない。
2. 現在の端数を `var remainder: int = int(_state.get(GameStateKeys.POTION_FOCUS_REMAINDER, 0))` で取得。
3. `var total_min: int = int(focus_minutes) + remainder`（整数演算）。
4. `var count: int = total_min / unit_per_min`（GDScript の int 除算で切り捨て）。
5. `var new_remainder: int = total_min % unit_per_min`。
6. 端数を `_state[GameStateKeys.POTION_FOCUS_REMAINDER] = new_remainder` で書き戻す。**Dictionary の単純代入なので `_copy_dict` は不要**（トップレベルキー直下の int）。
7. `count > 0` のときだけ `add_to_inventory(GameStateKeys.ITEM_STAMINA_POTION, count, GameStateKeys.ITEM_TYPE_CONSUMABLE)` を呼ぶ。`item_type` を省略せず `ITEM_TYPE_CONSUMABLE` を必ず明示する（EXEC §3-3 末尾の注意）。
8. `print("[GameManager] grant_stamina_potions(focus_minutes=%d, prev_remainder=%d) -> count=%d, new_remainder=%d" % [...])` を出す（完了条件 §5 の検証用）。
9. `count` を返す。

`add_to_inventory` 経由にすることで、初出時の `codex.discovered = true` 自動付与と `inventory_changed` シグナル発火を既存実装に任せられる。

### 2-2. `get_stamina_potion_count() -> int`

`INVENTORY[ITEM_STAMINA_POTION][ITEM_COUNT]` を返すだけのゲッター。

実装:
```
var inventory: Dictionary = _state.get(GameStateKeys.INVENTORY, {})
if not inventory.has(GameStateKeys.ITEM_STAMINA_POTION):
	return 0
var entry: Dictionary = inventory[GameStateKeys.ITEM_STAMINA_POTION]
return int(entry.get(GameStateKeys.ITEM_COUNT, 0))
```

- `get_state()` ではなく `_state` を直接参照する。読み取り専用で副作用なし、`duplicate(true)` のコストを払う必要がないため
- 該当アイテム未取得（エントリなし）でも 0 を返す。Dictionary の `has` チェックを必ず行う

### 2-3. `use_stamina_potion() -> bool` — `add_stamina()` を使わずにスタミナを増やす具体手順

ここが指示書で最重要注意喚起されている箇所。`add_stamina()` は `max` で切り捨てるため使えない（EXEC §3-4, §0-3）。

処理の流れ:

1. 所持数チェック: `var count: int = get_stamina_potion_count()`. **`count <= 0` なら `print("[GameManager] use_stamina_potion() -> false (no potion)")` を出して `false` を返す。** 何も変更しない。
2. インベントリから1個減らす。**ネストした Dictionary のため `_copy_dict` で複製してから書き換える**（既存パターン `add_to_inventory` / `add_material` と同じ流儀。AGENTS.md「ネスト更新時の複製ルール」）。
   ```
   var inventory: Dictionary = _copy_dict(GameStateKeys.INVENTORY)
   var entry: Dictionary = (inventory[GameStateKeys.ITEM_STAMINA_POTION] as Dictionary).duplicate(true)
   entry[GameStateKeys.ITEM_COUNT] = int(entry.get(GameStateKeys.ITEM_COUNT, 0)) - 1
   if int(entry[GameStateKeys.ITEM_COUNT]) <= 0:
	   inventory.erase(GameStateKeys.ITEM_STAMINA_POTION)  # 0個になったらエントリ削除
   else:
	   inventory[GameStateKeys.ITEM_STAMINA_POTION] = entry
   _state[GameStateKeys.INVENTORY] = inventory
   ```
   - **エントリ削除を採用する**。`CODEX` は別キー（`CODEX[ITEM_STAMINA_POTION][CODEX_DISCOVERED]`）なので影響しない（指示書 §3-4 のただし書き適合）
   - 0個で残しておくと `_on_inventory_changed` 側で「所持数0」のときに Value を再描画する際に紛らわしい。エントリ削除のほうがシンプル
3. `inventory_changed.emit(GameStateKeys.ITEM_STAMINA_POTION)` を発火する。
4. **ここが `add_stamina()` を使わない核心。** STAMINA を直接加算する:
   ```
   var stamina: Dictionary = _copy_dict(GameStateKeys.STAMINA)
   var current: int = int(stamina.get(GameStateKeys.STAMINA_CURRENT, 0))
   current += int(Balance.pomodoro.stamina_potion_recovery)
   # max で切り捨てない（EXEC §0-3 決定事項）
   stamina[GameStateKeys.STAMINA_CURRENT] = current
   _state[GameStateKeys.STAMINA] = stamina
   ```
   - `add_stamina` のコード（行 125-137）と違い、`if current > max_stamina: current = max_stamina` の行を**書かない**。`max: 100, current: 60` のときに飲むと `current: 110` になる（完了条件 §10 の `130/100` 相当ケース）
5. `resource_changed.emit(GameStateKeys.STAMINA, current)` を発火する。`current` だけ（`max` を含まない。AGENTS.md のシグナル表の注意書きどおり）。
6. `print("[GameManager] use_stamina_potion() -> true (count=%d, current=%d)" % [...])` を出して `true` を返す。

### 2-4. 共通: 追加位置と import / preload

- `PomodoroConfig` クラスは `class_name` 経由で `Balance.pomodoro.potion_focus_minutes_per_unit` のようにアクセス可能。追加 import / preload は不要
- `GameStateKeys` も `class_name` 経由、AGENTS.md 命名規則どおり文字列リテラル禁止
- 既存 `add_to_inventory` のシグネチャと副作用を信頼して使い回す。**新規にインベントリ書き込みパスを増やさない**（二重実装禁止）

## 3. 端数の計算例（指示書 §0-2 の動作追跡）

`potion_focus_minutes_per_unit = 25`（.tres に書く値）。整数除算 / 剰余で端数管理する実装が指示書の例を満たすか、初期状態 `POTION_FOCUS_REMAINDER = 0` から順番に追う。

### 3-1. 1回目: 60分 → 2個 + 端数10分

| ステップ | 計算 | 結果 |
|---|---|---|
| 入力 | `focus_minutes = 60` | — |
| 端数取得 | `remainder = 0`（初期値） | 0 |
| 合計分 | `total_min = 60 + 0` | 60 |
| 個数 | `count = 60 / 25` | **2** |
| 新端数 | `new_remainder = 60 % 25` | **10** |
| 状態書き込み | `_state[POTION_FOCUS_REMAINDER] = 10` | 端数 = 10 |
| インベントリ | `add_to_inventory("stamina_potion", 2, "consumable")` | count = 2 |
| 戻り値 | 2 | 2 |

→ 指示書 §0-2 の「2個（50分ぶん）、残り10分は次回へ」と一致。✅

### 3-2. 2回目: 40分 → 2個 + 端数0分

| ステップ | 計算 | 結果 |
|---|---|---|
| 入力 | `focus_minutes = 40` | — |
| 端数取得 | `remainder = 10`（1回目で保存） | 10 |
| 合計分 | `total_min = 40 + 10` | 50 |
| 個数 | `count = 50 / 25` | **2** |
| 新端数 | `new_remainder = 50 % 25` | **0** |
| 状態書き込み | `_state[POTION_FOCUS_REMAINDER] = 0` | 端数 = 0 |
| インボントリ | `add_to_inventory("stamina_potion", 2, "consumable")` | count = 4（累計） |
| 戻り値 | 2 | 2 |

→ 「合計50分で2個、残り0分」と一致。✅ 端数の持ち越しが効いている。

### 3-3. 3回目: 10分 → 0個 + 端数10分（境界ケース）

| ステップ | 計算 | 結果 |
|---|---|---|
| 入力 | `focus_minutes = 10` | — |
| 端数取得 | `remainder = 0`（2回目で保存） | 0 |
| 合計分 | `total_min = 10 + 0` | 10 |
| 個数 | `count = 10 / 25` | **0** |
| 新端数 | `new_remainder = 10 % 25` | **10** |
| 状態書き込み | `_state[POTION_FOCUS_REMAINDER] = 10` | 端数 = 10 |
| インベントリ | 呼ばれない（`count == 0` ガード） | 変化なし |
| 戻り値 | 0 | 0 |

→ 完了条件 §7「`10` を入れて実行すると0個で、端数だけが増える（ポーションが増えないこと）」と一致。✅ かつ `add_to_inventory` を呼ばないので `inventory_changed` も発火しない（過剰通知防止）。

### 3-4. 4回目: 0分（フォーカスなしで完走）→ 0個、副作用なし

| ステップ | 計算 | 結果 |
|---|---|---|
| 入力 | `focus_minutes = 0` | — |
| 端数取得 | `remainder`（任意の値） | 変化なしを期待 |
| 合計分 | `total_min = 0 + remainder` | remainder そのまま |
| 個数 | `count = remainder / 25` | 0（端数 < 25 のとき）または端数÷25 ぶん |
| 新端数 | `new_remainder = remainder % 25` | remainder そのまま |
| 状態書き込み | `_state[POTION_FOCUS_REMAINDER] = remainder` | 端数変化なし |

→ `focus_minutes = 0` でも `grant_stamina_potions(0)` は安全に動く。完了条件 §13 と一致。✅

### 3-5. 25分ぴったりの単体投入

| ステップ | 計算 | 結果 |
|---|---|---|
| 入力 | `focus_minutes = 25` | — |
| 端数 | `remainder = 0` | 0 |
| 合計 | 25 | 25 |
| 個数 | `25 / 25 = 1` | **1** |
| 新端数 | `25 % 25 = 0` | **0** |

→ 完了条件 §4「25 を入れて実行し…ポーションを1個獲得」と一致。✅

### 3-6. 異常系: `potion_focus_minutes_per_unit = 0`（バランサー設定ミス）

- `unit_per_min <= 0` ガードで `push_warning` を出して 0 を返す
- 端数も書き換えない、`_state` には触らない
- `Balance` の値が壊れた状態で無限ループやクラッシュしない

→ ゼロ除算回避の安全弁。指示書 §3-3 末尾のガードに一致。

### 3-7. まとめ

整数除算 / 剰余による「端数持ち越し」方式は指示書の例（60分→2+10、40分→2+0、10分→0+10、25分→1+0、0分→0）をすべて満たす。`grant_stamina_potions` の実装に落とし込んでよい。

## 4. `base_screen.tscn` への追加と、`base_screen.gd` の変更点

### 4-1. シーンへの挿入手順（既存ノードを消さない）

挿入位置: ResourceRow（HBoxContainer）のうち MaterialsDisplay（行 69-70）と Spacer（行 72-74）のあいだ。

.tscn ファイルへの追記形式。[node name="MaterialsDisplay" ...] ブロックの直後・[node name="Spacer" ...] ブロックの直前に、次の3ノードを挿入する:

[node name="PotionEntry" type="HBoxContainer" parent="Layout/BottomArea/BottomLayout/ResourceRow"]
layout_mode = 2

[node name="NameLabel" type="Label" parent="Layout/BottomArea/BottomLayout/ResourceRow/PotionEntry"]
layout_mode = 2
text = "ui_res_stamina_potion"

[node name="Value" parent="Layout/BottomArea/BottomLayout/ResourceRow/PotionEntry" instance=ExtResource("2_resource_dsp")]
layout_mode = 2

[node name="UseButton" parent="Layout/BottomArea/BottomLayout/ResourceRow/PotionEntry" instance=ExtResource("3_button")]
layout_mode = 2
label_key = "ui_base_use_potion"

ポイント:
- unique_id 属性は付けない（Godot 4.x で optional。既存ノードに付いているのは過去ツールの生成物。再現性のため付けないほうが無難）
- parent="..." のパスは Layout/BottomArea/BottomLayout/ResourceRow/PotionEntry で PotionEntry を親に指定する。3つの子は同じ親を持つ
- Value ノードは instance=ExtResource("2_resource_dsp") で resource_display.tscn のインスタンスを参照。既存 GoldEntry/Value、StaminaEntry/Value と同じ id="2_resource_dsp" を使い回せる
- UseButton は instance=ExtResource("3_button")、label_key = "ui_base_use_potion" を override する。既存 SaveButton、BackToTitleButton の label_key 指定と同じ流儀
- text = "ui_res_stamina_potion" は翻訳キー直書き。auto_translate_mode = AUTO_TRANSLATE_MODE_INHERIT がデフォルトで効くため tr() と同等

挿入後の兄弟順:
ResourceRow
├─ GoldEntry
├─ StaminaEntry
├─ MaterialsDisplay
├─ PotionEntry（追加）
├─ Spacer
├─ ChestBadge
├─ SaveButton
└─ BackToTitleButton

挿入で Spacer 以降の x 座標はそのまま右にズレる。Spacer は size_flags_horizontal = 3（EXPAND_FILL）なので UI レイアウト的には吸収される（新規作成・既存維持の影響なし）。

### 4-2. base_screen.gd への変更

#### 追加する @onready 参照（2つ）

既存 @onready 群（行 25-32 の gold_value、stamina_value など）の末尾、# 内部状態 コメントの直前に追加:

@onready var potion_value: ResourceDisplay = $Layout/BottomArea/BottomLayout/ResourceRow/PotionEntry/Value
@onready var potion_use_button: PrimaryButton = $Layout/BottomArea/BottomLayout/ResourceRow/PotionEntry/UseButton

> 「3つ」と言いつつ2つしか書かないのは、NameLabel にはスクリプトから触らない（翻訳キー直書きで auto_translate に任せる）ため。アクセスする必要があるノードだけが @onready の対象。

#### _ready() への追加

_init_resource_displays(state) の最後（スタミナ反映の直後）に追記:

# ポーション
potion_value.set_value(GameManager.get_stamina_potion_count())
potion_use_button.disabled = (GameManager.get_stamina_potion_count() <= 0)

#### _connect_signals() への追加

GameManager.pending_chests_changed.connect(_on_pending_chests_changed) の直後に追加:

GameManager.inventory_changed.connect(_on_inventory_changed)
potion_use_button.pressed.connect(_on_use_potion_pressed)

#### 新規ハンドラ: _on_inventory_changed(item_id: String) -> void

inventory_changed はあらゆる消費アイテム・装備追加で発火する（add_to_inventory 内の inventory_changed.emit(item_id) 由来）ため、item_id で絞り込まないとポーション以外の入手でもポーション表示が書き換わってしまう。

実装:
func _on_inventory_changed(item_id: String) -> void:
	if item_id != GameStateKeys.ITEM_STAMINA_POTION:
		return
	var count: int = GameManager.get_stamina_potion_count()
	potion_value.set_value(count)
	potion_use_button.disabled = (count <= 0)

> 早期 return 必須。item_id != ITEM_STAMINA_POTION のときは何もしない。指示書 §5-2「他のアイテムのシグナルで所持数を書き換えないこと」を遵守。

#### 新規ハンドラ: _on_use_potion_pressed() -> void

func _on_use_potion_pressed() -> void:
	if GameManager.use_stamina_potion():
		return
	# false 返却時（所持なし）は何もしない。
	# 表示更新は _on_inventory_changed と _on_resource_changed(STAMINA) 経由で自動反映されるため、
	# ここで直接ラベルを書き換えてはいけない（指示書 §5-2 末尾）
	pass

- _ready() の disabled ガードがあるので通常ここには来ないが、連打や複数シグナルの競合で表示更新前に押される可能性に備えた形
- pass は明示的に「何もしない」を示すため。コメントで意図を説明

#### 変更しない箇所

- _on_resource_changed の STAMINA ブランチ（行 108-113）: 既存どおり set_value_with_max(current, max) を呼ぶ。use_stamina_potion が 110/100 を発火しても、このロジックでそのまま表示され、100/100 には丸めない（指示書 §5-3 厳守）
- _init_materials / _on_material_changed: 触らない
- ナビゲーションボタン系: 触らない

## 5. 既存ファイルを壊さないための手順

AGENTS.md「編集後の確認」と指示書「既存の行と重複させないこと」「編集後は read で開く」を守る。具体的な bash コマンドと確認観点。


### 5-1. res://scripts/utils/state_keys.gd

追記コマンド:

cat >> "D:/pomodoro-heroes/scripts/utils/state_keys.gd" << 'EOF'

\# スタミナポーション
const POTION_FOCUS_REMAINDER: String = "potion_focus_remainder"
const ITEM_STAMINA_POTION: String = "stamina_potion"
EOF

確認手順:
  1. read ツールで res://scripts/utils/state_keys.gd を開く
  2. 既存の const がすべて残っていることを目視で確認。具体的には GOLD、GEMS、STAMINA、MATERIALS、INVENTORY、ITEM_TYPE_CONSUMABLE、SCREEN_POMODORO など、依存するキーが消えていないこと
  3. 末尾に POTION_FOCUS_REMAINDER と ITEM_STAMINA_POTION の2行が追記されていること
  4. ファイル全体の行数が 192行 から 196行付近になっていること（行数ずれの早期検出）
  5. ファイル先頭の class_name GameStateKeys と extends RefCounted が変わっていないこと

### 5-2. res://resources/balance/pomodoro_config.gd

追記コマンド:

cat >> "D:/pomodoro-heroes/resources/balance/pomodoro_config.gd" << 'EOF'

@export var potion_focus_minutes_per_unit: int = 25
@export var stamina_potion_recovery: int = 50
EOF

確認手順:
  1. read ツールで res://resources/balance/pomodoro_config.gd を開く
  2. 既存 @export 群（行 7-21 の protection_light から session_title_max_length まで）がすべて残っていること
  3. ファイル先頭の class_name PomodoroConfig と extends Resource が変わっていないこと
  4. 末尾に potion_focus_minutes_per_unit と stamina_potion_recovery の2行が追記されていること

### 5-3. res://resources/balance/pomodoro_config.tres

このファイルは [resource] ブロックの構造を持つため、cat >> だとブロック終端の後に追記される形になり、Godot が正しく読めない可能性が高い。代わりに bash の sed を使い、

  - stamina_per_focus_minute = 0.2 を stamina_per_focus_minute = 0.0 に置換
  - [resource] ブロック内の最終行（session_title_max_length = 30）の直後に2行を挿入

する方針。具体的なコマンド:

  \# 1) 0.2 → 0.0 への書き換え
  sed -i 's/^stamina_per_focus_minute = 0\.2$/stamina_per_focus_minute = 0.0/' \
    "D:/pomodoro-heroes/resources/balance/pomodoro_config.tres"

  \# 2) session_title_max_length = 30 の直後に2行挿入
  sed -i '/^session_title_max_length = 30$/a\
potion_focus_minutes_per_unit = 25\
stamina_potion_recovery = 50
  ' "D:/pomodoro-heroes/resources/balance/pomodoro_config.tres"

> sed コマンドは Windows + Git Bash / WSL 環境を想定。Ziva の bash ツールが MSYS2 系のシェルであれば動作する想定だが、動作が疑わしい場合は人間に確認する。

確認手順:
  1. read ツールで res://resources/balance/pomodoro_config.tres を開く
  2. stamina_per_focus_minute = 0.0 になっていること
  3. potion_focus_minutes_per_unit = 25 と stamina_potion_recovery = 50 が追記されていること
  4. presets 行（3件）と chest_contents 行（4件）がそのまま残っていること
  5. すべての ext_resource 参照（行 3-8）と sub_resource ブロック（行 10-63）が消えていないこと
  6. Godot エディタでファイルを開き直し、Inspector で PomodoroConfig リソースの値を確認。presets 配列に3件、chest_contents 配列に4件が表示されること（完了条件 §2）

### 5-4. res://localization/ja.csv

追記コマンド（UTF-8 BOM なしを維持）:

cat >> "D:/pomodoro-heroes/localization/ja.csv" << 'EOF'
ui_res_stamina_potion,スタミナポーション
ui_base_use_potion,使う
EOF

> cat >> は BOM を付けない。BOM 付きだと1行目のキーが ¥ufeffkeys になり全滅する（AGENTS.md）。Windows の > リダイレクトは UTF-8 で BOM なしで書き出す（Git Bash / MSYS2 のリダイレクト）。念のため、head -c 3 ja.csv を xxd に通して efbbbf が先頭にないことを確認する。

確認手順:
  1. read ツールで res://localization/ja.csv を開く
  2. 既存の ui_title_label,ポモドーロヒーローズ から ui_pomodoro_break_skip,休憩をスキップ まで全行が残っていること
  3. 末尾に ui_res_stamina_potion,スタミナポーション と ui_base_use_potion,使う の2行が追記されていること
  4. ファイル行数が 63行 から 65行付近になっていること（行数ずれの早期検出）
  5. Godot の FileSystem パネルで ja.csv を再インポート（または Godot 再起動）。再インポートしないと画面に反映されない（AGENTS.md「翻訳キーの運用」）
  6. 拠点画面を開き、PotionEntry のラベルが「スタミナポーション」、「使う」ボタンが「使う」と表示されていることを確認（完了条件 §15 後半）

### 5-5. res://autoload/game_manager.gd

追記位置が決まっている（# --- ポモドーロ報酬 --- の前）ため、apply_pomodoro_rewards 関数の直前にマーカー行を置いて挿入する。

追記コマンド（_empty_state_template への1行と、3関数の追加。指示書 §3-1, §3-2 を一気に追記する）:

> このファイルは指示書で関数の形が完全指定されているため、cat >> ではなく指示書どおりの文字列を cat >> 形式でファイル末尾に追記する。既存関数の間にはさまない（行番号でアンカーが壊れる）。

確認手順:
  1. read ツールで res://autoload/game_manager.gd を開く
  2. 既存の add_stamina、spend_stamina、add_to_inventory、add_pending_chest、apply_pomodoro_rewards などのシグネチャが変わっていないこと
  3. _empty_state_template 内に POTION_FOCUS_REMAINDER: 0 が追加されていること
  4. 末尾に grant_stamina_potions、get_stamina_potion_count、use_stamina_potion の3関数が追加されていること
  5. ファイル冒頭の signal 宣言群（行 11-17）が変わっていないこと
  6. 行数が 605行 から約 660-680行になっていること（3関数ぶんおよそ60-80行追加）

### 5-6. 共通の最終確認

全ファイル編集後に以下を実施:
  1. Godot エディタで Project → Reload Current Project を実行（クラスパスの class_name 解決を再走させる）
  2. Output パネルに [GameManager] _ready() — initializing from Balance.initial_state がエラーなく出ていることを確認
  3. 拠点画面を開き、PotionEntry のラベルが「スタミナポーション」、Value が 0、UseButton が disabled で表示されていること
  4. ポモドーロ画面のデバッグパネルで「25」を加算 → 「このフェーズを終わらせる」連打で完走 → 拠点画面で Value: 1、UseButton: enabled になっていること

## 6. 判断に迷った点（「特になし」は避ける）

### 6-1. sed コマンドのシェル依存性

pomodoro_config.tres への2行挿入は cat >> では [resource] ブロックの構造を壊す懸念があり、sed を使う計画を立てた（5-3 節）。ただし sed -i のインライン編集は Windows + Git Bash / MSYS2 と WSL、PowerShell で挙動が違う可能性がある。Ziva の bash ツールがどのシェルで動いているかが未確定のため、実装時に sed が期待どおり動くか最初の1回で必ず確認する。動かない場合は python -c "..." での書き換えか、Godot エディタで .tres を開いて手動編集する手順に切り替える（この判断は実装フェーズで確定する。AGENTS.md「同じ箇所を3回以上直す必要が出た場合は実装を止め、設計を見直す」に従い、sed で詰まるようなら人間に相談する）。

### 6-2. ポーションの「0個エントリ」削除ポリシー

use_stamina_potion 内で所持数が0になったとき、INVENTORY から該当 item_id のエントリ自体を erase する方針にした（セクション 2-3 手順2）。代わりに「count=0 のエントリを残して所持0とみなす」設計もある。残すほうは:
  - 長所: 図鑑の discovered と挙動が完全同期する。item_id ベースのクエリが常にヒットする
  - 短所: 拠点画面側で count==0 のとき Value を 0 と表示するために get_stamina_potion_count() が count==0 を返さなければならず、ガードが増える
削除するほうは:
  - 長所: get_stamina_potion_count() が has チェック1回でよく、コードが単純
  - 短所: 「過去に取得したことがあるが今は持っていない」状態と「一度も取得したことがない」状態が INVENTORY のキー有無だけで区別できなくなる

今回は **削除する方針**を採用する。理由は (a) CODEX キーとは別で、図鑑の discovered は影響を受けないこと、(b) get_stamina_potion_count() をシンプルにしたいこと、(c) 後で倉庫画面で「履歴」を出したくなった場合は REACHED_CHEST_THRESHOLDS のような別キーで管理する方が責務が分離できる、の3点。ただしこの判断は将来「所持0のアイテムも図鑑リストに出したい」要件が出たときに見直しが必要。PRE_PLAN 末尾の「人間による決定事項」章で再確認したい。

### 6-3. grant_stamina_potions の端数リセット方針

指示書 §0-2 で「端数はリセットしない」と明記されており、reset_daily_pomodoro_state_if_needed で累計作業分・しきい値・加護選択が日付変更でリセットされるのとは対照的に、potion_focus_remainder は永続される実装になる。

この非対称（累計は毎日0に戻るが端数は持ち越される）は、ユーザーの作業リズムに依存する形で設計が分岐している。日付をまたいで持ち越すことで「昨日20分やって、今日5分やれば25分到達」のような体験になる。設計意図としては自然だが、ユーザーが「昨日の分も含めて25分に到達」と感じるか「今日の分だけで判定してくれている」と感じるかは、UI 上で端数を見せない以上、伝わりにくい。

実装上はシンプル（reset 関数に potion_focus_remainder を追加しないだけ）なのでこのまま進める。判断を再考するきっかけとしては、指示書の §0-2 が改めて「リセットしない」と書いてあるので、AI 側で勝手に「リセットすべき」と提案しない。

### 6-4. BaseScreen の _on_inventory_changed の配置と _ready 初期化の順序

onready var potion_value と _ready() 内の potion_value.set_value(...) は必ず @onready 解決後、すなわち Godot のシーンツリー構築完了後に走る。_ready の中で GameManager.get_stamina_potion_count() を呼んでも、その時点では GameManager 側の _ready はすでに走っているはず（Autoload はシーンより先に初期化される）なので安全。

しかし、もし「拠点画面が直接インスタンス化されて GameManager 初期化前に _ready が走る」テスト経路があった場合、GameManager が _state をまだ持っていないケースが考えられる。現在のプロジェクトでは Autoload 順序が Godot 仕様で保証されているため無視できるが、テストシーン res://tests/ 配下で動かす可能性があるなら「GameManager が _state を持つまで await する」ようなガードが必要になるかもしれない。今回は体験版スコープ・テスト未着手のためガードは入れない。テストを書く段階で発覚したら人間に相談する。

### 6-5. grant_stamina_potions のシグナル発火タイミング

add_to_inventory は内部で inventory_changed.emit(item_id) を発火する。grant_stamina_potions は count > 0 のときだけ add_to_inventory を呼ぶので、count == 0 のときは inventory_changed が飛ばない（セクション 3-3 で確認）。一方、拠点画面では potion_value.set_value は count==0 のときも実行したい（ポーションを1個使って所持0に戻ったとき _on_inventory_changed 経由で count==0 が来る）ので、count>0 ガードは適切。

もし将来「grant_stamina_potions を呼んだこと自体を画面側で検知したい」要件が出たら、専用のシグナルを切る必要がある。今は未要件なので追加しない。

### 6-6. POMODORO シグナルとの二重発火防止

指示書 §3-4 と §4 を読み合わせると、pomodoro_session_completed は apply_pomodoro_rewards が GameManager 内で1回だけ発火する（AGENTS.md「シグナル Bus の発火元は GameManager に一本化」）。今回 apply_pomodoro_rewards({}) を空 Dictionary で呼ぶことになるが、reward_data に REWARD_STAMINA を含めないため add_stamina は呼ばれず、指示書 §3-4 の「add_stamina() を使わないでください」と矛盾しない。

ただし apply_pomodoro_rewards 内で total_pomodoro_completed +1 と last_pomodoro_end_at の更新は引き続き走る。grant_stamina_potions よりもこちらが「セッション完了」の指標として扱われており、ダブルカウントや取りこぼしは起きないことを確認した。total_pomodoro_completed は add_stamina の有無とは独立にインクリメントされるため、ポーション方式でも統計上は整合する。

### 6-7. 人間による決定事項（このPRE_PLANを実装に移す前に確認したいこと）

- 6-2 の「0個エントリ削除 vs 残す」: 削除方針で進めて良いか
- 5-3 の sed コマンドで .tres を編集する方針で良いか、それとも Godot エディタで .tres を開いて手動編集したほうが安全か
- 拠点画面の PotionEntry の配置（MaterialsDisplay と Spacer のあいだ、指示書 §5-1 の図どおり）で良いか。画面幅が狭くて窮屈な場合に備えて _ready 後の確認もしたい

## 7. 人間による決定事項（実装時はここを最優先で従うこと）

§1〜§6 と矛盾する場合は **この §7 を優先する。**

### 7-1.【要修正】.tres と _empty_state_template() は人間が編集する

§5-3 の sed による .tres 編集は**行わないこと。** シェル依存で動作が保証されず、
このファイルは過去にAIの編集で中身が失われた事故がある。

以下は**人間がGodotエディタで実施済み**とする。実装側は触らないこと：
- pomodoro_config.tres の stamina_per_focus_minute = 0.0
- pomodoro_config.tres の potion_focus_minutes_per_unit = 25
- pomodoro_config.tres の stamina_potion_recovery = 50
- game_manager.gd の _empty_state_template() への
  POTION_FOCUS_REMAINDER: 0 の追加

実装側がやるのは pomodoro_config.gd への @export 2行の追記まで。

### 7-2.【承認】0個エントリは削除する

§6-2 の判断でよい。CODEX は別キーなので図鑑の discovered は消えない。
将来「所持0のアイテムも一覧に出したい」要件が出たら見直す。

### 7-3.【承認】端数は日付をまたいでも持ち越す

§6-3 のとおり。reset_daily_pomodoro_state_if_needed に
potion_focus_remainder を追加しないこと。

### 7-4.【承認】@onready は2つ

§4-2 の指摘が正しい。NameLabel はスクリプトから触らないため
@onready の対象外。指示書 §5-2 の「3つ」は誤り。

### 7-5.【明確化】PotionEntry の配置は指示書どおり

§6-7 の3点目について。MaterialsDisplay と Spacer のあいだで進めてよい。
窮屈になったら人間がGodotで調整するので、実装側で位置を変えないこと。

### 7-6. そのまま採用する判断

§2（3関数の実装方針）、§3（端数の計算例）、§4（シーンとスクリプトの変更）、
§5-1・§5-2・§5-4（state_keys.gd / pomodoro_config.gd / ja.csv への追記）、
§6-4、§6-5、§6-6
