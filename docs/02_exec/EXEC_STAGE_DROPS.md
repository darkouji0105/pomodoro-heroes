# EXEC_STAGE_DROPS — ステージの抽選ドロップ（宝箱方式）

**台帳の段階5**（`PLAN_IMPLEMENTATION.md` 3章「分解方式とステージの抽選ドロップ」）**の後半。**
**`GAME_DESIGN.md` 4-2（固定報酬＋抽選ドロップ）／ 4-4（宝箱のドロップテーブル）／ 6-5（装備の入手経路）。**

---

## 0. 人間が決めたこと（**本文と矛盾する場合はこちらが優先**・2026-08-23）

| # | 決定 |
|---|---|
| **A** | ⚠ **この回は「ステージの抽選ドロップ」。⚠ ③作業場の廃止は次の回に送る**（⚠ **順番を覆した。理由は §1-1**） |
| **B** | ⚠ **宝箱方式にする。⚠ 装備を直接インベントリに落とさず、⚠ 宝箱を1個積む。⚠ プレイヤーは倉庫で開ける** |
| **C** | ⚠ **抽選は「積むとき」に振る。⚠ 中身が確定した宝箱が `pending_chests` に入る**（⚠ **ポモドーロの宝箱と同じ形**） |
| **D** | ⚠ **テーブルの形は「重み ＋ 抽選回数」。⚠ ハズレ枠も `weight` で書く**（⚠ **`GAME_DESIGN` 4-4・631行の「ドロップ率・抽選回数」という語彙に合わせる**） |
| **E** | ⚠ **`battle_controller.gd` は触らない。⚠ 結果画面は gold と materials のまま**（⚠ **宝箱は拠点の未開封バッジと倉庫で見える**） |
| **F** | ⚠ **次の回（作業場の廃止）では、⚠ ギルドの「作業場」ボタンを隠し、⚠ 画面とコードは残す**（⚠ **`GAME_DESIGN` 9-3 で復活予定。⚠ 掘削も `crafting_queue` を使う。⚠ この回では実装しない**） |

---

## 0-1. ⚠ 設計役が自分で決めたもの（**人間が見ていない決め・要確認**）

⚠ **11件ある。⚠ 覆すなら実装前に言ってほしい。**

| # | 決めたこと | なぜ |
|---|---|---|
| **1** | ⚠ **`chest_table` を `stages.json` の `rewards` の中に置く**（⚠ **`rewards` の隣ではなく中**） | ⚠ **`apply_battle_rewards(result_data)` に `stage_id` が渡っていない**（`battle_controller.gd:1553-1557`）。⚠ **`rewards` の中に入れれば `BATTLE_REWARDS` 経由で届く＝決定E「`battle_controller` を触らない」が守れる** |
| **2** | ⚠ **`chest_type` は `battle` の1種類だけ。⚠ ステージごとに分けない** | ⚠ **分けると `ja.csv` の行がステージ数だけ増える。⚠ テーブルはステージごとに持つので、⚠ 「進行度で切り替わる」（`GAME_DESIGN` 4-4）は満たしている** |
| **3** | ⚠ **当たりが1件も無ければ宝箱を積まない** | ⚠ **空の宝箱を積むと「開けたのに何も出ない」になる。⚠ ハズレ枠の `weight` がそのまま「宝箱が出ない確率」になる** |
| **4** | ⚠ **翻訳キーの接頭辞を `ui_pomodoro_chest_` → `ui_chest_` に変える** | ⚠ **`warehouse_screen.gd:277` が `tr("ui_pomodoro_chest_" + chest_type)` で名前を引いている。⚠ 戦闘の宝箱に `ui_pomodoro_` を付けるのは `AGENTS.md`「翻訳キーの運用」に反する。⚠ 使用元は1箇所だけなので改名が安全**（⚠ **翻訳キーはセーブに入らない。`CLAUDE.md` 4番の「改名するな」は `item_id` / `recipe_id` / ノードIDの話**） |
| **5** | ⚠ **ドロップした装備の等級は1固定** | ⚠ **`_create_equipment_instance()` の現行どおり（`INSTANCE_GRADE: 1`）。⚠ 高等級の確率（`GAME_DESIGN` 631行）を入れると `add_to_inventory()` の引数が増える。⚠ そこは装備の個体を作る唯一の関所（`CLAUDE.md` 8番）なので、⚠ この回では引数を増やさない** |
| **6** | ⚠ **`weight` は `int`。⚠ `item_id: ""` がハズレ枠** | ⚠ **`float` にすると `MasterDataLoader` が `3.0` で返す（`CLAUDE.md` 3番）。⚠ 重みは表示にも保存にも出ないが、⚠ 型を揃えておく** |
| **7** | ⚠ **`count` は省略可・既定1** | ⚠ **装備は1個ずつのほうが個体（`eq_N`）の数が読める。⚠ 素材を落としたくなったときに使う欄として開けておく** |
| **8** | ⚠ **検証用ステージ（`stage_dbg_*`）には `chest_table` を書かない** | ⚠ **そもそも `apply_battle_rewards()` は `stage_type == story` のときしか呼ばれない（`battle_controller.gd:1562`）。⚠ 書いても落ちないので書かない** |
| **9** | ⚠ **抽選の乱数を固定しない** | ⚠ **装飾のロールと同じ（`EXEC_DECORATION.md` §0-3 の11）。⚠ 検証は「範囲に収まるか」「2種類以上出るか」で見る** |
| **10** | ⚠ **`E120` と `W19` を割り当てた** | ⚠ **§3-D。⚠ E119 まで／W18 まで使用済み（W6・W7 は欠番）** |
| **11** | ⚠ **どのステージから何が出るか、⚠ `weight` の数値** | ⚠ **全部「勘」。§3-A。⚠ バランスの回で必ず戻ってくる。§10 の宿題に立てた** |
| **12** | ⚠ **`apply_battle_rewards()` の `print` から `chest_table` を除く**（⚠ **実装中に足した**） | ⚠ **決定1で `chest_table` を `rewards` の中に置いた結果、⚠ 既存の `print(result_data)` が戦闘1回ごとに抽選テーブル5行を丸ごと吐くようになった。⚠ 実測で `godot.log` が読めなくなることを確認したので、⚠ ログ用に複製して `chest_table` だけ消してから出す。⚠ 配る処理は元の `rewards` を見るので挙動は変わらない** |
| **13** | ⚠ **ハズレのとき `print` を出さない**（⚠ **実装中に足した**） | ⚠ **一度は「ハズレ（宝箱は積まない）」を出していたが、⚠ 70%の戦闘で出る＝正常系。⚠ `NEXT_STEPS` §4「正常系に `print` を増やさない」に反するので消した** |

