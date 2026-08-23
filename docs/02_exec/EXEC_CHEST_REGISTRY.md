# EXEC_CHEST_REGISTRY — 宝箱の定義を `chests.json` に1本化する

**`GAME_DESIGN.md` 4-2（固定報酬＋抽選ドロップの二立て）／ 4-4（入手元ごとに別テーブル）。**
⚠ **`EXEC_STAGE_DROPS.md` §11 の事故（`.tres` の素材IDが改名から漏れた）を、⚠ 構造で起きなくする回。**

---

## 0. 人間が決めたこと（**本文と矛盾する場合はこちらが優先**・2026-08-23）

| # | 決定 |
|---|---|
| **A** | ⚠ **`chests.json` を新設する**（⚠ **マスターファイル6本目**）。⚠ **チェストの種類ごとに1エントリ。⚠ 抽選テーブルもそこで持つ** |
| **B** | ⚠ **ポモドーロの宝箱の中身も移す**（⚠ **`.tres` から JSON へ。⚠ `ChestContentConfig` は消える**） |
| **C** | ⚠ **状態のキーを `chest_id` に揃える**（⚠ **定義を指す欄の名前**） |

---

## 0-1. ⚠ 設計役が自分で決めたもの（**人間が見ていない決め・要確認**）

⚠ **8件。⚠ 覆すなら実装前に言ってほしい。**

| # | 決めたこと | なぜ |
|---|---|---|
| **1** | ⚠ **`pending_chests` の一意IDを `chest_id` → `instance_id` に改める** | ⚠ **決定C で定義を指す欄を `chest_id` と呼ぶが、⚠ その名前は既に「宝箱1個の一意ID」（`1787458307.861_1169711068`）が使っている。⚠ 同じ名前が2つの意味を持つので、⚠ 一意IDのほうを譲る。⚠ 装備の個体が `instance_id` を使っているので語も揃う** |
| **2** | ⚠ **`ChestScheduleEntry.chest_type` の `@export` 名は変えない** | ⚠ **`protection_light/middle/hard.tres` の7件が `chest_type = "generic"` の形で値を持っている。⚠ `@export` を改名すると `.tres` の旧キーが孤児になり、⚠ 新しい欄は空になる＝加護の宝箱が一切もらえなくなる。⚠ しかも赤も黄も出ない。⚠ 欄の名前だけ据え置き、⚠ 中の値は `chest_id` を指す** |
| **3** | ⚠ **`chest_id` の値は既存のまま**（⚠ **`generic` / `bonus_small` / `bonus_medium` / `bonus_large`**）⚠ **＋ 戦闘用に `stage_1` / `stage_2` / `stage_3`** | ⚠ **`pomodoro_` を付けたくなるが、⚠ 付けると `protection_*.tres` の7件を Inspector で直す作業が増える。⚠ 決定2 と同じ理由で値を動かさない** |
| **4** | ⚠ **`ja.csv` を1行も触らない** | ⚠ **`ui_chest_generic` 〜 `ui_chest_bonus_large` と `ui_chest_battle` は既にあり、⚠ 人間が再インポート済み（`EXEC_STAGE_DROPS.md` §7-B）。⚠ `stage_1..3` の3件は `ui_chest_battle` を共用する。⚠ **再インポートが要らない** |
| **5** | ⚠ **抽選の欄名を整える**：⚠ **`chest_table` → `draw` ／ その中の `table` → `entries`** | ⚠ **いまの形は `chest_table.table` で同じ語が入れ子になっている。⚠ 移す回なので綴りを直す。⚠ `stages.json` からは消える欄なので、⚠ 残る場所は1つだけ** |
| **6** | ⚠ **1エントリが `rewards`（固定）と `draw`（抽選）の両方を持てる** | ⚠ **`GAME_DESIGN` 4-2 の二立てがそのまま形になる。⚠ ポモドーロは `rewards` だけ、⚠ 戦闘は `draw` だけ、⚠ 将来「固定＋抽選」の宝箱も書ける** |
| **7** | ⚠ **`E120` と `W19` を `chests.json` 側の検証に移す。⚠ `E118` は `rewards` と `draw` の両方のIDを見る** | ⚠ **`stages.json` から `chest_table` が消えるので、⚠ 検証の置き場も移る。⚠ 番号は使い回す（意味が同じため）** |
| **8** | ⚠ **実装を前半・後半に割る** | ⚠ **`@export var chest_contents` を消す前に、⚠ 人間が `.tres` 側を空にしないと `ext_resource` が孤児になって `Parse Error` になる。⚠ `PartConfig` の回と同じ形。⚠ 「エディタを通すのは1回でいい」と書かないこと** |

