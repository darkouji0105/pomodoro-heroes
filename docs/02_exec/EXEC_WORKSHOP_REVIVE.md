# EXEC_WORKSHOP_REVIVE — 作業場の復活（装飾のランダム製作）

**段階11の後半**（`PLAN_IMPLEMENTATION.md` 3章）／ **仕様は `GAME_DESIGN.md` 9-3**／ 指示元は `NEXT_STEPS.md` §1。
**前半（廃止）は `EXEC_WORKSHOP_RETIRE.md`。⚠ 決め1（`_sync_recipes_from_master()` の早期 return を外した）は戻さない。**

---

## 0. 人間の決定（2026-08-25・着手前に確認済み）

| # | 聞いたこと | 決まったこと |
|---|---|---|
| **1** | 作業場で何を作れるようにするか | ⚠ **装飾のランダム製作だけ入れる。⚠ 中間素材（研究用素材）は入れない** |
| **2** | どのステージのクリアで開くか | ⚠ **`stage_3`**（`stages.json` の `unlocks` に1行） |
| **3** | 研究の作業場枝（決定9）を今回いっしょに足すか | ⚠ **足す。⚠ 製作時間の短縮とキュー本数の2件だけ**（変換レートは変換が廃止のため入れない） |

### 0-1. ⚠ 決定1で分かれた「仕様との差」（**設計役が見つけて報告した**）

⚠ **`GAME_DESIGN.md` 9-3 のデモ範囲は「中間素材の製作」と「装飾のランダム製作」の2つ。⚠ 今回は後者だけを入れる。**

理由は、前者が **5系統目の素材**を必要とするため。`GAME_DESIGN.md:84` の資源表は
「**研究用素材** ← 作業場（中間素材として製作）／→ 研究ボードの解放」と書いており、
これは `NEXT_STEPS` §1-3 の守り「**素材IDは `<系統>_material_<1..4>` で固定。新しい素材を作らない**」と正面から食い違う。
⚠ **人間に聞き、「装飾のくじだけ」を選んだ。⚠ 中間素材は宿題に落とす**（§6-1）。

> ⚠ **`NEXT_STEPS` §2-2 に従い、`GAME_DESIGN` / `PLAN_IMPLEMENTATION` / `PROJECT_STATUS` を `grep` して
> 「置き換えろ」が無いことを確かめた。⚠ 見つかったのがこの1件で、⚠ 仕様側を採らずに人間に聞いた。**

---

## 1. 何をするか

| # | 対象 | 変更 |
|---|---|---|
| **A** | `resources/balance/master/recipes.json` | ⚠ **装飾のくじを3件**（`draw` を持つ新しい形）。0件 → 3件 |
| **B** | `autoload/game_manager.gd` | ⚠ **`draw` を持つレシピの受け入れ**（正規化・開始・受け取り）／ ⚠ **抽選の本体を `_roll_weighted_table()` に切り出す**（§2 決め2）／ ⚠ **研究の作業場枝の2本**（`get_research_craft_slot_bonus()` / `get_research_craft_speed_percent()`） |
| **C** | `scripts/utils/state_keys.gd` | ⚠ `EFFECT_CRAFT_SPEED_BONUS` / `EFFECT_CRAFT_SLOT_BONUS` の2定数 |
| **D** | `scripts/systems/master_data_loader.gd` | ⚠ **`E129`**（`recipes.json` の `draw` の形）／ ⚠ **`E118` に `draw.entries` の枝**（番号は増やさない） |
| **E** | `resources/balance/master/research.json` | ⚠ **ボード2に `category: "workshop"` の2件**。18 → **20ノード**（ボード2は 6 → 8件） |
| **F** | `resources/balance/master/stages.json` | ⚠ `stage_3` の `unlocks` に `"workshop"` を1つ |
| **G** | `scenes/guild/guild_screen.gd` / `.tscn` | ⚠ `GUILD_SCENES` と `_nav_buttons` に `workshop` を戻す ／ ⚠ `WorkshopButton` の `visible = false` を外す |
| **H** | `scenes/guild/workshop_screen.gd` | ⚠ `draw` レシピの表示（「装飾素材 ×12 → 装飾（ランダム）」） |
| **I** | `scenes/guild/research_screen.gd` | ⚠ `_effect_text()` に2枝 |
| **J** | `localization/ja.csv` | ⚠ **6行追記**（§3-3） |
| **K** | `tests/debug_boot.gd` | ⚠ **`scenario=workshop`（30本目）**／ ⚠ `LAYOUT_SCENES` に作業場 ／ ⚠ `_report_unlock()` の「workshop は開かない」を**2箇所**直す ／ ⚠ 再インポートの合図キーを差し替え |
| **L** | `docs/` | `NEXT_STEPS` / `PLAN_IMPLEMENTATION` 3章の状態列 / `PROJECT_STATUS` のハッシュ表と宿題 |

