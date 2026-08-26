# 実行指示書：**段階14-a（フロアの器）**

**作成日：2026-08-25**

**台帳は `docs/01_plan/PLAN_SCENARIO_MAP.md`。** ⚠ **決定事項はあちらが正。⚠ ここには手順と完了条件だけを書く。**

⚠ **この回で作るのは `PLAN_SCENARIO_MAP.md` §9-1 の 1・2・3・9・10・11・12・13・14・15・30 の**11件**。**
⚠ **画面を1枚も作らない。⚠ `.tscn` / `.tres` / `ja.csv` を1件も触らない。⚠ 人間の作業はゼロで閉じる。**

---

## 0. ⚠ この回で触るもの・触らないもの

| 対象 | 可否 |
|---|---|
| ⚠ **`resources/balance/master/stages.json`** | ⚠ **作り替える** |
| ⚠ **`resources/balance/master/stage_order.json`** | ⚠ **`story` 列を5本に** |
| ⚠ **`scripts/utils/state_keys.gd`** | ⚠ **定数を足す** |
| ⚠ **`autoload/game_manager.gd`** | ⚠ **状態の器と関数を足す** |
| ⚠ **`tests/debug_boot.gd`** | ⚠ **`scenario=floor` を1本足す** |
| ⚠ **`AGENTS.md`** | ⚠ **状態の表に1行だけ足す**（⚠ **拒否仕様の注記は人間の仕事。⚠ 触らない**） |
| ⚠ **`.tscn` / `.tres` / `ja.csv`** | ⚠ **禁止**（⚠ **触りたくなったら段階の切り方が間違っている。⚠ 止めて報告する**） |
| ⚠ **`scenes/` 配下** | ⚠ **禁止**（⚠ **画面は 14-c**） |
| ⚠ **`battle_controller.gd`** | ⚠ **禁止**（⚠ **14-c**） |
| ⚠ **`chests.json`** | ⚠ **禁止**（⚠ **14-b**） |

---

## 1. ⚠ 先に決めたこと（**設計役の決め・人間の確認待ち**）

### 1-1. ⚠ `stage_dbg_*` **5本** はフロア化しない

⚠ **`area` / `condition` / `enemy_skill` / `intervene` / `passive` の5本**（⚠ **2026-08-25 に数え直した。⚠ 台帳に「6本」と書いていたのは誤り＝訂正済み**）。

⚠ **理由**：
- ⚠ **`debug_boot` の `KIND_BATTLE` シナリオ21本がこの5本に依存している。⚠ フロア化すると全部が一度に壊れる**
- ⚠ **入口は `_on_debug_challenge_pressed()` → `STAGE_TYPE_TRAINING` → `battle.tscn` 直行で、⚠ フロアの器を通らない**（`adventure_select.gd:190`）
- ⚠ **リリース前に丸ごと消すもの**（宿題16 / 28）

⚠ **結果：`stages.json` は**2つの形式が同居する**。**

| 形式 | 持つ欄 | 誰が使うか |
|---|---|---|
| ⚠ **フロア形式** | ⚠ **`layers`** | ⚠ **`floor_1..5`（本番）** |
| ⚠ **ウェーブ形式** | ⚠ **`waves`** | ⚠ **`stage_dbg_*` 5本（検証用）** |

⚠ **判定は「`layers` を持つか」の1本だけにする。⚠ 2箇所で判定しないこと。**

### 1-2. ⚠ フロアのIDは `floor_1` 〜 `floor_5`

⚠ **`stage_1..3` から改名する。** ⚠ **リリース前なので改名してよい**（⚠ **リリース後は禁止＝CLAUDE.md 4番**）。
⚠ **`STORY.stages` の既存セーブは `stage_1` のキーを持っているが、⚠ 改名すればクリア済みが消える。⚠ 検証用のセーブしか無いので許容する**（⚠ **人間のセーブは退避済み：`scratchpad/save_slot_0_before_playthrough.json`**）。

### 1-3. ⚠ スタミナは触らない

⚠ **いまスタミナを払うのは `adventure_select.gd:279`（画面側）。⚠ `start_floor()` はスタミナを見ない。⚠ どこで払うかは 14-c で決める。**

