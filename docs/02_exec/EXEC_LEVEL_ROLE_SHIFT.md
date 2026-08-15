# 【実行指示書】レベルの役割転換（**割り振りのみ。スキル解放とパッシブは次回**）

`PLAN_IMPLEMENTATION.md` 3章の**3番**。

**仕様の本体は`GAME_DESIGN.md` 5章。ここには仕様を書き写さない。** ただし今回の会話で 5-2 / 5-3 の記述から**外れた決定**が2件出たので、それは §2 に明記する（設計書側の書き換えは人間の作業。§4-4）。

---

## 1. このタスクで実現すること

**レベルの意味を「ステータスが式で伸びる」から「ノードを解放して自分で伸ばす」に移す。**

| 入るもの | |
|---|---|
| **ステータスノード** | キャラごと3本の枝・各20段。前提条件つき（縦に伸びる） |
| **割り振りポイント** | 1レベルにつき1点。Lv100到達時のみ2点（**合計100点**） |
| **無料の振り直し** | ノードを全解除して残ポイントを戻す |
| **`stat_growth_formula` を `"base"` に** | レベルでステータスが自動で伸びなくなる |
| **新画面** | `scenes/guild/stat_node_screen`（ツリー描画のため育成画面から切り出す） |

### 入らないもの（**次回以降**）

- **スキル解放と選択**（`select_skill()` は空実装のまま。呼び出し元0件のまま）
- **パッシブ**（器も作らない）
- **プリセット**（`PLAN_IMPLEMENTATION.md` 3章の7番に単独枠がある）

### なぜ分けたか

スキル解放は「戦闘が `char_data.get("skills")` をマスター直読みしているのを `growth.skills` 参照に**転換する**」変更を含み、`battle_controller.gd` に手が入る。割り振りは `game_manager.gd` と育成まわりの画面で閉じる。**触るファイルが重ならない。** 10軸を器／式で2回に割ったのと同じ理由。

---

## 2. `GAME_DESIGN.md` から外れた決定（**2件。設計書の書き換えが要る**）

**勝手に直していない。** §4-4 で人間が直す。

### 2-1. ポイントの刻み：5レベルごと3点 → **1レベルごと1点**

`GAME_DESIGN.md` 5-2 の表は「5レベルごとに割り振りポイント」。**1レベルごとに変更した。**

- Lv1 で 0点、Lv2 で 1点 …… Lv99 で 98点、**Lv100 到達時のみ2点入って合計100点**
- 副作用として、`"base"` 化しても **Lv1〜4 が無報酬になる問題が同時に消える**（毎レベル必ず1点貫く）
- 5-2 の「Lv20 は区切りとして強い山になる」という記述は、スキル解放（5/10/15/20）とパッシブ（20ごと）が残るので**効力を失わない**

### 2-2. ％系への割り振り：全面禁止 → **キャラ固有の例外を1軸だけ認める**

`GAME_DESIGN.md` 5-3 は「％系（`crit_rate` / `crit_dmg` / `atkspd` / `haste`）には振れない」と明記し、理由を「レベル100まで振り切った時点で紋章（装飾3段階目）が無意味になる」としている。

**弓に `atkspd` を認める。** 5-3 の禁止理由は、枝の長さ（＝上限）で担保する形に置き換える。

- `atkspd` 枝を全解放しても **+50%**（1.5秒 → 1.0秒）。`min_attack_interval_sec` 0.4 には当たらない
- 総ポイント100点に対し枝1本が50点なので、**全解放するには他の2枝を完全に捨てる**
- 紋章が乗る余地は残る

> **禁止を「枝の長さ」に置き換えたので、`crit_rate` / `crit_dmg` / `haste` の枝を将来足すときも同じ判断でよい。** ただし `crit_rate` は上限100%なので枝を長くすると死にノードが出る。足すときに考えること。

---

## 3. 決定事項（**この会話で確定した数値**）

**数値は全部仮でよい。** バランス実測は `PLAN_IMPLEMENTATION.md` 3章の12番。ここで決めた値は `character_config.gd` と `character_nodes.json` の2箇所にしか無く、あとから直せる。

### 3-1. ポイント

| | 値 |
|---|---|
| 1レベルあたり | **1点** |
| Lv100 到達時のみ | **2点** |
| Lv100 での合計 | **100点** |

計算式（状態に保存しない。`level` から毎回引く）：

```
総獲得ポイント = (level - 1) + (1 if level >= 100 else 0)
残ポイント     = 総獲得ポイント - 解放済みノードのコスト合計
```

### 3-2. 1点あたりの増分

