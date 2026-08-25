# EXEC_BALANCE_ECONOMY — バランス実測（資源の収支）

**段階12**（`PLAN_IMPLEMENTATION.md` 3章・**最後の段階**）／ 仕様は `GAME_DESIGN.md` 4-1・9-1 ／ 指示元は `NEXT_STEPS.md` §1。
**直前の回は `EXEC_WORKSHOP_REVIVE.md`（段階11の後半）。⚠ 決め2（抽選の本体は `_roll_weighted_table()` の1本）を戻さない。**

---

## 0. 人間の決定（2026-08-25・着手前に確認済み）

| # | 聞いたこと | 決まったこと |
|---|---|---|
| **1** | 「実測」を何でやるか | ⚠ **`scenario=economy` を1本足してヘッドレスで表を出す。⚠ 周回ステージは作らない**（＝**測るだけの回**） |
| **2** | 何を測るか | ⚠ **③素材の入口と出口の収支（最優先）と ②Lv100までの周回数の2つだけ。⚠ ①戦闘の秒数と装飾の出目は今回やらない** |
| **3** | 数値を直す範囲 | ⚠ **今回は1つも直さない。⚠ 直す値は一覧にして人間に渡し、次の回で入れる** |
| **4** | 宿題12（`inventory` の `count` が `5.0` で保存される） | ⚠ **このタスクのついでに直す**（`load_state()` に数行） |

### 0-1. ⚠ 着手前に見つけた「仕様と実コードの食い違い」3件（**報告のみ・勝手に直さない**）

`NEXT_STEPS` §2-2 に従い、`GAME_DESIGN` / `PLAN_IMPLEMENTATION` / `PROJECT_STATUS` を `grep` した。

| # | 見つけたもの | このタスクへの影響 |
|---|---|---|
| **(1)** | ⚠ **`GAME_DESIGN` 4-1 の「周回ステージ（素材系／装飾系）」と「スキップ周回」が実コードに1件も無い。** `stages.json` は `stage_1..3`（シナリオ）＋ `stage_dbg_*` だけ | ⚠ **仕様側を採ると段階12が「新ステージを作る回」に化ける。⚠ 人間に聞き、「作らない・測るだけ」を選んだ**（決定1）。⚠ **測る対象はシナリオ3本** |
| **(2)** | ⚠ **`training_material_2` / `_3` / `_4` に出口が1つも無い。** レベルアップが使うのは `character_config.tres` の `level_up_material_id = "training_material_1"` の1件だけで、`grep` しても消費箇所が0件 | ⚠ **これは測った結果ではなく、着手前に見えてしまったもの。⚠ §5-A の表がこれを機械的に出せることの確認に使う**（道具を疑う・§2 決め4） |
| **(3)** | ⚠ **効く数値の多くは `.tres` ではなく `resources/balance/*.gd` の `@export` 既定値にある** | ⚠ **§1-1 の「`.tres` は設計役が直せない」の前提が半分崩れる。⚠ 渡す一覧を「人間がやる分」と「次の回に設計役がやれる分」に分ける**（§2 決め6・ズレ39） |

---

## 1. 何をするか

| # | 対象 | 変更 |
|---|---|---|
| **A** | `tests/debug_boot.gd` | ⚠ **`scenario=economy`（31本目）**。`SCENARIOS` / `_ready()` の `elif` / `REPORT_ECONOMY` の**3箇所**＋ `_report_economy()` と補助関数 |
| **B** | `autoload/game_manager.gd` | ⚠ **`load_state()` に `inventory` の `count` を `int()` に戻す枝**（宿題12・決定4）。**それ以外は1行も触らない** |
| **C** | `docs/02_exec/EXEC_BALANCE_ECONOMY.md` | このファイル（§9 に測った結果と**渡す値の一覧**） |
| **D** | `docs/` | `NEXT_STEPS` / `PLAN_IMPLEMENTATION` 3章の状態列 / `PROJECT_STATUS` のハッシュ表と宿題 |

⚠ **`.json` を1件も触らない。⚠ `.tres` を1件も触らない。⚠ `ja.csv` を1行も触らない**（＝**再インポートの依頼が発生しない**）。
⚠ **`.tscn` を1件も触らない**（＝**画面の見た目が変わらない**）。

---

## 2. ⚠ 僕が自分で決めたもの（**人間が見ていない決め**）

> ⚠ **この章がこのEXECの本体。⚠ §0 の4件以外は全部ここ。⚠ 違うと思ったら差し戻してよい。**

### 決め1（**大きい**）：`economy` は「測るだけ」。⚠ 赤も黄も1本も足さない