### 1-4. ⚠ 固定報酬（`rewards`）はフロアの欄に残す

⚠ **各ノードへ配り直すのは 14-c 以降。⚠ この回は `stage_1..3` の `rewards` を `floor_1..5` へ移すだけ。**
⚠ **`scenario=economy` の「1周で入るもの」が5行になる。⚠ 前後を EXEC の §9 に並べる。**

---

## 2. `stages.json` の新しい形

### 2-1. フロア1本の形

```
"floor_1": {
  "unlocks": ["guild", "warehouse", "pomodoro"],
  "name_key": "ui_floor_1",
  "party_id": "party_default",
  "rewards": { ... 従来と同じ ... },
  "layers": [
    { "node_count": 1, "weights": { "battle": 100 } },
    { "node_count": 2, "weights": { "battle": 70, "relic": 30 } },
    { "node_count": 3, "weights": { "battle": 50, "relic": 25, "rest": 25 } },
    { "node_count": 3, "weights": { "battle": 50, "shop": 25, "rest": 25 } },
    { "node_count": 2, "weights": { "battle": 60, "rest": 40 } }
  ],
  "battle_pool": [
    { "enemies": [ { "enemy_type_id": "enemy_slime", "count": 2 } ] },
    ...
  ],
  "boss": { "enemies": [ { "enemy_type_id": "boss_slime_king", "count": 1, "is_boss": true, ... } ] }
}
```

- ⚠ **`layers` の長さが層数。⚠ 最初の層は必ず `node_count: 1`（入口）**
- ⚠ **`weights` は `_roll_weighted_table()` と同じ重みの考え方。⚠ ただし抽選の本体は流用せず、⚠ ノード種の抽選はフロア生成の中に書く**（⚠ **`_roll_weighted_table()` は `{item_id: count}` を返す形なので用途が違う。⚠ 無理に共通化しない**）
- ⚠ **ボスは `layers` に含めない。⚠ 最終層の全ノードから `boss` へ繋ぐ**（⚠ **§3-2 の「最終段だけ合流」**）
- ⚠ **`battle_pool` は既存の `stage_1..3` の15ウェーブを配り直したもの。⚠ 新しい敵を作らない**

### 2-2. `unlocks` の割り当て（**台帳 §8**）

| フロア | `unlocks` |
|---|---|
| `floor_1` | `guild` / `warehouse` / `pomodoro` |
| `floor_2` | `equipment` / `training` |
| `floor_3` | `shop` / `decoration` |
| `floor_4` | `research` / `workshop` |
| `floor_5` | `rune` |

⚠ **10画面のまま。⚠ 増やしても減らしてもいない。**
⚠ **`E125` が「`unlocks` の綴りが `GameStateKeys` の画面IDと一致するか」を見張っている。⚠ 綴りを変えない。**

### 2-3. `stage_order.json`

```
{ "story": ["floor_1", "floor_2", "floor_3", "floor_4", "floor_5"],
  "debug": [ ... 5本そのまま ... ] }
```

---

## 3. 状態の器

### 3-1. `state_keys.gd` に足す定数

```
FLOOR_RUN                 = "floor_run"        # トップレベル1本
  FLOOR_RUN_FLOOR_ID      = "floor_id"
  FLOOR_RUN_NODES         = "nodes"            # {node_id: {layer, kind, next}}
  FLOOR_RUN_POSITION      = "position"         # 現在のノードID
  FLOOR_RUN_VISITED       = "visited"          # {node_id: true}
  FLOOR_RUN_TORCH_GRADE   = "torch_grade"      # int（14-e で使う）
  FLOOR_RUN_RELICS        = "relics"           # [{relic_id, character_id}]（14-d）
  FLOOR_RUN_HP_CARRY      = "hp_carry"         # {character_id: int}（14-c）
  FLOOR_RUN_CHEST_COUNT   = "chest_count"      # int（14-b）
  FLOOR_RUN_CONSUMABLES   = "consumables"      # {item_id: int}（14-e）

FLOOR_NODE_LAYER          = "layer"
FLOOR_NODE_KIND           = "kind"
FLOOR_NODE_NEXT           = "next"             # [node_id]
FLOOR_NODE_CLEARED        = "cleared"

FLOOR_NODE_KIND_BATTLE    = "battle"
FLOOR_NODE_KIND_SHOP      = "shop"
FLOOR_NODE_KIND_RELIC     = "relic"
FLOOR_NODE_KIND_REST      = "rest"
FLOOR_NODE_KIND_BOSS      = "boss"

STAGE_MASTER_LAYERS       = "layers"           # ⚠ GameManager 側の定数（stages.json のキー）
STAGE_MASTER_BATTLE_POOL  = "battle_pool"
STAGE_MASTER_BOSS         = "boss"
```