---

## 2. ⚠ 僕が自分で決めたもの（**人間が見ていない決め**）

> ⚠ **この章がこのEXECの本体。⚠ §0 の3件以外は全部ここ。⚠ 違うと思ったら差し戻してよい。**

### 決め1（**大きい**）：レシピは「固定の `outputs`」と「`draw`（抽選）」のどちらかを持つ

`recipes.json` のレシピに `draw` という欄を足す。**形は `chests.json` の `draw` と同じ**（`rolls` / `entries[{item_id, weight, count}]`）。

```json
{
  "recipe_id": "craft_part_1",
  "duration_sec": 1800,
  "inputs": [ { "item_id": "decor_material_1", "count": 12 } ],
  "outputs": [],
  "draw": { "rolls": 1, "entries": [ { "item_id": "part_gem_hp_1", "weight": 10 }, ... ] },
  "unlocked_by_default": true,
  "sort_order": 1
}
```

- ⚠ **`inputs` は必ず要る。⚠ `outputs` と `draw` は「どちらか片方が非空」なら妥当**（両方空は `E129` で赤）
- ⚠ **両方あってもよい**（固定分＋抽選分）。今回のデータは使わないが、弾く理由が無いので弾かない
- ⚠ **抽選は受け取り（`collect_craft()`）のときに引く。⚠ 開始のときではない。** 開始で引くと、待っている間に結果が確定していることになり、`recipes.json` を直しても走行中のものに反映されない（`outputs` を受け取り時に引き直しているのと同じ理由＝`EXEC_GUILD_WORKSHOP.md` §2-5）

**代償**：`crafting_queue` の `output_item_id` が `draw` レシピでは `""` になる。
⚠ **`output_item_id` と `recipe_type` は表示にも判定にも使われていないことを `grep` で確認済み**（書いているのは `start_craft()` の1箇所だけ）。**キーは消さない**（セーブの形を変えないため）。

### 決め2（**大きい**）：抽選の本体を `_roll_weighted_table()` に切り出す

⚠ **`_roll_chest_draw()` をそのまま呼んではいけない。** あの中に `get_research_chest_draw_bonus()` が入っているため、
**研究の「宝箱」枝が作業場のくじにも黙って乗る**（`NEXT_STEPS` §0-3 は「乗る先は `rolls` 1箇所だけ」と書いている）。

```
_roll_weighted_table(entries, rolls) -> {item_id: count}   ← 抽選の本体（新設）
    ↑                          ↑
_roll_chest_draw(draw_def)     _roll_recipe_draw(draw_def)
  rolls + 宝箱枝のボーナス        rolls をそのまま
```

⚠ **`NEXT_STEPS` §2-6「同じ形の判定が散っていたら1本に寄せる」に従った形。⚠ 抽選の本体は引き続き1本。**
⚠ **`_roll_chest_draw()` の外から見た振る舞いは変えない**（宝箱の分布は今までどおり）。

### 決め3：作業場のくじに「ハズレ」を作らない

`chests.json` の `draw` は `item_id: ""` をハズレとして許している。
⚠ **`recipes.json` の `draw` では `""` を赤にする（`E129`）。** 素材と時間を払って何も出ないのは、宝箱のハズレとは意味が違うため。

### 決め4：ルーンはくじに入れない

`item_type: "part"` は61件あるが、⚠ **25件はルーン**（`GAME_DESIGN` 7-7「ルーンだけは別系統」）。
⚠ **くじに入れるのは 宝石12・護符8・紋章16 の36件だけ。** ルーンの本番入手経路は宿題8のまま。

### 決め5：レシピは3件。段階1〜3の装飾素材を入口にする

| `recipe_id` | 投入 | 時間 | 出る等級の重み（1段につき9件・各件同じ重み） |
|---|---|---|---|
| `craft_part_1` | `decor_material_1` ×12 | 30分 | 段階1 = 10 ／ 段階2 = 2 |
| `craft_part_2` | `decor_material_2` ×12 | 90分 | 段階1 = 3 ／ 段階2 = 10 ／ 段階3 = 2 |
| `craft_part_3` | `decor_material_3` ×12 | 3時間 | 段階2 = 3 ／ 段階3 = 10 ／ 段階4 = 2 |

⚠ **`decor_material_4` を使うレシピは作らない。** `_4` は月替わりショップだけの入手で、
⚠ **段階12（バランス実測）で入手量を測る前にレートを決めたくないため**（宿題6-1）。
⚠ **3件とも `unlocked_by_default: true`。** レシピの解放条件は今回作らない（作業場そのものが `stage_3` で開く）。