⚠ **「入口が無い素材」「出口が無い素材」を見つけても `push_error` / `push_warning` にしない。**

理由は2つ。

- ⚠ **今の実コードで既に (2) が当たっている。** 赤にすると **`economy` 以外の30本全部で赤が出る**（`MasterDataLoader` のロード時検証に入れた場合）。⚠ **平常値を全面的に書き換える回になり、決定3「今回は1つも直さない」と両立しない**
- ⚠ **穴かどうかは人間が決めること。** `training_material_2..4` は「まだ出口を作っていない」のか「要らない」のかがデータからは分からない

→ ⚠ **`print` で「⚠ 出口が無い」と名指しするだけにする。⚠ 赤の平常値は `unlock` 1本・`workshop` 2本のまま。⚠ 黄も変えない。**
→ ⚠ **`E130` / `W21` は使わない**（次の回に取ってある）。

### 決め2：測るのは**本番3ステージだけ**。`stage_dbg_*` を除く

⚠ **除き方は「`stages.json` のキーが `stage_dbg_` で始まらないもの」ではなく、⚠ `unlocks` か `chest_id` を持つもの**……にはしない。**`stage_dbg_` の接頭辞で除く。**

⚠ **理由**：`stage_1..3` は `rewards.gold` が 50/80/120、`stage_dbg_*` は全部 `gold: 1` で、判定に使える欄が接頭辞以外に無い。
⚠ **接頭辞は宿題35（リリース前に消すもの）が既に名指ししている綴り**なので、新しい約束を作っていない。
⚠ **`debug_boot.gd` の中だけで使う定数にする**（`GameManager` に持ち込まない）。

### 決め3（**大きい**）：③には**ゴールドとスタミナも入れる**

人間が選んだのは「③素材の入口と出口の収支」だが、⚠ **素材の入口の1つが「ショップで買う」であり、⚠ ショップの支払いはゴールドのため、⚠ ゴールドを測らないと `_4` 系の素材の入口が「有る」としか言えない。**

⚠ **同じ理由でスタミナも入れる。⚠ 周回そのものが 1回 5 スタミナを払う**（`adventure_config.gd` の `stamina_cost_per_stage = 5`）。
⚠ **スタミナの入口はポモドーロのポーションだけ**（`grant_stamina_potions()`：集中25分ごとに1個・1個 +50）。
→ ⚠ **「Lv100 に必要な集中時間（分）」まで出せる。⚠ ②の答えを「周回数」ではなく「時間」で言えるのは、この回でいちばん効く数字。**

### 決め4：Lv100 のコストは `level_up_character()` を99回回さず、**式を直接99回評価する**

⚠ **`level_up_character()` は1回ごとに `print` を出す。⚠ 3キャラで297行になり、⚠ 2026-08-24 の罠（在庫を減らすために操作を繰り返して数万行）と同じ形に近づく。**

→ ⚠ **`GrowthFormula.evaluate_int()` を Lv1..99 で99回評価して合計する**（`get_level_up_cost()` が中で呼んでいるのと同じ関数・同じ引数）。
→ ⚠ **道具を疑う**（`NEXT_STEPS` §4）：**Lv1 のときの評価結果が `get_level_up_cost()` の戻り値と一致することを1行で突き合わせる。⚠ 合わなければその場で「⚠ 式の評価が実装とずれている」と出す。**

### 決め5：宝箱の期待値は `_roll_chest_draw()` を**研究なしの状態で**1000回引く

⚠ **`_roll_chest_draw()` には `get_research_chest_draw_bonus()` が乗っている**（`EXEC_WORKSHOP_REVIVE` 決め2・前の回に踏みかけた罠）。

→ ⚠ **「研究0件のとき」と「研究を全部解放したとき」の2本を並べて出す。⚠ 差がそのまま研究の宝箱枝の効き。**
→ ⚠ **順番を固定する。⚠ 研究を先に解放してしまうと素の値が二度と取れない**（`_report_workshop()` が解放を最後に置いているのと同じ理由）。

### 決め6：渡す値の一覧は「**人間しか入れられない分**」と「**次の回に設計役が入れられる分**」に分ける

⚠ **§0-1 の (3)。⚠ `.tres` に実際の行があるのは 13本中 3本だけ**（`character_config` / `initial_state_config` / `pomodoro_config` ＋ `protection_*` / `sound_config`）。
⚠ **`adventure_config` / `equipment_config` / `part_config` / `research_config` / `shop_config` / `workshop_config` の `.tres` は `script = ...` の1行しか無い**＝**効いているのは `.gd` の `@export` 既定値**。