---

## 1. いま何がどうなっているか（**実コードで確認済み・2026-08-23**）

### 1-1. ⚠ なぜ③作業場の廃止より先か（**順番を覆した理由**）

⚠ **装備10種のIDを全ファイルで追った結果、⚠ `items.json` と `recipes.json` にしか出てこない。**

| 経路 | 装備の件数 |
|---|---|
| `shop.json` | ⚠ **0件**（13枠すべて素材とポーション） |
| 宝箱（`ChestContentConfig.equipment`） | ⚠ **0件**（⚠ **4件の `chest_contents` が全部空。§1-3 のズレ21**） |
| `stages.json` の `rewards.inventory` | ⚠ **装飾3件のみ**（`EXEC_DECORATION.md` §0-3 の4） |
| `recipes.json` | ⚠ **10件**（⚠ **ここだけ**） |
| `F4` のデバッグパネル | ⚠ **全種類**（⚠ **リリース前に消す**） |

→ ⚠ **決定6どおり `recipes.json` を空にすると、⚠ プレイヤーが装備を1つも手に入れられなくなる。⚠ 鍛冶・枠・装飾36件がまとめて到達不能になる。**
→ ⚠ **`PLAN_IMPLEMENTATION.md` 3章は 11「作業場の作り直し」の依存を「5」＝この回のタスクと書いている。⚠ 決定5（①→②→③）はこの依存を1つ跨いでいた。**

### 1-2. ⚠ 使える器（**作り直さないこと**）

| 器 | 状態 |
|---|---|
| `GameManager.add_pending_chest(chest_data)` | ⚠ **ある**（`game_manager.gd:466`）。⚠ **`pending_chests` に積んで `pending_chests_changed` を飛ばす** |
| `GameManager.open_chest(chest_id)` | ⚠ **ある**（`:473-506`）。⚠ **`rewards` の gold / gems / materials / inventory を全部読む** |
| ⚠ **`rewards.inventory` → 個体化** | ⚠ **通っている**（`:498-501` → `add_to_inventory()` → `_create_equipment_instance()`）。⚠ **`CLAUDE.md` 8番の唯一の関所を通る** |
| 倉庫の宝箱タブ | ⚠ **ある**（`warehouse_screen.gd:250-290`）。⚠ **未開封だけ並ぶ・`[開ける]`・`[全部開ける]`** |
| ⚠ **開封結果の表示** | ⚠ **`inventory` も出る**（`:359-364`。⚠ **`tr("ui_res_" + item_id)`**）。⚠ **装備10種の `ui_res_*` は `ja.csv` に全部ある**（`:184-205`） |
| 拠点の未開封バッジ | ⚠ **ある**（`pending_chests_changed`） |
| `apply_battle_rewards()` | ⚠ **`stage_type == story` のときだけ呼ばれる**（`battle_controller.gd:1562`） |

### 1-3. ⚠ 報告するズレ（**4件・勝手に直していない**）