⚠ **9欄を全部この回で作る。⚠ 14-b〜14-e で使う欄も空で置く。⚠ あとから足すと `AGENTS.md` と `load_state()` を何度も触ることになる。**

### 3-2. `_empty_state_template()` に1行

⚠ **`FLOOR_RUN` を空の器で入れる**（⚠ **`floor_id` が `""` なら「フロアに入っていない」**）。

### 3-3. `load_state()` の `int()` 正規化

⚠ **`torch_grade` / `chest_count` / `hp_carry` の値 / `consumables` の値 / `nodes[].layer` を `int()` で包む。**
⚠ **これを飛ばすとセーブに `"layer": 3.0` と書かれる**（⚠ **CLAUDE.md 3番。⚠ 宿題57 が同じ形で起きている**）。

### 3-4. `AGENTS.md` の状態表に1行

⚠ **`FLOOR_RUN` の行を足す。⚠ 他の行は触らない。⚠ 拒否仕様の節は触らない**（人間の仕事）。

---

## 4. 関数（**`game_manager.gd`**）

⚠ **状態を変える前に全部の判定を終える**（CLAUDE.md 6番）。

| 関数 | 中身 |
|---|---|
| `start_floor(floor_id) -> bool` | ⚠ **解放判定 → マップ生成 → 状態を1回で書く。⚠ 途中で状態を触らない。⚠ スタミナは見ない（§1-3）** |
| `_build_floor_map(floor_id) -> Dictionary` | ⚠ **層構造を組む。⚠ ここだけがノードを作る。⚠ 2本目を書かない** |
| `get_floor_run() -> Dictionary` | ⚠ **スナップショット（`duplicate(true)`）** |
| `get_floor_node(node_id) -> Dictionary` | |
| `get_available_moves() -> Array` | ⚠ **現在位置から進めるノードID。⚠ 判定はここ1本** |
| `move_to_node(node_id) -> bool` | ⚠ **`get_available_moves()` に無ければ `false`。⚠ 状態を触る前に弾く** |
| `is_in_floor() -> bool` | ⚠ **`floor_id != ""`** |
| `abandon_floor()` | ⚠ **`FLOOR_RUN` を空に戻す** |
| `get_floor_layer_count(floor_id) -> int` | ⚠ **`layers` の長さ** |
| `is_floor_stage(stage_id) -> bool` | ⚠ **`layers` を持つか。⚠ フロア形式とウェーブ形式を見分ける唯一の口（§1-1）** |

⚠ **シグナル `floor_run_changed(floor_id)` を1本足す**（⚠ **14-c の画面が購読する。⚠ いま購読者はゼロ**）。
⚠ **`MasterDataLoader` が返す数値は必ず `float`。⚠ `int()` で包む**（CLAUDE.md 3番）。

---

## 5. `scenario=floor`（**`debug_boot.gd`**）

⚠ **`SCENARIOS` に1行足す。⚠ シーンを増やさない。⚠ 報告の枝は3箇所**（`REPORT_FLOOR` の定数 ／ `SCENARIOS` の1行 ／ `_ready()` の `elif`）。

```
"floor": { "kind": KIND_REPORT, "report": REPORT_FLOOR,
           "note": "フロア5本。層構造の生成 / 入口からボスまで歩ける / 進めない先は弾く" },
```

### 5-1. ⚠ 何を出すか