⚠ **数値（12個・30分/90分/3時間・重み 10/3/2）は全部「勘」。⚠ 宿題22に足す。**

### 決め6：研究の作業場枝は2件・ボード2の末尾に置く

| `node_id` | `category` | `effect_type` | 値 | 前提 | コスト |
|---|---|---|---|---|---|
| `res2_craft_1` | `workshop` | `craft_speed_bonus` | 20（**製作時間 -20%**） | `res2_stat_hp_1` | `construction_material_3` ×40 |
| `res2_craft_2` | `workshop` | `craft_slot_bonus` | 1（**同時製作 +1**） | `res2_craft_1` | `construction_material_4` ×10 |

- ⚠ **`level_cap_unlock` を1件も足さないので `E127`（20 ＋ 8件×10 ＝ 100）は動かない**
- ⚠ **前提は同じボード2の中。`E128` に触れない**
- ⚠ **`milestone` は付けない**（ボード2の ★ / ★★ は `res2_stat_3` / `res2_stat_4` のまま）
- ⚠ **研究画面に `if` を1行も足さない。⚠ 見出しは `ja.csv` に `ui_research_category_workshop` を1行足すだけで出る**（段階10で作った器）
- ⚠ **`_effect_text()` にだけ2枝が要る**（効果の文言は画面が組み立てているため）

### 決め7：製作時間の短縮は「開始のとき」に確定する

`start_craft()` が `duration_sec` を計算するときに %短縮を掛ける。
⚠ **走行中のものには効かない**（開始時点の所要時間をコピーして持つ既存の作りをそのまま使う）。
⚠ **床は `maxi(1, ...)`。** 0秒や負を作らない。⚠ **1 は「0にしない」ための床であって、バランス数値ではない**（`.tres` に置かない）。

### 決め8：`E129` を新しく1本足す（`E118` は番号を増やさない）

| 番号 | 見るもの |
|---|---|
| ⚠ **`E129`** | `recipes.json`：⚠ `outputs` と `draw` が**両方空** ／ ⚠ `draw.entries` が空 ／ ⚠ `draw.entries[].item_id` が `""`（決め3）／ ⚠ `weight` の合計が0以下 |
| **`E118`**（既存） | ⚠ `draw.entries[].item_id` が `items.json` に無い ← **枝を足すだけ。番号は増やさない** |

⚠ **`NEXT_STEPS` §1-3 の指示どおり、⚠ `E121` / `E118` の既存の枝を先に見てから足した。**

### 決め9：`scenario=workshop` は**赤を2本**出すのが正常

`E129` を2箇所で壊して確かめる（`scenario=unlock` の `(c)` と同じ形）。
⚠ **壊すのは `MasterDataLoader` のメモリ上のキャッシュだけ。⚠ `recipes.json` は触らない**（`git diff` が最初から空のまま）。

→ ⚠ **赤の平常値が変わる：`unlock` が1本 ＋ `workshop` が2本。⚠ 他の28本は0本。**

### 決め10：Ziva に渡せる部分は**無い**（分割しない）

`recipes.json` の3件は **`draw` という新しい欄**を使うため、`game_manager.gd` と `master_data_loader.gd` の変更と
**同じ回に入らないと `E129` で赤になるか、黙って落ちる**（`_normalized_recipe()` が `outputs` 空で弾く）。
`ja.csv` の6行も、研究画面の2枝と作業場画面の1行が同時に要る。**`EXEC_WORKSHOP_RETIRE` 決め6と同じ判断。**

### 決め11：`workshop_screen.gd` は `draw` を「装飾（ランダム）」の1語で出す

`_recipe_text()` は `inputs → outputs` を組み立てている。⚠ **`draw` のときは右辺を `tr("ui_guild_workshop_draw")` にする。**
⚠ **抽選の中身（36件）を画面に出さない。** 出すと行が縦に伸びて `ScrollContainer` の外へ出るうえ、
⚠ **「種類も等級も両方ランダム」という仕様（9-3）の見え方が壊れる。**

### 決め12：`ja.csv` の再インポートの合図キーを `ui_research_category_workshop` に差し替える

⚠ **ズレ37。⚠ 前の回のキー（`ui_research_board`）を見たままだと、今回足した6行が未インポートでも「済んでいる」と出る。**

---

## 3. データ

### 3-1. `recipes.json`（**新規3件**）

⚠ **形は `{ "recipes": [ ... ] }` の配列**（研究やアイテムと違う）。⚠ **インデントはトップレベルだけ半角スペース2つ、中はタブ**（既存の `stages.json` / `chests.json` と同じ）。

各レシピの `draw.entries` は、その段階の**9件を全部**書く（宝石3・護符2・紋章4）。