| 置き場 | 誰が入れるか |
|---|---|
| ⚠ **`resources/balance/*.gd` の `@export` 既定値** | ⚠ **次の回に設計役が入れられる**（`.tres` に行が無いことを確認済みの6本） |
| ⚠ **`resources/balance/master/*.json`** | ⚠ **次の回に設計役が入れられる** |
| ⚠ **`character_config.tres` の3行**（`level_up_material_id` / `base_level_up_cost` / `cost_growth_per_level`） | ⚠ **人間が Inspector で入れる。⚠ ここだけ本当に設計役が触れない** |
| ⚠ **`initial_state_config.tres` / `pomodoro_config.tres`** | ⚠ **人間**（⚠ **ただし `initial_state` はセーブがあると読まれない**＝`NEXT_STEPS` §1-3） |

### 決め7：宿題12 の直し方は「`materials` の隣に同じ形で足す」

```gdscript
if new_state.has(GameStateKeys.INVENTORY) and new_state[GameStateKeys.INVENTORY] is Dictionary:
    var inv: Dictionary = new_state[GameStateKeys.INVENTORY]
    for item_id: String in inv:
        if inv[item_id] is Dictionary and (inv[item_id] as Dictionary).has(GameStateKeys.ITEM_COUNT):
            (inv[item_id] as Dictionary)[GameStateKeys.ITEM_COUNT] = int((inv[item_id] as Dictionary)[GameStateKeys.ITEM_COUNT])
```

- ⚠ **`GameStateKeys.ITEM_COUNT` を使う**（文字列リテラルの `"count"` を書かない）
- ⚠ **`is Dictionary` を見てから触る。⚠ 壊れたセーブで落とさない**（`GROWTH_NODES` の既存の枝と同じ形）
- ⚠ **`type` / `slot_position` / `properties` は触らない。⚠ 直すのは `count` だけ**（`§6-2 の決定事項に従い、対象を限定する` という既存のコメントを守る）
- ⚠ **`equipment_instances` は既に `int()` を通っているので触らない**

### 決め8：`economy` は戦闘を回さない（`kind: "report"`）

⚠ **`NEXT_STEPS` §1-3。⚠ 戦闘を回すと1本10〜20秒で、⚠ 3ステージ×5ウェーブを実際に戦うと終わらない。**
⚠ **1周で入るものは `stages.json` の `rewards` と `_roll_chest_draw()` から出す。⚠ `drops` と `workshop` と同じ形。**

⚠ **代償：「戦闘に勝てるか」は測っていない。⚠ 表に出るのは勝った前提の収支だけ。⚠ ①（戦闘が何秒で終わるか）を人間が後回しにした結果なので、⚠ §9 に明記する。**

### 決め9：`_report_economy()` は1つの関数に全部書かず、**入口と出口を作る2本を分ける**

⚠ **`_economy_sources()` / `_economy_sinks()` の2本。⚠ どちらも `{material_id: [説明の行]}` を返す。**
⚠ **理由：この2本が「同じ形の判定」で、⚠ 片方だけ直す事故が起きる**（`NEXT_STEPS` §2-6）。⚠ **表は両方を突き合わせて1回で組む。**

### 決め10：Ziva に渡せる部分は**無い**（分割しない）

⚠ **`.json` も `ja.csv` も1行も触らない回のため、⚠ 渡せる粒が存在しない**（`EXEC_WORKSHOP_REVIVE` 決め10と同じ判断）。

---

## 3. `scenario=economy` が出すもの

⚠ **`kind: KIND_REPORT` / `report: REPORT_ECONOMY`。⚠ `SCENARIOS` に1行・`_ready()` の `elif` に1行・`REPORT_ECONOMY` の定数に1行の3箇所。**

### 3-1. 素材16件の入口と出口（**この回の本体**）

| 列 | 中身 |
|---|---|
| 入口 | ⚠ **`stages.json` の `rewards.materials`（本番3本のみ・決め2）／ `chests.json` の `rewards.materials` と `draw.entries` ／ `shop.json` の `payout_type: "material"` ／ 装備の分解（`forging_*`）／ 装飾の分解（`decor_*`）** |
| 出口 | ⚠ **レベルアップ（`Balance.character.level_up_material_id`）／ 鍛冶（`forging_*`）／ 装飾の段階上げ（`decor_*`）／ 研究（`research.json` の `cost_material_id`）／ 作業場（`recipes.json` の `inputs`）** |

⚠ **最後に「入口が0件のもの N 件」「出口が0件のもの N 件」を1行ずつ出し、⚠ IDを並べる**（決め1・print だけ）。

### 3-2. 1周で入るもの（本番3ステージ）

