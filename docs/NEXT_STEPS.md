# 次にやること：**⑫-c 残った穴の器を決める（出口と入口）**

**このファイルは「次の1タスク」だけを書く。** 終わったら次のタスクの内容に書き換える。全体の状況は `PROJECT_STATUS.md`、ルールは `AGENTS.md` と `CLAUDE.md`、**ゲームの中身は `GAME_DESIGN.md`**、**順番の台帳は `docs/PLAN_IMPLEMENTATION.md` 3章**。

**このファイルだけ読めば着手できるように書いてある。** 過去のタスクを知らない前提で読んでよい。

⚠ **段階12（バランス実測）の前半＝測る・後半＝入れる は終わっている。⚠ これは「数値では直らなかった3件」を器の側で片付ける回。**
⚠ **入力は `docs/02_exec/EXEC_BALANCE_TUNE.md` §6（宿題52〜56）と §9-2（前と後の数字）。⚠ 先に読むこと。**
⚠ **仕様の正は `GAME_DESIGN.md`。⚠ 人間の決定はまだ無い。⚠ §1-2 を先に聞くこと。**

---

## 0. ⚠ 前のタスク（**2026-08-25・段階12の後半＝測った数値を入れる**）

**指示書は `docs/02_exec/EXEC_BALANCE_TUNE.md`。⚠ コミットは `26beb3c`。**
⚠ **ログとファイルの項目は通っている**（⚠ **30本を1本ずつ回した**）。
⚠ **画面の項目は4つ。⚠ ⚠ まだ人間が見ていない**（§0-2）。

### 0-0. ⚠ 何が入ったか（**4ファイル**）

- ⚠ **`character_config.gd` の `level_up_cost_formula` を線形から二次へ**
  - ⚠ **`"base + growth * (level - 1)"` → `"base + growth * (level - 1) * (level - 1) / 245.0"`**
  - ⚠ **`GAME_DESIGN` 5-2 が名指しで指示していた置き換え**（「立ち上がりを寝かせて後半を跳ねさせる」）
  - ⚠ **効いているのは `.tres` ではなく `.gd` の `@export` 既定値**（⚠ **`.tres` に `level_up_cost_formula` の行が無い**）
- ⚠ **`stages.json`：経験値素材を `training_material_1` に一本化**（`stage_2` x5 ／ `stage_3` x6）
- ⚠ **`shop.json`：`slot_id` 7 / 8 を `_1` のまとめ買い（x75 / x180）へ**（⚠ **`daily` は13枠のまま**）
- ⚠ **`debug_boot.gd`：式の置き場の但し書きだけ修正。⚠ 数える処理は1行も触っていない**

⚠ **`.tres` / `ja.csv` / `.tscn` / `research.json` / `chests.json` / `recipes.json` / `items.json` を1件も触っていない。**
⚠ **赤も黄も1本も足していない**（`E130` / `W21` はまだ空いている）。

### 0-1. ⚠ 前と後（**全文は `EXEC_BALANCE_TUNE.md` §9-2**）

| | 前 | 後 |
|---|---|---|
| Lv100×3キャラの育成素材 | 15,444 個 | ⚠ **4,785 個** |
| `stage_2` を回す | **160.9 時間** | ⚠ **39.9 時間** |
| `stage_3` を回す | ⚠ **∞（1個も落ちない）** | ⚠ **33.3 時間**（⚠ **進むほど速い**） |
| 1回あたり（Lv1 / Lv20 / Lv99） | 3 / 22 / 101 個 | ⚠ **3 / 4 / 42 個** |
| ⚠ **入口が0件の素材** | **0 件** | ⚠ **3 件**（`training_material_2..4`） |
| ⚠ **出口が0件の素材** | **4 件** | ⚠ **4 件（同じまま）** |
| 研究の総コスト | 790 個 | ⚠ **790 個のまま**（`E127` に触れていない） |

### 0-2. ⚠ 人間の宿題（**⚠ 2件とも未了。⚠ 「終わっている」と書かないこと**）

1. ⚠ **今回の画面4項目**（`EXEC_BALANCE_TUNE.md` §5-C）
   - ⚠ **C-1：育成画面で Lv1 の必要数が `training_material_1` **3個**（⚠ 旧と同じ数字なのが正解）**
   - ⚠ **C-2：`F4`「素材を全種類」→ 20回上げて、Lv20 の必要数が **4個**（⚠ 旧なら22個）**
   - ⚠ **C-3：`F4`「画面を全部解放」→ ショップ（日替わり）に `training_material_1` の枠が **4つ**（x10 / x30 / x75 / x180）。⚠ 上級・超級の育成素材の枠が無い。⚠ 総数13**
   - ⚠ **C-4：`stage_3` を1回クリアして、経験値素材が **x6** で出る**
2. ⚠ **前の回から残っているセーブの確認**（`EXEC_BALANCE_ECONOMY.md` §5-C の3項目と §5-B の B-5）
   - ⚠ **`F4` →「装飾を全種類」→「セーブする」→ アプリを閉じて開き直す → もう一度「セーブする」。⚠ そのあと設計役が `save_slot_0.json` を読み、⚠ `"count"` に `.0` が0件であることを見る**