| 段階 | 9件 |
|---|---|
| 1 | `part_gem_hp_1` `part_gem_atk_1` `part_gem_mag_1` `part_charm_def_1` `part_charm_mdef_1` `part_emblem_crit_rate_1` `part_emblem_crit_dmg_1` `part_emblem_atkspd_1` `part_emblem_haste_1` |
| 2〜4 | 同じ並びで末尾の数字だけ差し替え |

⚠ **ルーン（`part_rune_*`）は1件も入れない**（決め4）。

### 3-2. `research.json`（**新規2件**）… 決め6の表のとおり。`sort_order` は 7 / 8。

### 3-3. `ja.csv`（**6行追記**）

```
ui_research_category_workshop,作業場
ui_research_b2_craft_1,製作手順の見直し
ui_research_b2_craft_2,作業台の増設
ui_research_effect_craft_speed,製作時間 -%d%%
ui_research_effect_craft_slot,同時製作 +%d
ui_guild_workshop_draw,装飾（ランダム）
```

⚠ **`%%` は `tr()` が返したあと `% value` で `%` 1つになる。⚠ 1つで書くと落ちる。**
⚠ **UTF-8（BOMなし・LF）。⚠ 既存の `ui_guild_workshop_*` 12行は1行も触らない**（`EXEC_WORKSHOP_RETIRE` 決め5でそのために残してある）。

---

## 4. ⚠ 先に潰す落ち（`NEXT_STEPS` §1-3）

| # | 予想 | 対応 |
|---|---|---|
| 1 | `recipes.json` の形が配列 | ✅ `_index_by()` を通る。**形は変えない** |
| 2 | `_sync_recipes_from_master()` の早期 return | ✅ **戻さない**（`EXEC_WORKSHOP_RETIRE` 決め1）。3件になるので `-> 3 recipes (unlocked=3, skipped=0)` になる |
| 3 | 素材IDは固定。新しい素材を作らない | ✅ **1件も作らない**（決定1。§0-1） |
| 4 | 装飾を作るなら `add_to_inventory()` を通す | ✅ `collect_craft()` → `_grant_item()` → `storage == "inventory"` → `add_to_inventory()`。⚠ **新しい入手経路を作らない** |
| 5 | `E121` / `E118` に既にレシピの枝がある | ✅ **見てから足した**（決め8） |
| 6 | `LAYOUT_SCENES` に作業場が無い | ✅ 1行足す（K） |
| 7 | ボタンが1つ増える＝「5個前提の並びに6個目」 | ⚠ **ギルドは `CenterContainer/Layout`（`VBoxContainer`）＝縦に伸びる。⚠ はみ出すなら横ではなく縦。⚠ `scenario=layout` が `guild_screen.tscn` を測っているので数字で出る**（§7-A） |
| 8 | `crafting_queue` の時刻が JSON から `float` で戻る | ✅ `_normalize_crafting_queue()` が `int()` に戻す。**触らない** |

### 4-1. ⚠ 予想に無かったが見つけた落ち

- ⚠ **`_report_unlock()` が「workshop は `unlocks` に1度も出てこない」を2箇所で正解として出している**
  （`tests/debug_boot.gd` の「最初から開く3つ ＋ workshop だけが正解」と「workshop は開いたか -> false が正解」）。
  ⚠ **`stages.json` を直すとこの2行が嘘になる。⚠ 同じ回で直す**（K）
- ⚠ **`_roll_chest_draw()` に研究の宝箱枝が入っている**（決め2）。⚠ **そのまま呼ぶと作業場のくじに黙って乗る**

---

## 5. 完了条件

### §0 事前チェック（**設計役・人間に渡す前に終わっている**）

- ⚠ **全シナリオ（`training` を除く29本）をヘッドレスで1本ずつ回す。⚠ 14〜15本ずつ2回に分ける**
- ⚠ **赤は `unlock` の1本 ＋ `workshop` の2本だけ**（決め9）。⚠ **黄は 1本（`skill_dbg_dot_odd`）。⚠ `drops` と `parts` はもう1本ずつ多い**
- ⚠ **`--check-only --script` で `game_manager.gd` / `master_data_loader.gd` / `guild_screen.gd` / `workshop_screen.gd` / `research_screen.gd` の `Parse Error` が0件**
- ⚠ **編集直後に `grep -n` で当たったことを確認**（`CLAUDE.md` 2番）
- ⚠ **回している間は `.gd` / `.tscn` / `.json` / `.csv` を触らない**（`.md` はよい）

### A. ログ（**設計役が読む**）