---

## 1. いま何がどうなっているか（**実コードで確認済み・2026-08-23**）

⚠ **宝箱に関する情報が5箇所に散っている。**

| 置き場 | 何を持っているか | 検証 |
|---|---|---|
| ⚠ **`pomodoro_config.tres` の `chest_contents`** | ⚠ **ポモドーロ宝箱4種の `materials` / `equipment`** | ⚠ **`E118` が見ない**（⚠ **`EXEC_STAGE_DROPS.md` §11 の事故の原因**） |
| ⚠ **`stages.json` の `rewards.chest_table`** | ⚠ **戦闘宝箱の抽選テーブル3件** | ⚠ **`E118` / `E120` / `W19` が見る** |
| `protection_*.tres` の `ChestScheduleEntry` | ⚠ **7件。⚠ しきい値 → `chest_type`** | 見ない |
| `state_keys.gd` の `CHEST_TYPE_*` | 種類の名前5件 | — |
| `ja.csv` の `ui_chest_*` | 表示名5件 | — |

⚠ **`ChestContentConfig.equipment` は4件とも空**（`EXEC_STAGE_DROPS.md` §1-3 のズレ21）。⚠ **移すのは `materials` だけになる。**

---

## 2. ⚠ 事故りやすい箇所

### 2-1. ⚠ `@export` を改名すると `.tres` の値が黙って消える（**この回の最大の罠**）

⚠ **`.tres` は `@export` の変数名をそのままキーにして保存している。⚠ `.gd` 側で改名すると、⚠ 旧キーは孤児になり、⚠ 新しい欄は既定値（`String` なら `""`）になる。⚠ 赤も黄も出ない。**
→ ⚠ **`ChestScheduleEntry.chest_type` は触らない**（§0-1 の2）。⚠ **触ると加護の宝箱7件が全部消える。**

### 2-2. ⚠ `chest_id` が2つの意味を持っていた

⚠ **`pending_chests` の `chest_id` は「その1個」の一意ID。⚠ `chests.json` の `chest_id` は「種類」。⚠ 前者を `instance_id` に改める**（§0-1 の1）。
⚠ **`open_chest(chest_id)` の引数名も `instance_id` にする。⚠ 呼び出し元は `warehouse_screen.gd` の2箇所。**

### 2-3. ⚠ `.tres` を空にする前に `.gd` を消さない

⚠ **`chest_content_config.gd` を先に消すと、⚠ `pomodoro_config.tres` の `ext_resource` が実在しないパスを指して `Parse Error` になる**（`EXEC_DECORATION.md` §2-3 と同じ形）。
→ ⚠ **前半では `.gd` も `@export` も残す。⚠ 人間が `.tres` を空にしてから後半で消す。**

### 2-4. ⚠ `MasterDataLoader` が返す数値は `float`

⚠ **`rolls` / `weight` / `count` / `materials` の個数を `int()` で包む**（`CLAUDE.md` 3番）。

### 2-5. ⚠ 状態を変える前に全部の判定を終える

⚠ **`claim_pending_chests()` は、⚠ 定義が引けなかった `chest_id` を黄で言って飛ばす形を保つ**（⚠ **既存の `chest_type not found in config` と同じ**）。

### 2-6. ⚠ E / W の次番号

⚠ **`E121` まで使用済み → `E122` から。⚠ `W19` まで使用済み → `W20` から**（⚠ **`W6` と `W7` は欠番**）。
⚠ **`E120` と `W19` は番号を使い回す**（§0-1 の7。⚠ **置き場が移るだけで意味は同じ**）。