⚠ **ステージごとに1行**：`gold` ／ 素材 ／ `inventory` ／ **スタミナ -5** ／ ⚠ **宝箱の期待値**（1000回引いた合計 ÷ 1000）。
⚠ **研究0件のときと全解放のときの2本**（決め5）。

### 3-3. Lv100 までの周回数と集中時間（②）

- ⚠ **Lv1→100 の `training_material_1` 累計**（決め4）／ ⚠ **3キャラぶん**
- ⚠ **各ステージの `training_material_1` 産出で割った周回数。⚠ 産出が0のステージは「∞（落ちない）」と出す**
- ⚠ **周回数 × 5 スタミナ ÷ 50（ポーション1個）× 25分 ＝ 必要な集中時間**（決め3）

### 3-4. 研究20件の総コストと `construction_material_4` の入口

- ⚠ **`cost_material_id` ごとの合計**
- ⚠ **`construction_material_4` は入口がショップだけ。⚠ `stock_limit` と `cost.amount` から「1日あたり最大何個・何ゴールド」を出す**
- ⚠ **ゴールドの入口（ステージ報酬）で割った周回数**

### 3-5. 道具を疑う枝（**決め4・`NEXT_STEPS` §4**）

⚠ **`get_level_up_cost()` の戻り値と、式を直接評価した値が Lv1 で一致するかを1行で出す。**
⚠ **一致しなければ「⚠ 式の評価が実装とずれている」と出す**（赤にはしない・決め1）。

---

## 4. ⚠ 先に潰す落ち（`NEXT_STEPS` §1-3）

| # | 予想 | 対応 |
|---|---|---|
| 1 | `.tres` は設計役が直せない | ⚠ **今回は1つも直さない**（決定3）。⚠ **渡す一覧を2段に分ける**（決め6） |
| 2 | `initial_state_config.tres` はセーブがあると読まれない | ⚠ **一覧の中で名指しする**（決め6の表） |
| 3 | `drops` / `workshop` は意図的に赤黄を出す枝を持つ | ⚠ **平常値を1本も変えない**（決め1） |
| 4 | シナリオを足すのは3箇所 | ⚠ **`SCENARIOS` / `_ready()` の `elif` / `REPORT_ECONOMY` の定数** |
| 5 | 「1000回戦わせる」は終わらない | ⚠ **戦闘を回さない**（決め8）。⚠ **`_roll_chest_draw()` を直接叩く** |
| 6 | ⚠ **`_roll_chest_draw()` に研究の宝箱枝が乗っている** | ⚠ **研究なしを先に測る**（決め5）。⚠ **前の回に踏みかけた罠** |
| 7 | ⚠ **`MasterDataLoader` が返す数値は `float`** | ⚠ **`int()` で包む。⚠ 今回いちばん踏みやすい**（数値を集計する回のため）。⚠ **表に `.0` が出ていたらその場で直す** |
| 8 | ⚠ **関数を足すときは「次の `func` まで」を見る** | ⚠ **`_report_workshop()` の末尾（`_io_summary()` の直前）に差し込む** |
| 9 | ⚠ **測る道具が「0」や「全部同じ数字」を返したら道具を疑う** | ⚠ **決め4の突き合わせを1行入れる**（§3-5） |
| 10 | ⚠ **回している間は `.gd` を触らない** | ⚠ **宿題12 の修正を先に当て、そのあと29本＋1本を回す** |

---

## 5. 完了条件

### §0 事前チェック（**設計役・人間に渡す前に終わっている**）

- ⚠ **全シナリオ（`training` を除く **30本**）をヘッドレスで1本ずつ回す。⚠ 10本ずつ3回に分け、`timeout` を伸ばす**
- ⚠ **赤は `unlock` の1本 ＋ `workshop` の2本だけ。⚠ `economy` は0本**（決め1）
- ⚠ **黄は1本（`skill_dbg_dot_odd`）。⚠ `drops` と `parts` はもう1本ずつ多い。⚠ `economy` は1本**
- ⚠ **`--check-only --script` で `game_manager.gd` / `debug_boot.gd` の `Parse Error` が0件**
- ⚠ **編集直後に `grep -n` で当たったことを確認**（`CLAUDE.md` 2番）

### A. ログ（**設計役が読む**）

