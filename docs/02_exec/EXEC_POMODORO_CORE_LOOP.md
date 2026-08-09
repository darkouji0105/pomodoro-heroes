# 【実行指示書】ポモドーロ最小ループ

第3層・実行指示書。この指示書はAI（Ziva等）にそのまま渡して実装させることを想定している。

**これが完成するとMVPが揃う。** `CONCEPT.md`のコアループ「ポモドーロをやる → 報酬がもらえる → 拠点が育つ」が初めて動く。

---

## 前提・参照ドキュメント

実装前に必ず以下を読むこと。ここに書かれていないやり方は勝手に採用しない。

- `AGENTS.md`：フォルダ構造・命名規則・状態構造の表・数値管理ルール・開発ルール
- `PLAN_POMODORO_CORE_LOOP.md`：この実行指示書のもとになった第2層の作戦計画書

### 既存の実装状況（実コードで確認済み・推測しないこと）

| 対象 | 実際の状態 |
|---|---|
| `GameManager.apply_pomodoro_rewards(reward_data)` | 実装済み。gold / stamina / materials を反映し、`total_pomodoro_completed`を+1、`last_pomodoro_end_at`を更新、`SignalBus.pomodoro_session_completed`を発火する |
| `GameManager.add_pending_chest(chest_data)` | 実装済み。`pending_chests`へ追加し`pending_chests_changed`を発火 |
| `GameManager.add_stamina(amount)` | 実装済み。**現状maxで切り捨てていない**（コメントに「未確定」と残っている）。今回ここを修正する |
| `GameManager.get_state()` | `duplicate(true)`のスナップショットを返す |
| `SceneManager.change_scene(path)` | 実装済み |
| `Balance.pomodoro` | `PomodoroConfig`が割り当て済み。**ただし`pomodoro_config.tres`の中身は完全に空**（`presets`が空配列、加護3種が未割り当て、換算レートが全部0）。今回値を入れる |
| `ProtectionTypeConfig` | 倍率フィールド（`threshold_min` / `bonus_multiplier` / `before_multiplier` / `after_multiplier`）のみ。**今回作り替える** |
| `PomodoroPreset` | `preset_id` / `focus_duration_sec` / `short_break_sec` / `long_break_sec` / `long_break_interval` / `default_total_sets`。構造は変えない |
| 拠点画面 | 実装済み。下部にスタミナ表示と`ChestBadge`があり、`resource_changed` / `pending_chests_changed`で自動更新される |
| `scripts/utils/game_date.gd` | **存在しない。今回新規作成する** |

---

## 0. 人間による決定事項（最優先・§1以降と矛盾する場合はここを優先）

以下はすべて人間が決定済み。**変更しないこと。**

### 0-1.【確定】加護は報酬倍率ではなく宝箱スケジュール

`ProtectionTypeConfig`の倍率フィールドは**全廃**する。加護は「その日の累計作業分が◯分に達したら、どの宝箱がもらえるか」だけを持つ。

| 累計作業分 | ライト | ミドル | ハード |
|---|---|---|---|
| 45分 | **bonus_small** | generic | generic |
| 90分 | — | **bonus_medium** | generic |
| 135分 | — | — | generic |
| 180分 | — | — | **bonus_large** |

- **しきい値は1セッションではなく「その日の累計」で判定する。** 朝に100分、夜に80分やれば合計180分としてハードのボーナスに届く
- 報酬計算に倍率を掛けてはならない。加護で差がつくのは宝箱だけ

### 0-2.【確定】報酬は当面スタミナのみ

- `stamina_per_focus_minute`のみ使う
- `gold_per_focus_minute` / `materials_per_focus_minute`は**フィールドを残したまま値を0にする**（後で使うため削除しない）
- 換算レートのランダム性は今回入れない

### 0-3.【確定】宝箱は拠点へ戻ったときにまとめて受け取る

- ポモドーロ中はしきい値到達を記録するだけ。`add_pending_chest()`を呼ばない
- 拠点へ戻るときに、溜まったぶんをまとめて付与する
- **全セット完走でも、途中でやめた場合でも、同じ経路を通る。分岐を作らないこと**（片方だけ報酬が消えるバグを防ぐため）