---

## 3. 実装 — **前半**（⚠ **人間の `.tres` 作業の前**）

### 3-A. `resources/balance/master/chests.json`（**新規**）

```json
{
  "chests": [
    {
      "chest_id": "generic",
      "name_key": "ui_chest_generic",
      "sort_order": 0,
      "rewards": { "materials": { "construction_material_1": 4 } }
    },
    {
      "chest_id": "bonus_small",
      "name_key": "ui_chest_bonus_small",
      "sort_order": 1,
      "rewards": { "materials": { "construction_material_1": 10 } }
    },
    {
      "chest_id": "bonus_medium",
      "name_key": "ui_chest_bonus_medium",
      "sort_order": 2,
      "rewards": { "materials": { "construction_material_1": 25 } }
    },
    {
      "chest_id": "bonus_large",
      "name_key": "ui_chest_bonus_large",
      "sort_order": 3,
      "rewards": { "materials": { "construction_material_1": 30 } }
    },
    {
      "chest_id": "stage_1",
      "name_key": "ui_chest_battle",
      "sort_order": 10,
      "draw": {
        "rolls": 1,
        "entries": [
          { "item_id": "weapon_wooden_sword", "weight": 10 },
          { "item_id": "armor_leather_cap", "weight": 10 },
          { "item_id": "armor_leather_boots", "weight": 10 },
          { "item_id": "", "weight": 70 }
        ]
      }
    }
  ]
}
```

⚠ **`stage_2` / `stage_3` も同じ形**（⚠ **中身は `EXEC_STAGE_DROPS.md` §3-A の表のまま。⚠ 数値を1つも変えない**）。
⚠ **ポモドーロ4件の個数（4 / 10 / 25 / 30）は `pomodoro_config.tres` の現物のまま。⚠ IDだけ `_1` 付きに直す**（⚠ **これで §11 の事故が消える**）。
⚠ **`equipment` は4件とも空だったので書かない**（§1）。

### 3-B. `scripts/systems/master_data_loader.gd`

**① 読み込み**（⚠ **`items` / `recipes` と同じ形。⚠ 末尾に追記**）

```gdscript
const PATH_CHESTS: String = DIR_PATH + "chests.json"
static var _cache_chests: Dictionary = {}
static var _chests_loaded: bool = false

static func get_chest(chest_id: String) -> Dictionary
static func get_all_chests() -> Dictionary
static func _ensure_chests_loaded() -> void   # _index_by(..., "chests", "chest_id", ...)
```

**② 検証**（⚠ **`_validate_all_item_refs()` の中に枝を1本足す。⚠ 関数を増やさない**）

| 記号 | 何を見るか | 色 |
|---|---|---|
| ⚠ **`E118` 拡張** | ⚠ **`rewards.materials` / `rewards.inventory` / `draw.entries[].item_id` が `items.json` に無い**（⚠ **`""` は飛ばす**） | 赤 |
| ⚠ **`E120`（移設）** | ⚠ **`draw` の形が不正**：⚠ **`rolls` < 1 ／ `entries` が空 ／ `weight` が負 ／ 合計が0以下** | 赤 |
| ⚠ **`W19`（移設）** | ⚠ **`draw` はあるが当たり枠が1件も無い** | 黄 |
| ⚠ **`E122`（新規）** | ⚠ **`stages.json` の `rewards.chest_id` が `chests.json` に無い** | 赤 |
| ⚠ **`W20`（新規）** | ⚠ **`chests.json` のエントリが `rewards` も `draw` も持たない**（⚠ **開けても何も出ない宝箱**） | 黄 |

⚠ **`stages.json` から `chest_table` を見る枝は消す**（⚠ **欄ごと移るため**）。
⚠ **メッセージに `chest_id` / `stage_id` を必ず入れる。**

### 3-C. `scripts/utils/state_keys.gd`