### 0-3. ⚠ 直近の人間の決定（**覆すときは影響範囲が広い**）

1. ⚠ **コンボは作らない**（2026-08-22）／ ⚠ **`target.range` は触らない**
2. ⚠ **素材IDは `<系統>_material_<1..4>` で固定** ／ ⚠ **状態の色は3つだけ。⚠ デバフも青**
3. ⚠ **プリセットは2階層。⚠ 装備も持ち、適用で着け替わる**（2026-08-23）
4. ⚠ **解放の単位は画面IDを増やす ／ 閉じている機能は「出さない」 ／ 引き金はステージのクリア**（2026-08-24）
5. ⚠ **パッシブは選ばない。⚠ 解放されたものが全部効く**（2026-08-25）
6. ⚠ **レベル100まで上げられるようにする**（2026-08-25。⚠ **`base_level_cap` 20 ＋ 研究8件 × 10 ＝ 100**）
7. ⚠ **作業場は「装飾のランダム製作」だけ。⚠ 中間素材は入れない**（2026-08-25）
8. ⚠ **Lv100 までの目安は集中40時間**（2026-08-25。⚠ **`stage_2` を回した場合の数字**）
9. ⚠ **経験値素材は `training_material_1` に一本化。⚠ `_2..4` はIDだけ残す**（2026-08-25）
10. ⚠ **`construction_material_4` の入口は作らない**（2026-08-25。⚠ **ショップ待ちのまま残す**）
11. ⚠ **器の変更は次の回に分ける**（2026-08-25。⚠ **＝このタスク**）

---

## 1. ⚠ このタスク：**残った穴の器を決める**

⚠ **`PLAN_IMPLEMENTATION.md` 3章の段階12は「入れた」で閉じている。⚠ これは段階13へ行く前の後始末。⚠ 規模は §1-2 の答え次第。**

### 1-0. ⚠ なぜ次がこれなのか

- ⚠ **数値で直せる穴は前の回で全部埋まった。⚠ 残っているのは「器が無いから直せない」3件だけ**（§1-2）
- ⚠ **どれも `GAME_DESIGN` に記述があり、⚠ 実装が追いついていない側の食い違い**
- ⚠ **これが片付くと、残りは 段階13（SDキャラとアニメーション＝専用の会話）だけ**
- ⚠ **「やらない」と決めるのも1つの答え。⚠ その場合このタスクは `PROJECT_STATUS` に宿題として残して段階13へ行く**

### 1-1. ⚠ いまの実装（**2026-08-25に確認**）

| | 事実 |
|---|---|
| ⚠ **数値の置き場**（ズレ39を実測で狭めた） | ⚠ **設計役が直せないのは `character_config.tres` の3行（`level_up_material_id` / `base_level_up_cost` / `cost_growth_per_level`）と `initial_state_config.tres` の初期値だけ。⚠ 他は `.gd` の `@export` 既定値か `master/*.json`＝設計役が直せる** |
| ⚠ **`pomodoro_config.tres`** | ⚠ **プリセット3件・加護3件・`min_*` / `max_*` の行しか無い。⚠ ポーションの `25分 / +50` は `.gd` の既定値＝設計役が直せる** |
| ⚠ **`training_material_2..4`** | ⚠ **入口も出口も無い。⚠ `items.json` に定義だけ残っている**（宿題52） |
| ⚠ **`decor_material_4`** | ⚠ **出口が無い。⚠ `max_part_tier = 4` のため。⚠ `GAME_DESIGN` 111行は「装飾 等級1〜5」と言っている**（宿題47） |
| ⚠ **`max_part_tier` を5にすると** | ⚠ **`game_manager.gd:2503` が段階5の装飾アイテム（`part_*_5` **36件**）を `items.json` に要求する。⚠ 数値ではなくコンテンツ追加になる** |
| ⚠ **`construction_material_4`** | ⚠ **入口は daily ショップ x3・5000G だけ。⚠ 研究が55個要求＝19日＋91,667G**（宿題48。⚠ **人間が「触らない」と決めた**） |
| ⚠ **`shop.json` の `slot_id` 12** | ⚠ **出口の無い `decor_material_4` を 5000G で売っている**（宿題53） |

### 1-2. ⚠ 先に聞くこと（**着手前**）