### 0-4.【確定】スタミナ上限を大きく取る

`initial_state_config.tres`を以下に変更する。

| プロパティ | 変更前 | 変更後 |
|---|---|---|
| `starting_stamina_max` | 10 | **100** |
| `starting_stamina_current` | 10 | **20** |

あわせて`GameManager.add_stamina()`を**maxで切り捨てる**実装にする（現状は切り捨てていない）。上限が大きいため実質発動しないが、仕様として確定させる。

### 0-5.【確定】Balanceに入れる値（仮値・後で調整する前提）

**`PomodoroConfig`**

| プロパティ | 値 |
|---|---|
| `stamina_per_focus_minute` | `0.2`（25分1セットで5スタミナ） |
| `gold_per_focus_minute` | `0.0` |
| `materials_per_focus_minute` | `0.0` |
| `min_sets` | `1` |
| `max_sets` | `12` |
| `min_long_break_minutes` | `5` |
| `max_long_break_minutes` | `60` |
| `min_long_break_interval` | `2` |
| `max_long_break_interval` | `8` |
| `session_title_max_length` | `30`（**新規フィールド**。DATA_SCHEMA 2-7） |

`max_sets = 12`は、shortプリセット（15分）でもハードの180分に理屈上到達できるようにするため。

**`PomodoroPreset`（3件）**

| preset_id | focus | short_break | long_break | interval | default_total_sets |
|---|---|---|---|---|---|
| `short` | 900 | 180 | 1800 | 4 | 4 |
| `standard` | 1500 | 300 | 1800 | 4 | 4 |
| `long` | 3000 | 600 | 1800 | 4 | 3 |

**宝箱の中身（すべて建築素材。レア素材等が実装されたら差し替える）**

| chest_type | construction_material |
|---|---|
| `generic` | 4 |
| `bonus_small` | 10 |
| `bonus_medium` | 25 |
| `bonus_large` | 30 |

---

## 今回のタスク

### やること
- `ProtectionTypeConfig`の作り替えと、`ChestScheduleEntry` / `ChestContentConfig`の新規作成
- `pomodoro_config.tres`への値の投入
- `initial_state_config.tres`のスタミナ変更
- `GameManager`への追加（当日累計・到達しきい値・受け取り待ち宝箱の保持、`add_stamina`の上限処理）
- `GameStateKeys`への定数追加
- `scripts/utils/game_date.gd`（毎朝4:00基準の日付判定ヘルパー）の新規作成
- `res://scenes/pomodoro/pomodoro.tscn`とサブビュー4つの実装
- `ja.csv`への追加

### やらないこと
- ストリーク・猶予日数・防衛チケット（`DATA_SCHEMA.md` 2-4）
- セッション履歴・記録画面（2-5）
- タイマー装飾（2-6）
- アプリを閉じた場合の中断・復帰処理（`paused` / `interrupted`、`app_closed_at`）
- 宝箱の中身の**抽選**（`pity_counters`を使った乱数）。固定内容のみ
- Steam連携そのもの（`get_presence_status()`の口だけ用意する）
- gold・素材の報酬
- ユーザーがセット数や長休憩を変更するUI（値の範囲は`Balance`に入れるが、変更画面は設定画面のタスク）

---

## 1. Configクラスの変更

### 1-1. `res://resources/balance/chest_schedule_entry.gd`（新規）

```gdscript
class_name ChestScheduleEntry
extends Resource

# 加護の宝箱スケジュール1件分。
# 「その日の累計作業分が threshold_min に達したら chest_type の宝箱がもらえる」を表す。

@export var threshold_min: int
@export var chest_type: String
```

### 1-2. `res://resources/balance/protection_type_config.gd`（作り替え）

**既存の倍率フィールドを全て削除する。**

```gdscript
class_name ProtectionTypeConfig
extends Resource

# 加護1種の宝箱スケジュール（DATA_SCHEMA.md 2-3準拠）。
# 加護は報酬倍率ではなく「いつ・どの宝箱がもらえるか」だけを決める。
# しきい値はその日の累計作業分で判定する（1セッションではない）。

@export var schedule: Array[ChestScheduleEntry]
```