| # | 場所 | 記述 | 実際 |
|---|---|---|---|
| **19** | `EXEC_DECORATION.md` §13-5 | 「全**21**シナリオ ✅ red=0」 | ⚠ **`debug_boot.gd` の `SCENARIOS` は22件**（⚠ **同じEXECの §5-1 は正しく22本と書いている**） |
| **20** | `GAME_DESIGN.md` 15章 | 「`recipes.json` 装備製作レシピ**7件**を削除」 | ⚠ **装備製作は10件 ＋ 変換4件 ＝ 14件**（⚠ **6-5 の 399行も「7件」と書いている**） |
| **21** | `PROJECT_STATUS.md` 84行 | 「**宝箱からも装備が出る**」 | ⚠ **`ChestContentConfig.equipment` は4件とも空。⚠ 器はあるが実データは0件** |
| **22** | `GAME_DESIGN.md` 4-4 | 「**戦闘**｜シナリオの進行度で切り替わる｜素材・装飾」 | ⚠ **戦闘は宝箱を1個も作らない。⚠ `add_pending_chest()` の呼び出し元は `claim_pending_chests()`（ポモドーロ）だけ。⚠ この回で塞ぐ** |

---

## 2. ⚠ 事故りやすい箇所

### 2-1. ⚠ `chest_table` は `rewards` の**中**（§0-1 の1）

⚠ **`rewards` の隣に置くと `apply_battle_rewards()` に届かない**（⚠ **`battle_controller.gd:1556` が渡すのは `_stage_data.get("rewards", {})` だけ**）。
⚠ **`_stage_data` は `MasterDataLoader.get_stage()` の戻り。⚠ 中身を書き換えないこと**（⚠ **リトライで読み直すが、⚠ キャッシュを汚す形は作らない**）。

### 2-2. ⚠ `MasterDataLoader` が返す数値は `float`

⚠ **`weight` も `rolls` も `count` も `int()` で包む**（`CLAUDE.md` 3番）。
⚠ **`weight` が `10.0` のまま合計されると、⚠ `randi_range` に渡す上限が `float` になって黙って壊れる。**

### 2-3. ⚠ 再描画に `await` を持たせない

⚠ **触らないが、⚠ `warehouse_screen.gd` の `_rebuild_*` は `await` を持つ書き方のまま**（`AGENTS.md` 末尾）。
⚠ **`add_pending_chest()` が飛ばすのは `pending_chests_changed` の1本だけ。⚠ 2本目を足さないこと**（⚠ **足すと宝箱の行が二重に並ぶ**）。

### 2-4. ⚠ 状態を変える前に全部の判定を終える

⚠ **抽選 → 当たりが0件なら何もしない → 1件以上あるときだけ `add_pending_chest()` を1回呼ぶ**（`CLAUDE.md` 6番）。
⚠ **途中で積んでから「やっぱり空だった」で消す形にしない。**

### 2-5. ⚠ 編集したら `grep` で当たったことを確認する

⚠ **`CLAUDE.md` 2番。⚠ 特に `warehouse_screen.gd:277` の1行**（⚠ **当たっていないと画面に `ui_chest_battle` がそのまま出る**）。

### 2-6. ⚠ E / W の次番号

⚠ **`E119` まで使用済み → `E120` から。⚠ `W18` まで使用済み → `W19` から**（⚠ **`W6` と `W7` は欠番**）。

---

## 3. 実装（ファイル別）

⚠ **新しい `class_name` も `.tres` も増えない。⚠ エディタを通す回数は `ja.csv` の再インポート1回だけ。**

### 3-A. `resources/balance/master/stages.json`

⚠ **`stage_1` / `stage_2` / `stage_3` の `rewards` の中に `chest_table` を足す。⚠ 既存の `gold` / `materials` / `inventory` は1文字も変えない。**

```json
"chest_table": {
  "rolls": 1,
  "table": [
    { "item_id": "weapon_wooden_sword",  "weight": 10 },
    { "item_id": "armor_leather_cap",    "weight": 10 },
    { "item_id": "armor_leather_boots",  "weight": 10 },
    { "item_id": "",                     "weight": 70 }
  ]
}
```

⚠ **3ステージぶんの中身**（⚠ **数値は全部「勘」。§0-1 の11**）：

| ステージ | `rolls` | 当たり枠（`weight`） | ハズレ | 宝箱が出る率 |
|---|---|---|---|---|
| `stage_1` | 1 | ⚠ **木の剣10 / 革の帽子10 / 革のブーツ10** | ⚠ **70** | ⚠ **30%** |
| `stage_2` | 1 | ⚠ **鉄の剣8 / 革の胴着8 / 力の指輪7 / 革の帽子7** | ⚠ **70** | ⚠ **30%** |
| `stage_3` | 1 | ⚠ **鉄の兜8 / 鉄の鎧8 / 鉄の具足7 / 生命の護符7** | ⚠ **70** | ⚠ **30%** |