| # | 見るもの |
|---|---|
| **A-1** | ⚠ `scenario=economy`：**素材16件が全部行になっている**（⚠ 16 未満なら集計の抜け） |
| **A-2** | ⚠ **「出口が0件のもの」に `training_material_2` `training_material_3` `training_material_4` の3件が出る**（⚠ **§0-1 の (2) を道具が機械的に見つけられること＝道具を疑う枝**） |
| **A-3** | ⚠ **「入口が0件のもの」が0件**（⚠ 16件とも何らかの入口を持つ） |
| **A-4** | ⚠ **1周の表に本番3ステージだけが出る**（⚠ `stage_dbg_*` が混ざっていない＝決め2） |
| **A-5** | ⚠ **宝箱の期待値が「研究0件」と「全解放」で違う**（⚠ 全解放のほうが大きい＝`_roll_chest_draw()` の枝が生きている） |
| **A-6** | ⚠ **Lv1→100 の `training_material_1` 累計が `5148`**（⚠ **`3 + 1.0×(level-1)` の手計算と一致。⚠ 違えば式か `.tres` が変わっている**） |
| **A-7** | ⚠ **Lv1 の突き合わせが `一致` と出る**（§3-5・決め4） |
| **A-8** | ⚠ **表の数字に `.0` が1つも無い**（⚠ `CLAUDE.md` 3番・落ち7） |
| **A-9** | ⚠ **研究20件の総コストが `construction_material_1..4` の4行に分かれて出る**（⚠ 合計が `research.json` の `cost_amount` の総和と一致） |
| **A-10** | ⚠ **`load_state()` に `count` が `float` の `inventory` を直接渡すと、⚠ 読み直した値が `int` で返る**（⚠ **UIから到達できない経路なので、ここで見る**）。⚠ **直す前は `float` だったことも同じ行に出す** |
| **A-11** | ⚠ **他の29本の赤黄が平常値のまま**（§0 事前チェック） |

### B. ファイル（**設計役が読む**）

| # | 見るもの |
|---|---|
| **B-1** | ⚠ **`git diff --stat` に `.json` / `.tres` / `.csv` / `.tscn` が1件も無い**（⚠ 触るのは `tests/debug_boot.gd` と `autoload/game_manager.gd` の2本だけ＝決定3）。⚠ **`localization/ja.ja.translation` はこのセッションの前から `M` のまま**（⚠ **人間の再インポートで作り直されたバイナリ。⚠ 宿題5**） |
| **B-2** | ⚠ **`grep -n "GameStateKeys.ITEM_COUNT" autoload/game_manager.gd` が `load_state()` の中で1件増えている** |
| **B-3** | ⚠ **`grep -c '"count"' autoload/game_manager.gd` が増えていない**（⚠ 文字列リテラルを書いていない＝決め7） |
| **B-4** | ⚠ **`tests/debug_boot.gd` に `REPORT_ECONOMY` が3箇所**（定数・`SCENARIOS`・`elif`） |
| **B-5** | ⚠ **人間が §C を通したあとの `save_slot_0.json` に `"count":` の `.0` が0件**（⚠ **宿題12 が直った証拠。⚠ 直す前は装飾36件中33件が `5.0` だった**） |

### C. 画面（**人間だけ**）

⚠ **観測できる合図で書く。⚠ 待ち時間のある項目は1つも無い。**

| # | すること | 見るもの |
|---|---|---|
| **C-1** | ⚠ **F4 →「装飾を全種類」** → **F4 →「セーブする」** | ⚠ **「セーブしました」が出る** |
| **C-2** | ⚠ **アプリを閉じて開き直し、⚠ もう一度 F4 →「セーブする」** | ⚠ **倉庫の持ち物で装飾の個数が `5` と出ている**（⚠ **`5.0` でも表示は `5` なので、⚠ 本当の判定は B-5。⚠ ここは「壊れていない」ことだけ見る**） |
| **C-3** | ⚠ **倉庫 → 持ち物** | ⚠ **装飾の行が消えていない・個数が0になっていない**（⚠ **`int()` を足したことで在庫が飛んでいないこと**） |

> ⚠ **画面の項目がこれだけしか無いのは、⚠ この回が `.tscn` も `ja.csv` も1件も触らないため**（§1）。
> ⚠ **将来コードを変えたときに見る項目**：`load_state()` に `inventory` が `Dictionary` でないセーブを渡しても落ちない（A-10 の枝で見ている）。

---

## 6. `PROJECT_STATUS.md` へ足す宿題

1. ⚠ **`GAME_DESIGN` 4-1 の「周回ステージ」「スキップ周回」が実装に無い**（§0-1 の (1)）。⚠ **段階12 は測るだけにしたので、⚠ 作るかどうかは未決のまま**
2. ⚠ **`training_material_2..4` に出口が1つも無い**（§0-1 の (2)）。⚠ **レベルアップが `_1` しか使わない。⚠ 段階を要求する形にするか、`_2..4` を消すか**
3. ⚠ **①「戦闘が何秒で終わるか」を測っていない**（決め8・人間の決定2）。⚠ **`def` が除算式になった影響はまだ数字で見ていない**
4. ⚠ **装飾の出目（`part_base` / `part_roll_max` 72個）とルーンの効果量を測っていない**（人間の決定2で後回し）
5. ⚠ **測った結果を数値に反映していない**（決定3）。⚠ **§9 の一覧が次の回の入力**
6. ⚠ **宿題12 は解消**（決定4）