### 1-3. `res://resources/balance/chest_content_config.gd`（新規）

```gdscript
class_name ChestContentConfig
extends Resource

# chest_type 1種ぶんの中身。
# 現状は建築素材のみ。レア素材・レシピ・装飾が実装されたら項目を増やす。

@export var chest_type: String
@export var materials: Dictionary   # material_id -> 個数
```

### 1-4. `res://resources/balance/pomodoro_config.gd`（追記）

既存のフィールドのうち**倍率に関するものは無い**（倍率は`ProtectionTypeConfig`側にあった）ため、削除は不要。以下を追記する。

```gdscript
@export var chest_contents: Array[ChestContentConfig]
@export var session_title_max_length: int
```

`protection_light` / `protection_middle` / `protection_hard`の型は`ProtectionTypeConfig`のまま変わらない。

---

## 2. `pomodoro_config.tres` への値の投入

**現状このファイルは完全に空。** `[resource]`の下に`script`の行しかなく、`presets`は空配列、加護3種は未割り当て、数値は全部0。**このまま実装すると作業時間0秒でタイマーが即終了する。**

§0-5の表の値をすべて入れること。加護3種は`.tres`を分けて作る。

| ファイル | 内容 |
|---|---|
| `res://resources/balance/protection_light.tres` | schedule: [{45, "bonus_small"}] |
| `res://resources/balance/protection_middle.tres` | schedule: [{45, "generic"}, {90, "bonus_medium"}] |
| `res://resources/balance/protection_hard.tres` | schedule: [{45, "generic"}, {90, "generic"}, {135, "generic"}, {180, "bonus_large"}] |

プリセット3件と`chest_contents`4件は、`pomodoro_config.tres`内のサブリソースとして持たせてよい（`.tres`を12個に分けなくてよい）。

**`.tres`の手書きは避けること。** `IMPL_LOG_COMMON_INFRA.md`の逸脱5にあるとおり、`ResourceSaver.save()`を使ってGodotに正しいフォーマットで出力させるほうが確実。

---

## 3. `GameStateKeys` への追加

`res://scripts/utils/state_keys.gd`の末尾に追記する。**既存の定数は変更しないこと。**

```gdscript
# ポモドーロ（当日の進捗・受け取り待ちの宝箱）
const CUMULATIVE_FOCUS_MINUTES_TODAY: String = "cumulative_focus_minutes_today"
const REACHED_CHEST_THRESHOLDS: String = "reached_chest_thresholds"
const UNCLAIMED_CHESTS: String = "unclaimed_chests"
const LAST_PROTECTION_SELECTED_AT: String = "last_protection_selected_at"
const SELECTED_PROTECTION_TYPE: String = "selected_protection_type"

# 加護の種類
const PROTECTION_LIGHT: String = "light"
const PROTECTION_MIDDLE: String = "middle"
const PROTECTION_HARD: String = "hard"

# 宝箱の種類（chest_type）
const CHEST_TYPE_GENERIC: String = "generic"
const CHEST_TYPE_BONUS_SMALL: String = "bonus_small"
const CHEST_TYPE_BONUS_MEDIUM: String = "bonus_medium"
const CHEST_TYPE_BONUS_LARGE: String = "bonus_large"

# 宝箱の source
const CHEST_SOURCE_POMODORO: String = "pomodoro"
```

---

## 4. `GameManager` への追加

`res://autoload/game_manager.gd`に以下を追加する。**既存の関数のシグネチャは変更しないこと**（`add_stamina`の内部処理のみ変更）。

### 4-1. 状態テンプレートへの追加

`_empty_state_template()`に以下を追加する。

```gdscript
GameStateKeys.CUMULATIVE_FOCUS_MINUTES_TODAY: 0,
GameStateKeys.REACHED_CHEST_THRESHOLDS: [],
GameStateKeys.UNCLAIMED_CHESTS: [],
GameStateKeys.LAST_PROTECTION_SELECTED_AT: "",
GameStateKeys.SELECTED_PROTECTION_TYPE: "",
```

### 4-2. `add_stamina()` の上限処理

現状「maxを超えたぶんを切り捨てるかどうかは未確定」というコメントが残っている。**maxで切り捨てる**実装に変更し、コメントを更新すること。

