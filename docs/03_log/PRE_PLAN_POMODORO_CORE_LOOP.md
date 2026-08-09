# PRE_PLAN_POMODORO_CORE_LOOP.md

`EXEC_POMODORO_CORE_LOOP.md` を読んだ上での実装前計画。実装は別フェーズで行う。
指示書 §0「人間による決定事項」を最優先とする（§1以降と矛盾したら §0 を優先）。

---

## 1. 作成・変更するファイル一覧（パスと役割）

### 1-1. 新規作成

| パス | 役割 |
|---|---|
| `res://resources/balance/chest_schedule_entry.gd` | `ChestScheduleEntry`。加護1件の宝箱スケジュール（`threshold_min` + `chest_type`）。指示書 §1-1 |
| `res://resources/balance/chest_content_config.gd` | `ChestContentConfig`。`chest_type` 1種の中身（今回は建築素材のみ）。指示書 §1-3 |
| `res://resources/balance/protection_light.tres` | 加護ライトの `ProtectionTypeConfig`。schedule: `[{45, "bonus_small"}]`。指示書 §2 |
| `res://resources/balance/protection_middle.tres` | 加護ミドル。schedule: `[{45, "generic"}, {90, "bonus_medium"}]` |
| `res://resources/balance/protection_hard.tres` | 加護ハード。schedule: `[{45, "generic"}, {90, "generic"}, {135, "generic"}, {180, "bonus_large"}]` |
| `res://scripts/utils/game_date.gd` | `GameDate` ヘルパー（毎朝4:00基準の日付判定）。指示書 §5 |
| `res://scenes/pomodoro/pomodoro.tscn` | 4ビューを `CurrentViewContainer` 配下に置く親シーン。指示書 §6 |
| `res://scenes/pomodoro/pomodoro.gd` | `PomodoroController` の状態機械 + タイマー減算 + 報酬計算 + 帰還処理。指示書 §7 |
| `res://scenes/pomodoro/protection_select_view.tscn` | 加護選択ビュー（1日1回）。指示書 §6 / §7-2 |
| `res://scenes/pomodoro/protection_select_view.gd` | 同上スクリプト |
| `res://scenes/pomodoro/focus_view.tscn` | 作業（フォーカス）ビュー。指示書 §6 / §7-3 |
| `res://scenes/pomodoro/focus_view.gd` | 同上スクリプト |
| `res://scenes/pomodoro/reflection_view.tscn` | 振り返りビュー（120秒タイマー + 20文字以上）。指示書 §6 / §7-4 |
| `res://scenes/pomodoro/reflection_view.gd` | 同上スクリプト |
| `res://scenes/pomodoro/break_view.tscn` | 休憩ビュー（短/長 自動切替 + Skip）。指示書 §6 / §7-5 |
| `res://scenes/pomodoro/break_view.gd` | 同上スクリプト |
| `res://tests/pomodoro_core_loop_debug.tscn` | 検証用シーン（短秒数のプリセットで一通り通す）。指示書「検証用の呼び出し方」 |
| `res://tests/pomodoro_core_loop_debug.gd` | 同上スクリプト（`base_screen_debug.tscn` 方式を踏襲） |
| `res://docs/03_log/IMPL_LOG_POMODORO_CORE_LOOP.md` | 実装完了後に `IMPL_LOG_TEMPLATE.md` の型で生成 |

### 1-2. 既存ファイルの書き換え

| パス | 変更内容 | 対応する指示 |
|---|---|---|
| `res://resources/balance/protection_type_config.gd` | 倍率フィールド4つを全廃し、`@export var schedule: Array[ChestScheduleEntry]` 1本に作り替え | §1-2 |
| `res://resources/balance/pomodoro_config.gd` | 末尾に `chest_contents: Array[ChestContentConfig]` と `session_title_max_length: int` を追記 | §1-4 |
| `res://resources/balance/pomodoro_config.tres` | 空 → §0-5 の値を完全投入（presets 3件・加護3種・換算レート・範囲・chest_contents 4件・session_title_max_length=30） | §2 |
| `res://resources/balance/initial_state_config.tres` | `starting_stamina_max` 10→100、`starting_stamina_current` 10→20 | §0-4 |
| `res://scripts/utils/state_keys.gd` | 末尾に11個の定数追記（§3の表どおり。既存の定数は触らない） | §3 |
| `res://autoload/game_manager.gd` | ① `_empty_state_template()` に5キー追加、② `add_stamina()` を max 切り捨てに変更、③ §4-3 の関数8つを追加 | §4-1 / §4-2 / §4-3 |
| `res://localization/ja.csv` | §8 の22行を追加。既存行は触らない（`ui_nav_pomodoro` は既存） | §8 |

### 1-3. 触らないもの（明示的に禁止）

- `res://autoload/balance.gd` / `res://autoload/balance.tscn` … `pomodoro_config.tres` を差し替えれば `Balance.pomodoro` から値が引ける。Autoload登録順を壊さない
- `res://autoload/save_manager.gd` / `res://autoload/scene_manager.gd` / `res://autoload/signal_bus.gd`
- `res://addons/` 配下、Ziva 本体
- `res://theme/main_theme.tres`
- `project.godot` の `[input]` セクション
- `res://scenes/base/base_screen.tscn` / `res://scenes/base/base_screen.gd` … 既に `scenes/pomodoro` 行は `PLACEHOLDER_PATH` になっている。今回これを実体 `res://scenes/pomodoro/pomodoro.tscn` に差し替えるかどうかは §9 で迷う
- `res://scenes/title/title_screen.tscn` / `.gd`
- 既存の `res://scripts/utils/state_keys.gd` の定数（**追加のみ。値変更・削除しない**）
- 既存の `res://autoload/game_manager.gd` の関数シグネチャ（**`add_stamina` の内部処理変更のみ許可**）

---

## 2. Config クラスの最終的な定義

### 2-1. `ChestScheduleEntry`（新規・指示書 §1-1 そのまま）

```gdscript
class_name ChestScheduleEntry
extends Resource

# 加護の宝箱スケジュール1件分。
# 「その日の累計作業分が threshold_min に達したら chest_type の宝箱がもらえる」を表す。

@export var threshold_min: int
@export var chest_type: String
```

### 2-2. `ProtectionTypeConfig`（作り替え後・指示書 §1-2）

**削除するフィールド（現行 `protection_type_config.gd` 8〜11行目を全廃）**：

| 削除する `@export` | 型 | 理由 |
|---|---|---|
| `threshold_min` | `int` | 旧：単一しきい値。新：schedule 配列のエントリごとに持つ |
| `bonus_multiplier` | `float` | 旧：加護の報酬倍率。§0-1 で倍率廃止 |
| `before_multiplier` | `float` | 同上 |
| `after_multiplier` | `float` | 同上 |

**残す／新規追加するフィールド**：

```gdscript
class_name ProtectionTypeConfig
extends Resource

# 加護1種の宝箱スケジュール（DATA_SCHEMA.md 2-3準拠）。
# 加護は報酬倍率ではなく「いつ・どの宝箱がもらえるか」だけを決める。
# しきい値はその日の累計作業分で判定する（1セッションではない）。

@export var schedule: Array[ChestScheduleEntry]
```

### 2-3. `ChestContentConfig`（新規・指示書 §1-3 そのまま）

```gdscript
class_name ChestContentConfig
extends Resource

# chest_type 1種ぶんの中身。
# 現状は建築素材のみ。レア素材・レシピ・装飾が実装されたら項目を増やす。

@export var chest_type: String
@export var materials: Dictionary   # material_id -> 個数
```

### 2-4. `PomodoroConfig`（追記後）

**既存のフィールドはそのまま残す**（指示書 §1-4「倍率は`ProtectionTypeConfig`側にあった」ため削除不要）。
**追記する2フィールド**（ファイル末尾に追加）：

```gdscript
@export var chest_contents: Array[ChestContentConfig]
@export var session_title_max_length: int
```

追記後の全 `@export` 順：