| # | 見るもの |
|---|---|
| **A-1** | `[GameManager] _sync_recipes_from_master() -> 3 recipes (unlocked=3, skipped=0)` |
| **A-2** | `[MasterDataLoader] loaded 3 entries from res://resources/balance/master/recipes.json` |
| **A-3** | `_sync_research_tree_from_master() -> 20 nodes` |
| **A-4** | `level cap validated: 20 + 80 (8 nodes) = 100, 0 errors`（⚠ **`E127` が変わっていない**） |
| **A-5** | `balance item refs validated: 0 errors`（⚠ `E121`）／ `items validated: 89 entries, 0 errors`（⚠ **素材を1件も足していない**） |
| **A-6** | ⚠ `scenario=workshop`：レシピ3件が出て、⚠ **`craft_part_1` の1000回の分布が「段階1が8割前後・段階2が2割前後・段階3以上が0件」** |
| **A-7** | ⚠ `scenario=workshop`：⚠ **研究の宝箱枝を解放しても、作業場の `rolls` が増えない**（決め2の分離が効いている） |
| **A-8** | ⚠ `scenario=workshop`：⚠ `res2_craft_1` 解放後の `duration_sec` が **1800 → 1440**、⚠ `res2_craft_2` 解放後の `get_max_queue_slots()` が **1 → 2** |
| **A-9** | ⚠ `scenario=workshop`：⚠ **壊した2箇所で `E129` の赤が1本ずつ出て、戻すと出ない** |
| **A-10** | ⚠ `scenario=unlock`：⚠ **`stage_3 -> [research, shop, rune, workshop]`**／⚠ **「`unlocks` に1度も出てこないもの」が最初から開く3つだけ** |
| **A-11** | ⚠ `scenario=passives`：`ja.csv の再インポート:` の行が **`ui_research_category_workshop` を見ている**（決め12） |
| **A-12** | ⚠ `scenario=layout`：`guild_screen.tscn` と `workshop_screen.tscn` が**縦にも横にもはみ出さない**（基準 1280 x 720） |

### B. ファイル（**設計役が読む**）

| # | 見るもの |
|---|---|
| **B-1** | `recipes.json` が JSON として妥当（`python -m json.tool`）。`recipe_id` が3件 |
| **B-2** | `grep -c "part_rune_" resources/balance/master/recipes.json` が **0**（決め4） |
| **B-3** | `grep -c '"item_id": ""' resources/balance/master/recipes.json` が **0**（決め3） |
| **B-4** | `research.json` のノードが **20件**。`category: "workshop"` が **2件** |
| **B-5** | `localization/ja.csv` の CR が **0**（`python -c "print(open('localization/ja.csv','rb').read().count(b'\x0d'))"`）。⚠ BOM が付いていない |
| **B-6** | `grep -n '"workshop"' scenes/guild/guild_screen.gd` が **0件のまま**（⚠ `GameStateKeys.SCREEN_WORKSHOP` で書く。文字列リテラルを書かない） |
| **B-7** | `guild_screen.tscn` の `WorkshopButton` ブロックに `visible = false` が**無い** |
| **B-8** | ⚠ **セーブに `"duration_sec": 1800.0` のような `.0` が書かれていない**（⚠ 人間が §C を通したあと `save_slot_0.json` を読む。⚠ `CLAUDE.md` 3番） |

### C. 画面（**人間だけ**）

⚠ **観測できる合図で書く。時間で書かない。**