```gdscript
# max を超える分は切り捨てる（DATA_SCHEMA.md 1章で確定）。
# ただし max を大きく取っているため、実質的にはほぼ発動しない。
```

### 4-3. 追加する関数

```gdscript
# その日の累計作業分を加算する。振り返りが確定したセットのみ呼ばれる想定。
func add_focus_minutes(minutes: int) -> void

# その日の累計作業分を取得する
func get_cumulative_focus_minutes() -> int

# しきい値に到達済みか（同じしきい値で二重に宝箱を発生させないため）
func has_reached_threshold(threshold_min: int) -> bool

# しきい値到達を記録し、受け取り待ちの宝箱を積む。
# この時点では add_pending_chest() を呼ばない（受け取りは拠点帰還時）。
func record_reached_threshold(threshold_min: int, chest_type: String) -> void

# 受け取り待ちの宝箱の一覧を取得する
func get_unclaimed_chests() -> Array

# 受け取り待ちの宝箱をすべて pending_chests へ移し、unclaimed_chests を空にする。
# 付与した件数を返す。
func claim_pending_chests() -> int

# 加護の選択を記録する（選択時刻も記録し、翌日の再表示判定に使う）
func set_protection_type(protection_type: String) -> void

# 今日すでに加護を選んでいるか（毎朝4:00基準）
func has_selected_protection_today() -> bool

# 日付が変わっていれば当日データをリセットする。
# リセット対象：cumulative_focus_minutes_today / reached_chest_thresholds /
#               selected_protection_type
# **unclaimed_chests はリセットしない**（未受け取りの宝箱が消えるため）
func reset_daily_pomodoro_state_if_needed() -> void
```

### 4-4. `claim_pending_chests()` の実装上の注意

- `unclaimed_chests`の各`chest_type`について、`Balance.pomodoro.chest_contents`から該当する`ChestContentConfig`を引き、`rewards`を組み立てて`add_pending_chest()`に渡す
- `chest_data`は`DATA_SCHEMA.md` 1章の`pending_chests`の形に従う。`chest_id`は一意になるよう生成し、`source`は`GameStateKeys.CHEST_SOURCE_POMODORO`、`opened`は`false`
- 該当する`ChestContentConfig`が見つからない場合は`push_warning`を出し、**その宝箱はスキップして残りを処理する**（1件の設定漏れで全部が失われないようにするため）
- 配り終えたら`unclaimed_chests`を空にする

---

## 5. `res://scripts/utils/game_date.gd`（新規）

毎朝4:00を1日の区切りとする判定ヘルパー。ポモドーロの加護選択・当日リセットのほか、将来のストリーク判定・ショップのリフレッシュ判定からも共用する（`PROJECT_STATUS.md`「横断的な未確定事項一覧」で決定済み）。

```gdscript
class_name GameDate
extends RefCounted

# 1日の区切りは毎朝4:00（DATA_SCHEMA.md 2-4で確定）。
# ポモドーロの加護選択・ストリーク・ショップのリフレッシュで
# 基準がズレないよう、日付判定は必ずこのクラスを経由すること。

const DAY_BOUNDARY_HOUR: int = 4

# 「ゲーム内の今日」を表す文字列（例: "2026-08-09"）を返す。
# 深夜0:00〜3:59は前日として扱う。
static func get_game_date_string(unix_time: float = -1.0) -> String

# 2つの時刻が「ゲーム内の同じ日」かどうか
static func is_same_game_day(unix_time_a: float, unix_time_b: float) -> bool
```

- `unix_time`に負値が渡されたら現在時刻（`Time.get_unix_time_from_system()`）を使う
- ローカルタイムで判定する（`Time.get_datetime_dict_from_unix_time(t, false)`）

---

## 6. シーン階層

```
res://scenes/pomodoro/pomodoro.tscn
Pomodoro (Control)                       # full rect
├─ Background (ColorRect)                # #1A1418
└─ CurrentViewContainer (Control)        # full rect。この中に子ビューを差し替える
    ├─ ProtectionSelectView (Control)
    ├─ FocusView (Control)
    ├─ ReflectionView (Control)
    └─ BreakView (Control)
```