| 順 | 名前 | 型 | 用途 |
|---|---|---|---|
| 1 | `protection_light` | `ProtectionTypeConfig` | 既存 |
| 2 | `protection_middle` | `ProtectionTypeConfig` | 既存 |
| 3 | `protection_hard` | `ProtectionTypeConfig` | 既存 |
| 4 | `gold_per_focus_minute` | `float` | 既存（値は0のまま・§0-2） |
| 5 | `stamina_per_focus_minute` | `float` | 既存（0.2 を入れる） |
| 6 | `materials_per_focus_minute` | `float` | 既存（値は0のまま・§0-2） |
| 7 | `presets` | `Array[PomodoroPreset]` | 既存（short/standard/long を入れる） |
| 8 | `min_sets` | `int` | 既存（1） |
| 9 | `max_sets` | `int` | 既存（12） |
| 10 | `min_long_break_minutes` | `int` | 既存（5） |
| 11 | `max_long_break_minutes` | `int` | 既存（60） |
| 12 | `min_long_break_interval` | `int` | 既存（2） |
| 13 | `max_long_break_interval` | `int` | 既存（8） |
| 14 | `chest_contents` | `Array[ChestContentConfig]` | **新規** |
| 15 | `session_title_max_length` | `int` | **新規**（30） |

---

## 3. `.tres` に入れる値の一覧

### 3-1. `pomodoro_config.tres`（§0-5 / §2 を完全反映）

| プロパティ | 値 | 備考 |
|---|---|---|
| `protection_light` | `ExtResource("res://resources/balance/protection_light.tres")` | 別ファイル参照 |
| `protection_middle` | `ExtResource("res://resources/balance/protection_middle.tres")` | 別ファイル参照 |
| `protection_hard` | `ExtResource("res://resources/balance/protection_hard.tres")` | 別ファイル参照 |
| `gold_per_focus_minute` | `0.0` | §0-2（フィールド残す・値0） |
| `stamina_per_focus_minute` | `0.2` | §0-5（25分1セットで5スタミナ） |
| `materials_per_focus_minute` | `0.0` | §0-2（フィールド残す・値0） |
| `presets` | 3件のサブリソースを `[sub_resource]` で定義 | 下記3-1-1 |
| `min_sets` | `1` | §0-5 |
| `max_sets` | `12` | §0-5（shortプリセット×12でハード180分に届く） |
| `min_long_break_minutes` | `5` | §0-5 |
| `max_long_break_minutes` | `60` | §0-5 |
| `min_long_break_interval` | `2` | §0-5 |
| `max_long_break_interval` | `8` | §0-5 |
| `chest_contents` | 4件のサブリソースを `[sub_resource]` で定義 | 下記3-1-2 |
| `session_title_max_length` | `30` | §0-5（新規フィールド） |

#### 3-1-1. `presets` の中身（`PomodoroPreset` ×3）

| `preset_id` | `focus_duration_sec` | `short_break_sec` | `long_break_sec` | `long_break_interval` | `default_total_sets` |
|---|---|---|---|---|---|
| `short` | `900` | `180` | `1800` | `4` | `4` |
| `standard` | `1500` | `300` | `1800` | `4` | `4` |
| `long` | `3000` | `600` | `1800` | `4` | `3` |

#### 3-1-2. `chest_contents` の中身（`ChestContentConfig` ×4）

| `chest_type` | `materials`（Dictionary） |
|---|---|
| `generic` | `{ "construction_material": 4 }` |
| `bonus_small` | `{ "construction_material": 10 }` |
| `bonus_medium` | `{ "construction_material": 25 }` |
| `bonus_large` | `{ "construction_material": 30 }` |

### 3-2. `protection_light.tres` / `protection_middle.tres` / `protection_hard.tres`

§0-1 の表をそのまま反映する。`schedule` 配列の要素は `ChestScheduleEntry` のサブリソース。

| ファイル | `schedule` の内容（threshold_min / chest_type） |
|---|---|
| `protection_light.tres` | `[(45, "bonus_small")]` |
| `protection_middle.tres` | `[(45, "generic"), (90, "bonus_medium")]` |
| `protection_hard.tres` | `[(45, "generic"), (90, "generic"), (135, "generic"), (180, "bonus_large")]` |

### 3-3. `initial_state_config.tres`（§0-4）

| プロパティ | 変更前 | 変更後 |
|---|---|---|
| `starting_stamina_max` | `10` | `100` |
| `starting_stamina_current` | `10` | `20` |
| `starting_gold` | `100` | そのまま |
| `starting_gems` | `0` | そのまま |
| `starting_materials` | `{ "construction_material": 5 }` | そのまま |
| `initially_unlocked_screens` | `["guild", "adventure_select", "pomodoro", "settings", "scenario"]` | そのまま |
| `starting_scenario_chapter` | `1` | そのまま |
| `save_version` | `1` | そのまま |

### 3-4. `.tres` の生成方法

- **手書き禁止。** 指示書 §2 末尾と `IMPL_LOG_COMMON_INFRA.md` 逸脱5（P.137-140）に倣い、**`ResourceSaver.save()` + `PackedScene.pack()` で Godot に正しいフォーマットを出力させる。**
- 実装時は `res://tests/pomodoro_tres_gen.gd` を作り、その中で `PomodoroConfig` / `ProtectionTypeConfig` / `ChestContentConfig` / `PomodoroPreset` を `new()` して値を代入 → 各 `.tres` を `ResourceSaver.save()` で書き出す。**検証用スクリプトのため `res://tests/` 配下に置き、本番には残さない。**
- `Balance.pomodoro` の `@export` 枠に `.tres` を割り当てる作業は **不要**。`autoload/balance.tscn` は既に `pomodoro = ExtResource("res://resources/balance/pomodoro_config.tres")` 形式で参照しているため、`.tres` を上書き保存するだけで `Balance.pomodoro` から新しい値が引ける。
- `initial_state_config.tres` も同様に `ResourceSaver.save()` で上書きする。`Balance.initial_state` の参照は `autoload/balance.tscn` 7行目で固定済み。

---

## 4. `GameStateKeys`・`GameManager`・`GameDate` への追加内容

### 4-1. `GameStateKeys` に追加する定数（指示書 §3 そのまま、計11個）

末尾の「トップレベルキー」セクションに追加する。**既存の定数は一切変更しない。**

| 追加定数 | 文字列値 | 用途 |
|---|---|---|
| `CUMULATIVE_FOCUS_MINUTES_TODAY` | `"cumulative_focus_minutes_today"` | その日の累計作業分 |
| `REACHED_CHEST_THRESHOLDS` | `"reached_chest_thresholds"` | 到達済みしきい値（intの配列） |
| `UNCLAIMED_CHESTS` | `"unclaimed_chests"` | 受け取り待ち宝箱のchest_type配列 |
| `LAST_PROTECTION_SELECTED_AT` | `"last_protection_selected_at"` | 加護選択時刻（unix_timeの文字列） |
| `SELECTED_PROTECTION_TYPE` | `"selected_protection_type"` | 選択中の加護種別 |
| `PROTECTION_LIGHT` | `"light"` | 加護：ライト |
| `PROTECTION_MIDDLE` | `"middle"` | 加護：ミドル |
| `PROTECTION_HARD` | `"hard"` | 加護：ハード |
| `CHEST_TYPE_GENERIC` | `"generic"` | 宝箱：汎用 |
| `CHEST_TYPE_BONUS_SMALL` | `"bonus_small"` | 宝箱：ボーナス（小） |
| `CHEST_TYPE_BONUS_MEDIUM` | `"bonus_medium"` | 宝箱：ボーナス（中） |
| `CHEST_TYPE_BONUS_LARGE` | `"bonus_large"` | 宝箱：ボーナス（大） |
| `CHEST_SOURCE_POMODORO` | `"pomodoro"` | 宝箱の入手元 |

（`PROTECTION_*` / `CHEST_TYPE_*` / `CHEST_SOURCE_POMODORO` の3系統は「**キーの値として流通する**識別子」であり、状態キーのDictionaryの値に出てくる文字列。`STAMINA` 等と違って`get_state()`のキーとしては使わないが、文字列リテラル排除のため定数化する必要がある。`UNLOCKED_SCREENS`配下の`SCREEN_*`定数と同じ立ち位置。）