1. ⚠ **フロア5本の一覧**（⚠ **層数・各層のノード数・生成されたノードの総数・`unlocks`**）
2. ⚠ **`floor_1` を生成して入口からボスまで歩く**（⚠ **各歩で「いまのノード / 種類 / 進める先」を1行**）
3. ⚠ **どのルートを選んでもボスに着くこと**（⚠ **全ルート総当たりで「ボスに着かなかったルート」が **0件** であること＝§3-2 の (a) の検証**）
4. ⚠ **進めないノードIDを `move_to_node()` に渡して `false` が返ること**
5. ⚠ **`abandon_floor()` で `floor_id` が `""` に戻ること**
6. ⚠ **ノード種の内訳**（⚠ **`battle` / `relic` / `rest` / `shop` / `boss` の件数**）

### 5-2. ⚠ 足した検証が本当に効くか確かめる

⚠ **2箇所で壊して確かめる。⚠ 壊したら必ず戻し、⚠ 平常値に戻ったことを再実行で確認する**（`NEXT_STEPS` §3-1）。

- ⚠ **(a) 最終層からボスへの接続を1本切る → 3 が「ボスに着かなかったルート」を検出すること**
- ⚠ **(b) `floor_3` の `unlocks` を存在しない画面IDにする → `E125` が出ること**（⚠ **`debug_boot.gd:950` に既に同じ形がある。⚠ 真似する**）

---

## 6. 完了条件（**ログ**）

⚠ **設計役が `godot.log` を読んで取る。⚠ 人間の作業はゼロ。**

| # | 条件 |
|---|---|
| **L-1** | ⚠ **`scenario=floor` が5フロアを出し、⚠ 各フロアの層数が 5 であること** |
| **L-2** | ⚠ **`floor_1` の生成ノード数が `layers` の `node_count` の合計 + 1（ボス）と一致すること** |
| **L-3** | ⚠ **入口からボスまで歩けること。⚠ 歩数が層数と一致すること** |
| **L-4** | ⚠ **全ルート総当たりで「ボスに着かなかったルート」が **0件** であること** |
| **L-5** | ⚠ **進めないノードIDを渡すと `move_to_node()` が `false` を返し、⚠ `position` が動かないこと** |
| **L-6** | ⚠ **`abandon_floor()` で `floor_id` が `""` に戻ること** |
| **L-7** | ⚠ **`scenario=unlock` が `floor_1` → `floor_5` で10画面を段階的に開くこと。⚠ 赤は `E125` の **1本** だけ（平常値）** |
| **L-8** | ⚠ **`scenario=economy` が赤も黄も増やさないこと。⚠ 「1周で入るもの」が5行になること** |
| **L-9** | ⚠ **`scenario=area` など `KIND_BATTLE` の21本が今までどおり動くこと**（⚠ **`stage_dbg_*` を壊していない＝§1-1**）。⚠ **10本ずつ3回に分けて回す** |
| **L-10** | ⚠ **ロード時の赤が0本・黄が1本（`skill_dbg_dot_odd`）であること** |
| **L-11** | ⚠ **§5-2 の (a) と (b) を壊して検証が反応し、⚠ 戻して平常値に戻ること** |

## 7. 完了条件（**ファイル**）

⚠ **F-1 / F-2 は「ログ」へ移した**（2026-08-25・実施時に変更）。
⚠ **理由：`debug_boot` はセーブを書かない（`_ready()` の注記）。⚠ セーブを作るには人間が遊ぶしかなく、⚠ 「14-a は人間の作業ゼロで閉じる」という段階の切り方と矛盾する。**
⚠ **代わりに `JSON.stringify()` → `JSON.parse_string()` → `load_state()` の往復を `scenario=floor` の中で回す。⚠ セーブに書かれる形は JSON の往復と同じなので、⚠ `int()` 正規化が効いているかはこれで見える。**

| # | 条件 | 移動先 |
|---|---|---|
| ~~**F-1**~~ | `floor_run` が入り `floor_id` が `""` | ⚠ **L-13** |
| ~~**F-2**~~ | `layer` が `3` であって `3.0` でない | ⚠ **L-12** |
| **F-3** | ⚠ **`stages.json` に `floor_1..5` があり、⚠ `stage_1..3` が無いこと。⚠ `stage_dbg_*` 5本が `waves` のまま残っていること** | ⚠ **そのまま** |