| # | すること | 見るもの |
|---|---|---|
| **C-1** | ⚠ **新規開始**で `stage_3` をクリアするまで進める（⚠ 面倒なら既存セーブでよい。その場合は C-2 から） | ⚠ **`stage_3` をクリアした瞬間に、ギルドのボタンが5個から6個になる**（画面を出入りしない） |
| **C-2** | 拠点 → ギルド | ⚠ **ボタンが6個**（倉庫／ショップ／育成／研究／**作業場**／戻る）。⚠ **一番下のボタンが画面の外に出ていない** |
| **C-3** | ギルド → 作業場 | ⚠ **「製作中のものはありません」と、⚠ レシピが3行。⚠ 各行が「装飾素材 ×12 → 装飾（ランダム）」の形。⚠ `ui_` で始まるキー名が生で出ていない** |
| **C-4** | ⚠ **F4 →「素材を全種類」** を押してから作業場を開く | ⚠ **3行とも「作る」が押せる**（灰色でない） |
| **C-5** | 一番上のレシピの「作る」を押す | ⚠ **「製作を開始しました」／⚠ 製作中に1行増えて残り時間が1秒ずつ減る／⚠ 3行とも「作る」が灰色になる**（キューが1本のため） |
| **C-6** | そのまま画面を見ている | ⚠ **行が二重に並ばない**（`remove_child` → `queue_free` の形） |
| **C-7** | 作業場 → ギルド → 作業場 と往復する | ⚠ **残り時間が続きから減っている。⚠ 製作中の行が2行になっていない** |
| **C-8** | ⚠ **アプリを閉じて開き直す**（セーブしてから） | ⚠ **製作中の行が残っていて、⚠ 閉じている間の時間だけ減っている** |
| **C-9** | ⚠ **F4 →「製作をすぐ完了させる」**（⚠ **2026-08-25に足した。⚠ 30分待たないため**） | ⚠ **残り時間が「完成」になり、⚠ 「受け取る」が押せるようになる。⚠ F4 の情報欄が `製作 1 / 1本（完成 1）` になる** |
| **C-10** | ⚠ **（旧）待たずに確かめる別の手**：F4 →「セーブする」→ 端末の時計を進めて開き直す | ⚠ **C-9 のボタンで足りるので、⚠ 普段はこちらを使わない** |
| **C-11** | 「受け取る」を押す | ⚠ **「受け取りました」／⚠ 製作中の行が消える／⚠ 倉庫の持ち物に装飾が1個増えている**（⚠ **何が出るかは毎回変わる**） |
| **C-12** | 同じレシピを2回以上回す | ⚠ **出るものが毎回同じではない**（種類も等級も変わる） |
| **C-13** | 研究を開く | ⚠ **ボード1が12件のまま。⚠ 「作業場」の見出しはボード2に入るまで出ない** |
| **C-14** | ⚠ **F4 →「研究を全部解放」** → 研究を開く | ⚠ **ボード2に「戦闘」「宝箱」「作業場」の3つの見出しが出て、⚠ 「作業場」の下が2行。⚠ 効果が「製作時間 -20%」「同時製作 +1」と読める**（⚠ **`%d` や `？` になっていない**） |
| **C-15** | そのまま作業場を開く | ⚠ **レシピの時間が 30:00 ではなく 24:00 になっている（-20%）／⚠ 1本作り始めても、⚠ 残り2行の「作る」がまだ押せる**（キューが2本） |
| **C-16** | ⚠ **ここで1回セーブしてもらう** | ⚠ **設計役が `save_slot_0.json` を読む（B-8）** |

> ⚠ **将来コードを変えたときに見る項目**（UIから到達できないので人間の確認項目にしない）：
> `start_craft("craft_part_1")` をキューが満杯のときに呼ぶと `false (queue full: N/N)`／
> `collect_craft()` を完了前に呼ぶと `false (not completed)`／
> `recipes.json` から `craft_part_1` を消すと走行中のキューが `_normalize_crafting_queue()` で黄1本とともに落ちる。

---

## 6. `PROJECT_STATUS.md` へ足す宿題

1. ⚠ **`GAME_DESIGN` 9-3 の「中間素材の製作」が入っていない**（決定1）。⚠ **`GAME_DESIGN.md:84` の資源表は「研究用素材 ← 作業場」と書いているが、⚠ 5系統目の素材が要る。⚠ 段階12（バランス実測）で `construction_material_4` の入手量を測ってから、⚠ 新設するか研究のコストを組み替えるかを決める**
2. ⚠ **`decor_material_4` を使うレシピが無い**（決め5）。⚠ 月替わりショップだけの入手のため、段階12の後に判断する
3. ⚠ **くじの数値が全部「勘」**（投入12個・30分/90分/3時間・重み 10/3/2）→ ⚠ **宿題22に合流**
4. ⚠ **`crafting_queue` の `output_item_id` / `recipe_type` が `draw` レシピでは `""` になる**（決め1）。⚠ **どちらも誰も読んでいないので、⚠ 次にセーブの形を触る回で消すか判断する**
5. ⚠ **作業場のアップグレード（`GAME_DESIGN` 9-3「建築素材で作業場自体をアップグレード」）が無い。** ⚠ **キュー本数は研究の枝で伸ばす形にした**（決め6）
6. ⚠ **掘削（`GAME_DESIGN` 9-3-1）はデモ範囲外のまま**
7. ⚠ **`_sync_recipes_from_master()` の「読めない」保険は `MasterDataLoader` 側の赤だけのまま**（`EXEC_WORKSHOP_RETIRE` 宿題3の結論）。⚠ **レシピが3件になったので、⚠ 0件に戻ったら異常だと分かる。⚠ ただし検証は足していない**
8. ⚠ **`guild_screen.gd` の `WORKSHOP_PATH` が未使用だった宿題は解消**（`EXEC_WORKSHOP_RETIRE` 宿題4を消す）

---

## 7. 変えないもの

⚠ **`NEXT_STEPS` §2-2 に従い、`GAME_DESIGN` / `PLAN_IMPLEMENTATION` / `PROJECT_STATUS` を `grep` して
「置き換えろ」が無いことを確認済み。⚠ 見つかった1件は §0-1 に書き、人間に聞いた。**