### 4-2. `_empty_state_template()` への追加（指示書 §4-1 そのまま）

```gdscript
GameStateKeys.CUMULATIVE_FOCUS_MINUTES_TODAY: 0,
GameStateKeys.REACHED_CHEST_THRESHOLDS: [],
GameStateKeys.UNCLAIMED_CHESTS: [],
GameStateKeys.LAST_PROTECTION_SELECTED_AT: "",
GameStateKeys.SELECTED_PROTECTION_TYPE: "",
```

### 4-3. `add_stamina()` の上限処理（指示書 §4-2）

現状は加算後に何の制限もしていない（`game_manager.gd` 120〜127行）。これを `max` で切り捨てる実装に差し替える。差分イメージ：

```gdscript
func add_stamina(amount: int) -> void:
	# max を超える分は切り捨てる（DATA_SCHEMA.md 1章で確定）。
	# ただし max を大きく取っているため、実質的にはほぼ発動しない。
	var stamina: Dictionary = _copy_dict(GameStateKeys.STAMINA)
	var current: int = int(stamina.get(GameStateKeys.STAMINA_CURRENT, 0))
	var max_v: int = int(stamina.get(GameStateKeys.STAMINA_MAX, 0))
	var new_current: int = current + amount
	if new_current > max_v:
		new_current = max_v
	stamina[GameStateKeys.STAMINA_CURRENT] = new_current
	_state[GameStateKeys.STAMINA] = stamina
	print("[GameManager] add_stamina(%d) -> current=%d (max=%d)" % [amount, new_current, max_v])
	resource_changed.emit(GameStateKeys.STAMINA, new_current)
```

シグネチャは変更なし（指示書 §4 冒頭「既存関数のシグネチャは変更しない」）。変数名 `max` は GDScript 予約語ではないが組み込み関数と被るため `max_v` を使う（念のため）。

### 4-4. 追加する関数（指示書 §4-3、各 1〜3 行の挙動要約）

| 関数 | 内部挙動 |
|---|---|
| `add_focus_minutes(minutes: int) -> void` | `CUMULATIVE_FOCUS_MINUTES_TODAY` を複製 → `+ minutes` → 代入。`add_stamina` 等と違い `resource_changed` 等の**シグナルは発火しない**（UI 側が監視する状態ではないため）。`_copy_dict` は不要、`int + int` のため複製は `_copy_dict` パターンに倣う |
| `get_cumulative_focus_minutes() -> int` | `_state.get(CUMULATIVE_FOCUS_MINUTES_TODAY, 0)` を `int()` で返す。読み取り専用 |
| `has_reached_threshold(threshold_min: int) -> bool` | `_state.get(REACHED_CHEST_THRESHOLDS, [])` の中に `threshold_min` が含まれていれば true。`in` 演算子で十分 |
| `record_reached_threshold(threshold_min: int, chest_type: String) -> void` | `REACHED_CHEST_THRESHOLDS` の複製に `threshold_min` を append、`UNCLAIMED_CHESTS` の複製に `chest_type` を append、それぞれ `_state` へ代入 |
| `get_unclaimed_chests() -> Array` | `_copy_array(UNCLAIMED_CHESTS)` を返す（AGENTS.md ルール準拠） |
| `claim_pending_chests() -> int` | 下記4-5 で詳述 |
| `set_protection_type(protection_type: String) -> void` | `SELECTED_PROTECTION_TYPE` に文字列をセット、`LAST_PROTECTION_SELECTED_AT` に `str(Time.get_unix_time_from_system())` をセット |
| `has_selected_protection_today() -> bool` | 下記4-6 で詳述 |
| `reset_daily_pomodoro_state_if_needed() -> void` | 下記4-7 で詳述 |

### 4-5. `claim_pending_chests()` の実装詳細（指示書 §4-4）

1. `unclaimed_chests` を `_copy_array` で複製し、1件ずつ `chest_type` を取り出す
2. `Balance.pomodoro.chest_contents` を線形走査し、`chest_type` が一致する `ChestContentConfig` を探す
3. 見つかった場合：`rewards` Dictionary を組み立てる。`ChestContentConfig.materials` の各 `material_id` を `{REWARD_MATERIALS: {mat_id: amount}}` に詰める
4. `chest_data` を組み立てる：
   - `chest_id`: `"chest_" + str(unix_time) + "_" + str(i)` 形式（呼び出しごとにユニーク）
   - `chest_type`: 取り出した値
   - `source`: `GameStateKeys.CHEST_SOURCE_POMODORO`
   - `obtained_at`: `str(Time.get_unix_time_from_system())`
   - `opened`: `false`
   - `rewards`: 上記3の Dictionary
5. `add_pending_chest(chest_data)` を呼ぶ
6. 該当 `ChestContentConfig` が見つからなかった場合：`push_warning("[GameManager] claim_pending_chests: ChestContentConfig not found for chest_type=" + chest_type)` を出し、**その宝箱はスキップして次へ**（指示書 §4-4「1件の設定漏れで全部が失われないように」）
7. 配り終えたら `unclaimed_chests` を空配列にして `_state` へ代入し直す
8. 付与した件数を返す

### 4-6. `has_selected_protection_today()` の実装詳細

1. `_state.get(SELECTED_PROTECTION_TYPE, "")` が空文字なら `false`（一度も選んでいない）
2. 空文字でなければ `LAST_PROTECTION_SELECTED_AT` を `float()` で数値化（失敗時は `false`）
3. `GameDate.is_same_game_day(float(now), float(selected_at))` を呼んで bool を返す

`is_same_game_day(a, b)` は両方を `GameDate.get_game_date_string()` に通して文字列比較する想定。

### 4-7. `reset_daily_pomodoro_state_if_needed()` の実装詳細

1. `SELECTED_PROTECTION_TYPE` が空文字（＝これまで一度も選んでいない）なら何もしない
2. 空文字でなければ `LAST_PROTECTION_SELECTED_AT` を `float()` で数値化
3. `GameDate.is_same_game_day(float(now), float(selected_at))` が `true` なら**何もしない**（同じ日のうち）
4. `false` なら（日付が変わった）以下3つを `_copy_*` パターンで空にする。**`UNCLAIMED_CHESTS` は触らない**（指示書 §4-3 強調）：
   - `CUMULATIVE_FOCUS_MINUTES_TODAY: 0`
   - `REACHED_CHEST_THRESHOLDS: []`
   - `SELECTED_PROTECTION_TYPE: ""`（リセット後は「未選択」状態に戻し、次回起動時に加護選択画面を再表示する）

### 4-8. `GameDate.get_game_date_string()` の計算フロー（指示書 §5）

`unix_time` が負値なら `Time.get_unix_time_from_system()` で現在時刻を取得。`false` を第2引数に渡して**ローカルタイム**の `Time.get_datetime_dict_from_unix_time(t, false)` を呼び、`{year, month, day, hour, ...}` を得る。

「深夜3:59」と「深夜4:00」で何が違うかの具体例：

- 入力 `unix_time = 2026-08-09 03:59:00 JST` のとき：
  - ローカル datetime 辞書：`{year:2026, month:8, day:9, hour:3, ...}`
  - `hour < DAY_BOUNDARY_HOUR (=4)` なので「前日扱い」
  - `2026-08-08` を `day=8` に修正してから `"%04d-%02d-%02d" % [year, month, day]` でフォーマット
  - 戻り値：`"2026-08-08"`
- 入力 `unix_time = 2026-08-09 04:00:00 JST` のとき：
  - ローカル datetime 辞書：`{year:2026, month:8, day:9, hour:4, ...}`
  - `hour >= 4` なのでそのまま当日
  - 戻り値：`"2026-08-09"`

「4:00ちょうど」の閾値処理は「hour >= 4 を当日、hour < 4 を前日」とする。`is_same_game_day(a, b)` は `get_game_date_string(a) == get_game_date_string(b)`。

---

## 5. `pomodoro.tscn` のノード階層

### 5-1. 全体構成