⚠ **`stage_dbg_*` の5本には書かない**（§0-1 の8）。
⚠ **`weapon_steel_sword` は入れない**（⚠ **`ja.csv` に名前はあるが、⚠ ドロップ表に入れる根拠が無い。⚠ 宿題に書く**）。
⚠ **`stages.json` だけトップレベルが半角スペース2つ**（`NEXT_STEPS.md` §4）。⚠ **既存の書き方に合わせる。**

### 3-B. `scripts/utils/state_keys.gd`

⚠ **1行だけ足す**（⚠ **`CHEST_SOURCE_POMODORO` の隣**）：

```gdscript
const CHEST_TYPE_BATTLE: String = "battle"
const CHEST_SOURCE_BATTLE: String = "battle"
```

⚠ **`CHEST_TYPE_BATTLE` も `GameStateKeys` に置く**（⚠ **実装時に決めた。⚠ 既存の `CHEST_TYPE_GENERIC` 等4件と並ぶ値なので、⚠ ここだけ `GameManager` に置くと種類が2箇所に分かれる**）。

⚠ **`chest_table` の中のキー（`rolls` / `table` / `weight` / `item_id` / `count`）は状態ではなくマスターデータ。⚠ `GameStateKeys` に入れない**（⚠ **`ITEM_MASTER_ITEM_TYPE` と同じで `game_manager.gd` の定数にする。§3-C**）。

### 3-C. `autoload/game_manager.gd`

**① 定数を足す**（⚠ **`stages.json` のキー。⚠ 文字列リテラルを散らさない**）

```gdscript
const CHEST_TABLE: String = "chest_table"
const CHEST_TABLE_ROLLS: String = "rolls"
const CHEST_TABLE_LIST: String = "table"
const CHEST_TABLE_ITEM_ID: String = "item_id"
const CHEST_TABLE_WEIGHT: String = "weight"
const CHEST_TABLE_COUNT: String = "count"
```

**② `_roll_chest_table(table_def: Dictionary) -> Dictionary` を新設**（⚠ **抽選はこの1本だけ。`NEXT_STEPS.md` §2-4**）

- ⚠ **戻りは `{item_id: count}` の Dictionary**（⚠ **`rewards.inventory` と同じ形。⚠ `get_dismantle_refund()` と同じ流儀**）
- ⚠ **`rolls` 回まわす。⚠ 毎回 `weight` の合計で `randi_range(1, total)` を引き、⚠ 累積で当たり枠を決める**
- ⚠ **`item_id` が `""` の枠に当たったら何も足さない**
- ⚠ **`weight` の合計が0以下なら空を返す**（⚠ **`randi_range` に0を渡さない**）
- ⚠ **同じ `item_id` が2回当たったら `count` を足す**

**③ `_grant_stage_chest(rewards: Dictionary) -> void` を新設**

- ⚠ **`rewards[CHEST_TABLE]` が Dictionary でなければ何もしない**（⚠ **黄も出さない。⚠ 書いていないステージは正常**）
- ⚠ **`_roll_chest_table()` を呼ぶ。⚠ 戻りが空なら何もしない**（§0-1 の3）
- ⚠ **空でなければ `add_pending_chest()` を1回だけ呼ぶ**：

```gdscript
{
    GameStateKeys.CHEST_ID: str(Time.get_unix_time_from_system()) + "_" + str(randi()),
    GameStateKeys.CHEST_TYPE: CHEST_TYPE_BATTLE,
    GameStateKeys.CHEST_SOURCE: GameStateKeys.CHEST_SOURCE_BATTLE,
    GameStateKeys.CHEST_OBTAINED_AT: str(Time.get_unix_time_from_system()),
    GameStateKeys.CHEST_OPENED: false,
    GameStateKeys.CHEST_REWARDS: {
        GameStateKeys.REWARD_INVENTORY: drawn,
    },
}
```

⚠ **`chest_id` の作り方は `claim_pending_chests()`（`:605`）と同じにする。⚠ 2本の作り方を作らない。**

**④ `apply_battle_rewards()` の末尾に1行**

⚠ **`rewards.inventory` を流し終えたあと、⚠ `SignalBus.battle_finished.emit()` の**前**に `_grant_stage_chest(rewards)` を呼ぶ。
⚠ **既存の gold / materials / inventory の枝は1文字も変えない。**

### 3-D. `scripts/systems/master_data_loader.gd`

⚠ **`stages.json` を見ている既存の検証（`:199-276` の枝）に足す。⚠ 新しい検証関数を作らない。**