| 軸 | 1点あたり |
|---|---|
| `hp` | **+5** |
| `atk` / `mag` / `def` / `mdef` | **+1** |
| `atkspd` | **+1**（＝+1%） |

### 3-3. 振れる軸（`allocatable_stats`）

| キャラ | 枝1 | 枝2 | 枝3 |
|---|---|---|---|
| `char_swordsman` | `hp` | `atk` | `def` |
| `char_archer` | `hp` | `atk` | **`atkspd`** |
| `char_priest` | `hp` | `mag` | `mdef` |

### 3-4. 枝の形（**3キャラ共通**）

**1枝 = 20段。コストは5段ごとに1つ上がる。**

| 段 | コスト | `hp` 枝の増分 | 他の枝の増分 |
|---|---|---|---|
| 1〜5 | 1点 | +5 | +1 |
| 6〜10 | 2点 | +10 | +2 |
| 11〜15 | 3点 | +15 | +3 |
| 16〜20 | 4点 | +20 | +4 |

- **1枝の全解放に50点。** 3枝で150点 ＞ 総ポイント100点 → **1本は必ず諦める**
- 1枝を全解放したときの合計：`hp` **+250** / 他の軸 **+50**
- **どの段でも「1点あたりの増分」は §3-2 と同じ。** 奥ほど1ノードが重くなるだけで、効率は変わらない

### 3-5. ノードIDの命名

```
node_<character_id>_<stat_key>_<段番号2桁>
例: node_char_swordsman_hp_01 … node_char_swordsman_hp_20
```

⚠ **リリース後に改名できない**（CLAUDE.md 4番）。改名すると解放済みノードが黙って消え、ステータスが減る。**キャラ略号にせず `character_id` をそのまま埋める。**

### 3-6. セーブ

- **`save_version` を 3 に上げる。** 旧セーブは弾かれて捨てられる（`GAME_DESIGN.md` 14章。今回の会話で確認済み）
- 増えるフィールドは **`character_growth.<id>.nodes`（解放済みノードIDの配列）1本だけ**
- **総獲得ポイントも、ノードの効果値も保存しない。** `level` とマスターデータから毎回引く（CLAUDE.md 4番）

---

## 4. 人間がやる作業

### 4-1. `initial_state_config.tres` の `save_version` を **3** にする

**⚠ `save_version` の出どころは3箇所ある**（`game_manager.gd` 197〜203行のコメント）。設計役が2つ直し、**Inspector が要る1つを人間が直す。**

| # | 場所 | 誰が |
|---|---|---|
| 1 | `game_manager.gd` 203行（`_empty_state_template()` の即値 `2`） | 設計役 |
| 2 | `save_manager.gd` 7行（`CURRENT_SAVE_VERSION`） | 設計役 |
| 3 | **`initial_state_config.tres` 16行（`save_version = 2`）** | **人間** |

3番は `.tres` に**実際に書き出されている**（既定値ではない）ので、テキスト編集でも直せる。**新規開始で実際に効くのはこれ。** ここだけ2のままだと、新規開始した直後のセーブが version 2 になり、次回起動で自分のセーブを弾く。

### 4-2. 旧セーブを消す

`user://saves/save_slot_0.json` を削除する。version 3 に上げたので**残っていても弾かれるだけ**だが、削除しておくとログが静かになる。

### 4-3. `ja.csv` を再インポート・`.tscn` を Godot で開いて確認

- **`ja.csv` は UTF-8（BOMなし）。** 編集後は Godot で再インポートが要る
- **`stat_node_screen.tscn` は設計役がテキストで書く。** Godot で開いてノードパスが壊れていないか見るのは人間

### 4-4. ドキュメントを更新する（**実装が通ってから**）

**勝手に直していない。承認をもらって直すか、人間が直す。**

| ファイル | 直す内容 |
|---|---|
| `GAME_DESIGN.md` 5-2 | 表の「5レベルごと」→「**1レベルごとに1点。Lv100到達時のみ2点（計100点）**」 |
| `GAME_DESIGN.md` 5-3 | 「％系には振れない」→「**原則振れない。キャラ固有の例外を枝1本ぶんだけ認める（弓の `atkspd`）。上限は枝の長さで担保する**」。あわせて**ノード式であること**を追記（現在は「配列に持たせる」としか書いていない） |
| `GAME_DESIGN.md` 14章 | 未決から「割り振りポイントの1回あたりの点数、軸ごとの効率」「キャラごとの `allocatable_stats` の中身」を**削除**（決まったため） |
| `GAME_DESIGN.md` 15章 | `stat_growth_formula` の行に「**2026-08-15 実施済み**」 |
| `PLAN_IMPLEMENTATION.md` 3章 | 3番にチェック。**1章の未チェック項目「ロード時に `_recalc_stats()` を通る経路がある」は今回で解消する**（§5-3） |
| `DATA_SCHEMA.md` | `character_growth.<id>.nodes` を追記 |
| `PROJECT_STATUS.md` | `save_version` 3・ノード式・宿題（§10） |
| `NEXT_STEPS.md` | 次のタスク（スキル解放）の内容に書き換える |