指示書 §6 / §7-1 どおり、**4ビューを同じシーン内に置き `visible` で切り替える**方式。`SceneManager` は拠点⇔ポモドーロの出入りにしか使わない（休憩のバックグラウンド自動開始を成立させるため）。

```
res://scenes/pomodoro/pomodoro.tscn
Pomodoro (Control)                            # full rect。スクリプト = pomodoro.gd
├─ Background (ColorRect)                     # 例外で色ハードコード #1A1418
└─ CurrentViewContainer (Control)             # full rect。中ビューを visible 切替
	├─ ProtectionSelectView (Control)         # [instance] protection_select_view.tscn
	├─ FocusView (Control)                     # [instance] focus_view.tscn
	├─ ReflectionView (Control)               # [instance] reflection_view.tscn
	└─ BreakView (Control)                    # [instance] break_view.tscn
```

### 5-2. ルート `Pomodoro` ノードのプロパティ

```
[node name="Pomodoro" type="Control"]
anchors_preset = 15                           # anchor_right=1, anchor_bottom=1
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("res://scenes/pomodoro/pomodoro.gd")
```

**Timer ノードはここに1つだけ持たせる。** 名前は `PhaseTimer`（Type=`Timer`、one_shot=`false`、autostart=`false`）。`@onready var phase_timer: Timer = $PhaseTimer` で参照し、`_process(delta)` でなく `_physics_process` ではなく **`_process(delta)` から `phase_timer.time_left` を毎フレーム読んで残時間表示に使い、ゼロになった瞬間にシグナル `_on_phase_timer_timeout` で状態遷移する**。

### 5-3. `Background`（指示書 §6 そのまま）

```
[node name="Background" type="ColorRect" parent="."]
anchors_preset = 15
color = Color(0.101961, 0.0784314, 0.0941176, 1)   # #1A1418
```

### 5-4. `CurrentViewContainer`（指示書 §6）

```
[node name="CurrentViewContainer" type="Control" parent="."]
anchors_preset = 15
grow_horizontal = 2
grow_vertical = 2
```

4つの子ビューを `[ext_resource type="PackedScene" path="res://scenes/pomodoro/xxx_view.tscn"]` で参照し、`[node name="XxxView" parent="CurrentViewContainer" instance=ExtResource("...")]` でインスタンス化。**初期状態では `ProtectionSelectView` だけ `visible = true`、他3つは `visible = false`**。`pomodoro.gd._ready()` の最後に `_show_view("protection_select")` を呼んで整合させる。

### 5-5. 各サブビューのノード階層（指示書 §6「各ビューの中身」）

#### 5-5-1. `protection_select_view.tscn`

```
ProtectionSelectView (Control)               # full rect
├─ VBox                                       # 中央寄せ用の縦並び
│   ├─ TitleLabel (Label)                     # text = "ui_pomodoro_protection_select"
│   ├─ HintLabel (Label)                      # text = "ui_pomodoro_protection_hint"
│   └─ ProtectionButtons (VBoxContainer)
│       ├─ LightButton (PrimaryButton)        # label_key = "ui_pomodoro_protection_light"
│       ├─ LightDescLabel (Label)             # 宝箱タイミング説明。Balance.pomodoro.protection_light.schedule から組み立て
│       ├─ MiddleButton (PrimaryButton)       # label_key = "ui_pomodoro_protection_middle"
│       ├─ MiddleDescLabel (Label)            # 同上・protection_middle から組み立て
│       ├─ HardButton (PrimaryButton)         # label_key = "ui_pomodoro_protection_hard"
│       └─ HardDescLabel (Label)              # 同上・protection_hard から組み立て
```

#### 5-5-2. `focus_view.tscn`

```
FocusView (Control)
├─ VBox
│   ├─ SetLabel (Label)                       # "ui_pomodoro_set_progress" 形式
│   ├─ TitleInput (LineEdit)
│   │     max_length = 30                     # Balance.pomodoro.session_title_max_length を _ready() で再代入
│   │     placeholder_text = "ui_pomodoro_title_placeholder"
│   ├─ TitleHintLabel (Label)                 # text = "ui_pomodoro_title_hint"
│   ├─ TimerLabel (Label)                     # "24:35" 形式・pomodoro.gd が毎フレーム更新
│   └─ StartButton (PrimaryButton)            # label_key = "ui_pomodoro_start"
```

#### 5-5-3. `reflection_view.tscn`

```
ReflectionView (Control)
├─ VBox
│   ├─ PromptLabel (Label)                    # text = "ui_pomodoro_reflection_prompt"
│   ├─ ReflectionInput (TextEdit)
│   ├─ CharCountLabel (Label)                 # "12 / 20" 形式
│   ├─ RemainLabel (Label)                    # 残り秒数のカウントダウン
│   └─ ConfirmButton (PrimaryButton)          # label_key = "ui_pomodoro_confirm"
```

#### 5-5-4. `break_view.tscn`

```
BreakView (Control)
├─ VBox
│   ├─ BreakTitleLabel (Label)                # "ui_pomodoro_break_short" or "ui_pomodoro_break_long"
│   ├─ TimerLabel (Label)                     # カウントダウン表示
│   └─ SkipButton (PrimaryButton)             # label_key = "ui_pomodoro_skip_break"
```

### 5-6. 確認ダイアログ（指示書 §7-7「確認ダイアログ」）

`dialog_base.tscn`（既存）を **インスタンスとして `Pomodoro` の直下に置く**（`CurrentViewContainer` の外）。`@onready var quit_confirm_dialog: DialogBase = $QuitConfirmDialog` で参照。`hide()` 状態が初期値。`_on_quit_button_pressed()`（やめるボタン押下時）に `quit_confirm_dialog.open_with_content(...)` を呼んで表示する。確認OK時に `_return_to_base()` を呼ぶ。

---

## 6. `pomodoro.gd` の関数一覧と状態遷移

### 6-1. ファイル先頭

- `class_name PomodoroController` を付ける（指示書 §6 では「Pomodoro（Control）にスクリプト」とのみあるが、`get_presence_status()` を将来Steam層から呼ぶため `class_name` 公開が必要）
- `extends Control`（ノードにアタッチする）
- 冒頭に AGENTS.md 準拠のコメント

### 6-2. 定数

| 定数 | 値 | 用途 |
|---|---|---|
| `PRESET_ID` | `"standard"` | §7-1 ③。今回は standard 固定。プリセット選択UIは設定画面のタスク |
| `BASE_PATH` | `"res://scenes/base/base_screen.tscn"` | `_return_to_base()` の遷移先 |
| `QUIT_CONFIRM_DIALOG_SCENE` | `preload("res://scenes/ui/components/dialog_base.tscn")` | 確認ダイアログの PackedScene |
| `REFLECTION_MIN_CHARS` | `20` | 確定に必要な最小文字数（指示書 §7-4）。**`Balance` 経由で読むべきか判断迷う箇所（§9 参照）** |
| `REFLECTION_TIME_LIMIT_SEC` | `120` | 振り返り制限時間（指示書 §7-4） |
| `MIN_TITLE_CHARS_FOR_COUNT` | `0` | 文字数判定の最小値（空でも開始OK） |

### 6-3. @onready 参照

| 名前 | 型 | パス |
|---|---|---|
| `phase_timer` | `Timer` | `$PhaseTimer` |
| `current_view_container` | `Control` | `$CurrentViewContainer` |
| `protection_view` | `Control` | `$CurrentViewContainer/ProtectionSelectView` |
| `focus_view` | `Control` | `$CurrentViewContainer/FocusView` |
| `reflection_view` | `Control` | `$CurrentViewContainer/ReflectionView` |
| `break_view` | `Control` | `$CurrentViewContainer/BreakView` |
| `quit_confirm_dialog` | `DialogBase` | `$QuitConfirmDialog` |
| `set_label` | `Label` | `focus_view` 配下 |
| `title_input` | `LineEdit` | `focus_view` 配下 |
| `timer_label` | `Label` | `focus_view` 配下 |
| `start_button` | `PrimaryButton` | `focus_view` 配下 |
| `reflection_input` | `TextEdit` | `reflection_view` 配下 |
| `char_count_label` | `Label` | `reflection_view` 配下 |
| `remain_label` | `Label` | `reflection_view` 配下 |
| `confirm_button` | `PrimaryButton` | `reflection_view` 配下 |
| `break_title_label` | `Label` | `break_view` 配下 |
| `break_timer_label` | `Label` | `break_view` 配下 |
| `skip_button` | `PrimaryButton` | `break_view` 配下 |
| `light_button` / `middle_button` / `hard_button` | `PrimaryButton` | `protection_view` 配下 |
| `light_desc_label` / `middle_desc_label` / `hard_desc_label` | `Label` | `protection_view` 配下 |