- スクリプトは`res://scenes/pomodoro/pomodoro.gd`（`PomodoroController`の役割を兼ねる）
- 4つのビューは**同じシーンの中に置き、`visible`で切り替える。** `SceneManager`で遷移しない（タイマーを親側で継続させ、休憩のバックグラウンド自動開始を成立させるため）
- 拠点⇔ポモドーロの出入りのみ`SceneManager.change_scene()`を使う
- 各ビューは1画面でしか使わないため`scenes/pomodoro/`配下に置く（`AGENTS.md`「UIパーツの置き場所ルール」）
- タイマーは親（`Pomodoro`）が1つ持ち、`_process(delta)`で減算する。ビューごとにTimerノードを持たせない

### 各ビューの中身（最小構成）

```
ProtectionSelectView
├─ TitleLabel                            # "ui_pomodoro_protection_select"
└─ ProtectionButtons (VBoxContainer)
    ├─ LightButton   (primary_button.tscn)
    ├─ LightDescLabel                     # 宝箱タイミングの説明
    ├─ MiddleButton  / MiddleDescLabel
    └─ HardButton    / HardDescLabel

FocusView
├─ TitleInput (LineEdit)                 # セッションタイトル。任意入力
├─ TitleHintLabel                        # "ui_pomodoro_title_hint"（フレンドに見える旨）
├─ SetLabel                              # "3 / 4" 形式
├─ TimerLabel                            # "24:35" 形式
└─ StartButton (primary_button.tscn)     # 入力を終えて作業開始

ReflectionView
├─ PromptLabel                           # "ui_pomodoro_reflection_prompt"
├─ ReflectionInput (TextEdit)
├─ CharCountLabel                        # "12 / 20" 形式
├─ RemainLabel                           # 残り120秒のカウントダウン
└─ ConfirmButton (primary_button.tscn)   # 20文字未満は disabled

BreakView
├─ BreakTitleLabel                       # 短休憩/長休憩で文言を変える
├─ TimerLabel
└─ SkipButton (primary_button.tscn)      # 休憩をスキップして次セットへ
```

---

## 7. 進行の実装

### 7-1. 起動時（`_ready()`）

1. `GameManager.reset_daily_pomodoro_state_if_needed()`を呼ぶ
2. プリセットを決める（今回は`standard`固定でよい。プリセット選択UIは設定画面のタスク）
3. `Balance.pomodoro.presets`から`preset_id`が一致する`PomodoroPreset`を探し、各秒数と`default_total_sets`をコピーする
   - **見つからない場合は`push_error`を出して拠点へ戻る。** 0秒のまま進行させないこと
4. `GameManager.has_selected_protection_today()`が`false`なら`ProtectionSelectView`を表示、`true`なら`FocusView`へ

### 7-2. 加護選択（ProtectionSelectView）

- 3種のボタンを表示し、それぞれの下に**宝箱がもらえるタイミングを表示する**
  - 表示内容は`Balance.pomodoro`の各`ProtectionTypeConfig.schedule`から組み立てる。文言をハードコードしない
  - **「しきい値はその日の累計作業分であり、1セッションで到達する必要はない」**ことが分かる文言を添える（`ui_pomodoro_protection_hint`）
- 選択したら`GameManager.set_protection_type()`を呼び、`FocusView`へ

### 7-3. 作業（FocusView）

- `TitleInput`にセッションタイトルを入力できる。**任意**。空のまま開始してよい
  - 2セット目以降は前セットの値を初期値として入れる
  - 入力値は`set_titles[set_index]`に保存する
  - `Balance.pomodoro.session_title_max_length`で`max_length`を設定する
- `StartButton`押下でカウントダウン開始
- タイマー完了で自動的に`ReflectionView`へ

### 7-4. 振り返り（ReflectionView）

- 120秒のカウントダウンを表示
- `ConfirmButton`は**20文字以上で有効化**。文字数は`CharCountLabel`に常時表示する
- 確定した場合：`skipped: false`で記録し、**§7-6のしきい値判定を行う**
- 120秒超過、または20文字未満のまま時間切れ：`skipped: true`で記録し、**しきい値判定を行わない**
- どちらの場合も`reflections`に1件追記して`BreakView`へ