| # | 聞くこと | 設計役の推奨 |
|---|---|---|
| **1** | ⚠ **そもそもこの回をやるか、段階13へ行くか** | ⚠ **穴は3件とも「遊べなくなる穴」ではない**（⚠ **死に素材が3件と、⚠ 買うと損する枠が1つ**）。⚠ **段階13が「専用の会話」である以上、⚠ ここで畳んで宿題に落とす選択も妥当** |
| **2** | ⚠ **`decor_material_4` の出口をどうするか** | ⚠ **作業場に4本目のレシピを足す**（⚠ **`recipes.json` ＋ `ja.csv` に1行＝最小。⚠ `max_part_tier` は触らない**）。⚠ **装飾の等級5まで作るのは36件のアイテム追加＝別物** |
| **3** | ⚠ **`training_material_2..4` を将来どうするか** | ⚠ **今回は決めない。⚠ IDを残したまま宿題52で寝かせる**（⚠ **レベル帯の器を入れるのは「レベルアップの仕様変更」であり、⚠ 40時間の目安を測り直す回になる**） |
| **4** | ⚠ **`shop.json` の `slot_id` 12（`decor_material_4` を5000G）** | ⚠ **2 を採るなら残す。⚠ 採らないなら枠の中身を替える**（⚠ **枠を消すと13枠の平常値が変わる**） |

### 1-3. ⚠ 予想できている落ち（**先に潰すこと**）

- ⚠ **`ja.csv` を触ったら再インポートが要る**（⚠ **人間の作業。⚠ 済んだかは `scenario=passives` の1行で分かる**）
  - ⚠ **合図が見るキーは、⚠ その回に足したキーへ必ず差し替える**（⚠ **ズレ37。⚠ 今は `ui_research_category_workshop`**）
- ⚠ **`recipes.json` を触ると `scenario=workshop` の赤2本（`E129`）と件数の行が変わる**（⚠ **平常値を書き写さない**）
- ⚠ **`_sync_recipes_from_master()` の早期 `return` を戻さない**
- ⚠ **`_roll_weighted_table()` にボーナスを足さない**（`EXEC_WORKSHOP_REVIVE` 決め2）
- ⚠ **`economy` に赤や黄を足さない**（`EXEC_BALANCE_ECONOMY` 決め1）
- ⚠ **`E127`（`base_level_cap` 20 ＋ `level_cap_unlock` 8件×10 ＝ 100）を壊さない**
- ⚠ **素材を1件でも動かしたら `scenario=economy` を回し直し、⚠ 前後を並べる**
- ⚠ **`economy` の `⚠ 入口が0件のもの` の平常値は **3件**（`training_material_2..4`）。⚠ **0件ではない**

---

## 2. ⚠ 事故りやすい箇所

### 2-1. ⚠ ドキュメントの「実装済み」を信じない

**ズレが39回起きている。** ⚠ **`grep` で関数の中身を見てから判断する。⚠ 違っていたら報告する（勝手に直さない）。**

⚠ **未報告のズレは 4件（下の 34・37・38・39）。⚠ 次に見つけたものは 40 番。**

| # | ズレ | 直すなら |
|---|---|---|
| ⚠ **34** | ⚠ **`skill_schema.gd:330` のコメント「`of` を読まない source」は `scale_from` にしか当てはまらない。** ⚠ **`condition` は同じ source でも `of` が必須** | ⚠ **未着手。⚠ コメント側か、⚠ `condition` 側で `of` を任意にするか** |
| ⚠ **37** | ⚠ **`ja.csv` の再インポートの合図が「前の回のキー」を見ていた**（⚠ **`scenario=passives` の1行**） | ⚠ **その回のキーに差し替えて回避している**（今は `ui_research_category_workshop`） |
| ⚠ **38** | ⚠ **`GAME_DESIGN` 9-1 の作業場カテゴリに「変換レート」が残っている。⚠ 同じファイルの 9-3 と 2章（`:104`）が「変換は廃止・ショップに一本化」と書いている** | ⚠ **未着手。⚠ 9-1 の表の3つ目を消す** |
| ⚠ **39** | ⚠ **「数値は `.tres`（設計役は直せない）」が半分しか当たっていない**。⚠ **2026-08-25 に範囲を実測で狭めた（§1-1）**。⚠ **同じズレで「`_4` は月替わりショップだけ」も違う。⚠ `shop.json` に `weekly` / `monthly` のキーが無く `daily` しかない** | ⚠ **未着手。⚠ このファイルの §1-1 は既に実体に合わせて書いてある** |

### 2-2. ⚠ 触る器について、先に台帳を `grep` する

⚠ **`EXEC` の §「変えないもの」に何か書く前に、⚠ `GAME_DESIGN` / `PLAN_IMPLEMENTATION` / `PROJECT_STATUS` を `grep` して「置き換えろ」が無いことを確かめる。**
⚠ **実例（2026-08-25・数値を入れる回）：⚠ `GAME_DESIGN` 5-2 が「線形の式を差し替える」と名指しで指示していた。⚠ `NEXT_STEPS` §1-2 の推奨（「人間に係数を決めてもらう」）より仕様側が具体的で、⚠ しかも設計役が直せる場所だった。⚠ 台帳を見ずに推奨どおり進めていたら、⚠ 人間の Inspector 作業を1往復発生させたうえで線形のままにしていた**（⚠ **§2-2 が効いた3回目**）。

### 2-3. ⚠ 定数は名前ではなく値を見る

⚠ **`SCALE_ALIVE_ENEMY` の値は `"alive_enemy"` ではなく `"alive_count_enemy"`。⚠ 名前を JSON に書いてロード時に赤3本・戦闘中に毎フレームの赤3886本を出した**（2026-08-25）。