---

## 5. 設計役が書くもの

### 5-1. `res://resources/balance/master/character_nodes.json`（**新規**）

`research.json` と同じく **`node_id` をキーにした Dictionary**。1キャラ3枝×20段 ＝ **60ノード × 3キャラ ＝ 180件**。

```json
{
	"node_char_swordsman_hp_01": {
		"character_id": "char_swordsman",
		"stat": "hp",
		"tier": 1,
		"cost": 1,
		"value": 5,
		"prerequisites": []
	},
	"node_char_swordsman_hp_02": {
		"character_id": "char_swordsman",
		"stat": "hp",
		"tier": 2,
		"cost": 1,
		"value": 5,
		"prerequisites": ["node_char_swordsman_hp_01"]
	}
}
```

- **`prerequisites` は1つ手前のノードだけ。** `research.json` と同じ形にして、判定コードを流用できるようにする
- **枝の所属は `stat` で表す。** 別に `branch` を持たない（同じ情報を2箇所に置かない）
- **`value` は `cost × §3-2 の効率`。** 生成時に計算して JSON に書き出す（実行時に掛けない。マスターを見れば効果が分かる状態にする）
- **インデントはタブ**（既存の `.json` に合わせる）

⚠ **180件を手書きしない。** 生成スクリプトを `tests/` に置いて出力を貼るか、この指示書の表から機械的に展開する。**手書きすると `prerequisites` のIDを1つ間違えて枝が途中で切れる。**

### 5-2. `res://scripts/systems/master_data_loader.gd`（**末尾に追記のみ**）

既存の関数・定数・`static var` に触らない。`get_research_node()` と同じ遅延ロードの形。

```gdscript
# ========================================================================
# ステータスノード（EXEC_LEVEL_ROLE_SHIFT.md §5-2）。既存に触らず末尾追記。
# get_research_node() と同じく _ensure_loaded() には組み込まず、遅延ロードする。
# ========================================================================

const PATH_CHARACTER_NODES: String = DIR_PATH + "character_nodes.json"

static var _cache_character_nodes: Dictionary = {}
static var _character_nodes_loaded: bool = false


static func get_character_node(node_id: String) -> Dictionary:
	_ensure_character_nodes_loaded()
	if not _cache_character_nodes.has(node_id):
		push_error("[MasterDataLoader] character node id not found: " + node_id)
		return {}
	return (_cache_character_nodes[node_id] as Dictionary).duplicate(true)


# 全件返す。GameManager がボーナスを合計するときに使う。
static func get_all_character_nodes() -> Dictionary:
	_ensure_character_nodes_loaded()
	return _cache_character_nodes.duplicate(true)


static func _ensure_character_nodes_loaded() -> void:
	if _character_nodes_loaded:
		return
	_character_nodes_loaded = true
	_cache_character_nodes = _load_json(PATH_CHARACTER_NODES)
```

⚠ **`get_all_characters()` が無い件は今回も直さない**（`training_screen.gd` の `CHARACTER_IDS` 決め打ちのまま）。新画面も同じ決め打ちを増やさないよう、**`character_id` は必ず遷移時に `TransferKeys` で渡す**（`equipment_screen` と同じ形）。

### 5-3. `res://autoload/game_manager.gd`

**触るのは既存3箇所＋新規6関数。**

| # | 場所 | 内容 |
|---|---|---|
| a | `_empty_state_template()` 203行 | `SAVE_VERSION: 2` → **3** |
| b | `_default_growth_for()` 1074行〜 | `GROWTH_NODES: []` を追加 |
| c | `get_effective_stats()` 923行〜 | **第5項として `get_stat_node_bonus()` を足す** |
| d | `load_state()` 2198行〜 | `nodes` の型を検査（`Array` でなければ `[]`）。**`int()` 正規化は不要**（中身は文字列） |
| e | `load_state()` 2211行付近 | **全キャラに `_recalc_stats()` を通す経路を追加**（下記） |
| f | 新規 | ノード6関数 |

#### e：ロード時の `_recalc_stats()`（**今回の本質的な修正**）