### 7-5. 休憩（BreakView）

- `(set_index + 1) % long_break_interval == 0`なら`long_break_sec`、それ以外は`short_break_sec`
- 自動でカウントダウン開始
- `SkipButton`で即座に次へ進める
- 終了時：
  - `set_index + 1 < total_sets` → `set_index`を+1して`FocusView`へ
  - `set_index + 1 >= total_sets` → §7-7の終了処理へ

### 7-6. しきい値の判定（振り返り確定時）

**この時点で`add_pending_chest()`を呼んではならない。記録だけを行う。**

1. `GameManager.add_focus_minutes(そのセットの作業分)`を呼ぶ
2. 選択中の加護の`schedule`を走査し、以下を両方満たすエントリを探す
   - `threshold_min <= GameManager.get_cumulative_focus_minutes()`
   - `GameManager.has_reached_threshold(threshold_min)`が`false`
3. 該当するものすべてについて`GameManager.record_reached_threshold(threshold_min, chest_type)`を呼ぶ
4. 画面上で「宝箱を獲得した（拠点で受け取れる）」ことを知らせる（`ui_pomodoro_chest_earned`）

**1セットで複数のしきい値を跨ぐことがある**（longプリセットで50分×2セット＝100分など）。跨いだぶんすべてを記録すること。

### 7-7. 拠点へ戻るときの処理

**全セット完走でも、途中でやめた場合でも、必ずこの関数を通す。分岐を作らないこと。**

```gdscript
func _return_to_base() -> void:
    # 1. skipped: false のセットの作業分を集計
    # 2. stamina_per_focus_minute を掛けてスタミナ量を算出（int に丸める）
    # 3. GameManager.apply_pomodoro_rewards({stamina: N}) を呼ぶ
    #    gold と materials は含めない（§0-2）
    #    加護による倍率は掛けない（§0-1）
    # 4. GameManager.claim_pending_chests() を呼ぶ
    # 5. SceneManager.change_scene("res://scenes/base/base_screen.tscn")
```

- **途中でやめる導線を用意すること。** `ui_cancel`（Escape）または画面上の「やめる」ボタンで、確認ダイアログを出したうえで`_return_to_base()`を呼ぶ
- 確認ダイアログには`dialog_base.tscn`を使ってよい
- 作業分が0（1セットも振り返りを確定していない）の場合も、同じ経路を通す。スタミナ0で`apply_pomodoro_rewards`を呼んでよい

### 7-8. `get_presence_status()`

`PLAN_POMODORO_CORE_LOOP.md` 6-3のとおり実装する。

```gdscript
func get_presence_status() -> Dictionary:
    # status: "focus" | "reflection" | "break" | "none"
    # title: set_titles[set_index]（未入力なら空文字列）
    # set_index: 現在のセット番号（表示は1始まり）
    # total_sets / elapsed_min / remain_min
```

- **振り返り（`reflections`）のテキストを絶対に含めないこと。** 業務内容など本人が公開を意図しないテキストが入りうる（`DATA_SCHEMA.md` 2-7のプライバシー制約）
- 状態をprivate変数に閉じ込めず、この関数経由で常に取り出せる状態を保つ

---

## 8. `ja.csv` への追加

**UTF-8（BOMなし）で保存し、編集後は再インポートすること。** 既存行と重複させないこと。

```
ui_nav_pomodoro,ポモドーロ
```
↑これは**既存**。追加しないこと。

追加する行：