| いま | ⚠ **これから** |
|---|---|
| `CHEST_ID = "chest_id"`（⚠ **一意ID**） | ⚠ **`CHEST_INSTANCE_ID = "instance_id"** |
| `CHEST_TYPE = "chest_type"`（⚠ **種類**） | ⚠ **`CHEST_ID = "chest_id"**（⚠ **`chests.json` を指す**） |
| ⚠ **`CHEST_TYPE_GENERIC` 〜 `_BATTLE` の5件** | ⚠ **消す**（⚠ **IDは `chests.json` が持つ。⚠ `.gd` に並べない**） |
| `CHEST_SOURCE_POMODORO` / `_BATTLE` | ⚠ **そのまま** |

⚠ **コメントの `PENDING_CHESTS: [{chest_id, chest_type, ...}]` も直す** → ⚠ **`[{instance_id, chest_id, source, obtained_at, opened, rewards}]`**。

### 3-D. `autoload/game_manager.gd`

**① `chests.json` の欄の定数**（⚠ **`CHEST_TABLE_*` を置き換える**）

```gdscript
const CHEST_NAME_KEY: String = "name_key"
const CHEST_DRAW: String = "draw"
const CHEST_DRAW_ROLLS: String = "rolls"
const CHEST_DRAW_ENTRIES: String = "entries"
const CHEST_DRAW_ITEM_ID: String = "item_id"
const CHEST_DRAW_WEIGHT: String = "weight"
const CHEST_DRAW_COUNT: String = "count"
```

**② `_roll_chest_table()` → `_roll_chest_draw(draw_def)`**
⚠ **中身は同じ。⚠ 欄名だけ差し替える。⚠ 抽選はこの1本だけ。**

**③ `grant_chest(chest_id, source) -> bool` を新設**（⚠ **宝箱を積む唯一の口**）

- ⚠ **`MasterDataLoader.get_chest(chest_id)` を引く。⚠ 空なら黄を出して `false`**
- ⚠ **`rewards`（固定）を複製し、⚠ `draw` があれば引いて `inventory` に合流させる**
- ⚠ **合流した結果が空なら積まない**（⚠ **`EXEC_STAGE_DROPS.md` §0-1 の3 を引き継ぐ**）
- ⚠ **`add_pending_chest()` を1回だけ呼ぶ**

⚠ **`claim_pending_chests()`（ポモドーロ）と `_grant_stage_chest()`（戦闘）は、⚠ 両方この1本を通す**（⚠ **積む形が2つあると、⚠ 片方だけ直す事故が起きる。`NEXT_STEPS` §2-4**）。

**④ `claim_pending_chests()` の書き換え**
⚠ **`Balance.pomodoro.chest_contents` を引くのをやめ、⚠ `grant_chest(chest_type_の値, CHEST_SOURCE_POMODORO)` を呼ぶ。**

**⑤ `_grant_stage_chest(rewards)` の書き換え**
⚠ **`rewards[CHEST_TABLE]` を見るのをやめ、⚠ `rewards["chest_id"]` を読んで `grant_chest(それ, CHEST_SOURCE_BATTLE)` を呼ぶ。**

**⑥ `open_chest()` の引数名を `instance_id` に。⚠ 中で読むキーも `CHEST_INSTANCE_ID` に。**

**⑦ `_validate_balance_item_refs()`（`E121`）から宝箱の枝を消す**
⚠ **`pomodoro_config.tres` の宝箱が `chests.json` へ移るため。⚠ 残るのは `character_config` / `initial_state_config` / `research_config` / `shop_config` の4箇所。**

### 3-E. `resources/balance/master/stages.json`

⚠ **`rewards.chest_table`（3ステージぶん）を消し、⚠ 代わりに1行入れる。**

```json
"chest_id": "stage_1"
```

⚠ **`gold` / `materials` / `inventory` は1文字も変えない。**

### 3-F. `scenes/guild/warehouse_screen.gd`