---

## 7. 変えないもの

⚠ **`NEXT_STEPS` §2-2 に従って `grep` した。⚠ 見つかった食い違いは §0-1 の3件で、⚠ 全部人間に報告済み。**

- ⚠ **`_roll_weighted_table()` にボーナスを足さない**（`EXEC_WORKSHOP_REVIVE` 決め2）／ ⚠ **`_roll_chest_draw()` の外から見た振る舞い**
- ⚠ **`_sync_recipes_from_master()` の早期 return を戻さない**（`EXEC_WORKSHOP_RETIRE` 決め1）
- ⚠ **`base_level_cap`（20）＋ `level_cap_unlock` 8件×10 ＝ 100**（`E127`）
- ⚠ **ノードID・レシピID・素材ID・`ChestScheduleEntry.chest_type` の `@export` 名**
- ⚠ **素材16件。`<系統>_material_<1..4>`。⚠ 1件も足さない**
- ⚠ **`parts` は長さ8の固定配列**（`null` 込み・位置が枠を表す）
- ⚠ **状態にキーを1つも足さない**（⚠ `GameStateKeys` に定数を足さない＝`AGENTS.md` の表も触らない）
- ⚠ **`tests/debug_boot.gd` の既存シナリオ30本**（⚠ 消さない。⚠ `economy` を足して31本）
- ⚠ **赤黄の平常値**（決め1）
- ⚠ **`E130` / `W21` を使わない**（次の回に取ってある）

---

## 8. ⚠ ドキュメントのズレ（**報告のみ・勝手に直さない**）

`NEXT_STEPS` §2-1 の通し番号の続き。**前回までで38件、未報告3件（34・37・38）。今回1件。**

### ズレ39 — `NEXT_STEPS` §3 と `resources/balance/*.tres` の実体

> ⚠ **勘で入っている数値の置き場** ｜ `resources/balance/*.tres`（**設計役は直せない。人間の作業**）

⚠ **13本の `.tres` のうち、⚠ 値の行を1つでも持つのは 6本だけ**（`character_config` / `initial_state_config` / `pomodoro_config` / `protection_*` / `sound_config`）。
⚠ **`adventure_config` / `equipment_config` / `part_config` / `research_config` / `shop_config` / `workshop_config` の6本は `script = ExtResource(...)` の1行しか無く、⚠ 効いているのは `.gd` の `@export` 既定値**（⚠ **`equipment_config.gd` と `part_config.gd` のコメント自身がそう書いている**）。

⚠ **同じ理由で `NEXT_STEPS` §1-3 の「`.tres` は設計役が直せない（`part_config` など）」も、⚠ `part_config` については当たらない。**
⚠ **本当に設計役が触れないのは `character_config.tres` の3行と `initial_state_config.tres` / `pomodoro_config.tres`。**

→ ⚠ **`NEXT_STEPS` §1-1 の表と §1-3 の1行目を直すべきだが、⚠ 勝手に書き換えない。**

⚠ **`NEXT_STEPS` §3 の「`_4` はどのステージからも落ちない＝月替わりショップだけ」も、⚠ `shop.json` に `weekly` / `monthly` のキーが無く `daily` しか無い**（⚠ `GameManager` が `refresh_shop_if_needed() -> skip (第1弾は daily のみ)` と print している）。⚠ **実体は「日替わりショップだけ」。⚠ ズレ39 に含める。**

---

## 9. 実施結果（2026-08-25・設計役）

### 9-0. §0 事前チェック … **通った**

⚠ **全30シナリオ（`training` を除く）をヘッドレスで1本ずつ、10本ずつ3回に分けて回した。**

| | 結果 |
|---|---|
| ⚠ **赤** | ⚠ **`unlock` 1本（`E125`・意図）／ `workshop` 2本（`E129`・意図）。⚠ 他の28本は0本。⚠ `economy` は0本**（決め1のとおり） |
| ⚠ **黄** | ⚠ **全本 `skill_dbg_dot_odd` の1本。⚠ `parts` と `drops` はもう1本ずつ。⚠ `economy` は1本** |
| `--check-only --script` | ⚠ **`Parse Error` は0件**（⚠ 出るのは `Identifier not found: SceneManager / Balance` だけ＝Autoload が読まれないため） |
| `scenario=layout` | ⚠ **8画面とも前の回と同じ数字**（⚠ `.tscn` を1件も触っていない） |
| `scenario=passives` | `ja.csv の再インポート: 済んでいる`（⚠ **今回 `ja.csv` を1行も触っていない**） |