| 記号 | 何を見るか | 色 |
|---|---|---|
| ⚠ **`E118` 拡張** | ⚠ **`rewards.chest_table.table[].item_id` が `items.json` に無い**（⚠ **`""` は飛ばす**） | 赤 |
| ⚠ **`E120`（新規）** | ⚠ **`chest_table` の形が不正**：⚠ **`rolls` が1未満 ／ `table` が空 ／ `weight` が負 ／ `weight` の合計が0以下** | 赤 |
| ⚠ **`W19`（新規）** | ⚠ **`chest_table` はあるが、⚠ 当たり枠（`item_id != ""`）が1件も無い** | 黄 |

⚠ **`W19` の理由**：⚠ **そのステージは永久に宝箱を落とさない。⚠ 「書いたのに出ない」が無音になる形。⚠ ただし「今は落とさない」と意図的に書く余地を残すので赤にしない。**
⚠ **メッセージに `stage_id` を必ず入れる**（⚠ **どのステージか分からないと直せない**）。

### 3-E. `scenes/guild/warehouse_screen.gd`

⚠ **277行の1行だけ**：

```gdscript
name_label.text = tr("ui_chest_" + str(chest.get(GameStateKeys.CHEST_TYPE, "")))
```

⚠ **他は1行も触らない**（⚠ **`_rebuild_*` の `await` にも触らない。§2-3**）。

### 3-F. `localization/ja.csv`

⚠ **改名4行 ＋ 新規1行 ＝ 5行。⚠ 他の行に触らない。**

| 旧キー | 新キー | 値 |
|---|---|---|
| `ui_pomodoro_chest_generic` | ⚠ **`ui_chest_generic`** | ふつうの宝箱 |
| `ui_pomodoro_chest_bonus_small` | ⚠ **`ui_chest_bonus_small`** | ボーナス宝箱（小） |
| `ui_pomodoro_chest_bonus_medium` | ⚠ **`ui_chest_bonus_medium`** | ボーナス宝箱（中） |
| `ui_pomodoro_chest_bonus_large` | ⚠ **`ui_chest_bonus_large`** | ボーナス宝箱（大） |
| — | ⚠ **`ui_chest_battle`（新規）** | ⚠ **戦利品の宝箱** |

⚠ **`ui_pomodoro_chest_at` と `ui_pomodoro_chest_earned` は改名しない**（⚠ **`chest_type` ではない。⚠ ポモドーロ画面の文言**）。
⚠ **UTF-8（BOMなし）。⚠ CR を混ぜない。**

### 3-G. `tests/debug_boot.gd`

⚠ **`SCENARIOS` に1行足す。⚠ シーンもスクリプトも増やさない**（`:525` の注記どおり）。

```gdscript
"drops": {
    "kind": KIND_REPORT,
    "report": REPORT_DROPS,
    "note": "ステージの抽選ドロップ / 宝箱を積む→開ける→個体になる / 重みの分布",
},
```

⚠ **`REPORT_DROPS` の定数と、⚠ `:527-532` の分岐に `elif` を1本足す。⚠ `_report_drops()` を新設。**

⚠ **`_report_drops()` が `print` するもの**：

1. ⚠ **3ステージの `chest_table` を、⚠ 当たり枠とハズレの `weight` ／ 宝箱が出る率（%）で並べる**
2. ⚠ **`stage_1` のテーブルを1000回引き、⚠ 各 `item_id` の出現数と、⚠ 宝箱が出なかった回数**
3. ⚠ **`apply_battle_rewards()` に `stage_3` の `rewards` を渡し、⚠ 宝箱が積まれるまで繰り返す**（⚠ **上限200回。⚠ 積まれなかったら赤**）
4. ⚠ **積まれた宝箱の `chest_type` / `source` / `rewards.inventory`**
5. ⚠ **`open_chest()` を呼び、⚠ `equipment_instances` が増えたこと ／ 増えた個体の `item_id` と `grade` と `parts` の長さ**
6. ⚠ **ハズレだけのテーブル（`item_id` が全部 `""`）を引いて、⚠ 宝箱が積まれないこと**

⚠ **`SaveManager` をこのファイルから呼ばないこと**（`:518-520`）。

---

## 4. 変えないもの

- ⚠ **`battle_controller.gd`**（決定E）。⚠ **結果画面は gold と materials のまま**
- ⚠ **`recipes.json` の14件**（⚠ **廃止は次の回。決定A・F**）
- ⚠ **`ChestContentConfig`**（⚠ **`equipment` 欄は空のまま。⚠ ポモドーロの宝箱に装備を入れるのは別の回**）
- ⚠ **`add_to_inventory()` の引数**（⚠ **等級を渡す口を開けない。§0-1 の5**）
- ⚠ **`open_chest()` の中身**（⚠ **決定C で「積むときに振る」と決めたので、⚠ ここは読むだけのまま**）
- ⚠ **`_create_equipment_instance()`**（⚠ **`INSTANCE_GRADE: 1` のまま**）
- ⚠ **`ui_pomodoro_chest_at` / `ui_pomodoro_chest_earned`**
- ⚠ **`ja.csv` の `ui_status_ch_*` 45行**