`load_state()` は `_normalize_equipment_from_save()` / `_sync_research_tree_from_master()` / `_sync_shops_from_master()` / `_sync_recipes_from_master()` は呼ぶが、**`_recalc_stats()` を呼んでいない**（実コードで確認済み）。

`stat_growth_formula` を `"base"` にしても、**旧セーブの `growth.stats` は伸びた値のまま残る。** `save_version` を3に上げれば当面は防げるが、**今後バランス調整で式を触るたびに同じ事故が起きる。**

```gdscript
# セーブから戻した stats を、現在の stat_growth_formula で計算し直す。
# 状態に残っている数値ではなくマスター＋式を正とする（_sync_research_tree_from_master() と同じ考え方）。
#
# これが無いと、式を変えたときに「新規開始では効くが、ロードすると古い値のまま」になる。
# PLAN_IMPLEMENTATION.md 1章の未チェック項目「ロード時に _recalc_stats() を通る経路がある」はこれ。
func _resync_growth_stats_from_master() -> void:
	var growth_all: Dictionary = _state.get(GameStateKeys.CHARACTER_GROWTH, {})
	for character_id: String in growth_all:
		if not (growth_all[character_id] is Dictionary):
			continue
		var entry: Dictionary = growth_all[character_id]
		var level: int = int(entry.get(GameStateKeys.GROWTH_LEVEL, 1))
		var recalculated: Dictionary = _recalc_stats(character_id, level)
		# characters.json から消えたキャラは _recalc_stats() が {} を返す。
		# 空で上書きすると全ステータスが 0 になるため、そのまま残す。
		if recalculated.is_empty():
			continue
		entry[GameStateKeys.GROWTH_STATS] = recalculated
```

`_state` に代入したあと、`_normalize_equipment_from_save()` の**直前**で呼ぶ。

#### f：新規6関数（`_write_growth()` の直後、`select_skill()` の手前に置く）

```gdscript
# --- 育成：ステータスノード ---

# 現在のレベルで得られる総ポイント。状態に保存しない（level から毎回引く）。
# GAME_DESIGN.md 5-2：1レベルにつき1点。最大レベル到達時のみ2点（合計100点）。
func get_stat_node_total_points(character_id: String) -> int:
	var level: int = int(get_character_growth(character_id).get(GameStateKeys.GROWTH_LEVEL, 1))
	var points: int = level - 1
	if level >= MAX_CHARACTER_LEVEL:
		points += 1
	return points

# 解放済みノードが使っているポイントの合計。
func get_stat_node_spent_points(character_id: String) -> int

# 残ポイント。画面が出す数字はこれ。
func get_stat_node_remaining_points(character_id: String) -> int

# 解放済みノードのステータス合計。get_effective_stats() の第5項。
# 戻り値は stat_key -> int。振っていない軸はキーごと入れない。
func get_stat_node_bonus(character_id: String) -> Dictionary

# 前提条件を満たしているか（ポイントは見ない）。
# 画面が「前提未解放」と「ポイント不足」を区別して出すために分ける
# （can_unlock_research_node() と同じ形）。
func can_unlock_stat_node(character_id: String, node_id: String) -> bool

# ノードを1つ解放する。
# ⚠ 状態を変える前に全部の判定を終えること（CLAUDE.md 6番）：
#     1. ノードが存在するか
#     2. そのノードが character_id のものか（他キャラのノードを弾く）
#     3. 既に解放済みでないか
#     4. 前提条件を満たしているか
#     5. 残ポイントが cost 以上か
#   ここまで全部通ってから nodes に append し、_write_growth() する。
func unlock_stat_node(character_id: String, node_id: String) -> bool

# 全解除。無料（GAME_DESIGN.md 5-3「いつでも無料で振り直せる」）。
# nodes を [] にするだけ。ポイントは level から引いているので自動で戻る。
func reset_stat_nodes(character_id: String) -> bool
```

- **全部 `character_growth_changed.emit(character_id)` で終わる。** 画面は戻り値ではなくシグナルで描き直す（`level_up_character()` と同じ）
- **`MAX_CHARACTER_LEVEL` は `character_config.gd` に `@export var max_character_level: int = 100` として置く。** `game_manager.gd` に定数をベタ書きしない
- ⚠ **`.tres` は `@export` の既定値を書き出さない。** `character_config.tres` に `max_character_level` の行は現れない。**効くのは `.gd` の 100**（CLAUDE.md／`NEXT_STEPS.md` 3章の罠）

### 5-4. `res://scripts/utils/state_keys.gd`（124行の直後に1行）