### 2-4. ⚠ `@export` を改名すると `.tres` の値が黙って消える

⚠ **実例：`ChestScheduleEntry.chest_type`**（⚠ **`protection_*.tres` の7件が黙って空になる**）。
⚠ **`.tres` に行が無い `@export` は改名しても消えるものが無い**（§1-1）が、⚠ **画面と JSON が綴りを参照している**ので同じく改名しないこと。

### 2-5. ⚠ 大きな範囲の文字列置換をしない

⚠ **2026-08-23に `game_manager.gd` で715行を丸ごと消した。** → ⚠ **`Edit` で1箇所ずつ当てる。**

### 2-6. ⚠ 「同じ形の判定」が散っていたら1本に寄せる

今ある1本ものは：
- ⚠ **`BattleSession.find_unit()`** ／ **`battle_controller._all_units()`** ／ **`StatusRegistry.entries_for()`**
- ⚠ **`GameManager.get_forge_material_tier()`** ／ **`add_to_inventory()`**（装備の個体を作る唯一の口）
- ⚠ **`GameManager.get_part_reject_reason()`** ／ **`get_equip_reject_reason()`** ／ **`grant_chest()`**
- ⚠ **`GameManager._roll_weighted_table()`**（⚠ **抽選の本体はここ1本だけ**）
- ⚠ **`GameManager.set_party_member()`** ／ **`get_party_candidates()`**
- ⚠ **`GameManager._plan_build()` / `_write_build()`** ／ **`format_apply_report()`**
- ⚠ **`GameManager.get_battle_skills()` / `get_battle_passives()` / `get_battle_runes()`**
- ⚠ **`GameManager.unlock_research_node()`** ／ **`get_research_board_of()`** ／ **`_research_effect_total()`**
- ⚠ **`GameManager.start_craft()` / `collect_craft()`** ／ **`get_part_upgrade_cost()` / `get_part_dismantle_refund()`**
- ⚠ **`MasterDataLoader.rune_skill_data()`** ／ **`_merge_character_files()`**
- ⚠ **`debug_boot._economy_sources()` / `_economy_sinks()`**（⚠ **対になっている。⚠ 片方だけ直さないこと**）

### 2-7. ⚠ E / W の次番号

⚠ **`E129` まで使用済み → `E130` から。** ⚠ **`W20` まで使用済み → `W21` から**（⚠ **`W3` `W6` `W7` は欠番**）。

---

## 3. 調査済みの事実（**`grep`し直さなくてよい**・2026-08-25確認）

> ⚠ **ここは「実コードの現在の状態」であって仕様ではない。** ⚠ **仕様は `GAME_DESIGN.md`。⚠ 台帳が「置き換えろ」と言っている項目は、ここに書いてあっても変わる**（⚠ **§2-2 の実例**）。