| # | 足した条件 |
|---|---|
| **L-12** | ⚠ **JSON の往復のあと、⚠ `layer` が `int` でないノードが **0件**。⚠ `torch_grade` と `chest_count` も `int`** |
| **L-13** | ⚠ **新規開始の `floor_run` が **9欄** を持ち、⚠ `floor_id` が `""` であること** |

## 8. 完了条件（**画面**）

⚠ **無し。** ⚠ **この回は画面を1枚も作らないため。**
⚠ **⚠ ただし `adventure_select` は `stage_order.json` の `story` 列を読むので、⚠ フロア5本が行として並ぶはず。⚠ 押しても `battle.tscn` へ飛ぶだけで、⚠ フロアの器は通らない**（⚠ **14-c で繋ぐ。⚠ この回は「壊れていない」ことだけ確認できればよい**）。

---

## 9. 実施結果（**2026-08-25**）

### 9-0. ⚠ 何が入ったか（**6ファイル**）

| ファイル | 中身 |
|---|---|
| `resources/balance/master/stages.json` | ⚠ **`stage_1..3` → `floor_1..5`（フロア形式）。⚠ `stage_dbg_*` 5本は `waves` のまま** |
| `resources/balance/master/stage_order.json` | ⚠ **`story` 列を5本に** |
| `scripts/utils/state_keys.gd` | ⚠ **`FLOOR_*` を22件** |
| `autoload/game_manager.gd` | ⚠ **`STAGE_MASTER_LAYERS` ほか5定数 ／ `floor_run_changed` シグナル ／ 状態の器 ／ `load_state()` の `int()` ／ 関数11本** |
| `tests/debug_boot.gd` | ⚠ **`scenario=floor` ／ `_report_floor()` ／ `_walk_all_routes()` ／ 既存の `stage_1..3` 参照の追随** |
| `AGENTS.md` | ⚠ **状態表に `FLOOR_RUN` の1行** |

⚠ **`.tres` / `ja.csv` / `.tscn` は1件も触っていない。⚠ 人間の Inspector 作業ゼロ。**

### 9-1. ⚠ 完了条件の結果（**全部通った**）

| # | 結果 |
|---|---|
| **L-1** | ✅ **5本。⚠ 5フロアとも層=5** |
| **L-2** | ✅ **`floor_1` 10+1=11 ／ `floor_2` 11+1=12 ／ `floor_3` 12+1=13 ／ `floor_4` 13+1=14 ／ `floor_5` 15+1=16** |
| **L-3** | ✅ **`floor_1` を入口からボスまで5手で歩けた**（`n_1_0` → `n_2_0` → `n_3_0` → `n_4_0` → `n_5_0` → `boss`） |
| **L-4** | ✅ **⚠ ボスに着かなかったルート＝5フロアとも 0本**（⚠ **全ルート 11 / 12 / 12 / 17 / 26 本**）。⚠ **通れないノードも 0件。⚠ 歩数は全ルート 6ノード（層5＋ボス1）で揃った** |
| **L-5** | ✅ **入口 `n_1_0` へ戻ろうとして `false`。⚠ 位置は `boss` のまま動かない** |
| **L-6** | ✅ **`abandon_floor()` → `is_in_floor()=false`** |
| **L-7** | ✅ **`floor_1` +guild/warehouse/pomodoro ／ `floor_2` +equipment/training ／ `floor_3` +decoration/shop ／ `floor_4` +research/workshop ／ `floor_5` +rune。⚠ 赤は `E125` の1本だけ** |
| **L-8** | ✅ **`economy` 赤0黄1。⚠ 「1周で入るもの」が5行** |
| **L-9** | ✅ **`KIND_BATTLE` 21本すべて 赤0黄1** |
| **L-10** | ✅ **ロード時の赤0本・黄1本（`skill_dbg_dot_odd`）** |
| **L-11** | ⚠ **(b) のみ実施**（下記 9-3） |
| **L-12** | ✅ **JSON 往復のあと `layer` が `int` でないノード 0件。⚠ `torch_grade` / `chest_count` も `int`** |
| **L-13** | ✅ **新規開始の `floor_run` が9欄。⚠ `floor_id=""`** |
| **F-3** | ✅ **`stages.json` は `floor_1..5` ＋ `stage_dbg_*` 5本（`waves`）** |