> ⚠ **`PART_SLOT_COUNT` / `PART_SLOT_GRADES` をここに書かない。**
> ⚠ **前回、⚠ 台帳（`GAME_DESIGN` 15章）が「置き換えろ」と言っている値を「変えないもの」に書いて保護し、⚠ 丸ごと作り直しになった**（`EXEC_DECORATION.md` §13-1）。
> ⚠ **この §4 の6件は、⚠ `GAME_DESIGN` 15章 ／ `PLAN_IMPLEMENTATION` 3章 ／ `PROJECT_STATUS` の決定済み表を `grep` して、⚠ 「置き換えろ」が書かれていないことを確かめてある。**

---

## 5. 完了条件 — **§0 事前チェック**（⚠ **設計役・ヘッドレス。⚠ 人間に渡す前に終わっている**）

1. ⚠ **全23シナリオ（既存22 ＋ 新規 `drops`）で `ERROR:` / `SCRIPT ERROR:` / `Parse Error` が1行も出ないこと**（⚠ **`training` は窓あり専用なので除く＝実際に回すのは22本。⚠ 1本10〜20秒なので分けて回す**）
2. ⚠ **`items validated: 64 entries, 0 errors`**（⚠ **この回で件数が変わらないこと**）
3. ⚠ **`skills validated: 79 entries, 0 errors, 1 warnings`**（⚠ **黄1本は `skill_dbg_dot_odd` の端数。⚠ 増えないこと**）
4. ⚠ **`basic attacks validated: 19 entries, 0 errors, 0 warnings`**
5. ⚠ **`E118` / `E120` / `W19` がロード時に0件であること**（⚠ **本番データが全部正しい状態**）
6. ⚠ **触った6ファイルとも `--check-only --script` で `Parse Error` が0件**（⚠ **`Identifier not found` は Autoload 未読み込みで構文エラーではない**）

## 6. 完了条件 — **ログ / ファイル**（⚠ **設計役が読む。⚠ 人間の仕事は無い**）

### 6-A. 抽選そのもの（`scenario=drops`）

7. ⚠ **`stage_1` を1000回引いたとき、⚠ 宝箱が出た回数が 300 ± 60 に収まること**（⚠ **重み30/100。⚠ 幅は乱数のぶれ**）
8. ⚠ **その1000回で、⚠ `stage_1` の当たり3種すべてが1回以上出ること**（⚠ **`randi_range` を呼び忘れて常に同じ枠、を潰す**）
9. ⚠ **`stage_1` のテーブルから、⚠ `stage_2` / `stage_3` にしか無いIDが1件も出ないこと**（⚠ **テーブルを取り違えていない**）
10. ⚠ **ハズレだけのテーブルで、⚠ 宝箱が1個も積まれないこと**（§0-1 の3）
11. ⚠ **`weight` の合計が0のテーブルで、⚠ 赤も黄も出さずに空を返すこと**（⚠ **`randi_range(1, 0)` を踏んでいない**）

### 6-B. 宝箱が積まれてから個体になるまで

12. ⚠ **`apply_battle_rewards()` を `stage_3` の `rewards` で呼ぶと、⚠ `pending_chests` が1件増えること**
13. ⚠ **積まれた宝箱の `chest_type` が `battle`、⚠ `source` が `battle`、⚠ `opened` が `false` であること**
14. ⚠ **`rewards.inventory` の中身が `stage_3` のテーブルにあるIDだけであること**
15. ⚠ **`open_chest()` を呼ぶと `equipment_instances` が増え、⚠ 増えた個体の `grade` が `1`、⚠ `parts` の長さが `8` であること**（⚠ **`add_to_inventory()` の関所を通っている証拠。`CLAUDE.md` 8番**）
16. ⚠ **その `grade` に `.0` が付いていないこと**（`CLAUDE.md` 3番）
17. ⚠ **`open_chest()` を同じ `chest_id` で2回呼ぶと、⚠ 2回目が `false` を返し、⚠ 個体が増えないこと**（⚠ **既存の `already opened` の枝**）
18. ⚠ **1回の `apply_battle_rewards()` で `pending_chests_changed` が1本だけ飛ぶこと**（§2-3）

### 6-C. 既存が動いていないこと

19. ⚠ **`chest_table` を持たないステージ（`stage_dbg_*`）で宝箱が積まれないこと。⚠ 黄も出ないこと**
20. ⚠ **`stage_1` / `stage_2` / `stage_3` の `gold` と `materials` と `inventory` が前回と同じ値で入ること**（⚠ **`apply_battle_rewards()` の既存3枝を壊していない**）
21. ⚠ **`area` 3/4/4/3 ／ `recast` 2/8 ／ `mitigate` 200/300/200/120 ／ `pierce` 194/200 ／ `lineup` 99.4 ／ `atk_mult` 200→400 ／ `pool` の `zone` 12件 ／ `dot_react` の `react` 6件**（⚠ **前回と同じ値**）
22. ⚠ **`parts` シナリオが `EXEC_DECORATION.md` §13-4 と同じ出力であること**（⚠ **装飾に触っていない**）
23. ⚠ **`save_slot_0.json` が設計役のヘッドレス実行で書き換わらないこと**