| | 事実 |
|---|---|
| ⚠ ログの実体 | ⚠ **`C:\Users\admin\AppData\Roaming\Godot\app_userdata\pomodoro-heroes\logs\`**。`battle_last.jsonl`（戦闘のたびに上書き）／ `godot.log`（保持5本） |
| ⚠ **セーブの実体** | ⚠ **`...\app_userdata\pomodoro-heroes\saves\save_slot_0.json`**（⚠ **`user://saves/` の下。⚠ 直下ではない**） |
| ロード時の正常な出力 | `skills validated: 94 entries, 0 errors, 1 warnings` ／ `basic attacks validated: 19 entries, 0 errors, 0 warnings` ／ `items validated: 89 entries, 0 errors` ／ `runes validated: 25 entries, 0 errors` ／ `balance item refs validated: 0 errors` ／ `_sync_research_tree_from_master() -> 20 nodes` ／ `level cap validated: 20 + 80 (8 nodes) = 100, 0 errors` ／ `_sync_recipes_from_master() -> 3 recipes (unlocked=3, skipped=0)` ／ `_sync_shop_from_master('daily') -> 13 slots` |
| ⚠ **マスターは7本** | ⚠ **`items` / `stages` / `shop` / `research` / `recipes` / `chests` / `runes`**（⚠ **`characters` `enemies` は配下にフォルダを持つ**） |
| ⚠ **数値の置き場** | ⚠ **§1-1 の表**（ズレ39・2026-08-25に範囲を狭めた） |
| ⚠ **レベル** | ⚠ **上限 100**（⚠ **`base_level_cap` 20 ＋ 研究 `level_cap_unlock` 8件 × 10**）。⚠ **`E127` が起動のたびに突き合わせる**。⚠ **式は `base + growth * (level - 1) * (level - 1) / 245.0`（`base=3` / `growth=1.0`）＝ Lv100 まで **1,595 個**／3キャラで **4,785 個** |
| ⚠ **上限で測るとき** | ⚠ **`Balance.character.max_character_level` を使う。⚠ `get_effective_level_cap()` は研究を解放するまで 20 を返す** |
| ⚠ **スタミナ** | ⚠ **1周 5**（`adventure_config.gd`）。⚠ **入口はポモドーロのポーションだけ**（⚠ **集中25分で1個・1個 +50 ＝ 集中1分あたり0.4周**）。⚠ **時間で回復しない**。⚠ **`25分 / +50` は `.gd` の既定値＝設計役が直せる** |
| ⚠ **研究** | ⚠ **2ボード20ノード**（⚠ **ボード1＝12件・ボード2＝8件**）。⚠ **枝は `combat` / `chest` / `workshop`**。⚠ **効果は5種類**。⚠ **総コスト 790 個**（`construction_material_1..4`） |
| ⚠ **作業場** | ⚠ **装飾のくじ3レシピ**（`craft_part_1..3`）。⚠ **投入は `decor_material_1..3` ×12。⚠ 30分/90分/3時間**。⚠ **`stage_3` のクリアで開く**。⚠ **キューは1本（研究で+1）** |
| ⚠ **パッシブ** | ⚠ **本番3キャラ × 5件＝15件。⚠ Lv20/40/60/80/100 で解放。⚠ 解放されたものが全部効く（選ばない）** |
| ⚠ **`condition` の書き方** | ⚠ **`source` に書けるのは 10軸 ＋ `hp_current` `hp_lost` `hp_ratio` `hp_lost_ratio` `elapsed_sec` `alive_count_ally` `alive_count_enemy` `wave_index` `stack` `status_has`**（⚠ **`distance` は除く**）。⚠ **`of` は必ず書く**（⚠ **ズレ34**） |
| ⚠ **`react` の出来事** | ⚠ **`attacked` / `dealt_damage` / `took_damage` の3つだけ** |
| ⚠ **素材** | ⚠ **16件**。`construction_` / `training_` / `forging_` / `decor_` × `_1..4`。⚠ **入口が無いものが3件（`training_material_2..4`）。⚠ 出口が無いものが4件（それに `decor_material_4`）** |
| ⚠ **装備の等級** | ⚠ **1〜10**。⚠ 段階は `forge_material_tier_min_grades = [1,4,7,10]`。⚠ **コストは `[8,12,16,20,24,28,32,36,40]`** |
| ⚠ **刺す枠** | ⚠ **長さ8の固定配列**（`null` 込み・**位置が枠を表す**）。⚠ **開く等級は `part_slot_min_grades = [3,4,5,5,6,7,8,9]`** |
| ⚠ **装飾** | ⚠ **61件**（宝石12・護符8・紋章16 ／ ルーン25）。⚠ **くじに入るのは前の36件だけ**。⚠ **段階上げは `[10,20,40]`・壊すと `[3,5,10,20]`**。⚠ **段階の上限は `max_part_tier = 4`** |
| ⚠ **装備の個体** | ⚠ **一意キーは `instance_id`（`eq_N`）。⚠ `equipment_instances` に入る。⚠ `inventory` を通らない** |
| ⚠ **編成** | ⚠ **状態が唯一の正**。⚠ **書く口は `set_party_member()` の1本** |
| ⚠ **本番ステージ** | ⚠ **`stage_1` / `stage_2` / `stage_3` の3本 × 各5ウェーブ。⚠ 5波目が全部ボス**。⚠ **報酬は 50 / 80 / 120 G**。⚠ **経験値素材は 2 / 5 / 6 個/周**。⚠ **宝箱は3割の周でしか出ない**（⚠ **周回ステージもスキップ周回も無い＝宿題49**） |
| ⚠ **ショップ** | ⚠ **`daily` の13枠だけ**（⚠ **`shop.json` に `weekly` / `monthly` のキーが無い＝ズレ39**）。⚠ **`training_material_1` が x10 / x30 / x75 / x180 の4枠**。⚠ **`slot_id` 12 は出口の無い `decor_material_4`＝宿題53** |
| ⚠ **画面の解放** | ⚠ **`stage_1` → `guild` `equipment` `training` `warehouse` ／ `stage_2` → `pomodoro` `decoration` ／ `stage_3` → `research` `shop` `rune` `workshop`** |
| ⚠ **`F4` のデバッグパネル** | ⚠ **`tests/debug_overlay.gd`。⚠ 「ゴールド・ジェム・スタミナ」「素材を全種類」「消費アイテムを全種類」「装備を全種類 1個ずつ」「装飾を全種類」「研究を全部解放」「画面を全部解放」「製作をすぐ完了させる」「セーブする」** |
| 行数 | `game_manager` **約5200** ／ `battle_controller` **約1800** ／ `debug_boot` **約2800** ／ `master_data_loader` **約1350** |

```
battle_controller  … 入力と表示。ノードを触る唯一の層。⚠ ルーンの発火もここ（_fire_runes）
					 ⚠ パッシブの掛け直しもここ（_step_passives → _restore_passives）
	  ↓ cast()
SkillRuntime       … 待ち行列。trigger・購読の配布と発火・中断
	  ↓ 効果1件ずつ
SkillResolver      … 1つの効果を確定した対象に当てる。時間も段も知らない
	  ↓ host が none 以外
StatusRegistry     … 状態。寿命はスキルより長い

BattleLog          … 静的クラス。どの層からも呼べる（Autoload ではない）
```