### 6-4. 内部状態（指示書 §4 「ランタイムデータ」対応）

| 変数 | 型 | 用途 |
|---|---|---|
| `_status` | `String` | `"protection_select"` / `"focus"` / `"reflection"` / `"break"` / `"completed"` |
| `_preset` | `PomodoroPreset` | 起動時に `Balance.pomodoro.presets` からコピー |
| `_set_index` | `int` | 0から開始 |
| `_total_sets` | `int` | `_preset.default_total_sets` |
| `_focus_duration_sec` | `int` | セッション開始時にコピー |
| `_short_break_sec` | `int` | 同上 |
| `_long_break_sec` | `int` | 同上 |
| `_long_break_interval` | `int` | 同上 |
| `_selected_protection_type` | `String` | `GameManager.get_state()[SELECTED_PROTECTION_TYPE]` をキャッシュ |
| `_current_phase_total_sec` | `float` | `_process` の減算用基準値。タイマーセット時に毎回記録 |
| `_reflections` | `Array` | `[{set_index, text, char_count, confirmed, confirmed_at, skipped}]` |
| `_set_titles` | `Array[String]` | セットごとのタイトル |
| `_elapsed_at_phase_start_sec` | `float` | presence 用の経過分計算用 |

`_cumulative_focus_minutes_today` / `_reached_chest_thresholds` / `_unclaimed_chests` は **持たない**。毎回 `GameManager.get_state()` 経由で取得（指示書 §4 強調「GameManager が保持」）。

### 6-5. 関数一覧

| 関数 | 役割 | ビュー切替 |
|---|---|---|
| `_ready()` | ① `reset_daily_pomodoro_state_if_needed()` ② preset 取得 ③ 表示ビュー判定 | `_show_view()` を最後に呼ぶ |
| `_process(delta)` | 毎フレーム残り時間を `timer_label` 等に反映。**`phase_timer.time_left` を読み、`int(time_left)` を `mm:ss` 形式にフォーマット**。**減算は `Timer` ノードが自動で行う**（`wait_time` 設定→ `start()`→ 0 で `timeout` シグナル） | なし（描画更新のみ） |
| `_on_phase_timer_timeout()` | `Timer.timeout` 接続先。状態に応じて `_enter_reflection()` / `_enter_focus_next_set()` / `_return_to_base()` のいずれかに分岐 | 切替含む |
| `_show_view(name: String)` | 4つの子ビューの `visible` を切り替える内部ヘルパー。1度に1つだけ true | 切替 |
| `_enter_protection_select()` | 3ボタンへの `pressed` 接続、`schedule` を読んで desc_label 組み立て、`ProtectionSelectView` を表示 | 切替 |
| `_on_light_button_pressed()` 等 | `GameManager.set_protection_type("light")` 等を呼んで `_enter_focus()` | 切替 |
| `_enter_focus()` | `set_index` から `set_label.text` を `tr("ui_pomodoro_set_progress").format({0:set_index+1, 1:total_sets})` で組み立て、`title_input.text` に前セットタイトル or `""`、`title_input.max_length` に `Balance.pomodoro.session_title_max_length`、`start_button.pressed` 接続、`FocusView` を表示 | 切替 |
| `_on_start_button_pressed()` | `set_titles[set_index] = title_input.text`、`_current_phase_total_sec = float(_focus_duration_sec)`、`phase_timer.start(_focus_duration_sec)`、`_elapsed_at_phase_start_sec = Time.get_ticks_msec() / 1000.0` | 切替なし（タイマー開始） |
| `_enter_reflection()` | `ReflectionInput.text = ""`、`ConfirmButton.disabled = true`、`phase_timer.start(120)`、`_elapsed_at_phase_start_sec = ...`、`_connect_reflection_input()`、`_on_reflection_input_text_changed()` 初回呼び出し（CharCount 表示更新のため）、`ReflectionView` を表示 | 切替 |
| `_on_reflection_input_text_changed()` | `text.length()` を `char_count_label` に表示。`>= 20` なら `ConfirmButton.disabled = false` | なし |
| `_on_confirm_button_pressed()` | `_finalize_reflection(false)` 呼び出し | 切替含む |
| `_on_reflection_timer_expired()` | タイマー残り0時。`_finalize_reflection(true)` | 切替含む |
| `_finalize_reflection(skipped: bool)` | 振り返り1件を `_reflections` に push。`skipped == false` の場合のみ `_check_chest_thresholds()` を呼ぶ。次に `_enter_break()` | 切替含む |
| `_check_chest_thresholds()` | 指示書 §7-6。`add_focus_minutes()` → 加護の `schedule` を走査し `record_reached_threshold()` を該当分すべて呼ぶ → 画面上で「宝箱を獲得した（拠点で受け取れる）」を知らせる（ラベル or トースト） | なし（通知表示のみ） |
| `_enter_break()` | `(set_index + 1) % long_break_interval == 0` なら `long_break_sec` / `break_title_label` を `"ui_pomodoro_break_long"`、それ以外は `short_break_sec` / `"ui_pomodoro_break_short"`、`phase_timer.start(...)`、`BreakView` を表示 | 切替 |
| `_on_skip_break_pressed()` | `phase_timer.stop()` 後 `_on_phase_timer_timeout()` を直接呼ぶ | 切替含む |
| `_enter_focus_next_set()` | `set_index + 1 < total_sets` なら `set_index += 1` → `_enter_focus()`、それ以外なら `_return_to_base()` | 切替含む |
| `_on_quit_requested()` | 確認ダイアログを表示（`open_with_content` で Label + OK/キャンセルボタンを生成） | ダイアログ表示 |
| `_on_quit_confirmed()` | `_return_to_base()` | 切替（→ 拠点） |
| `_return_to_base()` | 指示書 §7-7 の5ステップを順に実行 | 画面遷移 |
| `get_presence_status() -> Dictionary` | 指示書 §7-8。`_status` / `_set_titles[_set_index]` / elapsed / remain を `Dictionary` で返す。**`_reflections` の text は絶対に入れない** | なし |

### 6-6. `_process(delta)` の挙動（指示書 §7 全体に関わる部分）

指示書 §6 末尾「タイマーは親（`Pomodoro`）が1つ持ち、`_process(delta)` で減算する」は **誤読リスクが高い**。実装は以下：

- **減算は `Timer` ノードの `wait_time` + `start()` で行い、0 で `timeout` シグナルが発火する**。これは Godot の標準的な仕組みで、フレーム落ちにも強い
- `_process(delta)` は **残時間表示の更新専用**。`phase_timer.time_left` を毎フレーム読み、`int(ceil(time_left))` を `mm:ss` 形式にフォーマットして `timer_label.text` に流す
- `_process` 内で `phase_timer.time_left <= 0.0` を直接見る**必要はない**（`timeout` シグナルに任せる）。表示上 0:00 が一瞬見えてからビューが切り替わる程度は許容する

---

## 7. しきい値判定と拠点帰還の処理の流れ

### 7-1. 振り返り確定時のしきい値判定（指示書 §7-6、コードの流れ）

`_finalize_reflection(skipped: bool)` の中で `skipped == false` の場合のみ実行する：