### 6-D. ファイル

24. ⚠ **`ja.csv` が 427行（426 ＋ 新規1行）。⚠ BOM が無いこと。⚠ CR が0バイトであること**
24-b. ⚠ **`git diff --numstat localization/ja.csv` が `5	4` であること**（⚠ **改行コードが混ざると全行が差分になる。⚠ 行数だけ見ていると気づけない**）
> ⚠ **CR は `grep -c $'\r'` で数えないこと。⚠ Git Bash では全行に誤ヒットする（2026-08-23 に実際に踏んだ）。⚠ `python -c "print(open(p,'rb').read().count(b'\x0d'))"` で数える。**
25. ⚠ **`ja.csv` に `ui_pomodoro_chest_generic` / `_bonus_small` / `_bonus_medium` / `_bonus_large` が0件であること**（⚠ **改名の取りこぼし**）
26. ⚠ **`grep -rn "ui_pomodoro_chest_" --include=*.gd --include=*.tscn` が `ui_pomodoro_chest_at` と `ui_pomodoro_chest_earned` 以外に当たらないこと**
27. ⚠ **重複キーが0件であること**
28. ⚠ **`stages.json` の `chest_table` に書いた `item_id` が全部 `items.json` に実在すること**（⚠ **`""` を除いて14件**）
29. ⚠ **`recipes.json` が14件のまま**（⚠ **この回で触っていない。§4**）

### 6-E. ⚠ 足した検証が本当に出るか（**2箇所で壊す**）

30. ⚠ **`E118` の新しい枝を実測する**：⚠ **`stage_1` の `chest_table` の `item_id` を1件壊し、⚠ 赤が1本出ること。⚠ 戻して0件に戻ること**
31. ⚠ **別のステージでも同じことを見る**：⚠ **`stage_3` でも同じく赤が出ること**（⚠ **1ステージだけ通っていて他が素通り、を潰す。⚠ `E118` で実際にやった形**）
32. ⚠ **`E120` を実測する**：⚠ **`stage_1` の `rolls` を `0` にして赤が出ること ＋ `stage_2` の `weight` を負にして赤が出ること**（⚠ **2箇所**）
33. ⚠ **`W19` を実測する**：⚠ **`stage_1` の当たり枠を全部 `""` にして黄が1本出ること ＋ `stage_2` でも同じく出ること**（⚠ **2箇所**）。⚠ **どちらも赤にならないこと**

## 7. 完了条件 — **画面**（⚠ **人間だけ**）

### 7-A. ⚠ 先にやってもらうこと

| # | やること |
|---|---|
| **A-1** | ⚠ **`ja.csv` を再インポート**（⚠ **FileSystem で右クリック → 再インポート**）。⚠ **キーを4つ改名しているので、⚠ これをしないと倉庫の宝箱の名前が全部 `ui_chest_...` になる。⚠ 合図は下の 34** |
| **A-2** | ⚠ **`F4` のデバッグパネルは要らない**（⚠ **今回はステージを勝つだけで到達できる**） |

⚠ **`class_name` も `.tres` も増えていないので、⚠ エディタを開くのは1回。**
⚠ **セーブは消さなくてよい**（⚠ **IDを1件も改名していない。⚠ 翻訳キーだけ**）。

### 7-B. ⚠ 見るもの

| # | 見るもの |
|---|---|
| **34** | ⚠ **倉庫の宝箱タブで、⚠ `ui_chest_` で始まる文字がそのまま出ている箇所が無いこと**（⚠ **出たら再インポート漏れ**） |
| **35** | ⚠ **`stage_1` を数回クリアすると、⚠ 拠点の未開封バッジが増えることがあること**（⚠ **30%なので出ない回がある。⚠ 10回やって1度も増えなければ報告してほしい**） |
| **36** | ⚠ **戦闘結果の報酬画面には宝箱が出ないこと**（⚠ **決定E。⚠ gold と materials だけ。⚠ ここが変わっていたら報告してほしい**） |
| **37** | ⚠ **倉庫の宝箱タブに `戦利品の宝箱` が並ぶこと**（⚠ **`ふつうの宝箱` ではないこと。⚠ ポモドーロの宝箱と名前で見分けがつくこと**） |
| **38** | ⚠ **`[開ける]` を押すと、⚠ 下のラベルに装備の名前が出ること**（⚠ **`木の剣 ×1` のような形。⚠ `ui_res_...` がそのまま出ないこと**）。⚠ **出た名前を報告してほしい** |
| **39** | ⚠ **開けたあと、⚠ その宝箱が一覧から消えること。⚠ 未開封バッジが減ること** |
| **40** | ⚠ **装備画面に、⚠ 開けて出た装備が並んでいること**（⚠ **ここが今回の目玉。⚠ 作業場を使わずに装備が手に入る**） |
| **41** | ⚠ **その装備を装備できること。⚠ ステータスが増えること** |
| **42** | ⚠ **その装備を等級3まで鍛えると宝石枠が開き、⚠ 装飾が刺さること**（⚠ **入手 → 鍛冶 → 枠 → 装飾 が一周する。⚠ `EXEC_DECORATION.md` §7-C の35と同じ画面**） |
| **43** | ⚠ **ポモドーロの宝箱がこれまでどおり受け取れて開けられること**（⚠ **名前が `ふつうの宝箱` などのまま。⚠ 改名で壊していない**） |
| **44** | ⚠ **`[全部開ける]` で、⚠ 戦闘の宝箱とポモドーロの宝箱が両方開くこと** |