- ⚠ **`tr("ui_chest_" + chest_type)` をやめ、⚠ `MasterDataLoader.get_chest(chest_id).get("name_key")` を `tr()` に渡す**（⚠ **接頭辞の組み立てをやめる。§0-1 の4 で `ja.csv` は触らない**）
- ⚠ **`chest_id` を読んでいた2箇所を `instance_id` に**
- ⚠ **`_rebuild_*` の `await` には触らない**（§2-3 は別の話）

### 3-G. `tests/debug_boot.gd`

⚠ **`drops` シナリオを新しい形に直す。⚠ シナリオを増やさない。**

- ⚠ **`chests.json` の全エントリを、⚠ 固定／抽選の別・当たり率つきで並べる**
- ⚠ **`stage_1` の `draw` を1000回引いた分布**（⚠ **前回と同じ検証**）
- ⚠ **`grant_chest("generic", ...)` で固定の宝箱が積まれ、⚠ 開けると素材が増えること**（⚠ **ポモドーロ側の経路。⚠ これまで検証が1本も無かった**）
- ⚠ **`grant_chest("stage_3", ...)` で抽選の宝箱が積まれ、⚠ 開けると個体になること**
- ⚠ **`grant_chest("知らないID", ...)` が黄を出して `false` を返すこと**

---

## 3-H. 実装 — **後半**（⚠ **人間の `.tres` 作業のあと**）

- ⚠ **`resources/balance/pomodoro_config.gd` から `@export var chest_contents: Array[ChestContentConfig]` を消す**
- ⚠ **`resources/balance/chest_content_config.gd` と `.uid` を消す**

⚠ **前半では両方とも残す**（§2-3）。

---

## 4. 変えないもの

- ⚠ **`ChestScheduleEntry.chest_type` の `@export` 名**（§0-1 の2。⚠ **改名すると `.tres` 7件が黙って空になる**）
- ⚠ **`protection_light/middle/hard.tres`**（⚠ **1文字も触らない**）
- ⚠ **`ja.csv`**（§0-1 の4。⚠ **再インポートが要らない**）
- ⚠ **`battle_controller.gd`**（⚠ **`EXEC_STAGE_DROPS.md` 決定E を引き継ぐ**）
- ⚠ **抽選の数値**（⚠ **`weight` も `rolls` も宝箱の個数も、⚠ 移すだけで1つも変えない**）
- ⚠ **`add_to_inventory()` の引数**（`CLAUDE.md` 8番）
- ⚠ **`recipes.json` の14件**（⚠ **廃止は次の回**）

> ⚠ **この7件は、⚠ `GAME_DESIGN` 15章 ／ `PLAN_IMPLEMENTATION` 3章 ／ `PROJECT_STATUS` の決定済み表を `grep` して、⚠ 「置き換えろ」が書かれていないことを確かめてある**（`EXEC_DECORATION.md` §13-1 の再発防止）。

---

## 5. 完了条件 — **§0 事前チェック**（⚠ **設計役・ヘッドレス**）

1. ⚠ **全22シナリオで `ERROR:` / `SCRIPT ERROR:` / `Parse Error` が1行も出ないこと**（⚠ **`training` は窓あり専用なので除く**）
2. ⚠ **`items validated: 64 entries, 0 errors`**（⚠ **件数が変わらないこと**）
3. ⚠ **`skills` `79 / 0 / 1` ／ `basic attacks` `19 / 0 / 0`**
4. ⚠ **`balance item refs validated: 0 errors`**（⚠ **宝箱の枝が消え、⚠ 人間が `character_config.tres` を直したあとの姿**）
5. ⚠ **`[MasterDataLoader] loaded 7 entries from ...chests.json`**
6. ⚠ **前半の終わりに `chest_content_config.gd` がまだ在ること**（§2-3）

## 6. 完了条件 — **ログ / ファイル**（⚠ **設計役が読む**）

### 6-A. 定義と抽選

7. ⚠ **`chests.json` が7件。⚠ `chest_id` に重複が無いこと**
8. ⚠ **ポモドーロ4件が `rewards` だけ、⚠ 戦闘3件が `draw` だけを持つこと**
9. ⚠ **`stage_1` を1000回引いて、⚠ 宝箱が出た回数が 300 ± 60 に収まること**（⚠ **前回と同じ値。⚠ 移して壊れていない**）
10. ⚠ **その1000回で `stage_1` の当たり3種すべてが出て、⚠ よそのIDが0件であること**