```
1. 今回のセットの作業分（分）を計算
   focus_minutes: int = int(_focus_duration_sec / 60)   # 端数は切り捨て

2. GameManager.add_focus_minutes(focus_minutes) を呼ぶ
   → GameManager._state[CUMULATIVE_FOCUS_MINUTES_TODAY] が +focus_minutes される

3. 選択中の加護の ProtectionTypeConfig を取得
   config: ProtectionTypeConfig = _get_protection_config(_selected_protection_type)
   _get_protection_config は Balance.pomodoro.protection_light/middle/hard を切り替えるヘルパー

4. config.schedule を全件走査
   for entry in config.schedule:
	   threshold_min: int = entry.threshold_min
	   chest_type: String = entry.chest_type
	   if not GameManager.has_reached_threshold(threshold_min) and \
		  GameManager.get_cumulative_focus_minutes() >= threshold_min:
		   GameManager.record_reached_threshold(threshold_min, chest_type)
		   # 画面上で「宝箱を獲得した」を知らせる（_show_chest_earned_notice(chest_type) 等）

5. 重要：ここでは add_pending_chest() を **絶対に呼ばない**。
   受け取りは _return_to_base() 内の claim_pending_chests() に集約する（指示書 §0-3 強調）。
```

**1セットで複数のしきい値を跨ぐケースの処理**：longプリセット（focus=50分）の2セット目直後に累計100分になり、middle加護の45/90両方を跨ぐ場合、ループ内で両方の `record_reached_threshold()` が順番に呼ばれる。`has_reached_threshold()` ガードで同じしきい値の二重登録は防がれる。

### 7-2. 拠点へ戻るときの処理（指示書 §7-7、コードの流れ）

`_return_to_base()` は **全セット完走・途中終了の両方から必ず通る単一エントリポイント**。分岐を作らない。

```
func _return_to_base() -> void:
	# 1. skipped: false のセットの作業分を集計
	var total_focus_minutes: int = 0
	for set_index in range(_set_index + 1):   # 完了済みセット = 0..set_index
		# 該当セットが skipped か否かは _reflections[set_index].skipped を見る
		if not _reflections[set_index].get("skipped", true):
			total_focus_minutes += int(_focus_duration_sec / 60)

	# 2. stamina を算出（int に丸め。加護倍率は掛けない §0-1）
	var stamina_gain: int = int(round(
		float(total_focus_minutes) * Balance.pomodoro.stamina_per_focus_minute
	))

	# 3. apply_pomodoro_rewards({stamina: N}) のみを呼ぶ
	#    gold / materials は含めない（§0-2）
	var reward_data: Dictionary = {GameStateKeys.REWARD_STAMINA: stamina_gain}
	GameManager.apply_pomodoro_rewards(reward_data)

	# 4. unclaimed_chests を pending_chests へ移す
	GameManager.claim_pending_chests()

	# 5. 拠点へ戻る
	SceneManager.change_scene(BASE_PATH)
```

**重要事項**：

- **1セットも振り返りを確定せずにやめた場合**（`set_index == 0` で `_reflections` が空）でも、`_return_to_base()` を通る。`total_focus_minutes = 0` → `stamina_gain = 0` → `apply_pomodoro_rewards({stamina: 0})` を呼ぶ。**クラッシュしない**し、`total_pomodoro_completed` は +1 される（指示書「やめる」を選んでも `apply_pomodoro_rewards` 自体は通る、と DATA_SCHEMA 2-2 整合）
- 宝箱 `unclaimed_chests` が空の場合、`claim_pending_chests()` は何もしない（戻り値 0）。安全
- 完走ルート（`_enter_focus_next_set()` → `set_index+1 >= total_sets`）と途中終了ルート（`_on_quit_confirmed()`）の **どちらも同じ `_return_to_base()` を呼ぶ**。これが指示書 §0-3「分岐を作らないこと」の担保

---

## 8. `ja.csv` の最終的な中身

### 8-1. 編集方針

- 既存30行（`ui_title_label` 〜 `ui_res_material_unknown`）はすべて維持する
- **追加のみ。** 既存行のリネーム・削除・値変更はしない
- `ui_nav_pomodoro` は既存（指示書 §8 強調「これは既存。追加しないこと」）
- 追加する22行は、指示書 §8 のリストを**完全にそのままの順序**で `ui_res_*` 群の直後あたりに挿入する
- 文字コードは UTF-8 (BOMなし)。日本語の値に `,` を含む行は無いのでセルを `"` で囲む必要なし
- 編集後に `ja.csv` を FileSystem パネルで再インポート

### 8-2. 重複チェック

指示書 §8 の追加キー22個を既存30行と照合した結果：

| 追加キー | 既存行と重複するか |
|---|---|
| `ui_pomodoro_protection_select` | 無 |
| `ui_pomodoro_protection_light` | 無 |
| `ui_pomodoro_protection_middle` | 無 |
| `ui_pomodoro_protection_hard` | 無 |
| `ui_pomodoro_protection_hint` | 無 |
| `ui_pomodoro_chest_at` | 無 |
| `ui_pomodoro_chest_generic` | 無 |
| `ui_pomodoro_chest_bonus_small` | 無 |
| `ui_pomodoro_chest_bonus_medium` | 無 |
| `ui_pomodoro_chest_bonus_large` | 無 |
| `ui_pomodoro_title_placeholder` | 無 |
| `ui_pomodoro_title_hint` | 無 |
| `ui_pomodoro_start` | 無 |
| `ui_pomodoro_focus` | 無 |
| `ui_pomodoro_reflection_prompt` | 無 |
| `ui_pomodoro_reflection_placeholder` | 無 |
| `ui_pomodoro_confirm` | 無 |
| `ui_pomodoro_break_short` | 無 |
| `ui_pomodoro_break_long` | 無 |
| `ui_pomodoro_skip_break` | 無 |
| `ui_pomodoro_chest_earned` | 無 |
| `ui_pomodoro_quit` | 無 |
| `ui_pomodoro_quit_confirm` | 無 |
| `ui_pomodoro_set_progress` | 無 |

すべて新規。重複なし。

### 8-3. 編集後の全行

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
ui_base_chest,宝箱
ui_pomodoro_protection_select,今日の加護を選ぶ
ui_pomodoro_protection_light,ライト
ui_pomodoro_protection_middle,ミドル
ui_pomodoro_protection_hard,ハード
ui_pomodoro_protection_hint,しきい値は今日の合計作業時間です。何回かに分けても大丈夫です。
ui_pomodoro_chest_at,{0}分で{1}
ui_pomodoro_chest_generic,ふつうの宝箱
ui_pomodoro_chest_bonus_small,ボーナス宝箱（小）
ui_pomodoro_chest_bonus_medium,ボーナス宝箱（中）
ui_pomodoro_chest_bonus_large,ボーナス宝箱（大）
ui_pomodoro_title_placeholder,何に取り組みますか？（任意）
ui_pomodoro_title_hint,ここに入れた文字はフレンドに表示されます
ui_pomodoro_start,はじめる
ui_pomodoro_focus,集中中
ui_pomodoro_reflection_prompt,今回やったことを振り返ってください
ui_pomodoro_reflection_placeholder,20文字以上で入力してください
ui_pomodoro_confirm,確定する
ui_pomodoro_break_short,休憩
ui_pomodoro_break_long,長い休憩
ui_pomodoro_skip_break,休憩をスキップ
ui_pomodoro_chest_earned,宝箱を獲得しました（拠点で受け取れます）
ui_pomodoro_quit,やめる
ui_pomodoro_quit_confirm,ここまでの報酬を受け取って拠点に戻ります。よろしいですか？
ui_pomodoro_set_progress,{0} / {1} セット目
```

### 8-4. 並び順の意図

- `ui_base_chest` の後ろに `ui_pomodoro_*` 群をまとめて追加（カテゴリ的に「画面別キー」の始まり）
- `ui_pomodoro_chest_at` は `{0}分で{1}` の **プレースホルダ付き**。`tr("ui_pomodoro_chest_at").format({0: 45, 1: tr("ui_pomodoro_chest_generic")})` のように使う想定。`chest_type` のラベルを差し込んで加護選択画面の `*DescLabel` に表示する
- `ui_pomodoro_set_progress` の `{0} / {1} セット目` も `format()` で埋める

---

## 9. 判断に迷った点／指示書に書かれていないが必要なこと

### 9-1. `pomodoro.gd` の `class_name` 要否

指示書 §6 は「スクリプトは `res://scenes/pomodoro/pomodoro.gd`（`PomodoroController` の役割を兼ねる）」とだけあり、`class_name` の指定はない。`get_presence_status()` を将来のSteam層やウィジェットから呼ぶことを考えると、ノードパス参照（`$Pomodoro`）でなく**型参照できたほうが安全**。