### 9-1. ログの完了条件（§5-A）… **A-1 〜 A-11 とも通った**

| # | 取れたもの |
|---|---|
| A-1 | `素材 16 件` |
| A-2 | ⚠ **出口が0件のものが 4 件**：`decor_material_4` / `training_material_2` / `training_material_3` / `training_material_4`（⚠ **予想は3件だった。⚠ `decor_material_4` は着手前に見えていなかった＝道具が自分で1件見つけた**） |
| A-3 | `⚠ 入口が0件のもの 0 件: []` |
| A-4 | `本番ステージ 3 本（⚠ stage_dbg_* は除いた）` |
| A-5 | ⚠ **宝箱の期待値 0.31 / 0.32 / 0.30 → 研究全解放で 0.90 / 0.92 / 0.91**（⚠ `宝箱の抽選 +2`） |
| A-6 | ⚠ **1キャラ 5148 個 / 3キャラ 15444 個**（⚠ **Σ(3+(L-1)), L=1..99 の手計算と一致**） |
| A-7 | `⚠ Lv1 の突き合わせ 実装 3 / 式 3 -> 一致` |
| A-8 | ⚠ **個数の列に `.0` は1つも無い**（⚠ `.0` が出るのは `返却率 0.5` と `growth=1.0` の2箇所だけ＝**どちらも本当に float の欄**） |
| A-9 | ⚠ **`ノード 20 件 / 合計 790 個`。⚠ `research.json` の `cost_amount` 20件の総和 790 と一致** |
| A-10 | ⚠ **`load_state()` に `count: 5.0` を渡すと `戻ってきた count = 5 (int)`。⚠ 修正を一時的に外すと `5.0 (float)` に戻り、⚠ 戻すと再び `5 (int)`**（⚠ **壊して確かめ、⚠ 平常値に戻ったことを再実行で確認した**）。⚠ **同じ枝に `Dictionary` でない行を混ぜているが落ちない** |
| A-11 | ⚠ **他の29本の赤黄が平常値のまま**（§9-0） |

### 9-2. ⚠ 測った結果（**この回の本体**）

#### (1) 素材16件の収支

| 素材 | 入口 | 出口 |
|---|---|---|
| `construction_material_1` | `stage_1` x3 ／ `stage_2` x5 ／ 宝箱4種 ／ daily | ⚠ **研究 270** |
| `construction_material_2` | `stage_2` x1 ／ `stage_3` x5 | ⚠ **研究 235** |
| `construction_material_3` | `stage_3` x1 ／ daily x5 を 2000G | ⚠ **研究 230** |
| `construction_material_4` | ⚠ **daily x3 を 5000G だけ** | ⚠ **研究 55** |
| `decor_material_1..3` | ステージ ／ 装飾を壊す | 装飾の段階上げ ／ 作業場 x12 |
| ⚠ **`decor_material_4`** | daily ／ 装飾を壊す x20 | ⚠ **無し** |
| `forging_material_1..4` | ステージ ／ daily ／ 装備の分解 | 鍛冶 等級2〜10 |
| `training_material_1` | `stage_1` x2 ／ `stage_2` x4 ／ daily | レベルアップ |
| ⚠ **`training_material_2..4`** | ステージ ／ daily | ⚠ **3件とも無し** |

⚠ **入口が無い素材は0件。⚠ 出口が無い素材が4件。**

#### (2) ⚠ Lv100 が遠すぎる（**この回でいちばん大きい数字**）

| | |
|---|---|
| 式 | `base + growth * (level - 1)`（`base=3` / `growth=1.0`） |
| ⚠ **1キャラ Lv1→100** | ⚠ **`training_material_1` を 5,148 個** |
| ⚠ **3キャラぶん** | ⚠ **15,444 個** |
| ⚠ **`stage_2` を回すと**（4個/周） | ⚠ **3,861 周 ／ スタミナ 19,305 ／ 集中 9,653 分＝ **160.9 時間** |
| ⚠ **`stage_1` を回すと**（2個/周） | ⚠ **7,722 周 ／ **321.8 時間** |
| ⚠ **`stage_3` を回すと** | ⚠ **∞（`training_material_1` を1個も落とさない）** |