### 6-B. 積む → 開ける（**2つの経路**）

11. ⚠ **`grant_chest("generic", pomodoro)` で宝箱が1個積まれ、⚠ `chest_id` が `generic`・`source` が `pomodoro` であること**
12. ⚠ **それを開けると `construction_material_1` が 4 増えること**（⚠ **`.tres` 時代は「不明な素材」が増えていた。⚠ ここが直った証拠**）
13. ⚠ **`grant_chest("stage_3", battle)` で積まれた宝箱を開けると個体（`eq_N`）ができ、⚠ `grade` が `1`（型は `int`）・`parts` 長が `8` であること**
14. ⚠ **`grant_chest("知らないID", ...)` が `false` を返し、⚠ 黄が1本出て、⚠ 宝箱が積まれないこと**
15. ⚠ **同じ `instance_id` で `open_chest()` を2回呼ぶと2回目が `false`、⚠ 個体が増えないこと**
16. ⚠ **1回の `grant_chest()` で `pending_chests_changed` が1本だけ飛ぶこと**

### 6-C. 既存が動いていないこと

17. ⚠ **`area` 3/4/4/3 ／ `mitigate` 200/300/200/120 ／ `dot_react` の `ev=react` 6件**
18. ⚠ **`parts` シナリオが `EXEC_DECORATION.md` §13-4 と同じ出力であること**
19. ⚠ **`stages.json` の `gold` / `materials` / `inventory` が前回と同じ値で入ること**
20. ⚠ **`save_slot_0.json` が書き換わらないこと**

### 6-D. ファイル

21. ⚠ **`grep -rn "chest_table" --include=*.gd --include=*.json` が0件**（⚠ **移し忘れ**）
22. ⚠ **`grep -rn "CHEST_TYPE_" --include=*.gd` が0件**（⚠ **`tests/` も含む**）
23. ⚠ **`grep -rn "chest_contents" --include=*.gd` が、⚠ 前半では `pomodoro_config.gd` の1件だけ、⚠ 後半では0件**
24. ⚠ **`ja.csv` が 427行のまま。⚠ `git diff --numstat localization/ja.csv` が空**（§0-1 の4）
25. ⚠ **`protection_*.tres` の3件に差分が無いこと**（§4）

### 6-E. ⚠ 足した検証が本当に出るか（**2箇所で壊す**）

26. ⚠ **`E118`**：⚠ **`generic` の `materials` のIDを壊して赤 ＋ `stage_1` の `draw` のIDを壊して赤**（⚠ **固定と抽選の両方の枝**）
27. ⚠ **`E120`**：⚠ **`stage_1` の `rolls=0` で赤 ＋ `stage_2` の `weight` を負にして赤**
28. ⚠ **`W19`**：⚠ **`stage_1` の当たり枠を全部空にして黄 ＋ `stage_2` でも黄**（⚠ **どちらも赤にならないこと**）
29. ⚠ **`E122`**：⚠ **`stages.json` の `chest_id` を知らない値にして赤 ＋ 別のステージでも赤**
30. ⚠ **`W20`**：⚠ **`generic` から `rewards` を消して黄 ＋ `bonus_small` でも黄**

## 7. 完了条件 — **画面**（⚠ **人間だけ**）

### 7-A. ⚠ やってもらうこと

| # | やること | いつ |
|---|---|---|
| **A-1** | ⚠ **`character_config.tres` の `level_up_material_id` を `training_material` → `training_material_1`**（⚠ **`EXEC_STAGE_DROPS.md` §11-5 の①。⚠ こちらは移設で消えないので、⚠ この回でも要る**） | ⚠ **前半のあと** |
| **A-2** | ⚠ **`pomodoro_config.tres` の `chest_contents` を空にする**（⚠ **配列の要素4件を削除して保存。⚠ 中身は `chests.json` へ移した**）。⚠ **`pomodoro_config.tres` の宝箱の素材IDは直さなくてよい**（⚠ **消すため**） | ⚠ **前半のあと** |
| **A-3** | ⚠ **`ja.csv` の再インポートは要らない**（§0-1 の4） | — |