**解釈**：`class_name PomodoroController` を付ける。ノード名はシーンルート上は `Pomodoro` のまま（PascalCase、指示書 §6 階層どおり）。

### 9-2. 振り返り確定の最小文字数（20）と制限時間（120秒）を `Balance` 経由で読むか

指示書 §7-4 は「20文字以上」「120秒」と直接書かれている。AGENTS.md「数値管理ルール」は「ゲームバランスに関わる数値はスクリプト内にハードコードしない」とあり、20 と 120 は確実にバランス数値。

**解釈**：`REFLECTION_MIN_CHARS` と `REFLECTION_TIME_LIMIT_SEC` の2定数を `PomodoroConfig` に新規 `@export` で追加する（指示書 §1-4 にはこの2つが無いが、§7-4 で「20文字以上」「120秒」と指定されているので**AGENTS.md の数値管理ルールに照らして追加が必要**）。値はそれぞれ 20 / 120。指示書 §0-5 の表には無いが、§7-4 の記述があるためここに追加するのは整合的。本PRE_PLANで提案し人間に確認する。

（実装フェーズで人間に確認した結果、しきい値は固定でよいなら `PomodoroConfig` 追加は不要、`pomodoro.gd` の定数でも可。今回は実装フェーズで再確認する。）

### 9-3. `_return_to_base()` を「やめる」確認ダイアログ経由でしか呼べない作りにするか

指示書 §7-7「`_return_to_base()` は分岐を作らない」とあるが、確認ダイアログOKで呼ばれる場合と、全セット完走で直接呼ばれる場合の2経路がある。これは「分岐」ではなく「エントリポイントが1つ」という意味だと解釈する。

**解釈**：完走時は確認ダイアログを出さずに直接 `_return_to_base()` を呼ぶ。「やめる」経由のときだけ `quit_confirm_dialog` を経由する。**両方とも最終的に `_return_to_base()` を通る**ので指示書 §0-3 違反ではない。確認ダイアログは `dialog_base.tscn` の中身（Label + OK/キャンセル）を `open_with_content()` で差し込む方式。OK ボタン押下で `_on_quit_confirmed()` → `_return_to_base()`。

### 9-4. 振り返りで時間切れになった瞬間の処理

指示書 §7-4「120秒超過、または20文字未満のまま時間切れ：`skipped: true`」とある。`Timer` の `timeout` シグナルを受けたとき、`ReflectionInput.text.length() < 20` かどうかをチェックする。

**解釈**：`timeout` 時に `_finalize_reflection(true)` を呼ぶ。`true` の場合は `_check_chest_thresholds()` を呼ばず、`_reflections` に `skipped: true` で1件 push → `_enter_break()` へ進む。「120秒ちょうど」の解釈は `phase_timer.time_left <= 0.0` で発火する `timeout` なので、**超過ではなく「到達」**。DATA_SCHEMA.md 2-2「120秒以内に確定しなかった場合 skipped: true」と整合。

### 9-5. 2セット目以降の `TitleInput` 初期値

指示書 §7-3「2セット目以降は前セットの値を初期値として入れる」とある。

**解釈**：`_enter_focus()` 内で `var prev_title: String = _set_titles[_set_index] if _set_index < _set_titles.size() else ""` を取り、`title_input.text = prev_title` を設定。空文字でも開始可能（指示書「未入力のままでも開始できる」）。`placeholder_text` には `ui_pomodoro_title_placeholder`（"何に取り組みますか？（任意）"）を入れて、入力欄が空でもユーザーに「任意である」ことが伝わるようにする。

### 9-6. 宝箱獲得の通知（指示書 §7-6 ④「画面上で知らせる」）

指示書 §7-6 ④「画面上で『宝箱を獲得した（拠点で受け取れる）』ことを知らせる（`ui_pomodoro_chest_earned`）」とあるが、具体的な演出方法は指示が無い。

**解釈**：`FocusView` の中に `ChestEarnedLabel` を非表示で常備し、 `_check_chest_thresholds()` 内で `text = tr("ui_pomodoro_chest_earned")` ＋ `visible = true` にする。一定時間後にフェードアウト等の演出は今回入れない（AGENTS.md「タイマー装飾は体験版スコープ外」に近い思想で、表示を出すだけにとどめる）。`FocusView` 内に常備する理由は「振り返り確定直後だから作業画面にいる」前提のため。**休憩や加護選択で獲得した場合は考えない**（振り返り確定直後以外に `_check_chest_thresholds()` は呼ばれない）。

### 9-7. `phase_timer` を `one_shot = false` にするか

`wait_time` を毎回 `start(N)` で再設定するなら `one_shot` プロパティは実質使われない（`start()` がタイマーをリセットするため）。`autostart = false` は当然。

**解釈**：`one_shot = false` のまま（`wait_time` を使う以上デフォルトでOK）。毎フェーズ開始時に `phase_timer.wait_time = N; phase_timer.start()` を呼ぶ統一APIにすれば、`one_shot` 値に依存しない。

### 9-8. `PomodoroPreset` が見つからない場合のフォールバック

指示書 §7-1 ③「見つからない場合は `push_error` を出して拠点へ戻る。0秒のまま進行させないこと」。

**解釈**：`_ready()` で `_preset = null` のとき `push_error("[PomodoroController] preset not found: " + PRESET_ID)` → `_return_to_base()` を即座に呼ぶ。これにより `apply_pomodoro_rewards({stamina: 0})` まで通るが、それでよい。エラーでクラッシュさせない（`return_to_base()` の中で `Time.get_unix_time_from_system()` 等を呼ばないため安全）。

### 9-9. `base_screen.gd` の `SCREEN_SCENES` 辞書差し替え

現状 `res://scenes/base/base_screen.gd` の `SCREEN_SCENES` 辞書で `SCREEN_POMODORO` は `PLACEHOLDER_PATH` を指している。今回 `pomodoro.tscn` を実体として作るので、**ここを `res://scenes/pomodoro/pomodoro.tscn` に差し替える**必要がある。

**解釈**：`base_screen.gd` の変更は最小（定数1個の差し替え）で済む。指示書 §1-3「触らないもの」に `res://scenes/base/base_screen.tscn` / `.gd` は含まれていない（書換対象にも含まれていない）ため、**PRE_PLAN で人間に確認してから**変更する。確認結果は人間による決定事項セクション（§10）に書く。

### 9-10. 検証用シーンの構成

指示書「検証用の呼び出し方」によると、項目14〜16・21・24は `res://tests/` に検証用シーンを作って確認してよい。

**解釈**：
- `res://tests/pomodoro_core_loop_debug.tscn` を作り、その中で `Pomodoro` シーンをインスタンス化して直接表示する（`base_screen.gd` を経由しない）
- 完了条件6（タイマーが0秒で即終了しない）の検証には、`Balance.pomodoro.presets` の `standard` の `focus_duration_sec` を**テスト用の `.tres` に差し替え**る。ただし `.tres` を直接書き換えると他テストと衝突する。**テスト用 Config インスタンスを `execute_script` で生成し、`Balance` には触らず、シーン内の preset 参照だけ差し替える**方式を採る
- 完了条件14・15・16（しきい値跨ぎ）は、`Pomodoro` シーンのインスタンス化直後に `_check_chest_thresholds()` を強制呼び出しして検証するデバッグボタンを `tests/pomodoro_core_loop_debug.gd` 側に置く
- 検証後に `res://tests/pomodoro_core_loop_debug.tscn` / `.gd` を **残すか削除するかは人間判断**（指示書には明示なし、`IMPL_LOG_COMMON_INFRA.md` の `dummy_scene_*` は残した前例あり）

### 9-11. 振り返り文字数カウンタは `TextEdit.text_changed` シグナルで更新