```gdscript
# 解放済みステータスノードのID配列（EXEC_LEVEL_ROLE_SHIFT.md）。
# 中身はIDだけ。効果値は character_nodes.json から毎回引く（CLAUDE.md 4番）。
const GROWTH_NODES: String = "nodes"
```

120行のコメント `# CHARACTER_GROWTH: {character_id: {level, stats, skills, equipment}}` も `nodes` を足して直す。

### 5-5. `res://resources/balance/character_config.gd`

```gdscript
# --- 最大レベル ---
# 研究で解放される実効上限（get_effective_level_cap()）とは別。
# ここは「設計上いくつまで上げられるか」の天井で、最終レベル到達ボーナスの判定にも使う。
@export var max_character_level: int = 100
```

`stat_growth_formula` の既定値を **`"base"`** に変える（31行）。**コメントも直す**（「レベルで伸びない。伸ばすのはステータスノード」と書く）。

⚠ **順番を守ること。** `"base"` 化は §6 の**最後**。ノードが動く前に変えると、レベルアップが完全に無意味な状態が途中に生まれる。

### 5-6. `res://resources/balance/master/characters.json`

3キャラに `allocatable_stats` を足す（§3-3）。

```json
"allocatable_stats": ["hp", "atk", "def"]
```

- **画面が枝を並べる順序がこの配列の順序になる。** `_stat_keys()` の順に並べ替えない
- **`growth_per_level` は消さない。** `stat_growth_formula` が `"base"` なので使われなくなるが、消すと式を戻したときに全キャラ伸びなくなる。**死にデータとして §10 の宿題に積む**

### 5-7. `res://scenes/guild/stat_node_screen.tscn` ＋ `.gd`（**新規**）

**育成画面には置かない。** 3枝×20段のツリー描画は `training_screen.gd` の詳細パネルに収まらない。`equipment_screen` と同じく独立画面にし、`TransferKeys.CHARACTER_ID` で対象を受け取る。

画面の構成：

```
残ポイント 37 / 100
[ 振り直す ]

  hp          atk          def
  ●  +5       ●  +1        ●  +1
  ●  +5       ●  +1        ○  +1
  ○  +5       ○  +1        ○  +1
  ...（20段。ScrollContainer で縦スクロール）

[ 戻る ]
```

- **`●`＝解放済み / `○`＝解放可能 / `✕`＝前提未解放**。ポイント不足は「押せるが失敗する」のではなく**ボタンを `disabled`** にする（`training_screen.gd` の `level_up_button` と同じ判断）
- **枝は `allocatable_stats` の順に3列。** 列数を決め打ちしない（配列の長さで回す）
- 軸名の翻訳キーは既存の **`ui_training_stat_<key>`** を流用する。**新しく作らない**（10軸のときに `_stat_labels()` の二重管理で事故った形）
- ％系は `GameManager.is_percent_stat()` で `%` を付ける（`training_screen.gd` 206行と同じヘルパー）

⚠ **再描画に `await` を持たせない**（CLAUDE.md 5番）。`character_growth_changed` で描き直すとき、**`remove_child()` してから `queue_free()`**。振り直しは1操作で60ノードが一斉に変わるので、ここが一番危ない。

### 5-8. `res://scenes/guild/training_screen.gd`

`skill_button` の下に**ノード画面へのボタンを1本足す**（`.tscn` にもノードを追加）。`_on_equip_pressed()` と同じ形。

```gdscript
const STAT_NODE_PATH: String = "res://scenes/guild/stat_node_screen.tscn"

func _on_stat_node_pressed() -> void:
	if _selected_id == "":
		return
	SceneManager.change_scene_with_data(STAT_NODE_PATH, {TransferKeys.CHARACTER_ID: _selected_id})
```

**`skill_button` は触らない**（`placeholder_screen` へ飛ぶまま。次回のタスク）。

### 5-9. `res://autoload/save_manager.gd`

7行の `CURRENT_SAVE_VERSION` を **3** に。コメントに理由を書く：

```gdscript
# character_growth に nodes（解放済みステータスノード）が増え、
# stat_growth_formula が "base" になって stats の意味が変わったため 3 へ。
# 旧バージョンは読み込まず捨てる（GAME_DESIGN.md 14章）。移行処理は書かない。
const CURRENT_SAVE_VERSION: int = 3
```

### 5-10. `res://localization/ja.csv`（**追加のみ**）

| キー | ja |
|---|---|
| `ui_training_stat_node` | ステータスノード |
| `ui_nav_stat_node` | ステータスノード |
| `ui_stat_node_points` | 残ポイント %d / %d |
| `ui_stat_node_reset` | 振り直す |
| `ui_stat_node_locked` | 前提が未解放 |
| `ui_stat_node_no_points` | ポイントが足りない |