```
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

- `{0}` `{1}`は`String.format()`で埋める。**数値だけの表示は`tr()`不要**だが、この行のように文言に埋め込む場合はキー経由にすること

---

## 動作確認手順（完了条件）

**検証時は`pomodoro_config.tres`の秒数を一時的に短くしてよい**（focus 10秒・break 5秒など）。ただし**確認後は§0-5の値に必ず戻すこと。**

1. 拠点画面のポモドーロボタンから`pomodoro.tscn`へ遷移する
2. 初回起動時に加護選択画面が表示され、3種それぞれの宝箱タイミングが表示されている
3. 加護を選ぶと作業画面へ進み、**同じ日に再度ポモドーロを開いても加護選択が表示されない**
4. 作業開始前にセッションタイトルを入力でき、**未入力のままでも開始できる**
5. 2セット目のタイトル入力欄に、前セットのタイトルが初期値として入っている
6. 作業タイマーが`Balance`のプリセット値どおりに動く（**0秒で即終了しない**）
7. タイマー完了で自動的に振り返り画面へ遷移する
8. 20文字未満のあいだ確定ボタンが無効、20文字以上で有効になる
9. 120秒以内に確定しなかった場合、`skipped: true`として記録され、次のセットに進む
10. `skipped: true`のセットは`cumulative_focus_minutes_today`に加算されない
11. 振り返り確定後、自動的に休憩画面へ遷移しカウントダウンが始まる
12. 休憩をスキップすると次のセットの作業画面へ進む
13. `long_break_interval`の倍数のセット後は長休憩の秒数が使われる
14. 累計作業分がしきい値（45分）を跨ぐと`unclaimed_chests`に積まれ、**この時点では`pending_chests`が増えていない**ことをprintで確認できる
15. 同じしきい値で二重に積まれない
16. 1セットで複数のしきい値を跨いだ場合、跨いだぶんすべてが積まれる
17. 全セット終了で拠点へ戻り、スタミナが増え、`ChestBadge`が点灯し、`unclaimed_chests`が空になっている
18. **途中で「やめる」から拠点へ戻った場合も、そこまでのスタミナと宝箱を受け取れる**（完走時と同じ関数を通っていることをコードレビューで確認）
19. 1セットも振り返りを確定せずにやめた場合、スタミナ0で正常に拠点へ戻る（クラッシュしない）
20. `total_pomodoro_completed`が1回の帰還につき1増える
21. `GameManager.add_stamina()`が`max`を超えないことを確認できる（`add_stamina(9999)`で`100/100`になる）
22. `initial_state_config.tres`が`starting_stamina_max = 100` / `starting_stamina_current = 20`になっている
23. `pomodoro_config.tres`に§0-5の値がすべて入っており、Inspectorから開いて確認できる
24. `GameDate.get_game_date_string()`が、深夜3:59を前日として、4:00を当日として返すことをprintで確認できる
25. `get_presence_status()`が現在の状態・タイトル・経過/残り分を返し、**振り返りテキストを含んでいない**ことをprintで確認できる
26. 表示テキストがすべて`tr()`経由で、日本語がハードコードされていないことをコードレビューで確認できる
27. 数値（秒数・しきい値・倍率・宝箱の中身）が`Balance`経由で、スクリプトにハードコードされていないことをコードレビューで確認できる
28. `IMPL_LOG_TEMPLATE.md`の型に沿って`res://docs/03_log/IMPL_LOG_POMODORO_CORE_LOOP.md`が生成されている

### 検証用の呼び出し方

項目14〜16・21・24は`res://tests/`に検証用シーンを作って確認してよい。**検証用コードを本番シーンに残さないこと。**

---

## 遵守事項（AGENTS.mdより再掲）

- 変数・関数・ファイル名はsnake_case、`class_name`とノード名はPascalCase、シグナルは過去形にする
- 状態のキーは文字列リテラルではなく`GameStateKeys`の定数を使う（**ネストしたキーも含む**）
- **数値をスクリプトにハードコードしない。** 秒数・しきい値・宝箱の中身はすべて`Balance`経由
- 全ての表示テキストは`tr()`を経由する。日本語をハードコードしない
- 色・フォントは個別シーンにハードコードせず、Theme経由にする（背景の`ColorRect`は例外）
- 画面遷移は必ず`SceneManager`経由
- **エラー回避のために型指定・命名規則・状態アクセスのルールを緩めない。** `class_name`が認識されない場合はGodotエディタを再起動する
- **完了条件はこのファイルから項目番号ごとそのまま転記し、1項目ずつ実際に動かして検証する**
- `edit_file`は使用しない。追記は`bash`の`cat >> "パス" << 'EOF'`を使う
- Autoloadを追加しない（5つ固定）
- Input Map（`project.godot`の`[input]`）は変更しない
- 同じ箇所を3回以上直す必要が出た場合は実装を止め、設計を見直す