⚠ **40 と 42 が今回の目玉。⚠ 他が落ちても、⚠ この2つが通っているかを先に教えてほしい。**

---

## 8. 将来コードを変えたときに見る項目

- ⚠ **`weight` の合計が0のテーブルを本番データに書いたとき**（⚠ **`E120` が出る。⚠ 正規の経路では作れない**）
- ⚠ **`rolls` を2以上にしたとき、⚠ 同じ `item_id` が2回当たって `count` が2になるか**（⚠ **本番データは全部 `rolls: 1`**）
- ⚠ **`chest_table` に素材を書いたとき**（⚠ **`rewards.inventory` に素材IDを入れると `add_to_inventory()` が在庫に積む。⚠ `add_material()` は通らない。⚠ 素材を落としたいなら別の欄が要る**）
- ⚠ **ドロップに等級を振るとき**（§0-1 の5。⚠ **`add_to_inventory()` の引数を増やすことになる。⚠ `CLAUDE.md` 8番の関所**）
- ⚠ **`ChestContentConfig.equipment` を埋めたとき**（⚠ **ポモドーロの宝箱からも装備が出るようになる。⚠ ズレ21**）
- ⚠ **スキップ周回が入ったとき**（⚠ **`GAME_DESIGN` 4-1「固定報酬も抽選ドロップも通常通り引く」。⚠ `apply_battle_rewards()` を呼べば満たせる形にしてある**）

---

## 9. Ziva に渡せる部分

⚠ **ある。⚠ `localization/ja.csv` の5行（§3-F）。⚠ `.gd` を1行も触らない。**
⚠ **ただし `warehouse_screen.gd:277`（§3-E）が先に入っていないと、⚠ 改名した4行が画面から消えて `ui_chest_generic` がそのまま出る。**
→ ⚠ **順番は「`.gd` と `stages.json` → `ja.csv`」。⚠ 同時に渡さない**（⚠ **前回・前々回と同じ**）。

⚠ **`stages.json` の `chest_table`（§3-A）は渡さない。**
⚠ **理由：⚠ `_grant_stage_chest()`（§3-C）と `E120` / `W19`（§3-D）とセットで初めて効く。⚠ 別々の手が触ると「書いたのに落ちない」の原因がどちらか分からなくなる。**

---

## 10. 終わったあとに足す宿題

- ⚠ **NEW：ドロップの `weight` が全部「勘」**（⚠ **`stages.json` の3テーブル・14行。⚠ バランスの回で必ず戻ってくる**）
- ⚠ **NEW：宝箱が3ステージとも30%で同じ**（⚠ **進行度で美味しさが変わらない。⚠ `GAME_DESIGN` 4-1 の「ステージによって落ちるものが違う」は種類だけ満たしている**）
- ⚠ **NEW：ドロップの等級が1固定**（⚠ **`GAME_DESIGN` 631行の「高等級の確率」が未実装**）
- ⚠ **NEW：`weapon_steel_sword` がどこからも出ない**（⚠ **`ja.csv` に名前があり `items.json` にもあるが、⚠ ショップにもドロップにもレシピにも無い**）
- ⚠ **NEW：戦闘の宝箱が `chest_type` 1種類**（⚠ **倉庫でどのステージから出たか分からない。⚠ `source` には入っているが画面に出ない**）
- ⚠ **NEW：`chest_table` に素材を書くと在庫に積まれる**（§8。⚠ **素材の枠が無い**）
- ⚠ **NEW：`apply_battle_rewards()` が `gems` と `stamina` を読まない**（⚠ **前回からの持ち越し。⚠ この回でも塞いでいない**）
- ⚠ **NEW：③作業場の廃止が次の回に残っている**（決定A・F。⚠ **`recipes.json` 14件・ギルドのボタンを隠す**）
- ⚠ **NEW：報告したズレ4件が未修正**（§1-3 の19〜22。⚠ **勝手に直していない**）