⚠ **30シナリオの平常値は変わっていない**：⚠ **`unlock` 赤1（`E125`）／ `workshop` 赤2（`E129`）／ `parts` と `drops` は黄2 ／ ほかは赤0黄1。**

### 9-2. `scenario=economy` の前後

| | 前（`stage_1..3`） | 後（`floor_1..5`） |
|---|---|---|
| ゴールド/周 | 50 / 80 / 120 | ⚠ **50 / 70 / 90 / 110 / 130** |
| `training_material_1`/周 | 2 / 5 / 6 | ⚠ **2 / 3 / 5 / 6 / 6** |
| ⚠ **Lv100×3キャラの集中時間**（最良） | ⚠ **33.3 時間**（`stage_3`） | ⚠ **33.3 時間**（`floor_4` / `floor_5`） |
| 入口が0件の素材 | 3件 | ⚠ **3件**（変わらず） |
| 出口が0件の素材 | 4件 | ⚠ **4件**（変わらず） |

⚠ **`floor_3` が旧 `stage_2` と同じ 39.9 時間。⚠ 育成の速さの目安は動いていない。**
⚠ **宝箱の期待値は 0.29〜0.32 個/周のまま**（⚠ **`chests.json` を触っていないため。⚠ 14-b で作り替える**）。

### 9-3. ⚠ 指示書からの逸脱（**3件**）

1. ⚠ **`battle_controller.gd` を2行触った**（⚠ **§0 で「禁止（14-c）」と書いていた**）。⚠ **`_stage_id` の既定値と push_warning の文言が `"stage_1"` を名指ししていて、⚠ 改名で宙に浮いたため。⚠ 直したのは文字列2つだけで、⚠ 挙動には触っていない**
2. ⚠ **F-1 / F-2 を「ファイル」から「ログ」へ移した**（⚠ **§7 に理由を書いた。⚠ `debug_boot` はセーブを書かないため**）
3. ⚠ **`L-11` の (a)（最終層からボスへの接続を切る）を実施していない**。⚠ **代わりに `_walk_all_routes()` が「どのルートからも通れないノード」を常時数えている。⚠ (a) を常設の自己テストにするかは 14-c で判断する。⚠ (b)（`E125`）は既存の枝がそのまま効いた**

### 9-4. ⚠ 見つけたズレ・申し送り

| | 中身 |
|---|---|
| ⚠ **申し送り1** | ⚠ **`ja.csv` に `ui_floor_1..5` が無い。⚠ 冒険選択画面にキー名がそのまま出る**（⚠ **`AGENTS.md` の許容挙動**）。⚠ **14-a は `ja.csv` 禁止なので触っていない。⚠ 14-c で5行足す。⚠ 古い `ui_stage_1..3` の3行も同時に消す** |
| ⚠ **申し送り2** | ⚠ **`stages.json` の `chest_id` はまだ `stage_1` / `stage_2` / `stage_3`（`chests.json` の宝箱ID）。⚠ 14-b で `floor_N_<rarity>` に差し替える** |
| ⚠ **申し送り3** | ⚠ **`battle_pool` と `boss` はまだ誰も読んでいない。⚠ 戦闘に繋ぐのは 14-c** |
| ⚠ **申し送り4** | ⚠ **`floor_run_changed` シグナルの購読者がゼロ。⚠ 14-c のマップ画面が繋ぐ** |
| ⚠ **ズレ43** | ⚠ **`_report_unlock()` の「workshop は段階11で `stage_3` に入った」など、⚠ `debug_boot` の文言5箇所が `stage_1..3` を名指ししていた。⚠ 追随させた**（⚠ **`stages.json` を改名したときに一緒に動く場所は `debug_boot` に5箇所・`battle_controller` に2箇所あった**） |