⚠ **A-2 が終わってから後半（§3-H）に入る。⚠ 逆にすると `Parse Error` で全画面が落ちる**（§2-3）。

### 7-B. ⚠ 見るもの

| # | 見るもの |
|---|---|
| **31** | ⚠ **ポモドーロを回して宝箱を受け取り、⚠ 開けると拠点の素材欄の「木材」が増えること**（⚠ **ここが今回の目玉。⚠ これまでは「不明な素材」が増えていた**） |
| **32** | ⚠ **倉庫の宝箱タブの名前が `ふつうの宝箱` / `ボーナス宝箱（小・中・大）` のままであること**（⚠ **`ui_chest_...` がそのまま出ないこと**） |
| **33** | ⚠ **ステージを勝つと `戦利品の宝箱` が積まれること。⚠ 開けると装備が出ること** |
| **34** | ⚠ **`[全部開ける]` で、⚠ ポモドーロの宝箱と戦闘の宝箱が両方開くこと** |
| **35** | ⚠ **加護を選んでしきい値に達したとき、⚠ これまでどおり宝箱がもらえること**（⚠ **`protection_*.tres` を触っていないことの確認。⚠ ここが落ちたら §0-1 の2 の罠を踏んでいる**） |
| **36** | ⚠ **育成のレベルアップが押せて、⚠ 「修練の証」が減ってレベルが1つ上がること**（⚠ **A-1 の合図**） |

⚠ **31 と 35 が今回の目玉。⚠ 他が落ちても、⚠ この2つを先に教えてほしい。**

---

## 8. 将来コードを変えたときに見る項目

- ⚠ **`ChestScheduleEntry.chest_type` を `chest_id` に改名するとき**（⚠ **`.tres` 3ファイル7件を Inspector で入れ直す手順とセットでないと、⚠ 黙って空になる。§0-1 の2**）
- ⚠ **宝箱に `equipment` を入れるとき**（⚠ **いまは `rewards.inventory` に書けば `add_to_inventory()` が個体にする。⚠ 欄を増やさないこと**）
- ⚠ **`rolls` を2以上にしたとき**（⚠ **同じIDが2回当たって `count` が2になる。⚠ 本番は全部 `rolls: 1`**）
- ⚠ **宝箱に `gold` / `gems` / `stamina` を書くとき**（⚠ **`open_chest()` は gold と gems を読むが、⚠ `stamina` は読まない**）

---

## 9. Ziva に渡せる部分

⚠ **無い。**
⚠ **理由：⚠ `chests.json`（§3-A）は `MasterDataLoader` の読み込み（§3-B）と `grant_chest()`（§3-D）が同時に入らないと、⚠ 書いたかどうかがログにも画面にも出ない。⚠ `ja.csv` は1行も触らないので、⚠ 前回のような「JSON と `ja.csv` だけの部分」が存在しない。**

---

## 10. 終わったあとに足す宿題

- ⚠ **NEW：マスターファイルが6本目になった**（⚠ **`PROJECT_STATUS` 判断待ち2番「`summons.json` を分けたのは設計役の判断」に1本足す形**）
- ⚠ **NEW：`ChestScheduleEntry.chest_type` だけ語が揃っていない**（§8）
- ⚠ **NEW：`chests.json` の宝箱の中身と `weight` が全部「勘」**（⚠ **移しただけで1つも測っていない**）
- ⚠ **NEW：戦闘の宝箱が3ステージとも30%で同じ**（⚠ **`EXEC_STAGE_DROPS.md` からの持ち越し**）
- ⚠ **NEW：`open_chest()` が `stamina` を読まない**
- ⚠ **NEW：`E121` の守備範囲が4箇所に減った**（⚠ **宝箱が JSON へ移ったため。⚠ 残りは `character` / `initial_state` / `research` / `shop`**）