⚠ **スタミナが律速。⚠ 1周 5 スタミナで、⚠ 入口はポモドーロのポーションだけ**（`grant_stamina_potions()`：集中25分ごとに1個・1個 +50 ＝ **集中1分あたり2スタミナ＝0.4周**）。
⚠ **時間で言うと「Lv100 まで 160 時間ポモドーロを回す」。⚠ 数値ではなく体験の問題として人間に返す。**

#### (3) ⚠ 進めるほど育成が止まる

⚠ **`stage_3` は `training_material_1` を1個も落とさない**（落ちるのは `_2` x4 と `_3` x1）。
⚠ **`_2..4` に出口が無いため、⚠ 最新ステージを回すほど「使える育成素材」が減る。**
→ ⚠ **「シナリオを進める理由が資源面にも生まれる」**（`GAME_DESIGN` 4-1）と**逆向きになっている。**

#### (4) ⚠ 研究の終盤が事実上ショップ待ち

| | |
|---|---|
| 研究20件の総コスト | **790 個**（`construction_material_1..4`） |
| `construction_material_3`（230個） | ⚠ **`stage_3` が 1個/周 → 230 周** |
| ⚠ **`construction_material_4`（55個）** | ⚠ **どのステージからも落ちない。⚠ daily ショップ x3 を 5000G・在庫1** |
| ⚠ **換算** | ⚠ **19日（1日3個）＋ **91,667 G**。⚠ `stage_3` は 120 G/周なので **764 周ぶんのゴールド** |

#### (5) 1周で入るもの（勝った前提）

| ステージ | ゴールド | スタミナ | 宝箱の期待値（研究0件 → 全解放） |
|---|---|---|---|
| `stage_1` | 50 G | -5 | **0.31 → 0.90 個/周** |
| `stage_2` | 80 G | -5 | **0.32 → 0.92 個/周** |
| `stage_3` | 120 G | -5 | **0.30 → 0.91 個/周** |

⚠ **宝箱は3割の周でしか出ない**（ハズレ枠の `weight` が 70）。⚠ **研究を全部解放すると3倍になる。**

### 9-3. ⚠ 次の回に入れる値の一覧（**決め6の2段**）

> ⚠ **この回は1つも直していない**（決定3）。⚠ **下の表が次の回の入力。**

#### (a) ⚠ **人間しか入れられない**（Inspector）

| 値 | いまの値 | 置き場 | 効くところ |
|---|---|---|---|
| ⚠ **`base_level_up_cost`** | **3** | `character_config.tres` | ⚠ **(2) の 5,148 個の元。⚠ ここが最重要** |
| ⚠ **`cost_growth_per_level`** | **1.0** | `character_config.tres` | 同上 |
| `level_up_material_id` | `training_material_1` | `character_config.tres` | ⚠ **(3)。⚠ 1件しか持てない構造** |
| `starting_stamina_current` / `starting_materials` | 20 / 55個 | `initial_state_config.tres` | ⚠ **セーブがあると読まれない** |

#### (b) ⚠ **次の回に設計役が入れられる**（`.tres` に行が無い＝`.gd` の既定値が効いている・ズレ39）

| 値 | いまの値 | 置き場 |
|---|---|---|
| `level_up_cost_formula` | `"base + growth * (level - 1)"` | `character_config.gd` |
| `stamina_cost_per_stage` | **5** | `adventure_config.gd` |
| `potion_focus_minutes_per_unit` / `stamina_potion_recovery` | **25 / 50** | `pomodoro_config.gd` |
| `forge_cost_by_grade` / `dismantle_refund_ratio` | `[8,12,16,20,24,28,32,36,40]` / **0.5** | `equipment_config.gd` |
| `upgrade_cost_by_tier` / `dismantle_by_tier` | `[10,20,40]` / `[3,5,10,20]` | `part_config.gd` |
| ステージ報酬（`gold` / `materials`） | (5) の表 | `stages.json` |
| 研究のコスト20件 | 合計 790 | `research.json` |
| ショップの価格・個数・在庫 | 13枠 | `shop.json` |
| 宝箱の `weight`（ハズレ 70） | (5) | `chests.json` |
| 作業場の投入12個・時間・重み | 3件 | `recipes.json` |

#### (c) ⚠ **数値では直らないもの**（器の変更が要る＝人間の判断待ち）

1. ⚠ **`training_material_2..4` の出口**（`level_up_material_id` が1件しか持てない）
2. ⚠ **`decor_material_4` の出口**（装飾の段階が4止まり＝`max_part_tier`）
3. ⚠ **`construction_material_4` の入口**（`GAME_DESIGN` 4-1 の**周回ステージ**がまだ無い＝§0-1 の (1)）