`TextEdit` には `LineEdit` の `text_changed` 相当のシグナル `text_changed` がある（Godot 4 で `TextEdit` も `text_changed` シグナルを発火する）。

**解釈**：`reflection_view.gd._ready()` で `reflection_input.text_changed.connect(_on_reflection_input_text_changed)` を接続。`_on_reflection_input_text_changed()` 内で `text.length()` を `char_count_label.text` に `%d / 20` 形式で流す。`>= 20` で `confirm_button.disabled = false`。

### 9-12. 「やめる」ボタンの配置場所

指示書 §7-7「`ui_cancel`（Escape）または画面上の『やめる』ボタンで、確認ダイアログを出したうえで `_return_to_base()` を呼ぶ」とあるが、ボタン位置は指定なし。

**解釈**：各サブビューに `QuitButton` を配置するのは冗雑なので、`Pomodoro` シーン直下に QuitButton を1つだけ置く（CurrentViewContainer の外、`quit_confirm_dialog` の隣）。`text = "ui_pomodoro_quit"`。`pressed` シグナルで `_on_quit_requested()` を呼ぶ。**休憩中・振り返り中でも同じボタンから `_on_quit_requested()` を呼べる**（確認ダイアログで確認後に帰還する仕様）。

### 9-13. `apply_pomodoro_rewards({stamina: 0})` 時の挙動

`add_stamina(0)` は現状 max 切り捨てで `current + 0` → 0で切り捨ての場合はそのまま 0。`resource_changed` シグナルは発火する。問題なし。

**解釈**：特殊扱い不要。`stamina: 0` でも普通に呼ぶ。

---

## 10. 人間による決定事項（実装時はここを最優先で従うこと）

本PRE_PLANは人間のレビューを経て承認済み。§1〜§9の方針は基本的に
そのまま実装してよいが、以下が§1〜§9と矛盾する場合は**この§10を優先する。**

### 10-1.【要修正・重要】_return_to_base() の集計ループが範囲外アクセスになる

§7-2 の以下は**そのままだとクラッシュする。**

    for set_index in range(_set_index + 1):
		if not _reflections[set_index].get("skipped", true):

`_reflections` は振り返りを終えたセットぶんしか append されないため、
作業中や振り返り中に「やめる」を押すと `_reflections.size()` が
`_set_index` 個しかなく、範囲外アクセスになる。完了条件19がこのケース。

**`_reflections` を直接ループすること：**

    var confirmed_sets: int = 0
    for reflection: Dictionary in _reflections:
		if not bool(reflection.get("skipped", true)):
            confirmed_sets += 1
    var total_focus_minutes: int = confirmed_sets * int(_focus_duration_sec / 60.0)

`_set_index` を集計に使わない。配列の中身だけを見る。

### 10-2.【要修正】宝箱の獲得通知を FocusView に置かない

§9-6 は `FocusView` に `ChestEarnedLabel` を置くとしているが、
しきい値判定が走るのは**振り返り確定の直後**で、そのまま `BreakView` へ
遷移する。FocusView は表示されていないため通知が見えない。

**`Pomodoro` シーン直下（`CurrentViewContainer` の外）に
`ChestEarnedLabel` を1つ置くこと。** どのビューが表示されていても
上に重なって見える。QuitButton と同じ扱い。

### 10-3.【要修正】preset が見つからないときに報酬処理を通さない

§9-8 は preset 未発見時に `_return_to_base()` を呼ぶとしているが、
その中で `apply_pomodoro_rewards()` が走り `total_pomodoro_completed` が
+1される。**設定ミスで起動できなかった回を「1回やった」と数えるのはおかしい。**

preset 未発見時は `push_error` のあと
`SceneManager.change_scene(BASE_PATH)` だけを呼ぶこと。
報酬処理と `claim_pending_chests()` は通さない。

### 10-4.【確定】確定セットが0なら apply_pomodoro_rewards を呼ばない

`total_pomodoro_completed` は Steam実績の条件に使う予定
（`GODOT_SETUP.md` 6章）。1セットも振り返りを確定せずにやめた回を
+1すると実績の意味が壊れる。

`_return_to_base()` の中で：
- 確定セットが1以上 → `apply_pomodoro_rewards()` を呼ぶ
- 確定セットが0 → 呼ばない
- **`claim_pending_chests()` と `change_scene()` はどちらの場合も必ず呼ぶ**

これは§0-3の「分岐を作らないこと」に反しない。禁じているのは
「完走と途中終了で別の関数を通すこと」であり、`_return_to_base()` という
単一のエントリポイントを通る点は変わらない。

### 10-5.【承認】20文字・120秒を PomodoroConfig に追加する

§9-2 の判断は正しい。AGENTS.md の数値管理ルールどおり、
`PomodoroConfig` に以下を追加し、`.tres` に値を入れること。

| プロパティ | 値 |
|---|---|
| `reflection_min_chars` | 20 |
| `reflection_time_limit_sec` | 120 |

`pomodoro.gd` に定数として持たせないこと。

### 10-6.【承認】base_screen.gd の SCREEN_SCENES を差し替える

§9-9 の指摘は正しく、指示書の書き漏れ。以下1行だけ変更してよい。

	GameStateKeys.SCREEN_POMODORO: "res://scenes/pomodoro/pomodoro.tscn",

他の4画面は PLACEHOLDER_PATH のまま。base_screen.gd のそれ以外は触らない。
完了条件1（拠点のポモドーロボタンから遷移する）はこの変更が前提。

### 10-7.【要修正】検証用の秒数短縮は .tres の一時変更で行う

§9-10 の「execute_script でテスト用 Config を生成し、Balance に触らず
preset 参照だけ差し替える」は複雑すぎて失敗しやすい。

**`pomodoro_config.tres` の `standard` プリセットの秒数を一時的に
短くして検証し、確認後に §0-5 の値へ戻すこと。**（指示書「動作確認手順」冒頭）

ただし注意：focus を10秒などにすると
`int(_focus_duration_sec / 60.0)` が 0 になり、累計作業分が増えず
しきい値に到達しなくなる。**完了条件14〜16（しきい値判定）を検証するときは、
focus を 2700秒（45分）に設定するのではなく、
`protection_light.tres` の `threshold_min` を一時的に 1 に下げること。**
確認後に 45 へ戻す。

### 10-8.【明確化】確認ダイアログの持ち方を1つにする

§5-6 は `dialog_base.tscn` をシーンに配置すると書き、
§6-2 は `QUIT_CONFIRM_DIALOG_SCENE` として preload するとしていて重複している。

**§5-6 のシーン配置方式に統一する。** preload 定数は作らない。
`@onready var quit_confirm_dialog: DialogBase = $QuitConfirmDialog` で参照する。

### 10-9.【明確化】add_focus_minutes の複製は不要

§4-4 の「`_copy_dict` は不要」「`_copy_dict` パターンに倣う」は
記述が矛盾している。`CUMULATIVE_FOCUS_MINUTES_TODAY` は `int` なので
参照渡しの問題は起きない。`_state[キー] = 既存値 + minutes` で直接更新してよい。

`REACHED_CHEST_THRESHOLDS` と `UNCLAIMED_CHESTS` は Array なので、
`_copy_array()` で複製してから append し、`_state` へ代入し直すこと。

### 10-10.【明確化】GameStateKeys に追加する定数は13個

§4-1 の本文は「計11個」と書いているが、表は13行ある。
指示書§3のコードブロックも13個。**13個が正しい。**

### 10-11. そのまま採用する判断

以下は人間が確認済み。記述どおり実装してよい：
§3-4（ResourceSaver での .tres 生成）、§4-5〜§4-8、
§6-6（減算は Timer ノード、_process は表示更新のみ）、
§7-1（振り返り確定時に add_pending_chest を呼ばない）、
§8（ja.csv 全行）、§9-1、§9-3、§9-4、§9-5、§9-7、§9-11、§9-12、§9-13

### 10-12. 検証用シーンは残す

`res://tests/pomodoro_core_loop_debug.tscn` / `.gd` は削除せず残す
（`base_screen_debug` と同じ扱い）。本番シーンには検証用コードを残さない。