- ⚠ **`_sync_recipes_from_master()` の早期 return を戻さない**（`EXEC_WORKSHOP_RETIRE` 決め1）
- ⚠ **`_roll_chest_draw()` の外から見た振る舞い**（宝箱の分布・`get_research_chest_draw_bonus()` の乗り先）
- ⚠ **素材16件。`<系統>_material_<1..4>`。⚠ 1件も足さない**
- ⚠ **`base_level_cap`（20）＋ 全 `level_cap_unlock`（8件×10）＝ 100**（`E127`）
- ⚠ **既存のノードID・レシピID・`ChestScheduleEntry.chest_type` の `@export` 名**
- ⚠ **`parts` は長さ8の固定配列**（`null` 込み・位置が枠を表す）
- ⚠ **`GameStateKeys.CRAFTING_QUEUE` / `RECIPES_UNLOCKED` の形**（⚠ **状態にキーを1つも足さない**）
- ⚠ **`localization/ja.csv` の既存 `ui_guild_workshop_*` 12行**
- ⚠ **`resources/balance/workshop_config.gd` / `.tres`**（⚠ `.tres` は設計役には直せない。⚠ `max_queue_slots` は既定値1のまま）
- ⚠ **`tests/debug_boot.gd` の既存シナリオ29本**（⚠ 消さない。⚠ `workshop` を足して30本）

---

## 8. 実施結果（2026-08-25・設計役）

### 8-1. §0 事前チェック … **通った**

⚠ **全29シナリオ（`training` を除く）をヘッドレスで1本ずつ回した。**

| | 結果 |
|---|---|
| ⚠ **赤** | ⚠ **`unlock` 1本（`E125`・意図）／ `workshop` 2本（`E129`・意図）。⚠ 他の27本は0本** |
| ⚠ **黄** | ⚠ **全本 `skill_dbg_dot_odd` の1本。⚠ `parts` と `drops` はもう1本ずつ多い**（どちらも意図） |
| `--check-only --script` | ⚠ **`Parse Error` は0件**（⚠ 出るのは `Identifier not found: Balance / GameManager / SceneManager` だけ＝Autoload が読まれないため。⚠ この形は前からそう） |

### 8-2. ログの完了条件（§5-A）… **A-1 〜 A-12 とも通った**

| # | 取れたもの |
|---|---|
| A-1 | `_sync_recipes_from_master() -> 3 recipes (unlocked=3, skipped=0)` |
| A-2 | `loaded 3 entries from res://resources/balance/master/recipes.json` |
| A-3 | `_sync_research_tree_from_master() -> 20 nodes (unlocked=0)` |
| A-4 | `level cap validated: 20 + 80 (8 nodes) = 100, 0 errors` |
| A-5 | `balance item refs validated: 0 errors` ／ `items validated: 89 entries, 0 errors` |
| A-6 | ⚠ **1000回の分布**：`craft_part_1` 段階1 **839** / 段階2 **161**／`craft_part_2` **203 / 666 / 131**／`craft_part_3` **0 / 199 / 654 / 147**。⚠ **ルーンは3件とも0件** |
| A-7 | ⚠ **研究を全部解放（宝箱の抽選 +2）した状態で 200回引いて出た件数が 200**（⚠ 宝箱の枝が作業場に乗っていない＝決め2が効いている） |
| A-8 | ⚠ **`duration=1440s`**（1800 の -20%）／ ⚠ **`queue=2/2`**（1本 → 2本） |
| A-9 | ⚠ **壊した2箇所で `E129` が1本ずつ。⚠ 戻して「レシピ 3 件 / 抽選 18 件」に戻ることを再実行で確認** |
| A-10 | `stage_3 -> ["research", "shop", "rune", "workshop"]` ／ `unlocks に1度も出てこないもの: ["adventure_select", "settings", "scenario"]` ／ `workshop は開いたか -> true` |
| A-11 | `ja.csv の再インポート: まだ`（⚠ **`ui_research_category_workshop` を見ている**。⚠ **人間の再インポート待ち**） |
| A-12 | `guild_screen.tscn 最小 104 x 312` ／ `workshop_screen.tscn 最小 120 x 207`（⚠ **基準 1280 x 720。どちらもはみ出さない**） |

⚠ **受け取りのログ**：`add_to_inventory('part_charm_mdef_1', 1, type='part') -> count=1` →
`collect_craft(...) -> true (part_charm_mdef_1 x1 (draw), queue=0)`。⚠ **装飾の所持数 0 → 1。⚠ `output_item_id` は空。**

### 8-3. ファイルの完了条件（§5-B）… **B-1 〜 B-7 は通った。⚠ B-8 は人間待ち**