**UTF-8（BOMなし）。** 既存行を消さない。再インポートは人間（§4-3）。

---

## 6. 作業の順番

**⚠ `stat_growth_formula` の `"base"` 化は最後。** 割り振りが動く前に変えない（`NEXT_STEPS.md` 3章）。

1. `state_keys.gd` に `GROWTH_NODES`
2. `character_nodes.json` を生成（180件）
3. `master_data_loader.gd` に3関数を末尾追記
4. `characters.json` に `allocatable_stats`
5. `character_config.gd` に `max_character_level`（**`stat_growth_formula` はまだ触らない**）
6. `game_manager.gd`：新規6関数 → `_default_growth_for()` → `get_effective_stats()` → `load_state()`（`nodes` 検査＋`_resync_growth_stats_from_master()`）→ `_empty_state_template()` の `save_version`
7. `save_manager.gd` の `CURRENT_SAVE_VERSION`
8. `stat_node_screen.tscn` ＋ `.gd`
9. `training_screen.gd` ＋ `.tscn` にボタン
10. `ja.csv`
11. **人間が `initial_state_config.tres` を3にする（§4-1）**
12. **人間が実機で §7〜§9 を確認する**
13. **ここまで通ってから `character_config.gd` の `stat_growth_formula` を `"base"` に**
14. **もう一度 §7-5 だけ確認する**

⚠ **各編集の直後に `grep -n "<新しい関数名>" <ファイル>` が0件でないことを確認する**（CLAUDE.md 2番）。特に `get_effective_stats()` への第5項の追加。**「割り振りだけ反映されない」は前回と同じ形の事故になる。**

⚠ **1ファイルへの書き込みが2回失敗したら中止して報告する**（CLAUDE.md）。

---

## 7. 完了条件：画面（人間が実機で確かめる）

| # | 手順 | 期待 |
|---|---|---|
| 7-1 | デバッグオーバーレイ（`0`）→ 素材を全種類 → 研究を全部解放 → 育成画面 | レベル上限が上がっている |
| 7-2 | 剣士を Lv10 まで上げる → **ステータスノード**ボタン | 新画面。**残ポイント 9 / 9**。3列（hp / atk / def）が20段ずつ |
| 7-3 | hp 枝の1段目を押す | `●` になり、**残ポイント 8 / 9**。hp の段は 1〜5 が `+5` |
| 7-4 | hp 枝の**3段目**を先に押す | **押せない**（2段目が未解放。`✕` 表示） |
| 7-5 | 戻る → 育成画面の詳細 | **hp が +5 されている**（ノードの効果が `get_effective_stats()` に乗っている） |
| 7-6 | 装備画面を開く | **同じく +5 されている**（2箇所で同じ値。片方だけ反映は事故） |
| 7-7 | 戦闘に入り `F3` | デバッグパネルの hp が育成画面と一致 |
| 7-8 | ノード画面 → 振り直す | **全部 `○` に戻り、残ポイントが 9 / 9 に戻る**。行が二重に並ばない |
| 7-9 | 残ポイント0まで振ってから、もう1つ押す | **ボタンが `disabled`**（押せて失敗、ではない） |
| 7-10 | 弓のノード画面 | 3列目が **`atkspd`**。値が `+1%` と `%` 付きで出る |
| 7-11 | 僧侶のノード画面 | 2列目が `mag`、3列目が `mdef` |
| 7-12 | **手順13のあと**：新規開始 → 剣士を Lv5 まで上げる | **ステータスが1つも増えていない**（`"base"` 化。増えるのはノードだけ） |

---

## 8. 完了条件：ログ（Godotの出力パネル）

| # | 期待 |
|---|---|
| 8-1 | 起動時に `[MasterDataLoader] loaded ...` が出る、または `character_nodes.json` の読み込みで `push_error` が**出ない** |
| 8-2 | ノード解放時に `[GameManager] unlock_stat_node('char_swordsman', 'node_char_swordsman_hp_01') -> true (spent=1 remaining=8)` |
| 8-3 | 前提未達で押したとき（デバッグ経路）に `-> false (prerequisite ...)` |
| 8-4 | 振り直しで `[GameManager] reset_stat_nodes('char_swordsman') -> true (cleared 3 nodes)` |
| 8-5 | ロード時に `[GameManager] load_state success. version=3` |
| 8-6 | **旧セーブが残っている場合**：`[SaveManager] load_game: version mismatch (have=2, expected=3) - refusing to load`。**`push_error` ではなく `push_warning`** |

---