### 3-1. ⚠ 検証の道具（**人間に頼る前にこれを回す**）

```powershell
& 'D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' `
  --headless --path d:\pomodoro-heroes res://tests/debug_boot.tscn -- scenario=area
```

- ⚠ **`Start-Process` ＋ `-RedirectStandardOutput` / `-RedirectStandardError` で実行する**（直接叩くと1行も返らない）
- ⚠ **読むのは `[System.IO.File]::ReadAllLines(path, UTF8)`**（`Get-Content` は化ける）
- ⚠ **警告とエラーは `-RedirectStandardError` のほう**（`push_warning` / `push_error` は stdout に出ない）
- ⚠ **赤黄を数えるときは行頭で絞る**（`^(ERROR|WARNING)`）
- ⚠ **今あるシナリオ（31本）**：`area` / `recast` / `recast_expire` / `summon` / `summon_wipe` / `lineup` / `mitigate` / `pierce` / `shield` / `reflect` / `reflect_self` / `intervene_legacy` / `aura` / `aura_follow` / `pool` / `atk_mult` / `dot_react` / `status_ui` / `status_ui_over` / `materials` / `parts` / `drops` / `presets` / `layout` / `runes` / `unlock` / `passives` / `research` / `workshop` / `economy` / `training`
- ⚠ **`training` はヘッドレスで終わらない**（⚠ **窓あり専用。⚠ 全シナリオを回すときは除く＝30本**）
- ⚠ **`materials` / `parts` / `drops` / `presets` / `layout` / `unlock` / `research` / `workshop` / `economy` は戦闘を回さない**（`kind: "report"`）
- ⚠ **`economy` は数値を直したら必ず回す**（⚠ **前後の数字を並べる唯一の道具**）
  - ⚠ **`_economy_sources()` と `_economy_sinks()` は対。⚠ 入口か出口を1つ足したら両方を見る**
  - ⚠ **末尾の宿題43の枝は状態を丸ごと入れ替える。⚠ 何かを足すならその前に置くこと**
  - ⚠ **`drops` は `chests.json` しか見ていない。⚠ `stages.json` の固定報酬を見るのは `economy` の「1周で入るもの」の行だけ**（宿題54）
  - ⚠ **`⚠ Lv1 の突き合わせ` は式の差し替えを検出できない**（⚠ **Lv1 はどの式でも3個。⚠ 宿題55**）
- ⚠ **`layout` は「はみ出していないか」を数字で見る唯一の道具**。⚠ **器を足した回・件数を増やした回は必ず回すこと**
  - ⚠ **測る器を足すときは `LAYOUT_PATHS` / `LAYOUT_ROWS` / `LAYOUT_SCENES` に1行足す**
  - ⚠ **排他で切り替わる器・段階解放で消える器は `LAYOUT_SCENE_SHOW` に1行足す**
  - ⚠ **測るのは一番外側の `Container`。⚠ ルートを測ると必ず 0 が返る**（ズレ36）
  - ⚠ **基準は `SCREEN_SIZE`（1280 x 720）。⚠ ヘッドレスの viewport（1280 x 1280）を使わないこと**
  - ⚠ **`ScrollContainer` の中は測れない**（⚠ **縦は人間しか見られない**）
- ⚠ **黄の平常値は 1本**（`skill_dbg_dot_odd`）。⚠ **`drops` と `parts` はもう1本ずつ多いのが正解**
- ⚠ **赤の平常値は 0本。⚠ ただし `unlock` は 1本（`E125`）・`workshop` は 2本（`E129`）出るのが正解**
- ⚠ **`ja.csv` を触った回は、⚠ 再インポートが済むまで研究画面の効果が「？」になる。⚠ 済んだかは `scenario=passives` の `ja.csv の再インポート:` の1行で分かる**
  - ⚠ **合図が見るキーは、⚠ その回に足したキーへ必ず差し替えること**（⚠ **ズレ37。⚠ 今は `ui_research_category_workshop`**）
- ⚠ **1本あたり10〜20秒。⚠ 30本で9分ほど。⚠ 10本ずつ3回に分けて回すこと**（⚠ **PowerShell ツールの既定タイムアウトは2分。⚠ `timeout` を伸ばすこと**）
- ⚠ **シナリオは `SCENARIOS` に1行足す。シーンを増やさない**
  - ⚠ **報告の枝は `_ready()` の `elif` にも1行要る**（⚠ **`REPORT_*` の定数と合わせて3箇所**）
- ⚠ **足した検証が本当に効くか、2箇所で壊して確かめる。⚠ 壊したら必ず戻し、平常値に戻ったことを再実行で確認する**
- ⚠ **画面のスクリプトは `debug_boot` から読み込まれない。⚠ `--check-only --script` で `Parse Error` を見る**（⚠ **ただし Autoload が読まれないため `Identifier not found: GameManager / Balance / SceneManager` は必ず出る。⚠ これは無視してよい**）

---

## 4. 罠（**直近で実際に踏んだものだけ**）

### ⚠ 完了条件に「数字」だけでなく「意味」を書くと取り違える（**2026-08-25**）

⚠ **数値を入れる回で、⚠ 完了条件に「出口が0件のものが 4件 → 1件になる」と書いた。⚠ 実際に一本化が消したのは `_2..4` の**入口**であって、⚠ 出口は4件のまま。**
→ ⚠ **数字は予想どおりでも、⚠ 自分の変更が表のどちらの列を動かすのかを取り違えていた。**
→ ⚠ **完了条件を書いたら、⚠ 「その変更が触るのは入口か出口か」を1回だけ声に出して確かめる。**

### ⚠ 全シナリオを回している最中にコードを触らない

⚠ **2026-08-23に `game_manager.gd` を編集し、赤560本の偽陽性を出した。**
→ ⚠ **回している間は `.gd` / `.tscn` / `.json` / `.csv` を触らない。⚠ `.md` はよい。**

### ⚠ 測る道具が「0」や「全部同じ数字」を返したら、まずその道具を疑う（**2026-08-25に2回目**）

⚠ **1回目**：⚠ `scenario=layout` が6シーンとも `最小幅 0` を返していたのに流した（ズレ36）。
⚠ **2回目**：⚠ **ギルドが `72 x 72` を返していた。⚠ 段階解放で5個とも `visible = false` のため。**
→ ⚠ **もっともらしい小さい数字を信じない。**

### ⚠ 既存の器を「そのまま呼ぶ」前に、中に何が乗っているか見る（**2026-08-25**）

⚠ **`_roll_chest_draw()` の中に `get_research_chest_draw_bonus()` が入っていた。**
→ ⚠ **抽選の本体を `_roll_weighted_table()` に切り出し、⚠ ボーナスは呼ぶ側に置いた。**

### ⚠ 上限を返す関数が、その時点の状態を見ていることがある（**2026-08-25**）

⚠ **`get_effective_level_cap()` は研究を解放するまで 20 を返す。**
→ ⚠ **上限で測りたいときは `Balance.character.max_character_level` を使う。**

### ⚠ 画面の完了条件に「待つ」を書かない（**2026-08-25**）

⚠ **作業場の回で「30分待つ」を書き、人間の確認がそこで止まった。**
→ ⚠ **待ち時間のある機能は、`F4` に飛ばすボタンを同じ回で用意する。**

### ⚠ 人間がまだやっていないことを「終わっている」と書かない（**2026-08-25**）

⚠ **`NEXT_STEPS` に「人間の宿題は全部終わっている」と書いたが、⚠ セーブの確認が未了だった**（`28f1254` で訂正）。

### ⚠ 検証で在庫を「減らすために操作を繰り返す」書き方をしない

⚠ **2026-08-24**：⚠ **`while count > 1: merge_runes()` が150回回り、出力が数万行になった。**
→ ⚠ **`economy` は `level_up_character()` を99回回さず、式を直接99回評価している。**

### ⚠ Bash ツールに PowerShell の書き方を渡さない

⚠ **ヒアストリング（`@'...'@`）を渡してコミットメッセージの先頭に `@` が入った。⚠ Bash では heredoc（`<< 'EOF'`）。**

### ⚠ `.tscn` を触らずコードでノードを足すときは、隣の兄弟の `size_flags` を見る

⚠ **5個前提の並びに6個目を足して、拠点の下段が丸ごと左右にはみ出した。**

### ⚠ 新しい `class_name` は、エディタを1回通すまで認識されない

⚠ **確かめ方**：`grep -c "<クラス名>" .godot/global_script_class_cache.cfg`

### ⚠ 正常系に警告を付けない・`print` を増やさない

**出したい記録は `BattleLog` へ。**（⚠ **`tests/` は例外。あちらは `print` が出口**）

### インデントはタブ

`.gd`はタブ。**`.json`も既存ファイルはタブ**（⚠ トップレベルだけ半角スペース2つのファイルが在る＝`stages.json` / `chests.json` / `runes.json` / `recipes.json`）。`ja.csv`はUTF-8（BOMなし・LF）。

---

## 5. 引き継いだ宿題

**⚠ 全件は `PROJECT_STATUS.md`「溜まっている宿題」を見ること。** ここは判断待ちと大きい穴だけ。

### ⚠ 人間の判断待ち（**このタスクで効くもの**）

1. ⚠ **`decor_material_4` に出口が無い**（宿題47）。⚠ **`max_part_tier` を上げるとアイテム36件の追加になる**
2. ⚠ **`training_material_2..4` が入口も出口も無い**（宿題52）
3. ⚠ **`shop.json` の `slot_id` 12 が出口の無い素材を 5000G で売っている**（宿題53）
4. ⚠ **`construction_material_4` の入口がショップだけ**（宿題48。⚠ **人間が「触らない」と決めた**）
5. ⚠ **`GAME_DESIGN` 4-1 の周回ステージ・スキップ周回が実装に無い**（宿題49）
6. ⚠ **①戦闘の秒数と装飾の出目を測っていない**（宿題50）。⚠ **鍛冶・装飾・宝箱・ショップ価格の数値は「勘」のまま**（宿題56）
7. ⚠ **`W16`（知らない欄）を赤に上げるか** ／ ⚠ **godot MCP の設定を消すか** ／ ⚠ **`tests/` の既存9件の棚卸し** ／ ⚠ **Ziva の `.bak` が7件残っている**
8. ⚠ **`ja.ja.translation` が縮んだ理由が不明**（⚠ **再インポートで作り直される。⚠ どのコミットにも含めていない**）

### ⚠ 器の穴（**大きいものだけ**）

9. ⚠ **ルーンのかけらが無い** ／ ⚠ **ルーンの本番入手経路が無い**（`F4` だけ）
10. ⚠ **`GROWTH_PASSIVES`（状態）とキャラプリセットの `passives` が、誰も読まない欄として残っている**
11. ⚠ **`crafting_queue` の `output_item_id` / `recipe_type` が `draw` レシピでは `""` になる**
12. ⚠ **作業場のアップグレードが無い** ／ ⚠ **掘削（9-3-1）はデモ範囲外**
13. ⚠ **`react` の中で `buff` / `heal` を出す形が本番に0件** ／ ⚠ **`host: point` が本番に0件**
14. ⚠ **プリセットに名前を付けられない**（自動名）／ ⚠ **キャラプリセットを消せない** ／ ⚠ **`party_changed` シグナルが無い**
15. ⚠ **等級10の「部位固有のパッシブ」が未実装** ／ ⚠ **護符が宝石と仕組み上同じ**
16. ⚠ **移動のロック中であることが画面に出ない** ／ ⚠ **ルーンのCDが画面に出ない** ／ ⚠ **パッシブが戦闘画面のどこにも一覧で出ない**
17. ⚠ **召喚の同時数に上限が無い** ／ ⚠ **召喚はスキルもパッシブも持てない**
18. ⚠ **「死亡時発動」と「他人の蘇生」はまだ書けない** ／ ⚠ **多段の2発目に投射物が出ない**
19. ⚠ **反射は1段だけ** ／ ⚠ **DoT は反射しない** ／ ⚠ **シールドが複数付いたときの吸う順が未定**
20. ⚠ **オーラの範囲が画面に描かれない** ／ ⚠ **状態の色が3つしかない** ／ ⚠ **状態の残り時間がマスに出ない**
21. ⚠ **研究にゴールド払いが無い**（⚠ **`GAME_DESIGN` 9-1 は「ゴールドと各種資源」と言っている**）
22. ⚠ **研究の宝箱枝が「抽選回数」だけ** ／ ⚠ **ボードは2枚しか無い**

### ⚠ 表示の穴

23. ⚠ **戦闘結果の報酬画面に `rewards.inventory` が出ない**（⚠ **宝箱も出ない**）
24. ⚠ **素材欄・倉庫の持ち物タブが Dictionary のキー順**
25. ⚠ **`apply_battle_rewards()` が `gems` と `stamina` を読まない** ／ ⚠ **`open_chest()` が `stamina` を読まない**
26. ⚠ **`weapon_steel_sword` がどこからも出ない** ／ ⚠ **`ChestScheduleEntry.chest_type` だけ語が揃っていない**
27. ⚠ **プリセットを適用したとき、編成の3人の間で装備が移るぶんはメッセージに出ない**（意図的）

### 片付け

28. **検証用のものはリリース前に消す**（`stage_dbg_*` ／ `skill_dbg_*` ／ `st_dbg_*` ／ `char_debug_*` ／ `enemy_dbg_*` ／ `passive_dbg_*` ／ `summons.json` ／ `tests/debug_boot` ／ `tests/debug_overlay` ／ `ui_status_ch_*` ／ ⚠ **`GameManager.get_party_candidates()` の `OS.is_debug_build()` 分岐**）
29. ⚠ **`GameManager.PRESET_EQUIPMENT_ENABLED` の定数と分岐が残っている**
30. ⚠ **`ui_skill_select_passive_slot` と `ui_skill_select_passive_candidates_header` の2行が未使用**
31. ⚠ **共有部品 `BuildPresetRow` を作れていない**（⚠ **育成と装備に同じ行が2本ある**）
32. ⚠ **`pomodoro_config.gd` の `gold_per_focus_minute` / `stamina_per_focus_minute` / `materials_per_focus_minute` が誰も読まない欄**

---

## 6. 終わったあと

**このファイルを、次のタスクの内容に書き換える。**
⚠ **`debug_boot` の `SCENARIOS` は消さない**（次の回で使い回す）。
⚠ **`PLAN_IMPLEMENTATION.md` 3章の状態列を1行だけ直す**（⚠ **段階単位の完了はあそこ1箇所で持つ**）。
⚠ **素材を1件でも動かしたら `scenario=economy` を回し直し、⚠ 前後の数字を EXEC に並べる。**
⚠ **残りは 段階13（SDキャラとアニメーション＝専用の会話）だけ。**