`recipes.json` は JSON として妥当・`recipe_id` 3件・`part_rune_` 0件・`item_id: ""` 0件。
`research.json` は 20ノード・`category: "workshop"` 2件。`ja.csv` は CR 0・BOM なし。
`guild_screen.gd` に文字列リテラルの `"workshop"` は0件（`GameStateKeys.SCREEN_WORKSHOP` で書いた）。
`guild_screen.tscn` の `WorkshopButton` に `visible = false` は無い。
⚠ **B-8（セーブに `.0` が無いこと）は §5-C の C-16 のあと。**

### 8-4. ⚠ 予定に無かった修正2件（**`scenario=layout` が数字で出したもの**）

| # | 見つかったもの | 直したこと |
|---|---|---|
| **1** | ⚠ **`workshop_screen.tscn` が横に +344 はみ出していた**（最小 1624 x 180）。⚠ **原因は `MaterialLabel`。素材16件を1行に連結するため、ScrollContainer の外で横に伸びていた**（⚠ **廃止前からあった穴。⚠ 到達できなかったので誰も踏んでいない**） | ⚠ **`MaterialLabel` に `autowrap_mode = 3` を1行**。→ 最小 **120 x 207** |
| **2** | ⚠ **`guild_screen.tscn` の測定が「104 x 312」ではなく「72 x 72」だった。⚠ 開いた直後は段階解放で5個とも `visible = false` のため、⚠ 見出しと戻るだけを測っていた**（⚠ **「5個前提の並びに6個目」を見るための道具が、その姿を測れていなかった**） | ⚠ **`LAYOUT_SCENE_SHOW` に `guild_screen.tscn` の5行**。→ 最小 **104 x 312**（⚠ **6個並べても縦 312 で収まる**） |

⚠ **2件目は `NEXT_STEPS` §4「測る道具が『0』や『全部同じ数字』を返したら、まずその道具を疑う」の同じ形。**

### 8-5. ⚠ ドキュメントのズレ（**報告のみ・勝手に直さない**）

`NEXT_STEPS` §2-1 の通し番号の続き。**前回までで37件、未報告2件（34・37）。今回1件。**

#### ズレ38 — `docs/GAME_DESIGN.md` 9-1（**今回の領域**）

> **作業場** ｜ 製作時間の短縮、キュー本数、**変換レート**

⚠ **「変換レート」は成立しない。⚠ 同じ `GAME_DESIGN.md` の 9-3 と 2章（`:104`）が「素材の変換は廃止。ショップに一本化」と書いているため、⚠ 上げるレートが存在しない。**

→ ⚠ **今回は研究の作業場枝を「製作時間の短縮」「キュー本数」の2件だけにした（決め6）。⚠ 9-1 の表の3つ目は消すべきだが、⚠ `GAME_DESIGN.md` は勝手に書き換えない。**

### 8-6. ⚠ 画面の確認の結果（2026-08-25・人間）

⚠ **§5-C のうち、⚠ 「製作が完成するのを待つ」に依存する項目以外は全部通った**（人間の報告）。
⚠ **`ja.csv` の再インポートも済んでいる**（⚠ **C-3 と C-14 が通ったことがその証拠。⚠ `.translation` はキーがハッシュで入るため、⚠ 設計役はファイルからは確かめられない**）。

⚠ **通らなかったのは「30分待てない」ことが理由の項目だけ**（C-9 / C-11 / C-12 と、⚠ C-15 の受け取り）。

→ ⚠ **`F4` に「製作をすぐ完了させる」を1つ足した**（`tests/debug_overlay.gd`）。

| | |
|---|---|
| すること | ⚠ **製作中のものを全部「完成」にする。⚠ 受け取りはしない**（⚠ **「受け取る」を押すのは人間。⚠ そこが確認したい所のため**） |
| ⚠ **`_state` を直接書く唯一の例外** | ⚠ **書き換えるのは `started_at` だけ。⚠ 資源もアイテムも個体も作らないので `add_to_inventory()` の関所を迂回しない。⚠ 時刻を戻す公開関数が無い。⚠ `debug_boot.gd` の `_rewind_craft_queue()` と同じ形** |
| ⚠ **再描画** | ⚠ **`refresh_crafting_queue_if_needed()` に任せる。⚠ `crafting_queue_changed` をここで発火しない**（二重発火になる） |
| ⚠ **見える合図** | ⚠ **`F4` の情報欄に `製作 N / M本（完成 K）` の1行を足した。⚠ ログを見ずに効いたことが分かる** |

⚠ **リリース前に消すものの一覧（宿題35）は `tests/debug_overlay` をファイルごと挙げているので、⚠ 新しく足す項目は無い。**