## 9. 完了条件：セーブファイル（`user://saves/save_slot_0.json`）

| # | 期待 |
|---|---|
| 9-1 | `"save_version": 3` |
| 9-2 | `character_growth.char_swordsman.nodes` が **文字列の配列**（`["node_char_swordsman_hp_01", ...]`） |
| 9-3 | **`nodes` の中身以外に何も増えていない。** ポイント数・ノードの効果値・`allocatable_stats` がセーブに現れない（CLAUDE.md 4番） |
| 9-4 | `stats` の値に **`.0` が付いていない**（`"hp": 120` であって `"hp": 120.0` ではない） |
| 9-5 | **手順13のあと**：Lv5 のキャラの `stats` が Lv1 と同じ値 |

---

## 10. UIから到達できない項目（**人間は確認しない**）

将来コードを変えたときに見る項目。

- `unlock_stat_node()` に**他キャラのノードID**を渡したとき `false`（画面は自分の枝しか出さないので到達しない）
- `character_nodes.json` から**ノードを削除した**とき、セーブに残ったIDが無視されて落ちない
- `characters.json` から**キャラを削除した**とき、`_resync_growth_stats_from_master()` が空で上書きせずスキップする
- `allocatable_stats` に**％系を2軸**入れたときの画面（今は弓の1軸だけ）

---

## 11. 併せて直さないもの

- **`select_skill()`**（空実装のまま。呼び出し元0件のまま。次回）
- **`growth.skills`**（`{}` のまま）
- **`training_screen.gd` の `CHARACTER_IDS` 決め打ち**（`MasterDataLoader.get_all_characters()` が無い件。§10 の宿題）
- **`growth_per_level`**（死にデータになるが消さない。§5-6）
- **`adventure_config.tres` に上限3値を書く件**（前回からの宿題。動作に影響しない）
- **バランス調整**（敵HP・スキル倍率。`PLAN_IMPLEMENTATION.md` 3章の12番）

---

## 12. このタスクで残す宿題（`PROJECT_STATUS.md` に積む）

- **`characters.json` の `growth_per_level` が死にデータになった。** `stat_growth_formula` が `"base"` の間は使われない。消すか残すかを決める
- **`character_nodes.json` が180件ある。** キャラを1人足すたびに60件増える。生成スクリプトを `tests/` に残すか決める
- **ノードの `value` は §3-2 の効率をそのまま掛けただけの仮値。** バランス実測（3章の12番）で調整する
- **`MasterDataLoader.get_all_characters()` が無い。** `training_screen.gd` と、今後のプリセット画面（3章の7番）で同じ決め打ちが増える
- **`crit_rate` / `crit_dmg` / `haste` の枝を将来足すとき、`crit_rate` は上限100%で死にノードが出る**（§2-2）
- **検証用のものはリリース前に消す**（デバッグオーバーレイ・0Gスロット・`weapon_debug_blade`）

---

## 13. 実施結果（2026-08-15）

**§6 の手順1〜10 を実施した。11・12（人間）と 13・14（`"base"` 化）は未了。**

### 13-1. 書いたもの

| ファイル | 内容 | 確認 |
|---|---|---|
| `state_keys.gd` | `GROWTH_NODES` 追加。120行のコメントも更新 | `grep` 済み |
| `character_nodes.json`（新規） | **180件**。生成スクリプトで出力 | 検算：1枝50点・`hp`枝 +250 / 他 +50。§3-4 と一致 |
| `master_data_loader.gd` | 末尾に `get_character_node()` / `get_all_character_nodes()` / `_ensure_character_nodes_loaded()` | `grep` 済み（335〜364行） |
| `characters.json` | 3キャラに `allocatable_stats` | JSONパース確認済み |
| `character_config.gd` | `max_character_level: int = 100` | — |
| `game_manager.gd` | 定数6本 ＋ 新規関数8本 ＋ 既存5箇所 | `grep` 済み（下表） |
| `save_manager.gd` | `CURRENT_SAVE_VERSION` → 3 | — |
| `stat_node_screen.gd` / `.tscn`（新規） | ノード画面 | タブインデント確認済み |
| `training_screen.gd` / `.tscn` | `StatNodeButton` と `_on_stat_node_pressed()` | `grep` 済み |
| `ja.csv` | 4行追加。**BOM無しを確認** | `od -c` で `k e y` を確認 |

`game_manager.gd` の変更箇所：

| 行 | 内容 |
|---|---|
| 57〜62 | `STAT_NODE_*` 定数6本 |
| 212 | `SAVE_VERSION: 3` |
| 927・937 | `get_effective_stats()` の**5項目め** |
| 1092 | `_default_growth_for()` に `GROWTH_NODES: []` |
| 1138 | `_resync_growth_stats_from_master()`（新規） |
| 1579〜1726 | ノード関数7本 |
| 2412 | `load_state()` の `nodes` 型検査 |
| 2420 | `load_state()` から `_resync_growth_stats_from_master()` を呼ぶ |

### 13-2. この指示書からの逸脱（**2件**）

**① 翻訳キー `ui_training_stat_node` → `ui_training_nodes`**

§5-10 では `ui_training_stat_node` としていたが、**軸ラベルの機械生成キー `ui_training_stat_<軸>` と1文字違いで紛らわしい**。将来 `node` という名前の軸を作ることは無いが、`_stat_value_text()` が `"ui_training_stat_" + stat_key` で引く形なので、並べたときに読み間違える。`ui_training_nodes` に変えた。

**② 最大レベルの持ち方**

§5-3 では `MAX_CHARACTER_LEVEL` と書いたが、`character_config.gd` の `@export var max_character_level` にした（§5-5 の記述どおり）。`get_stat_node_total_points()` は `Balance.character` が `null` のときだけ 100 にフォールバックする。

### 13-3. 手順11〜13の実施（2026-08-15・2回目）

| # | 状況 |
|---|---|
| 11 | **人間が実施済み**（`initial_state_config.tres` の `save_version` を3に） |
| 12 | **人間が実施済み。§7 の確認が通った**（列幅の不具合1件を除く。13-6） |
| 13 | **実施した。** `character_config.gd` の `stat_growth_formula` を `"base"` に |
| 14 | **未了。** §7-12 と §9-5 の再確認が残っている |

⚠ **`character_config.tres` に `stat_growth_formula` の行が無いことを確認した**（`.tres` 全文に `level_up_material_id` / `base_level_up_cost` / `cost_growth_per_level` の3行しか無い）。**効いているのは `.gd` の `"base"`。** `max_character_level` も同様に `.tres` に現れず、`.gd` の 100 が効く。

### 13-4. 実装環境で確認できていないこと

**Godot を起動できないため、以下は人間の確認待ち。**

- `stat_node_screen.tscn` に `unique_id=` を書いていない。既存の `.tscn` は全ノードに持っているが、新規ぶんの値を作れないため省略した。**Godot が開いたときに再生成されるはずだが、確認が要る**
- `[gd_scene format=3]` に `uid` を書いていない（同上）
- `.gd` の `.uid` ファイルも無い。`ext_resource` は `path` のみで参照している（`primary_button.tscn` の参照と同じ形）
- **GDScript の構文チェックをしていない。** パースエラーは Godot で開いて初めて出る

### 13-6. 実機で出た不具合（1件・修正済み）

**症状：ステータスノード画面の3列の幅が列ごとに違う。**

原因は2つ重なっていた。

1. **列（`VBoxContainer`）に `size_flags_horizontal` を付けていなかった。** 各列が中身の最小幅のまま並ぶため、軸名の長さ（`HP` と `物理防御`）とボタン文字列の％の有無（`+1` と `+1%`）で幅が変わる
2. **`ScrollContainer` の `horizontal_scroll_mode` が既定（自動）だった。** ScrollContainer は既定で子に「中身に必要な幅」を与えるため、子の `SIZE_EXPAND_FILL` が効かない

修正：

| ファイル | 変更 |
|---|---|
| `stat_node_screen.tscn` | `Scroll` に `horizontal_scroll_mode = 0`（無効）。**これを付けないと下の2つが効かない** |
| `stat_node_screen.gd` `_build_branch()` | 列と見出しに `Control.SIZE_EXPAND_FILL`。`stretch_ratio` は既定の1のままで3列が等幅になる |
| 同上・ボタン生成 | ボタンにも `Control.SIZE_EXPAND_FILL`（段ごとに右端が揃うように） |

> **列を増やしても等幅のまま。** `allocatable_stats` が4軸のキャラを作っても、列数で自動的に割れる。

### 13-5. 気づいた点

- `get_effective_stats()` は戦闘のユニット生成でも呼ばれる。`get_stat_node_bonus()` が解放ノード数ぶん `MasterDataLoader.get_character_node()`（`duplicate(true)`）を回すため、**Lv100 で最大100回**の小さな辞書複製が乗る。今の規模では問題ないが、装飾（3章の6番）で同じ形の合成が増えたら見直す
- **`character_nodes.json` の生成スクリプトはスクラッチパッドに置いた。リポジトリには入れていない。** §12 の宿題どおり、残すかどうかは未決
